import Foundation
import AVFoundation
import Combine

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording(progress: Double, timeRemaining: Int)
    case processing
    case completed(URL)
    case error(String)
    
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.preparing, .preparing), (.processing, .processing):
            return true
        case let (.recording(p1, t1), .recording(p2, t2)):
            return p1 == p2 && t1 == t2
        case let (.completed(u1), .completed(u2)):
            return u1 == u2
        case let (.error(e1), .error(e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

// MARK: - Audio Quality Metrics

struct AudioQualityMetrics {
    let averagePower: Float
    let peakPower: Float
    let signalToNoiseRatio: Float
    let isQualityAcceptable: Bool
    
    var qualityDescription: String {
        if isQualityAcceptable {
            return "音质良好"
        } else if averagePower < -40 {
            return "音量过低，请靠近发动机"
        } else if signalToNoiseRatio < 10 {
            return "噪音过大，请在安静环境录音"
        } else {
            return "音质一般"
        }
    }
    
    var qualityColor: String {
        if isQualityAcceptable {
            return "#34C759"
        } else if averagePower < -40 || signalToNoiseRatio < 10 {
            return "#FF3B30"
        } else {
            return "#FF9500"
        }
    }
}

// MARK: - Audio Recording Service

@MainActor
final class AudioRecordingService: NSObject, ObservableObject, AudioRecordingServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var state: RecordingState = .idle
    @Published var audioLevels: [Float] = []
    @Published var currentMetrics: AudioQualityMetrics?
    @Published var hasMicrophonePermission = false
    
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingStartTime: Date?
    private let recordingDuration: TimeInterval = 12 // 录音时长12秒
    private let sampleRate: Double = 44100.0
    private let numberOfChannels: Int = 1
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var levelUpdateHandler: (([Float]) -> Void)?
    
    // 音频文件管理
    private var recordingsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("EngineEarRecordings", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
        
        return recordingsPath
    }
    
    // MARK: - Initialization
    
    static let shared = AudioRecordingService()
    
    private override init() {
        super.init()
        checkMicrophonePermission()
    }
    
    // MARK: - Permission Handling
    
    func checkMicrophonePermission() {
        switch audioSession.recordPermission {
        case .granted:
            hasMicrophonePermission = true
        case .denied:
            hasMicrophonePermission = false
            state = .error("麦克风权限被拒绝，请在设置中开启")
        case .undetermined:
            hasMicrophonePermission = false
        @unknown default:
            hasMicrophonePermission = false
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasMicrophonePermission = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() async throws {
        guard hasMicrophonePermission else {
            let granted = await requestMicrophonePermission()
            guard granted else {
                throw RecordingError.permissionDenied
            }
            return
        }
        
        state = .preparing
        
        do {
            // 配置音频会话
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            // 配置录音设置
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: numberOfChannels,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128000
            ]
            
            // 生成文件名
            let fileName = "engine_\(Date().timeIntervalSince1970).m4a"
            let fileURL = recordingsDirectory.appendingPathComponent(fileName)
            
            // 创建录音器
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            guard audioRecorder?.prepareToRecord() == true else {
                throw RecordingError.preparationFailed
            }
            
            // 开始录音
            audioRecorder?.record()
            recordingStartTime = Date()
            
            // 初始化音频电平数组
            audioLevels = Array(repeating: -60.0, count: 50)
            
            // 启动定时器更新状态
            startTimer()
            
            state = .recording(progress: 0.0, timeRemaining: Int(recordingDuration))
            
        } catch {
            state = .error("录音启动失败: \(error.localizedDescription)")
            throw RecordingError.startFailed(error.localizedDescription)
        }
    }
    
    func stopRecording() {
        timer?.invalidate()
        timer = nil
        
        audioRecorder?.stop()
        
        do {
            try audioSession.setActive(false)
        } catch {
            print("停止音频会话失败: \(error)")
        }
        
        if case .recording = state {
            if let url = audioRecorder?.url {
                state = .completed(url)
            } else {
                state = .error("录音文件保存失败")
            }
        }
    }
    
    func cancelRecording() {
        timer?.invalidate()
        timer = nil
        
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        
        do {
            try audioSession.setActive(false)
        } catch {
            print("停止音频会话失败: \(error)")
        }
        
        state = .idle
        audioLevels = []
        currentMetrics = nil
    }
    
    // MARK: - Timer & Level Updates
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateRecordingProgress()
            }
        }
    }
    
    private func updateRecordingProgress() {
        guard let startTime = recordingStartTime,
              let recorder = audioRecorder else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / recordingDuration, 1.0)
        let remaining = max(Int(recordingDuration - elapsed), 0)
        
        // 更新音频电平
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // 更新电平数组
        audioLevels.removeFirst()
        audioLevels.append(averagePower)
        
        // 计算音频质量指标
        currentMetrics = calculateQualityMetrics(averagePower: averagePower, peakPower: peakPower)
        
        // 更新状态
        if progress >= 1.0 {
            stopRecording()
        } else {
            state = .recording(progress: progress, timeRemaining: remaining)
        }
        
        // 回调电平更新
        levelUpdateHandler?(audioLevels)
    }
    
    // MARK: - Quality Metrics
    
    private func calculateQualityMetrics(averagePower: Float, peakPower: Float) -> AudioQualityMetrics {
        // 估算信噪比 (简化计算)
        let noiseFloor: Float = -60.0
        let signalToNoiseRatio = averagePower - noiseFloor
        
        // 判断音质是否可接受
        // 平均音量 > -30dB 且 信噪比 > 15dB 认为质量良好
        let isQualityAcceptable = averagePower > -35 && signalToNoiseRatio > 15
        
        return AudioQualityMetrics(
            averagePower: averagePower,
            peakPower: peakPower,
            signalToNoiseRatio: max(signalToNoiseRatio, 0),
            isQualityAcceptable: isQualityAcceptable
        )
    }
    
    // MARK: - File Management
    
    func getRecordingFileURL() -> URL? {
        if case .completed(let url) = state {
            return url
        }
        return nil
    }
    
    func cleanupOldRecordings(keepCount: Int = 10) {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            // 按创建时间排序
            let sortedFiles = files.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            
            // 删除旧文件
            if sortedFiles.count > keepCount {
                let filesToDelete = sortedFiles.suffix(from: keepCount)
                for file in filesToDelete {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("清理旧录音文件失败: \(error)")
        }
    }
    
    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Level Update Handler
    
    func onLevelUpdate(_ handler: @escaping ([Float]) -> Void) {
        self.levelUpdateHandler = handler
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.state = .error("录音异常终止")
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.state = .error("录音编码错误: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Recording Error

enum RecordingError: LocalizedError {
    case permissionDenied
    case preparationFailed
    case startFailed(String)
    case invalidState
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "麦克风权限被拒绝"
        case .preparationFailed:
            return "录音准备失败"
        case .startFailed(let message):
            return "录音启动失败: \(message)"
        case .invalidState:
            return "无效的录音状态"
        }
    }
}

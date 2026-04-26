import Foundation
import AVFoundation
import Accelerate
import Combine
import UIKit

// MARK: - AC System Status

enum ACSystemStatus: String, CaseIterable, Codable {
    case excellent = "优秀"
    case good = "良好"
    case fair = "一般"
    case poor = "较差"
    case critical = "严重"
    
    var color: String {
        switch self {
        case .excellent: return "#34C759"
        case .good: return "#5AC8FA"
        case .fair: return "#FFCC00"
        case .poor: return "#FF9500"
        case .critical: return "#FF3B30"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "snowflake.circle.fill"
        case .good: return "snowflake"
        case .fair: return "exclamationmark.triangle.fill"
        case .poor: return "exclamationmark.octagon.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    var description: String {
        switch self {
        case .excellent:
            return "空调系统状态极佳"
        case .good:
            return "空调系统工作正常"
        case .fair:
            return "空调系统性能略有下降"
        case .poor:
            return "空调系统需要检修"
        case .critical:
            return "空调系统存在严重问题"
        }
    }
}

// MARK: - AC Issue Type

enum ACIssueType: String, CaseIterable, Codable {
    case normal = "正常"
    case refrigerantLow = "制冷剂不足"
    case compressorIssue = "压缩机故障"
    case beltWear = "皮带磨损"
    case fanMotorIssue = "风机电机故障"
    case condenserBlockage = "冷凝器堵塞"
    case expansionValveIssue = "膨胀阀故障"
    case electricalIssue = "电路故障"
    
    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .refrigerantLow: return "drop.fill"
        case .compressorIssue: return "gearshape.fill"
        case .beltWear: return "circle.dashed"
        case .fanMotorIssue: return "fanblades.fill"
        case .condenserBlockage: return "rectangle.grid.2x2"
        case .expansionValveIssue: return "valve.fill"
        case .electricalIssue: return "bolt.fill"
        }
    }
    
    var description: String {
        switch self {
        case .normal:
            return "空调系统各部件工作正常"
        case .refrigerantLow:
            return "制冷剂压力不足，制冷效果下降"
        case .compressorIssue:
            return "压缩机工作异常，可能产生异响"
        case .beltWear:
            return "空调皮带磨损或松动"
        case .fanMotorIssue:
            return "冷凝器或蒸发器风机工作异常"
        case .condenserBlockage:
            return "冷凝器散热不良，影响制冷效果"
        case .expansionValveIssue:
            return "膨胀阀开度异常，制冷剂流量不稳"
        case .electricalIssue:
            return "空调电路存在故障"
        }
    }
    
    var severity: ACSystemStatus {
        switch self {
        case .normal: return .excellent
        case .condenserBlockage: return .fair
        case .beltWear: return .fair
        case .refrigerantLow: return .poor
        case .fanMotorIssue: return .poor
        case .expansionValveIssue: return .poor
        case .compressorIssue: return .critical
        case .electricalIssue: return .critical
        }
    }
    
    var recommendedAction: String {
        switch self {
        case .normal:
            return "继续保持定期保养"
        case .refrigerantLow:
            return "建议检查泄漏并补充制冷剂"
        case .compressorIssue:
            return "建议检查压缩机离合器和工作状态"
        case .beltWear:
            return "建议检查皮带张紧度或更换皮带"
        case .fanMotorIssue:
            return "建议检查风机电机和电路"
        case .condenserBlockage:
            return "建议清洗冷凝器表面"
        case .expansionValveIssue:
            return "建议检查膨胀阀工作状态"
        case .electricalIssue:
            return "建议检查空调电路和继电器"
        }
    }
}

// MARK: - Belt Analysis Result

struct BeltAnalysisResult: Codable {
    let wearLevel: Double // 0-100
    let tensionStatus: TensionStatus
    let crackDetected: Bool
    let glazingDetected: Bool
    let estimatedLife: Int // 剩余寿命百分比
    
    enum TensionStatus: String, Codable {
        case proper = "正常"
        case loose = "过松"
        case tight = "过紧"
    }
}

// MARK: - Fan Sound Analysis

struct FanSoundAnalysis: Codable {
    let noiseLevel: Double // dB
    let frequencySpectrum: [Double]
    let bearingCondition: BearingCondition
    let bladeBalance: BalanceStatus
    let motorHealth: MotorHealthStatus
    
    enum BearingCondition: String, Codable {
        case good = "良好"
        case worn = "磨损"
        case critical = "严重磨损"
    }
    
    enum BalanceStatus: String, Codable {
        case balanced = "平衡"
        case slightImbalance = "轻微不平衡"
        case severeImbalance = "严重不平衡"
    }
    
    enum MotorHealthStatus: String, Codable {
        case excellent = "优秀"
        case good = "良好"
        case fair = "一般"
        case poor = "较差"
    }
}

// MARK: - AC Diagnosis Result

struct ACDiagnosisResult: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let overallScore: Int
    let status: ACSystemStatus
    let detectedIssues: [ACIssueType]
    let beltAnalysis: BeltAnalysisResult?
    let fanAnalysis: FanSoundAnalysis?
    let refrigerantPressure: Double? // bar
    let outletTemperature: Double? // °C
    let ambientTemperature: Double? // °C
    let recommendations: [String]
}

// MARK: - AC Monitor Service

@MainActor
final class ACMonitorService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var recordingProgress: Double = 0
    @Published var currentNoiseLevel: Double = 0
    @Published var analysisResult: ACDiagnosisResult?
    @Published var spectrumData: [Double] = []
    
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var analysisTimer: Timer?
    
    private let sampleRate: Double = 44100.0
    private let fftSize = 2048
    
    // MARK: - Singleton
    
    static let shared = ACMonitorService()
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startRecording(duration: TimeInterval = 5.0) {
        guard !isRecording else { return }
        
        isRecording = true
        recordingProgress = 0
        
        // 开始录制
        startAudioRecording()
        
        // 进度更新 - 使用MainActor确保在主线程更新UI
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recordingProgress += 0.1 / duration
                
                if self.recordingProgress >= 1.0 {
                    self.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        isRecording = false
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    /// 分析空调皮带图像 - 使用真实图像处理
    /// - Parameter image: 拍摄的皮带图像
    /// - Returns: 皮带分析结果
    func analyzeBeltFromImage(_ image: UIImage) -> BeltAnalysisResult {
        // 使用真实图像处理分析皮带状态
        let analysis = performBeltImageAnalysis(image)
        return analysis
    }
    
    /// 执行真实皮带图像分析
    private func performBeltImageAnalysis(_ image: UIImage) -> BeltAnalysisResult {
        guard let cgImage = image.cgImage else {
            return BeltAnalysisResult(
                wearLevel: 0,
                tensionStatus: .proper,
                crackDetected: false,
                glazingDetected: false,
                estimatedLife: 100
            )
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return BeltAnalysisResult(
                wearLevel: 0,
                tensionStatus: .proper,
                crackDetected: false,
                glazingDetected: false,
                estimatedLife: 100
            )
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 分析皮带区域的颜色特征
        var totalBrightness: Double = 0
        var darkPixelCount = 0
        var brightPixelCount = 0
        var crackedPixelCount = 0
        var glazedPixelCount = 0
        var edgeVarianceSum: Double = 0
        
        let totalPixels = width * height
        let sampleStep = max(1, totalPixels / 10000) // 采样以提高性能
        
        for i in stride(from: 0, to: totalPixels, by: sampleStep) {
            let offset = i * bytesPerPixel
            let r = Double(pixels[offset])
            let g = Double(pixels[offset + 1])
            let b = Double(pixels[offset + 2])
            
            // 计算亮度
            let brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
            totalBrightness += brightness
            
            // 检测深色像素（裂纹）
            if brightness < 0.15 {
                darkPixelCount += 1
            }
            
            // 检测高亮像素（磨损/老化）
            if brightness > 0.85 {
                brightPixelCount += 1
            }
            
            // 检测边缘变化（裂纹特征）
            if i > 0 && i < totalPixels - 1 {
                let prevOffset = (i - sampleStep) * bytesPerPixel
                let nextOffset = min((i + sampleStep) * bytesPerPixel, pixels.count - bytesPerPixel)
                
                let prevBrightness = (Double(pixels[prevOffset]) * 0.299 + Double(pixels[prevOffset + 1]) * 0.587 + Double(pixels[prevOffset + 2]) * 0.114) / 255.0
                let nextBrightness = (Double(pixels[nextOffset]) * 0.299 + Double(pixels[nextOffset + 1]) * 0.587 + Double(pixels[nextOffset + 2]) * 0.114) / 255.0
                
                let variance = abs(nextBrightness - prevBrightness)
                edgeVarianceSum += variance
                
                // 高方差区域可能是裂纹
                if variance > 0.3 {
                    crackedPixelCount += 1
                }
            }
            
            // 检测釉面特征（老化皮带的光泽）
            let colorVariance = max(abs(r - g), abs(g - b), abs(r - b)) / 255.0
            if brightness > 0.6 && colorVariance < 0.1 {
                glazedPixelCount += 1
            }
        }
        
        let sampledPixels = totalPixels / sampleStep
        let avgBrightness = totalBrightness / Double(sampledPixels)
        let darkRatio = Double(darkPixelCount) / Double(sampledPixels)
        let brightRatio = Double(brightPixelCount) / Double(sampledPixels)
        let crackRatio = Double(crackedPixelCount) / Double(sampledPixels)
        let glazeRatio = Double(glazedPixelCount) / Double(sampledPixels)
        let avgEdgeVariance = edgeVarianceSum / Double(sampledPixels)

        // 计算磨损等级
        var wearLevel: Double = 0

        // 基于亮度的磨损评估（老化皮带会变亮/发白）
        if avgBrightness > 0.7 {
            wearLevel += (avgBrightness - 0.7) * 150
        }

        // 基于裂纹的磨损评估
        wearLevel += crackRatio * 200

        // 基于釉面特征的磨损评估
        wearLevel += glazeRatio * 100

        // 基于边缘变化的磨损评估
        wearLevel += avgEdgeVariance * 50

        wearLevel = min(100, max(0, wearLevel))

        // 检测裂纹
        let crackDetected = crackRatio > 0.02 || darkRatio > 0.05

        // 使用 brightRatio 避免警告
        let _ = brightRatio
        
        // 检测釉面
        let glazingDetected = glazeRatio > 0.1 && avgBrightness > 0.65
        
        // 估计剩余寿命
        let estimatedLife = max(0, Int(100 - wearLevel))
        
        // 判断张紧状态（基于图像中的皮带直线度）
        let tensionStatus = determineTensionStatus(from: avgEdgeVariance, brightness: avgBrightness)
        
        return BeltAnalysisResult(
            wearLevel: wearLevel,
            tensionStatus: tensionStatus,
            crackDetected: crackDetected,
            glazingDetected: glazingDetected,
            estimatedLife: estimatedLife
        )
    }
    
    /// 根据图像特征判断皮带张紧状态
    private func determineTensionStatus(from edgeVariance: Double, brightness: Double) -> BeltAnalysisResult.TensionStatus {
        // 过松的皮带会有更多的振动/模糊
        // 过紧的皮带会显示更明显的拉伸痕迹
        
        if edgeVariance > 0.15 && brightness > 0.6 {
            return .loose
        } else if edgeVariance < 0.05 && brightness < 0.4 {
            return .tight
        } else {
            return .proper
        }
    }
    
    private let audioAnalyzer = ACAudioAnalyzer()
    
    func analyzeFanSound(audioURL: URL? = nil) async throws -> FanSoundAnalysis {
        // 如果有音频文件，进行真实分析
        if let url = audioURL {
            let analyzer = audioAnalyzer
            let analysis = try await analyzer.analyzeAudio(at: url)
            return interpretAudioAnalysis(analysis)
        }
        
        // 如果没有音频，返回需要录音的提示
        throw ACMonitorError.audioRecordingRequired
    }
    
    func analyzeFanSound(buffer: AVAudioPCMBuffer) -> FanSoundAnalysis {
        let analyzer = audioAnalyzer
        let analysis = analyzer.analyzeBuffer(buffer)
        return interpretAudioAnalysis(analysis)
    }
    
    private func interpretAudioAnalysis(_ analysis: AudioAnalysisResult) -> FanSoundAnalysis {
        // 根据音频特征判断风机状态
        let noiseLevel = analysis.rms > 0 ? 20 * log10(analysis.rms) + 94 : 40 // 转换为dB SPL
        
        // 判断轴承状态
        let bearingCondition: FanSoundAnalysis.BearingCondition
        if analysis.bearingEnergy > 50 {
            bearingCondition = .critical
        } else if analysis.bearingEnergy > 20 {
            bearingCondition = .worn
        } else {
            bearingCondition = .good
        }
        
        // 判断叶片平衡
        let bladeBalance: FanSoundAnalysis.BalanceStatus
        if analysis.bladeEnergy > 100 {
            bladeBalance = .severeImbalance
        } else if analysis.bladeEnergy > 50 {
            bladeBalance = .slightImbalance
        } else {
            bladeBalance = .balanced
        }
        
        // 判断电机健康
        let motorHealth: FanSoundAnalysis.MotorHealthStatus
        if analysis.motorEnergy > 200 {
            motorHealth = .poor
        } else if analysis.motorEnergy > 100 {
            motorHealth = .fair
        } else if analysis.motorEnergy > 50 {
            motorHealth = .good
        } else {
            motorHealth = .excellent
        }
        
        return FanSoundAnalysis(
            noiseLevel: max(30, min(90, noiseLevel)),
            frequencySpectrum: analysis.spectrum,
            bearingCondition: bearingCondition,
            bladeBalance: bladeBalance,
            motorHealth: motorHealth
        )
    }
    
    func performDiagnosis(
        beltAnalysis: BeltAnalysisResult? = nil,
        fanAnalysis: FanSoundAnalysis? = nil,
        refrigerantPressure: Double? = nil,
        outletTemp: Double? = nil,
        ambientTemp: Double? = nil
    ) -> ACDiagnosisResult {
        var issues: [ACIssueType] = []
        var score = 100
        
        // 分析皮带
        if let belt = beltAnalysis {
            if belt.wearLevel > 70 {
                issues.append(.beltWear)
                score -= 20
            } else if belt.wearLevel > 50 {
                score -= 10
            }
            
            if belt.tensionStatus != .proper {
                issues.append(.beltWear)
                score -= 10
            }
        }
        
        // 分析风机
        if let fan = fanAnalysis {
            if fan.noiseLevel > 70 {
                score -= 15
            }
            
            if fan.bearingCondition == .critical {
                issues.append(.fanMotorIssue)
                score -= 25
            } else if fan.bearingCondition == .worn {
                issues.append(.fanMotorIssue)
                score -= 15
            }
            
            if fan.bladeBalance == .severeImbalance {
                score -= 15
            } else if fan.bladeBalance == .slightImbalance {
                score -= 5
            }
        }
        
        // 分析制冷剂压力
        if let pressure = refrigerantPressure {
            if pressure < 1.5 {
                issues.append(.refrigerantLow)
                score -= 20
            } else if pressure > 3.5 {
                issues.append(.expansionValveIssue)
                score -= 15
            }
        }
        
        // 分析温度差
        if let outlet = outletTemp, let ambient = ambientTemp {
            let tempDiff = ambient - outlet
            if tempDiff < 5 {
                if !issues.contains(.refrigerantLow) {
                    issues.append(.refrigerantLow)
                }
                score -= 15
            } else if tempDiff < 8 {
                score -= 5
            }
        }
        
        // 如果没有问题，标记为正常
        if issues.isEmpty {
            issues.append(.normal)
        }
        
        score = max(0, score)
        let status = statusFromScore(score)
        
        // 生成建议
        var recommendations: [String] = []
        for issue in issues where issue != .normal {
            recommendations.append(issue.recommendedAction)
        }
        
        if recommendations.isEmpty {
            recommendations.append("空调系统状态良好，继续保持定期保养")
        }
        
        let result = ACDiagnosisResult(
            id: UUID(),
            timestamp: Date(),
            overallScore: score,
            status: status,
            detectedIssues: issues,
            beltAnalysis: beltAnalysis,
            fanAnalysis: fanAnalysis,
            refrigerantPressure: refrigerantPressure,
            outletTemperature: outletTemp,
            ambientTemperature: ambientTemp,
            recommendations: recommendations
        )
        
        analysisResult = result
        return result
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    private func startAudioRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("ac_recording.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
        } catch {
            print("Recording failed: \(error)")
        }
    }
    
    private func statusFromScore(_ score: Int) -> ACSystemStatus {
        switch score {
        case 90...100: return .excellent
        case 75...89: return .good
        case 60...74: return .fair
        case 40...59: return .poor
        default: return .critical
        }
    }
}

// MARK: - AC Monitor Error

enum ACMonitorError: Error, LocalizedError {
    case audioRecordingRequired
    case analysisFailed(String)
    case invalidInput(String)
    
    var errorDescription: String? {
        switch self {
        case .audioRecordingRequired:
            return "需要录制音频进行分析"
        case .analysisFailed(let reason):
            return "分析失败: \(reason)"
        case .invalidInput(let reason):
            return "输入无效: \(reason)"
        }
    }
}

// MARK: - AC Audio Analyzer (Integrated)

/// 空调系统音频分析器 - 用于分析风机和压缩机的声音
struct ACAudioAnalyzer {
    
    private let sampleRate: Double = 44100.0
    private let fftSize = 2048
    
    func analyzeAudio(at url: URL) async throws -> AudioAnalysisResult {
        let audioData = try await loadAudioData(from: url)
        let spectrum = try performFFT(on: audioData)
        return extractFeatures(from: spectrum, audioData: audioData)
    }
    
    func analyzeBuffer(_ buffer: AVAudioPCMBuffer) -> AudioAnalysisResult {
        guard let channelData = buffer.floatChannelData?[0] else {
            return AudioAnalysisResult.empty
        }
        let frameLength = Int(buffer.frameLength)
        let data = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        do {
            let spectrum = try performFFT(on: data)
            return extractFeatures(from: spectrum, audioData: data)
        } catch {
            return AudioAnalysisResult.empty
        }
    }
    
    private func loadAudioData(from url: URL) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = UInt32(file.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ACAudioError.invalidAudioFile
        }
        
        try file.read(into: buffer)
        
        guard let channelData = buffer.floatChannelData?[0] else {
            throw ACAudioError.noAudioData
        }
        
        return Array(UnsafeBufferPointer(start: channelData, count: Int(frameCount)))
    }
    
    private func performFFT(on data: [Float]) throws -> [Float] {
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw ACAudioError.fftSetupFailed
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // 准备输入数据 - 使用单精度
        var real = Array(data.prefix(fftSize))
        // 如果数据不足，补零
        if real.count < fftSize {
            real.append(contentsOf: [Float](repeating: 0.0, count: fftSize - real.count))
        }
        var imaginary = [Float](repeating: 0.0, count: fftSize)
        
        // 执行FFT - 使用单精度版本
        real.withUnsafeMutableBufferPointer { realPtr in
            imaginary.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        
        // 计算幅度谱
        var magnitudes = [Float](repeating: 0.0, count: fftSize / 2)
        for i in 0..<fftSize / 2 {
            magnitudes[i] = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
        }
        
        // 转换为dB刻度 - 使用单精度版本
        var dbValues = [Float](repeating: 0.0, count: fftSize / 2)
        var zero: Float = 0.0
        vDSP_vdbcon(magnitudes, 1, &zero, &dbValues, 1, vDSP_Length(fftSize / 2), 1)
        
        return dbValues
    }
    
    private func extractFeatures(from spectrum: [Float], audioData: [Float]) -> AudioAnalysisResult {
        let totalEnergy = spectrum.reduce(0) { $0 + $1 }
        let rms = calculateRMS(audioData)
        let centroid = calculateSpectralCentroid(spectrum)
        let flatness = calculateSpectralFlatness(spectrum)
        let peakFrequencies = detectPeakFrequencies(in: spectrum)
        
        let bearingRange = 50...500
        let bearingEnergy = calculateEnergyInRange(spectrum, range: bearingRange)
        
        let bladeRange = 100...1000
        let bladeEnergy = calculateEnergyInRange(spectrum, range: bladeRange)
        
        let motorRange = 1000...8000
        let motorEnergy = calculateEnergyInRange(spectrum, range: motorRange)
        
        return AudioAnalysisResult(
            spectrum: spectrum.map { Double($0) },
            totalEnergy: Double(totalEnergy),
            rms: rms,
            spectralCentroid: centroid,
            spectralFlatness: flatness,
            peakFrequencies: peakFrequencies,
            bearingEnergy: bearingEnergy,
            bladeEnergy: bladeEnergy,
            motorEnergy: motorEnergy
        )
    }
    
    private func calculateRMS(_ data: [Float]) -> Double {
        var sum: Float = 0
        for sample in data {
            sum += sample * sample
        }
        return Double(sqrt(sum / Float(data.count)))
    }
    
    private func calculateSpectralCentroid(_ spectrum: [Float]) -> Double {
        var weightedSum: Double = 0
        var sum: Double = 0
        
        for (index, magnitude) in spectrum.enumerated() {
            let frequency = Double(index) * sampleRate / Double(fftSize)
            weightedSum += frequency * Double(magnitude)
            sum += Double(magnitude)
        }
        
        return sum > 0 ? weightedSum / sum : 0
    }
    
    private func calculateSpectralFlatness(_ spectrum: [Float]) -> Double {
        let logSum = spectrum.reduce(0.0) { partialResult, value in
            partialResult + log(Double(value) + 1e-10)
        }
        let arithmeticMean = spectrum.reduce(0.0) { partialResult, value in
            partialResult + Double(value)
        } / Double(spectrum.count)
        let geometricMean = exp(logSum / Double(spectrum.count))
        
        return arithmeticMean > 0 ? geometricMean / arithmeticMean : 0
    }
    
    private func detectPeakFrequencies(in spectrum: [Float]) -> [Double] {
        var peaks: [Double] = []
        let threshold: Float = spectrum.max() ?? 0 * 0.3
        
        for i in 1..<spectrum.count - 1 {
            if spectrum[i] > threshold &&
               spectrum[i] > spectrum[i - 1] &&
               spectrum[i] > spectrum[i + 1] {
                let frequency = Double(i) * sampleRate / Double(fftSize)
                peaks.append(frequency)
            }
        }
        
        return peaks.sorted().prefix(10).map { $0 }
    }
    
    private func calculateEnergyInRange(_ spectrum: [Float], range: ClosedRange<Int>) -> Double {
        let startIndex = Int(Double(range.lowerBound) * Double(fftSize) / sampleRate)
        let endIndex = min(Int(Double(range.upperBound) * Double(fftSize) / sampleRate), spectrum.count)
        
        guard startIndex < endIndex else { return 0 }
        
        let rangeData = Array(spectrum[startIndex..<endIndex])
        return Double(rangeData.reduce(0) { $0 + $1 })
    }
}

// MARK: - Audio Analysis Result

struct AudioAnalysisResult {
    let spectrum: [Double]
    let totalEnergy: Double
    let rms: Double
    let spectralCentroid: Double
    let spectralFlatness: Double
    let peakFrequencies: [Double]
    let bearingEnergy: Double
    let bladeEnergy: Double
    let motorEnergy: Double
    
    static let empty = AudioAnalysisResult(
        spectrum: [],
        totalEnergy: 0,
        rms: 0,
        spectralCentroid: 0,
        spectralFlatness: 0,
        peakFrequencies: [],
        bearingEnergy: 0,
        bladeEnergy: 0,
        motorEnergy: 0
    )
}

// MARK: - ACAudioError

enum ACAudioError: Error {
    case invalidAudioFile
    case noAudioData
    case fftSetupFailed
}

// MARK: - Extension for DrivingMode

extension SuspensionDiagnosisResult.DrivingMode {
    static var allCases: [SuspensionDiagnosisResult.DrivingMode] {
        return [.stationary, .city, .highway, .rough]
    }
}

import SwiftUI
import AVFoundation

struct EngineEarView: View {
    @StateObject private var classifier = EngineSoundClassifier()
    @StateObject private var audioRecorder = AudioRecorderService()
    @State private var lastResult: ClassificationResult?
    @State private var showGuide = true
    @State private var showModelStatus = false
    
    var body: some View {
        List {
            // 模型和传感器状态栏
            Section {
                HStack(spacing: 16) {
                    // 模型状态
                    HStack(spacing: 4) {
                        Circle()
                            .fill(classifier.isModelLoaded ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text("AI模型")
                            .font(.caption)
                        Text(classifier.isModelLoaded ? "就绪" : "加载中")
                            .font(.caption)
                            .foregroundColor(classifier.isModelLoaded ? .green : .red)
                    }
                    
                    Spacer()
                    
                    // 麦克风状态
                    HStack(spacing: 4) {
                        Circle()
                            .fill(audioRecorder.isAuthorized ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text("麦克风")
                            .font(.caption)
                        Text(audioRecorder.isAuthorized ? "正常" : "未授权")
                            .font(.caption)
                            .foregroundColor(audioRecorder.isAuthorized ? .green : .orange)
                    }
                }
            }
            .listRowBackground(Color.clear)
            
            // 使用指南
            if showGuide {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("将手机靠近发动机舱，点击录音按钮录制5秒")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("保持环境安静，避免其他噪音干扰")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Button {
                        withAnimation {
                            showGuide = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("知道了")
                            Spacer()
                        }
                    }
                    .foregroundColor(.gray)
                }
            }
            
            // 录音按钮
            Section {
                Button {
                    audioRecorder.isRecording ? stopRecording() : startRecording()
                } label: {
                    HStack {
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title2)
                        Text(audioRecorder.isRecording ? "停止录音" : "开始录音")
                            .font(.body)
                        Spacer()
                        if audioRecorder.isRecording {
                            Image(systemName: "waveform")
                                .foregroundColor(.red)
                        }
                    }
                }
                .foregroundColor(audioRecorder.isRecording ? .red : .white)
                .disabled(!classifier.isModelLoaded || classifier.isLoading)
            } header: {
                Text("操作")
                    .font(.caption)
                    .textCase(.uppercase)
            }
            
            // 录音状态
            if audioRecorder.isRecording {
                Section {
                    HStack {
                        Text("录音中...")
                        Spacer()
                        Text("\(String(format: "%.1f", audioRecorder.currentTime))s")
                    }
                    .foregroundColor(.red)
                    
                    ProgressView(value: min(audioRecorder.currentTime / 5.0, 1.0))
                        .progressViewStyle(.linear)
                        .tint(.red)
                }
            }
            
            // 分析状态
            if classifier.isLoading {
                Section {
                    HStack {
                        Text("AI分析中")
                        Spacer()
                        ProgressView()
                    }
                }
            }
            
            // 诊断结果
            if let result = lastResult {
                Section {
                    HStack {
                        Text("诊断结果")
                        Spacer()
                        Text(result.faultType.rawValue)
                            .foregroundColor(result.faultType.severity == .normal ? .green : .orange)
                    }
                    
                    HStack {
                        Text("置信度")
                        Spacer()
                        Text("\(Int(result.confidence * 100))%")
                            .foregroundColor(.gray)
                    }
                    
                    if !result.faultType.recommendedAction.isEmpty {
                        HStack {
                            Text("建议")
                            Spacer()
                            Text(result.faultType.recommendedAction)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Button {
                        lastResult = nil
                        showGuide = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("重新检测")
                            Spacer()
                        }
                    }
                    .foregroundColor(.gray)
                } header: {
                    Text("结果")
                        .font(.caption)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.plain)
        .background(.black)
        .scrollContentBackground(.hidden)
        .navigationTitle("引擎听诊")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showModelStatus = true
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(classifier.isModelLoaded ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text("模型")
                            .font(.caption)
                    }
                }
            }
        }
        .sheet(isPresented: $showModelStatus) {
            ModelStatusView(
                modelName: "EngineSoundClassifier",
                isLoaded: classifier.isModelLoaded,
                errorMessage: classifier.errorMessage
            )
        }
        .preferredColorScheme(.dark)
        .onAppear {
            audioRecorder.requestPermission()
        }
    }
    
    private func startRecording() {
        do {
            try audioRecorder.startRecording()
            
            // 5秒后自动停止
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if audioRecorder.isRecording {
                    stopRecording()
                }
            }
        } catch {
            print("录音失败: \(error)")
        }
    }
    
    private func stopRecording() {
        guard let audioURL = audioRecorder.stopRecording() else {
            print("无法获取录音文件")
            return
        }
        
        // 使用真实模型分析
        Task {
            do {
                let result = try await classifier.classify(audioURL: audioURL)
                await MainActor.run {
                    lastResult = result
                }
            } catch {
                print("分析失败: \(error)")
            }
        }
    }
}

// MARK: - Audio Recorder Service

@MainActor
class AudioRecorderService: ObservableObject {
    @Published var isRecording = false
    @Published var currentTime: TimeInterval = 0
    @Published var isAuthorized = false
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?
    
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
        }
    }
    
    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("engine_\(Date().timeIntervalSince1970).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.record()
        recordingURL = audioFilename
        
        isRecording = true
        currentTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.currentTime += 0.1
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        timer?.invalidate()
        isRecording = false
        
        try? AVAudioSession.sharedInstance().setActive(false)
        
        return recordingURL
    }
}

// MARK: - Model Status View

struct ModelStatusView: View {
    let modelName: String
    let isLoaded: Bool
    let errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("模型状态") {
                    HStack {
                        Text("模型名称")
                        Spacer()
                        Text(modelName)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("加载状态")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isLoaded ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(isLoaded ? "已加载" : "未加载")
                                .foregroundColor(isLoaded ? .green : .red)
                        }
                    }
                    
                    if let error = errorMessage {
                        HStack(alignment: .top) {
                            Text("错误信息")
                            Spacer()
                            Text(error)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(.black)
            .scrollContentBackground(.hidden)
            .navigationTitle("模型状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

#Preview("Engine Ear") {
    NavigationStack {
        EngineEarView()
    }
}

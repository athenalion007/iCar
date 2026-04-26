import SwiftUI

// MARK: - Engine Ear View (极简主义)

struct EngineEarViewV2: View {

    @StateObject private var aiService = EngineEarAIService.shared
    @StateObject private var recordingService = AudioRecordingService.shared
    @StateObject private var reportService = UnifiedReportService.shared
    @State private var viewState: EngineViewState = .guide
    @State private var diagnosisResult: EngineDiagnosisResult?
    @State private var recordedURL: URL?
    @State private var errorMessage: String?
    @State private var isSaving = false

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showDetail = false

    enum EngineViewState {
        case guide
        case recording
        case confirm
        case analyzing
        case result
        case error
    }

    var body: some View {
        List {
            content
        }
        .listStyle(.plain)
        .background(.black)
        .scrollContentBackground(.hidden)
        .navigationTitle("引擎听诊")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                leadingToolbarButton
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                trailingToolbarButton
            }
        }
        .alert("保存成功", isPresented: $showSaveConfirmation) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("诊断报告已保存到历史记录")
        }
        .alert("保存失败", isPresented: $showSaveError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            if let result = diagnosisResult {
                EngineEarShareSheet(activityItems: [createShareContent(from: result)])
            }
        }
        .preferredColorScheme(.dark)
    }

    private func createShareContent(from result: EngineDiagnosisResult) -> String {
        var content = "iCar 发动机诊断报告\n"
        content += "检测时间: \(Date().formatted(date: .long, time: .shortened))\n"
        content += "诊断结果: \(result.faultType.rawValue)\n"
        content += "严重程度: \(result.severity.rawValue)\n\n"
        content += "建议: \(result.recommendedAction)\n"
        return content
    }

    // MARK: - Toolbar Buttons

    @ViewBuilder
    private var leadingToolbarButton: some View {
        switch viewState {
        case .guide, .result, .error:
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
            }
        case .confirm:
            Button {
                recordedURL = nil
                viewState = .recording
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .semibold))
            }
        case .recording, .analyzing:
            Button {
                recordingService.cancelRecording()
                recordedURL = nil
                viewState = .guide
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private var trailingToolbarButton: some View {
        switch viewState {
        case .result:
            HStack(spacing: 16) {
                // 保存按钮
                Button {
                    saveReport()
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .disabled(isSaving)

                // 分享按钮
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Save Report

    private func saveReport() {
        guard let result = diagnosisResult else { return }

        isSaving = true

        Task {
            // 使用适配器创建统一报告
            let unifiedReport = ReportAdapters.createEngineReport(from: result)
            _ = reportService.createReport(unifiedReport)

            await MainActor.run {
                isSaving = false
                showSaveConfirmation = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewState {
        case .guide:
            EngineGuideSection(onStart: { viewState = .recording })
        case .recording:
            EngineRecordingSection(
                recordingService: recordingService,
                onComplete: { url in
                    recordedURL = url
                    viewState = .confirm
                }
            )
        case .confirm:
            EngineConfirmSection(
                onAnalyze: {
                    if let url = recordedURL {
                        analyzeAudio(url)
                    }
                },
                onRetake: {
                    recordedURL = nil
                    viewState = .recording
                }
            )
        case .analyzing:
            EngineAnalyzingSection(
                progress: aiService.analysisProgress,
                currentStep: aiService.currentStep
            )
        case .result:
            if let result = diagnosisResult {
                EngineResultSection(
                    result: result,
                    showDetail: $showDetail,
                    onRetest: {
                        recordedURL = nil
                        diagnosisResult = nil
                        viewState = .recording
                    },
                    onDone: { dismiss() }
                )
            }
        case .error:
            EngineErrorSection(
                message: errorMessage ?? "分析失败",
                onRetry: {
                    errorMessage = nil
                    if let url = recordedURL {
                        analyzeAudio(url)
                    } else {
                        viewState = .guide
                    }
                },
                onCancel: { viewState = .guide }
            )
        }
    }

    private func analyzeAudio(_ url: URL) {
        viewState = .analyzing

        Task {
            do {
                let result = try await aiService.analyzeAudio(at: url)
                await MainActor.run {
                    diagnosisResult = result
                    viewState = .result
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    viewState = .error
                }
            }
        }
    }
}

// MARK: - Guide Section

struct EngineGuideSection: View {
    let onStart: () -> Void
    @StateObject private var classifier = EngineSoundClassifier()

    private let detectableFaults = [
        ("敲缸", "1000-4000Hz"),
        ("皮带异响", "2000-8000Hz"),
        ("轴承磨损", "500-3000Hz"),
        ("气门异响", "800-2500Hz"),
        ("缺缸", "100-600Hz")
    ]

    var body: some View {
        Section {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))

                    Text("请将手机靠近发动机舱")
                        .font(.title3)
                        .foregroundColor(.white)

                    Text("保持环境安静，发动机怠速运转")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                // 可检测问题类型
                VStack(alignment: .leading, spacing: 12) {
                    Text("可检测 \(detectableFaults.count) 种常见问题")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(detectableFaults, id: \.0) { fault, freq in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.cyan.opacity(0.6))
                                    .frame(width: 6, height: 6)
                                Text(fault)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // 模型状态
                HStack(spacing: 8) {
                    Circle()
                        .fill(modelStatusColor)
                        .frame(width: 8, height: 8)
                    Text(modelStatusText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                ICButton(
                    title: "开始录音",
                    icon: "mic.fill",
                    style: .primary,
                    action: onStart
                )
                .disabled(classifier.isLoading)
            }
            .padding(.vertical, 40)
        }
    }

    private var modelStatusColor: Color {
        if classifier.isLoading {
            return .orange
        } else if classifier.isModelLoaded {
            return .green
        } else if classifier.errorMessage != nil {
            return .red
        } else {
            return .gray
        }
    }

    private var modelStatusText: String {
        if classifier.isLoading {
            return "AI模型加载中..."
        } else if classifier.isModelLoaded {
            return "AI模型就绪"
        } else if let error = classifier.errorMessage {
            return "模型加载失败: \(error)"
        } else {
            return "正在初始化..."
        }
    }
}

// MARK: - Recording Section

struct EngineRecordingSection: View {
    let recordingService: AudioRecordingService
    let onComplete: (URL) -> Void

    @State private var elapsedTime: Int = 0
    @State private var timer: Timer?
    @State private var waveformData: [CGFloat] = Array(repeating: 0.1, count: 30)
    @State private var waveformTimer: Timer?

    private var recordingProgress: Double {
        if case .recording(let progress, _) = recordingService.state {
            return progress
        }
        return 0
    }

    var body: some View {
        Section {
            VStack(spacing: 24) {
                Spacer()

                // 脉动圆点 + 时间
                VStack(spacing: 16) {
                    PulsingDot()

                    Text("聆听中... \(elapsedTime)s")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                // 实时波形
                HStack(spacing: 3) {
                    ForEach(0..<waveformData.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 6, height: max(4, waveformData[index] * 60))
                    }
                }
                .frame(height: 60)
                .animation(.easeInOut(duration: 0.05), value: waveformData)

                // 进度条
                VStack(spacing: 8) {
                    ProgressView(value: recordingProgress)
                        .progressViewStyle(.linear)
                        .tint(.red)

                    HStack {
                        Spacer()
                        Text("\(Int(recordingProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            startRecording()
            startTimer()
            startWaveformUpdates()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            waveformTimer?.invalidate()
            waveformTimer = nil
        }
        .onChange(of: recordingService.state) { newState in
            handleStateChange(newState)
        }
    }

    private func startRecording() {
        Task {
            do {
                try await recordingService.startRecording()
            } catch {
                // 错误会在 state 更新时处理
            }
        }
    }

    private func startTimer() {
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    private func startWaveformUpdates() {
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateWaveform()
        }
    }

    @MainActor
    private func updateWaveform() {
        let levels = recordingService.audioLevels
        guard !levels.isEmpty else { return }

        let normalized = levels.map { level -> CGFloat in
            let clamped = max(-60, min(0, level))
            return CGFloat((clamped + 60) / 60)
        }

        waveformData = normalized.count >= 30
            ? Array(normalized.suffix(30))
            : Array(repeating: 0.1, count: 30 - normalized.count) + normalized
    }

    private func handleStateChange(_ state: RecordingState) {
        switch state {
        case .completed(let url):
            timer?.invalidate()
            timer = nil
            waveformTimer?.invalidate()
            waveformTimer = nil
            onComplete(url)
        default:
            break
        }
    }
}

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    .scaleEffect(isPulsing ? 2.5 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Confirm Section

struct EngineConfirmSection: View {
    let onAnalyze: () -> Void
    let onRetake: () -> Void

    var body: some View {
        Section {
            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("录音完成")
                    .font(.title2)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.vertical, 60)
        }

        Section {
            ICButton(
                title: "开始分析",
                icon: "play.fill",
                style: .primary,
                action: onAnalyze
            )

            ICButton(
                title: "重新录制",
                icon: "arrow.counterclockwise",
                style: .secondary,
                action: onRetake
            )
        }
    }
}

// MARK: - Analyzing Section

struct EngineAnalyzingSection: View {
    let progress: Double
    let currentStep: String

    private var steps: [String] {
        ["提取音频特征", "匹配故障模型", "生成诊断报告"]
    }

    private var currentStepIndex: Int {
        switch progress {
        case 0..<0.4: return 0
        case 0.4..<0.75: return 1
        default: return 2
        }
    }

    var body: some View {
        Section {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 24) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        HStack(spacing: 12) {
                            if index < currentStepIndex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if index == currentStepIndex {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                            }

                            Text(steps[index])
                                .font(.body)
                                .foregroundColor(index <= currentStepIndex ? .white : .gray)

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical, 80)
        }
    }
}

// MARK: - Result Section

struct EngineResultSection: View {
    let result: EngineDiagnosisResult
    @Binding var showDetail: Bool
    let onRetest: () -> Void
    let onDone: () -> Void

    private var statusColor: Color {
        switch result.severity {
        case .normal: return .green
        case .minor: return .cyan
        case .moderate: return .orange
        case .severe: return .red
        }
    }

    private var statusIcon: String {
        switch result.severity {
        case .normal: return "checkmark.circle.fill"
        case .minor: return "info.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .severe: return "xmark.octagon.fill"
        }
    }

    var body: some View {
        // 核心结论 - 大图标 + 结论
        Section {
            VStack(spacing: 16) {
                Image(systemName: statusIcon)
                    .font(.system(size: 64))
                    .foregroundColor(statusColor)

                Text(result.faultType.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)

                if result.severity != .normal {
                    Text(result.severity.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }

        // 前3种可能问题
        if !result.top3Faults.isEmpty {
            Section("可能的故障类型") {
                ForEach(result.top3Faults) { faultProb in
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(faultProb.faultType == result.faultType ? Color.red.opacity(0.8) : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                            Text(faultProb.faultType.rawValue)
                                .font(.subheadline)
                                .foregroundColor(faultProb.faultType == result.faultType ? .white : .gray)
                        }

                        Spacer()

                        Text(faultProb.formattedProbability)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(faultProb.faultType == result.faultType ? statusColor : .gray)
                    }
                }
            }
        }

        // 展开详情按钮
        Section {
            Button {
                withAnimation {
                    showDetail.toggle()
                }
            } label: {
                HStack {
                    Text(showDetail ? "收起详情" : "查看详情")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Image(systemName: showDetail ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
        }

        // 详情内容
        if showDetail {
            if !result.faultType.description.isEmpty {
                Section("说明") {
                    Text(result.faultType.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            if !result.recommendedAction.isEmpty {
                Section("建议措施") {
                    Text(result.recommendedAction)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            // 关键频谱特征
            Section("音频特征") {
                HStack {
                    Text("主导频率")
                    Spacer()
                    Text("\(Int(result.spectrumData.dominantFrequency))Hz")
                        .foregroundColor(.yellow)
                        .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Text("频谱能量")
                    Spacer()
                    Text(String(format: "%.2f", result.spectrumData.totalEnergy))
                        .foregroundColor(.gray)
                        .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Text("故障频段能量")
                    Spacer()
                    let faultEnergy = result.spectrumData.energyInRange(result.faultType.frequencyRange)
                    Text(String(format: "%.2f", faultEnergy))
                        .foregroundColor(.red)
                        .font(.system(.body, design: .monospaced))
                }
            }

            // 频谱数据可视化
            if !result.spectrumData.magnitudes.isEmpty {
                Section("频谱分析") {
                    SpectrumChart(
                        frequencies: result.spectrumData.frequencies,
                        magnitudes: result.spectrumData.magnitudes,
                        faultType: result.faultType
                    )
                }
            }
        }

        // 操作按钮
        Section {
            Button {
                onRetest()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("重新检测")
                    Spacer()
                }
            }
            .foregroundColor(.white)

            Button {
                onDone()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("完成")
                    Spacer()
                }
            }
            .foregroundColor(.green)
        }
    }
}

// MARK: - Spectrum Chart

struct SpectrumChart: View {
    let frequencies: [Double]
    let magnitudes: [Double]
    let faultType: EngineFaultType

    private var maxMagnitude: Double {
        magnitudes.max() ?? 1.0
    }

    private var displayRange: ClosedRange<Double> {
        0...8000
    }

    private var filteredData: [(freq: Double, mag: Double)] {
        let data = Array(zip(frequencies, magnitudes))
        return data.filter { displayRange.contains($0.0) }
    }

    var body: some View {
        VStack(spacing: 8) {
            // 频谱图
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let data = filteredData
                let barWidth = max(1, width / CGFloat(data.count))

                ZStack {
                    // 背景网格线
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            HStack {
                                Spacer()
                            }
                            .frame(height: height / 4)
                            .background(i > 0 ? Color.white.opacity(0.03) : Color.clear)
                        }
                    }

                    // 故障特征频率范围高亮
                    FaultRangeHighlight(
                        width: width,
                        height: height,
                        data: data,
                        range: faultType.frequencyRange
                    )

                    // 频谱柱状图
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(0..<data.count, id: \.self) { index in
                            let magnitude = data[index].mag
                            let normalizedHeight = magnitude / maxMagnitude
                            let isInFaultRange = faultType.frequencyRange.contains(data[index].freq)

                            RoundedRectangle(cornerRadius: 1)
                                .fill(isInFaultRange ? Color.red.opacity(0.8) : Color.cyan.opacity(0.5))
                                .frame(width: barWidth, height: max(2, CGFloat(normalizedHeight) * height))
                        }
                    }

                    // 主导频率标记
                    if let dominantIndex = data.indices.max(by: { data[$0].mag < data[$1].mag }) {
                        let dominantFreq = data[dominantIndex].freq
                        let xPosition = CGFloat(dominantFreq / displayRange.upperBound) * width

                        VStack {
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: 1, height: height)
                            Text("\(Int(dominantFreq))Hz")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                        }
                        .position(x: xPosition, y: height / 2)
                    }
                }
            }
            .frame(height: 140)

            // X轴频率标注
            HStack {
                Text("0Hz")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Spacer()
                Text("2k")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Spacer()
                Text("4k")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Spacer()
                Text("6k")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Spacer()
                Text("8kHz")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            // 图例
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 6, height: 6)
                    Text("故障频段 (\(Int(faultType.frequencyRange.lowerBound))-\(Int(faultType.frequencyRange.upperBound))Hz)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.cyan.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text("正常频段")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 2)
                    Text("主导频率")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct FaultRangeHighlight: View {
    let width: CGFloat
    let height: CGFloat
    let data: [(freq: Double, mag: Double)]
    let range: ClosedRange<Double>

    var body: some View {
        if let minIndex = data.firstIndex(where: { range.contains($0.freq) }),
           let maxIndex = data.lastIndex(where: { range.contains($0.freq) }) {
            let startX = CGFloat(minIndex) / CGFloat(data.count) * width
            let endX = CGFloat(maxIndex) / CGFloat(data.count) * width

            Rectangle()
                .fill(Color.red.opacity(0.08))
                .frame(width: endX - startX, height: height)
                .position(x: startX + (endX - startX) / 2, y: height / 2)
        }
    }
}

// MARK: - Error Section

struct EngineErrorSection: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Section {
            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text("分析失败")
                    .font(.title2)
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(.vertical, 60)
        }

        Section {
            ICButton(
                title: "重试",
                icon: "arrow.counterclockwise",
                style: .primary,
                action: onRetry
            )

            ICButton(
                title: "返回",
                style: .secondary,
                action: onCancel
            )
        }
    }
}

// MARK: - Share Sheet

struct EngineEarShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("Engine Ear View V2") {
    EngineEarViewV2()
}

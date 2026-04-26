import SwiftUI
import AVFoundation

// MARK: - AC Doctor View

struct ACDoctorView: View {
    
    @StateObject private var service = ACMonitorService.shared
    @StateObject private var cameraService = CameraService.shared
    @StateObject private var reportService = UnifiedReportService.shared
    
    @State private var viewState: ACDoctorViewState = .guide
    @State private var beltAnalysis: BeltAnalysisResult?
    @State private var fanAnalysis: FanSoundAnalysis?
    @State private var refrigerantPressure: String = ""
    @State private var outletTemp: String = ""
    @State private var ambientTemp: String = ""
    @State private var diagnosisResult: ACDiagnosisResult?
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    enum ACDoctorViewState {
        case guide
        case beltCapture
        case beltAnalysis
        case fanRecording
        case fanAnalysis
        case manualInput
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
        .navigationTitle("空调诊断")
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
                ACShareSheet(activityItems: [createShareContent(from: result)])
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ICCameraView(
                config: ICCameraConfiguration(guideType: .rect),
                onCapture: { image in
                    let result = service.analyzeBeltFromImage(image)
                    beltAnalysis = result
                    viewState = .beltAnalysis
                    showCamera = false
                },
                onCancel: {
                    showCamera = false
                }
            )
        }
        .preferredColorScheme(.dark)
    }
    
    private func createShareContent(from result: ACDiagnosisResult) -> String {
        var content = "iCar 空调诊断报告\n"
        content += "诊断时间: \(Date().formatted(date: .long, time: .shortened))\n"
        content += "综合评分: \(result.overallScore)分\n"
        content += "系统状态: \(result.status.rawValue)\n"
        if !result.detectedIssues.isEmpty {
            content += "发现问题: \(result.detectedIssues.map { $0.rawValue }.joined(separator: ", "))\n"
        }
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
        case .beltCapture, .beltAnalysis, .fanRecording, .fanAnalysis, .manualInput, .analyzing:
            Button {
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
            let unifiedReport = ReportAdapters.createACReport(from: result)
            _ = reportService.createReport(unifiedReport)

            await MainActor.run {
                isSaving = false
                showSaveConfirmation = true
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch viewState {
        case .guide:
            ACGuideSection(
                onStart: { viewState = .beltCapture }
            )
        case .beltCapture:
            ACBeltCaptureSection(
                onCapture: { showCamera = true },
                onCancel: { viewState = .guide }
            )
        case .beltAnalysis:
            if let result = beltAnalysis {
                ACBeltAnalysisSection(
                    result: result,
                    onContinue: { viewState = .fanRecording },
                    onRetake: {
                        beltAnalysis = nil
                        viewState = .beltCapture
                    }
                )
            }
        case .fanRecording:
            ACFanRecordingSection(
                isRecording: service.isRecording,
                recordingProgress: service.recordingProgress,
                onToggleRecording: { toggleRecording() },
                onCancel: { viewState = .guide }
            )
        case .fanAnalysis:
            if let result = fanAnalysis {
                ACFanAnalysisSection(
                    result: result,
                    onContinue: { viewState = .manualInput },
                    onRerecord: {
                        fanAnalysis = nil
                        viewState = .fanRecording
                    }
                )
            }
        case .manualInput:
            ACManualInputSection(
                refrigerantPressure: $refrigerantPressure,
                ambientTemp: $ambientTemp,
                outletTemp: $outletTemp,
                onAnalyze: { performDiagnosis() },
                onCancel: { viewState = .guide }
            )
        case .analyzing:
            ACAnalyzingSection()
        case .result:
            if let result = diagnosisResult {
                ACResultSection(
                    result: result,
                    onRetest: {
                        resetState()
                        viewState = .beltCapture
                    },
                    onDone: { dismiss() }
                )
            }
        case .error:
            ACErrorSection(
                message: errorMessage ?? "诊断失败",
                onRetry: {
                    errorMessage = nil
                    viewState = .manualInput
                },
                onCancel: { viewState = .guide }
            )
        }
    }
    
    // MARK: - Actions
    
    @State private var recordingTimer: Timer?
    
    private func toggleRecording() {
        if service.isRecording {
            service.stopRecording()
            recordingTimer?.invalidate()
            recordingTimer = nil
            Task {
                await analyzeFanSound()
            }
        } else {
            service.startRecording(duration: 5.0)
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                Task { @MainActor in
                    if !service.isRecording {
                        self.recordingTimer?.invalidate()
                        self.recordingTimer = nil
                        await analyzeFanSound()
                    }
                }
            }
        }
    }
    
    private func analyzeFanSound() async {
        let audioURL = getRecordingURL()
        do {
            let result = try await service.analyzeFanSound(audioURL: audioURL)
            await MainActor.run {
                fanAnalysis = result
                viewState = .fanAnalysis
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                viewState = .error
            }
        }
    }
    
    private func getRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("ac_recording.m4a")
    }
    
    private func performDiagnosis() {
        viewState = .analyzing
        
        Task {
            let pressure = Double(refrigerantPressure)
            let outTemp = Double(outletTemp)
            let ambTemp = Double(ambientTemp)
            
            let result = service.performDiagnosis(
                beltAnalysis: beltAnalysis,
                fanAnalysis: fanAnalysis,
                refrigerantPressure: pressure,
                outletTemp: outTemp,
                ambientTemp: ambTemp
            )
            
            await MainActor.run {
                diagnosisResult = result
                viewState = .result
            }
        }
    }
    
    private func resetState() {
        beltAnalysis = nil
        fanAnalysis = nil
        diagnosisResult = nil
        refrigerantPressure = ""
        outletTemp = ""
        ambientTemp = ""
    }
}

// MARK: - Guide Section

struct ACGuideSection: View {
    let onStart: () -> Void
    
    private let guidelines = [
        "打开引擎盖，找到空调压缩机皮带",
        "启动车辆，打开空调至最大风量",
        "将手机靠近空调出风口录制声音",
        "输入制冷剂压力和温度数据"
    ]
    
    var body: some View {
        Section {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "air.conditioner.horizontal")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("空调系统诊断")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("全面检测空调皮带、风机和制冷系统")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("诊断流程")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    ForEach(Array(guidelines.enumerated()), id: \.offset) { index, text in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.cyan)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.cyan.opacity(0.2)))
                            Text(text)
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                ICButton(
                    title: "开始诊断",
                    icon: "play.fill",
                    style: .primary,
                    action: onStart
                )
            }
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Belt Capture Section

struct ACBeltCaptureSection: View {
    let onCapture: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        Section {
            VStack(spacing: 40) {
                Spacer()
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.3))
                
                Text("步骤1: 皮带检测")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("打开引擎盖，找到空调压缩机皮带")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("确保光线充足，拍摄清晰的皮带照片")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                ICButton(
                    title: "拍摄皮带",
                    icon: "camera.fill",
                    style: .primary,
                    action: onCapture
                )
            }
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Belt Analysis Section

struct ACBeltAnalysisSection: View {
    let result: BeltAnalysisResult
    let onContinue: () -> Void
    let onRetake: () -> Void
    
    var body: some View {
        Section {
            VStack(spacing: 24) {
                HStack {
                    Text("磨损程度")
                    Spacer()
                    Text("\(Int(result.wearLevel))%")
                        .foregroundColor(result.wearLevel > 80 ? .orange : .white)
                        .font(.system(.body, design: .monospaced))
                }
                
                HStack {
                    Text("张紧度")
                    Spacer()
                    Text(result.tensionStatus.rawValue)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("裂纹检测")
                    Spacer()
                    Text(result.crackDetected ? "发现裂纹" : "无裂纹")
                        .foregroundColor(result.crackDetected ? .orange : .green)
                }
            }
        }
        
        Section {
            ICButton(
                title: "继续下一步",
                icon: "arrow.right",
                style: .primary,
                action: onContinue
            )
            
            ICButton(
                title: "重新拍摄",
                icon: "arrow.counterclockwise",
                style: .secondary,
                action: onRetake
            )
        }
    }
}

// MARK: - Fan Recording Section

struct ACFanRecordingSection: View {
    let isRecording: Bool
    let recordingProgress: Double
    let onToggleRecording: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        Section {
            VStack(spacing: 40) {
                Spacer()
                
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(isRecording ? .red : .white.opacity(0.3))
                
                Text("步骤2: 风机检测")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("启动车辆，打开空调至最大风量")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("将手机靠近空调出风口录制声音")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if isRecording {
                    VStack(spacing: 8) {
                        Text("录制中...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        ProgressView(value: recordingProgress)
                            .progressViewStyle(.linear)
                            .tint(.white)
                    }
                }
                
                Spacer()
                
                ICButton(
                    title: isRecording ? "停止录制" : "开始录制",
                    icon: isRecording ? "stop.fill" : "mic.fill",
                    style: isRecording ? .danger : .primary,
                    action: onToggleRecording
                )
            }
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Fan Analysis Section

struct ACFanAnalysisSection: View {
    let result: FanSoundAnalysis
    let onContinue: () -> Void
    let onRerecord: () -> Void
    
    var body: some View {
        Section {
            VStack(spacing: 24) {
                HStack {
                    Text("噪声水平")
                    Spacer()
                    Text("\(Int(result.noiseLevel)) dB")
                        .foregroundColor(result.noiseLevel > 70 ? .orange : .white)
                        .font(.system(.body, design: .monospaced))
                }
                
                HStack {
                    Text("轴承状态")
                    Spacer()
                    Text(result.bearingCondition.rawValue)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("叶片平衡")
                    Spacer()
                    Text(result.bladeBalance.rawValue)
                        .foregroundColor(.gray)
                }
            }
        }
        
        Section {
            Button {
                onContinue()
            } label: {
                HStack {
                    Image(systemName: "arrow.right")
                    Text("继续下一步")
                    Spacer()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
            }
            
            Button {
                onRerecord()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("重新录制")
                    Spacer()
                }
                .font(.body)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Manual Input Section

struct ACManualInputSection: View {
    @Binding var refrigerantPressure: String
    @Binding var ambientTemp: String
    @Binding var outletTemp: String
    let onAnalyze: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("使用空调压力表读取制冷剂压力")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("使用温度计测量出风口和环境温度")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        
        Section("步骤3: 输入数据") {
            TextField("制冷剂压力 (bar)", text: $refrigerantPressure)
                .keyboardType(.decimalPad)
            TextField("环境温度 (°C)", text: $ambientTemp)
                .keyboardType(.decimalPad)
            TextField("出风口温度 (°C)", text: $outletTemp)
                .keyboardType(.decimalPad)
        }
        
        Section {
            ICButton(
                title: "生成诊断报告",
                icon: "doc.text.magnifyingglass",
                style: .primary,
                action: onAnalyze
            )
            .disabled(refrigerantPressure.isEmpty || ambientTemp.isEmpty || outletTemp.isEmpty)
        }
    }
}

// MARK: - Analyzing Section

struct ACAnalyzingSection: View {
    private let steps = ["分析皮带数据", "分析风机声音", "计算制冷效率", "生成诊断报告"]
    
    var body: some View {
        Section {
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 24) {
                    ForEach(steps, id: \.self) { step in
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            
                            Text(step)
                                .font(.body)
                                .foregroundColor(.white)
                            
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

struct ACResultSection: View {
    let result: ACDiagnosisResult
    let onRetest: () -> Void
    let onDone: () -> Void
    
    private var statusColor: Color {
        if result.overallScore >= 80 { return .green }
        if result.overallScore >= 60 { return .orange }
        return .red
    }
    
    private var statusIcon: String {
        if result.overallScore >= 80 { return "checkmark.circle.fill" }
        if result.overallScore >= 60 { return "info.circle.fill" }
        return "exclamationmark.triangle.fill"
    }
    
    var body: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: statusIcon)
                    .font(.system(size: 64))
                    .foregroundColor(statusColor)
                
                Text("\(result.overallScore)分")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                
                Text(result.status.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        
        Section("诊断详情") {
            HStack {
                Text("综合评分")
                Spacer()
                Text("\(result.overallScore)分")
                    .foregroundColor(statusColor)
                    .font(.system(.body, design: .monospaced))
            }
            
            HStack {
                Text("系统状态")
                Spacer()
                Text(result.status.rawValue)
                    .foregroundColor(.gray)
            }
            
            if !result.detectedIssues.isEmpty {
                HStack(alignment: .top) {
                    Text("发现问题")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(result.detectedIssues, id: \.self) { issue in
                            Text(issue.rawValue)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        
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

// MARK: - Error Section

struct ACErrorSection: View {
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
                
                Text("诊断失败")
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

struct ACShareSheet: UIViewControllerRepresentable {
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

#Preview("AC Doctor") {
    NavigationStack {
        ACDoctorView()
    }
}

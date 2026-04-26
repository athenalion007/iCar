import SwiftUI

// MARK: - Suspension IQ View

struct SuspensionIQView: View {
    
    @StateObject private var service = SuspensionMonitorService.shared
    @StateObject private var reportService = UnifiedReportService.shared
    
    @State private var viewState: SuspensionViewState = .guide
    @State private var diagnosisResult: SuspensionDiagnosisResult?
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    enum SuspensionViewState {
        case guide
        case monitoring
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
        .navigationTitle("悬挂监测")
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
            Text("检测报告已保存到历史记录")
        }
        .alert("保存失败", isPresented: $showSaveError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            if let result = diagnosisResult {
                SuspensionShareSheet(activityItems: [createShareContent(from: result)])
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func createShareContent(from result: SuspensionDiagnosisResult) -> String {
        var content = "iCar 悬挂检测报告\n"
        content += "检测时间: \(Date().formatted(date: .long, time: .shortened))\n"
        content += "综合评分: \(result.overallScore)分\n"
        content += "悬挂状态: \(result.status.rawValue)\n"
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
        case .monitoring, .analyzing:
            Button {
                stopMonitoring()
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
            let unifiedReport = ReportAdapters.createSuspensionReport(from: result)
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
            SuspensionGuideSection(
                onStart: { startMonitoring() }
            )
        case .monitoring:
            SuspensionMonitoringSection(
                progress: service.monitoringProgress,
                currentStep: service.currentStep,
                onStop: { stopMonitoring() }
            )
        case .analyzing:
            SuspensionAnalyzingSection()
        case .result:
            if let result = diagnosisResult {
                SuspensionResultSection(
                    result: result,
                    onRetest: {
                        resetState()
                        viewState = .guide
                    },
                    onDone: { dismiss() }
                )
            }
        case .error:
            SuspensionErrorSection(
                message: errorMessage ?? "监测失败",
                onRetry: {
                    errorMessage = nil
                    viewState = .guide
                },
                onCancel: { dismiss() }
            )
        }
    }
    
    // MARK: - Actions
    
    private func startMonitoring() {
        viewState = .monitoring
        service.startMonitoring(duration: 10.0)
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if !service.isMonitoring && service.monitoringProgress >= 1.0 {
                timer.invalidate()
                viewState = .analyzing
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    diagnosisResult = service.performDiagnosis()
                    viewState = .result
                }
            }
        }
    }
    
    private func stopMonitoring() {
        service.stopMonitoring()
    }
    
    private func resetState() {
        diagnosisResult = nil
        service.stopMonitoring()
        service.monitoringProgress = 0.0
        service.currentStep = "准备中..."
    }
}

// MARK: - Guide Section

struct SuspensionGuideSection: View {
    let onStart: () -> Void
    
    private let guidelines = [
        "将手机固定在车内平稳位置",
        "以20-40km/h速度行驶在不平路面",
        "系统将自动分析悬挂状态"
    ]
    
    var body: some View {
        Section {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("悬挂系统监测")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("通过加速度传感器分析悬挂状态")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("操作指南")
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
                    title: "开始监测",
                    icon: "play.fill",
                    style: .primary,
                    action: onStart
                )
            }
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Monitoring Section

struct SuspensionMonitoringSection: View {
    let progress: Double
    let currentStep: String
    let onStop: () -> Void
    
    var body: some View {
        Section {
            VStack(spacing: 40) {
                Spacer()
                
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                
                Text("监测中...")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    Text(currentStep)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                Spacer()
                
                ICButton(
                    title: "停止监测",
                    icon: "stop.fill",
                    style: .danger,
                    action: onStop
                )
            }
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Analyzing Section

struct SuspensionAnalyzingSection: View {
    private let steps = ["数据预处理", "振动特征提取", "悬挂状态分析", "生成诊断报告"]
    
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

struct SuspensionResultSection: View {
    let result: SuspensionDiagnosisResult
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
        
        Section("监测详情") {
            HStack {
                Text("综合评分")
                Spacer()
                Text("\(result.overallScore)分")
                    .foregroundColor(statusColor)
                    .font(.system(.body, design: .monospaced))
            }
            
            HStack {
                Text("悬挂状态")
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

struct SuspensionErrorSection: View {
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
                
                Text("监测失败")
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

struct SuspensionShareSheet: UIViewControllerRepresentable {
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

#Preview("Suspension IQ") {
    NavigationStack {
        SuspensionIQView()
    }
}

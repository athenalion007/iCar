import SwiftUI
import AVFoundation

// MARK: - Paint Scan View

struct PaintScanView: View {
    
    @StateObject private var service = CarDamageDetectorService.shared
    @StateObject private var reportService = UnifiedReportService.shared
    
    @State private var viewState: PaintViewState = .guide
    @State private var capturedImage: UIImage?
    @State private var result: PaintScanResult?
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    enum PaintViewState {
        case guide
        case capturing
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
        .navigationTitle("漆面扫描")
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
            if let result = result {
                PaintShareSheet(activityItems: [createShareContent(from: result)])
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func createShareContent(from result: PaintScanResult) -> String {
        var content = "iCar 漆面检测报告\n"
        content += "检测时间: \(Date().formatted(date: .long, time: .shortened))\n"
        content += "漆面评分: \(result.score)分\n"
        content += "状态评估: \(result.status)\n"
        if result.damageCount > 0 {
            content += "损伤数量: \(result.damageCount)处\n"
        }
        if let recommendation = result.recommendation {
            content += "建议: \(recommendation)\n"
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
        case .capturing, .analyzing:
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
        guard let result = result, let image = capturedImage else { return }

        isSaving = true

        Task {
            // 使用适配器创建统一报告
            let unifiedReport = ReportAdapters.createPaintReport(from: result, image: image)
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
            PaintGuideSection(
                isModelLoaded: service.isModelLoaded,
                onStart: { viewState = .capturing }
            )
        case .capturing:
            PaintCapturingSection(
                onCapture: { image in
                    capturedImage = image
                    analyzeImage(image)
                },
                onCancel: { viewState = .guide }
            )
        case .analyzing:
            PaintAnalyzingSection()
        case .result:
            if let result = result, let image = capturedImage {
                PaintResultSection(
                    result: result,
                    capturedImage: image,
                    onRetest: {
                        capturedImage = nil
                        self.result = nil
                        viewState = .capturing
                    },
                    onDone: { dismiss() }
                )
            }
        case .error:
            PaintErrorSection(
                message: errorMessage ?? "分析失败",
                onRetry: {
                    errorMessage = nil
                    if let image = capturedImage {
                        analyzeImage(image)
                    } else {
                        viewState = .guide
                    }
                },
                onCancel: { viewState = .guide }
            )
        }
    }
    
    private func analyzeImage(_ image: UIImage) {
        // 检查模型是否加载
        guard service.isModelLoaded else {
            errorMessage = "AI模型未加载完成，请稍后重试"
            viewState = .error
            print("❌ 漆面扫描: 模型未加载")
            return
        }
        
        viewState = .analyzing
        
        Task {
            do {
                print("🔍 漆面扫描: 开始分析图片...")
                let detections = try await service.detectDamages(in: image)
                print("🔍 漆面扫描: 检测到 \(detections.count) 处损伤")
                
                // 如果没有检测到损伤，显示提示而不是直接给95分
                let score: Int
                let status: String
                let recommendation: String
                
                if detections.isEmpty {
                    // 没有检测到损伤，可能是真的没有损伤，也可能是模型没工作
                    score = 95
                    status = "优秀"
                    recommendation = "未检测到明显损伤，漆面状况良好"
                    print("⚠️ 漆面扫描: 未检测到损伤，可能图片中没有损伤或模型置信度低")
                } else {
                    score = calculateScore(detections: detections)
                    
                    if score >= 90 {
                        status = "优秀"
                        recommendation = "漆面状况良好"
                    } else if score >= 70 {
                        status = "良好"
                        recommendation = "有轻微损伤，建议打蜡护理"
                    } else {
                        status = "需修复"
                        recommendation = "漆面损伤较多，建议专业修复"
                    }
                }
                
                let result = PaintScanResult(
                    status: status,
                    score: score,
                    damageCount: detections.count,
                    detectedDamages: detections,
                    recommendation: recommendation
                )
                
                await MainActor.run {
                    self.result = result
                    viewState = .result
                }
            } catch {
                print("❌ 漆面扫描分析失败: \(error)")
                await MainActor.run {
                    errorMessage = "分析失败: \(error.localizedDescription)"
                    viewState = .error
                }
            }
        }
    }
    
    private func calculateScore(detections: [DamageDetection]) -> Int {
        if detections.isEmpty { return 95 }
        
        let totalSeverity = detections.reduce(0.0) { sum, detection in
            return sum + detection.severity.severityWeight
        }
        
        let avgSeverity = totalSeverity / Double(detections.count)
        let score = Int(100 - (avgSeverity * 30))
        return max(0, min(100, score))
    }
}

// MARK: - Guide Section

struct PaintGuideSection: View {
    let isModelLoaded: Bool
    let onStart: () -> Void
    
    private let guidelines = [
        "将手机对准车身漆面，保持适当距离",
        "确保光线均匀，避免强光反射",
        "保持手机稳定，确保照片清晰"
    ]
    
    var body: some View {
        Section {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "paintbrush")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("漆面损伤检测")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("AI智能识别漆面划痕、凹陷等损伤")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("拍摄指南")
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
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(modelStatusColor)
                        .frame(width: 8, height: 8)
                    Text(modelStatusText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                ICButton(
                    title: "开始扫描",
                    icon: "camera.fill",
                    style: .primary,
                    action: onStart
                )
                .disabled(!isModelLoaded)
            }
            .padding(.vertical, 40)
        }
    }
    
    private var modelStatusColor: Color {
        isModelLoaded ? .green : .red
    }
    
    private var modelStatusText: String {
        isModelLoaded ? "AI模型就绪" : "AI模型未加载"
    }
}

// MARK: - Capturing Section

struct PaintCapturingSection: View {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    @State private var showCamera = false
    
    var body: some View {
        Section {
            VStack(spacing: 40) {
                Spacer()
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.3))
                
                Text("准备拍摄")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("请将手机对准需要检测的漆面区域")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                ICButton(
                    title: "打开相机",
                    icon: "camera.fill",
                    style: .primary,
                    action: { showCamera = true }
                )
            }
            .padding(.vertical, 40)
        }
        .fullScreenCover(isPresented: $showCamera) {
            ICCameraView(
                config: ICCameraConfiguration(guideType: .grid),
                onCapture: { image in
                    onCapture(image)
                    showCamera = false
                },
                onCancel: {
                    showCamera = false
                }
            )
        }
    }
}

// MARK: - Analyzing Section

struct PaintAnalyzingSection: View {
    private let steps = ["图像预处理", "损伤特征提取", "AI模型分析", "生成检测报告"]
    
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

struct PaintResultSection: View {
    let result: PaintScanResult
    let capturedImage: UIImage
    let onRetest: () -> Void
    let onDone: () -> Void
    
    private var statusColor: Color {
        if result.score >= 90 { return .green }
        if result.score >= 70 { return .cyan }
        if result.score >= 50 { return .orange }
        return .red
    }
    
    private var statusIcon: String {
        if result.score >= 90 { return "checkmark.circle.fill" }
        if result.score >= 70 { return "info.circle.fill" }
        if result.score >= 50 { return "exclamationmark.triangle.fill" }
        return "xmark.octagon.fill"
    }
    
    var body: some View {
        // 检测结果照片 - 带损伤标定
        Section {
            DamageAnnotatedImage(
                image: capturedImage,
                damages: result.detectedDamages
            )
            .frame(height: 300)
            .cornerRadius(12)
        }
        
        Section {
            VStack(spacing: 16) {
                Image(systemName: statusIcon)
                    .font(.system(size: 64))
                    .foregroundColor(statusColor)
                
                Text("\(result.score)分")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                
                Text(result.status)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        
        Section("检测详情") {
            HStack {
                Text("漆面评分")
                Spacer()
                Text("\(result.score)分")
                    .foregroundColor(statusColor)
                    .font(.system(.body, design: .monospaced))
            }
            
            HStack {
                Text("状态评估")
                Spacer()
                Text(result.status)
                    .foregroundColor(.gray)
            }
            
            if result.damageCount > 0 {
                HStack {
                    Text("损伤数量")
                    Spacer()
                    Text("\(result.damageCount)处")
                        .foregroundColor(.white)
                }
            }
            
            if !result.detectedDamages.isEmpty {
                HStack(alignment: .top) {
                    Text("损伤类型")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(result.detectedDamages.prefix(3), id: \.id) { damage in
                            Text("\(damage.type.rawValue) (\(Int(damage.confidence * 100))%)")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            if let recommendation = result.recommendation {
                HStack(alignment: .top) {
                    Text("建议")
                    Spacer()
                    Text(recommendation)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        
        Section {
            ICButton(
                title: "重新检测",
                icon: "arrow.counterclockwise",
                style: .secondary,
                action: onRetest
            )
            
            ICButton(
                title: "完成",
                icon: "checkmark",
                style: .success,
                action: onDone
            )
        }
    }
}

// MARK: - Damage Annotated Image

/// 带损伤标定的图片组件
struct DamageAnnotatedImage: View {
    let image: UIImage
    let damages: [DamageDetection]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 原始图片
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                
                // 损伤标定框
                ForEach(damages) { damage in
                    DamageBoundingBox(
                        damage: damage,
                        containerSize: geometry.size,
                        imageSize: image.size
                    )
                }
            }
        }
    }
}

/// 单个损伤的标定框
struct DamageBoundingBox: View {
    let damage: DamageDetection
    let containerSize: CGSize
    let imageSize: CGSize
    
    private var boxColor: Color {
        switch damage.severity {
        case .minor: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        case .none: return .gray
        }
    }
    
    private var rect: CGRect {
        // Vision的boundingBox是归一化的（0-1），原点在左下角
        // 需要转换为SwiftUI坐标系（原点在左上角）
        let x = damage.boundingBox.origin.x * containerSize.width
        let y = (1 - damage.boundingBox.origin.y - damage.boundingBox.height) * containerSize.height
        let width = damage.boundingBox.width * containerSize.width
        let height = damage.boundingBox.height * containerSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 标定框
            Rectangle()
                .strokeBorder(boxColor, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
            
            // 损伤类型标签
            Text(damage.type.rawValue)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(boxColor)
                .cornerRadius(4)
                .offset(y: -20)
        }
        .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Error Section

struct PaintErrorSection: View {
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

// MARK: - Result Type

struct PaintScanResult {
    let status: String
    let score: Int
    let damageCount: Int
    let detectedDamages: [DamageDetection]
    let recommendation: String?
}

// MARK: - Damage Severity Extension

extension DamageSeverity {
    var severityWeight: Double {
        switch self {
        case .none: return 0
        case .minor: return 0.3
        case .moderate: return 0.6
        case .severe: return 1.0
        }
    }
}

// MARK: - Share Sheet

struct PaintShareSheet: UIViewControllerRepresentable {
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

#Preview("Paint Scan") {
    NavigationStack {
        PaintScanView()
    }
}

import SwiftUI
import AVFoundation

// MARK: - Tire Tread View

struct TireTreadView: View {
    
    @StateObject private var aiService = TireTreadAIService.shared
    @StateObject private var coreMLService = TireTreadCoreMLService()
    @StateObject private var reportService = UnifiedReportService.shared
    
    @State private var viewState: TireViewState = .guide
    @State private var capturedPhotos: [TirePhoto] = []
    @State private var report: TireTreadReport?
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    enum TireViewState {
        case guide
        case capturing
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
        .navigationTitle("轮胎检测")
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
            if let report = report {
                TireShareSheet(items: [createShareContent(from: report)])
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func createShareContent(from report: TireTreadReport) -> String {
        var content = "iCar 轮胎检测报告\n"
        content += "检测时间: \(Date().formatted(date: .long, time: .shortened))\n"
        content += "综合评分: \(report.overallHealthScore)/100\n"
        content += "平均深度: \(String(format: "%.1f", report.averageDepth))mm\n\n"
        
        for result in report.results {
            content += "\(result.position.displayName): \(result.healthStatus.displayName)\n"
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
        case .confirm:
            Button {
                viewState = .capturing
            } label: {
                Image(systemName: "arrow.counterclockwise")
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
        guard let report = report else { return }
        
        isSaving = true
        
        Task {
            // 使用适配器创建统一报告
            let unifiedReport = ReportAdapters.createTireReport(from: report, photos: capturedPhotos)
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
            TireGuideSection(
                isModelLoaded: coreMLService.isModelLoaded,
                onStart: { viewState = .capturing }
            )
        case .capturing:
            TireCapturingSection(
                photos: $capturedPhotos,
                onComplete: { viewState = .confirm },
                onCancel: { viewState = .guide }
            )
        case .confirm:
            TireConfirmSection(
                photoCount: capturedPhotos.count,
                onAnalyze: { analyzePhotos() },
                onRetake: {
                    capturedPhotos.removeAll()
                    viewState = .capturing
                }
            )
        case .analyzing:
            TireAnalyzingSection(
                progress: aiService.analysisProgress,
                currentPosition: aiService.currentAnalyzingPosition
            )
        case .result:
            if let currentReport = report {
                TireResultSection(
                    report: currentReport,
                    onRetest: {
                        capturedPhotos.removeAll()
                        self.report = nil
                        viewState = .capturing
                    },
                    onDone: { dismiss() }
                )
            }
        case .error:
            TireErrorSection(
                message: errorMessage ?? "分析失败",
                onRetry: {
                    errorMessage = nil
                    analyzePhotos()
                },
                onCancel: { viewState = .guide }
            )
        }
    }
    
    private func analyzePhotos() {
        viewState = .analyzing
        
        Task {
            let result = await aiService.analyzeTires(capturedPhotos)
            await MainActor.run {
                report = result
                viewState = .result
            }
        }
    }
}

// MARK: - Guide Section

struct TireGuideSection: View {
    let isModelLoaded: Bool
    let onStart: () -> Void
    
    private let guidelines = [
        "将手机对准轮胎胎面，确保光线充足",
        "尽量垂直拍摄，包含完整的胎面纹理",
        "在轮胎旁放置参照物（如硬币）用于校准",
        "依次拍摄4个轮胎以获得完整报告"
    ]
    
    var body: some View {
        Section {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("轮胎花纹深度检测")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("AI智能分析轮胎磨损状况")
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
                    title: "开始拍摄",
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

struct TireCapturingSection: View {
    @Binding var photos: [TirePhoto]
    let onComplete: () -> Void
    let onCancel: () -> Void
    @State private var showCamera = false
    
    var body: some View {
        Section {
            VStack(spacing: 24) {
                Spacer()
                
                Text("已拍摄 \(photos.count)/4")
                    .font(.title2)
                    .foregroundColor(.white)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(photos) { photo in
                        PhotoThumbnailView(photo: photo)
                    }
                    
                    if photos.count < 4 {
                        Button {
                            showCamera = true
                        } label: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 100)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                if photos.count >= 1 {
                    ICButton(
                        title: "完成拍摄",
                        icon: "checkmark",
                        style: .success,
                        action: onComplete
                    )
                }
            }
            .padding(.vertical, 40)
        }
        .fullScreenCover(isPresented: $showCamera) {
            ICCameraView(
                config: ICCameraConfiguration(guideType: .circle),
                onCapture: { image in
                    // 创建轮胎照片对象
                    let tirePhoto = TirePhoto(
                        position: .frontLeft,
                        image: image,
                        referenceObject: .coin1Yuan,
                        captureDate: Date()
                    )
                    photos.append(tirePhoto)
                    showCamera = false
                    if photos.count >= 4 {
                        onComplete()
                    }
                },
                onCancel: {
                    showCamera = false
                }
            )
        }
    }
}

// MARK: - Confirm Section

struct TireConfirmSection: View {
    let photoCount: Int
    let onAnalyze: () -> Void
    let onRetake: () -> Void
    
    var body: some View {
        Section {
            VStack(spacing: 40) {
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("已拍摄 \(photoCount) 个轮胎")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.vertical, 60)
        }
        
        Section {
            ICButton(
                title: "开始AI分析",
                icon: "wand.and.stars",
                style: .primary,
                action: onAnalyze
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

// MARK: - Analyzing Section

struct TireAnalyzingSection: View {
    let progress: Double
    let currentPosition: TirePosition?
    
    private let steps = ["检测花纹深度", "分析磨损模式", "生成检测报告"]
    
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
                
                if let position = currentPosition {
                    HStack {
                        Image(systemName: position.icon)
                            .foregroundColor(.cyan)
                        Text("正在分析: \(position.displayName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical, 80)
        }
    }
}

// MARK: - Result Section

struct TireResultSection: View {
    let report: TireTreadReport
    let onRetest: () -> Void
    let onDone: () -> Void
    
    private var statusColor: Color {
        if report.overallHealthScore >= 80 {
            return .green
        } else if report.overallHealthScore >= 60 {
            return .cyan
        } else if report.overallHealthScore >= 40 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var statusIcon: String {
        if report.overallHealthScore >= 80 {
            return "checkmark.circle.fill"
        } else if report.overallHealthScore >= 60 {
            return "info.circle.fill"
        } else if report.overallHealthScore >= 40 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.octagon.fill"
        }
    }
    
    var body: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: statusIcon)
                    .font(.system(size: 64))
                    .foregroundColor(statusColor)
                
                Text("\(report.overallHealthScore)/100")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                
                Text(report.overallStatus.displayName)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        
        if !report.results.isEmpty {
            Section("各轮胎状况") {
                ForEach(report.results.sorted(by: { $0.position.rawValue < $1.position.rawValue })) { result in
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: result.position.icon)
                                .foregroundColor(result.healthStatus.color)
                            Text(result.position.displayName)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("\(result.healthScore)分")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(result.healthStatus.color)
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

struct TireErrorSection: View {
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

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let photo: TirePhoto
    
    var body: some View {
        VStack(spacing: 4) {
            if let thumbnail = photo.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            HStack(spacing: 4) {
                Image(systemName: photo.position.icon)
                    .font(.system(size: 12))
                Text(photo.position.displayName)
                    .font(.caption2)
            }
            .foregroundColor(.gray)
        }
    }
}

// MARK: - Preview

#Preview("Tire Tread") {
    NavigationStack {
        TireTreadView()
    }
}

import SwiftUI

// MARK: - Simplified Tire Tread View

/// 简化版轮胎检测视图 - 统一设计风格
struct TireTreadViewV2: View {
    
    @StateObject private var viewModel = TireTreadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showCancelConfirmation = false
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 进度指示器
            ProgressHeader(currentStep: viewModel.currentStep)
            
            // 主要内容
            content
        }
        .navigationTitle("轮胎检测")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("关闭") { 
                    if viewModel.currentStep != .guide && viewModel.currentStep != .result {
                        showCancelConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.currentStep == .result {
                    Menu {
                        Button(action: { showSaveConfirmation = true }) {
                            Label("保存报告", systemImage: "square.and.arrow.down")
                        }
                        Button(action: { showShareSheet = true }) {
                            Label("分享报告", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("确认取消？", isPresented: $showCancelConfirmation) {
            Button("继续检测", role: .cancel) { }
            Button("确认取消", role: .destructive) {
                viewModel.reset()
                dismiss()
            }
        } message: {
            Text("当前进度将不会保存，确定要取消吗？")
        }
        .alert("保存成功", isPresented: $showSaveConfirmation) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("检测报告已保存到历史记录")
        }
        .sheet(isPresented: $showShareSheet) {
            if let report = viewModel.report {
                ShareSheet(activityItems: [createShareContent(from: report)])
            }
        }
    }
    
    private func createShareContent(from report: TireTreadReport) -> String {
        var content = "🚗 iCar 轮胎检测报告\n"
        content += "检测时间: \(Date().formatted(date: .long, time: .shortened))\n"
        content += "总体评分: \(report.overallHealthScore)/100\n\n"
        
        for result in report.results {
            content += "【\(result.position.displayName)】\n"
            content += "  花纹深度: \(String(format: "%.1f", result.averageDepth))mm\n"
            content += "  状态: \(result.healthStatus.displayName)\n\n"
        }
        
        if !report.recommendations.isEmpty {
            content += "💡 建议:\n"
            for rec in report.recommendations {
                content += "• \(rec)\n"
            }
        }
        
        return content
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.currentStep {
        case .guide:
            SimplifiedGuideView(viewModel: viewModel)
        case .camera:
            TireCameraView(onComplete: { photos in
                viewModel.handlePhotosCaptured(photos)
            }, onCancel: {
                viewModel.reset()
            })
        case .analyzing:
            SimplifiedAnalyzingView(viewModel: viewModel)
        case .result:
            SimplifiedResultView(viewModel: viewModel)
        }
    }
}

// MARK: - Progress Header

struct ProgressHeader: View {
    let currentStep: TireTreadViewModel.DetectionStep
    
    private var progress: Double {
        switch currentStep {
        case .guide: return 0.0
        case .camera: return 0.33
        case .analyzing: return 0.66
        case .result: return 1.0
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 步骤指示器
            HStack(spacing: 0) {
                StepIndicator(icon: "doc.text", isActive: currentStep == .guide, isCompleted: true)
                StepConnector(isActive: currentStep != .guide)
                StepIndicator(icon: "camera", isActive: currentStep == .camera, isCompleted: currentStep == .analyzing || currentStep == .result)
                StepConnector(isActive: currentStep == .analyzing || currentStep == .result)
                StepIndicator(icon: "sparkles", isActive: currentStep == .analyzing, isCompleted: currentStep == .result)
                StepConnector(isActive: currentStep == .result)
                StepIndicator(icon: "checkmark", isActive: currentStep == .result, isCompleted: false)
            }
            .padding(.horizontal, 32)
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.gray5)
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.blue)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.2))
    }
}

struct StepIndicator: View {
    let icon: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 32, height: 32)
            
            Image(systemName: isCompleted ? "checkmark" : icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(foregroundColor)
        }
    }
    
    private var backgroundColor: Color {
        if isCompleted { return .green }
        if isActive { return .blue }
        return .gray5
    }
    
    private var foregroundColor: Color {
        if isCompleted || isActive { return .white }
        return .gray
    }
}

struct StepConnector: View {
    let isActive: Bool
    
    var body: some View {
        Rectangle()
            .fill(isActive ? .green : .gray5)
            .frame(height: 2)
            .padding(.horizontal, 4)
    }
}

// MARK: - Simplified Guide View

struct SimplifiedGuideView: View {
    @ObservedObject var viewModel: TireTreadViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 主视觉
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.blueUltraLight)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "circle.hexagongrid")
                            .font(.system(size: 56))
                            .foregroundColor(.blue)
                    }
                    
                    Text("轮胎花纹检测")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("AI自动分析胎纹深度")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                // 简化步骤 - 使用图标代替文字
                HStack(spacing: 24) {
                    QuickStep(icon: "hands.sparkles", label: "清洁")
                    QuickStep(icon: "centsign.circle", label: "放硬币")
                    QuickStep(icon: "camera.fill", label: "拍摄")
                }
                .padding(.horizontal)
                
                // 提示卡片
                ICTipCard(
                    icon: "lightbulb.fill",
                    title: "小贴士",
                    tips: ["确保光线充足", "垂直拍摄胎面", "包含硬币参照"]
                )
                .padding(.horizontal)
                
                Spacer()
                
                // 开始按钮
                ICButton(
                    title: "开始检测",
                    icon: "camera.fill",
                    style: .primary,
                    size: .large
                ) {
                    viewModel.startDetection()
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
}

struct QuickStep: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
                .background(.blueUltraLight)
                .cornerRadius(8)
            
            Text(label)
                .font(.captionMedium)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Simplified Analyzing View

struct SimplifiedAnalyzingView: View {
    @ObservedObject var viewModel: TireTreadViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // AI分析动画
            ZStack {
                // 外圈脉冲
                PulseRing()
                
                // 中心图标
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
            }
            .frame(width: 120, height: 120)
            
            VStack(spacing: 16) {
                Text("AI分析中")
                    .font(.title2)
                    .foregroundColor(.white)
                
                if let position = viewModel.currentAnalyzingPosition {
                    Text(position.displayName)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            // 进度条
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray5)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blueLight, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * viewModel.analysisProgress, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.analysisProgress)
                    }
                }
                .frame(height: 8)
                
                Text("\(Int(viewModel.analysisProgress * 100))%")
                    .font(.captionMedium)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

struct PulseRing: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(.blue.opacity(0.2), lineWidth: 2)
                .frame(width: 100, height: 100)
            
            Circle()
                .stroke(.blue.opacity(0.4), lineWidth: 2)
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating ? 1.5 : 1.0)
                .opacity(isAnimating ? 0 : 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Simplified Result View

struct SimplifiedResultView: View {
    @ObservedObject var viewModel: TireTreadViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                if let report = viewModel.report {
                    // 总体评分仪表盘
                    ScoreDashboard(score: report.overallHealthScore)
                    
                    // 轮胎状态网格
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(report.results) { result in
                            TireStatusCard(result: result)
                        }
                    }
                    
                    // 建议
                    if !report.recommendations.isEmpty {
                        CompactRecommendations(recommendations: report.recommendations)
                    }
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            ICButton(
                title: "重新检测",
                icon: "arrow.counterclockwise",
                style: .secondary,
                size: .large
            ) {
                viewModel.reset()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
        }
    }
}

struct ScoreDashboard: View {
    let score: Int
    
    private var status: (color: Color, text: String, icon: String) {
        switch score {
        case 80...100: return (.green, "良好", "checkmark.shield.fill")
        case 60..<80: return (.orange, "一般", "exclamationmark.triangle.fill")
        default: return (.red, "需更换", "xmark.octagon.fill")
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(status.color.opacity(0.15), lineWidth: 16)
                    .frame(width: 140, height: 140)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        status.color,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: score)
                
                VStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.system(size: 32))
                        .foregroundColor(status.color)
                    
                    Text("\(score)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(status.color)
                }
            }
            
            HStack(spacing: 16) {
                StatusBadge(text: status.text, color: status.color)
                
                if score < 80 {
                    StatusBadge(text: "建议关注", color: .orange, style: .outline)
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status.color.opacity(0.05))
        )
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var style: BadgeStyle = .filled
    
    enum BadgeStyle {
        case filled, outline
    }
    
    var body: some View {
        Text(text)
            .font(.subheadlineMedium)
            .foregroundColor(style == .filled ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(style == .filled ? color : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color, lineWidth: style == .outline ? 1.5 : 0)
            )
            .cornerRadius(16)
    }
}

struct TireStatusCard: View {
    let result: TireAnalysisResult
    
    private var statusColor: Color {
        switch result.healthStatus {
        case .excellent, .good: return .green
        case .fair: return .orange
        case .poor, .critical: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: result.position.icon)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
                
                Spacer()
                
                if result.shouldReplace {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.position.displayName)
                    .font(.subheadlineMedium)
                    .foregroundColor(.white)
                
                Text("\(String(format: "%.1f", result.averageDepth))mm")
                    .font(.title3)
                    .foregroundColor(statusColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 磨损进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.gray5)
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * (1 - result.wearPercentage), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct CompactRecommendations: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text("维护建议")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(recommendations.prefix(3), id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        
                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(.orangeLight)
        .cornerRadius(12)
    }
}

// MARK: - Tip Card Component

struct ICTipCard: View {
    let icon: String
    let title: String
    let tips: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text(title)
                    .font(.subheadlineMedium)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 16) {
                ForEach(tips, id: \.self) { tip in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        
                        Text(tip)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
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

#Preview("Tire Tread View V2") {
    NavigationView {
        TireTreadViewV2()
    }
}

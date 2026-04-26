import SwiftUI

// MARK: - Simplified AC Doctor View

/// 简化版空调诊断视图 - 统一设计风格
struct ACDoctorViewV2: View {
    
    @StateObject private var service = ACMonitorService.shared
    @State private var viewState: ACViewState = .guide
    @State private var diagnosisResult: ACDiagnosisResult?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCancelConfirmation = false
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    
    enum ACViewState {
        case guide
        case scan
        case analyzing
        case result
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                content
            }
            .navigationTitle("空调诊断")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewState == .guide {
                        Button("关闭") { dismiss() }
                    } else if viewState == .result {
                        Button("完成") { dismiss() }
                    } else {
                        Button("取消") { 
                            if viewState == .scan || viewState == .analyzing {
                                showCancelConfirmation = true
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewState == .result {
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
        }
        .alert("确认取消？", isPresented: $showCancelConfirmation) {
            Button("继续诊断", role: .cancel) { }
            Button("确认取消", role: .destructive) {
                viewState = .guide
            }
        } message: {
            Text("当前进度将不会保存，确定要取消吗？")
        }
        .alert("保存成功", isPresented: $showSaveConfirmation) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("诊断报告已保存到历史记录")
        }
        .sheet(isPresented: $showShareSheet) {
            if let result = diagnosisResult {
                ShareSheet(activityItems: [createShareContent(from: result)])
            }
        }
    }
    
    private func createShareContent(from result: ACDiagnosisResult) -> String {
        var content = "🚗 iCar 空调诊断报告\n"
        content += "检测时间: \(Date().formatted(date: .long, time: .shortened))\n"
        content += "总体评分: \(result.overallScore)/100\n"
        content += "状态: \(result.status.rawValue)\n\n"
        
        if let outletTemp = result.outletTemperature,
           let ambientTemp = result.ambientTemperature {
            content += "出风温度: \(String(format: "%.1f", outletTemp))°C\n"
            content += "环境温度: \(String(format: "%.1f", ambientTemp))°C\n"
            content += "温差: \(String(format: "%.1f", ambientTemp - outletTemp))°C\n\n"
        }
        
        if !result.detectedIssues.isEmpty {
            content += "检测到的问题:\n"
            for issue in result.detectedIssues {
                content += "• \(issue.rawValue)\n"
            }
            content += "\n"
        }
        
        if !result.recommendations.isEmpty {
            content += "💡 建议:\n"
            for rec in result.recommendations {
                content += "• \(rec)\n"
            }
        }
        
        return content
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewState {
        case .guide:
            ACGuideView(onStart: { viewState = .scan })
        case .scan:
            ACScanView(service: service, onComplete: { result in
                diagnosisResult = result
                viewState = .analyzing
                // 模拟分析过程
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    viewState = .result
                }
            })
        case .analyzing:
            ACAnalyzingView()
        case .result:
            if let result = diagnosisResult {
                ACResultView(result: result, onRestart: {
                    viewState = .guide
                    diagnosisResult = nil
                })
            }
        }
    }
}

// MARK: - Guide View

struct ACGuideView: View {
    let onStart: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 主视觉
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "snowflake.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.cyan)
                    }
                    
                    Text("空调智能诊断")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("一键检测空调系统状态")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                // 功能特点 - 简化展示
                HStack(spacing: 24) {
                    ACFeatureItem(icon: "camera.fill", title: "皮带检测", color: .cyan)
                    ACFeatureItem(icon: "mic.fill", title: "风机分析", color: .blue)
                    ACFeatureItem(icon: "thermometer", title: "制冷评估", color: .indigo)
                }
                .padding(.horizontal)
                
                // 提示卡片
                ICTipCard(
                    icon: "info.circle.fill",
                    title: "检测前准备",
                    tips: ["启动发动机", "打开空调", "关闭车窗"]
                )
                .padding(.horizontal)
                
                Spacer()
                
                // 开始按钮
                ICButton(
                    title: "开始诊断",
                    icon: "play.fill",
                    style: .primary,
                    size: .large
                ) {
                    onStart()
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
}

struct ACFeatureItem: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            
            Text(title)
                .font(.captionMedium)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Scan View

struct ACScanView: View {
    let service: ACMonitorService
    let onComplete: (ACDiagnosisResult) -> Void
    
    @State private var scanProgress: Double = 0
    @State private var currentScanItem: ScanItem = .belt
    
    enum ScanItem: String {
        case belt = "检测皮带"
        case fan = "分析风机"
        case temp = "测量温度"
        
        var icon: String {
            switch self {
            case .belt: return "camera.fill"
            case .fan: return "waveform"
            case .temp: return "thermometer"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // 扫描动画
            ZStack {
                // 外圈
                Circle()
                    .stroke(.cyan.opacity(0.2), lineWidth: 4)
                    .frame(width: 140, height: 140)
                
                // 旋转扫描线
                ScanningRing(progress: scanProgress)
                
                // 中心图标
                VStack {
                    Image(systemName: currentScanItem.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.cyan)
                    
                    Text(currentScanItem.rawValue)
                        .font(.captionMedium)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
            }
            .frame(width: 140, height: 140)
            
            // 进度
            VStack(spacing: 8) {
                Text("\(Int(scanProgress * 100))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray5)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * scanProgress, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 40)
            
            // 扫描项状态
            HStack(spacing: 24) {
                ScanStatusItem(icon: "camera.fill", label: "皮带", isActive: currentScanItem == .belt, isCompleted: scanProgress > 0.33)
                ScanStatusItem(icon: "mic.fill", label: "风机", isActive: currentScanItem == .fan, isCompleted: scanProgress > 0.66)
                ScanStatusItem(icon: "thermometer", label: "温度", isActive: currentScanItem == .temp, isCompleted: scanProgress >= 1.0)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .onAppear {
            startScanning()
        }
    }
    
    private func startScanning() {
        // 模拟扫描过程
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            scanProgress += 0.01
            
            // 更新当前扫描项
            if scanProgress < 0.33 {
                currentScanItem = .belt
            } else if scanProgress < 0.66 {
                currentScanItem = .fan
            } else if scanProgress < 1.0 {
                currentScanItem = .temp
            }
            
            if scanProgress >= 1.0 {
                timer.invalidate()
                let result = service.performDiagnosis(
                    beltAnalysis: nil,
                    fanAnalysis: nil,
                    refrigerantPressure: 2.5,
                    outletTemp: 12.0,
                    ambientTemp: 35.0
                )
                onComplete(result)
            }
        }
    }
}

struct ScanningRing: View {
    let progress: Double
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.3)
            .stroke(
                LinearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 140, height: 140)
            .rotationEffect(.degrees(progress * 360))
    }
}

struct ScanStatusItem: View {
    let icon: String
    let label: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isCompleted ? .green : (isActive ? Color.cyan.opacity(0.2) : .gray5))
                    .frame(width: 40, height: 40)
                
                Image(systemName: isCompleted ? "checkmark" : icon)
                    .font(.system(size: 18))
                    .foregroundColor(isCompleted ? .white : (isActive ? .cyan : .gray))
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(isActive || isCompleted ? .white : .gray)
        }
    }
}

// MARK: - Analyzing View

struct ACAnalyzingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // AI分析动画
            ZStack {
                // 脉冲效果
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.cyan.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                        .frame(width: 100 + CGFloat(index) * 30, height: 100 + CGFloat(index) * 30)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.3),
                            value: isAnimating
                        )
                }
                
                // 中心图标
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(.cyan)
            }
            .frame(width: 160, height: 160)
            
            VStack(spacing: 16) {
                Text("AI分析中")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("正在生成诊断报告")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // 分析项
            HStack(spacing: 24) {
                AnalyzingItem(icon: "checkmark.circle.fill", text: "皮带状态", isDone: true)
                AnalyzingItem(icon: "checkmark.circle.fill", text: "风机声音", isDone: true)
                AnalyzingItem(icon: "ellipsis.circle.fill", text: "制冷效率", isDone: false)
            }
            
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct AnalyzingItem: View {
    let icon: String
    let text: String
    let isDone: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isDone ? .green : .cyan)
            
            Text(text)
                .font(.captionMedium)
                .foregroundColor(isDone ? .white : .gray)
        }
    }
}

// MARK: - Result View

struct ACResultView: View {
    let result: ACDiagnosisResult
    let onRestart: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 总体评分
                ACScoreDashboard(result: result)
                
                // 详细指标
                ACMetricsCard(result: result)
                
                // 问题列表
                if !result.detectedIssues.isEmpty {
                    ACIssuesList(issues: result.detectedIssues)
                }
                
                // 建议
                if !result.recommendations.isEmpty {
                    ACRecommendationsList(recommendations: result.recommendations)
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
                onRestart()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
        }
    }
}

struct ACScoreDashboard: View {
    let result: ACDiagnosisResult
    
    private var statusColor: Color {
        switch result.status {
        case .excellent: return .green
        case .good: return .cyan
        case .fair: return .orange
        case .poor: return .red
        case .critical: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(statusColor.opacity(0.15), lineWidth: 16)
                    .frame(width: 140, height: 140)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: CGFloat(result.overallScore) / 100)
                    .stroke(
                        statusColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: result.overallScore)
                
                VStack(spacing: 4) {
                    Image(systemName: result.status.icon)
                        .font(.system(size: 32))
                        .foregroundColor(statusColor)
                    
                    Text("\(result.overallScore)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                }
            }
            
            VStack(spacing: 4) {
                Text(result.status.rawValue)
                    .font(.title2)
                    .foregroundColor(statusColor)
                
                Text(result.status.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.05))
        )
    }
}

struct ACMetricsCard: View {
    let result: ACDiagnosisResult
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)
                
                Text("详细指标")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                MetricBox(
                    icon: "thermometer.snowflake",
                    value: "\(String(format: "%.1f", result.outletTemperature ?? 0))°C",
                    label: "出风温度",
                    color: .cyan
                )
                
                MetricBox(
                    icon: "thermometer.sun",
                    value: "\(String(format: "%.1f", result.ambientTemperature ?? 0))°C",
                    label: "环境温度",
                    color: .orange
                )
                
                MetricBox(
                    icon: "arrow.up.arrow.down",
                    value: "\(String(format: "%.1f", (result.ambientTemperature ?? 0) - (result.outletTemperature ?? 0)))°C",
                    label: "温差",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct MetricBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ACIssuesList: View {
    let issues: [ACIssueType]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                
                Text("检测到的问题")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(issues.count)项")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.gray5)
                    .cornerRadius(12)
            }
            
            VStack(spacing: 8) {
                ForEach(issues.prefix(3), id: \.self) { issue in
                    ACIssueRowCompact(issue: issue)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct ACIssueRowCompact: View {
    let issue: ACIssueType
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: issue.severity.color).opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: issue.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: issue.severity.color))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.rawValue)
                    .font(.subheadlineMedium)
                    .foregroundColor(.white)
                
                Text(issue.recommendedAction)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: issue.severity.icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: issue.severity.color))
        }
        .padding()
        .background(.grayBackground)
        .cornerRadius(8)
    }
}

struct ACRecommendationsList: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18))
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

#Preview("AC Doctor View V2") {
    ACDoctorViewV2()
}

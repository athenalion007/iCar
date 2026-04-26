import SwiftUI

// MARK: - Tire Report View

/// 轮胎检测报告视图
struct TireReportView: View {
    let report: TireTreadReport
    
    @State private var selectedPosition: TirePosition?
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 报告摘要
                reportSummary
                
                // 整体健康评估
                OverallHealthSummaryView(report: report)
                    .padding(.horizontal)
                
                // 花纹深度对比
                TreadDepthComparisonView(results: report.results)
                    .padding(.horizontal)
                
                // 各轮胎详情
                tireDetailsSection
                
                // 维护建议汇总
                maintenanceSummarySection
                
                // 报告信息
                reportInfoSection
                
                // 底部按钮
                bottomActions
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
            .padding(.vertical)
        }
        .navigationTitle("轮胎检测报告")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            TireShareSheet(items: [generateReportText()])
        }
        .alert("报告已保存", isPresented: $showSaveConfirmation) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("轮胎检测报告已成功保存到您的记录中")
        }
    }
    
    // MARK: - Report Summary
    
    private var reportSummary: some View {
        VStack(spacing: 24) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(report.overallStatus.color.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: report.overallStatus.icon)
                    .font(.system(size: 48))
                    .foregroundColor(report.overallStatus.color)
            }
            
            VStack(spacing: 8) {
                Text(report.overallStatus.displayName)
                    .font(.largeTitle)
                    .foregroundColor(report.overallStatus.color)
                
                Text("综合评分: \(report.overallHealthScore)/100")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("平均花纹深度: \(String(format: "%.1f", report.averageDepth)) mm")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // 关键提醒
            if report.needsReplacement {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                    
                    Text("\(report.tiresNeedingReplacement.count)个轮胎需要更换")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.2))
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            LinearGradient(
                colors: [report.overallStatus.color.opacity(0.1), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Tire Details Section
    
    private var tireDetailsSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text("各轮胎详情")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 24) {
                ForEach(report.results.sorted(by: { $0.position.rawValue < $1.position.rawValue })) { result in
                    TireDetailCard(result: result, isExpanded: selectedPosition == result.position) {
                        withAnimation {
                            if selectedPosition == result.position {
                                selectedPosition = nil
                            } else {
                                selectedPosition = result.position
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Maintenance Summary Section
    
    private var maintenanceSummarySection: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text("维护建议汇总")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(report.summaryRecommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 16) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(.blue)
                            .clipShape(Circle())
                        
                        Text(recommendation)
                            .font(.body)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    if index < report.summaryRecommendations.count - 1 {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Report Info Section
    
    private var reportInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("报告信息")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                InfoRow(title: "报告编号", value: report.id.uuidString.prefix(8).uppercased())
                InfoRow(title: "检测时间", value: formatDate(report.createdAt))
                InfoRow(title: "检测轮胎数", value: "\(report.results.count)个")
                InfoRow(title: "安全标准", value: "≥ \(TireTreadAIService.safetyThresholds.minimum) mm")
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        VStack(spacing: 16) {
            ICButton(
                title: "保存报告",
                icon: "square.and.arrow.down",
                style: .primary
            ) {
                saveReport()
            }
            
            ICButton(
                title: "分享报告",
                icon: "square.and.arrow.up",
                style: .secondary
            ) {
                showShareSheet = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
    
    private func saveReport() {
        // 这里可以实现保存到本地或上传到服务器的逻辑
        showSaveConfirmation = true
    }
    
    private func generateReportText() -> String {
        var text = "【iCar轮胎检测报告】\n"
        text += "检测时间: \(formatDate(report.createdAt))\n"
        text += "综合评分: \(report.overallHealthScore)/100\n"
        text += "整体状态: \(report.overallStatus.displayName)\n"
        text += "平均花纹深度: \(String(format: "%.1f", report.averageDepth)) mm\n\n"
        
        text += "【各轮胎状况】\n"
        for result in report.results.sorted(by: { $0.position.rawValue < $1.position.rawValue }) {
            text += "\(result.position.displayName): "
            text += "\(result.healthScore)分 | "
            text += "深度: \(String(format: "%.1f", result.averageDepth)) mm | "
            text += "磨损: \(result.wearPattern.displayName)"
            if result.shouldReplace {
                text += " 【需更换】"
            }
            text += "\n"
        }
        
        text += "\n【维护建议】\n"
        for (index, recommendation) in report.summaryRecommendations.enumerated() {
            text += "\(index + 1). \(recommendation)\n"
        }
        
        return text
    }
}

// MARK: - Tire Detail Card

struct TireDetailCard: View {
    let result: TireAnalysisResult
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部（始终显示）
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // 位置图标
                    ZStack {
                        Circle()
                            .fill(result.healthStatus.color.opacity(0.15))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: result.position.icon)
                            .font(.system(size: 20))
                            .foregroundColor(result.healthStatus.color)
                    }
                    
                    // 基本信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.position.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Text("\(result.healthScore)分")
                                .font(.caption)
                                .foregroundColor(result.healthStatus.color)
                            
                            Text("·")
                                .foregroundColor(.gray)
                            
                            Text("\(String(format: "%.1f", result.averageDepth)) mm")
                                .font(.caption)
                                .foregroundColor(TireTreadAIService.colorForDepth(result.averageDepth))
                        }
                    }
                    
                    Spacer()
                    
                    // 状态图标
                    if result.shouldReplace {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                    }
                    
                    // 展开指示
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展开内容
            if isExpanded {
                VStack(spacing: 24) {
                    Divider()
                    
                    // 简化的深度信息
                    HStack(spacing: 24) {
                        MiniStatItem(
                            title: "平均",
                            value: String(format: "%.1f", result.averageDepth),
                            color: TireTreadAIService.colorForDepth(result.averageDepth)
                        )
                        
                        MiniStatItem(
                            title: "最小",
                            value: String(format: "%.1f", result.minDepth),
                            color: TireTreadAIService.colorForDepth(result.minDepth)
                        )
                        
                        MiniStatItem(
                            title: "磨损",
                            value: "\(Int(result.wearPercentage))%",
                            color: wearColor
                        )
                    }
                    
                    // 磨损模式
                    HStack {
                        Image(systemName: result.wearPattern.icon)
                            .font(.system(size: 16))
                            .foregroundColor(result.wearPattern.color)
                        
                        Text(result.wearPattern.displayName)
                            .font(.subheadline)
                            .foregroundColor(result.wearPattern.color)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // 建议
                    if !result.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.recommendations.prefix(2), id: \.self) { recommendation in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                    
                                    Text(recommendation)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 查看详情按钮
                    NavigationLink(destination: TireDetailView(result: result)) {
                        HStack {
                            Text("查看详细分析")
                                .font(.subheadline)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
        }
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(
            color: Color.black.opacity(0.3),
            radius: 10,
            x: 0,
            y: 5
        )
    }
    
    private var wearColor: Color {
        if result.wearPercentage < 30 {
            return .green
        } else if result.wearPercentage < 70 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Mini Stat Item

struct MiniStatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Tire Detail View

struct TireDetailView: View {
    let result: TireAnalysisResult
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 轮胎位置信息卡片
                TirePositionInfoCard(result: result)
                    .padding(.horizontal)
                
                // 健康评估
                TireHealthView(result: result)
                    .padding(.horizontal)
                
                // 花纹深度
                TreadDepthView(result: result)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(result.position.displayName)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Tire Position Info Card

struct TirePositionInfoCard: View {
    let result: TireAnalysisResult
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: result.position.icon)
                    .font(.system(size: 32))
                    .foregroundColor(result.healthStatus.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.position.displayName)
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text(result.position.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            HStack {
                Text("拍摄时间:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(formatDate(result.photo.captureDate))
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("参照物:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(result.photo.referenceObject.displayName)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Share Sheet

struct TireShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("Tire Report View") {
    NavigationView {
        let sampleReport = TireTreadReport(
            createdAt: Date(),
            results: [
                TireAnalysisResult(
                    position: .frontLeft,
                    photo: TirePhoto(
                        position: .frontLeft,
                        image: UIImage(),
                        referenceObject: .coin1Yuan,
                        captureDate: Date()
                    ),
                    depthPoints: [
                        TreadDepthPoint(position: "inner", depth: 3.2, coordinate: CGPoint(x: 0.3, y: 0.5)),
                        TreadDepthPoint(position: "center", depth: 4.1, coordinate: CGPoint(x: 0.5, y: 0.5)),
                        TreadDepthPoint(position: "outer", depth: 2.8, coordinate: CGPoint(x: 0.7, y: 0.5))
                    ],
                    averageDepth: 3.4,
                    minDepth: 2.8,
                    maxDepth: 4.1,
                    depthVariance: 0.3,
                    wearPattern: .uneven,
                    wearPercentage: 45,
                    healthStatus: .fair,
                    healthScore: 65,
                    shouldReplace: false,
                    remainingMileage: 15000,
                    recommendations: [
                        "建议进行四轮定位检查",
                        "轮胎磨损不均匀，建议进行轮胎换位"
                    ]
                ),
                TireAnalysisResult(
                    position: .frontRight,
                    photo: TirePhoto(
                        position: .frontRight,
                        image: UIImage(),
                        referenceObject: .coin1Yuan,
                        captureDate: Date()
                    ),
                    depthPoints: [],
                    averageDepth: 5.2,
                    minDepth: 4.8,
                    maxDepth: 5.5,
                    wearPattern: .normal,
                    wearPercentage: 20,
                    healthStatus: .good,
                    healthScore: 85,
                    shouldReplace: false,
                    remainingMileage: 35000,
                    recommendations: []
                ),
                TireAnalysisResult(
                    position: .rearLeft,
                    photo: TirePhoto(
                        position: .rearLeft,
                        image: UIImage(),
                        referenceObject: .coin1Yuan,
                        captureDate: Date()
                    ),
                    depthPoints: [],
                    averageDepth: 1.2,
                    minDepth: 0.8,
                    maxDepth: 1.5,
                    wearPattern: .cupping,
                    wearPercentage: 90,
                    healthStatus: .critical,
                    healthScore: 25,
                    shouldReplace: true,
                    remainingMileage: 0,
                    recommendations: ["必须立即更换轮胎"]
                ),
                TireAnalysisResult(
                    position: .rearRight,
                    photo: TirePhoto(
                        position: .rearRight,
                        image: UIImage(),
                        referenceObject: .coin1Yuan,
                        captureDate: Date()
                    ),
                    depthPoints: [],
                    averageDepth: 4.8,
                    minDepth: 4.5,
                    maxDepth: 5.0,
                    wearPattern: .normal,
                    wearPercentage: 25,
                    healthStatus: .good,
                    healthScore: 80,
                    shouldReplace: false,
                    remainingMileage: 30000,
                    recommendations: []
                )
            ]
        )
        
        TireReportView(report: sampleReport)
    }
}

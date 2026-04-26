import SwiftUI

// MARK: - Tire Health View

/// 轮胎健康评估视图
struct TireHealthView: View {
    let result: TireAnalysisResult
    var showDetailedInfo: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 健康评分卡片
            healthScoreCard
            
            if showDetailedInfo {
                // 磨损模式分析
                wearPatternSection
                
                // 更换建议
                replacementRecommendation
                
                // 预估剩余里程
                remainingMileageSection
                
                // 维护建议列表
                maintenanceRecommendations
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(
            color: Color.black.opacity(0.3),
            radius: 10,
            x: 0,
            y: 5
        )
    }
    
    // MARK: - Health Score Card
    
    private var healthScoreCard: some View {
        HStack(spacing: 32) {
            // 评分圆环
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(
                        result.healthStatus.color.opacity(0.2),
                        lineWidth: 12
                    )
                    .frame(width: 100, height: 100)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: CGFloat(result.healthScore) / 100)
                    .stroke(
                        result.healthStatus.color,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: result.healthScore)
                
                // 分数
                VStack(spacing: 0) {
                    Text("\(result.healthScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(result.healthStatus.color)
                    
                    Text("/100")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: result.healthStatus.icon)
                        .font(.system(size: 20))
                        .foregroundColor(result.healthStatus.color)
                    
                    Text(result.healthStatus.displayName)
                        .font(.title3)
                        .foregroundColor(result.healthStatus.color)
                }
                
                Text(healthStatusDescription)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: result.position.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    
                    Text(result.position.displayName)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(result.healthStatus.color.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Wear Pattern Section
    
    private var wearPatternSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("磨损模式分析")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 32) {
                // 磨损类型图标
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(result.wearPattern.color.opacity(0.15))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: result.wearPattern.icon)
                            .font(.system(size: 32))
                            .foregroundColor(result.wearPattern.color)
                    }
                    
                    Text(result.wearPattern.displayName)
                        .font(.subheadline)
                        .foregroundColor(result.wearPattern.color)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.wearPattern.description)
                        .font(.body)
                        .foregroundColor(.white)
                        .lineLimit(3)
                    
                    if result.wearPattern != .normal {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            
                            Text("需要关注")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    // MARK: - Replacement Recommendation
    
    private var replacementRecommendation: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(replacementColor)
                
                Text("更换建议")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack {
                Image(systemName: replacementIcon)
                    .font(.system(size: 32))
                    .foregroundColor(replacementColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(replacementTitle)
                        .font(.title3)
                        .foregroundColor(replacementColor)
                    
                    Text(replacementDescription)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(replacementColor.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(replacementColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Remaining Mileage Section
    
    private var remainingMileageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speedometer")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("预估剩余里程")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(formattedRemainingMileage)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(mileageColor)
                
                Text("公里")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            
            if result.remainingMileage > 0 {
                // 里程进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(mileageGradient)
                            .frame(width: mileageBarWidth(in: geometry.size.width), height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("0 km")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("~\(result.remainingMileage / 1000)k km")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Text("*基于当前磨损状况和平均驾驶习惯估算")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    // MARK: - Maintenance Recommendations
    
    private var maintenanceRecommendations: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("维护建议")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(result.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        
                        Text(recommendation)
                            .font(.body)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var healthStatusDescription: String {
        switch result.healthStatus {
        case .excellent:
            return "轮胎状况极佳，可以放心使用"
        case .good:
            return "轮胎状况良好，正常使用即可"
        case .fair:
            return "轮胎状况一般，建议关注磨损情况"
        case .poor:
            return "轮胎状况较差，建议尽快检查"
        case .critical:
            return "轮胎状况危险，必须立即更换"
        }
    }
    
    private var replacementColor: Color {
        result.shouldReplace ? .red : .green
    }
    
    private var replacementIcon: String {
        result.shouldReplace ? "exclamationmark.octagon.fill" : "checkmark.shield.fill"
    }
    
    private var replacementTitle: String {
        result.shouldReplace ? "建议立即更换" : "暂无需更换"
    }
    
    private var replacementDescription: String {
        if result.shouldReplace {
            return "轮胎已达到或超过安全磨损极限"
        } else {
            return "轮胎仍在安全使用范围内"
        }
    }
    
    private var formattedRemainingMileage: String {
        if result.remainingMileage == 0 {
            return "0"
        } else if result.remainingMileage >= 10000 {
            return String(format: "%.1f万", Double(result.remainingMileage) / 10000)
        } else {
            return "\(result.remainingMileage)"
        }
    }
    
    private var mileageColor: Color {
        if result.remainingMileage == 0 {
            return .red
        } else if result.remainingMileage < 10000 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var mileageGradient: LinearGradient {
        LinearGradient(
            colors: [mileageColor.opacity(0.7), mileageColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func mileageBarWidth(in totalWidth: CGFloat) -> CGFloat {
        let maxMileage: Double = 50000 // 最大参考里程
        let ratio = min(Double(result.remainingMileage) / maxMileage, 1.0)
        return totalWidth * CGFloat(ratio)
    }
}

// MARK: - Overall Health Summary View

/// 整体健康摘要视图
struct OverallHealthSummaryView: View {
    let report: TireTreadReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 标题
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text("整体健康评估")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // 总体评分
            HStack(spacing: 32) {
                // 总体评分圆环
                ZStack {
                    Circle()
                        .stroke(
                            report.overallStatus.color.opacity(0.2),
                            lineWidth: 16
                        )
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(report.overallHealthScore) / 100)
                        .stroke(
                            report.overallStatus.color,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: report.overallHealthScore)
                    
                    VStack(spacing: 0) {
                        Text("\(report.overallHealthScore)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(report.overallStatus.color)
                        
                        Text("总分")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: report.overallStatus.icon)
                            .font(.system(size: 24))
                            .foregroundColor(report.overallStatus.color)
                        
                        Text(report.overallStatus.displayName)
                            .font(.title2)
                            .foregroundColor(report.overallStatus.color)
                    }
                    
                    Text(overallStatusDescription)
                        .font(.body)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    // 统计信息
                    HStack(spacing: 32) {
                        StatBadge(
                            icon: "tirepressure",
                            value: "\(report.results.count)",
                            label: "检测轮胎"
                        )
                        
                        StatBadge(
                            icon: "exclamationmark.triangle",
                            value: "\(report.tiresNeedingReplacement.count)",
                            label: "需更换",
                            color: .red
                        )
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(report.overallStatus.color.opacity(0.05))
            .cornerRadius(12)
            
            // 各轮胎状态概览
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(report.results.sorted(by: { $0.position.rawValue < $1.position.rawValue })) { result in
                    TireStatusRow(result: result)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(
            color: Color.black.opacity(0.3),
            radius: 10,
            x: 0,
            y: 5
        )
    }
    
    private var overallStatusDescription: String {
        switch report.overallStatus {
        case .excellent:
            return "所有轮胎状况良好，请继续保持"
        case .good:
            return "轮胎整体状况良好，建议定期检查"
        case .fair:
            return "部分轮胎需要关注，建议及时维护"
        case .poor:
            return "轮胎状况较差，建议尽快检修"
        case .critical:
            return "存在严重安全隐患，必须立即处理"
        }
    }
}

// MARK: - Tire Status Row

struct TireStatusRow: View {
    let result: TireAnalysisResult
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(result.healthStatus.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: result.position.icon)
                    .font(.system(size: 18))
                    .foregroundColor(result.healthStatus.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.position.displayName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text("\(result.healthScore)分 · \(String(format: "%.1f", result.averageDepth))mm")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if result.shouldReplace {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Preview

#Preview("Tire Health View") {
    ScrollView {
        VStack(spacing: 32) {
            // 单个轮胎健康视图
            let sampleResult = TireAnalysisResult(
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
            )
            
            TireHealthView(result: sampleResult)
                .padding(.horizontal)
            
            // 整体健康摘要
            let sampleReport = TireTreadReport(
                createdAt: Date(),
                results: [
                    sampleResult,
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
                    )
                ]
            )
            
            OverallHealthSummaryView(report: sampleReport)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

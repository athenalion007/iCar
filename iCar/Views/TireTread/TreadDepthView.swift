import SwiftUI

// MARK: - Tread Depth View

/// 花纹深度可视化视图
struct TreadDepthView: View {
    let result: TireAnalysisResult
    var showTitle: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            if showTitle {
                HStack {
                    Image(systemName: result.position.icon)
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text(result.position.displayName)
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    TireStatusBadge(status: result.healthStatus)
                }
            }
            
            // 深度条形图
            depthBarChart
            
            // 统计信息
            depthStatistics
            
            // 安全线说明
            safetyLegend
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
    
    // MARK: - Depth Bar Chart
    
    private var depthBarChart: some View {
        VStack(spacing: 24) {
            // 图表标题
            HStack {
                Text("花纹深度分布")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("单位: mm")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // 条形图
            HStack(alignment: .bottom, spacing: 32) {
                ForEach(result.depthPoints) { point in
                    DepthBar(
                        point: point,
                        maxDepth: max(result.maxDepth, TireTreadAIService.safetyThresholds.new)
                    )
                }
            }
            .frame(height: 160)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Depth Statistics
    
    private var depthStatistics: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                StatItem(
                    title: "平均深度",
                    value: String(format: "%.1f", result.averageDepth),
                    unit: "mm",
                    color: TireTreadAIService.colorForDepth(result.averageDepth)
                )
                
                StatItem(
                    title: "最小深度",
                    value: String(format: "%.1f", result.minDepth),
                    unit: "mm",
                    color: TireTreadAIService.colorForDepth(result.minDepth)
                )
                
                StatItem(
                    title: "最大深度",
                    value: String(format: "%.1f", result.maxDepth),
                    unit: "mm",
                    color: TireTreadAIService.colorForDepth(result.maxDepth)
                )
            }
            
            // 磨损百分比
            HStack {
                Text("磨损程度")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(result.wearPercentage))%")
                    .font(.headline)
                    .foregroundColor(wearPercentageColor)
            }
            .padding(.top, 8)
            
            // 磨损进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray)
                        .frame(height: 8)
                    
                    // 进度
                    RoundedRectangle(cornerRadius: 4)
                        .fill(wearPercentageColor)
                        .frame(width: geometry.size.width * CGFloat(result.wearPercentage / 100), height: 8)
                        .animation(.easeInOut(duration: 0.5), value: result.wearPercentage)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Safety Legend
    
    private var safetyLegend: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("安全标准")
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 16) {
                LegendItem(
                    color: .green,
                    label: "良好 (≥4mm)",
                    isActive: result.averageDepth >= TireTreadAIService.safetyThresholds.good
                )
                
                LegendItem(
                    color: .orange,
                    label: "注意 (1.6-4mm)",
                    isActive: result.averageDepth >= TireTreadAIService.safetyThresholds.minimum &&
                             result.averageDepth < TireTreadAIService.safetyThresholds.good
                )
                
                LegendItem(
                    color: .red,
                    label: "危险 (<1.6mm)",
                    isActive: result.averageDepth < TireTreadAIService.safetyThresholds.minimum
                )
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Computed Properties
    
    private var wearPercentageColor: Color {
        if result.wearPercentage < 30 {
            return .green
        } else if result.wearPercentage < 70 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Depth Bar

struct DepthBar: View {
    let point: TreadDepthPoint
    let maxDepth: Double
    
    private var barHeight: CGFloat {
        let ratio = point.depth / max(maxDepth, 1)
        return max(CGFloat(ratio) * 120, 20)
    }
    
    private var barColor: Color {
        TireTreadAIService.colorForDepth(point.depth)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 数值标签
            Text(String(format: "%.1f", point.depth))
                .font(.caption)
                .foregroundColor(barColor)
            
            // 条形
            RoundedRectangle(cornerRadius: 6)
                .fill(barColor.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(barColor, lineWidth: 2)
                )
                .frame(width: 50, height: barHeight)
                .overlay(
                    // 安全线标记
                    Group {
                        if point.depth < TireTreadAIService.safetyThresholds.minimum {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                        }
                    }
                )
            
            // 位置标签
            Text(point.positionDisplayName)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Status Badge

struct TireStatusBadge: View {
    let status: TireHealthStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 12))
            Text(status.displayName)
                .font(.caption)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: Color
    let label: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(isActive ? .white : .gray)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isActive ? color.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Tread Depth Comparison View

/// 所有轮胎花纹深度对比视图
struct TreadDepthComparisonView: View {
    let results: [TireAnalysisResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("花纹深度对比")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // 对比图表
            VStack(spacing: 24) {
                ForEach(results.sorted(by: { $0.position.rawValue < $1.position.rawValue })) { result in
                    ComparisonRow(result: result)
                }
            }
            
            // 平均值参考线
            HStack {
                Spacer()
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(.blue)
                        .frame(width: 20, height: 2)
                    
                    Text("平均值: \(String(format: "%.1f", averageDepth))mm")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 8)
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
    
    private var averageDepth: Double {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0.0) { $0 + $1.averageDepth } / Double(results.count)
    }
}

// MARK: - Comparison Row

struct ComparisonRow: View {
    let result: TireAnalysisResult
    
    private let maxScaleDepth: Double = 8.0
    
    var body: some View {
        HStack(spacing: 16) {
            // 位置标签
            HStack(spacing: 4) {
                Image(systemName: result.position.icon)
                    .font(.system(size: 14))
                Text(result.position.displayName)
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .frame(width: 80, alignment: .leading)
            
            // 深度条形
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景刻度
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(.green.opacity(0.3))
                            .frame(width: geometry.size.width * 0.5)
                        Rectangle()
                            .fill(.orange.opacity(0.3))
                            .frame(width: geometry.size.width * 0.25)
                        Rectangle()
                            .fill(.red.opacity(0.3))
                            .frame(width: geometry.size.width * 0.25)
                    }
                    
                    // 实际深度
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: barWidth(in: geometry.size.width), height: 24)
                        .overlay(
                            HStack {
                                Spacer()
                                Text(String(format: "%.1f", result.averageDepth))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                            }
                        )
                    
                    // 安全线
                    Rectangle()
                        .fill(.red)
                        .frame(width: 2, height: 28)
                        .offset(x: geometry.size.width * CGFloat(TireTreadAIService.safetyThresholds.minimum / maxScaleDepth))
                }
            }
            .frame(height: 28)
        }
    }
    
    private func barWidth(in totalWidth: CGFloat) -> CGFloat {
        let ratio = min(result.averageDepth / maxScaleDepth, 1.0)
        return totalWidth * CGFloat(ratio)
    }
    
    private var barColor: Color {
        TireTreadAIService.colorForDepth(result.averageDepth)
    }
}

// MARK: - Preview

#Preview("Tread Depth View") {
    ScrollView {
        VStack(spacing: 32) {
            // 单个轮胎深度视图
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
                recommendations: ["建议进行四轮定位检查"]
            )
            
            TreadDepthView(result: sampleResult)
                .padding(.horizontal)
            
            // 对比视图
            let sampleResults = [
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
            
            TreadDepthComparisonView(results: sampleResults)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

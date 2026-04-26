import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML

// MARK: - Tread Depth Measurement

/// 花纹深度测量点
struct TreadDepthPoint: Identifiable, Codable {
    let id: UUID
    let position: String  // "inner", "center", "outer"
    let depth: Double     // 毫米
    let coordinate: Coordinate // 在图片中的位置
    
    init(id: UUID = UUID(), position: String, depth: Double, coordinate: CGPoint) {
        self.id = id
        self.position = position
        self.depth = depth
        self.coordinate = Coordinate(cgPoint: coordinate)
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: coordinate.x, y: coordinate.y)
    }
    
    var positionDisplayName: String {
        switch position {
        case "inner": return "内侧"
        case "center": return "中间"
        case "outer": return "外侧"
        default: return position
        }
    }
}

/// 可编码的坐标结构
struct Coordinate: Codable {
    let x: Double
    let y: Double
    
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    init(cgPoint: CGPoint) {
        self.x = Double(cgPoint.x)
        self.y = Double(cgPoint.y)
    }
}

// MARK: - Tire Analysis Result

/// 单个轮胎分析结果
struct TireAnalysisResult: Identifiable, Codable {
    let id: UUID
    let position: TirePosition
    let photo: TirePhotoInfo
    
    // 花纹深度数据
    var depthPoints: [TreadDepthPoint]
    var averageDepth: Double
    var minDepth: Double
    var maxDepth: Double
    var depthVariance: Double // 方差，用于判断磨损均匀性
    
    // 磨损分析
    var wearPattern: WearPatternType
    var wearPercentage: Double // 磨损百分比
    
    // 安全评估
    var healthStatus: TireHealthStatus
    var healthScore: Int // 0-100
    
    // 建议
    var shouldReplace: Bool
    var remainingMileage: Int // 预估剩余里程
    var recommendations: [String]
    
    // 检测置信度
    var confidence: Double
    
    init(
        id: UUID = UUID(),
        position: TirePosition,
        photo: TirePhoto,
        depthPoints: [TreadDepthPoint] = [],
        averageDepth: Double = 0,
        minDepth: Double = 0,
        maxDepth: Double = 0,
        depthVariance: Double = 0,
        wearPattern: WearPatternType = .normal,
        wearPercentage: Double = 0,
        healthStatus: TireHealthStatus = .good,
        healthScore: Int = 0,
        shouldReplace: Bool = false,
        remainingMileage: Int = 0,
        recommendations: [String] = [],
        confidence: Double = 0.95
    ) {
        self.id = id
        self.position = position
        self.photo = TirePhotoInfo(from: photo)
        self.depthPoints = depthPoints
        self.averageDepth = averageDepth
        self.minDepth = minDepth
        self.maxDepth = maxDepth
        self.depthVariance = depthVariance
        self.wearPattern = wearPattern
        self.wearPercentage = wearPercentage
        self.healthStatus = healthStatus
        self.healthScore = healthScore
        self.shouldReplace = shouldReplace
        self.remainingMileage = remainingMileage
        self.recommendations = recommendations
        self.confidence = confidence
    }
}

/// 可编码的轮胎照片信息
struct TirePhotoInfo: Codable {
    let id: UUID
    let position: TirePosition
    let referenceObject: ReferenceObject
    let captureDate: Date
    
    init(from photo: TirePhoto) {
        self.id = photo.id
        self.position = photo.position
        self.referenceObject = photo.referenceObject
        self.captureDate = photo.captureDate
    }
}

// MARK: - Complete Tire Report

/// 完整轮胎检测报告
struct TireTreadReport: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    var results: [TireAnalysisResult]
    
    init(id: UUID = UUID(), createdAt: Date = Date(), results: [TireAnalysisResult] = []) {
        self.id = id
        self.createdAt = createdAt
        self.results = results
    }
    
    // 整体评估
    var overallHealthScore: Int {
        guard !results.isEmpty else { return 0 }
        let totalScore = results.reduce(0) { $0 + $1.healthScore }
        return totalScore / results.count
    }
    
    var overallStatus: TireHealthStatus {
        let score = overallHealthScore
        switch score {
        case 90...100: return .excellent
        case 75..<90: return .good
        case 60..<75: return .fair
        case 40..<60: return .poor
        default: return .critical
        }
    }
    
    var needsReplacement: Bool {
        results.contains { $0.shouldReplace }
    }
    
    var tiresNeedingReplacement: [TirePosition] {
        results.filter { $0.shouldReplace }.map { $0.position }
    }
    
    // 维护建议
    var recommendations: [String] {
        var recs: [String] = []
        
        if needsReplacement {
            recs.append("建议更换以下轮胎: \(tiresNeedingReplacement.map { $0.displayName }.joined(separator: ", "))")
        }
        
        if overallHealthScore < 60 {
            recs.append("轮胎整体状况较差，建议进行全面检查")
        } else if overallHealthScore < 75 {
            recs.append("轮胎状况一般，建议定期检查")
        }
        
        // 检查是否有不均匀磨损
        let unevenWear = results.filter { $0.wearPattern != .normal }
        if !unevenWear.isEmpty {
            recs.append("检测到不均匀磨损，建议检查轮胎定位和平衡")
        }
        
        if recs.isEmpty {
            recs.append("轮胎状况良好，继续保持定期保养")
        }
        
        return recs
    }
    
    var averageDepth: Double {
        guard !results.isEmpty else { return 0 }
        let total = results.reduce(0.0) { $0 + $1.averageDepth }
        return total / Double(results.count)
    }
    
    var summaryRecommendations: [String] {
        var recommendations: Set<String> = []
        
        for result in results {
            recommendations.insert(result.wearPattern.recommendation)
        }
        
        if needsReplacement {
            recommendations.insert("建议尽快更换磨损严重的轮胎，确保行车安全。")
        }
        
        if overallHealthScore < 60 {
            recommendations.insert("建议进行全面的轮胎和悬挂系统检查。")
        }
        
        return Array(recommendations)
    }
}

// MARK: - Tire Tread AI Service

/// 轮胎AI分析服务
/// 使用 CoreML 模型进行真实深度预测
@MainActor
final class TireTreadAIService: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = TireTreadAIService()
    
    // MARK: - Published Properties
    
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    @Published var currentAnalyzingPosition: TirePosition?
    @Published var lastReport: TireTreadReport?
    @Published var errorMessage: String?
    @Published var isModelLoaded = false
    
    // MARK: - Properties
    
    /// Core ML 模型
    private let coreMLService = TireTreadCoreMLService()
    
    /// 安全花纹深度阈值（毫米）
    static let safetyThresholds = (
        new: 8.0,           // 新轮胎
        good: 4.0,          // 良好
        minimum: 1.6,       // 法定最低
        critical: 1.0       // 危险
    )
    
    /// 预估每毫米花纹可行驶里程（公里）
    static let mileagePerMm = 5000
    
    // MARK: - Analysis
    
    /// 分析所有轮胎照片
    func analyzeTires(_ photos: [TirePhoto]) async -> TireTreadReport {
        isAnalyzing = true
        analysisProgress = 0
        errorMessage = nil
        
        var report = TireTreadReport(createdAt: Date())
        let totalPhotos = photos.count
        
        for (index, photo) in photos.enumerated() {
            currentAnalyzingPosition = photo.position
            
            let result = await analyzeSingleTire(photo)
            report.results.append(result)
            
            analysisProgress = Double(index + 1) / Double(totalPhotos)
        }
        
        isAnalyzing = false
        currentAnalyzingPosition = nil
        lastReport = report
        
        return report
    }
    
    /// 分析单个轮胎
    private func analyzeSingleTire(_ photo: TirePhoto) async -> TireAnalysisResult {
        var result = TireAnalysisResult(
            position: photo.position,
            photo: photo
        )
        
        // 1. 使用 Core ML 模型检测花纹深度
        let depthPoints: [TreadDepthPoint]
        do {
            depthPoints = try await detectDepthsWithAI(photo: photo)
        } catch {
            print("❌ AI 分析失败: \(error.localizedDescription)")
            if let treadError = error as? TireTreadError {
                errorMessage = treadError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            return result
        }
        result.depthPoints = depthPoints
        
        // 2. 计算统计数据
        let depths = depthPoints.map { $0.depth }
        result.averageDepth = depths.reduce(0, +) / Double(depths.count)
        result.minDepth = depths.min() ?? 0
        result.maxDepth = depths.max() ?? 0
        
        // 计算方差
        let mean = result.averageDepth
        let variance = depths.map { pow($0 - mean, 2) }.reduce(0, +) / Double(depths.count)
        result.depthVariance = variance
        
        // 3. 识别磨损模式
        result.wearPattern = detectWearPattern(depthPoints: depthPoints, variance: variance)
        
        // 4. 计算磨损百分比
        result.wearPercentage = calculateWearPercentage(averageDepth: result.averageDepth)
        
        // 5. 评估健康状态
        let healthAssessment = assessHealth(
            averageDepth: result.averageDepth,
            minDepth: result.minDepth,
            wearPattern: result.wearPattern,
            variance: variance
        )
        result.healthStatus = healthAssessment.status
        result.healthScore = healthAssessment.score
        result.shouldReplace = healthAssessment.shouldReplace
        result.remainingMileage = healthAssessment.remainingMileage
        result.recommendations = healthAssessment.recommendations
        
        return result
    }
    
    // MARK: - AI Depth Detection

    /// 使用 Core ML 模型检测花纹深度
    private func detectDepthsWithAI(photo: TirePhoto) async throws -> [TreadDepthPoint] {
        let image = photo.image

        // 检查 Core ML 模型是否已加载
        guard coreMLService.isModelLoaded else {
            print("❌ Core ML 模型未加载")
            throw TireTreadError.modelNotLoaded
        }

        // 使用 Core ML 模型预测深度
        let depths = try await coreMLService.predictDepths(from: image)

        // 使用模型返回的真实深度值创建测量点
        let innerDepth = depths.count > 0 ? depths[0] : 4.0
        let centerDepth = depths.count > 1 ? depths[1] : depths[0]
        let outerDepth = depths.count > 2 ? depths[2] : depths[0]

        let points = [
            TreadDepthPoint(
                position: "inner",
                depth: max(0.5, innerDepth),
                coordinate: CGPoint(x: 0.3, y: 0.5)
            ),
            TreadDepthPoint(
                position: "center",
                depth: max(0.5, centerDepth),
                coordinate: CGPoint(x: 0.5, y: 0.5)
            ),
            TreadDepthPoint(
                position: "outer",
                depth: max(0.5, outerDepth),
                coordinate: CGPoint(x: 0.7, y: 0.5)
            )
        ]

        print("✅ AI 深度检测完成: \(photo.position.displayName) - 内:\(String(format: "%.2f", innerDepth))mm, 中:\(String(format: "%.2f", centerDepth))mm, 外:\(String(format: "%.2f", outerDepth))mm")
        return points
    }
    
    // MARK: - Wear Pattern Detection

    /// 检测磨损模式 - 基于真实深度数据计算
    private func detectWearPattern(depthPoints: [TreadDepthPoint], variance: Double) -> WearPatternType {
        guard depthPoints.count >= 3 else { return .normal }

        let innerDepth = depthPoints.first { $0.position == "inner" }?.depth ?? 0
        let centerDepth = depthPoints.first { $0.position == "center" }?.depth ?? 0
        let outerDepth = depthPoints.first { $0.position == "outer" }?.depth ?? 0

        let maxDiff = max(abs(innerDepth - centerDepth), abs(centerDepth - outerDepth), abs(innerDepth - outerDepth))
        let avgDepth = (innerDepth + centerDepth + outerDepth) / 3.0

        if maxDiff < 0.5 && variance < 0.3 {
            return .normal
        } else if maxDiff > 2.0 {
            if abs(innerDepth - outerDepth) > 1.5 {
                return .uneven
            }
        }

        let centerVsSideDiff = centerDepth - (innerDepth + outerDepth) / 2.0
        if centerVsSideDiff > 0.8 && variance > 0.4 {
            return .feathering
        }

        if variance > 0.6 && maxDiff > 1.0 {
            return .cupping
        }

        if centerDepth > min(innerDepth, outerDepth) && centerDepth < max(innerDepth, outerDepth) {
            if abs(centerDepth - avgDepth) > 0.3 && maxDiff > 0.8 {
                return .scalloping
            }
        }

        return .normal
    }
    
    // MARK: - Wear Percentage Calculation
    
    /// 计算磨损百分比
    private func calculateWearPercentage(averageDepth: Double) -> Double {
        let newDepth = TireTreadAIService.safetyThresholds.new
        let minDepth = TireTreadAIService.safetyThresholds.minimum
        
        if averageDepth >= newDepth {
            return 0
        } else if averageDepth <= minDepth {
            return 100
        } else {
            return ((newDepth - averageDepth) / (newDepth - minDepth)) * 100
        }
    }
    
    // MARK: - Health Assessment
    
    /// 健康评估结果
    private struct HealthAssessment {
        let status: TireHealthStatus
        let score: Int
        let shouldReplace: Bool
        let remainingMileage: Int
        let recommendations: [String]
    }
    
    /// 评估轮胎健康状态
    private func assessHealth(
        averageDepth: Double,
        minDepth: Double,
        wearPattern: WearPatternType,
        variance: Double
    ) -> HealthAssessment {
        var score = 100
        var recommendations: [String] = []
        var shouldReplace = false
        
        if averageDepth < TireTreadAIService.safetyThresholds.critical {
            score -= 60
            shouldReplace = true
            recommendations.append("轮胎花纹深度严重不足，必须立即更换！")
        } else if averageDepth < TireTreadAIService.safetyThresholds.minimum {
            score -= 40
            shouldReplace = true
            recommendations.append("轮胎花纹深度低于法定最低标准，请尽快更换。")
        } else if averageDepth < TireTreadAIService.safetyThresholds.good {
            score -= 20
            recommendations.append("轮胎花纹深度偏浅，建议关注磨损情况。")
        }
        
        switch wearPattern {
        case .normal:
            break
        case .uneven:
            score -= 15
            recommendations.append("检测到偏磨现象，建议进行四轮定位。")
        case .feathering:
            score -= 10
            recommendations.append("检测到羽状磨损，建议检查前束角。")
        case .cupping:
            score -= 20
            recommendations.append("检测到杯状磨损，建议检查减震器。")
        case .scalloping:
            score -= 15
            recommendations.append("检测到锯齿磨损，建议检查轮胎气压。")
        }
        
        if variance > 1.0 {
            score -= 10
            recommendations.append("轮胎磨损不均匀，建议进行轮胎换位。")
        }
        
        score = max(0, min(100, score))
        
        let status: TireHealthStatus
        switch score {
        case 90...100: status = .excellent
        case 75..<90: status = .good
        case 60..<75: status = .fair
        case 40..<60: status = .poor
        default: status = .critical
        }
        
        let remainingMileage: Int
        if shouldReplace {
            remainingMileage = 0
        } else {
            let remainingDepth = averageDepth - TireTreadAIService.safetyThresholds.minimum
            remainingMileage = Int(remainingDepth * Double(TireTreadAIService.mileagePerMm))
        }
        
        return HealthAssessment(
            status: status,
            score: score,
            shouldReplace: shouldReplace,
            remainingMileage: remainingMileage,
            recommendations: recommendations.isEmpty ? ["轮胎状态良好，继续保持。"] : recommendations
        )
    }
    
    // MARK: - Image Processing
    
    /// 预处理图像用于AI分析
    func preprocessImage(_ image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        
        let targetSize = CGSize(width: 416, height: 416)
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(targetSize.width),
            Int(targetSize.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
    
    // MARK: - Utility Methods
    
    /// 获取安全深度阈值
    static func getSafetyThreshold() -> Double {
        return safetyThresholds.minimum
    }
    
    /// 判断深度是否安全
    static func isDepthSafe(_ depth: Double) -> Bool {
        return depth >= safetyThresholds.minimum
    }
    
    /// 获取深度对应的颜色
    static func colorForDepth(_ depth: Double) -> Color {
        if depth >= safetyThresholds.good {
            return ICTheme.Colors.success
        } else if depth >= safetyThresholds.minimum {
            return ICTheme.Colors.warning
        } else {
            return ICTheme.Colors.error
        }
    }
    
    /// 格式化深度显示
    static func formatDepth(_ depth: Double) -> String {
        return String(format: "%.1f mm", depth)
    }
}

// MARK: - Tire Tread Error

enum TireTreadError: LocalizedError {
    case modelNotLoaded
    case preprocessingFailed
    case inferenceFailed(String)
    case invalidOutput(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "模型未加载"
        case .preprocessingFailed:
            return "图像预处理失败"
        case .inferenceFailed(let message):
            return "推理失败: \(message)"
        case .invalidOutput(let message):
            return "输出无效: \(message)"
        }
    }
}

// MARK: - Tire Analysis View Model

/// 轮胎分析视图模型
@MainActor
class TireAnalysisViewModel: ObservableObject {
    @Published var report: TireTreadReport?
    @Published var isAnalyzing = false
    @Published var progress: Double = 0
    @Published var error: String?
    
    private let aiService: TireTreadAnalysisProtocol
    
    init(aiService: TireTreadAnalysisProtocol = TireTreadAIService.shared) {
        self.aiService = aiService
    }
    
    func analyzePhotos(_ photos: [TirePhoto]) async {
        isAnalyzing = true
        progress = 0
        error = nil
        
        let report = await aiService.analyzeTires(photos)
        
        self.report = report
        self.isAnalyzing = false
        self.progress = 1.0
    }
    
    func clearReport() {
        report = nil
    }
}

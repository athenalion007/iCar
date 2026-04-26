import Foundation
#if canImport(UIKit)
import UIKit
#endif
import CoreImage
import CoreGraphics

// MARK: - Damage Type

enum DamageType: String, CaseIterable, Codable {
    case scratch = "划痕"
    case dent = "凹陷"
    case paintLoss = "掉漆"
    case oxidation = "氧化"
    case waterSpot = "水渍"
    case stoneChip = "石子冲击"
    case swirlMark = "旋涡纹"
    case birdDropping = "鸟粪痕迹"
    case clearCoatFailure = "清漆失效"

    var icon: String {
        switch self {
        case .scratch: return "scribble"
        case .dent: return "arrow.down.circle"
        case .paintLoss: return "square.fill.and.line.vertical.and.square.fill"
        case .oxidation: return "sun.max.trianglebadge.exclamationmark"
        case .waterSpot: return "drop.fill"
        case .stoneChip: return "circle.grid.cross.fill"
        case .swirlMark: return "circle.dotted"
        case .birdDropping: return "exclamationmark.triangle.fill"
        case .clearCoatFailure: return "square.dashed"
        }
    }

    var color: String {
        switch self {
        case .scratch: return "#FF9500"
        case .dent: return "#FF3B30"
        case .paintLoss: return "#FF3B30"
        case .oxidation: return "#FF9500"
        case .waterSpot: return "#5AC8FA"
        case .stoneChip: return "#FF9500"
        case .swirlMark: return "#FFCC00"
        case .birdDropping: return "#AF52DE"
        case .clearCoatFailure: return "#FF3B30"
        }
    }

    var description: String {
        switch self {
        case .scratch:
            return "漆面表面可见的线性划痕，可能由清洗不当或接触尖锐物体造成"
        case .dent:
            return "车身表面出现的凹陷变形，通常由外力撞击造成"
        case .paintLoss:
            return "小石块或杂物撞击造成的小块漆面脱落"
        case .oxidation:
            return "漆面失去光泽，颜色变暗淡，由紫外线和氧化造成"
        case .waterSpot:
            return "水蒸发后留下的矿物质沉积，长时间不处理会腐蚀漆面"
        case .stoneChip:
            return "行驶过程中石子等硬物撞击造成的点状损伤"
        case .swirlMark:
            return "在光照下可见的圆形细微划痕，通常由不正确的洗车方式造成"
        case .birdDropping:
            return "鸟粪中的酸性物质对漆面造成的腐蚀痕迹"
        case .clearCoatFailure:
            return "清漆层开始剥落或失效，导致漆面失去保护"
        }
    }

    var severityWeight: Double {
        switch self {
        case .scratch: return 0.6
        case .dent: return 0.9
        case .paintLoss: return 0.8
        case .oxidation: return 0.7
        case .waterSpot: return 0.4
        case .stoneChip: return 0.5
        case .swirlMark: return 0.3
        case .birdDropping: return 0.6
        case .clearCoatFailure: return 0.85
        }
    }
}

// MARK: - Damage Severity

enum DamageSeverity: String, Codable, CaseIterable {
    case none = "无损伤"
    case minor = "轻微"
    case moderate = "中等"
    case severe = "严重"

    var color: String {
        switch self {
        case .none: return "#34C759"
        case .minor: return "#FFCC00"
        case .moderate: return "#FF9500"
        case .severe: return "#FF3B30"
        }
    }

    var icon: String {
        switch self {
        case .none: return "checkmark.circle.fill"
        case .minor: return "exclamationmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .severe: return "xmark.octagon.fill"
        }
    }

    var scoreImpact: Int {
        switch self {
        case .none: return 0
        case .minor: return 5
        case .moderate: return 15
        case .severe: return 30
        }
    }
}

// MARK: - Damage Detection

struct DamageDetection: Identifiable, Codable {
    let id: UUID
    let type: DamageType
    let severity: DamageSeverity
    let boundingBox: CGRect
    let mask: [CGPoint]
    let confidence: Double
    let position: PaintScanPosition

    init(
        id: UUID = UUID(),
        type: DamageType,
        severity: DamageSeverity,
        boundingBox: CGRect,
        mask: [CGPoint] = [],
        confidence: Double,
        position: PaintScanPosition
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.boundingBox = boundingBox
        self.mask = mask
        self.confidence = confidence
        self.position = position
    }

    var area: Double {
        Double(boundingBox.width * boundingBox.height)
    }

    var formattedConfidence: String {
        String(format: "%.1f%%", confidence * 100)
    }
    
    var severityText: String {
        switch severity {
        case .none: return "无损伤"
        case .minor: return "轻微"
        case .moderate: return "中等"
        case .severe: return "严重"
        }
    }
}

// MARK: - Detection Result

struct DetectionResult: Identifiable, Codable {
    let id: UUID
    let position: PaintScanPosition
    let detections: [DamageDetection]
    let overallScore: Int
    let glossLevel: Double
    let clarity: Double
    let colorConsistency: Double
    let timestamp: Date

    init(
        id: UUID = UUID(),
        position: PaintScanPosition,
        detections: [DamageDetection],
        overallScore: Int,
        glossLevel: Double,
        clarity: Double,
        colorConsistency: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.position = position
        self.detections = detections
        self.overallScore = overallScore
        self.glossLevel = glossLevel
        self.clarity = clarity
        self.colorConsistency = colorConsistency
        self.timestamp = timestamp
    }

    var hasDamages: Bool {
        !detections.isEmpty
    }

    var criticalDamages: [DamageDetection] {
        detections.filter { $0.severity == .severe }
    }

    var severityLevel: DamageSeverity {
        if detections.isEmpty { return .none }
        if detections.contains(where: { $0.severity == .severe }) { return .severe }
        if detections.contains(where: { $0.severity == .moderate }) { return .moderate }
        return .minor
    }

    var damageCountByType: [DamageType: Int] {
        var counts: [DamageType: Int] = [:]
        for detection in detections {
            counts[detection.type, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Image Preprocessing Result

struct PreprocessedImage {
    let originalImage: UIImage
    let resizedImage: UIImage
    let normalizedData: Data
    let originalSize: CGSize
    let targetSize: CGSize
}

// MARK: - Paint Scan AI Service

@MainActor
final class PaintScanAIService: ObservableObject {

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var currentStep: String = ""

    // MARK: - Properties

    private let targetSize = CGSize(width: 640, height: 640)
    private let confidenceThreshold: Double = 0.5
    private let nmsThreshold: Double = 0.45
    private let damageDetector = CarDamageDetectorService.shared

    // MARK: - Singleton

    static let shared = PaintScanAIService()

    private init() {}

    // MARK: - Public Methods

    /// 分析单张图片 - 使用真实的 CoreML 模型
    func analyzeImage(_ image: UIImage, position: PaintScanPosition) async throws -> DetectionResult {
        isProcessing = true
        progress = 0

        defer { isProcessing = false }

        // Step 1: 图像预处理
        currentStep = "图像预处理"
        let preprocessed = try await preprocessImage(image)
        progress = 0.3

        // Step 2: 使用真实的 CoreML 模型进行损伤检测
        currentStep = "AI模型推理"
        let detections = try await performRealDetection(image: preprocessed.originalImage, position: position)
        progress = 0.8

        // Step 3: 后处理
        currentStep = "结果后处理"
        let processedDetections = applyNMS(detections)
        progress = 1.0

        // 计算综合评分 - 基于真实检测结果
        let overallScore = calculateOverallScore(detections: processedDetections)
        let glossLevel = calculateGlossLevel(detections: processedDetections)
        let clarity = calculateClarity(detections: processedDetections)
        let colorConsistency = calculateColorConsistency(detections: processedDetections)

        return DetectionResult(
            position: position,
            detections: processedDetections,
            overallScore: overallScore,
            glossLevel: glossLevel,
            clarity: clarity,
            colorConsistency: colorConsistency
        )
    }

    /// 批量分析多张图片
    func analyzeImages(_ photos: [CapturedPhoto]) async throws -> [DetectionResult] {
        var results: [DetectionResult] = []

        for (index, photo) in photos.enumerated() {
            let result = try await analyzeImage(photo.image, position: photo.position)
            results.append(result)

            // 更新总体进度
            progress = Double(index + 1) / Double(photos.count)
        }

        return results
    }

    // MARK: - Real Detection

    /// 使用真实的 CoreML 模型进行损伤检测
    private func performRealDetection(image: UIImage, position: PaintScanPosition) async throws -> [DamageDetection] {
        // 使用 CarDamageDetectorService 进行真实检测
        let detections = try await damageDetector.detectDamages(in: image)

        // CarDamageDetectorService 返回的已经是 DamageDetection 类型
        // 只需要更新 position 为传入的位置
        return detections.map { detection in
            DamageDetection(
                id: detection.id,
                type: detection.type,
                severity: detection.severity,
                boundingBox: detection.boundingBox,
                mask: detection.mask,
                confidence: detection.confidence,
                position: position
            )
        }
    }

    // MARK: - Image Preprocessing

    private func preprocessImage(_ image: UIImage) async throws -> PreprocessedImage {
        guard let cgImage = image.cgImage else {
            throw AIServiceError.invalidImage
        }

        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)

        // 调整图像大小
        let resizedImage = await resizeImage(image, to: targetSize)

        // 归一化处理 (0-255 -> 0-1)
        let normalizedData = await normalizeImage(resizedImage)

        return PreprocessedImage(
            originalImage: image,
            resizedImage: resizedImage,
            normalizedData: normalizedData,
            originalSize: originalSize,
            targetSize: targetSize
        )
    }

    private func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        await Task.detached {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0

            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            return renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }.value
    }

    private func normalizeImage(_ image: UIImage) async -> Data {
        await Task.detached {
            guard let cgImage = image.cgImage else { return Data() }

            let width = cgImage.width
            let height = cgImage.height
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let bitsPerComponent = 8

            var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

            guard let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return Data()
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            // 转换为归一化的Float数组 (RGB顺序)
            var normalizedValues: [Float] = []
            normalizedValues.reserveCapacity(width * height * 3)

            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * bytesPerPixel
                    let r = Float(pixels[offset]) / 255.0
                    let g = Float(pixels[offset + 1]) / 255.0
                    let b = Float(pixels[offset + 2]) / 255.0

                    normalizedValues.append(r)
                    normalizedValues.append(g)
                    normalizedValues.append(b)
                }
            }

            return Data(bytes: &normalizedValues, count: normalizedValues.count * MemoryLayout<Float>.size)
        }.value
    }

    private func generateMaskPoints(for boundingBox: CGRect) -> [CGPoint] {
        var points: [CGPoint] = []
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY
        let radiusX = boundingBox.width / 2
        let radiusY = boundingBox.height / 2

        // 生成椭圆形的遮罩点
        let pointCount = 16
        for i in 0..<pointCount {
            let angle = Double(i) * 2.0 * .pi / Double(pointCount)
            let x = centerX + CGFloat(cos(angle)) * radiusX
            let y = centerY + CGFloat(sin(angle)) * radiusY
            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    // MARK: - Non-Maximum Suppression

    private func applyNMS(_ detections: [DamageDetection]) -> [DamageDetection] {
        // 按置信度排序
        var sortedDetections = detections.sorted { $0.confidence > $1.confidence }
        var selectedDetections: [DamageDetection] = []

        while !sortedDetections.isEmpty {
            let current = sortedDetections.removeFirst()
            selectedDetections.append(current)

            // 移除与当前检测框IoU过高的框
            sortedDetections.removeAll { detection in
                calculateIoU(current.boundingBox, detection.boundingBox) > nmsThreshold
            }
        }

        return selectedDetections
    }

    private func calculateIoU(_ box1: CGRect, _ box2: CGRect) -> Double {
        let intersection = box1.intersection(box2)
        guard intersection.width > 0 && intersection.height > 0 else { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = box1.width * box1.height + box2.width * box2.height - intersectionArea

        return Double(intersectionArea / unionArea)
    }

    // MARK: - Scoring

    private func calculateOverallScore(detections: [DamageDetection]) -> Int {
        let baseScore = 100

        let totalDeduction = detections.reduce(0) { sum, detection in
            let severityImpact = detection.severity.scoreImpact
            let typeWeight = detection.type.severityWeight
            return sum + Int(Double(severityImpact) * typeWeight)
        }

        return max(0, baseScore - totalDeduction)
    }

    /// 基于真实检测结果计算光泽度
    private func calculateGlossLevel(detections: [DamageDetection]) -> Double {
        let baseGloss = 95.0
        let oxidationPenalty = detections.filter { $0.type == .oxidation }.reduce(0.0) { sum, _ in sum + 15.0 }
        let waterSpotPenalty = detections.filter { $0.type == .waterSpot }.reduce(0.0) { sum, _ in sum + 5.0 }
        let clearCoatPenalty = detections.filter { $0.type == .clearCoatFailure }.reduce(0.0) { sum, _ in sum + 20.0 }
        return max(50.0, baseGloss - oxidationPenalty - waterSpotPenalty - clearCoatPenalty)
    }

    /// 基于真实检测结果计算清晰度
    private func calculateClarity(detections: [DamageDetection]) -> Double {
        let baseClarity = 90.0
        let scratchPenalty = detections.filter { $0.type == .scratch }.reduce(0.0) { sum, _ in sum + 10.0 }
        let swirlPenalty = detections.filter { $0.type == .swirlMark }.reduce(0.0) { sum, _ in sum + 8.0 }
        let stoneChipPenalty = detections.filter { $0.type == .stoneChip }.reduce(0.0) { sum, _ in sum + 6.0 }
        return max(40.0, baseClarity - scratchPenalty - swirlPenalty - stoneChipPenalty)
    }

    /// 基于真实检测结果计算颜色一致性
    private func calculateColorConsistency(detections: [DamageDetection]) -> Double {
        let baseConsistency = 95.0
        let oxidationPenalty = detections.filter { $0.type == .oxidation }.reduce(0.0) { sum, _ in sum + 12.0 }
        let paintLossPenalty = detections.filter { $0.type == .paintLoss }.reduce(0.0) { sum, _ in sum + 10.0 }
        let birdDroppingPenalty = detections.filter { $0.type == .birdDropping }.reduce(0.0) { sum, _ in sum + 8.0 }
        return max(60.0, baseConsistency - oxidationPenalty - paintLossPenalty - birdDroppingPenalty)
    }
}

// MARK: - AI Service Error

enum AIServiceError: LocalizedError {
    case invalidImage
    case modelNotLoaded
    case inferenceFailed(String)
    case preprocessingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无效的图像数据"
        case .modelNotLoaded:
            return "AI模型未加载"
        case .inferenceFailed(let message):
            return "推理失败: \(message)"
        case .preprocessingFailed(let message):
            return "预处理失败: \(message)"
        }
    }
}

// MARK: - Bug Splat (for front position)

extension DamageType {
    static let bugSplat = DamageType.scratch // 使用scratch作为虫胶的替代
}

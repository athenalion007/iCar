import SwiftUI
import Combine

// MARK: - Captured Photo Model

struct CapturedPhoto: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
    let position: PaintScanPosition
    let timestamp: Date
    
    static func == (lhs: CapturedPhoto, rhs: CapturedPhoto) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Paint Scan State

enum PaintScanState: Equatable {
    case idle
    case capturing(position: PaintScanPosition)
    case processing
    case completed
    case error(message: String)
}

// MARK: - Paint Scan View Model

@MainActor
final class PaintScanViewModel: ObservableObject {
    
    @Published var capturedPhotos: [CapturedPhoto] = []
    @Published var currentPosition: PaintScanPosition?
    @Published var scanState: PaintScanState = .idle
    @Published var isAnalyzing = false
    @Published var analysisResults: [PaintAnalysisResult] = []
    @Published var showCamera = false
    @Published var showResults = false
    
    var completedPositions: [PaintScanPosition] {
        capturedPhotos.map { $0.position }
    }
    
    var pendingPositions: [PaintScanPosition] {
        PaintScanPosition.allCases.filter { position in
            !completedPositions.contains(position)
        }
    }
    
    var requiredPositions: [PaintScanPosition] {
        PaintScanPosition.allCases.filter { $0.isRequired }
    }
    
    var completedRequiredPositions: [PaintScanPosition] {
        completedPositions.filter { $0.isRequired }
    }
    
    var hasRequiredPositionsCompleted: Bool {
        let requiredSet = Set(requiredPositions.map { $0.rawValue })
        let completedSet = Set(completedRequiredPositions.map { $0.rawValue })
        return requiredSet.isSubset(of: completedSet)
    }
    
    var progressPercentage: CGFloat {
        let total = PaintScanPosition.allCases.count
        guard total > 0 else { return 0 }
        return CGFloat(completedPositions.count) / CGFloat(total)
    }
    
    var nextPendingPosition: PaintScanPosition? {
        pendingPositions.first ?? PaintScanPosition.allCases.first
    }
    
    private let cameraService: CameraServiceProtocol
    private let damageDetector: CarDamageDetectorProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(cameraService: CameraServiceProtocol = CameraService.shared,
         damageDetector: CarDamageDetectorProtocol = CarDamageDetectorService.shared) {
        self.cameraService = cameraService
        self.damageDetector = damageDetector
        setupBindings()
        if let cs = cameraService as? CameraService {
            cs.delegate = self
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        guard let cs = cameraService as? CameraService else { return }
        cs.$isCapturingPhoto
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isCapturing in
                if isCapturing {
                    self?.scanState = .processing
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Photo Management
    
    func addPhoto(_ image: UIImage, for position: PaintScanPosition) {
        // 如果该位置已有照片，先移除旧的
        capturedPhotos.removeAll { $0.position == position }
        
        // 添加新照片
        let photo = CapturedPhoto(
            image: image,
            position: position,
            timestamp: Date()
        )
        capturedPhotos.append(photo)
        
        // 更新状态
        scanState = .idle
        
        // 自动移动到下一个位置
        if let nextPosition = pendingPositions.first {
            currentPosition = nextPosition
        }
    }
    
    func removePhoto(_ photo: CapturedPhoto) {
        capturedPhotos.removeAll { $0.id == photo.id }
    }
    
    func removePhoto(for position: PaintScanPosition) {
        capturedPhotos.removeAll { $0.position == position }
    }
    
    func isPositionCompleted(_ position: PaintScanPosition) -> Bool {
        completedPositions.contains(position)
    }
    
    func getPhoto(for position: PaintScanPosition) -> CapturedPhoto? {
        capturedPhotos.first { $0.position == position }
    }
    
    // MARK: - Scan Control
    
    func startScan(for position: PaintScanPosition) {
        currentPosition = position
        scanState = .capturing(position: position)
        showCamera = true
    }
    
    func startNextScan() {
        if let nextPosition = nextPendingPosition {
            startScan(for: nextPosition)
        }
    }
    
    func finishScan() {
        showCamera = false
        scanState = .idle
        
        // 如果完成了所有必需位置，可以显示结果
        if hasRequiredPositionsCompleted {
            // 可以自动显示结果或提示用户
        }
    }
    
    func reset() {
        capturedPhotos.removeAll()
        currentPosition = nil
        scanState = .idle
        analysisResults.removeAll()
        showCamera = false
        showResults = false
    }
    
    // MARK: - Analysis
    
    func analyzePhotos() async {
        guard !capturedPhotos.isEmpty else { return }
        
        isAnalyzing = true
        
        do {
            var results: [PaintAnalysisResult] = []
            
            for photo in capturedPhotos {
                let detections = try await damageDetector.detectDamages(in: photo.image)
                
                // 将 DamageDetection 转换为 PaintDefect
                let paintDefects = detections.map { detection -> PaintDefect in
                    mapDamageToPaintDefect(detection)
                }
                
                // 基于真实检测结果计算漆面质量指标
                let overallScore = calculateOverallScore(defects: paintDefects)
                let glossLevel = calculateGlossLevel(defects: paintDefects)
                let clarity = calculateClarity(defects: paintDefects)
                let colorConsistency = calculateColorConsistency(defects: paintDefects)
                
                let result = PaintAnalysisResult(
                    position: photo.position,
                    defects: paintDefects,
                    overallScore: overallScore,
                    glossLevel: glossLevel,
                    clarity: clarity,
                    colorConsistency: colorConsistency
                )
                results.append(result)
            }
            
            analysisResults = results
            isAnalyzing = false
            showResults = true
            
        } catch {
            isAnalyzing = false
            scanState = .error(message: "分析失败: \(error.localizedDescription)")
        }
    }
    
    /// 将 DamageDetection 映射为 PaintDefect
    private func mapDamageToPaintDefect(_ detection: DamageDetection) -> PaintDefect {
        let defectType: PaintDefectType
        switch detection.type {
        case .scratch:
            defectType = .scratch
        case .dent:
            defectType = .paintChip
        case .paintLoss:
            defectType = .clearCoatFailure
        case .oxidation:
            defectType = .oxidation
        case .waterSpot:
            defectType = .waterSpot
        case .stoneChip:
            defectType = .paintChip
        case .swirlMark:
            defectType = .swirlMark
        case .birdDropping:
            defectType = .birdDropping
        case .clearCoatFailure:
            defectType = .clearCoatFailure
        }

        let severity: PaintDefectSeverity
        switch detection.severity {
        case .none:
            severity = .none
        case .minor:
            severity = .minor
        case .moderate:
            severity = .moderate
        case .severe:
            severity = .severe
        }

        return PaintDefect(
            type: defectType,
            severity: severity,
            location: CGPoint(
                x: Double(detection.boundingBox.midX),
                y: Double(detection.boundingBox.midY)
            ),
            size: CGSize(
                width: Double(detection.boundingBox.width) * 100,
                height: Double(detection.boundingBox.height) * 100
            ),
            confidence: detection.confidence
        )
    }
    
    /// 基于缺陷计算综合评分
    private func calculateOverallScore(defects: [PaintDefect]) -> Int {
        let baseScore = 100
        let deduction = defects.reduce(0) { total, defect in
            switch defect.severity {
            case .minor: return total + 5
            case .moderate: return total + 15
            case .severe: return total + 30
            case .none: return total
            }
        }
        return max(0, baseScore - deduction)
    }
    
    /// 计算光泽度（基于缺陷类型和数量）
    private func calculateGlossLevel(defects: [PaintDefect]) -> Double {
        let baseGloss = 95.0
        let oxidationPenalty = defects.filter { $0.type == .oxidation }.reduce(0.0) { sum, _ in sum + 15.0 }
        let waterSpotPenalty = defects.filter { $0.type == .waterSpot }.reduce(0.0) { sum, _ in sum + 5.0 }
        return max(50.0, baseGloss - oxidationPenalty - waterSpotPenalty)
    }

    /// 计算清晰度（基于划痕和旋涡纹）
    private func calculateClarity(defects: [PaintDefect]) -> Double {
        let baseClarity = 90.0
        let scratchPenalty = defects.filter { $0.type == .scratch }.reduce(0.0) { sum, _ in sum + 10.0 }
        let swirlPenalty = defects.filter { $0.type == .swirlMark }.reduce(0.0) { sum, _ in sum + 8.0 }
        return max(40.0, baseClarity - scratchPenalty - swirlPenalty)
    }

    /// 计算颜色一致性（基于氧化和掉漆）
    private func calculateColorConsistency(defects: [PaintDefect]) -> Double {
        let baseConsistency = 95.0
        let oxidationPenalty = defects.filter { $0.type == .oxidation }.reduce(0.0) { sum, _ in sum + 12.0 }
        let chipPenalty = defects.filter { $0.type == .paintChip }.reduce(0.0) { sum, _ in sum + 8.0 }
        return max(60.0, baseConsistency - oxidationPenalty - chipPenalty)
    }
}

// MARK: - Camera Service Delegate

extension PaintScanViewModel: CameraServiceDelegate {
    
    nonisolated func cameraService(_ service: AnyObject, didCapturePhoto image: UIImage) {
        Task { @MainActor in
            if let position = self.currentPosition {
                self.addPhoto(image, for: position)
            }
        }
    }
    
    nonisolated func cameraService(_ service: AnyObject, didFailWithError error: CameraError) {
        Task { @MainActor in
            self.scanState = .error(message: error.errorDescription ?? "相机错误")
        }
    }
    
    nonisolated func cameraServiceDidChangeZoom(_ service: AnyObject, zoomFactor: CGFloat) {
        // 可以在这里处理变焦变化
    }
    
    nonisolated func cameraServiceDidChangeFocus(_ service: AnyObject, point: CGPoint) {
        // 可以在这里处理对焦变化
    }
}

// MARK: - Paint Analysis Result Models

struct PaintAnalysisResult: Identifiable {
    let id = UUID()
    let position: PaintScanPosition
    let defects: [PaintDefect]
    let overallScore: Int
    let glossLevel: Double
    let clarity: Double
    let colorConsistency: Double
    
    var hasDefects: Bool {
        !defects.isEmpty
    }
    
    var severityLevel: PaintDefectSeverity {
        if defects.isEmpty { return .none }
        if defects.contains(where: { $0.severity == .severe }) { return .severe }
        if defects.contains(where: { $0.severity == .moderate }) { return .moderate }
        return .minor
    }
}

struct PaintDefect: Identifiable {
    let id = UUID()
    let type: PaintDefectType
    let severity: PaintDefectSeverity
    let location: CGPoint
    let size: CGSize
    let confidence: Double
}

enum PaintDefectType: String, CaseIterable {
    case scratch = "划痕"
    case swirlMark = "旋涡纹"
    case oxidation = "氧化"
    case waterSpot = "水渍"
    case birdDropping = "鸟粪痕迹"
    case paintChip = "掉漆"
    case clearCoatFailure = "清漆失效"
    
    var icon: String {
        switch self {
        case .scratch: return "scribble"
        case .swirlMark: return "circle.dotted"
        case .oxidation: return "sun.max.trianglebadge.exclamationmark"
        case .waterSpot: return "drop.fill"
        case .birdDropping: return "exclamationmark.triangle.fill"
        case .paintChip: return "square.fill.and.line.vertical.and.square.fill"
        case .clearCoatFailure: return "square.dashed"
        }
    }
    
    var description: String {
        switch self {
        case .scratch:
            return "漆面表面可见的线性划痕，可能由清洗不当或接触尖锐物体造成"
        case .swirlMark:
            return "在光照下可见的圆形细微划痕，通常由不正确的洗车方式造成"
        case .oxidation:
            return "漆面失去光泽，颜色变暗淡，由紫外线和氧化造成"
        case .waterSpot:
            return "水蒸发后留下的矿物质沉积，长时间不处理会腐蚀漆面"
        case .birdDropping:
            return "鸟粪中的酸性物质对漆面造成的腐蚀痕迹"
        case .paintChip:
            return "小石块或杂物撞击造成的小块漆面脱落"
        case .clearCoatFailure:
            return "清漆层开始剥落或失效，导致漆面失去保护"
        }
    }
}

enum PaintDefectSeverity: String, CaseIterable {
    case none = "无缺陷"
    case minor = "轻微"
    case moderate = "中等"
    case severe = "严重"
    
    var color: Color {
        switch self {
        case .none: return .green
        case .minor: return .yellow
        case .moderate: return .orange
        case .severe: return .red
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
}

// MARK: - Paint Scan Report

struct PaintScanReport {
    let id = UUID()
    let timestamp: Date
    let photos: [CapturedPhoto]
    let results: [PaintAnalysisResult]
    
    var overallScore: Int {
        guard !results.isEmpty else { return 0 }
        let totalScore = results.reduce(0) { $0 + $1.overallScore }
        return totalScore / results.count
    }
    
    var totalDefects: Int {
        results.reduce(0) { $0 + $1.defects.count }
    }
    
    var criticalIssues: Int {
        results.reduce(0) { count, result in
            count + result.defects.filter { $0.severity == .severe }.count
        }
    }
    
    var recommendations: [String] {
        var recommendations: [String] = []
        
        if overallScore < 80 {
            recommendations.append("建议进行专业漆面修复护理")
        }
        
        if criticalIssues > 0 {
            recommendations.append("发现严重漆面问题，建议尽快处理")
        }
        
        let hasSwirlMarks = results.contains { $0.defects.contains { $0.type == .swirlMark } }
        if hasSwirlMarks {
            recommendations.append("建议进行漆面抛光去除旋涡纹")
        }
        
        let hasOxidation = results.contains { $0.defects.contains { $0.type == .oxidation } }
        if hasOxidation {
            recommendations.append("漆面存在氧化，建议使用抗氧化剂处理")
        }
        
        if recommendations.isEmpty {
            recommendations.append("漆面状况良好，继续保持定期护理")
        }
        
        return recommendations
    }
}

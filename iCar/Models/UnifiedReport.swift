import Foundation
#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

// MARK: - Unified Inspection Report

/// 统一检测报告模型 - 支持所有检测类型
struct UnifiedReport: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date

    // 基本信息
    var title: String
    var notes: String
    var inspectionType: UnifiedInspectionType
    var status: UnifiedReportStatus
    var isFavorite: Bool
    var tags: [String]

    // 车辆信息
    var carId: UUID?
    var carBrand: String
    var carModel: String
    var licensePlate: String
    var carColor: String
    var vin: String
    var mileage: Double

    // 通用评分
    var overallScore: Int
    var overallStatus: UnifiedInspectionStatus

    // 检测数据 - 根据类型存储不同数据
    var sections: [ReportSection]
    var capturedPhotos: [UnifiedCapturedPhotoInfo]
    var recommendations: [UnifiedReportRecommendation]
    var maintenanceTasks: [UnifiedMaintenanceTask]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String,
        notes: String = "",
        inspectionType: UnifiedInspectionType,
        status: UnifiedReportStatus = .completed,
        isFavorite: Bool = false,
        tags: [String] = [],
        carId: UUID? = nil,
        carBrand: String,
        carModel: String,
        licensePlate: String,
        carColor: String,
        vin: String = "",
        mileage: Double = 0,
        overallScore: Int,
        overallStatus: UnifiedInspectionStatus,
        sections: [ReportSection] = [],
        capturedPhotos: [UnifiedCapturedPhotoInfo] = [],
        recommendations: [UnifiedReportRecommendation] = [],
        maintenanceTasks: [UnifiedMaintenanceTask] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.notes = notes
        self.inspectionType = inspectionType
        self.status = status
        self.isFavorite = isFavorite
        self.tags = tags
        self.carId = carId
        self.carBrand = carBrand
        self.carModel = carModel
        self.licensePlate = licensePlate
        self.carColor = carColor
        self.vin = vin
        self.mileage = mileage
        self.overallScore = overallScore
        self.overallStatus = overallStatus
        self.sections = sections
        self.capturedPhotos = capturedPhotos
        self.recommendations = recommendations
        self.maintenanceTasks = maintenanceTasks
    }
}

// MARK: - Unified Inspection Type

enum UnifiedInspectionType: String, Codable, CaseIterable {
    case paint = "paint"
    case tire = "tire"
    case engine = "engine"
    case suspension = "suspension"
    case ac = "ac"

    var displayName: String {
        switch self {
        case .paint: return "漆面检测"
        case .tire: return "轮胎检测"
        case .engine: return "引擎听诊"
        case .suspension: return "悬挂监测"
        case .ac: return "空调诊断"
        }
    }

    var icon: String {
        switch self {
        case .paint: return "paintpalette.fill"
        case .tire: return "circle.fill"
        case .engine: return "gearshape.fill"
        case .suspension: return "arrow.up.and.down"
        case .ac: return "snowflake"
        }
    }

    var color: String {
        switch self {
        case .paint: return "#5856D6"
        case .tire: return "#FF9500"
        case .engine: return "#FF3B30"
        case .suspension: return "#34C759"
        case .ac: return "#5AC8FA"
        }
    }
}

// MARK: - Unified Inspection Status

enum UnifiedInspectionStatus: String, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "需关注"
        case .critical: return "严重"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "info.circle.fill"
        case .poor: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

// MARK: - Unified Report Status

enum UnifiedReportStatus: String, Codable {
    case draft = "draft"
    case completed = "completed"
    case archived = "archived"
}

// MARK: - Report Section

/// 报告区块 - 通用结构，支持各种检测数据
struct ReportSection: Identifiable, Codable {
    let id: UUID
    var title: String
    var subtitle: String?
    var icon: String?
    var order: Int
    var items: [ReportItem]
    var metrics: [ReportMetric]
    var summary: String?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        order: Int = 0,
        items: [ReportItem] = [],
        metrics: [ReportMetric] = [],
        summary: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.order = order
        self.items = items
        self.metrics = metrics
        self.summary = summary
    }
}

// MARK: - Report Item

/// 报告条目 - 单个检测项
struct ReportItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var status: ReportItemStatus
    var severity: ItemSeverity?
    var value: String?
    var unit: String?
    var referenceRange: String?
    var confidence: Double?
    var position: String?
    var imageFilename: String?

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        status: ReportItemStatus = .normal,
        severity: ItemSeverity? = nil,
        value: String? = nil,
        unit: String? = nil,
        referenceRange: String? = nil,
        confidence: Double? = nil,
        position: String? = nil,
        imageFilename: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.severity = severity
        self.value = value
        self.unit = unit
        self.referenceRange = referenceRange
        self.confidence = confidence
        self.position = position
        self.imageFilename = imageFilename
    }
}

// MARK: - Report Item Status

enum ReportItemStatus: String, Codable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
    case info = "info"

    var displayName: String {
        switch self {
        case .normal: return "正常"
        case .warning: return "警告"
        case .critical: return "严重"
        case .info: return "信息"
        }
    }

    var color: String {
        switch self {
        case .normal: return "#34C759"
        case .warning: return "#FF9500"
        case .critical: return "#FF3B30"
        case .info: return "#5AC8FA"
        }
    }
}

// MARK: - Item Severity

enum ItemSeverity: String, Codable {
    case minor = "minor"
    case moderate = "moderate"
    case severe = "severe"

    var displayName: String {
        switch self {
        case .minor: return "轻微"
        case .moderate: return "中等"
        case .severe: return "严重"
        }
    }
}

// MARK: - Report Metric

/// 报告指标 - 数值型数据
struct ReportMetric: Identifiable, Codable {
    let id: UUID
    var name: String
    var value: Double
    var unit: String?
    var maxValue: Double?
    var icon: String?

    init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        unit: String? = nil,
        maxValue: Double? = nil,
        icon: String? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.maxValue = maxValue
        self.icon = icon
    }

    var percentage: Double {
        guard let max = maxValue, max > 0 else { return 0 }
        return min(value / max, 1.0)
    }

    var formattedValue: String {
        if let unit = unit {
            return String(format: "%.1f%@", value, unit)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Unified Report Recommendation

struct UnifiedReportRecommendation: Identifiable, Codable {
    let id: UUID
    var priority: UnifiedRecommendationPriority
    var category: UnifiedRecommendationCategory
    var title: String
    var description: String
    var estimatedCost: String

    init(
        id: UUID = UUID(),
        priority: UnifiedRecommendationPriority,
        category: UnifiedRecommendationCategory,
        title: String,
        description: String,
        estimatedCost: String
    ) {
        self.id = id
        self.priority = priority
        self.category = category
        self.title = title
        self.description = description
        self.estimatedCost = estimatedCost
    }
}

// MARK: - Unified Recommendation Priority

enum UnifiedRecommendationPriority: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }

    var color: String {
        switch self {
        case .high: return "#FF3B30"
        case .medium: return "#FF9500"
        case .low: return "#34C759"
        }
    }
}

// MARK: - Unified Recommendation Category

enum UnifiedRecommendationCategory: String, Codable {
    case repair = "repair"
    case maintenance = "maintenance"
    case polishing = "polishing"
    case replacement = "replacement"

    var displayName: String {
        switch self {
        case .repair: return "维修"
        case .maintenance: return "保养"
        case .polishing: return "抛光"
        case .replacement: return "更换"
        }
    }

    var icon: String {
        switch self {
        case .repair: return "wrench.fill"
        case .maintenance: return "gearshape.fill"
        case .polishing: return "sparkles"
        case .replacement: return "arrow.2.circlepath"
        }
    }
}

// MARK: - Unified Maintenance Task

struct UnifiedMaintenanceTask: Identifiable, Codable {
    let id: UUID
    var timeframe: UnifiedMaintenanceTimeframe
    var title: String
    var description: String
    var isUrgent: Bool

    init(
        id: UUID = UUID(),
        timeframe: UnifiedMaintenanceTimeframe,
        title: String,
        description: String,
        isUrgent: Bool = false
    ) {
        self.id = id
        self.timeframe = timeframe
        self.title = title
        self.description = description
        self.isUrgent = isUrgent
    }
}

// MARK: - Unified Maintenance Timeframe

enum UnifiedMaintenanceTimeframe: String, Codable {
    case immediate = "immediate"
    case oneWeek = "oneWeek"
    case oneMonth = "oneMonth"
    case threeMonths = "threeMonths"
    case sixMonths = "sixMonths"
    case oneYear = "oneYear"

    var displayName: String {
        switch self {
        case .immediate: return "立即"
        case .oneWeek: return "1周内"
        case .oneMonth: return "1个月内"
        case .threeMonths: return "3个月内"
        case .sixMonths: return "6个月内"
        case .oneYear: return "1年内"
        }
    }

    var icon: String {
        switch self {
        case .immediate: return "exclamationmark.circle.fill"
        case .oneWeek: return "calendar.badge.clock"
        case .oneMonth: return "calendar"
        case .threeMonths: return "calendar.badge.plus"
        case .sixMonths: return "calendar.badge.minus"
        case .oneYear: return "calendar.badge.checkmark"
        }
    }
}

// MARK: - Unified Score Range

enum UnifiedScoreRange: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"

    var displayName: String {
        switch self {
        case .excellent: return "优秀 (90-100)"
        case .good: return "良好 (75-89)"
        case .fair: return "一般 (60-74)"
        case .poor: return "需改进 (0-59)"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .excellent: return 90...100
        case .good: return 75...89
        case .fair: return 60...74
        case .poor: return 0...59
        }
    }

    var color: String {
        switch self {
        case .excellent: return "#34C759"
        case .good: return "#FFCC00"
        case .fair: return "#FF9500"
        case .poor: return "#FF3B30"
        }
    }
}

// MARK: - Unified Report Sort Option

enum UnifiedReportSortOption: String, Codable, CaseIterable {
    case dateDesc = "dateDesc"
    case dateAsc = "dateAsc"
    case scoreDesc = "scoreDesc"
    case scoreAsc = "scoreAsc"

    var displayName: String {
        switch self {
        case .dateDesc: return "日期 (新→旧)"
        case .dateAsc: return "日期 (旧→新)"
        case .scoreDesc: return "评分 (高→低)"
        case .scoreAsc: return "评分 (低→高)"
        }
    }
}

// MARK: - Unified Captured Photo Info

struct UnifiedCapturedPhotoInfo: Identifiable, Codable {
    let id: UUID
    var filename: String
    var position: UnifiedPhotoPosition?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        filename: String,
        position: UnifiedPhotoPosition? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.position = position
        self.timestamp = timestamp
    }
}

// MARK: - Unified Photo Position

enum UnifiedPhotoPosition: String, Codable {
    case front = "front"
    case rear = "rear"
    case left = "left"
    case right = "right"
    case top = "top"
    case interior = "interior"

    var displayName: String {
        switch self {
        case .front: return "前部"
        case .rear: return "后部"
        case .left: return "左侧"
        case .right: return "右侧"
        case .top: return "顶部"
        case .interior: return "内部"
        }
    }
}

// MARK: - Computed Properties

extension UnifiedReport {
    var displayTitle: String {
        if title.isEmpty {
            return "\(inspectionType.displayName) - \(formattedDate)"
        }
        return title
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: createdAt)
    }

    var totalIssues: Int {
        sections.reduce(0) { count, section in
            count + section.items.filter { $0.status != .normal }.count
        }
    }

    var criticalIssues: Int {
        sections.reduce(0) { count, section in
            count + section.items.filter { $0.status == .critical }.count
        }
    }

    var hasCriticalIssues: Bool {
        criticalIssues > 0
    }

    var scoreColor: String {
        switch overallStatus {
        case .excellent: return "#34C759"
        case .good: return "#FFCC00"
        case .fair: return "#FF9500"
        case .poor, .critical: return "#FF3B30"
        }
    }
}

// MARK: - Report Builder

/// 报告构建器 - 简化报告创建
class UnifiedReportBuilder {
    private var title: String = ""
    private var notes: String = ""
    private var inspectionType: UnifiedInspectionType = .paint
    private var carBrand: String = ""
    private var carModel: String = ""
    private var licensePlate: String = ""
    private var carColor: String = ""
    private var overallScore: Int = 0
    private var overallStatus: UnifiedInspectionStatus = .good
    private var sections: [ReportSection] = []
    private var capturedPhotos: [UnifiedCapturedPhotoInfo] = []
    private var recommendations: [UnifiedReportRecommendation] = []
    private var maintenanceTasks: [UnifiedMaintenanceTask] = []

    func setTitle(_ title: String) -> Self {
        self.title = title
        return self
    }

    func setNotes(_ notes: String) -> Self {
        self.notes = notes
        return self
    }

    func setInspectionType(_ type: UnifiedInspectionType) -> Self {
        self.inspectionType = type
        return self
    }

    func setVehicleInfo(brand: String, model: String, plate: String = "", color: String = "") -> Self {
        self.carBrand = brand
        self.carModel = model
        self.licensePlate = plate
        self.carColor = color
        return self
    }

    func setScore(_ score: Int, status: UnifiedInspectionStatus) -> Self {
        self.overallScore = score
        self.overallStatus = status
        return self
    }

    func addSection(_ section: ReportSection) -> Self {
        self.sections.append(section)
        return self
    }

    func addPhoto(_ photo: UnifiedCapturedPhotoInfo) -> Self {
        self.capturedPhotos.append(photo)
        return self
    }

    func addRecommendation(_ recommendation: UnifiedReportRecommendation) -> Self {
        self.recommendations.append(recommendation)
        return self
    }

    func addMaintenanceTask(_ task: UnifiedMaintenanceTask) -> Self {
        self.maintenanceTasks.append(task)
        return self
    }

    func build() -> UnifiedReport {
        UnifiedReport(
            title: title,
            notes: notes,
            inspectionType: inspectionType,
            carBrand: carBrand,
            carModel: carModel,
            licensePlate: licensePlate,
            carColor: carColor,
            overallScore: overallScore,
            overallStatus: overallStatus,
            sections: sections.sorted { $0.order < $1.order },
            capturedPhotos: capturedPhotos,
            recommendations: recommendations,
            maintenanceTasks: maintenanceTasks
        )
    }
}

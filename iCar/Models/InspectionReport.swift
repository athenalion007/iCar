import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Inspection Report

struct InspectionReport: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var title: String
    var notes: String
    
    // 车辆信息
    var carId: UUID?
    var carBrand: String
    var carModel: String
    var licensePlate: String
    var carColor: String
    var vin: String
    var mileage: Double
    
    // 检测结果
    var detectionResults: [DetectionResult]
    var capturedPhotos: [CapturedPhotoInfo]
    
    // 评分
    var overallScore: Int
    var glossLevel: Double
    var clarity: Double
    var colorConsistency: Double
    
    // 报告状态
    var status: ReportStatus
    var isFavorite: Bool
    var tags: [String]
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String,
        notes: String = "",
        carId: UUID? = nil,
        carBrand: String,
        carModel: String,
        licensePlate: String,
        carColor: String,
        vin: String = "",
        mileage: Double = 0,
        detectionResults: [DetectionResult] = [],
        capturedPhotos: [CapturedPhotoInfo] = [],
        overallScore: Int = 0,
        glossLevel: Double = 0,
        clarity: Double = 0,
        colorConsistency: Double = 0,
        status: ReportStatus = .draft,
        isFavorite: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.notes = notes
        self.carId = carId
        self.carBrand = carBrand
        self.carModel = carModel
        self.licensePlate = licensePlate
        self.carColor = carColor
        self.vin = vin
        self.mileage = mileage
        self.detectionResults = detectionResults
        self.capturedPhotos = capturedPhotos
        self.overallScore = overallScore
        self.glossLevel = glossLevel
        self.clarity = clarity
        self.colorConsistency = colorConsistency
        self.status = status
        self.isFavorite = isFavorite
        self.tags = tags
    }
    
    // MARK: - Computed Properties
    
    var displayTitle: String {
        if title.isEmpty {
            return "\(carBrand) \(carModel) - \(formattedDate)"
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
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: createdAt)
    }
    
    var totalDamages: Int {
        detectionResults.reduce(0) { $0 + $1.detections.count }
    }
    
    var criticalDamages: Int {
        detectionResults.reduce(0) { count, result in
            count + result.detections.filter { $0.severity == .severe }.count
        }
    }
    
    var damageCountByType: [DamageType: Int] {
        var counts: [DamageType: Int] = [:]
        for result in detectionResults {
            for detection in result.detections {
                counts[detection.type, default: 0] += 1
            }
        }
        return counts
    }
    
    var damageCountByPosition: [PaintScanPosition: Int] {
        var counts: [PaintScanPosition: Int] = [:]
        for result in detectionResults {
            counts[result.position] = result.detections.count
        }
        return counts
    }
    
    var hasCriticalIssues: Bool {
        criticalDamages > 0
    }
    
    var scoreColor: String {
        if overallScore >= 90 { return "#34C759" }
        if overallScore >= 75 { return "#FFCC00" }
        if overallScore >= 60 { return "#FF9500" }
        return "#FF3B30"
    }
    
    var scoreDescription: String {
        if overallScore >= 90 { return "优秀" }
        if overallScore >= 75 { return "良好" }
        if overallScore >= 60 { return "一般" }
        return "需关注"
    }
    
    // MARK: - Recommendations
    
    var recommendations: [ReportRecommendation] {
        var recommendations: [ReportRecommendation] = []
        
        // 基于总体评分
        if overallScore < 60 {
            recommendations.append(ReportRecommendation(
                priority: .high,
                category: .general,
                title: "漆面状况较差",
                description: "车辆漆面存在较多问题，建议尽快进行全面修复护理。",
                estimatedCost: "¥2000-5000"
            ))
        } else if overallScore < 80 {
            recommendations.append(ReportRecommendation(
                priority: .medium,
                category: .general,
                title: "建议进行专业护理",
                description: "漆面存在一些问题，建议进行专业修复护理以恢复光泽。",
                estimatedCost: "¥800-2000"
            ))
        }
        
        // 基于严重问题
        if criticalDamages > 0 {
            recommendations.append(ReportRecommendation(
                priority: .high,
                category: .repair,
                title: "发现严重漆面损伤",
                description: "检测到\(criticalDamages)处严重损伤，建议尽快处理以防止进一步恶化。",
                estimatedCost: "¥1000-3000"
            ))
        }
        
        // 基于损伤类型
        let damageTypes = damageCountByType
        
        if damageTypes.keys.contains(.swirlMark) {
            recommendations.append(ReportRecommendation(
                priority: .low,
                category: .polishing,
                title: "建议进行漆面抛光",
                description: "检测到旋涡纹，建议进行专业抛光处理以恢复漆面光泽。",
                estimatedCost: "¥300-800"
            ))
        }
        
        if damageTypes.keys.contains(.oxidation) {
            recommendations.append(ReportRecommendation(
                priority: .medium,
                category: .treatment,
                title: "漆面氧化处理",
                description: "检测到漆面氧化，建议使用抗氧化剂和抛光剂进行处理。",
                estimatedCost: "¥500-1500"
            ))
        }
        
        if damageTypes.keys.contains(.scratch) {
            recommendations.append(ReportRecommendation(
                priority: .medium,
                category: .repair,
                title: "划痕修复",
                description: "检测到划痕，建议根据严重程度选择修复剂处理或专业抛光。",
                estimatedCost: "¥200-1000"
            ))
        }
        
        if damageTypes.keys.contains(.stoneChip) || damageTypes.keys.contains(.paintLoss) {
            recommendations.append(ReportRecommendation(
                priority: .high,
                category: .repair,
                title: "补漆修复",
                description: "检测到掉漆或石子冲击损伤，建议尽快补漆防止生锈。",
                estimatedCost: "¥300-1500"
            ))
        }
        
        if damageTypes.keys.contains(.waterSpot) {
            recommendations.append(ReportRecommendation(
                priority: .low,
                category: .cleaning,
                title: "水渍清洁",
                description: "检测到水渍痕迹，建议使用酸性清洁剂去除并打蜡保护。",
                estimatedCost: "¥100-300"
            ))
        }
        
        if damageTypes.keys.contains(.birdDropping) {
            recommendations.append(ReportRecommendation(
                priority: .medium,
                category: .treatment,
                title: "鸟粪腐蚀处理",
                description: "检测到鸟粪腐蚀痕迹，建议立即清洁并使用漆面修复剂处理。",
                estimatedCost: "¥200-600"
            ))
        }
        
        if damageTypes.keys.contains(.clearCoatFailure) {
            recommendations.append(ReportRecommendation(
                priority: .high,
                category: .repair,
                title: "清漆层修复",
                description: "检测到清漆层失效，建议尽快重新喷涂清漆保护漆面。",
                estimatedCost: "¥1500-5000"
            ))
        }
        
        // 如果没有问题
        if recommendations.isEmpty {
            recommendations.append(ReportRecommendation(
                priority: .low,
                category: .maintenance,
                title: "漆面状况良好",
                description: "车辆漆面状况良好，建议继续保持定期护理和保养。",
                estimatedCost: "¥0"
            ))
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - Maintenance Schedule
    
    var suggestedMaintenanceSchedule: [MaintenanceTask] {
        var tasks: [MaintenanceTask] = []
        
        // 立即处理
        if criticalDamages > 0 {
            tasks.append(MaintenanceTask(
                timeframe: .immediate,
                title: "处理严重漆面损伤",
                description: "尽快修复\(criticalDamages)处严重损伤",
                isUrgent: true
            ))
        }
        
        // 一周内
        if damageCountByType.keys.contains(.birdDropping) {
            tasks.append(MaintenanceTask(
                timeframe: .oneWeek,
                title: "清洁鸟粪腐蚀痕迹",
                description: "防止酸性物质进一步腐蚀漆面",
                isUrgent: false
            ))
        }
        
        // 一月内
        if overallScore < 80 {
            tasks.append(MaintenanceTask(
                timeframe: .oneMonth,
                title: "全面漆面护理",
                description: "进行专业漆面修复和护理",
                isUrgent: false
            ))
        }
        
        // 定期保养
        tasks.append(MaintenanceTask(
            timeframe: .regular,
            title: "定期洗车打蜡",
            description: "建议每2-4周洗车，每3个月打蜡",
            isUrgent: false
        ))
        
        return tasks
    }
}

// MARK: - Report Status

enum ReportStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case completed = "completed"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .draft: return "草稿"
        case .completed: return "已完成"
        case .archived: return "已归档"
        }
    }
    
    var icon: String {
        switch self {
        case .draft: return "doc.plaintext"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    var color: String {
        switch self {
        case .draft: return "#FF9500"
        case .completed: return "#34C759"
        case .archived: return "#8E8E93"
        }
    }
}

// MARK: - Captured Photo Info

struct CapturedPhotoInfo: Identifiable, Codable {
    let id: UUID
    let position: PaintScanPosition
    let timestamp: Date
    let filename: String
    var detectionCount: Int
    
    init(
        id: UUID = UUID(),
        position: PaintScanPosition,
        timestamp: Date,
        filename: String,
        detectionCount: Int = 0
    ) {
        self.id = id
        self.position = position
        self.timestamp = timestamp
        self.filename = filename
        self.detectionCount = detectionCount
    }
}

// MARK: - Report Recommendation

struct ReportRecommendation: Identifiable {
    let id = UUID()
    let priority: RecommendationPriority
    let category: RecommendationCategory
    let title: String
    let description: String
    let estimatedCost: String
}

// MARK: - Recommendation Priority

enum RecommendationPriority: Int {
    case low = 1
    case medium = 2
    case high = 3
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#34C759"
        case .medium: return "#FF9500"
        case .high: return "#FF3B30"
        }
    }
}

// MARK: - Recommendation Category

enum RecommendationCategory: String, CaseIterable {
    case general = "general"
    case repair = "repair"
    case polishing = "polishing"
    case treatment = "treatment"
    case cleaning = "cleaning"
    case maintenance = "maintenance"
    
    var displayName: String {
        switch self {
        case .general: return "综合"
        case .repair: return "修复"
        case .polishing: return "抛光"
        case .treatment: return "护理"
        case .cleaning: return "清洁"
        case .maintenance: return "保养"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "doc.text"
        case .repair: return "wrench.fill"
        case .polishing: return "sparkles"
        case .treatment: return "shield.fill"
        case .cleaning: return "drop.fill"
        case .maintenance: return "calendar"
        }
    }
}

// MARK: - Maintenance Task

struct MaintenanceTask: Identifiable {
    let id = UUID()
    let timeframe: MaintenanceTimeframe
    let title: String
    let description: String
    let isUrgent: Bool
}

// MARK: - Maintenance Timeframe

enum MaintenanceTimeframe: String {
    case immediate = "immediate"
    case oneWeek = "oneWeek"
    case oneMonth = "oneMonth"
    case threeMonths = "threeMonths"
    case sixMonths = "sixMonths"
    case regular = "regular"
    
    var displayName: String {
        switch self {
        case .immediate: return "立即"
        case .oneWeek: return "一周内"
        case .oneMonth: return "一月内"
        case .threeMonths: return "三月内"
        case .sixMonths: return "半年内"
        case .regular: return "定期"
        }
    }
    
    var icon: String {
        switch self {
        case .immediate: return "exclamationmark.circle.fill"
        case .oneWeek: return "calendar.badge.clock"
        case .oneMonth: return "calendar"
        case .threeMonths: return "calendar.badge.plus"
        case .sixMonths: return "calendar.badge.checkmark"
        case .regular: return "arrow.clockwise"
        }
    }
    
    var color: String {
        switch self {
        case .immediate: return "#FF3B30"
        case .oneWeek: return "#FF9500"
        case .oneMonth: return "#FFCC00"
        case .threeMonths: return "#5AC8FA"
        case .sixMonths: return "#5856D6"
        case .regular: return "#34C759"
        }
    }
}

// MARK: - Report Filter

struct ReportFilter {
    var searchText: String = ""
    var status: ReportStatus?
    var dateRange: DateRange?
    var hasDamages: Bool?
    var isFavorite: Bool?
    var sortBy: ReportSortOption = .dateDesc
}

// MARK: - Date Range

struct DateRange: Hashable {
    let startDate: Date
    let endDate: Date
    
    static func last7Days() -> DateRange {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        return DateRange(startDate: start, endDate: end)
    }
    
    static func last30Days() -> DateRange {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end)!
        return DateRange(startDate: start, endDate: end)
    }
    
    static func last90Days() -> DateRange {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -90, to: end)!
        return DateRange(startDate: start, endDate: end)
    }
}

// MARK: - Report Sort Option

enum ReportSortOption: String, CaseIterable {
    case dateDesc = "dateDesc"
    case dateAsc = "dateAsc"
    case scoreDesc = "scoreDesc"
    case scoreAsc = "scoreAsc"
    case damageCountDesc = "damageCountDesc"
    
    var displayName: String {
        switch self {
        case .dateDesc: return "最新优先"
        case .dateAsc: return "最早优先"
        case .scoreDesc: return "评分从高到低"
        case .scoreAsc: return "评分从低到高"
        case .damageCountDesc: return "问题数量"
        }
    }
}

// MARK: - Report Statistics

struct ReportStatistics {
    let totalReports: Int
    let averageScore: Int
    let totalDamages: Int
    let criticalDamages: Int
    let reportsWithCriticalIssues: Int
    let mostCommonDamageType: DamageType?
    let scoreDistribution: [ScoreRange: Int]
    let monthlyTrend: [MonthData]
}

// MARK: - Score Range

enum ScoreRange: String, CaseIterable {
    case excellent = "90-100"
    case good = "75-89"
    case fair = "60-74"
    case poor = "0-59"
    
    var displayName: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "需关注"
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
    
    var range: ClosedRange<Int> {
        switch self {
        case .excellent: return 90...100
        case .good: return 75...89
        case .fair: return 60...74
        case .poor: return 0...59
        }
    }
}

// MARK: - Month Data

struct MonthData: Identifiable {
    let id = UUID()
    let month: String
    let reportCount: Int
    let averageScore: Int
    let damageCount: Int
}

// MARK: - Report Preview

extension InspectionReport {
    static var preview: InspectionReport {
        InspectionReport(
            title: "示例检测报告",
            carBrand: "宝马",
            carModel: "X5",
            licensePlate: "京A12345",
            carColor: "黑色",
            mileage: 50000,
            detectionResults: [
                DetectionResult(
                    position: .front,
                    detections: [
                        DamageDetection(
                            type: .scratch,
                            severity: .moderate,
                            boundingBox: CGRect(x: 0.3, y: 0.4, width: 0.1, height: 0.05),
                            confidence: 0.85,
                            position: .front
                        ),
                        DamageDetection(
                            type: .stoneChip,
                            severity: .minor,
                            boundingBox: CGRect(x: 0.5, y: 0.3, width: 0.05, height: 0.05),
                            confidence: 0.92,
                            position: .front
                        )
                    ],
                    overallScore: 82,
                    glossLevel: 85,
                    clarity: 80,
                    colorConsistency: 88
                )
            ],
            overallScore: 82,
            glossLevel: 85,
            clarity: 80,
            colorConsistency: 88,
            status: .completed
        )
    }
}

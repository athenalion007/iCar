import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Report Adapters

/// 报告适配器 - 将各检测模块的结果转换为统一报告格式
enum ReportAdapters {

    // MARK: - Tire Report Adapter

    static func createTireReport(from report: TireTreadReport, photos: [TirePhoto]) -> UnifiedReport {
        let builder = UnifiedReportBuilder()
            .setTitle("轮胎检测报告 - 综合评分\(report.overallHealthScore)")
            .setInspectionType(.tire)
            .setVehicleInfo(brand: "未知品牌", model: "未知车型")
            .setScore(report.overallHealthScore, status: mapTireStatus(report.overallStatus))

        // 添加各轮胎区块
        for (index, result) in report.results.enumerated() {
            let section = ReportSection(
                title: result.position.displayName,
                subtitle: "健康状况: \(result.healthStatus.displayName)",
                icon: result.position.icon,
                order: index,
                items: [
                    ReportItem(
                        title: "花纹深度",
                        status: mapTireDepthStatus(result.averageDepth),
                        value: "\(String(format: "%.1f", result.averageDepth))mm",
                        referenceRange: "≥1.6mm"
                    ),
                    ReportItem(
                        title: "磨损模式",
                        status: result.wearPattern == .normal ? .normal : .warning,
                        value: result.wearPattern.displayName
                    ),
                    ReportItem(
                        title: "健康评分",
                        status: mapTireScoreStatus(result.healthScore),
                        value: "\(result.healthScore)分"
                    )
                ],
                metrics: [
                    ReportMetric(name: "花纹深度", value: result.averageDepth, unit: "mm", maxValue: 8.0, icon: "ruler"),
                    ReportMetric(name: "健康评分", value: Double(result.healthScore), unit: "分", maxValue: 100.0, icon: "heart.fill")
                ]
            )
            _ = builder.addSection(section)
        }

        // 添加建议
        if report.overallHealthScore < 60 {
            let recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.high,
                category: UnifiedRecommendationCategory.replacement,
                title: "建议更换轮胎",
                description: "轮胎整体状况较差，建议尽快更换以确保行车安全。",
                estimatedCost: "¥2000-8000"
            )
            _ = builder.addRecommendation(recommendation)
        } else if report.overallHealthScore < 80 {
            let recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.medium,
                category: UnifiedRecommendationCategory.maintenance,
                title: "定期检查轮胎",
                description: "轮胎状况一般，建议定期检查并注意磨损情况。",
                estimatedCost: "¥0"
            )
            _ = builder.addRecommendation(recommendation)
        }

        // 添加维护任务
        if report.results.contains(where: { $0.healthStatus == .critical }) {
            let task = UnifiedMaintenanceTask(
                timeframe: UnifiedMaintenanceTimeframe.immediate,
                title: "更换轮胎",
                description: "存在需要立即更换的轮胎",
                isUrgent: true
            )
            _ = builder.addMaintenanceTask(task)
        }

        return builder.build()
    }

    // MARK: - Engine Report Adapter

    static func createEngineReport(from result: EngineDiagnosisResult) -> UnifiedReport {
        let builder = UnifiedReportBuilder()
            .setTitle("引擎听诊报告 - \(result.faultType.rawValue)")
            .setInspectionType(.engine)
            .setVehicleInfo(brand: "未知品牌", model: "未知车型")
            .setScore(Int(result.confidence * 100), status: mapEngineStatus(result.severity))

        // 诊断结果区块
        let diagnosisSection = ReportSection(
            title: "诊断结果",
            icon: "stethoscope",
            order: 0,
            items: [
                ReportItem(
                    title: "故障类型",
                    status: mapEngineSeverity(result.severity),
                    value: result.faultType.rawValue
                ),
                ReportItem(
                    title: "严重程度",
                    status: mapEngineSeverity(result.severity),
                    value: result.severity.rawValue
                ),
                ReportItem(
                    title: "置信度",
                    status: .info,
                    value: result.formattedConfidence
                )
            ],
            summary: result.recommendedAction
        )
        _ = builder.addSection(diagnosisSection)

        // 频谱分析区块
        let spectrum = result.spectrumData
        let spectrumSection = ReportSection(
            title: "频谱分析",
            icon: "waveform",
            order: 1,
            items: [
                ReportItem(
                    title: "主频率",
                    status: .info,
                    value: "\(String(format: "%.1f", spectrum.dominantFrequency))Hz"
                )
            ]
        )
        _ = builder.addSection(spectrumSection)

        // 添加建议
        let recommendation: UnifiedReportRecommendation
        switch result.severity {
        case .severe:
            recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.high,
                category: UnifiedRecommendationCategory.repair,
                title: "立即检修",
                description: result.recommendedAction,
                estimatedCost: "¥1000-5000"
            )
        case .moderate:
            recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.medium,
                category: UnifiedRecommendationCategory.repair,
                title: "尽快检修",
                description: result.recommendedAction,
                estimatedCost: "¥500-2000"
            )
        case .minor:
            recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.low,
                category: UnifiedRecommendationCategory.maintenance,
                title: "注意观察",
                description: result.recommendedAction,
                estimatedCost: "¥0-500"
            )
        case .normal:
            recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.low,
                category: UnifiedRecommendationCategory.maintenance,
                title: "引擎状况良好",
                description: "继续定期保养，保持当前状态。",
                estimatedCost: "¥0"
            )
        }
        _ = builder.addRecommendation(recommendation)

        return builder.build()
    }

    // MARK: - Suspension Report Adapter

    static func createSuspensionReport(from result: SuspensionDiagnosisResult) -> UnifiedReport {
        let builder = UnifiedReportBuilder()
            .setTitle("悬挂监测报告 - \(result.status.rawValue)")
            .setInspectionType(.suspension)
            .setVehicleInfo(brand: "未知品牌", model: "未知车型")
            .setScore(result.overallScore, status: mapSuspensionStatus(result.status))

        // 总体状况区块
        let statusSection = ReportSection(
            title: "悬挂系统状况",
            icon: "arrow.up.and.down",
            order: 0,
            items: [
                ReportItem(
                    title: "系统状态",
                    status: mapSuspensionStatusToItem(result.status),
                    value: result.status.rawValue
                ),
                ReportItem(
                    title: "综合评分",
                    status: mapSuspensionScoreStatus(result.overallScore),
                    value: "\(result.overallScore)分"
                )
            ],
            metrics: [
                ReportMetric(name: "稳定性", value: Double(result.overallScore), unit: "%", maxValue: 100.0)
            ]
        )
        _ = builder.addSection(statusSection)

        // 发现问题区块
        if !result.detectedIssues.isEmpty {
            let issuesSection = ReportSection(
                title: "检测到的问题",
                icon: "exclamationmark.triangle",
                order: 1,
                items: result.detectedIssues.map { issue in
                    ReportItem(
                        title: issue.rawValue,
                        status: .warning
                    )
                }
            )
            _ = builder.addSection(issuesSection)
        }

        // 添加建议
        if result.overallScore < 60 {
            let recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.high,
                category: UnifiedRecommendationCategory.repair,
                title: "悬挂系统检修",
                description: "悬挂系统存在严重问题，建议立即检修。",
                estimatedCost: "¥2000-8000"
            )
            _ = builder.addRecommendation(recommendation)
        } else if !result.detectedIssues.isEmpty {
            let recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.medium,
                category: UnifiedRecommendationCategory.repair,
                title: "悬挂系统维护",
                description: "检测到\(result.detectedIssues.count)个问题，建议检查。",
                estimatedCost: "¥500-3000"
            )
            _ = builder.addRecommendation(recommendation)
        }

        return builder.build()
    }

    // MARK: - AC Report Adapter

    static func createACReport(from result: ACDiagnosisResult) -> UnifiedReport {
        let builder = UnifiedReportBuilder()
            .setTitle("空调诊断报告 - \(result.status.rawValue)")
            .setInspectionType(.ac)
            .setVehicleInfo(brand: "未知品牌", model: "未知车型")
            .setScore(result.overallScore, status: mapACStatus(result.status))

        // 系统状态区块
        let statusSection = ReportSection(
            title: "空调系统状态",
            icon: "snowflake",
            order: 0,
            items: [
                ReportItem(
                    title: "系统状态",
                    status: mapACStatusToItem(result.status),
                    value: result.status.rawValue
                ),
                ReportItem(
                    title: "制冷效果",
                    status: result.outletTemperature != nil && result.outletTemperature! < 10 ? .normal : .warning,
                    value: result.outletTemperature != nil ? "\(result.outletTemperature!)°C" : "未知"
                )
            ]
        )
        _ = builder.addSection(statusSection)

        // 发现问题区块
        if !result.detectedIssues.isEmpty {
            let issuesSection = ReportSection(
                title: "检测到的问题",
                icon: "exclamationmark.triangle",
                order: 1,
                items: result.detectedIssues.map { issue in
                    ReportItem(
                        title: issue.rawValue,
                        status: .warning
                    )
                }
            )
            _ = builder.addSection(issuesSection)
        }

        // 添加建议
        if result.overallScore < 60 {
            let recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.high,
                category: UnifiedRecommendationCategory.repair,
                title: "空调系统维修",
                description: "空调系统存在严重问题，建议立即维修。",
                estimatedCost: "¥1000-5000"
            )
            _ = builder.addRecommendation(recommendation)
        } else if !result.detectedIssues.isEmpty {
            let recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.medium,
                category: UnifiedRecommendationCategory.repair,
                title: "空调系统检查",
                description: "建议进行空调系统全面检查。",
                estimatedCost: "¥300-1500"
            )
            _ = builder.addRecommendation(recommendation)
        } else {
            let recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.low,
                category: UnifiedRecommendationCategory.maintenance,
                title: "空调系统良好",
                description: "空调系统运行正常，继续保持定期保养。",
                estimatedCost: "¥0"
            )
            _ = builder.addRecommendation(recommendation)
        }

        return builder.build()
    }

    // MARK: - Paint Report Adapter

    static func createPaintReport(from result: PaintScanResult, image: UIImage) -> UnifiedReport {
        let builder = UnifiedReportBuilder()
            .setTitle("漆面检测报告 - \(result.status) - \(result.score)分")
            .setInspectionType(.paint)
            .setVehicleInfo(brand: "待填写", model: "待填写")
            .setScore(result.score, status: mapPaintStatus(result.status))

        // 检测结果区块
        var detectionItems: [ReportItem] = []
        for damage in result.detectedDamages {
            detectionItems.append(ReportItem(
                title: damage.type.rawValue,
                description: "位置: \(damage.position.rawValue)",
                status: mapDamageSeverity(damage.severity),
                severity: mapItemSeverity(damage.severity),
                confidence: damage.confidence
            ))
        }

        if detectionItems.isEmpty {
            detectionItems.append(ReportItem(
                title: "未检测到明显问题",
                status: .normal
            ))
        }

        let detectionSection = ReportSection(
            title: "漆面检测结果",
            icon: "paintpalette",
            order: 0,
            items: detectionItems,
            metrics: [
                ReportMetric(name: "光泽度", value: Double(result.score) / 100.0, unit: nil, maxValue: 1.0),
                ReportMetric(name: "清晰度", value: Double(result.score) / 100.0, unit: nil, maxValue: 1.0)
            ]
        )
        _ = builder.addSection(detectionSection)

        // 添加建议
        if result.score < 60 {
            let recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.high,
                category: UnifiedRecommendationCategory.repair,
                title: "漆面修复",
                description: "漆面状况较差，建议进行专业修复。",
                estimatedCost: "¥2000-8000"
            )
            _ = builder.addRecommendation(recommendation)
        } else if !result.detectedDamages.isEmpty {
            let recommendation = UnifiedReportRecommendation(
                priority: UnifiedRecommendationPriority.medium,
                category: UnifiedRecommendationCategory.polishing,
                title: "漆面护理",
                description: "检测到\(result.detectedDamages.count)处问题，建议进行护理。",
                estimatedCost: "¥500-2000"
            )
            _ = builder.addRecommendation(recommendation)
        }

        return builder.build()
    }

    // MARK: - Mapping Helpers

    private static func mapTireStatus(_ status: TireHealthStatus) -> UnifiedInspectionStatus {
        switch status {
        case .excellent: return .excellent
        case .good: return .good
        case .fair: return .fair
        case .poor: return .poor
        case .critical: return .critical
        }
    }

    private static func mapTireDepthStatus(_ depth: Double) -> ReportItemStatus {
        if depth >= 3.0 { return .normal }
        if depth >= 1.6 { return .warning }
        return .critical
    }

    private static func mapTireScoreStatus(_ score: Int) -> ReportItemStatus {
        if score >= 80 { return .normal }
        if score >= 60 { return .warning }
        return .critical
    }

    private static func mapEngineStatus(_ severity: FaultSeverity) -> UnifiedInspectionStatus {
        switch severity {
        case .severe: return .critical
        case .moderate: return .poor
        case .minor: return .fair
        case .normal: return .good
        }
    }

    private static func mapEngineSeverity(_ severity: FaultSeverity) -> ReportItemStatus {
        switch severity {
        case .severe: return .critical
        case .moderate: return .warning
        case .minor: return .info
        case .normal: return .normal
        }
    }

    private static func mapSuspensionStatus(_ status: SuspensionStatus) -> UnifiedInspectionStatus {
        switch status {
        case .excellent: return .excellent
        case .good: return .good
        case .fair: return .fair
        case .poor: return .poor
        case .critical: return .critical
        }
    }

    private static func mapSuspensionStatusToItem(_ status: SuspensionStatus) -> ReportItemStatus {
        switch status {
        case .excellent, .good: return .normal
        case .fair: return .warning
        case .poor: return .warning
        case .critical: return .critical
        }
    }

    private static func mapSuspensionScoreStatus(_ score: Int) -> ReportItemStatus {
        if score >= 80 { return .normal }
        if score >= 60 { return .warning }
        return .critical
    }

    private static func mapACStatus(_ status: ACSystemStatus) -> UnifiedInspectionStatus {
        switch status {
        case .excellent: return .excellent
        case .good: return .good
        case .fair: return .fair
        case .poor: return .poor
        case .critical: return .critical
        }
    }

    private static func mapACStatusToItem(_ status: ACSystemStatus) -> ReportItemStatus {
        switch status {
        case .excellent, .good: return .normal
        case .fair: return .warning
        case .poor: return .warning
        case .critical: return .critical
        }
    }

    private static func mapPaintStatus(_ status: String) -> UnifiedInspectionStatus {
        switch status {
        case "优秀": return .excellent
        case "良好": return .good
        case "一般": return .fair
        case "需关注": return .poor
        default: return .good
        }
    }

    private static func mapDamageSeverity(_ severity: DamageSeverity) -> ReportItemStatus {
        switch severity {
        case .none: return .normal
        case .minor: return .warning
        case .moderate: return .warning
        case .severe: return .critical
        }
    }

    private static func mapItemSeverity(_ severity: DamageSeverity) -> ItemSeverity? {
        switch severity {
        case .none: return nil
        case .minor: return .minor
        case .moderate: return .moderate
        case .severe: return .severe
        }
    }
}

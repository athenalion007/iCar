import Foundation
#if canImport(UIKit)
import UIKit
#endif
import PDFKit
import SwiftUI

// MARK: - Unified Report Service

@MainActor
final class UnifiedReportService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var reports: [UnifiedReport] = []
    @Published var isGeneratingPDF = false
    @Published var pdfGenerationProgress: Double = 0
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let reportsDirectory: URL
    private let imagesDirectory: URL
    private let pdfsDirectory: URL
    private let reportsFileName = "unified_reports.json"
    
    // MARK: - Singleton
    
    static let shared = UnifiedReportService()
    
    private init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        reportsDirectory = documentsDirectory.appendingPathComponent("Reports", isDirectory: true)
        imagesDirectory = reportsDirectory.appendingPathComponent("Images", isDirectory: true)
        pdfsDirectory = reportsDirectory.appendingPathComponent("PDFs", isDirectory: true)
        
        try? fileManager.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: pdfsDirectory, withIntermediateDirectories: true)
        
        loadReports()
    }
    
    // MARK: - Report Management
    
    /// 创建新报告
    func createReport(_ report: UnifiedReport) -> UnifiedReport {
        var newReport = report
        
        reports.insert(newReport, at: 0)
        saveReports()
        return newReport
    }
    
    /// 使用Builder创建报告
    func createReport(using builder: UnifiedReportBuilder) -> UnifiedReport {
        let report = builder.build()
        return createReport(report)
    }
    
    /// 更新报告
    func updateReport(_ report: UnifiedReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            var updatedReport = report
            updatedReport.updatedAt = Date()
            reports[index] = updatedReport
            saveReports()
        }
    }
    
    /// 删除报告
    func deleteReport(_ report: UnifiedReport) {
        // 删除PDF
        let pdfURL = pdfsDirectory.appendingPathComponent("\(report.id).pdf")
        try? fileManager.removeItem(at: pdfURL)
        
        reports.removeAll { $0.id == report.id }
        saveReports()
    }
    
    /// 切换收藏状态
    func toggleFavorite(for report: UnifiedReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            reports[index].isFavorite.toggle()
            saveReports()
        }
    }
    
    /// 添加标签
    func addTag(_ tag: String, to report: UnifiedReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            if !reports[index].tags.contains(tag) {
                reports[index].tags.append(tag)
                saveReports()
            }
        }
    }
    
    // MARK: - Filtering
    
    func filterReports(
        searchText: String = "",
        type: UnifiedInspectionType? = nil
    ) -> [UnifiedReport] {
        var filtered = reports
        
        // 搜索文本
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { report in
                report.displayTitle.lowercased().contains(searchLower) ||
                report.licensePlate.lowercased().contains(searchLower) ||
                report.carBrand.lowercased().contains(searchLower) ||
                report.tags.contains(where: { $0.lowercased().contains(searchLower) })
            }
        }
        
        // 类型筛选
        if let type = type {
            filtered = filtered.filter { $0.inspectionType == type }
        }
        
        // 排序 - 默认按日期降序
        filtered.sort { $0.createdAt > $1.createdAt }
        
        return filtered
    }
    
    // MARK: - Statistics
    
    func getStatistics() -> UnifiedReportStatistics {
        let totalReports = reports.count
        let avgScore = totalReports > 0
            ? reports.reduce(0) { $0 + $1.overallScore } / totalReports
            : 0
        let totalIssues = reports.reduce(0) { $0 + $1.totalIssues }
        let criticalIssues = reports.reduce(0) { $0 + $1.criticalIssues }
        
        // 按类型统计
        var typeDistribution: [UnifiedInspectionType: Int] = [:]
        for report in reports {
            typeDistribution[report.inspectionType, default: 0] += 1
        }
        
        return UnifiedReportStatistics(
            totalReports: totalReports,
            averageScore: avgScore,
            totalIssues: totalIssues,
            criticalIssues: criticalIssues,
            typeDistribution: typeDistribution
        )
    }
    
    func getStatistics(for type: UnifiedInspectionType) -> UnifiedReportStatistics {
        let typeReports = reports.filter { $0.inspectionType == type }
        let totalReports = typeReports.count
        let avgScore = totalReports > 0
            ? typeReports.reduce(0) { $0 + $1.overallScore } / totalReports
            : 0
        let totalIssues = typeReports.reduce(0) { $0 + $1.totalIssues }
        let criticalIssues = typeReports.reduce(0) { $0 + $1.criticalIssues }
        
        return UnifiedReportStatistics(
            totalReports: totalReports,
            averageScore: avgScore,
            totalIssues: totalIssues,
            criticalIssues: criticalIssues,
            typeDistribution: [type: totalReports]
        )
    }
    
    // MARK: - Private Methods
    
    private func saveReports() {
        let url = reportsDirectory.appendingPathComponent(reportsFileName)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(reports)
            try data.write(to: url)
        } catch {
            print("Failed to save reports: \(error)")
        }
    }
    
    private func loadReports() {
        let url = reportsDirectory.appendingPathComponent(reportsFileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            reports = try decoder.decode([UnifiedReport].self, from: data)
        } catch {
            print("Failed to load reports: \(error)")
        }
    }
}

// MARK: - Unified Report Statistics

struct UnifiedReportStatistics {
    let totalReports: Int
    let averageScore: Int
    let totalIssues: Int
    let criticalIssues: Int
    let typeDistribution: [UnifiedInspectionType: Int]
}

import Foundation
#if canImport(UIKit)
import UIKit
import SwiftUI
#endif
import PDFKit
import UniformTypeIdentifiers

// MARK: - Report Service

@MainActor
final class ReportService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var reports: [InspectionReport] = []
    @Published var isGeneratingPDF = false
    @Published var pdfGenerationProgress: Double = 0
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let reportsDirectory: URL
    private let imagesDirectory: URL
    private let pdfsDirectory: URL
    
    private let reportsFileName = "inspection_reports.json"
    
    // MARK: - Singleton
    
    static let shared = ReportService()
    
    private init() {
        // 设置存储目录
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        reportsDirectory = documentsDirectory.appendingPathComponent("Reports", isDirectory: true)
        imagesDirectory = reportsDirectory.appendingPathComponent("Images", isDirectory: true)
        pdfsDirectory = reportsDirectory.appendingPathComponent("PDFs", isDirectory: true)
        
        // 创建目录
        try? fileManager.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: pdfsDirectory, withIntermediateDirectories: true)
        
        // 加载已有报告
        loadReports()
    }
    
    // MARK: - Report Management
    
    /// 创建新报告
    func createReport(
        title: String,
        car: Car? = nil,
        carBrand: String,
        carModel: String,
        licensePlate: String,
        carColor: String,
        vin: String = "",
        mileage: Double = 0,
        detectionResults: [DetectionResult],
        capturedPhotos: [CapturedPhoto],
        notes: String = ""
    ) -> InspectionReport {
        // 保存图片
        var photoInfos: [CapturedPhotoInfo] = []
        for photo in capturedPhotos {
            if let filename = saveImage(photo.image, id: photo.id) {
                let detectionCount = detectionResults
                    .first { $0.position == photo.position }?
                    .detections.count ?? 0
                
                let photoInfo = CapturedPhotoInfo(
                    id: photo.id,
                    position: photo.position,
                    timestamp: photo.timestamp,
                    filename: filename,
                    detectionCount: detectionCount
                )
                photoInfos.append(photoInfo)
            }
        }
        
        // 计算综合评分
        let overallScore = calculateOverallScore(from: detectionResults)
        let avgGloss = detectionResults.map { $0.glossLevel }.reduce(0, +) / Double(max(detectionResults.count, 1))
        let avgClarity = detectionResults.map { $0.clarity }.reduce(0, +) / Double(max(detectionResults.count, 1))
        let avgColorConsistency = detectionResults.map { $0.colorConsistency }.reduce(0, +) / Double(max(detectionResults.count, 1))
        
        let report = InspectionReport(
            title: title,
            notes: notes,
            carId: car?.id,
            carBrand: carBrand,
            carModel: carModel,
            licensePlate: licensePlate,
            carColor: carColor,
            vin: vin,
            mileage: mileage,
            detectionResults: detectionResults,
            capturedPhotos: photoInfos,
            overallScore: overallScore,
            glossLevel: avgGloss,
            clarity: avgClarity,
            colorConsistency: avgColorConsistency,
            status: .completed
        )
        
        reports.insert(report, at: 0)
        saveReports()
        
        return report
    }
    
    /// 更新报告
    func updateReport(_ report: InspectionReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            var updatedReport = report
            updatedReport.updatedAt = Date()
            reports[index] = updatedReport
            saveReports()
        }
    }
    
    /// 删除报告
    func deleteReport(_ report: InspectionReport) {
        // 删除关联的图片
        for photoInfo in report.capturedPhotos {
            deleteImage(filename: photoInfo.filename)
        }
        
        // 删除PDF文件
        let pdfURL = pdfsDirectory.appendingPathComponent("\(report.id).pdf")
        try? fileManager.removeItem(at: pdfURL)
        
        // 从列表中移除
        reports.removeAll { $0.id == report.id }
        saveReports()
    }
    
    /// 切换收藏状态
    func toggleFavorite(for report: InspectionReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            reports[index].isFavorite.toggle()
            saveReports()
        }
    }
    
    /// 更新报告状态
    func updateStatus(for report: InspectionReport, to status: ReportStatus) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            reports[index].status = status
            reports[index].updatedAt = Date()
            saveReports()
        }
    }
    
    /// 添加标签
    func addTag(_ tag: String, to report: InspectionReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            if !reports[index].tags.contains(tag) {
                reports[index].tags.append(tag)
                saveReports()
            }
        }
    }
    
    /// 移除标签
    func removeTag(_ tag: String, from report: InspectionReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            reports[index].tags.removeAll { $0 == tag }
            saveReports()
        }
    }
    
    // MARK: - PDF Generation
    
    /// 生成PDF报告
    func generatePDF(for report: InspectionReport) async throws -> URL {
        isGeneratingPDF = true
        pdfGenerationProgress = 0
        
        defer {
            isGeneratingPDF = false
            pdfGenerationProgress = 1.0
        }
        
        let pdfURL = pdfsDirectory.appendingPathComponent("\(report.id).pdf")
        
        // 创建PDF文档
        let pdfDocument = PDFDocument()
        
        // 第1页: 封面
        if let coverPage = createCoverPage(for: report) {
            pdfDocument.insert(coverPage, at: 0)
        }
        pdfGenerationProgress = 0.1
        
        // 第2页: 概览
        if let overviewPage = createOverviewPage(for: report) {
            pdfDocument.insert(overviewPage, at: 1)
        }
        pdfGenerationProgress = 0.2
        
        // 第3页: 详细结果
        if let detailPage = createDetailPage(for: report) {
            pdfDocument.insert(detailPage, at: 2)
        }
        pdfGenerationProgress = 0.4
        
        // 第4页: 建议
        if let recommendationPage = createRecommendationPage(for: report) {
            pdfDocument.insert(recommendationPage, at: 3)
        }
        pdfGenerationProgress = 0.6
        
        // 添加图片页
        var pageIndex = 4
        for (index, photoInfo) in report.capturedPhotos.enumerated() {
            if let image = loadImage(filename: photoInfo.filename) {
                if let photoPage = createPhotoPage(
                    image: image,
                    photoInfo: photoInfo,
                    detectionResult: report.detectionResults.first { $0.position == photoInfo.position }
                ) {
                    pdfDocument.insert(photoPage, at: pageIndex)
                    pageIndex += 1
                }
            }
            pdfGenerationProgress = 0.6 + (0.3 * Double(index + 1) / Double(report.capturedPhotos.count))
        }
        
        // 保存PDF
        pdfDocument.write(to: pdfURL)
        
        return pdfURL
    }
    
    /// 获取PDF文件URL（如果已存在）
    func getPDFURL(for report: InspectionReport) -> URL? {
        let pdfURL = pdfsDirectory.appendingPathComponent("\(report.id).pdf")
        return fileManager.fileExists(atPath: pdfURL.path) ? pdfURL : nil
    }
    
    /// 分享PDF
    func sharePDF(for report: InspectionReport) async throws -> URL {
        // 如果PDF不存在，先生成
        let pdfURL: URL
        if let existingURL = getPDFURL(for: report) {
            pdfURL = existingURL
        } else {
            pdfURL = try await generatePDF(for: report)
        }
        
        return pdfURL
    }
    
    // MARK: - Filtering & Searching
    
    /// 筛选报告
    func filterReports(using filter: ReportFilter) -> [InspectionReport] {
        var filtered = reports
        
        // 搜索文本
        if !filter.searchText.isEmpty {
            let searchLower = filter.searchText.lowercased()
            filtered = filtered.filter { report in
                report.displayTitle.lowercased().contains(searchLower) ||
                report.licensePlate.lowercased().contains(searchLower) ||
                report.carBrand.lowercased().contains(searchLower) ||
                report.carModel.lowercased().contains(searchLower) ||
                report.tags.contains(where: { $0.lowercased().contains(searchLower) })
            }
        }
        
        // 状态筛选
        if let status = filter.status {
            filtered = filtered.filter { $0.status == status }
        }
        
        // 日期范围
        if let dateRange = filter.dateRange {
            filtered = filtered.filter {
                $0.createdAt >= dateRange.startDate && $0.createdAt <= dateRange.endDate
            }
        }
        
        // 是否有损伤
        if let hasDamages = filter.hasDamages {
            filtered = filtered.filter { ($0.totalDamages > 0) == hasDamages }
        }
        
        // 收藏
        if let isFavorite = filter.isFavorite {
            filtered = filtered.filter { $0.isFavorite == isFavorite }
        }
        
        // 排序
        switch filter.sortBy {
        case .dateDesc:
            filtered.sort { $0.createdAt > $1.createdAt }
        case .dateAsc:
            filtered.sort { $0.createdAt < $1.createdAt }
        case .scoreDesc:
            filtered.sort { $0.overallScore > $1.overallScore }
        case .scoreAsc:
            filtered.sort { $0.overallScore < $1.overallScore }
        case .damageCountDesc:
            filtered.sort { $0.totalDamages > $1.totalDamages }
        }
        
        return filtered
    }
    
    /// 获取报告统计
    func getStatistics() -> ReportStatistics {
        let totalReports = reports.count
        let avgScore = totalReports > 0
            ? reports.reduce(0) { $0 + $1.overallScore } / totalReports
            : 0
        let totalDamages = reports.reduce(0) { $0 + $1.totalDamages }
        let criticalDamages = reports.reduce(0) { $0 + $1.criticalDamages }
        let reportsWithCritical = reports.filter { $0.hasCriticalIssues }.count
        
        // 最常见的损伤类型
        var allDamageTypes: [DamageType: Int] = [:]
        for report in reports {
            for (type, count) in report.damageCountByType {
                allDamageTypes[type, default: 0] += count
            }
        }
        let mostCommonType = allDamageTypes.max { $0.value < $1.value }?.key
        
        // 评分分布
        var scoreDistribution: [ScoreRange: Int] = [:]
        for range in ScoreRange.allCases {
            scoreDistribution[range] = reports.filter { range.range.contains($0.overallScore) }.count
        }
        
        // 月度趋势
        let monthlyTrend = calculateMonthlyTrend()
        
        return ReportStatistics(
            totalReports: totalReports,
            averageScore: avgScore,
            totalDamages: totalDamages,
            criticalDamages: criticalDamages,
            reportsWithCriticalIssues: reportsWithCritical,
            mostCommonDamageType: mostCommonType,
            scoreDistribution: scoreDistribution,
            monthlyTrend: monthlyTrend
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateOverallScore(from results: [DetectionResult]) -> Int {
        guard !results.isEmpty else { return 0 }
        let totalScore = results.reduce(0) { $0 + $1.overallScore }
        return totalScore / results.count
    }
    
    private func calculateMonthlyTrend() -> [MonthData] {
        let calendar = Calendar.current
        var monthlyData: [String: (count: Int, totalScore: Int, damages: Int)] = [:]
        
        for report in reports {
            let components = calendar.dateComponents([.year, .month], from: report.createdAt)
            let key = "\(components.year ?? 0)-\(String(format: "%02d", components.month ?? 0))"
            
            var data = monthlyData[key] ?? (0, 0, 0)
            data.count += 1
            data.totalScore += report.overallScore
            data.damages += report.totalDamages
            monthlyData[key] = data
        }
        
        return monthlyData
            .sorted { $0.key < $1.key }
            .map { key, data in
                MonthData(
                    month: key,
                    reportCount: data.count,
                    averageScore: data.count > 0 ? data.totalScore / data.count : 0,
                    damageCount: data.damages
                )
            }
    }
    
    // MARK: - Data Export & Clear
    
    /// 导出所有报告为JSON
    func exportReports() -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(reports)) ?? Data()
    }
    
    /// 清除所有报告
    func clearAllReports() {
        // 删除所有图片
        for report in reports {
            for photo in report.capturedPhotos {
                deleteImage(filename: photo.filename)
            }
            // 删除PDF
            let pdfURL = pdfsDirectory.appendingPathComponent("\(report.id).pdf")
            try? fileManager.removeItem(at: pdfURL)
        }
        
        // 清空报告列表
        reports.removeAll()
        saveReports()
    }
    
    // MARK: - File Operations
    
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
            reports = try decoder.decode([InspectionReport].self, from: data)
        } catch {
            print("Failed to load reports: \(error)")
        }
    }
    
    private func saveImage(_ image: UIImage, id: UUID) -> String? {
        let filename = "\(id.uuidString).jpg"
        let url = imagesDirectory.appendingPathComponent(filename)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    private func loadImage(filename: String) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    private func deleteImage(filename: String) {
        let url = imagesDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - PDF Page Creation
    
    private func createCoverPage(for report: InspectionReport) -> PDFPage? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { context in
            // 白色背景
            UIColor.white.setFill()
            context.fill(pageRect)
            
            // 标题
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: UIColor.black
            ]
            let title = "漆面检测报告"
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(at: CGPoint(x: (pageWidth - titleSize.width) / 2, y: 100), withAttributes: titleAttributes)
            
            // 副标题
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor.darkGray
            ]
            let subtitle = report.displayTitle
            let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
            subtitle.draw(at: CGPoint(x: (pageWidth - subtitleSize.width) / 2, y: 150), withAttributes: subtitleAttributes)
            
            // 车辆信息
            let infoY: CGFloat = 250
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            
            let infoItems = [
                "车辆: \(report.carBrand) \(report.carModel)",
                "车牌: \(report.licensePlate)",
                "颜色: \(report.carColor)",
                "里程: \(String(format: "%.0f", report.mileage)) km",
                "日期: \(report.formattedDate)"
            ]
            
            for (index, item) in infoItems.enumerated() {
                item.draw(at: CGPoint(x: 100, y: infoY + CGFloat(index) * 30), withAttributes: infoAttributes)
            }
            
            // 评分
            let scoreAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 72),
                .foregroundColor: UIColor(Color(hex: report.scoreColor))
            ]
            let scoreText = "\(report.overallScore)"
            let scoreSize = scoreText.size(withAttributes: scoreAttributes)
            scoreText.draw(at: CGPoint(x: (pageWidth - scoreSize.width) / 2, y: 500), withAttributes: scoreAttributes)
            
            // 评分标签
            let scoreLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor.darkGray
            ]
            let scoreLabel = report.scoreDescription
            let scoreLabelSize = scoreLabel.size(withAttributes: scoreLabelAttributes)
            scoreLabel.draw(at: CGPoint(x: (pageWidth - scoreLabelSize.width) / 2, y: 580), withAttributes: scoreLabelAttributes)
        }
        
        guard let cgImage = image.cgImage else { return nil }
        return PDFPage(image: UIImage(cgImage: cgImage))
    }
    
    private func createOverviewPage(for report: InspectionReport) -> PDFPage? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            
            // 页面标题
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            "检测概览".draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
            
            // 统计数据
            let statsY: CGFloat = 120
            let statAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            
            let stats = [
                "总体评分: \(report.overallScore)/100",
                "检测部位: \(report.detectionResults.count) 个",
                "发现问题: \(report.totalDamages) 处",
                "严重问题: \(report.criticalDamages) 处",
                "光泽度: \(String(format: "%.1f", report.glossLevel))/100",
                "清晰度: \(String(format: "%.1f", report.clarity))/100",
                "色彩一致性: \(String(format: "%.1f", report.colorConsistency))/100"
            ]
            
            for (index, stat) in stats.enumerated() {
                stat.draw(at: CGPoint(x: 50, y: statsY + CGFloat(index) * 35), withAttributes: statAttributes)
            }
            
            // 问题分布
            if !report.damageCountByType.isEmpty {
                let distributionY: CGFloat = 400
                let distributionTitle: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: UIColor.black
                ]
                "问题类型分布".draw(at: CGPoint(x: 50, y: distributionY), withAttributes: distributionTitle)
                
                let itemAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.darkGray
                ]
                
                for (index, (type, count)) in report.damageCountByType.sorted(by: { $0.value > $1.value }).enumerated() {
                    let text = "\(type.rawValue): \(count) 处"
                    text.draw(at: CGPoint(x: 50, y: distributionY + 35 + CGFloat(index) * 25), withAttributes: itemAttributes)
                }
            }
        }
        
        guard let cgImage = image.cgImage else { return nil }
        return PDFPage(image: UIImage(cgImage: cgImage))
    }
    
    private func createDetailPage(for report: InspectionReport) -> PDFPage? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            "详细检测结果".draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
            
            var currentY: CGFloat = 100
            let itemAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            for result in report.detectionResults {
                if currentY > pageHeight - 100 { break }
                
                // 位置名称
                let positionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ]
                "\(result.position.name) - 评分: \(result.overallScore)".draw(
                    at: CGPoint(x: 50, y: currentY),
                    withAttributes: positionAttributes
                )
                currentY += 25
                
                // 检测到的损伤
                if result.detections.isEmpty {
                    "  未发现明显问题".draw(at: CGPoint(x: 50, y: currentY), withAttributes: itemAttributes)
                    currentY += 20
                } else {
                    for detection in result.detections {
                        let text = "  • \(detection.type.rawValue) (\(detection.severity.rawValue)) - 置信度: \(detection.formattedConfidence)"
                        text.draw(at: CGPoint(x: 50, y: currentY), withAttributes: itemAttributes)
                        currentY += 20
                    }
                }
                
                currentY += 15
            }
        }
        
        guard let cgImage = image.cgImage else { return nil }
        return PDFPage(image: UIImage(cgImage: cgImage))
    }
    
    private func createRecommendationPage(for report: InspectionReport) -> PDFPage? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            "护理建议".draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
            
            var currentY: CGFloat = 100
            
            for recommendation in report.recommendations.prefix(6) {
                if currentY > pageHeight - 120 { break }
                
                // 优先级标签
                let priorityAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: UIColor(Color(hex: recommendation.priority.color))
                ]
                "[\(recommendation.priority.displayName)]".draw(
                    at: CGPoint(x: 50, y: currentY),
                    withAttributes: priorityAttributes
                )
                
                // 标题
                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ]
                recommendation.title.draw(at: CGPoint(x: 100, y: currentY), withAttributes: titleAttr)
                currentY += 22
                
                // 描述
                let descAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.darkGray
                ]
                let descRect = CGRect(x: 50, y: currentY, width: pageWidth - 100, height: 60)
                recommendation.description.draw(in: descRect, withAttributes: descAttributes)
                currentY += 50
                
                // 预估费用
                let costAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.systemBlue
                ]
                "预估费用: \(recommendation.estimatedCost)".draw(
                    at: CGPoint(x: 50, y: currentY),
                    withAttributes: costAttributes
                )
                currentY += 35
            }
        }
        
        guard let cgImage = image.cgImage else { return nil }
        return PDFPage(image: UIImage(cgImage: cgImage))
    }
    
    private func createPhotoPage(image: UIImage, photoInfo: CapturedPhotoInfo, detectionResult: DetectionResult?) -> PDFPage? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let renderedImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            
            // 位置标题
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ]
            photoInfo.position.name.draw(at: CGPoint(x: 50, y: 30), withAttributes: titleAttributes)
            
            // 绘制图片
            let imageRect = CGRect(x: 50, y: 70, width: pageWidth - 100, height: 400)
            image.draw(in: imageRect)
            
            // 检测信息
            let infoY: CGFloat = 500
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]
            
            if let result = detectionResult {
                "评分: \(result.overallScore)/100".draw(at: CGPoint(x: 50, y: infoY), withAttributes: infoAttributes)
                "发现问题: \(result.detections.count) 处".draw(at: CGPoint(x: 50, y: infoY + 25), withAttributes: infoAttributes)
                
                var detailY = infoY + 60
                for detection in result.detections.prefix(5) {
                    let text = "• \(detection.type.rawValue) - \(detection.severity.rawValue)"
                    text.draw(at: CGPoint(x: 50, y: detailY), withAttributes: infoAttributes)
                    detailY += 22
                }
            } else {
                "暂无检测数据".draw(at: CGPoint(x: 50, y: infoY), withAttributes: infoAttributes)
            }
        }
        
        guard let cgImage = renderedImage.cgImage else { return nil }
        return PDFPage(image: UIImage(cgImage: cgImage))
    }
}

// MARK: - Report Service Error

enum ReportServiceError: LocalizedError {
    case failedToSaveImage
    case failedToGeneratePDF
    case reportNotFound
    case failedToShare
    
    var errorDescription: String? {
        switch self {
        case .failedToSaveImage:
            return "保存图片失败"
        case .failedToGeneratePDF:
            return "生成PDF失败"
        case .reportNotFound:
            return "报告不存在"
        case .failedToShare:
            return "分享失败"
        }
    }
}

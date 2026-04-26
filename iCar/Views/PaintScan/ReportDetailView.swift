import SwiftUI

struct ReportDetailView: View {
    let report: InspectionReport
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportService = ReportService.shared
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPDFShare = false
    @State private var pdfURL: URL?
    @State private var isGeneratingPDF = false
    
    var body: some View {
        List {
            // 评分概览卡片
            ScoreOverviewSection(report: report)
            
            // 车辆信息
            VehicleInfoSection(report: report)
            
            // 问题统计
            if report.totalDamages > 0 {
                DamageSummarySection(report: report)
            }
            
            // 检测结果
            if !report.detectionResults.isEmpty {
                DetectionResultsSection(results: report.detectionResults)
            }
            
            // 建议措施
            if !report.recommendations.isEmpty {
                RecommendationsSection(recommendations: report.recommendations)
            }
            
            // 维护计划
            if !report.suggestedMaintenanceSchedule.isEmpty {
                MaintenanceScheduleSection(tasks: report.suggestedMaintenanceSchedule)
            }
            
            // 备注
            if !report.notes.isEmpty {
                NotesSection(notes: report.notes)
            }
            
            // 标签
            if !report.tags.isEmpty {
                TagsSection(tags: report.tags)
            }
            
            // 操作按钮
            ActionButtonsSection(
                report: report,
                onShare: { showingShareSheet = true },
                onDelete: { showingDeleteConfirmation = true },
                onGeneratePDF: generatePDF
            )
        }
        .listStyle(.plain)
        .background(.black)
        .scrollContentBackground(.hidden)
        .navigationTitle("报告详情")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: report.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(report.isFavorite ? .white : .gray)
                }
            }
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteReport()
            }
        } message: {
            Text("此操作将永久删除该报告，无法撤销。")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [createShareContent()])
        }
        .sheet(isPresented: $showingPDFShare) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private func createShareContent() -> String {
        var content = "iCar 检测报告\n"
        content += "==================\n\n"
        content += "车辆: \(report.carBrand) \(report.carModel)\n"
        content += "车牌: \(report.licensePlate)\n"
        content += "日期: \(report.formattedDate)\n"
        content += "评分: \(report.overallScore)分\n\n"
        
        if report.totalDamages > 0 {
            content += "发现问题: \(report.totalDamages)处\n"
            content += "严重问题: \(report.criticalDamages)处\n\n"
        }
        
        if !report.notes.isEmpty {
            content += "备注:\n\(report.notes)\n\n"
        }
        
        return content
    }
    
    private func toggleFavorite() {
        reportService.toggleFavorite(for: report)
    }
    
    private func deleteReport() {
        reportService.deleteReport(report)
        dismiss()
    }
    
    private func generatePDF() {
        isGeneratingPDF = true
        Task {
            do {
                let url = try await reportService.generatePDF(for: report)
                await MainActor.run {
                    pdfURL = url
                    showingPDFShare = true
                    isGeneratingPDF = false
                }
            } catch {
                isGeneratingPDF = false
            }
        }
    }
}

// MARK: - Score Overview Section

struct ScoreOverviewSection: View {
    let report: InspectionReport

    var scoreColor: Color {
        if report.overallScore >= 90 { return .white }
        if report.overallScore >= 75 { return .white.opacity(0.8) }
        if report.overallScore >= 60 { return .gray }
        return .gray
    }
    
    var body: some View {
        Section {
            VStack(spacing: 20) {
                // 大评分圆环
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 12)
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .trim(from: 0, to: Double(report.overallScore) / 100)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 4) {
                        Text("\(report.overallScore)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(scoreColor)
                        Text("分")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(report.scoreDescription)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor)
                
                // 状态标签
                HStack(spacing: 12) {
                    StatusBadge(
                        icon: report.status.icon,
                        text: report.status.displayName,
                        color: Color(hex: report.status.color)
                    )
                    
                    if report.isFavorite {
                        StatusBadge(
                            icon: "heart.fill",
                            text: "已收藏",
                            color: .red
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .listRowBackground(Color.clear)
    }
}

struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(16)
    }
}

// MARK: - Vehicle Info Section

struct VehicleInfoSection: View {
    let report: InspectionReport
    
    var body: some View {
        Section("车辆信息") {
            ReportDetailInfoRow(icon: "car.fill", title: "车型", value: "\(report.carBrand) \(report.carModel)")
            ReportDetailInfoRow(icon: "number", title: "车牌", value: report.licensePlate.isEmpty ? "未绑定" : report.licensePlate)
            ReportDetailInfoRow(icon: "paintpalette.fill", title: "颜色", value: report.carColor.isEmpty ? "未知" : report.carColor)
            if report.mileage > 0 {
                ReportDetailInfoRow(icon: "speedometer", title: "里程", value: "\(Int(report.mileage)) km")
            }
            if !report.vin.isEmpty {
                ReportDetailInfoRow(icon: "barcode", title: "VIN", value: report.vin)
            }
            ReportDetailInfoRow(icon: "calendar", title: "检测日期", value: report.formattedDate)
        }
    }
}

struct ReportDetailInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Damage Summary Section

struct DamageSummarySection: View {
    let report: InspectionReport

    var body: some View {
        Section("问题统计") {
            HStack(spacing: 16) {
                DamageStatCard(
                    icon: "exclamationmark.triangle.fill",
                    count: report.totalDamages,
                    label: "总问题",
                    color: .white
                )

                DamageStatCard(
                    icon: "xmark.octagon.fill",
                    count: report.criticalDamages,
                    label: "严重",
                    color: .gray
                )

                DamageStatCard(
                    icon: "checkmark.shield.fill",
                    count: report.detectionResults.count,
                    label: "检测部位",
                    color: .white
                )
            }
            .padding(.vertical, 8)

            // 问题类型分布
            if !report.damageCountByType.isEmpty {
                ForEach(report.damageCountByType.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(.white)
                            .frame(width: 24)
                        Text(type.rawValue)
                        Spacer()
                        Text("\(count) 处")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

struct DamageStatCard: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Detection Results Section

struct DetectionResultsSection: View {
    let results: [DetectionResult]
    
    var body: some View {
        Section("检测结果") {
            ForEach(results) { result in
                DetectionResultCard(result: result)
            }
        }
    }
}

struct DetectionResultCard: View {
    let result: DetectionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.position.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                ScoreBadgeSmall(score: result.overallScore)
            }
            
            if result.detections.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("无问题")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.detections.prefix(3)) { detection in
                        HStack {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 6, height: 6)
                            Text(detection.type.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                            Text(detection.severity.rawValue)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    if result.detections.count > 3 {
                        Text("+\(result.detections.count - 3) 更多")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // 指标
            HStack(spacing: 16) {
                MetricBadge(icon: "sparkles", value: result.glossLevel, label: "光泽")
                MetricBadge(icon: "eye", value: result.clarity, label: "清晰")
                MetricBadge(icon: "paintpalette", value: result.colorConsistency, label: "色彩")
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ScoreBadgeSmall: View {
    let score: Int

    var color: Color {
        if score >= 90 { return .white }
        if score >= 75 { return .white.opacity(0.8) }
        if score >= 60 { return .gray }
        return .gray
    }

    var body: some View {
        Text("\(score)")
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
    }
}

struct MetricBadge: View {
    let icon: String
    let value: Double
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.gray)
            Text("\(Int(value))")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Recommendations Section

struct RecommendationsSection: View {
    let recommendations: [ReportRecommendation]
    
    var body: some View {
        Section("建议措施") {
            ForEach(recommendations.prefix(5)) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: ReportRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: recommendation.category.icon)
                    .foregroundColor(Color(hex: recommendation.priority.color))
                
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(recommendation.priority.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: recommendation.priority.color).opacity(0.2))
                    .foregroundColor(Color(hex: recommendation.priority.color))
                    .cornerRadius(4)
            }
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            Text(recommendation.estimatedCost)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Maintenance Schedule Section

struct MaintenanceScheduleSection: View {
    let tasks: [MaintenanceTask]
    
    var body: some View {
        Section("维护计划") {
            ForEach(tasks) { task in
                MaintenanceTaskRow(task: task)
            }
        }
    }
}

struct MaintenanceTaskRow: View {
    let task: MaintenanceTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.timeframe.icon)
                .foregroundColor(.white)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(task.description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(task.timeframe.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(4)
        }
    }
}

// MARK: - Notes Section

struct NotesSection: View {
    let notes: String
    
    var body: some View {
        Section("备注") {
            Text(notes)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Tags Section

struct TagsSection: View {
    let tags: [String]

    var body: some View {
        Section("标签") {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            }
        }
    }
}

// MARK: - Action Buttons Section

struct ActionButtonsSection: View {
    let report: InspectionReport
    let onShare: () -> Void
    let onDelete: () -> Void
    let onGeneratePDF: () -> Void

    var body: some View {
        Section {
            Button(action: onShare) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("分享报告")
                    Spacer()
                }
                .foregroundColor(.white)
                .padding()
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
            }

            Button(action: onGeneratePDF) {
                HStack {
                    Image(systemName: "doc.fill")
                    Text("生成PDF")
                    Spacer()
                }
                .foregroundColor(.white)
                .padding()
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
            }

            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除报告")
                    Spacer()
                }
                .foregroundColor(.gray)
                .padding()
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Severity Color Extension

extension DamageSeverity {
    var severityColor: Color {
        switch self {
        case .minor:
            return .yellow
        case .moderate:
            return .orange
        case .severe:
            return .red
        @unknown default:
            return .gray
        }
    }
}

#Preview {
    NavigationStack {
        ReportDetailView(report: InspectionReport.preview)
    }
}

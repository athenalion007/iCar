import SwiftUI

// MARK: - Unified Report Detail View

struct UnifiedReportDetailView: View {
    let report: UnifiedReport
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportService = UnifiedReportService.shared
    
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPDFShare = false
    @State private var pdfURL: URL?
    @State private var isGeneratingPDF = false
    
    var body: some View {
        List {
            // 评分概览
            UnifiedScoreOverviewSection(report: report)
            
            // 车辆信息
            UnifiedVehicleInfoSection(report: report)
            
            // 问题统计
            if report.totalIssues > 0 {
                UnifiedIssueSummarySection(report: report)
            }
            
            // 检测区块
            ForEach(report.sections) { section in
                ReportSectionView(section: section)
            }
            
            // 建议措施
            if !report.recommendations.isEmpty {
                UnifiedRecommendationsSection(recommendations: report.recommendations)
            }
            
            // 维护计划
            if !report.maintenanceTasks.isEmpty {
                UnifiedMaintenanceTasksSection(tasks: report.maintenanceTasks)
            }
            
            // 备注
            if !report.notes.isEmpty {
                UnifiedNotesSection(notes: report.notes)
            }
            
            // 标签
            if !report.tags.isEmpty {
                UnifiedTagsSection(tags: report.tags)
            }
            
            // 操作按钮
            UnifiedActionButtonsSection(
                report: report,
                onShare: { showingShareSheet = true },
                onDelete: { showingDeleteConfirmation = true },
                onGeneratePDF: generatePDF,
                isGeneratingPDF: isGeneratingPDF
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
                        .foregroundColor(report.isFavorite ? .red : .gray)
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
            UnifiedShareSheet(activityItems: [createShareContent()])
        }
        .sheet(isPresented: $showingPDFShare) {
            if let url = pdfURL {
                UnifiedShareSheet(activityItems: [url])
            }
        }
    }
    
    private func createShareContent() -> String {
        var content = "iCar \(report.inspectionType.displayName)报告\n"
        content += "==================\n\n"
        content += "车辆: \(report.carBrand) \(report.carModel)\n"
        content += "车牌: \(report.licensePlate)\n"
        content += "日期: \(report.formattedDate)\n"
        content += "评分: \(report.overallScore)分 - \(report.overallStatus.displayName)\n\n"
        
        if report.totalIssues > 0 {
            content += "发现问题: \(report.totalIssues)处\n"
            content += "严重问题: \(report.criticalIssues)处\n\n"
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
        // PDF生成功能待实现
        isGeneratingPDF = false
    }
}

// MARK: - Score Overview Section

struct UnifiedScoreOverviewSection: View {
    let report: UnifiedReport
    
    var scoreColor: Color {
        Color(hex: report.scoreColor)
    }
    
    var body: some View {
        Section {
            VStack(spacing: 20) {
                // 检测类型图标
                Image(systemName: report.inspectionType.icon)
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: report.inspectionType.color))
                
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
                
                Text(report.overallStatus.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor)
                
                // 状态标签
                HStack(spacing: 12) {
                    UnifiedStatusBadge(
                        icon: report.overallStatus.icon,
                        text: report.overallStatus.displayName,
                        color: scoreColor
                    )

                    UnifiedStatusBadge(
                        icon: report.inspectionType.icon,
                        text: report.inspectionType.displayName,
                        color: Color(hex: report.inspectionType.color)
                    )

                    if report.isFavorite {
                        UnifiedStatusBadge(
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

// MARK: - Vehicle Info Section

struct UnifiedVehicleInfoSection: View {
    let report: UnifiedReport
    
    var body: some View {
        Section("车辆信息") {
            ReportInfoRow(icon: "car.fill", title: "车型", value: "\(report.carBrand) \(report.carModel)")
            ReportInfoRow(icon: "number", title: "车牌", value: report.licensePlate.isEmpty ? "未绑定" : report.licensePlate)
            ReportInfoRow(icon: "paintpalette.fill", title: "颜色", value: report.carColor.isEmpty ? "未知" : report.carColor)
            if report.mileage > 0 {
                ReportInfoRow(icon: "speedometer", title: "里程", value: "\(Int(report.mileage)) km")
            }
            ReportInfoRow(icon: "calendar", title: "检测日期", value: report.formattedDate)
        }
    }
}

// MARK: - Issue Summary Section

struct UnifiedIssueSummarySection: View {
    let report: UnifiedReport
    
    var body: some View {
        Section("问题统计") {
            HStack(spacing: 16) {
                StatCard(
                    icon: "exclamationmark.triangle.fill",
                    count: report.totalIssues,
                    label: "总问题",
                    color: .white
                )
                
                StatCard(
                    icon: "xmark.octagon.fill",
                    count: report.criticalIssues,
                    label: "严重",
                    color: .red
                )
                
                StatCard(
                    icon: "checkmark.shield.fill",
                    count: report.sections.count,
                    label: "检测区块",
                    color: .green
                )
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Report Section View

struct ReportSectionView: View {
    let section: ReportSection
    
    var body: some View {
        Section(section.title) {
            if let subtitle = section.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // 指标
            if !section.metrics.isEmpty {
                VStack(spacing: 12) {
                    ForEach(section.metrics) { metric in
                        MetricRow(metric: metric)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // 条目
            ForEach(section.items) { item in
                ReportItemRow(item: item)
            }
            
            if let summary = section.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Report Item Row

struct ReportItemRow: View {
    let item: ReportItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(item.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if let value = item.value {
                    Text(value)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if let description = item.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 16)
            }
            
            if let referenceRange = item.referenceRange {
                Text("参考范围: \(referenceRange)")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }
    
    var statusColor: Color {
        Color(hex: item.status.color)
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let metric: ReportMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let icon = metric.icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(metric.name)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(metric.formattedValue)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            if let maxValue = metric.maxValue, maxValue > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(progressColor)
                            .frame(width: geometry.size.width * metric.percentage, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
    }
    
    var progressColor: Color {
        if metric.percentage >= 0.8 {
            return .green
        } else if metric.percentage >= 0.6 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Recommendations Section

struct UnifiedRecommendationsSection: View {
    let recommendations: [UnifiedReportRecommendation]

    var body: some View {
        Section("建议措施") {
            ForEach(recommendations.prefix(5)) { recommendation in
                UnifiedRecommendationRow(recommendation: recommendation)
            }
        }
    }
}

struct UnifiedRecommendationRow: View {
    let recommendation: UnifiedReportRecommendation
    
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

// MARK: - Maintenance Tasks Section

struct UnifiedMaintenanceTasksSection: View {
    let tasks: [UnifiedMaintenanceTask]

    var body: some View {
        Section("维护计划") {
            ForEach(tasks) { task in
                UnifiedMaintenanceTaskRow(task: task)
            }
        }
    }
}

struct UnifiedMaintenanceTaskRow: View {
    let task: UnifiedMaintenanceTask
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.timeframe.icon)
                .foregroundColor(task.isUrgent ? .red : .white)
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

struct UnifiedNotesSection: View {
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

struct UnifiedTagsSection: View {
    let tags: [String]
    
    var body: some View {
        Section("标签") {
            UnifiedFlowLayout(spacing: 8) {
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

struct UnifiedActionButtonsSection: View {
    let report: UnifiedReport
    let onShare: () -> Void
    let onDelete: () -> Void
    let onGeneratePDF: () -> Void
    let isGeneratingPDF: Bool
    
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
                    if isGeneratingPDF {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "doc.fill")
                    }
                    Text(isGeneratingPDF ? "生成中..." : "生成PDF")
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
            .disabled(isGeneratingPDF)
            
            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除报告")
                    Spacer()
                }
                .foregroundColor(.red)
                .padding()
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Helper Views

struct UnifiedStatusBadge: View {
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

struct ReportInfoRow: View {
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

struct StatCard: View {
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

// MARK: - Flow Layout

struct UnifiedFlowLayout: Layout {
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

struct UnifiedShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

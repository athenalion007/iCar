import SwiftUI

struct ReportHistoryView: View {
    @StateObject private var reportService = ReportService.shared
    @State private var selectedReport: InspectionReport?
    @State private var searchText = ""
    @State private var selectedFilter: ReportFilter = ReportFilter()
    @State private var showingFilterSheet = false
    @State private var showingStatistics = false
    
    var filteredReports: [InspectionReport] {
        reportService.filterReports(using: selectedFilter)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 统计概览卡片
                if !reportService.reports.isEmpty {
                    StatisticsOverviewCard(statistics: reportService.getStatistics())
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                
                // 搜索和筛选
                Section {
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("搜索报告...", text: $searchText)
                                .onChange(of: searchText) { newValue in
                                    selectedFilter.searchText = newValue
                                }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        
                        Button {
                            showingFilterSheet = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                
                // 报告列表
                if filteredReports.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text(reportService.reports.isEmpty ? "暂无报告" : "未找到匹配的报告")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            if reportService.reports.isEmpty {
                                Text("开始检测车辆，生成您的第一份报告")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section(header: Text("共 \(filteredReports.count) 份报告")) {
                        ForEach(filteredReports) { report in
                            ReportCard(report: report) {
                                selectedReport = report
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(.black)
            .scrollContentBackground(.hidden)
            .navigationTitle("报告历史")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingStatistics = true
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.white)
                }
            }
            }
            .sheet(item: $selectedReport) { report in
                NavigationStack {
                    ReportDetailView(report: report)
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                ReportFilterView(filter: $selectedFilter)
            }
            .sheet(isPresented: $showingStatistics) {
                ReportStatisticsView(statistics: reportService.getStatistics())
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Statistics Overview Card

struct StatisticsOverviewCard: View {
    let statistics: ReportStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("检测统计")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("共 \(statistics.totalReports) 份报告")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("\(statistics.averageScore)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 20) {
                ReportHistoryStatItem(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(statistics.totalDamages)",
                    label: "发现问题",
                    color: .white
                )

                ReportHistoryStatItem(
                    icon: "xmark.octagon.fill",
                    value: "\(statistics.criticalDamages)",
                    label: "严重问题",
                    color: .gray
                )

                ReportHistoryStatItem(
                    icon: "checkmark.shield.fill",
                    value: "\(statistics.totalReports - statistics.reportsWithCriticalIssues)",
                    label: "良好报告",
                    color: .white
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ReportHistoryStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Report Card

struct ReportCard: View {
    let report: InspectionReport
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题行
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.displayTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(report.formattedDate)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // 评分徽章
                    ScoreBadge(score: report.overallScore)
                }
                
                // 车辆信息
                HStack(spacing: 8) {
                    Label(report.licensePlate.isEmpty ? "未绑定车牌" : report.licensePlate, systemImage: "car.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if report.mileage > 0 {
                        Text("·")
                            .foregroundColor(.gray)
                        Label("\(Int(report.mileage)) km", systemImage: "speedometer")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // 问题统计
                if report.totalDamages > 0 {
                    HStack(spacing: 12) {
                        DamageTag(
                            count: report.totalDamages,
                            label: "问题",
                            color: report.hasCriticalIssues ? .gray : .white
                        )

                        if report.criticalDamages > 0 {
                            DamageTag(
                                count: report.criticalDamages,
                                label: "严重",
                                color: .gray
                            )
                        }

                        Spacer()
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("无问题")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                    }
                }

                // 标签
                if !report.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(report.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ScoreBadge: View {
    let score: Int

    var color: Color {
        if score >= 90 { return .white }
        if score >= 75 { return .white.opacity(0.8) }
        if score >= 60 { return .gray }
        return .gray
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(score)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text("分")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: 50)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DamageTag: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.caption)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(4)
    }
}

// MARK: - Report Filter View

struct ReportFilterView: View {
    @Binding var filter: ReportFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("排序方式") {
                    ForEach(ReportSortOption.allCases, id: \.self) { option in
                        Button {
                            filter.sortBy = option
                        } label: {
                            HStack {
                                Text(option.displayName)
                                Spacer()
                                if filter.sortBy == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("状态筛选") {
                    Button {
                        filter.status = nil
                    } label: {
                        HStack {
                            Text("全部")
                            Spacer()
                            if filter.status == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    
                    ForEach(ReportStatus.allCases, id: \.self) { status in
                        Button {
                            filter.status = status
                        } label: {
                            HStack {
                                Label(status.displayName, systemImage: status.icon)
                                Spacer()
                                if filter.status == status {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("问题筛选") {
                    Toggle("仅显示有问题", isOn: Binding(
                        get: { filter.hasDamages == true },
                        set: { filter.hasDamages = $0 ? true : nil }
                    ))
                    
                    Toggle("仅显示收藏", isOn: Binding(
                        get: { filter.isFavorite == true },
                        set: { filter.isFavorite = $0 ? true : nil }
                    ))
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Report Statistics View

struct ReportStatisticsView: View {
    let statistics: ReportStatistics
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // 总体统计
                Section("总体统计") {
                    StatRow(icon: "doc.text.fill", title: "总报告数", value: "\(statistics.totalReports)", color: .white)
                    StatRow(icon: "star.fill", title: "平均评分", value: "\(statistics.averageScore)", color: .white)
                    StatRow(icon: "exclamationmark.triangle.fill", title: "总问题数", value: "\(statistics.totalDamages)", color: .gray)
                    StatRow(icon: "xmark.octagon.fill", title: "严重问题", value: "\(statistics.criticalDamages)", color: .gray)
                }
                
                // 常见问题类型
                if let mostCommon = statistics.mostCommonDamageType {
                    Section("常见问题") {
                        HStack {
                            Image(systemName: mostCommon.icon)
                                .foregroundColor(.white)
                            Text(mostCommon.rawValue)
                            Spacer()
                            Text("最常见")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // 评分分布
                Section("评分分布") {
                    ForEach(ScoreRange.allCases, id: \.self) { range in
                        if let count = statistics.scoreDistribution[range], count > 0 {
                            HStack {
                                Circle()
                                    .fill(Color(hex: range.color))
                                    .frame(width: 8, height: 8)
                                Text(range.displayName)
                                Spacer()
                                Text("\(count) 份")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("统计概览")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    NavigationStack {
        ReportHistoryView()
    }
}

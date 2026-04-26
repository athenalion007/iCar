import SwiftUI

// MARK: - Unified Report History View

struct UnifiedReportHistoryView: View {
    @StateObject private var reportService = UnifiedReportService.shared
    @State private var selectedReport: UnifiedReport?
    @State private var searchText = ""
    @State private var selectedType: UnifiedInspectionType?
    @State private var showingFilterSheet = false
    @State private var showingStatistics = false
    
    var filteredReports: [UnifiedReport] {
        reportService.filterReports(
            searchText: searchText,
            type: selectedType
        )
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 统计概览
                if !reportService.reports.isEmpty {
                    UnifiedStatisticsOverviewCard(statistics: reportService.getStatistics())
                        .listRowBackground(Color.clear)
                }
                
                // 类型筛选
                TypeFilterSection(selectedType: $selectedType)
                    .listRowBackground(Color.clear)
                
                // 搜索
                Section {
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("搜索报告...", text: $searchText)
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
                    EmptyReportsView(hasReports: !reportService.reports.isEmpty)
                } else {
                    Section(header: Text("共 \(filteredReports.count) 份报告")) {
                        ForEach(filteredReports) { report in
                            UnifiedReportCard(report: report) {
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
                    UnifiedReportDetailView(report: report)
                }
            }
            .sheet(isPresented: $showingStatistics) {
                UnifiedReportStatisticsView(statistics: reportService.getStatistics())
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Type Filter Section

struct TypeFilterSection: View {
    @Binding var selectedType: UnifiedInspectionType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                TypeFilterButton(
                    title: "全部",
                    icon: "doc.text.fill",
                    color: .white,
                    isSelected: selectedType == nil
                ) {
                    selectedType = nil
                }

                // 各类型
                ForEach(UnifiedInspectionType.allCases, id: \.self) { type in
                    TypeFilterButton(
                        title: type.displayName,
                        icon: type.icon,
                        color: Color(hex: type.color),
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TypeFilterButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color.white.opacity(0.05))
            .foregroundColor(isSelected ? color : .gray)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }
}

// MARK: - Statistics Overview Card

struct UnifiedStatisticsOverviewCard: View {
    let statistics: UnifiedReportStatistics
    
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
                UnifiedStatItem(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(statistics.totalIssues)",
                    label: "发现问题",
                    color: .orange
                )

                UnifiedStatItem(
                    icon: "xmark.octagon.fill",
                    value: "\(statistics.criticalIssues)",
                    label: "严重问题",
                    color: .red
                )

                UnifiedStatItem(
                    icon: "checkmark.shield.fill",
                    value: "\(statistics.totalReports - statistics.typeDistribution.values.filter { $0 > 0 }.count)",
                    label: "良好报告",
                    color: .green
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

struct UnifiedStatItem: View {
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

// MARK: - Empty Reports View

struct EmptyReportsView: View {
    let hasReports: Bool
    
    var body: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: hasReports ? "doc.text.magnifyingglass" : "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text(hasReports ? "未找到匹配的报告" : "暂无报告")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                if !hasReports {
                    Text("开始检测车辆，生成您的第一份报告")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Unified Report Card

struct UnifiedReportCard: View {
    let report: UnifiedReport
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题行
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: report.inspectionType.icon)
                            .font(.title3)
                            .foregroundColor(Color(hex: report.inspectionType.color))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.displayTitle)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(report.formattedDate)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // 评分徽章
                    UnifiedScoreBadge(score: report.overallScore)
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
                if report.totalIssues > 0 {
                    HStack(spacing: 12) {
                        IssueTag(
                            count: report.totalIssues,
                            label: "问题",
                            color: report.hasCriticalIssues ? .red : .orange
                        )
                        
                        if report.criticalIssues > 0 {
                            IssueTag(
                                count: report.criticalIssues,
                                label: "严重",
                                color: .red
                            )
                        }
                        
                        Spacer()
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("无问题")
                            .font(.caption)
                            .foregroundColor(.green)
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

struct UnifiedScoreBadge: View {
    let score: Int
    
    var color: Color {
        if score >= 90 { return .green }
        if score >= 75 { return .yellow }
        if score >= 60 { return .orange }
        return .red
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

struct IssueTag: View {
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

// MARK: - Unified Report Statistics View

struct UnifiedReportStatisticsView: View {
    let statistics: UnifiedReportStatistics
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // 总体统计
                Section("总体统计") {
                    UnifiedStatRow(icon: "doc.text.fill", title: "总报告数", value: "\(statistics.totalReports)", color: .white)
                    UnifiedStatRow(icon: "star.fill", title: "平均评分", value: "\(statistics.averageScore)", color: .yellow)
                    UnifiedStatRow(icon: "exclamationmark.triangle.fill", title: "总问题数", value: "\(statistics.totalIssues)", color: .orange)
                    UnifiedStatRow(icon: "xmark.octagon.fill", title: "严重问题", value: "\(statistics.criticalIssues)", color: .red)
                }
                
                // 类型分布
                let typeDistribution = statistics.typeDistribution
                if !typeDistribution.isEmpty {
                    Section("检测类型分布") {
                        let sortedTypes = typeDistribution.sorted { $0.value > $1.value }
                        ForEach(Array(sortedTypes), id: \.key) { type, count in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(Color(hex: type.color))
                                Text(type.displayName)
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

struct UnifiedStatRow: View {
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

// MARK: - Preview

#Preview {
    NavigationStack {
        UnifiedReportHistoryView()
    }
}

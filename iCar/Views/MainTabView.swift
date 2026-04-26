import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 诊断
            DiagnosisView()
                .tabItem {
                    Image(systemName: "stethoscope")
                    Text(String(localized: "tab.diagnosis"))
                }
                .tag(0)
                .accessibilityLabel(String(localized: "tab.diagnosis"))
                .accessibilityHint(String(localized: "accessibility.diagnosis.hint"))
            
            // Tab 2: 报告
            UnifiedReportHistoryView()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text(String(localized: "tab.reports"))
                }
                .tag(1)
                .accessibilityLabel(String(localized: "tab.reports"))
                .accessibilityHint(String(localized: "accessibility.reports.hint"))
            
            // Tab 3: 设置
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text(String(localized: "tab.settings"))
                }
                .tag(2)
                .accessibilityLabel(String(localized: "tab.settings"))
                .accessibilityHint(String(localized: "accessibility.settings.hint"))
        }
        .preferredColorScheme(.dark)
        .accentColor(.white)
    }
}

// MARK: - Diagnosis View (原ContentView的功能)

struct DiagnosisView: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    ForEach(FeatureModule.allCases) { module in
                        NavigationLink(value: module) {
                            MinimalFeatureRow(module: module)
                        }
                    }
                } header: {
                    Text(String(localized: "section.diagnosis_tools"))
                        .font(.caption)
                        .textCase(.uppercase)
                }
            }
            .listStyle(.plain)
            .background(.black)
            .scrollContentBackground(.hidden)
            .navigationTitle("iCar")
            .navigationDestination(for: FeatureModule.self) { module in
                moduleDestinationView(for: module)
            }
        }
    }
    
    @ViewBuilder
    private func moduleDestinationView(for module: FeatureModule) -> some View {
        switch module {
        case .engineEar:
            EngineEarViewV2()
        case .tireTread:
            TireTreadView()
        case .paintScan:
            PaintScanView()
        case .suspensionIQ:
            SuspensionIQView()
        case .acDoctor:
            ACDoctorView()
        }
    }
}

// MARK: - Settings View (经典分组列表设计 + 黑白灰极简风格)

struct SettingsView: View {
    @StateObject private var reportService = ReportService.shared
    @StateObject private var privacyService = PrivacyService.shared
    @StateObject private var encryptionService = EncryptionService.shared
    @StateObject private var dataService = DataPersistenceService.shared
    
    @State private var showingClearConfirmation = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingDataExport = false
    @State private var showingDeleteConfirmation = false
    @State private var showingClearCacheConfirmation = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var isClearing = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                // 用户统计概览
                userStatsSection
                
                // 权限与安全
                securitySection
                
                // 数据管理
                dataManagementSection
                
                // 隐私偏好
                privacyPreferencesSection
                
                // 法律信息
                legalSection
                
                // 关于
                aboutSection
            }
            .listStyle(.plain)
            .background(.black)
            .scrollContentBackground(.hidden)
            .navigationTitle(String(localized: "tab.settings"))
            .navigationBarTitleDisplayMode(.large)
            .alert(String(localized: "alert.confirm_clear"), isPresented: $showingClearConfirmation) {
                Button(String(localized: "common.cancel"), role: .cancel) { }
                Button(String(localized: "common.clear"), role: .destructive) {
                    reportService.clearAllReports()
                    successMessage = String(localized: "message.all_reports_cleared")
                    showingSuccessAlert = true
                }
            } message: {
                Text(String(localized: "alert.clear_reports_message"))
            }
            .alert(String(localized: "alert.confirm_delete"), isPresented: $showingDeleteConfirmation) {
                Button(String(localized: "common.cancel"), role: .cancel) { }
                Button(String(localized: "common.delete"), role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text(String(localized: "alert.delete_all_message"))
            }
            .alert(String(localized: "alert.confirm_clear_cache"), isPresented: $showingClearCacheConfirmation) {
                Button(String(localized: "common.cancel"), role: .cancel) { }
                Button(String(localized: "common.clear"), role: .destructive) {
                    clearCache()
                }
            } message: {
                Text(String(localized: "alert.clear_cache_message"))
            }
            .alert(String(localized: "alert.notice"), isPresented: $showingSuccessAlert) {
                Button(String(localized: "common.ok"), role: .cancel) { }
            } message: {
                Text(successMessage)
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                LegalDocumentView(title: String(localized: "settings.privacy_policy"), content: privacyPolicyContent)
            }
            .sheet(isPresented: $showingTermsOfService) {
                LegalDocumentView(title: String(localized: "settings.terms_of_service"), content: termsOfServiceContent)
            }
            .sheet(isPresented: $showingDataExport) {
                if let url = exportURL {
                    PrivacyShareSheet(activityItems: [url])
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - User Stats Section
    
    private var userStatsSection: some View {
        Section {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "settings.user_label"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(reportService.reports.count) \(String(localized: "settings.report_count_suffix"))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 20) {
                    SettingsStatItem(
                        value: "\(reportService.reports.count)",
                        label: String(localized: "settings.total_reports"),
                        icon: "doc.text.fill"
                    )
                    
                    SettingsStatItem(
                        value: "\(reportService.getStatistics().totalDamages)",
                        label: String(localized: "settings.issues_found"),
                        icon: "exclamationmark.triangle.fill"
                    )
                    
                    SettingsStatItem(
                        value: "\(reportService.reports.filter { $0.isFavorite }.count)",
                        label: String(localized: "settings.favorites"),
                        icon: "heart.fill"
                    )
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Security Section
    
    private var securitySection: some View {
        Section(header: SectionHeader(title: String(localized: "section.security"))) {
            // 权限管理
            NavigationLink {
                PermissionsSettingsView()
            } label: {
                SettingsRow(
                    icon: "lock.shield.fill",
                    title: String(localized: "settings.permissions"),
                    subtitle: String(localized: "settings.permissions_subtitle")
                )
            }
            
            // 数据加密
            SettingsToggleRow(
                icon: "key.fill",
                title: String(localized: "settings.encryption"),
                subtitle: String(localized: "settings.encryption_subtitle"),
                isOn: Binding(
                    get: { encryptionService.isEncryptionEnabled },
                    set: { encryptionService.setEncryptionEnabled($0) }
                )
            )
            
            // 生物识别
            if encryptionService.isBiometricAuthAvailable {
                SettingsToggleRow(
                    icon: encryptionService.biometricType.icon,
                    title: String(localized: "settings.biometric"),
                    subtitle: encryptionService.biometricType.displayName,
                    isOn: Binding(
                        get: { privacyService.getPrivacySettings().requireBiometricForSensitiveData },
                        set: { newValue in
                            var settings = privacyService.getPrivacySettings()
                            settings.requireBiometricForSensitiveData = newValue
                            privacyService.updatePrivacySettings(settings)
                        }
                    )
                )
            }
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        Section(header: SectionHeader(title: String(localized: "section.data_management"))) {
            // 导出数据
            Button {
                exportData()
            } label: {
                SettingsRow(
                    icon: "square.and.arrow.up.fill",
                    title: isExporting ? String(localized: "settings.exporting") : String(localized: "settings.export_data"),
                    subtitle: String(localized: "settings.export_subtitle"),
                    isLoading: isExporting
                )
            }
            
            // 数据保留
            NavigationLink {
                DataRetentionSettingsView()
            } label: {
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    title: String(localized: "settings.data_retention"),
                    subtitle: "\(dataService.userSettings?.dataRetentionDays ?? 365) \(String(localized: "unit.days"))"
                )
            }
            
            // 清除缓存
            Button {
                showingClearCacheConfirmation = true
            } label: {
                SettingsRow(
                    icon: "trash.fill",
                    title: String(localized: "settings.clear_cache"),
                    subtitle: String(localized: "settings.clear_cache_subtitle")
                )
            }
            
            // 删除所有数据
            Button {
                showingDeleteConfirmation = true
            } label: {
                SettingsRow(
                    icon: "exclamationmark.triangle.fill",
                    title: String(localized: "settings.delete_all"),
                    subtitle: String(localized: "settings.delete_all_subtitle"),
                    isDestructive: true
                )
            }
        }
    }
    
    // MARK: - Privacy Preferences Section
    
    private var privacyPreferencesSection: some View {
        Section(header: SectionHeader(title: String(localized: "section.privacy_preferences"))) {
            // 使用分析
            SettingsToggleRow(
                icon: "chart.bar.fill",
                title: String(localized: "settings.analytics"),
                subtitle: String(localized: "settings.analytics_subtitle"),
                isOn: Binding(
                    get: { privacyService.isAnalyticsEnabled() },
                    set: { privacyService.setAnalyticsEnabled($0) }
                )
            )
            
            // 崩溃报告
            SettingsToggleRow(
                icon: "exclamationmark.bubble.fill",
                title: String(localized: "settings.crash_reports"),
                subtitle: String(localized: "settings.crash_reports_subtitle"),
                isOn: Binding(
                    get: { privacyService.isCrashReportingEnabled() },
                    set: { privacyService.setCrashReportingEnabled($0) }
                )
            )
        }
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        Section(header: SectionHeader(title: String(localized: "section.legal"))) {
            Button {
                showingPrivacyPolicy = true
            } label: {
                SettingsRow(
                    icon: "doc.text.fill",
                    title: String(localized: "settings.privacy_policy"),
                    subtitle: String(localized: "settings.privacy_policy_subtitle")
                )
            }
            
            Button {
                showingTermsOfService = true
            } label: {
                SettingsRow(
                    icon: "doc.fill",
                    title: String(localized: "settings.terms_of_service"),
                    subtitle: String(localized: "settings.terms_subtitle")
                )
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section(header: SectionHeader(title: String(localized: "section.about"))) {
            HStack {
                SettingsRow(
                    icon: "info.circle.fill",
                    title: String(localized: "settings.about_app"),
                    subtitle: "\(String(localized: "settings.version")) \(appVersion)"
                )
                Spacer()
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    // MARK: - Actions
    
    private func exportData() {
        isExporting = true
        let exportData = reportService.exportReports()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("icar_export_\(Date().timeIntervalSince1970).json")
        try? exportData.write(to: tempURL)
        exportURL = tempURL
        showingDataExport = true
        isExporting = false
    }
    
    private func clearCache() {
        isClearing = true
        Task {
            try? CacheManager.shared.clearAllCache()
            successMessage = "缓存已清除"
            showingSuccessAlert = true
            isClearing = false
        }
    }
    
    private func deleteAllData() {
        Task {
            do {
                try await privacyService.deleteAllUserData()
                successMessage = "所有数据已删除"
                showingSuccessAlert = true
            } catch {
                successMessage = "删除失败: \(error.localizedDescription)"
                showingSuccessAlert = true
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.caption)
            .textCase(.uppercase)
            .foregroundColor(.gray)
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var isLoading: Bool = false
    var isDestructive: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isDestructive ? .gray : .white)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.body)
                        .foregroundColor(isDestructive ? .gray : .white)
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .white))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Settings Stat Item

struct SettingsStatItem: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white.opacity(0.5))
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Legal Document View

struct LegalDocumentView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Legal Content

private let privacyPolicyContent = """
iCar 隐私政策

最后更新日期：2026年4月26日

1. 我们收集的信息
为了提供车辆AI检测服务，我们收集以下信息：
• 车辆信息：车牌号码、车辆品牌、型号、颜色、VIN码、行驶里程
• 检测数据：轮胎照片、漆面照片、发动机录音、悬挂振动数据
• 位置信息：车辆检测地点、附近维修站搜索位置
• 设备信息：设备型号、操作系统版本（仅用于应用功能）

2. 我们如何使用您的信息
• 车辆照片：用于AI漆面损伤检测和轮胎花纹深度分析（本地处理）
• 发动机录音：用于AI声音故障诊断（本地实时分析，不保存录音）
• 位置信息：用于记录检测地点和查找附近维修站（本地存储）
• 运动传感器数据：用于悬挂系统振动分析（本地实时处理）

3. 数据存储与安全
• 所有数据仅存储在您的设备本地，使用iOS CoreData和文件系统
• 应用数据受iOS沙盒机制保护，其他应用无法访问
• 使用iOS标准加密API保护敏感数据
• 我们不会将您的任何数据上传到云端服务器

4. 数据保留与删除
• 检测报告：永久保留，直到您主动删除
• 车辆照片：与关联的检测报告一同保留
• 录音数据：分析完成后立即删除，不保留
• 传感器数据：实时处理，不保存

您可以通过以下方式删除数据：
• 在应用内删除单个检测报告
• 在应用设置中清除所有数据
• 卸载应用将删除所有应用数据

5. 第三方共享
我们不会与任何第三方共享、出售或传输您的个人信息。所有数据处理均在您的设备本地完成。

6. 儿童隐私保护
本应用不面向13岁以下儿童。我们不会故意收集13岁以下儿童的个人信息。

7. 您的权利
根据适用的隐私法律，您拥有以下权利：
• 访问权：查看我们持有的您的数据
• 更正权：更正不准确的信息
• 删除权：要求删除您的数据
• 限制处理权：限制某些数据处理活动
• 数据可携带权：导出您的数据

8. 联系我们
如果您对本隐私政策有任何疑问，或希望行使您的隐私权利，请通过以下方式联系我们：
• 邮箱：privacy@icar-app.com
• 支持网站：https://icar-app.com/support
• 响应时间：我们将在收到请求后的15个工作日内回复

9. 政策更新
我们可能会不时更新本隐私政策。任何重大变更将通过应用内通知告知您。继续使用本应用即表示您接受更新后的政策。
"""

private let termsOfServiceContent = """
iCar 服务条款

最后更新日期：2026年4月26日

1. 服务说明
iCar是一款车辆检测辅助工具，使用AI技术帮助用户检测车辆状况。检测结果仅供参考，不能替代专业技师的人工检查。

2. 免责声明
• 我们不对检测结果的准确性、完整性或可靠性提供任何明示或暗示的保证
• AI检测结果可能受环境光线、拍摄角度、设备性能等因素影响
• 对于因使用本应用检测结果而导致的任何损失，我们不承担责任
• 重大车辆故障请务必咨询专业维修技师

3. 使用限制
• 请勿将本应用用于非法目的
• 请勿干扰或破坏应用的正常运行
• 请勿未经授权访问我们的系统或网络
• 您对自己上传的内容负有全部责任

4. 知识产权
• 本应用的所有权利归iCar团队所有
• 未经许可，不得复制、修改、分发应用或其内容
• 用户生成的检测报告归用户所有

5. 隐私保护
我们严格保护用户隐私，所有数据仅在设备本地处理。详细信息请参阅我们的隐私政策。

6. 条款修改
我们保留随时修改这些条款的权利。重大变更将通过应用内通知告知用户。继续使用本应用即表示您接受更新后的条款。

7. 联系我们
如有任何问题，请联系：support@icar-app.com
"""

// MARK: - Data Retention Settings View

struct DataRetentionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataService = DataPersistenceService.shared
    @StateObject private var privacyService = PrivacyService.shared

    var body: some View {
        List {
            Section {
                VStack(spacing: 32) {
                    Spacer()

                    // 标题区域
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))

                        Text(String(localized: "settings.data_retention_title"))
                            .font(.title3)
                            .foregroundColor(.white)

                        Text(String(localized: "settings.data_retention_subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // 保留期限选项
                    VStack(spacing: 12) {
                        ForEach([30, 90, 180, 365, 730, 1095], id: \.self) { days in
                            Button {
                                updateRetentionDays(days)
                            } label: {
                                HStack {
                                    Text("\(days) \(String(localized: "unit.days"))")
                                        .foregroundColor(.white)
                                    Spacer()
                                    if dataService.userSettings?.dataRetentionDays == Int16(days) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 40)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .background(.black)
        .scrollContentBackground(.hidden)
        .navigationTitle(String(localized: "settings.data_retention_title"))
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }

    private func updateRetentionDays(_ days: Int) {
        Task {
            do {
                try await dataService.updateUserSettings { settings in
                    settings.dataRetentionDays = Int16(days)
                }
                var privacySettings = privacyService.getPrivacySettings()
                privacySettings.dataRetentionDays = days
                privacyService.updatePrivacySettings(privacySettings)
            } catch {
                print("Failed to update retention days: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}

import SwiftUI
import SafariServices

// MARK: - Privacy Settings View (极简主义 - 黑白灰)

struct PrivacySettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @StateObject private var privacyService = PrivacyService.shared
    @StateObject private var encryptionService = EncryptionService.shared
    @StateObject private var dataService = DataPersistenceService.shared

    // MARK: - State

    @State private var viewState: SettingsViewState = .main
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
    
    // 外部URL
    private let privacyPolicyURL = URL(string: "https://icar-app.com/privacy-policy.html")!
    private let supportURL = URL(string: "https://icar-app.com/support.html")!

    enum SettingsViewState {
        case main
        case permissions
        case dataRetention
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                content
            }
            .listStyle(.plain)
            .background(.black)
            .scrollContentBackground(.hidden)
            .navigationTitle("隐私与安全")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingToolbarButton
                }
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                SafariWebView(url: privacyPolicyURL)
            }
            .sheet(isPresented: $showingTermsOfService) {
                SafariWebView(url: supportURL)
            }
            .sheet(isPresented: $showingDataExport) {
                if let url = exportURL {
                    PrivacyShareSheet(activityItems: [url])
                }
            }
            .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("此操作将永久删除所有车辆数据、检测报告和设置。此操作无法撤销。")
            }
            .alert("确认清除", isPresented: $showingClearCacheConfirmation) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("此操作将清除所有缓存数据，包括临时文件和图片。不会影响您的车辆数据。")
            }
            .alert("提示", isPresented: $showingSuccessAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(successMessage)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var leadingToolbarButton: some View {
        switch viewState {
        case .main:
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
            }
        case .permissions, .dataRetention:
            Button {
                viewState = .main
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewState {
        case .main:
            mainSection
        case .permissions:
            permissionsDetailSection
        case .dataRetention:
            dataRetentionDetailSection
        }
    }

    // MARK: - Main Section

    private var mainSection: some View {
        Section {
            VStack(spacing: 32) {
                Spacer()

                // 标题区域
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkerboard")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))

                    Text("隐私与安全设置")
                        .font(.title3)
                        .foregroundColor(.white)

                    Text("管理您的数据隐私和安全选项")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // 设置选项网格
                VStack(spacing: 12) {
                    // 权限管理
                    SettingsActionButton(
                        icon: "lock.shield.fill",
                        title: "权限管理",
                        subtitle: "管理应用权限"
                    ) {
                        viewState = .permissions
                    }

                    // 数据加密
                    SettingsToggleButton(
                        icon: "key.fill",
                        title: "数据加密",
                        subtitle: "AES-256 加密",
                        isOn: Binding(
                            get: { encryptionService.isEncryptionEnabled },
                            set: { encryptionService.setEncryptionEnabled($0) }
                        )
                    )

                    // 生物识别
                    if encryptionService.isBiometricAuthAvailable {
                        SettingsToggleButton(
                            icon: encryptionService.biometricType.icon,
                            title: "生物识别验证",
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

                    // 导出数据
                    SettingsActionButton(
                        icon: "square.and.arrow.up.fill",
                        title: isExporting ? "导出中..." : "导出数据",
                        subtitle: "导出所有用户数据",
                        isLoading: isExporting
                    ) {
                        exportData()
                    }

                    // 清除缓存
                    SettingsActionButton(
                        icon: "trash.fill",
                        title: isClearing ? "清除中..." : "清除缓存",
                        subtitle: "清除临时文件和图片",
                        isLoading: isClearing
                    ) {
                        showingClearCacheConfirmation = true
                    }

                    // 删除所有数据
                    SettingsActionButton(
                        icon: "exclamationmark.triangle.fill",
                        title: "删除所有数据",
                        subtitle: "永久删除所有数据",
                        isDestructive: true
                    ) {
                        showingDeleteConfirmation = true
                    }

                    // 隐私政策
                    SettingsActionButton(
                        icon: "doc.text.fill",
                        title: "隐私政策",
                        subtitle: "查看隐私政策"
                    ) {
                        showingPrivacyPolicy = true
                    }

                    // 服务条款
                    SettingsActionButton(
                        icon: "doc.text.magnifyingglass",
                        title: "服务条款",
                        subtitle: "查看服务条款"
                    ) {
                        showingTermsOfService = true
                    }
                }

                Spacer()

                // 版本信息
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                    Text("版本 \(appVersion)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 40)
        }
    }

    // MARK: - Permissions Detail Section

    private var permissionsDetailSection: some View {
        Section {
            VStack(spacing: 32) {
                Spacer()

                // 标题区域
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))

                    Text("权限管理")
                        .font(.title3)
                        .foregroundColor(.white)

                    Text("点击权限图标管理应用权限")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // 权限状态图标
                HStack(spacing: 20) {
                    PermissionStatusIcon(
                        icon: "camera.fill",
                        isGranted: privacyService.cameraPermission == .authorized
                    )
                    PermissionStatusIcon(
                        icon: "mic.fill",
                        isGranted: privacyService.microphonePermission == .authorized
                    )
                    PermissionStatusIcon(
                        icon: "location.fill",
                        isGranted: mapLocationStatus(privacyService.locationPermission) == .authorized
                    )
                    PermissionStatusIcon(
                        icon: "photo.fill",
                        isGranted: privacyService.photoLibraryPermission == .authorized
                    )
                    PermissionStatusIcon(
                        icon: "bell.fill",
                        isGranted: privacyService.notificationPermission == .authorized
                    )
                }

                Spacer()

                // 前往系统设置按钮
                Button {
                    privacyService.openAppSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("前往系统设置")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
            }
            .padding(.vertical, 40)
        }
    }

    // MARK: - Data Retention Detail Section

    private var dataRetentionDetailSection: some View {
        Section {
            VStack(spacing: 32) {
                Spacer()

                // 标题区域
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))

                    Text("数据保留")
                        .font(.title3)
                        .foregroundColor(.white)

                    Text("设置数据保留期限")
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
                                Text("\(days) 天")
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
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private func mapLocationStatus(_ status: LocationPermissionStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        }
    }

    private func exportData() {
        isExporting = true

        Task {
            do {
                let url = try await privacyService.exportUserData()
                exportURL = url
                showingDataExport = true
            } catch {
                successMessage = "导出失败: \(error.localizedDescription)"
                showingSuccessAlert = true
            }
            isExporting = false
        }
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

// MARK: - Settings Action Button

struct SettingsActionButton: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var isLoading: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDestructive ? .gray : .white)
                    .frame(width: 30)

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

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDestructive ? Color.gray.opacity(0.3) : Color.white.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

// MARK: - Settings Toggle Button

struct SettingsToggleButton: View {
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
        .padding()
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Permission Status Icon

struct PermissionStatusIcon: View {
    let icon: String
    let isGranted: Bool

    var body: some View {
        Button {
            PrivacyService.shared.openAppSettings()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isGranted ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isGranted ? .white : .gray)
                }

                Circle()
                    .fill(isGranted ? Color.white : Color.gray)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    let htmlContent: String
    var title: String = "隐私政策"

    var body: some View {
        NavigationStack {
            WebView(htmlString: htmlContent)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Safari Web View

struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = .white
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Web View (Legacy)

struct WebView: UIViewControllerRepresentable {
    let htmlString: String

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let data = Data(htmlString.utf8)
        if let url = URL(dataRepresentation: data, relativeTo: nil) {
            return SFSafariViewController(url: url)
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("privacy.html")
        try? htmlString.write(to: tempURL, atomically: true, encoding: .utf8)
        return SFSafariViewController(url: tempURL)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Share Sheet

struct PrivacyShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    PrivacySettingsView()
}

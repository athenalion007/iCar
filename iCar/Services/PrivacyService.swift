import Foundation
import AVFoundation
import CoreLocation
import Photos
import Contacts
import EventKit
import UserNotifications
import AppTrackingTransparency
import AdSupport
import SwiftUI

// MARK: - Privacy Service

@MainActor
final class PrivacyService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var cameraPermission: PermissionStatus = .notDetermined
    @Published var microphonePermission: PermissionStatus = .notDetermined
    @Published var locationPermission: LocationPermissionStatus = .notDetermined
    @Published var photoLibraryPermission: PermissionStatus = .notDetermined
    @Published var contactsPermission: PermissionStatus = .notDetermined
    @Published var calendarPermission: PermissionStatus = .notDetermined
    @Published var notificationPermission: PermissionStatus = .notDetermined
    @Published var trackingPermission: PermissionStatus = .notDetermined
    
    @Published var locationManager = CLLocationManager()
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let privacySettingsKey = "privacy_settings"
    
    // MARK: - Singleton
    
    static let shared = PrivacyService()
    
    private override init() {
        super.init()
        locationManager.delegate = self
        checkAllPermissions()
    }
    
    // MARK: - Permission Checking
    
    func checkAllPermissions() {
        checkCameraPermission()
        checkMicrophonePermission()
        checkLocationPermission()
        checkPhotoLibraryPermission()
        checkContactsPermission()
        checkCalendarPermission()
        checkNotificationPermission()
        checkTrackingPermission()
    }
    
    func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermission = PermissionStatus(from: status)
    }
    
    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermission = PermissionStatus(from: status)
    }
    
    func checkLocationPermission() {
        let status = locationManager.authorizationStatus
        locationPermission = LocationPermissionStatus(from: status)
    }
    
    func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        photoLibraryPermission = PermissionStatus(from: status)
    }
    
    func checkContactsPermission() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        contactsPermission = PermissionStatus(from: status)
    }
    
    func checkCalendarPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)
        calendarPermission = PermissionStatus(from: status)
    }
    
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                self?.notificationPermission = PermissionStatus(from: status)
            }
        }
    }
    
    func checkTrackingPermission() {
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            trackingPermission = PermissionStatus(from: status)
        } else {
            trackingPermission = .authorized
        }
    }
    
    // MARK: - Permission Requesting
    
    func requestCameraPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        checkCameraPermission()
        return granted
    }
    
    func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        checkMicrophonePermission()
        return granted
    }
    
    func requestLocationPermission(always: Bool = false) {
        if always {
            locationManager.requestAlwaysAuthorization()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func requestPhotoLibraryPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoLibraryPermission = PermissionStatus(from: status)
        return status == .authorized || status == .limited
    }
    
    func requestContactsPermission() async -> Bool {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            contactsPermission = granted ? .authorized : .denied
            return granted
        } catch {
            contactsPermission = .denied
            return false
        }
    }
    
    func requestCalendarPermission() async -> Bool {
        let store = EKEventStore()
        do {
            let granted = try await store.requestAccess(to: .event)
            calendarPermission = granted ? .authorized : .denied
            return granted
        } catch {
            calendarPermission = .denied
            return false
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            notificationPermission = granted ? .authorized : .denied
            return granted
        } catch {
            notificationPermission = .denied
            return false
        }
    }
    
    @available(iOS 14, *)
    func requestTrackingPermission() async -> Bool {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        trackingPermission = PermissionStatus(from: status)
        return status == .authorized
    }
    
    // MARK: - Privacy Policy
    
    func getPrivacyPolicyHTML() -> String {
        """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>隐私政策</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    padding: 20px;
                    max-width: 800px;
                    margin: 0 auto;
                }
                h1 { color: #007AFF; }
                h2 { color: #333; margin-top: 30px; }
                h3 { color: #555; }
                .section { margin-bottom: 30px; }
                .last-updated { color: #666; font-style: italic; }
                ul { padding-left: 20px; }
                li { margin-bottom: 8px; }
            </style>
        </head>
        <body>
            <h1>iCar 隐私政策</h1>
            <p class="last-updated">最后更新日期：2026年4月23日</p>
            
            <div class="section">
                <h2>1. 引言</h2>
                <p>欢迎使用 iCar 应用。我们非常重视您的隐私保护。本隐私政策说明了我们如何收集、使用、存储和保护您的个人信息。</p>
            </div>
            
            <div class="section">
                <h2>2. 我们收集的信息</h2>
                <h3>2.1 您提供的信息</h3>
                <ul>
                    <li>车辆信息（品牌、型号、车牌号等）</li>
                    <li>检测照片和视频</li>
                    <li>检测报告数据</li>
                    <li>维护记录</li>
                </ul>
                
                <h3>2.2 自动收集的信息</h3>
                <ul>
                    <li>设备信息（型号、操作系统版本）</li>
                    <li>应用使用数据</li>
                    <li>崩溃日志（用于改进应用稳定性）</li>
                </ul>
            </div>
            
            <div class="section">
                <h2>3. 权限使用说明</h2>
                <ul>
                    <li><strong>相机权限：</strong>用于拍摄车辆照片和漆面检测</li>
                    <li><strong>麦克风权限：</strong>用于发动机声音录制和分析</li>
                    <li><strong>位置权限：</strong>用于记录检测位置（可选）</li>
                    <li><strong>照片库权限：</strong>用于保存检测照片</li>
                    <li><strong>通知权限：</strong>用于发送维护提醒</li>
                </ul>
            </div>
            
            <div class="section">
                <h2>4. 数据安全</h2>
                <p>我们采用以下措施保护您的数据安全：</p>
                <ul>
                    <li>AES-256 加密存储敏感数据</li>
                    <li>数据本地存储，不上传服务器</li>
                    <li>支持生物识别验证（Face ID/Touch ID）</li>
                    <li>定期安全更新</li>
                </ul>
            </div>
            
            <div class="section">
                <h2>5. 数据管理</h2>
                <p>您拥有以下数据权利：</p>
                <ul>
                    <li>查看和导出您的数据</li>
                    <li>删除特定数据或全部数据</li>
                    <li>控制数据保留期限</li>
                    <li>撤销应用权限</li>
                </ul>
            </div>
            
            <div class="section">
                <h2>6. 联系我们</h2>
                <p>如果您对本隐私政策有任何疑问，请联系我们：</p>
                <p>邮箱：privacy@icar.app</p>
            </div>
        </body>
        </html>
        """
    }
    
    func getTermsOfServiceHTML() -> String {
        """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>服务条款</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    padding: 20px;
                    max-width: 800px;
                    margin: 0 auto;
                }
                h1 { color: #007AFF; }
                h2 { color: #333; margin-top: 30px; }
                .section { margin-bottom: 30px; }
            </style>
        </head>
        <body>
            <h1>iCar 服务条款</h1>
            <p class="last-updated">最后更新日期：2026年4月23日</p>
            
            <div class="section">
                <h2>1. 接受条款</h2>
                <p>使用 iCar 应用即表示您同意本服务条款。如果您不同意，请勿使用本应用。</p>
            </div>
            
            <div class="section">
                <h2>2. 服务描述</h2>
                <p>iCar 是一款车辆检测和管理应用，提供以下功能：</p>
                <ul>
                    <li>车辆信息管理</li>
                    <li>漆面检测和分析</li>
                    <li>轮胎花纹检测</li>
                    <li>发动机声音分析</li>
                    <li>检测报告生成</li>
                </ul>
            </div>
            
            <div class="section">
                <h2>3. 用户责任</h2>
                <p>您同意：</p>
                <ul>
                    <li>提供准确的车辆信息</li>
                    <li>合法使用本应用</li>
                    <li>不滥用或干扰应用服务</li>
                    <li>对自己的账户安全负责</li>
                </ul>
            </div>
            
            <div class="section">
                <h2>4. 免责声明</h2>
                <p>本应用提供的检测结果仅供参考，不构成专业诊断。重要决策请咨询专业人士。</p>
            </div>
        </body>
        </html>
        """
    }
    
    // MARK: - Data Management
    
    func exportUserData() async throws -> URL {
        let dataPersistence = DataPersistenceService.shared
        let exportPackage = try await dataPersistence.exportAllData()
        
        // 创建临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let exportURL = tempDir.appendingPathComponent("iCar_Export_\(ISO8601DateFormatter().string(from: Date())).json")
        
        let jsonData = try JSONSerialization.data(
            withJSONObject: exportPackage.generateJSON(),
            options: .prettyPrinted
        )
        
        try jsonData.write(to: exportURL)
        return exportURL
    }
    
    func deleteAllUserData() async throws {
        let dataPersistence = DataPersistenceService.shared
        try await dataPersistence.clearAllData()
        
        // 清除缓存
        try? CacheManager.shared.clearAllCache()
        
        // 清除用户偏好设置（保留隐私政策接受状态）
        let privacyAccepted = userDefaults.bool(forKey: "privacy_policy_accepted")
        let keysToRemove = userDefaults.dictionaryRepresentation().keys.filter { key in
            !key.hasPrefix("NS") && !key.hasPrefix("Apple") && key != "privacy_policy_accepted"
        }
        keysToRemove.forEach { userDefaults.removeObject(forKey: $0) }
        userDefaults.set(privacyAccepted, forKey: "privacy_policy_accepted")
    }
    
    func deleteOldData(olderThan days: Int) async throws -> Int {
        let dataPersistence = DataPersistenceService.shared
        return try await dataPersistence.cleanupOldData(olderThan: days)
    }
    
    // MARK: - Privacy Settings
    
    func getPrivacySettings() -> PrivacySettings {
        if let data = userDefaults.data(forKey: privacySettingsKey),
           let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) {
            return settings
        }
        return PrivacySettings.default
    }
    
    func updatePrivacySettings(_ settings: PrivacySettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: privacySettingsKey)
        }
    }
    
    func hasAcceptedPrivacyPolicy() -> Bool {
        userDefaults.bool(forKey: "privacy_policy_accepted")
    }
    
    func acceptPrivacyPolicy() {
        userDefaults.set(true, forKey: "privacy_policy_accepted")
        userDefaults.set(Date(), forKey: "privacy_policy_accepted_date")
    }
    
    // MARK: - Analytics & Tracking
    
    func isAnalyticsEnabled() -> Bool {
        let settings = getPrivacySettings()
        return settings.isAnalyticsEnabled
    }
    
    func setAnalyticsEnabled(_ enabled: Bool) {
        var settings = getPrivacySettings()
        settings.isAnalyticsEnabled = enabled
        updatePrivacySettings(settings)
    }
    
    func isCrashReportingEnabled() -> Bool {
        let settings = getPrivacySettings()
        return settings.isCrashReportingEnabled
    }
    
    func setCrashReportingEnabled(_ enabled: Bool) {
        var settings = getPrivacySettings()
        settings.isCrashReportingEnabled = enabled
        updatePrivacySettings(settings)
    }
    
    // MARK: - App Settings URL
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PrivacyService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.locationPermission = LocationPermissionStatus(from: status)
        }
    }
}

// MARK: - Supporting Types

enum PermissionStatus: String, CaseIterable {
    case notDetermined = "notDetermined"
    case restricted = "restricted"
    case denied = "denied"
    case authorized = "authorized"
    case limited = "limited"
    
    init(from status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        @unknown default:
            self = .notDetermined
        }
    }
    
    init(from status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .limited:
            self = .limited
        @unknown default:
            self = .notDetermined
        }
    }
    
    init(from status: CNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        @unknown default:
            self = .notDetermined
        }
    }
    
    init(from status: EKAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        @unknown default:
            self = .notDetermined
        }
    }
    
    init(from status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .limited
        case .ephemeral:
            self = .authorized
        @unknown default:
            self = .notDetermined
        }
    }
    
    @available(iOS 14, *)
    init(from status: ATTrackingManager.AuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        @unknown default:
            self = .notDetermined
        }
    }
    
    var displayName: String {
        switch self {
        case .notDetermined:
            return "未决定"
        case .restricted:
            return "受限"
        case .denied:
            return "已拒绝"
        case .authorized:
            return "已授权"
        case .limited:
            return "有限访问"
        }
    }
    
    var icon: String {
        switch self {
        case .notDetermined:
            return "questionmark.circle"
        case .restricted:
            return "exclamationmark.triangle"
        case .denied:
            return "xmark.circle.fill"
        case .authorized:
            return "checkmark.circle.fill"
        case .limited:
            return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .notDetermined:
            return .orange
        case .restricted:
            return .yellow
        case .denied:
            return .red
        case .authorized:
            return .green
        case .limited:
            return .blue
        }
    }
}

enum LocationPermissionStatus: String, CaseIterable {
    case notDetermined = "notDetermined"
    case restricted = "restricted"
    case denied = "denied"
    case authorizedWhenInUse = "authorizedWhenInUse"
    case authorizedAlways = "authorizedAlways"
    
    init(from status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorizedWhenInUse:
            self = .authorizedWhenInUse
        case .authorizedAlways:
            self = .authorizedAlways
        @unknown default:
            self = .notDetermined
        }
    }
    
    var displayName: String {
        switch self {
        case .notDetermined:
            return "未决定"
        case .restricted:
            return "受限"
        case .denied:
            return "已拒绝"
        case .authorizedWhenInUse:
            return "使用期间"
        case .authorizedAlways:
            return "始终允许"
        }
    }
    
    var icon: String {
        switch self {
        case .notDetermined:
            return "questionmark.circle"
        case .restricted:
            return "exclamationmark.triangle"
        case .denied:
            return "xmark.circle.fill"
        case .authorizedWhenInUse:
            return "location.fill"
        case .authorizedAlways:
            return "location.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .notDetermined:
            return .orange
        case .restricted:
            return .yellow
        case .denied:
            return .red
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        }
    }
}

struct PrivacySettings: Codable {
    var isAnalyticsEnabled: Bool
    var isCrashReportingEnabled: Bool
    var isPersonalizedAdsEnabled: Bool
    var dataRetentionDays: Int
    var autoDeleteOldData: Bool
    var requireBiometricForSensitiveData: Bool
    
    static let `default` = PrivacySettings(
        isAnalyticsEnabled: false,
        isCrashReportingEnabled: true,
        isPersonalizedAdsEnabled: false,
        dataRetentionDays: 365,
        autoDeleteOldData: false,
        requireBiometricForSensitiveData: false
    )
}

// MARK: - Privacy Permission Item

struct PrivacyPermissionItem: Identifiable {
    let id = UUID()
    let type: PermissionType
    let title: String
    let description: String
    let icon: String
    var status: PermissionStatus
}

enum PermissionType {
    case camera
    case microphone
    case location
    case photoLibrary
    case contacts
    case calendar
    case notifications
    case tracking
}

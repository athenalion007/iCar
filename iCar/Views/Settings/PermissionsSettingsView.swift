import SwiftUI
import AVFoundation
import Photos
import UserNotifications
import CoreLocation

struct PermissionsSettingsView: View {
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @State private var photoStatus: PHAuthorizationStatus = .notDetermined
    @State private var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    
    var body: some View {
        List {
            Section(header: Text("必需权限").textCase(.uppercase)) {
                PermissionRow(
                    icon: "camera.fill",
                    title: "相机",
                    status: cameraStatus
                )

                PermissionRow(
                    icon: "photo.fill",
                    title: "相册",
                    status: photoStatus.toAVStatus()
                )

                PermissionRow(
                    icon: "mic.fill",
                    title: "麦克风",
                    status: microphoneStatus
                )
            }

            Section(header: Text("可选权限").textCase(.uppercase)) {
                PermissionRow(
                    icon: "bell.fill",
                    title: "通知",
                    status: notificationStatus.toAVStatus()
                )

                PermissionRow(
                    icon: "location.fill",
                    title: "位置",
                    status: locationStatus.toAVStatus()
                )
            }

            Section {
                Button {
                    openSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                        Text("前往系统设置")
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
            }
        }
        .listStyle(.plain)
        .background(.black)
        .scrollContentBackground(.hidden)
        .navigationTitle("权限管理")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
        .onAppear {
            checkAllPermissions()
        }
    }
    
    private func checkAllPermissions() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoStatus = PHPhotoLibrary.authorizationStatus()
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        locationStatus = CLLocationManager().authorizationStatus
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async { [self] in
                notificationStatus = status
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let status: AVAuthorizationStatus

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 30)
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding()
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var statusText: String {
        switch status {
        case .authorized:
            return "已授权"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限"
        case .notDetermined:
            return "未申请"
        @unknown default:
            return "未知"
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized:
            return .white
        case .denied, .restricted:
            return .gray
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
}

extension PHAuthorizationStatus {
    func toAVStatus() -> AVAuthorizationStatus {
        switch self {
        case .authorized, .limited:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
}

extension UNAuthorizationStatus {
    func toAVStatus() -> AVAuthorizationStatus {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
}

extension CLAuthorizationStatus {
    func toAVStatus() -> AVAuthorizationStatus {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
}

#Preview {
    NavigationStack {
        PermissionsSettingsView()
    }
}

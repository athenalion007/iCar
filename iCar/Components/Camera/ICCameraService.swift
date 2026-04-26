import SwiftUI
import AVFoundation

// MARK: - Enums

enum ICCameraFlashMode {
    case auto, on, off
}

// MARK: - ICCameraService

@MainActor
class ICCameraService: NSObject, ObservableObject {
    
    // MARK: - Published
    
    @Published var session = AVCaptureSession()
    @Published var flashMode: ICCameraFlashMode = .auto
    @Published var isCapturing = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Private
    
    private var captureDevice: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var captureCompletion: ((UIImage?) -> Void)?
    private let sessionQueue = DispatchQueue(label: "com.icar.camera")
    
    // MARK: - Lifecycle
    
    override init() {
        super.init()
        checkPermission()
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.setupCameraSync()
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    // MARK: - Setup (Sync version for background queue)
    
    private func setupCameraSync() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        session.sessionPreset = .photo
        
        // 输入
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            Task { @MainActor in
                self.errorMessage = "无法访问相机"
                self.showError = true
            }
            return
        }
        
        captureDevice = device
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                Task { @MainActor in
                    self.errorMessage = "无法添加相机输入"
                    self.showError = true
                }
                return
            }
            session.addInput(input)
        } catch {
            Task { @MainActor in
                self.errorMessage = "相机初始化失败"
                self.showError = true
            }
            return
        }
        
        // 输出
        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            Task { @MainActor in
                self.errorMessage = "无法添加照片输出"
                self.showError = true
            }
            return
        }
        session.addOutput(output)
        
        // 设置最高分辨率
        output.isHighResolutionCaptureEnabled = true
        
        photoOutput = output
    }
    
    // MARK: - Permission
    
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        case .denied, .restricted:
            errorMessage = "请在设置中允许相机权限"
            showError = true
        default:
            break
        }
    }
    
    // MARK: - Capture
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard !isCapturing, let photoOutput = photoOutput else {
            completion(nil)
            return
        }
        
        isCapturing = true
        captureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        
        switch flashMode {
        case .auto: settings.flashMode = .auto
        case .on: settings.flashMode = .on
        case .off: settings.flashMode = .off
        }
        
        settings.isHighResolutionPhotoEnabled = true
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Flash
    
    func toggleFlash() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on: flashMode = .off
        case .off: flashMode = .auto
        }
    }
    
    // MARK: - Focus
    
    func setFocusPoint(_ point: CGPoint) {
        guard let device = captureDevice else { return }
        
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            print("对焦失败: \(error)")
        }
    }
    
    // MARK: - Error
    
    func dismissError() {
        showError = false
        errorMessage = ""
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ICCameraService: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            print("拍摄失败: \(error)")
            Task { @MainActor [weak self] in
                self?.isCapturing = false
                self?.captureCompletion?(nil)
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor [weak self] in
                self?.isCapturing = false
                self?.captureCompletion?(nil)
            }
            return
        }
        
        Task { @MainActor [weak self] in
            self?.isCapturing = false
            self?.captureCompletion?(image)
        }
    }
}

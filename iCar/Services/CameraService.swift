@preconcurrency import AVFoundation
import SwiftUI
import Combine

// MARK: - Camera Service Errors

enum CameraError: LocalizedError {
    case permissionDenied
    case permissionRestricted
    case captureSessionNotRunning
    case invalidInput
    case invalidOutput
    case cameraNotAvailable
    case photoCaptureFailed
    case zoomFailed
    case focusFailed
    case torchFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "相机权限被拒绝，请在设置中开启"
        case .permissionRestricted:
            return "相机权限受限"
        case .captureSessionNotRunning:
            return "相机未启动"
        case .invalidInput:
            return "相机输入无效"
        case .invalidOutput:
            return "相机输出无效"
        case .cameraNotAvailable:
            return "相机不可用"
        case .photoCaptureFailed:
            return "拍照失败"
        case .zoomFailed:
            return "变焦失败"
        case .focusFailed:
            return "对焦失败"
        case .torchFailed:
            return "闪光灯控制失败"
        case .unknown:
            return "未知错误"
        }
    }
}

// MARK: - Camera Service Delegate

protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: AnyObject, didCapturePhoto image: UIImage)
    func cameraService(_ service: AnyObject, didFailWithError error: CameraError)
    func cameraServiceDidChangeZoom(_ service: AnyObject, zoomFactor: CGFloat)
    func cameraServiceDidChangeFocus(_ service: AnyObject, point: CGPoint)
}

// MARK: - Camera Service

@MainActor
final class CameraService: NSObject, ObservableObject {

    // MARK: - Shared Instance

    static let shared = CameraService()

    // MARK: - Published Properties

    @Published var isSessionRunning = false
    @Published var isFlashOn = false
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var maxZoomFactor: CGFloat = 1.0
    @Published var minZoomFactor: CGFloat = 1.0
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var isCapturingPhoto = false
    @Published var focusPoint: CGPoint?

    // MARK: - Properties

    weak var delegate: CameraServiceDelegate?

    nonisolated(unsafe) let captureSession = AVCaptureSession()
    var videoDeviceInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?

    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false

    // MARK: - Initialization

    private override init() {
        super.init()
        checkCameraPermission()
    }
    
    nonisolated deinit {
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
    
    // MARK: - Permission
    
    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied:
            return false
        case .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Session Configuration
    
    func configureSession() throws {
        guard cameraPermissionStatus == .authorized else {
            throw CameraError.permissionDenied
        }
        
        guard !isConfigured else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        // 添加视频输入
        try setupVideoInput()
        
        // 添加照片输出
        try setupPhotoOutput()
        
        captureSession.commitConfiguration()
        isConfigured = true
    }
    
    private func setupVideoInput() throws {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.cameraNotAvailable
        }
        
        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        
        guard captureSession.canAddInput(videoInput) else {
            throw CameraError.invalidInput
        }
        
        captureSession.addInput(videoInput)
        videoDeviceInput = videoInput
        
        // 更新变焦范围
        updateZoomFactors()
    }
    
    private func setupPhotoOutput() throws {
        let photoOutput = AVCapturePhotoOutput()
        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .quality
        
        guard captureSession.canAddOutput(photoOutput) else {
            throw CameraError.invalidOutput
        }
        
        captureSession.addOutput(photoOutput)
        self.photoOutput = photoOutput
    }
    
    // MARK: - Session Control
    
    func startSession() {
        guard isConfigured else { return }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = false
                }
            }
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            delegate?.cameraService(self, didFailWithError: .captureSessionNotRunning)
            return
        }
        
        isCapturingPhoto = true
        
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        settings.photoQualityPrioritization = .quality
        
        // 闪光灯设置
        if isFlashOn, let device = videoDeviceInput?.device, device.hasFlash {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Flash Control
    
    func toggleFlash() {
        guard let device = videoDeviceInput?.device, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
            
            isFlashOn = device.torchMode == .on
        } catch {
            delegate?.cameraService(self, didFailWithError: .torchFailed)
        }
    }
    
    func setFlashMode(_ mode: AVCaptureDevice.TorchMode) {
        guard let device = videoDeviceInput?.device, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = mode
            device.unlockForConfiguration()
            
            isFlashOn = mode == .on
        } catch {
            delegate?.cameraService(self, didFailWithError: .torchFailed)
        }
    }
    
    // MARK: - Zoom Control
    
    private func updateZoomFactors() {
        guard let device = videoDeviceInput?.device else { return }
        
        minZoomFactor = device.minAvailableVideoZoomFactor
        maxZoomFactor = device.maxAvailableVideoZoomFactor
        currentZoomFactor = device.videoZoomFactor
    }
    
    func setZoomFactor(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else {
            delegate?.cameraService(self, didFailWithError: .zoomFailed)
            return
        }
        
        let clampedFactor = max(minZoomFactor, min(factor, maxZoomFactor))
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()
            
            currentZoomFactor = clampedFactor
            delegate?.cameraServiceDidChangeZoom(self, zoomFactor: clampedFactor)
        } catch {
            delegate?.cameraService(self, didFailWithError: .zoomFailed)
        }
    }
    
    func zoomIn(step: CGFloat = 0.5) {
        setZoomFactor(currentZoomFactor + step)
    }
    
    func zoomOut(step: CGFloat = 0.5) {
        setZoomFactor(currentZoomFactor - step)
    }
    
    func resetZoom() {
        setZoomFactor(1.0)
    }
    
    // MARK: - Focus Control
    
    func focus(at point: CGPoint) {
        guard let device = videoDeviceInput?.device else {
            delegate?.cameraService(self, didFailWithError: .focusFailed)
            return
        }
        
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
            
            focusPoint = point
            delegate?.cameraServiceDidChangeFocus(self, point: point)
            
            // 清除对焦框显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.focusPoint = nil
            }
        } catch {
            delegate?.cameraService(self, didFailWithError: .focusFailed)
        }
    }
    
    func resetFocus() {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            focusPoint = nil
        } catch {
            delegate?.cameraService(self, didFailWithError: .focusFailed)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let photoData = photo.fileDataRepresentation()
        Task { @MainActor in
            self.isCapturingPhoto = false
            
            if let error = error {
                print("Photo capture error: \(error.localizedDescription)")
                self.delegate?.cameraService(self, didFailWithError: .photoCaptureFailed)
                return
            }
            
            guard let imageData = photoData,
                  let image = UIImage(data: imageData) else {
                self.delegate?.cameraService(self, didFailWithError: .photoCaptureFailed)
                return
            }
            
            self.delegate?.cameraService(self, didCapturePhoto: image)
        }
    }
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // 拍照即将开始
    }
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // 拍照完成
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    
    let session: AVCaptureSession
    var onTap: ((CGPoint) -> Void)?
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // 更新视图
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CameraPreviewView
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            guard let previewView = gesture.view as? VideoPreviewView else { return }
            
            // 转换坐标到相机坐标系 (0.0 - 1.0)
            let layerPoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: location)
            parent.onTap?(layerPoint)
        }
    }
}

// MARK: - Video Preview View

class VideoPreviewView: UIView {
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

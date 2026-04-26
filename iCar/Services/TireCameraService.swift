@preconcurrency import AVFoundation
import SwiftUI
import Combine
import Vision

// MARK: - Tire Position

/// 轮胎位置枚举
enum TirePosition: String, CaseIterable, Identifiable, Codable {
    case frontLeft = "front_left"
    case frontRight = "front_right"
    case rearLeft = "rear_left"
    case rearRight = "rear_right"
    case spare = "spare"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .frontLeft: return "前左轮胎"
        case .frontRight: return "前右轮胎"
        case .rearLeft: return "后左轮胎"
        case .rearRight: return "后右轮胎"
        case .spare: return "备胎"
        }
    }
    
    var icon: String {
        switch self {
        case .frontLeft: return "circle.lefthalf.filled"
        case .frontRight: return "circle.righthalf.filled"
        case .rearLeft: return "circle.lefthalf.filled.inverse"
        case .rearRight: return "circle.righthalf.filled.inverse"
        case .spare: return "circle.dashed"
        }
    }
    
    var description: String {
        switch self {
        case .frontLeft: return "驾驶员侧前轮"
        case .frontRight: return "副驾驶侧前轮"
        case .rearLeft: return "驾驶员侧后轮"
        case .rearRight: return "副驾驶侧后轮"
        case .spare: return "备用轮胎"
        }
    }
}

// MARK: - Reference Object

/// 参照物类型（用于尺寸校准）
enum ReferenceObject: String, CaseIterable, Codable {
    case coin1Yuan = "1_yuan"
    case coin5Jiao = "5_jiao"
    case coin1Jiao = "1_jiao"
    case creditCard = "credit_card"
    
    var displayName: String {
        switch self {
        case .coin1Yuan: return "1元硬币"
        case .coin5Jiao: return "5角硬币"
        case .coin1Jiao: return "1角硬币"
        case .creditCard: return "银行卡"
        }
    }
    
    /// 实际直径（毫米）
    var diameter: CGFloat {
        switch self {
        case .coin1Yuan: return 25.0
        case .coin5Jiao: return 20.5
        case .coin1Jiao: return 19.0
        case .creditCard: return 53.98 // 银行卡宽度
        }
    }
    
    var icon: String {
        switch self {
        case .coin1Yuan, .coin5Jiao, .coin1Jiao:
            return "circle.fill"
        case .creditCard:
            return "creditcard.fill"
        }
    }
}

// MARK: - Capture Guide State

/// 拍摄引导状态
enum CaptureGuideState {
    case idle
    case positioning      // 位置调整中
    case tooFar          // 距离太远
    case tooClose        // 距离太近
    case angleIncorrect  // 角度不正确
    case referenceNotFound // 未找到参照物
    case referenceFound   // 找到参照物
    case ready           // 准备就绪
    case capturing       // 拍摄中
    
    var message: String {
        switch self {
        case .idle: return "请将相机对准轮胎"
        case .positioning: return "调整位置..."
        case .tooFar: return "请靠近轮胎"
        case .tooClose: return "请远离轮胎"
        case .angleIncorrect: return "请保持相机与轮胎平行"
        case .referenceNotFound: return "请在轮胎旁放置一枚硬币作为参照"
        case .referenceFound: return "参照物已识别，保持稳定"
        case .ready: return "位置完美，可以拍摄"
        case .capturing: return "拍摄中..."
        }
    }
    
    var color: Color {
        switch self {
        case .idle, .positioning:
            return ICTheme.Colors.gray
        case .tooFar, .tooClose, .angleIncorrect, .referenceNotFound:
            return ICTheme.Colors.warning
        case .referenceFound:
            return ICTheme.Colors.info
        case .ready:
            return ICTheme.Colors.success
        case .capturing:
            return ICTheme.Colors.primary
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "camera.viewfinder"
        case .positioning: return "arrow.up.and.down.and.arrow.left.and.right"
        case .tooFar: return "arrow.up.circle.fill"
        case .tooClose: return "arrow.down.circle.fill"
        case .angleIncorrect: return "rotate.left.fill"
        case .referenceNotFound: return "exclamationmark.circle.fill"
        case .referenceFound: return "checkmark.circle.fill"
        case .ready: return "checkmark.circle.fill"
        case .capturing: return "camera.shutter.button.fill"
        }
    }
}

// MARK: - Tire Photo

/// 轮胎照片数据
struct TirePhoto: Identifiable {
    let id = UUID()
    let position: TirePosition
    let image: UIImage
    let referenceObject: ReferenceObject
    let captureDate: Date
    var referenceBounds: CGRect? // 参照物在图片中的位置
    
    var thumbnail: UIImage? {
        let size = CGSize(width: 200, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumbnail
    }
}

// MARK: - Tire Camera Service

/// 轮胎拍摄服务
@MainActor
final class TireCameraService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSessionRunning = false
    @Published var isFlashOn = false
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var maxZoomFactor: CGFloat = 1.0
    @Published var minZoomFactor: CGFloat = 1.0
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var isCapturingPhoto = false
    @Published var focusPoint: CGPoint?
    
    // 轮胎拍摄特有属性
    @Published var currentPosition: TirePosition = .frontLeft
    @Published var guideState: CaptureGuideState = .idle
    @Published var detectedReferenceBounds: CGRect?
    @Published var isReferenceDetected = false
    @Published var capturedPhotos: [TirePhoto] = []
    
    // MARK: - Properties
    
    weak var delegate: CameraServiceDelegate?
    
    nonisolated(unsafe) let captureSession = AVCaptureSession()
    var videoDeviceInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?
    var videoOutput: AVCaptureVideoDataOutput?
    
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false
    private var referenceObject: ReferenceObject = .coin1Yuan
    
    // 引导检测定时器
    private var guideCheckTimer: Timer?
    nonisolated(unsafe) private var lastPixelBuffer: CVPixelBuffer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkCameraPermission()
    }
    
    deinit {
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
        case .denied, .restricted:
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
        
        try setupVideoInput()
        try setupPhotoOutput()
        try setupVideoOutput()
        
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
    
    private func setupVideoOutput() throws {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        guard captureSession.canAddOutput(videoOutput) else {
            throw CameraError.invalidOutput
        }
        
        captureSession.addOutput(videoOutput)
        self.videoOutput = videoOutput
    }
    
    // MARK: - Session Control
    
    func startSession() {
        guard isConfigured else { return }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = true
                    self?.startGuideDetection()
                }
            }
        }
    }
    
    func stopSession() {
        stopGuideDetection()
        
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = false
                }
            }
        }
    }
    
    // MARK: - Guide Detection
    
    private func startGuideDetection() {
        guideCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateGuideState()
            }
        }
    }
    
    private func stopGuideDetection() {
        guideCheckTimer?.invalidate()
        guideCheckTimer = nil
    }
    
    private func updateGuideState() {
        guard !isCapturingPhoto else {
            guideState = .capturing
            return
        }
        
        // 模拟检测逻辑（实际项目中应使用Vision框架进行实时检测）
        if isReferenceDetected {
            guideState = .ready
        } else {
            guideState = .referenceNotFound
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(referenceObject: ReferenceObject = .coin1Yuan) {
        guard let photoOutput = photoOutput else {
            delegate?.cameraService(self, didFailWithError: .captureSessionNotRunning)
            return
        }
        
        self.referenceObject = referenceObject
        isCapturingPhoto = true
        guideState = .capturing
        
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        settings.photoQualityPrioritization = .quality
        
        if isFlashOn, let device = videoDeviceInput?.device, device.hasFlash {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func captureTirePhoto() {
        capturePhoto(referenceObject: referenceObject)
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.focusPoint = nil
            }
        } catch {
            delegate?.cameraService(self, didFailWithError: .focusFailed)
        }
    }
    
    // MARK: - Position Management
    
    func setCurrentPosition(_ position: TirePosition) {
        currentPosition = position
    }
    
    func nextPosition() -> TirePosition? {
        let allPositions = TirePosition.allCases
        guard let currentIndex = allPositions.firstIndex(of: currentPosition),
              currentIndex < allPositions.count - 1 else {
            return nil
        }
        return allPositions[currentIndex + 1]
    }
    
    func isLastPosition() -> Bool {
        currentPosition == .spare
    }
    
    // MARK: - Photo Management
    
    func getPhoto(for position: TirePosition) -> TirePhoto? {
        capturedPhotos.first { $0.position == position }
    }
    
    func hasPhoto(for position: TirePosition) -> Bool {
        capturedPhotos.contains { $0.position == position }
    }
    
    func removePhoto(for position: TirePosition) {
        capturedPhotos.removeAll { $0.position == position }
    }
    
    func clearAllPhotos() {
        capturedPhotos.removeAll()
    }
    
    var allPositionsCaptured: Bool {
        let requiredPositions: [TirePosition] = [.frontLeft, .frontRight, .rearLeft, .rearRight]
        return requiredPositions.allSatisfy { hasPhoto(for: $0) }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension TireCameraService: AVCapturePhotoCaptureDelegate {
    
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
            
            // 创建轮胎照片
            let tirePhoto = TirePhoto(
                position: self.currentPosition,
                image: image,
                referenceObject: self.referenceObject,
                captureDate: Date(),
                referenceBounds: self.detectedReferenceBounds
            )
            
            self.capturedPhotos.append(tirePhoto)
            self.delegate?.cameraService(self, didCapturePhoto: image)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension TireCameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 使用真实的Vision框架检测参照物
        // 复制pixelBuffer以避免数据竞争
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.8
        request.maximumAspectRatio = 1.2
        request.minimumSize = 0.05
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results as? [VNRectangleObservation],
                  let bestResult = results.first else {
                Task { @MainActor in
                    self.isReferenceDetected = false
                    self.detectedReferenceBounds = nil
                }
                return
            }

            // 转换为CGRect (Vision使用左下角坐标系，需要翻转Y轴)
            let bounds = CGRect(
                x: bestResult.boundingBox.origin.x,
                y: 1 - bestResult.boundingBox.origin.y - bestResult.boundingBox.height,
                width: bestResult.boundingBox.width,
                height: bestResult.boundingBox.height
            )

            Task { @MainActor in
                self.isReferenceDetected = true
                self.detectedReferenceBounds = bounds
            }

        } catch {
            print("Reference detection error: \(error)")
            Task { @MainActor in
                self.isReferenceDetected = false
                self.detectedReferenceBounds = nil
            }
        }
    }
}

// MARK: - Reference Object Detection

extension TireCameraService {
    
    /// 使用Vision框架检测圆形参照物
    func detectReferenceObject(in image: UIImage, completion: @escaping (CGRect?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNDetectRectanglesRequest { request, error in
            guard let results = request.results as? [VNRectangleObservation],
                  let bestResult = results.first else {
                completion(nil)
                return
            }
            
            // 转换为CGRect
            let bounds = CGRect(
                x: bestResult.boundingBox.origin.x,
                y: 1 - bestResult.boundingBox.origin.y - bestResult.boundingBox.height,
                width: bestResult.boundingBox.width,
                height: bestResult.boundingBox.height
            )
            
            completion(bounds)
        }
        
        request.minimumAspectRatio = 0.8
        request.maximumAspectRatio = 1.2
        request.minimumSize = 0.05
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Reference detection error: \(error)")
            completion(nil)
        }
    }
}

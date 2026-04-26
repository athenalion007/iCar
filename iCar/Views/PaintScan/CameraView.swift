import SwiftUI

// MARK: - Camera View

struct CameraView: View {
    
    // MARK: - Properties
    
    @ObservedObject var cameraService: CameraService
    @ObservedObject var viewModel: PaintScanViewModel
    
    @State private var showGridLines = true
    @State private var showPermissionAlert = false
    @State private var permissionError: CameraError?
    
    var onCapture: ((UIImage) -> Void)?
    var onDismiss: (() -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 相机预览层
            cameraPreviewLayer
            
            // 网格线
            if showGridLines {
                GridLinesView()
                    .allowsHitTesting(false)
            }
            
            // 对焦框
            focusIndicator
            
            // 顶部工具栏
            topToolbar
                .padding(.top, 50)
            
            // 底部控制栏
            bottomControls
                .padding(.bottom, 34)
            
            // 变焦控制
            zoomControl
                .padding(.trailing, 16)
        }
        .ignoresSafeArea()
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .alert("相机权限", isPresented: $showPermissionAlert) {
            Button("取消", role: .cancel) { }
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(permissionError?.errorDescription ?? "需要相机权限才能使用此功能")
        }
    }
    
    // MARK: - Camera Preview Layer
    
    private var cameraPreviewLayer: some View {
        CameraPreviewView(
            session: cameraService.captureSession,
            onTap: { point in
                cameraService.focus(at: point)
            }
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Focus Indicator
    
    @ViewBuilder
    private var focusIndicator: some View {
        if let focusPoint = cameraService.focusPoint {
            GeometryReader { geometry in
                let x = focusPoint.x * geometry.size.width
                let y = focusPoint.y * geometry.size.height
                
                FocusFrameView()
                    .position(x: x, y: y)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: focusPoint)
            }
        }
    }
    
    // MARK: - Top Toolbar
    
    private var topToolbar: some View {
        HStack {
            // 关闭按钮
            ICIconButton(icon: "xmark", style: .ghost, size: .medium) {
                onDismiss?()
            }
            
            Spacer()
            
            // 网格线切换
            ICIconButton(
                icon: showGridLines ? "grid" : "grid.slash",
                style: .ghost,
                size: .medium
            ) {
                withAnimation {
                    showGridLines.toggle()
                }
            }
            
            // 闪光灯按钮
            ICIconButton(
                icon: cameraService.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                style: cameraService.isFlashOn ? .primary : .ghost,
                size: .medium
            ) {
                cameraService.toggleFlash()
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 32) {
            // 当前拍摄位置提示
            if let currentPosition = viewModel.currentPosition {
                HStack(spacing: 16) {
                    Image(systemName: currentPosition.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    Text(currentPosition.name)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
            }
            
            // 拍摄控制
            HStack(spacing: 48) {
                // 已拍摄缩略图
                if let lastPhoto = viewModel.capturedPhotos.last {
                    ThumbnailButton(image: lastPhoto.image) {
                        // 查看已拍摄照片
                    }
                } else {
                    Color.clear
                        .frame(width: 56, height: 56)
                }
                
                // 拍摄按钮
                CaptureButton(
                    isCapturing: cameraService.isCapturingPhoto
                ) {
                    capturePhoto()
                }
                
                // 占位保持对称
                Color.clear
                    .frame(width: 56, height: 56)
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Zoom Control
    
    private var zoomControl: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // 变焦滑块
            ZoomSlider(
                currentZoom: $cameraService.currentZoomFactor,
                minZoom: cameraService.minZoomFactor,
                maxZoom: min(cameraService.maxZoomFactor, 5.0)
            ) { newZoom in
                cameraService.setZoomFactor(newZoom)
            }
            .frame(height: 150)
            
            Spacer()
        }
    }
    
    // MARK: - Methods
    
    private func setupCamera() {
        Task {
            let hasPermission = await cameraService.requestCameraPermission()
            
            if hasPermission {
                do {
                    try cameraService.configureSession()
                    cameraService.startSession()
                } catch {
                    if let cameraError = error as? CameraError {
                        permissionError = cameraError
                        showPermissionAlert = true
                    }
                }
            } else {
                permissionError = .permissionDenied
                showPermissionAlert = true
            }
        }
    }
    
    private func capturePhoto() {
        cameraService.capturePhoto()
    }
}

// MARK: - Grid Lines View

struct GridLinesView: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // 垂直线
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 0.5)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 0.5)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 0.5)
                }
                
                // 水平线
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 0.5)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 0.5)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 0.5)
                }
            }
        }
    }
}

// MARK: - Focus Frame View

struct FocusFrameView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // 外框
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 70, height: 70)

            // 四角标记
            Group {
                // 左上
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 15))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 15, y: 0))
                }
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 70, height: 70)

                // 右上
                Path { path in
                    path.move(to: CGPoint(x: 55, y: 0))
                    path.addLine(to: CGPoint(x: 70, y: 0))
                    path.addLine(to: CGPoint(x: 70, y: 15))
                }
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 70, height: 70)

                // 左下
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 55))
                    path.addLine(to: CGPoint(x: 0, y: 70))
                    path.addLine(to: CGPoint(x: 15, y: 70))
                }
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 70, height: 70)

                // 右下
                Path { path in
                    path.move(to: CGPoint(x: 55, y: 70))
                    path.addLine(to: CGPoint(x: 70, y: 70))
                    path.addLine(to: CGPoint(x: 70, y: 55))
                }
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 70, height: 70)
            }
        }
        .scaleEffect(isAnimating ? 1.0 : 1.2)
        .opacity(isAnimating ? 1.0 : 0.5)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Capture Button

struct CaptureButton: View {
    let isCapturing: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 外圈
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                // 内圈
                Circle()
                    .fill(isCapturing ? Color.white.opacity(0.5) : Color.white)
                    .frame(width: isPressed ? 56 : 60, height: isPressed ? 56 : 60)
            }
        }
        .disabled(isCapturing)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = false
            }
        }
    }
}

// MARK: - Thumbnail Button

struct ThumbnailButton: View {
    let image: UIImage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
        }
    }
}

// MARK: - Zoom Slider

struct ZoomSlider: View {
    @Binding var currentZoom: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onZoomChange: (CGFloat) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 4) {
            // 放大按钮
            ZoomButton(icon: "plus") {
                let newZoom = min(currentZoom + 0.5, maxZoom)
                onZoomChange(newZoom)
            }
            
            // 滑块
            GeometryReader { geometry in
                let height = geometry.size.height
                let percentage = (currentZoom - minZoom) / (maxZoom - minZoom)
                let thumbY = height * (1 - percentage)
                
                ZStack(alignment: .bottom) {
                    // 轨道
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 4)
                    
                    // 进度
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 4, height: height * percentage)
                    
                    // 滑块
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)
                        .position(x: geometry.size.width / 2, y: height - thumbY)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    let newY = max(0, min(height, height - value.location.y))
                                    let newPercentage = newY / height
                                    let newZoom = minZoom + (maxZoom - minZoom) * newPercentage
                                    onZoomChange(newZoom)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
            }
            .frame(width: 40)
            
            // 缩小按钮
            ZoomButton(icon: "minus") {
                let newZoom = max(currentZoom - 0.5, minZoom)
                onZoomChange(newZoom)
            }
            
            // 当前变焦值
            Text(String(format: "%.1fx", currentZoom))
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.4))
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }
}

// MARK: - Zoom Button

struct ZoomButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
        }
    }
}

// MARK: - Preview

#Preview {
    CameraView(
        cameraService: CameraService.shared,
        viewModel: PaintScanViewModel()
    )
}

import SwiftUI
import AVFoundation

// MARK: - Tire Camera View

/// 轮胎拍摄视图
struct TireCameraView: View {
    
    // MARK: - Properties
    
    @StateObject private var cameraService = TireCameraService()
    @State private var showPermissionAlert = false
    @State private var showReferenceGuide = true
    @State private var selectedReference: ReferenceObject = .coin1Yuan
    @State private var showPositionSelector = false
    @State private var capturedImage: UIImage?
    @State private var showPhotoReview = false
    
    var onComplete: (([TirePhoto]) -> Void)?
    var onCancel: (() -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 相机预览层
            cameraPreviewLayer
            
            // 覆盖层UI
            overlayUI
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
            Text("需要相机权限来拍摄轮胎照片，请在设置中开启")
        }
        .sheet(isPresented: $showPhotoReview) {
            if let image = capturedImage {
                PhotoReviewSheet(
                    image: image,
                    position: cameraService.currentPosition,
                    onRetake: {
                        showPhotoReview = false
                        capturedImage = nil
                    },
                    onConfirm: {
                        showPhotoReview = false
                        capturedImage = nil
                        moveToNextPosition()
                    }
                )
            }
        }
    }
    
    // MARK: - Camera Preview Layer
    
    private var cameraPreviewLayer: some View {
        Group {
            if cameraService.cameraPermissionStatus == .authorized {
                CameraPreviewView(session: cameraService.captureSession) { point in
                    cameraService.focus(at: point)
                }
                .ignoresSafeArea()
            } else {
                // 无权限提示 - HIG: 高对比度确保可读性
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("需要相机权限")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                    
                    Text("请在设置中允许访问相机以继续拍摄轮胎照片")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        ICButton(
                            title: "开启相机权限",
                            icon: "gear",
                            style: .primary,
                            action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                        
                        ICButton(
                            title: "返回",
                            style: .ghost,
                            action: {
                                onCancel?()
                            }
                        )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
            }
        }
    }
    
    // MARK: - Overlay UI
    
    private var overlayUI: some View {
        ZStack {
            // 轮胎轮廓引导框
            tireGuideOverlay
            
            // 参照物引导
            if showReferenceGuide {
                referenceGuideOverlay
            }
            
            // 顶部栏
            topBar
            
            // 底部控制栏
            bottomControls
            
            // 引导状态提示
            guideStatusView
            
            // 位置选择器
            if showPositionSelector {
                positionSelectorView
            }
        }
    }
    
    // MARK: - Tire Guide Overlay
    
    private var tireGuideOverlay: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * 0.85
            let height = width * 1.2 // 轮胎比例
            
            ZStack {
                // 半透明遮罩
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: width / 2)
                                    .frame(width: width, height: height)
                                    .blendMode(.destinationOut)
                            )
                    )
                
                // 轮胎轮廓
                RoundedRectangle(cornerRadius: width / 2)
                    .strokeBorder(
                        cameraService.guideState.color,
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: cameraService.guideState == .ready ? [] : [10, 5]
                        )
                    )
                    .frame(width: width, height: height)
                    .animation(.easeInOut(duration: 0.3), value: cameraService.guideState)
                
                // 角度标记线
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(cameraService.guideState.color)
                                .frame(width: 2, height: 20)
                            Text("花纹")
                                .font(.caption)
                                .foregroundColor(cameraService.guideState.color)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: width, height: height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Reference Guide Overlay
    
    private var referenceGuideOverlay: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // 参照物位置提示框
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                cameraService.isReferenceDetected ? .green : .orange,
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.3))
                            )
                            .frame(width: 80, height: 80)
                        
                        VStack(spacing: 4) {
                            Image(systemName: selectedReference.icon)
                                // HIG: 使用动态字体
                                .font(.title3)
                                .foregroundColor(cameraService.isReferenceDetected ? .green : .white)
                            
                            Text("放置\(selectedReference.displayName)")
                                // HIG: 使用动态字体
                                .font(.caption)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.trailing, 40)
                    .padding(.bottom, 180)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        VStack {
            HStack {
                // 关闭按钮
                ICIconButton(icon: "xmark", style: .ghost, size: .medium) {
                    onCancel?()
                }
                
                Spacer()
                
                // 当前位置显示
                ICButton(
                    title: cameraService.currentPosition.displayName,
                    icon: cameraService.currentPosition.icon,
                    style: .outline,
                    size: .small,
                    action: {
                        withAnimation {
                            showPositionSelector.toggle()
                        }
                    }
                )
                
                Spacer()
                
                // 闪光灯按钮
                ICIconButton(
                    icon: cameraService.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                    style: cameraService.isFlashOn ? .primary : .ghost,
                    size: .medium
                ) {
                    cameraService.toggleFlash()
                }
            }
            .padding(.horizontal)
            .padding(.top, 60)
            
            // 进度指示器
            HStack(spacing: 8) {
                ForEach(TirePosition.allCases) { position in
                    Circle()
                        .fill(cameraService.hasPhoto(for: position) ? .green : 
                              cameraService.currentPosition == position ? .blue : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 12)
            
            Spacer()
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 32) {
                // 参照物选择器
                HStack(spacing: 16) {
                    Text("参照物:")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    ForEach(ReferenceObject.allCases, id: \.self) { ref in
                        ICButton(
                            title: ref.displayName,
                            style: selectedReference == ref ? .primary : .secondary,
                            size: .small,
                            action: {
                                selectedReference = ref
                            }
                        )
                    }
                }
                
                // 拍摄按钮区域
                HStack {
                    // 相册/预览按钮 - HIG: 无障碍标签
                    if let photo = cameraService.getPhoto(for: cameraService.currentPosition),
                       let thumbnail = photo.thumbnail {
                        Button(action: {
                            // 查看已拍摄照片
                        }) {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(ICTheme.Colors.primary, lineWidth: 2)
                                )
                        }
                        .accessibilityLabel("查看已拍摄的\(cameraService.currentPosition.displayName)照片")
                        .accessibilityHint("双击查看照片详情")
                    } else {
                        Color.clear
                            .frame(width: 56, height: 56)
                            .accessibilityHidden(true)
                    }
                    
                    Spacer()
                    
                    // 拍摄按钮 - HIG优化：主要操作不应被阻塞
                    Button(action: {
                        // HIG: 触觉反馈
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        cameraService.captureTirePhoto()
                    }) {
                        ZStack {
                            // 外圈 - 动态边框
                            Circle()
                                .stroke(
                                    cameraService.isReferenceDetected ? Color.white : Color.yellow,
                                    lineWidth: cameraService.isReferenceDetected ? 4 : 3
                                )
                                .frame(width: 80, height: 80)
                            
                            // 内圈 - 填充
                            Circle()
                                .fill(cameraService.isCapturingPhoto ? Color.gray : Color.white)
                                .frame(width: 68, height: 68)
                            
                            // 加载指示器
                            if cameraService.isCapturingPhoto {
                                ICProgressView(size: .medium, color: .blue)
                            }
                        }
                    }
                    .disabled(cameraService.isCapturingPhoto)
                    // HIG: 按钮尺寸最小 44x44，这里 80x80 符合要求
                    .frame(width: 80, height: 80)
                    .contentShape(Circle())
                    // HIG: 无障碍标签
                    .accessibilityLabel(cameraService.isCapturingPhoto ? "正在拍摄" : "拍摄照片")
                    .accessibilityHint(cameraService.isReferenceDetected ? "双击拍摄\(cameraService.currentPosition.displayName)照片" : "警告：未检测到参照物，双击强制拍摄")
                    .accessibilityAddTraits(.isButton)
                    // HIG: 添加缩放动画反馈
                    .pressEvents {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            // 按下效果由系统处理
                        }
                    } onRelease: {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            // 释放效果
                        }
                    }
                    
                    Spacer()
                    
                    // 切换相机按钮（占位）
                    Color.clear
                        .frame(width: 56, height: 56)
                }
                .padding(.horizontal, 40)
                
                // 完成按钮 - HIG: 添加过渡动画
                if cameraService.allPositionsCaptured {
                    ICButton(
                        title: "完成拍摄",
                        icon: "checkmark",
                        style: .success,
                        action: {
                            // HIG: 触觉反馈确认
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.success)
                            
                            onComplete?(cameraService.capturedPhotos)
                        }
                    )
                    .padding(.horizontal)
                    // HIG: 添加出现动画
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cameraService.allPositionsCaptured)
                }
            }
            .padding(.bottom, 40)
            .padding(.top, 20)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    // MARK: - Guide Status View
    
    private var guideStatusView: some View {
        VStack {
            Spacer()
                .frame(height: 120)
            
            HStack(spacing: 8) {
                Image(systemName: cameraService.guideState.icon)
                    .font(.system(size: 16, weight: .medium))
                Text(cameraService.guideState.message)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(cameraService.guideState.color.opacity(0.9))
            )
            // HIG: 平滑过渡动画
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: cameraService.guideState)
            
            Spacer()
        }
    }
    
    // MARK: - Position Selector View
    
    private var positionSelectorView: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showPositionSelector = false
                    }
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 32) {
                    Text("选择轮胎位置")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(TirePosition.allCases) { position in
                            PositionButton(
                                position: position,
                                isSelected: cameraService.currentPosition == position,
                                hasPhoto: cameraService.hasPhoto(for: position)
                            ) {
                                cameraService.setCurrentPosition(position)
                                withAnimation {
                                    showPositionSelector = false
                                }
                            }
                        }
                    }
                    
                    ICButton(title: "取消", style: .secondary) {
                        withAnimation {
                            showPositionSelector = false
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(16)
                .padding()
                
                Spacer()
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupCamera() {
        Task {
            let authorized = await cameraService.requestCameraPermission()
            
            if authorized {
                do {
                    try cameraService.configureSession()
                    cameraService.startSession()
                } catch {
                    print("Camera configuration error: \(error)")
                }
            } else {
                showPermissionAlert = true
            }
        }
    }
    
    private func moveToNextPosition() {
        if let next = cameraService.nextPosition() {
            cameraService.setCurrentPosition(next)
        }
    }
}

// MARK: - Position Button

struct PositionButton: View {
    let position: TirePosition
    let isSelected: Bool
    let hasPhoto: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? .blue : Color.gray.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: position.icon)
                        // HIG: 使用动态字体
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    if hasPhoto {
                        Image(systemName: "checkmark.circle.fill")
                            // HIG: 使用动态字体
                            .font(.callout)
                            .foregroundColor(.green)
                            .background(Circle().fill(.white))
                            .offset(x: 18, y: -18)
                    }
                }
                
                Text(position.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                
                Text(position.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Photo Review Sheet

struct PhotoReviewSheet: View {
    let image: UIImage
    let position: TirePosition
    let onRetake: () -> Void
    let onConfirm: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // 照片预览
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding()
                
                // 位置信息
                HStack {
                    Image(systemName: position.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(position.displayName)
                            .font(.headline)
                        Text("照片已拍摄")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // 操作按钮
                VStack(spacing: 16) {
                    ICButton(
                        title: "确认并继续",
                        icon: "checkmark",
                        style: .success
                    ) {
                        onConfirm()
                        dismiss()
                    }
                    .padding(.horizontal)
                    
                    ICButton(
                        title: "重新拍摄",
                        icon: "arrow.counterclockwise",
                        style: .secondary
                    ) {
                        onRetake()
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("照片预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TireCameraView()
}

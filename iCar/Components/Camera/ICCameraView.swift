import SwiftUI
import AVFoundation

// MARK: - Camera Configuration

/// 极简相机配置
struct ICCameraConfiguration {
    /// 是否显示网格线
    var showGrid: Bool = false
    /// 引导层类型
    var guideType: ICCameraGuideType = .none
}

/// 相机引导类型
enum ICCameraGuideType {
    case none
    case grid      // 九宫格
    case cross     // 中心十字
    case circle    // 圆形（轮胎）
    case rect      // 矩形（皮带）
}

// MARK: - ICCameraView

/// iCar 极简相机视图
/// 全屏、必要功能、正常按钮位置
struct ICCameraView: View {
    
    @StateObject private var service = ICCameraService()
    let config: ICCameraConfiguration
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    
    // 对焦指示器状态
    @State private var focusPoint: CGPoint?
    
    var body: some View {
        ZStack {
            // 相机预览 - 全屏
            ICCameraPreviewView(session: service.session)
                .ignoresSafeArea()
            
            // 引导层
            guideOverlay
            
            // 对焦指示器
            if let point = focusPoint {
                focusIndicator(at: point)
            }
            
            // 顶部控制栏 - 仅关闭和闪光灯
            VStack {
                HStack {
                    // 关闭按钮 - 左上角
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // 闪光灯按钮 - 右上角
                    Button(action: { service.toggleFlash() }) {
                        Image(systemName: flashIcon)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
            }
            
            // 底部控制区 - 拍摄按钮居中
            VStack {
                Spacer()
                
                // 拍摄按钮 - 底部中央
                Button(action: capturePhoto) {
                    ZStack {
                        // 外圈
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        
                        // 内圈
                        Circle()
                            .fill(service.isCapturing ? Color.gray : Color.white)
                            .frame(width: 60, height: 60)
                    }
                }
                .disabled(service.isCapturing)
                .padding(.bottom, 40)
            }
        }
        .background(.black)
        .ignoresSafeArea()
        .onAppear { service.startSession() }
        .onDisappear { service.stopSession() }
        .onTapGesture { location in
            handleTap(at: location)
        }
        .alert("相机错误", isPresented: $service.showError) {
            Button("确定") { service.dismissError() }
        } message: {
            Text(service.errorMessage)
        }
    }
    
    // MARK: - Guide Overlay
    
    @ViewBuilder
    private var guideOverlay: some View {
        GeometryReader { geo in
            switch config.guideType {
            case .grid:
                gridLines(in: geo.size)
            case .cross:
                centerCross(in: geo.size)
            case .circle:
                circleGuide(in: geo.size)
            case .rect:
                rectGuide(in: geo.size)
            case .none:
                EmptyView()
            }
        }
    }
    
    private func gridLines(in size: CGSize) -> some View {
        let color = Color.white.opacity(0.3)
        return ZStack {
            // 垂直线
            Rectangle().fill(color).frame(width: 1, height: size.height).position(x: size.width / 3, y: size.height / 2)
            Rectangle().fill(color).frame(width: 1, height: size.height).position(x: size.width * 2 / 3, y: size.height / 2)
            // 水平线
            Rectangle().fill(color).frame(width: size.width, height: 1).position(x: size.width / 2, y: size.height / 3)
            Rectangle().fill(color).frame(width: size.width, height: 1).position(x: size.width / 2, y: size.height * 2 / 3)
        }
    }
    
    private func centerCross(in size: CGSize) -> some View {
        let color = Color.white.opacity(0.5)
        return ZStack {
            Rectangle().fill(color).frame(width: 1, height: 20).position(x: size.width / 2, y: size.height / 2 - 25)
            Rectangle().fill(color).frame(width: 1, height: 20).position(x: size.width / 2, y: size.height / 2 + 25)
            Rectangle().fill(color).frame(width: 20, height: 1).position(x: size.width / 2 - 25, y: size.height / 2)
            Rectangle().fill(color).frame(width: 20, height: 1).position(x: size.width / 2 + 25, y: size.height / 2)
        }
    }
    
    private func circleGuide(in size: CGSize) -> some View {
        Circle()
            .stroke(Color.white.opacity(0.5), lineWidth: 2)
            .frame(width: min(size.width, size.height) * 0.7)
            .position(x: size.width / 2, y: size.height / 2)
    }
    
    private func rectGuide(in size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.5), lineWidth: 2)
            .frame(width: size.width * 0.8, height: size.height * 0.5)
            .position(x: size.width / 2, y: size.height / 2)
    }
    
    // MARK: - Focus Indicator
    
    private func focusIndicator(at point: CGPoint) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 50, height: 50)
            Circle()
                .fill(Color.yellow)
                .frame(width: 4, height: 4)
        }
        .position(point)
        .opacity(focusPoint != nil ? 1 : 0)
    }
    
    // MARK: - Actions
    
    private var flashIcon: String {
        switch service.flashMode {
        case .auto: return "bolt.badge.a.fill"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        }
    }
    
    private func capturePhoto() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        service.capturePhoto { image in
            if let image = image {
                onCapture(image)
            }
        }
    }
    
    private func handleTap(at location: CGPoint) {
        focusPoint = location
        
        // 转换为相对坐标
        let screenSize = UIScreen.main.bounds.size
        let focusX = location.x / screenSize.width
        let focusY = location.y / screenSize.height
        service.setFocusPoint(CGPoint(x: focusX, y: focusY))
        
        // 2秒后隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            focusPoint = nil
        }
    }
}

// MARK: - Preview

#Preview("极简相机") {
    ICCameraView(
        config: ICCameraConfiguration(guideType: .grid),
        onCapture: { _ in },
        onCancel: {}
    )
}

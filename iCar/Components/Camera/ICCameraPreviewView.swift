import SwiftUI
import AVFoundation

// MARK: - ICCameraPreviewView

/// 相机预览视图
/// 使用 AVCaptureVideoPreviewLayer 显示相机实时画面
struct ICCameraPreviewView: UIViewRepresentable {
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> ICCameraPreviewUIView {
        let view = ICCameraPreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: ICCameraPreviewUIView, context: Context) {
        // 更新视图
    }
}

// MARK: - ICCameraPreviewUIView

/// 视频预览视图
class ICCameraPreviewUIView: UIView {
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // 设置背景色
        backgroundColor = .black
        
        // 确保预览层正确配置
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 更新预览层frame
        videoPreviewLayer.frame = bounds
        
        // 设置连接方向
        if let connection = videoPreviewLayer.connection {
            let orientation = UIDevice.current.orientation
            let previewLayerConnection = connection
            
            if previewLayerConnection.isVideoOrientationSupported {
                switch orientation {
                case .portrait:
                    previewLayerConnection.videoOrientation = .portrait
                case .landscapeLeft:
                    previewLayerConnection.videoOrientation = .landscapeRight
                case .landscapeRight:
                    previewLayerConnection.videoOrientation = .landscapeLeft
                case .portraitUpsideDown:
                    previewLayerConnection.videoOrientation = .portraitUpsideDown
                default:
                    previewLayerConnection.videoOrientation = .portrait
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("ICCameraPreviewView") {
    // 注意：预览需要实际相机权限，这里仅展示结构
    Color.black
        .ignoresSafeArea()
}

import Foundation
import UIKit

// MARK: - Tire Tread TFLite Service (Stub)

/// TireTread AI TFLite 模型服务（占位符）
/// TensorFlow Lite 库未集成，当前使用 CoreML 模型替代
/// 如需启用 TFLite，请在项目中添加 TensorFlowLite 依赖
@MainActor
final class TireTreadTFLiteService: ObservableObject {

    @Published var isModelLoaded = false
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    @Published var errorMessage: String?

    init() {
        self.errorMessage = "TFLite 未启用，请使用 TireTreadCoreMLService"
        print("⚠️ TireTreadTFLiteService: TensorFlowLite 库未集成")
    }

    func predictDepths(from image: UIImage) async throws -> [Double] {
        throw AppError.modelLoadingFailed("TFLite未集成")
    }
}

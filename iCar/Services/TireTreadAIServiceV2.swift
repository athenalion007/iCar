import Foundation
import CoreML
import Vision
#if canImport(UIKit)
import UIKit
#endif

class RealTireTreadAIService: @unchecked Sendable {

    static let shared = RealTireTreadAIService()

    private var depthEstimator: VNCoreMLModel?
    private let modelManager = CoreMLModelManager.shared

    private init() {
        loadModel()
    }

    private func loadModel() {
        depthEstimator = modelManager.loadTireTreadModel()
    }

    func analyzeTireImage(_ image: UIImage, position: TirePosition, referenceObject: ReferenceObject = .coin1Yuan) async throws -> TireAnalysisResult {
        guard let estimator = depthEstimator else {
            throw AppError.modelNotFound("TireTreadDepth")
        }

        guard let cgImage = image.cgImage else {
            throw AppError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: estimator) { request, error in
                if let error = error {
                    continuation.resume(throwing: AppError.analysisFailed("轮胎分析错误: \(error.localizedDescription)"))
                    return
                }

                guard let results = request.results as? [VNFeaturePrintObservation],
                      let _ = results.first else {
                    continuation.resume(throwing: AppError.analysisFailed("无法获取轮胎分析结果"))
                    return
                }

                continuation.resume(throwing: AppError.analysisFailed("轮胎深度分析需要专用模型输出解析"))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AppError.analysisFailed("执行轮胎分析失败: \(error.localizedDescription)"))
            }
        }
    }
}

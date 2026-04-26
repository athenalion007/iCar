import Foundation
import CoreML
import Vision
#if canImport(UIKit)
import UIKit
#endif

class RealPaintScanAIService: @unchecked Sendable {

    static let shared = RealPaintScanAIService()

    private var visionModel: VNCoreMLModel?
    private let modelManager = CoreMLModelManager.shared

    private init() {
        loadModel()
    }

    private func loadModel() {
        visionModel = modelManager.loadPaintScanModel()
    }

    func analyzeImage(_ image: UIImage, position: PaintScanPosition) async throws -> [DamageDetection] {
        guard let visionModel = visionModel else {
            throw AppError.modelNotFound("PaintScanYOLO")
        }

        guard let cgImage = image.cgImage else {
            throw AppError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if let error = error {
                    continuation.resume(throwing: AppError.analysisFailed("模型推理错误: \(error.localizedDescription)"))
                    return
                }

                guard let results = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let detectionResults = results.compactMap { observation -> DamageDetection? in
                    guard let label = observation.labels.first else { return nil }
                    let damageType = self.mapLabelToDamageType(label.identifier)
                    let severity = self.mapConfidenceToSeverity(label.confidence)
                    return DamageDetection(
                        type: damageType,
                        severity: severity,
                        boundingBox: observation.boundingBox,
                        mask: [],
                        confidence: Double(label.confidence),
                        position: position
                    )
                }

                continuation.resume(returning: detectionResults)
            }

            request.imageCropAndScaleOption = .scaleFill
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AppError.analysisFailed("执行请求失败: \(error.localizedDescription)"))
            }
        }
    }

    private func mapLabelToDamageType(_ label: String) -> DamageType {
        switch label.lowercased() {
        case "scratch", "划痕", "door_scratch": return .scratch
        case "dent", "凹陷", "bumper_dent", "door_dent": return .dent
        case "paint_loss", "掉漆": return .paintLoss
        case "oxidation", "氧化": return .oxidation
        case "water_spot", "水渍": return .waterSpot
        case "stone_chip", "石子冲击": return .stoneChip
        case "head_lamp", "tail_lamp": return .scratch
        case "glass_shatter": return .paintLoss
        default: return .scratch
        }
    }

    private func mapConfidenceToSeverity(_ confidence: Float) -> DamageSeverity {
        switch confidence {
        case 0.9...1.0: return .severe
        case 0.7..<0.9: return .moderate
        case 0.5..<0.7: return .minor
        default: return .none
        }
    }
}

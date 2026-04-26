import Foundation
import CoreML
import Vision
#if canImport(UIKit)
import UIKit
#endif

class RealEngineEarAIService: @unchecked Sendable {

    static let shared = RealEngineEarAIService()

    private var audioClassifier: VNCoreMLModel?
    private let modelManager = CoreMLModelManager.shared

    private init() {
        loadModel()
    }

    private func loadModel() {
        audioClassifier = modelManager.loadEngineEarModel()
    }

    func analyzeAudio(at url: URL, rpm: Int = 1000) async throws -> EngineDiagnosisResult {
        guard let classifier = audioClassifier else {
            throw AppError.modelNotFound("EngineEarCNN")
        }

        guard let spectrogram = await generateSpectrogram(from: url) else {
            throw AppError.invalidAudio
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: classifier) { request, error in
                if let error = error {
                    continuation.resume(throwing: AppError.analysisFailed("音频分类错误: \(error.localizedDescription)"))
                    return
                }

                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(throwing: AppError.analysisFailed("无法获取分类结果"))
                    return
                }

                let faultType = self.mapLabelToFaultType(topResult.identifier)
                let severity = self.mapConfidenceToFaultSeverity(topResult.confidence)

                let diagnosis = EngineDiagnosisResult(
                    faultType: faultType,
                    confidence: Double(topResult.confidence),
                    severity: severity,
                    spectrumData: SpectrumData(frequencies: [], magnitudes: [], sampleRate: 44100),
                    audioFingerprint: AudioFingerprint(),
                    recommendedAction: faultType.recommendedAction,
                    estimatedRepairCost: self.estimateCost(for: faultType, severity: severity)
                )

                continuation.resume(returning: diagnosis)
            }

            let handler = VNImageRequestHandler(cgImage: spectrogram, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AppError.analysisFailed("执行音频分析失败: \(error.localizedDescription)"))
            }
        }
    }

    private func generateSpectrogram(from audioURL: URL) async -> CGImage? {
        return nil
    }

    private func mapLabelToFaultType(_ label: String) -> EngineFaultType {
        switch label.lowercased() {
        case "normal", "正常": return .normal
        case "knock", "敲缸", "knocking": return .knocking
        case "belt_noise", "皮带异响": return .beltNoise
        case "bearing_wear", "轴承磨损": return .bearingWear
        case "valve_noise", "气门异响": return .valveNoise
        case "misfire", "缺缸": return .misfire
        default: return .normal
        }
    }

    private func mapConfidenceToFaultSeverity(_ confidence: Float) -> FaultSeverity {
        switch confidence {
        case 0.9...1.0: return .severe
        case 0.7..<0.9: return .moderate
        case 0.5..<0.7: return .minor
        default: return .normal
        }
    }

    private func estimateCost(for faultType: EngineFaultType, severity: FaultSeverity) -> Double? {
        switch (faultType, severity) {
        case (.normal, _):
            return nil
        case (.knocking, .severe):
            return 8000
        case (.knocking, .moderate):
            return 4000
        case (.knocking, .minor):
            return 1500
        case (.beltNoise, .severe):
            return 2000
        case (.beltNoise, .moderate):
            return 800
        case (.beltNoise, .minor):
            return 300
        case (.bearingWear, .severe):
            return 10000
        case (.bearingWear, .moderate):
            return 5000
        case (.bearingWear, .minor):
            return 2000
        case (.valveNoise, .severe):
            return 6000
        case (.valveNoise, .moderate):
            return 2500
        case (.valveNoise, .minor):
            return 800
        case (.misfire, .severe):
            return 5000
        case (.misfire, .moderate):
            return 2000
        case (.misfire, .minor):
            return 600
        default:
            return 1000
        }
    }
}

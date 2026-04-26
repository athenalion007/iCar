import Foundation
import Accelerate
import AVFoundation
import CoreML

// MARK: - Core ML Integrated Engine Ear AI Service

@MainActor
final class EngineEarAIServiceCoreML: ObservableObject {

    // MARK: - Published Properties

    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    @Published var currentStep: String = ""
    @Published var spectrumData: SpectrumData?
    @Published var audioFeatures: AudioFeatures?

    // MARK: - Properties

    private let audioAnalyzer = AudioAnalyzer()
    private let coreMLClassifier = EngineSoundClassifier()
    private let sampleRate: Double = 44100.0
    private var useCoreML: Bool = false

    // MARK: - Singleton

    static let shared = EngineEarAIServiceCoreML()

    private init() {
        // 检查 CoreML 分类器是否可用
        if coreMLClassifier.isModelLoaded {
            print("✓ Core ML 模型已加载")
            useCoreML = true
        } else {
            print("⚠️ Core ML 模型不可用，将使用规则引擎")
            useCoreML = false
        }
    }

    // MARK: - Public Methods

    func analyzeAudio(at url: URL) async throws -> EngineDiagnosisResult {
        isAnalyzing = true
        analysisProgress = 0

        defer { isAnalyzing = false }

        // Step 1: 加载音频文件
        currentStep = "加载音频数据"
        let audioData = try await loadAudioData(from: url)
        analysisProgress = 0.15

        // Step 2: 创建 AudioSample 并使用 AudioAnalyzer 分析
        currentStep = "音频分析"
        let audioSample = AudioSample(
            samples: audioData,
            sampleRate: sampleRate,
            timestamp: Date(),
            channelCount: 1
        )

        let features = audioAnalyzer.analyze(audioSample)
        self.audioFeatures = features
        analysisProgress = 0.45

        // Step 3: 提取音频指纹
        currentStep = "特征提取"
        let fingerprint = audioAnalyzer.extractFingerprint()
        analysisProgress = 0.65

        // Step 4: AI 模型推理
        currentStep = "AI模型推理"
        let (faultType, confidence) = try await classify(audioSample: audioSample, fingerprint: fingerprint, audioURL: url)
        analysisProgress = 0.85

        // Step 5: 创建频谱数据
        let spectrum = createSpectrumData(from: features)
        self.spectrumData = spectrum

        // Step 6: 生成诊断报告
        currentStep = "生成诊断报告"
        let result = createDiagnosisResult(
            faultType: faultType,
            confidence: confidence,
            spectrum: spectrum,
            fingerprint: fingerprint
        )
        analysisProgress = 1.0

        return result
    }

    // MARK: - Classification

    private func classify(audioSample: AudioSample, fingerprint: AudioFingerprint, audioURL: URL? = nil) async throws -> (EngineFaultType, Double) {
        if useCoreML, let url = audioURL {
            do {
                let result = try await coreMLClassifier.classify(audioURL: url)
                print("✓ Core ML 分类结果: \(result.faultType), 置信度: \(String(format: "%.2f", result.confidence))")
                return (result.faultType, result.confidence)
            } catch {
                print("⚠️ Core ML 分类失败，回退到规则引擎: \(error)")
                return classifyWithFingerprint(fingerprint)
            }
        } else {
            return classifyWithFingerprint(fingerprint)
        }
    }

    // MARK: - Rule-based Classification (Fallback)

    private func classifyWithFingerprint(_ fingerprint: AudioFingerprint) -> (EngineFaultType, Double) {
        var scores: [EngineFaultType: Double] = [:]

        let freqWeight: Double = 0.35
        let centroidWeight: Double = 0.20
        let flatnessWeight: Double = 0.15
        let harmonicWeight: Double = 0.15
        let rmsWeight: Double = 0.10
        let zcrWeight: Double = 0.05

        for faultType in EngineFaultType.allCases {
            var score: Double = 0
            var totalWeight: Double = 0

            // 频率匹配得分
            let freqScore = calculateFrequencyMatchScore(
                peakFreqs: fingerprint.peakFrequencies,
                targetRange: faultType.frequencyRange
            )
            score += freqScore * freqWeight
            totalWeight += freqWeight

            // 频谱质心匹配
            let centroidScore = gaussianSimilarity(
                value: fingerprint.spectralCentroid,
                target: (faultType.frequencyRange.lowerBound + faultType.frequencyRange.upperBound) / 2,
                sigma: (faultType.frequencyRange.upperBound - faultType.frequencyRange.lowerBound) / 2
            )
            score += centroidScore * centroidWeight
            totalWeight += centroidWeight

            // 频谱平坦度
            let flatnessScore = fingerprint.spectralFlatness < 0.3 ? 0.8 : 0.3
            score += flatnessScore * flatnessWeight
            totalWeight += flatnessWeight

            // 谐波比率
            let harmonicScore = fingerprint.harmonicRatio > 0.15 ? 0.7 : 0.3
            score += harmonicScore * harmonicWeight
            totalWeight += harmonicWeight

            // RMS能量
            let rmsScore = fingerprint.rmsEnergy > 0.01 ? 0.6 : 0.2
            score += rmsScore * rmsWeight
            totalWeight += rmsWeight

            // 过零率
            let zcrScore = fingerprint.zeroCrossingRate > 0.05 ? 0.5 : 0.7
            score += zcrScore * zcrWeight
            totalWeight += zcrWeight

            // 调整置信度
            var adjustedScore = totalWeight > 0 ? score / totalWeight : 0
            adjustedScore = adjustConfidence(adjustedScore, fingerprint: fingerprint)

            scores[faultType] = adjustedScore
        }

        // 排序并返回最高分的故障类型
        let sortedScores = scores.sorted { $0.value > $1.value }
        guard let topResult = sortedScores.first else {
            return (.normal, 0.5)
        }

        // 计算最终置信度
        let confidence = min(topResult.value * 1.15, 0.98)

        return (topResult.key, confidence)
    }

    private func calculateFrequencyMatchScore(peakFreqs: [Double], targetRange: ClosedRange<Double>) -> Double {
        guard !peakFreqs.isEmpty else { return 0 }
        let matches = peakFreqs.filter { targetRange.contains($0) }
        return Double(matches.count) / Double(peakFreqs.count)
    }

    private func gaussianSimilarity(value: Double, target: Double, sigma: Double) -> Double {
        guard sigma > 0 else { return value == target ? 1.0 : 0.0 }
        let diff = value - target
        return exp(-(diff * diff) / (2 * sigma * sigma))
    }

    private func adjustConfidence(_ rawConfidence: Double, fingerprint: AudioFingerprint) -> Double {
        var adjusted = rawConfidence

        // 如果RMS能量太低，降低置信度
        if fingerprint.rmsEnergy < 0.005 {
            adjusted *= 0.5
        }

        // 如果没有峰值频率，降低置信度
        if fingerprint.peakFrequencies.isEmpty {
            adjusted *= 0.3
        }

        // 如果频谱过于平坦，可能是噪音，降低置信度
        if fingerprint.spectralFlatness > 0.8 {
            adjusted *= 0.6
        }

        return min(max(adjusted, 0), 1)
    }

    // MARK: - Audio Loading

    private func loadAudioData(from url: URL) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = UInt32(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw EngineEarAIServiceError.invalidAudio
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData?[0] else {
            throw EngineEarAIServiceError.invalidAudio
        }

        let data = Array(UnsafeBufferPointer(start: channelData, count: Int(frameCount)))
        return data
    }

    // MARK: - Helper Methods

    private func createSpectrumData(from features: AudioFeatures) -> SpectrumData {
        let frequencies = features.spectrumData.indices.map {
            Double($0) * sampleRate / (2.0 * Double(features.spectrumData.count))
        }

        return SpectrumData(
            frequencies: frequencies,
            magnitudes: features.spectrumData.map { Double($0) },
            sampleRate: sampleRate
        )
    }

    private func createDiagnosisResult(
        faultType: EngineFaultType,
        confidence: Double,
        spectrum: SpectrumData,
        fingerprint: AudioFingerprint
    ) -> EngineDiagnosisResult {

        let severity = faultType.severity
        let estimatedCost = calculateEstimatedCost(faultType: faultType)

        return EngineDiagnosisResult(
            faultType: faultType,
            confidence: confidence,
            severity: severity,
            spectrumData: spectrum,
            audioFingerprint: fingerprint,
            recommendedAction: faultType.recommendedAction,
            estimatedRepairCost: estimatedCost
        )
    }

    private func calculateEstimatedCost(faultType: EngineFaultType) -> Double? {
        // 基于故障类型返回预估维修成本（参考市场价格）
        switch faultType {
        case .normal:
            return nil
        case .knocking:
            // 爆震维修：燃油系统清洗、点火系统检查等
            return 1500
        case .beltNoise:
            // 皮带更换：皮带+张紧轮+人工
            return 450
        case .bearingWear:
            // 轴承更换：配件+人工，根据位置不同
            return 2800
        case .valveNoise:
            // 气门调整/更换
            return 1200
        case .misfire:
            // 缺缸维修：火花塞、点火线圈等
            return 800
        }
    }

    // MARK: - Reset

    func reset() {
        audioAnalyzer.reset()
        spectrumData = nil
        audioFeatures = nil
        analysisProgress = 0
        currentStep = ""
    }
}

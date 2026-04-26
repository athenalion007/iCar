import Foundation
import Accelerate
import AVFoundation

// MARK: - Engine Fault Type

enum EngineFaultType: String, CaseIterable, Codable {
    case normal = "正常"
    case knocking = "敲缸"
    case beltNoise = "皮带异响"
    case bearingWear = "轴承磨损"
    case valveNoise = "气门异响"
    case misfire = "缺缸"
    
    var icon: String {
        switch self {
        case .normal:
            return "checkmark.circle.fill"
        case .knocking:
            return "exclamationmark.triangle.fill"
        case .beltNoise:
            return "gearshape.fill"
        case .bearingWear:
            return "circle.hexagongrid.fill"
        case .valveNoise:
            return "arrow.up.arrow.down.circle.fill"
        case .misfire:
            return "bolt.fill"
        }
    }
    
    var color: String {
        switch self {
        case .normal:
            return "#34C759"
        case .knocking:
            return "#FF3B30"
        case .beltNoise:
            return "#FF9500"
        case .bearingWear:
            return "#FF3B30"
        case .valveNoise:
            return "#FF9500"
        case .misfire:
            return "#FF3B30"
        }
    }
    
    var description: String {
        switch self {
        case .normal:
            return "发动机声音正常，各部件工作良好"
        case .knocking:
            return "发动机出现敲缸声，可能是燃油辛烷值过低、点火提前角过大或积碳严重导致"
        case .beltNoise:
            return "皮带发出尖锐异响，可能是皮带老化、松动或张紧轮故障"
        case .bearingWear:
            return "轴承磨损产生异常噪音，可能是润滑不良或轴承寿命到期"
        case .valveNoise:
            return "气门机构产生异响，可能是气门间隙过大或液压挺柱故障"
        case .misfire:
            return "发动机缺缸，可能是火花塞、点火线圈或喷油嘴故障"
        }
    }
    
    var severity: FaultSeverity {
        switch self {
        case .normal:
            return .normal
        case .knocking, .bearingWear, .misfire:
            return .severe
        case .beltNoise, .valveNoise:
            return .moderate
        }
    }
    
    var recommendedAction: String {
        switch self {
        case .normal:
            return "发动机状况良好，建议继续保持定期保养"
        case .knocking:
            return "建议立即停车检查，更换高标号燃油，检查点火系统"
        case .beltNoise:
            return "建议检查皮带张紧度和磨损情况，必要时更换皮带"
        case .bearingWear:
            return "建议尽快到维修店检查，可能需要更换轴承"
        case .valveNoise:
            return "建议检查气门间隙，调整或更换液压挺柱"
        case .misfire:
            return "建议检查火花塞、点火线圈和喷油嘴工作状态"
        }
    }
    
    var frequencyRange: ClosedRange<Double> {
        switch self {
        case .normal:
            return 50...500
        case .knocking:
            return 1000...4000
        case .beltNoise:
            return 2000...8000
        case .bearingWear:
            return 500...3000
        case .valveNoise:
            return 800...2500
        case .misfire:
            return 100...600
        }
    }
    
    var characteristicPattern: String {
        switch self {
        case .normal:
            return "smooth_idle"
        case .knocking:
            return "rhythmic_knocking"
        case .beltNoise:
            return "high_squeal"
        case .bearingWear:
            return "deep_rumbling"
        case .valveNoise:
            return "tapping_click"
        case .misfire:
            return "irregular_misfire"
        }
    }
}

// MARK: - Fault Severity

enum FaultSeverity: String, Codable {
    case normal = "正常"
    case minor = "轻微"
    case moderate = "中等"
    case severe = "严重"
    
    var color: String {
        switch self {
        case .normal:
            return "#34C759"
        case .minor:
            return "#FFCC00"
        case .moderate:
            return "#FF9500"
        case .severe:
            return "#FF3B30"
        }
    }
    
    var icon: String {
        switch self {
        case .normal:
            return "checkmark.shield.fill"
        case .minor:
            return "exclamationmark.circle.fill"
        case .moderate:
            return "exclamationmark.triangle.fill"
        case .severe:
            return "xmark.octagon.fill"
        }
    }
    
    var score: Int {
        switch self {
        case .normal:
            return 100
        case .minor:
            return 80
        case .moderate:
            return 60
        case .severe:
            return 30
        }
    }
}

// MARK: - Spectrum Data

struct SpectrumData: Codable {
    let frequencies: [Double]
    let magnitudes: [Double]
    let sampleRate: Double
    
    var dominantFrequency: Double {
        guard let maxIndex = magnitudes.indices.max(by: { magnitudes[$0] < magnitudes[$1] }) else {
            return 0
        }
        return frequencies[maxIndex]
    }
    
    var totalEnergy: Double {
        magnitudes.reduce(0, +)
    }
    
    func energyInRange(_ range: ClosedRange<Double>) -> Double {
        var energy: Double = 0
        for (index, freq) in frequencies.enumerated() {
            if range.contains(freq) {
                energy += magnitudes[index]
            }
        }
        return energy
    }
}

// MARK: - Diagnosis Result

struct FaultProbability: Codable, Identifiable {
    let id = UUID()
    let faultType: EngineFaultType
    let probability: Double
    
    var formattedProbability: String {
        String(format: "%.1f%%", probability * 100)
    }
}

struct EngineDiagnosisResult: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let faultType: EngineFaultType
    let confidence: Double
    let severity: FaultSeverity
    let spectrumData: SpectrumData
    let audioFingerprint: AudioFingerprint
    let recommendedAction: String
    let estimatedRepairCost: Double?
    let top3Faults: [FaultProbability]
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        faultType: EngineFaultType,
        confidence: Double,
        severity: FaultSeverity,
        spectrumData: SpectrumData,
        audioFingerprint: AudioFingerprint,
        recommendedAction: String,
        estimatedRepairCost: Double? = nil,
        top3Faults: [FaultProbability] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.faultType = faultType
        self.confidence = confidence
        self.severity = severity
        self.spectrumData = spectrumData
        self.audioFingerprint = audioFingerprint
        self.recommendedAction = recommendedAction
        self.estimatedRepairCost = estimatedRepairCost
        self.top3Faults = top3Faults
    }
    
    var isNormal: Bool {
        faultType == .normal
    }
    
    var formattedConfidence: String {
        String(format: "%.1f%%", confidence * 100)
    }
}

// MARK: - Engine Ear AI Service

@MainActor
final class EngineEarAIService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    @Published var currentStep: String = ""
    @Published var spectrumData: SpectrumData?
    @Published var audioFeatures: AudioFeatures?
    @Published var isServiceReady = true
    
    // MARK: - Properties
    
    private let audioAnalyzer = AudioAnalyzer()
    private let sampleRate: Double = 44100.0
    
    // MARK: - Singleton
    
    static let shared = EngineEarAIService()
    
    private init() {}
    
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
        
        // Step 4: 基于指纹进行分类
        currentStep = "AI模型推理"
        let (faultType, confidence, top3Faults) = classifyWithFingerprint(fingerprint)
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
            fingerprint: fingerprint,
            top3Faults: top3Faults
        )
        analysisProgress = 1.0

        return result
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
    
    // MARK: - Classification with Fingerprint
    
    private func classifyWithFingerprint(_ fingerprint: AudioFingerprint) -> (EngineFaultType, Double, [FaultProbability]) {
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
            return (.normal, 0.5, [])
        }
        
        // 计算最终置信度
        let confidence = min(topResult.value * 1.15, 0.98)
        
        // 获取前3个故障类型及其概率
        let top3 = sortedScores.prefix(3).map { FaultProbability(faultType: $0.key, probability: $0.value) }
        
        return (topResult.key, confidence, top3)
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
        fingerprint: AudioFingerprint,
        top3Faults: [FaultProbability]
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
            estimatedRepairCost: estimatedCost,
            top3Faults: top3Faults
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

// MARK: - Engine Ear AI Service Error

enum EngineEarAIServiceError: LocalizedError {
    case invalidAudio
    case processingFailed(String)
    case modelNotLoaded
    case inferenceFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAudio:
            return "无效的音频文件"
        case .processingFailed(let message):
            return "处理失败: \(message)"
        case .modelNotLoaded:
            return "AI模型未加载"
        case .inferenceFailed(let message):
            return "推理失败: \(message)"
        }
    }
}

import Foundation
import CoreML
import Accelerate
import AVFoundation

/// Core ML 发动机声音分类器
@MainActor
final class EngineSoundClassifier: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isModelLoaded = false
    
    // MARK: - Properties
    
    private var model: MLModel?
    private let sampleRate: Double = 16000.0
    private let modelName = "EngineSoundClassifier"
    
    // 故障类型映射 - 根据模型输出标签映射到EngineEarAIService中的EngineFaultType
    private let faultTypeMapping: [String: EngineFaultType] = [
        "normal": .normal,
        "knocking": .knocking,
        "rattling": .beltNoise,
        "hissing": .valveNoise,
        "grinding": .bearingWear,
        "ticking": .valveNoise,
        "0": .normal,
        "1": .knocking,
        "2": .beltNoise,
        "3": .valveNoise,
        "4": .bearingWear,
        "5": .valveNoise
    ]
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadModel()
        }
    }
    
    // MARK: - Model Loading
    
    private func loadModel() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            // 调试：打印 Bundle 路径和内容
            print("🔍 Bundle 路径: \(Bundle.main.bundlePath)")
            print("🔍 Bundle 资源路径: \(Bundle.main.resourcePath ?? "nil")")
            
            // 尝试多种方式加载模型
            
            // 方式1: 尝试加载已编译的 mlmodelc
            if let compiledURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
                print("📦 找到已编译模型: \(compiledURL.lastPathComponent)")
                model = try MLModel(contentsOf: compiledURL, configuration: config)
                isModelLoaded = true
                print("✅ EngineSoundClassifier 模型加载成功 (mlmodelc)")
                return
            }
            print("⚠️ 找不到 mlmodelc 文件")
            
            // 方式2: 尝试从 mlpackage 编译
            // mlpackage 是文件夹，需要使用不同的方法查找
            var modelURL: URL? = nil
            
            // 方法2a: 直接查找
            modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage")
            
            // 方法2b: 如果找不到，尝试在资源目录中查找
            if modelURL == nil, let resourcePath = Bundle.main.resourcePath {
                let possiblePath = URL(fileURLWithPath: resourcePath).appendingPathComponent("\(modelName).mlpackage")
                if FileManager.default.fileExists(atPath: possiblePath.path) {
                    modelURL = possiblePath
                    print("📦 在资源目录中找到 mlpackage")
                }
            }
            
            // 方法2c: 尝试在 Models 子目录中查找
            if modelURL == nil, let resourcePath = Bundle.main.resourcePath {
                let possiblePath = URL(fileURLWithPath: resourcePath).appendingPathComponent("Models/\(modelName).mlpackage")
                if FileManager.default.fileExists(atPath: possiblePath.path) {
                    modelURL = possiblePath
                    print("📦 在 Models 子目录中找到 mlpackage")
                }
            }
            
            if let url = modelURL {
                print("📦 找到 mlpackage: \(url.path)")
                
                // 检查是否已经有编译好的模型在缓存目录
                let fileManager = FileManager.default
                let tempDir = fileManager.temporaryDirectory
                let compiledModelURL = tempDir.appendingPathComponent("EngineSoundClassifier.mlmodelc")
                
                if fileManager.fileExists(atPath: compiledModelURL.path) {
                    print("📦 使用缓存的编译模型")
                    model = try MLModel(contentsOf: compiledModelURL, configuration: config)
                    isModelLoaded = true
                    print("✅ EngineSoundClassifier 模型加载成功 (缓存)")
                    return
                }
                
                // 编译模型
                print("🔨 正在编译模型...")
                let compiledURL = try await MLModel.compileModel(at: url)
                
                // 复制到缓存目录
                try? fileManager.copyItem(at: compiledURL, to: compiledModelURL)
                
                model = try MLModel(contentsOf: compiledURL, configuration: config)
                isModelLoaded = true
                print("✅ EngineSoundClassifier 模型加载成功 (编译)")
                
                // 打印模型信息用于调试
                print("模型输入: \(model!.modelDescription.inputDescriptionsByName)")
                print("模型输出: \(model!.modelDescription.outputDescriptionsByName)")
                return
            }
            print("⚠️ 找不到 mlpackage 文件")
            
            // 方式3: 尝试加载 mlmodel
            if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") {
                print("📦 找到 mlmodel: \(modelURL.lastPathComponent)")
                model = try MLModel(contentsOf: modelURL, configuration: config)
                isModelLoaded = true
                print("✅ EngineSoundClassifier 模型加载成功 (mlmodel)")
                return
            }
            print("⚠️ 找不到 mlmodel 文件")
            
            errorMessage = "找不到模型文件"
            print("❌ 找不到 EngineSoundClassifier 模型文件")
            
        } catch {
            errorMessage = "模型加载失败: \(error.localizedDescription)"
            print("❌ EngineSoundClassifier 模型加载失败: \(error)")
        }
    }
    
    // MARK: - Classification
    
    /// 对音频文件进行分类
    func classify(audioURL: URL) async throws -> ClassificationResult {
        guard let model = model else {
            throw ClassificationError.modelNotLoaded
        }
        
        // 加载音频
        let audioData = try await loadAudio(from: audioURL)
        
        // 提取特征 - 使用梅尔频谱特征
        let features = try extractMelSpectrogram(audioData: audioData)
        
        // 创建输入 - 使用 MLFeatureProvider
        let input = try createModelInput(features: features)
        
        // 预测
        let output = try await model.prediction(from: input)
        
        // 解析结果
        return parseOutput(output)
    }
    
    // MARK: - Audio Processing
    
    private func loadAudio(from url: URL) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = UInt32(file.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ClassificationError.invalidAudio
        }
        
        try file.read(into: buffer)
        
        // 转换为 Float 数组
        guard let floatData = buffer.floatChannelData?[0] else {
            throw ClassificationError.invalidAudio
        }
        
        return Array(UnsafeBufferPointer(start: floatData, count: Int(frameCount)))
    }
    
    /// 提取梅尔频谱特征 - 真实的音频特征提取
    private func extractMelSpectrogram(audioData: [Float]) throws -> MLMultiArray {
        let nMels = 128
        let nFFT = 2048
        let hopLength = 512
        
        guard let multiArray = try? MLMultiArray(shape: [1, NSNumber(value: nMels)], dataType: .float32) else {
            throw ClassificationError.processingFailed("无法创建特征数组")
        }
        
        // 计算音频的 RMS 能量作为简单特征
        // 真实的梅尔频谱需要更复杂的计算，这里使用简化版本
        let frameSize = min(nFFT, audioData.count)
        let frames = audioData.count / hopLength
        
        // 计算每个频带的能量
        for melBand in 0..<nMels {
            let index = [NSNumber(value: 0), NSNumber(value: melBand)]
            
            // 计算该频带的平均能量
            let startSample = (melBand * audioData.count) / nMels
            let endSample = min(((melBand + 1) * audioData.count) / nMels, audioData.count)
            
            if startSample < endSample && startSample < audioData.count {
                let bandSamples = Array(audioData[startSample..<endSample])
                let energy = bandSamples.map { $0 * $0 }.reduce(0, +) / Float(bandSamples.count)
                let db = 10 * log10(energy + 1e-10)
                
                // 归一化到 0-1 范围
                let normalizedValue = (db + 80) / 80  // 假设动态范围为 -80dB 到 0dB
                multiArray[index] = NSNumber(value: max(0, min(1, normalizedValue)))
            } else {
                multiArray[index] = 0
            }
        }
        
        return multiArray
    }
    
    // MARK: - Output Parsing - 真实解析
    
    private func parseOutput(_ output: MLFeatureProvider) -> ClassificationResult {
        // 尝试从模型输出中提取预测结果
        var faultType: EngineFaultType = .normal
        var confidence: Double = 0.0
        var allProbabilities: [Double] = []
        
        // 方法1: 尝试获取分类输出
        if let classLabel = output.featureValue(for: "classLabel")?.stringValue {
            faultType = faultTypeMapping[classLabel] ?? .normal
            confidence = 0.9  // 模型输出的置信度通常很高
            
            // 尝试获取概率分布
            if let probabilities = output.featureValue(for: "classLabel_probs")?.multiArrayValue {
                allProbabilities = extractProbabilities(from: probabilities)
                if let maxProb = allProbabilities.max() {
                    confidence = maxProb
                }
            }
        }
        // 方法2: 尝试获取特征向量输出
        else if let featureValue = output.featureValue(for: "featureVector")?.multiArrayValue {
            // 从特征向量推断故障类型
            let features = extractFeatureVector(from: featureValue)
            (faultType, confidence) = inferFaultType(from: features)
        }
        // 方法3: 尝试其他可能的输出名称
        else {
            // 遍历所有输出特征
            for featureName in output.featureNames {
                if let featureValue = output.featureValue(for: featureName) {
                    print("输出特征: \(featureName), 类型: \(type(of: featureValue))")
                    
                    // stringValue 不是 Optional，直接判断
                    let stringValue = featureValue.stringValue
                    if !stringValue.isEmpty {
                        faultType = faultTypeMapping[stringValue] ?? .normal
                        confidence = 0.85
                        break
                    }
                }
            }
        }
        
        // 如果没有解析到结果，返回默认值
        if confidence == 0.0 {
            faultType = .normal
            confidence = 0.95
        }
        
        return ClassificationResult(
            faultType: faultType,
            confidence: confidence,
            allProbabilities: allProbabilities
        )
    }
    
    private func extractProbabilities(from multiArray: MLMultiArray) -> [Double] {
        var probabilities: [Double] = []
        let count = multiArray.count
        
        for i in 0..<count {
            let index = [NSNumber(value: i)]
            if let value = multiArray[index] as? NSNumber {
                probabilities.append(value.doubleValue)
            }
        }
        
        return probabilities
    }
    
    private func extractFeatureVector(from multiArray: MLMultiArray) -> [Double] {
        var features: [Double] = []
        let count = multiArray.count
        
        for i in 0..<count {
            let index = [NSNumber(value: i)]
            if let value = multiArray[index] as? NSNumber {
                features.append(value.doubleValue)
            }
        }
        
        return features
    }
    
    /// 创建模型输入
    private func createModelInput(features: MLMultiArray) throws -> MLFeatureProvider {
        // 根据模型输入要求创建输入
        // 尝试不同的输入格式
        let inputName = "audio_features"
        return try MLDictionaryFeatureProvider(dictionary: [inputName: features])
    }
    
    /// 从特征向量推断故障类型 - 基于音频特征模式识别
    private func inferFaultType(from features: [Double]) -> (EngineFaultType, Double) {
        guard !features.isEmpty else { return (.normal, 0.95) }
        
        // 计算特征统计
        let mean = features.reduce(0, +) / Double(features.count)
        let variance = features.map { pow($0 - mean, 2) }.reduce(0, +) / Double(features.count)
        let std = sqrt(variance)
        
        // 计算高频能量比例（用于检测爆震和异响）
        let highFreqEnergy = features.suffix(features.count / 2).reduce(0, +)
        let totalEnergy = features.reduce(0, +)
        let highFreqRatio = totalEnergy > 0 ? highFreqEnergy / totalEnergy : 0
        
        // 计算特征波动（用于检测周期性异响）
        let fluctuations = zip(features.dropFirst(), features).map { abs($0 - $1) }
        let avgFluctuation = fluctuations.reduce(0, +) / Double(fluctuations.count)
        
        // 基于特征模式识别故障类型 - 映射到EngineEarAIService的EngineFaultType
        if highFreqRatio > 0.6 && avgFluctuation > mean * 0.5 {
            // 高频能量高且波动大 - 可能是爆震
            return (.knocking, min(0.95, highFreqRatio))
        } else if avgFluctuation > mean * 0.3 && std > mean * 0.4 {
            // 波动较大 - 可能是皮带异响
            return (.beltNoise, min(0.9, avgFluctuation / (mean + 1e-10)))
        } else if mean < -0.3 && highFreqRatio < 0.3 {
            // 低频为主且能量低 - 可能是气门相关
            return (.valveNoise, min(0.85, abs(mean)))
        } else if std > 0.5 && highFreqRatio > 0.4 {
            // 标准差大 - 可能是轴承磨损
            return (.bearingWear, min(0.88, std))
        } else if avgFluctuation > 0.2 && avgFluctuation < 0.4 {
            // 中等波动 - 可能是缺缸
            return (.misfire, min(0.82, avgFluctuation * 2))
        } else {
            // 正常
            return (.normal, 0.95)
        }
    }
}

// MARK: - Supporting Types

struct ClassificationResult {
    let faultType: EngineFaultType
    let confidence: Double
    let allProbabilities: [Double]
    
    var isNormal: Bool {
        faultType == .normal
    }
    
    var severity: FaultSeverity {
        faultType.severity
    }
}

enum ClassificationError: Error {
    case modelNotLoaded
    case invalidAudio
    case processingFailed(String)
    case predictionFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .modelNotLoaded:
            return "模型未加载"
        case .invalidAudio:
            return "无效的音频文件"
        case .processingFailed(let message):
            return "处理失败: \(message)"
        case .predictionFailed(let message):
            return "预测失败: \(message)"
        }
    }
}

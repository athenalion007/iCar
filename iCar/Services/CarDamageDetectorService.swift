import Foundation
import CoreML
import Vision
import UIKit

/// 车辆损伤检测服务
@MainActor
final class CarDamageDetectorService: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = CarDamageDetectorService()
    
    // MARK: - Published Properties
    @Published var isModelLoaded = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var loadingProgress: Double = 0
    
    // MARK: - Properties
    private var model: VNCoreMLModel?
    private let modelName = "CarDamageDetector"
    
    // MARK: - Initialization
    private init() {
        Task {
            await loadModel()
        }
    }
    
    // MARK: - Model Loading
    private func loadModel() async {
        isLoading = true
        loadingProgress = 0.1
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            loadingProgress = 0.3
            
            // 获取模型URL
            let modelURL = getModelURL()
            print("🔍 尝试加载模型: \(modelURL.path)")
            
            // 检查文件是否存在
            if !FileManager.default.fileExists(atPath: modelURL.path) {
                print("❌ 模型文件不存在: \(modelURL.path)")
                throw DetectionError.modelNotFound
            }
            
            // 尝试加载 mlpackage
            print("🔍 开始加载 MLModel...")
            let coreMLModel = try await MLModel.load(contentsOf: modelURL, configuration: config)
            print("✅ MLModel 加载成功")
            
            model = try VNCoreMLModel(for: coreMLModel)
            print("✅ VNCoreMLModel 创建成功")
            
            loadingProgress = 1.0
            isModelLoaded = true
            print("✅ CarDamageDetector 模型加载成功")
        } catch {
            errorMessage = "模型加载失败: \(error.localizedDescription)"
            print("❌ CarDamageDetector 模型加载失败: \(error)")
        }
        
        isLoading = false
    }
    
    private func getModelURL() -> URL {
        // 首先尝试 mlpackage - 直接返回mlpackage的URL，让MLModel.load处理
        if let mlpackageURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage") {
            print("✅ 找到 mlpackage: \(mlpackageURL.path)")
            return mlpackageURL
        }
        
        // 然后尝试 mlmodelc (已编译的模型)
        if let mlmodelcURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
            print("✅ 找到 mlmodelc: \(mlmodelcURL.path)")
            return mlmodelcURL
        }
        
        // 然后尝试 mlmodel
        if let mlmodelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") {
            print("✅ 找到 mlmodel: \(mlmodelURL.path)")
            return mlmodelURL
        }
        
        // 返回一个默认路径，让调用者处理错误
        print("⚠️ 找不到 CarDamageDetector 模型文件，将在加载时处理错误")
        return Bundle.main.bundleURL.appendingPathComponent("CarDamageDetector.mlpackage")
    }
    
    // MARK: - Damage Detection
    func detectDamages(in image: UIImage) async throws -> [DamageDetection] {
        guard let model = model else {
            print("❌ 模型未加载，无法检测")
            throw DetectionError.modelNotLoaded
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print("🔍 开始损伤检测...")
        
        // 转换 UIImage 为 CIImage
        guard let ciImage = CIImage(image: image) else {
            print("❌ 图片转换为CIImage失败")
            throw DetectionError.invalidImage
        }
        print("✅ 图片转换成功")
        
        // 创建 Vision 请求
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
        
        // 执行检测
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])
        
        // 解析结果
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            print("⚠️ 未识别到任何结果")
            return []
        }
        
        print("🔍 识别到 \(results.count) 个原始结果")
        
        // 转换为 DamageDetection
        let detections = results.compactMap { observation -> DamageDetection? in
            guard let label = observation.labels.first else { 
                print("⚠️ 观察结果没有标签")
                return nil 
            }
            
            print("🔍 检测到: \(label.identifier) 置信度: \(label.confidence)")
            
            let damageType = mapToDamageType(label: label.identifier)
            let severity = calculateSeverity(confidence: Double(label.confidence), damageType: damageType)
            
            return DamageDetection(
                type: damageType,
                severity: severity,
                boundingBox: observation.boundingBox,
                mask: [],
                confidence: Double(label.confidence),
                position: .front  // 默认位置
            )
        }
        
        print("✅ 检测到 \(detections.count) 处有效损伤")
        return detections
    }
    
    // MARK: - Helper Methods
    private func mapToDamageType(label: String) -> DamageType {
        switch label.lowercased() {
        case "scratch", "door_scratch":
            return .scratch
        case "dent", "bumper_dent", "door_dent":
            return .dent
        case "glass_shatter":
            return .paintLoss
        default:
            return .scratch
        }
    }
    
    private func calculateSeverity(confidence: Double, damageType: DamageType) -> DamageSeverity {
        let baseSeverity = damageType.severityWeight
        let confidenceWeight = confidence
        
        let score = baseSeverity * confidenceWeight
        
        if score < 0.3 { return .minor }
        if score < 0.6 { return .moderate }
        return .severe
    }
}

enum DetectionError: Error, LocalizedError {
    case modelNotLoaded
    case modelNotFound
    case invalidImage
    case detectionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "AI模型未加载完成"
        case .modelNotFound:
            return "找不到AI模型文件"
        case .invalidImage:
            return "图片格式无效"
        case .detectionFailed:
            return "检测失败"
        }
    }
}

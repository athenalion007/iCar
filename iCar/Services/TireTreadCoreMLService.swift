import Foundation
import UIKit
import CoreML
import Vision

// MARK: - Tire Tread Core ML Service

/// TireTread AI Core ML 模型服务
/// 使用原生 Core ML 进行轮胎花纹深度预测
@MainActor
public final class TireTreadCoreMLService: ObservableObject {

    @Published var isModelLoaded = false
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    @Published var errorMessage: String?

    private var model: MLModel?
    private let modelName = "TireTreadDepth"
    private let inputSize = (width: 224, height: 224)

    init() {
        loadModel()
    }

    private func loadModel() {
        if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc"),
           let compiledModel = try? MLModel(contentsOf: modelURL) {
            model = compiledModel
            isModelLoaded = true
            print("✅ TireTread Core ML 模型加载成功 (compiled)")
            return
        }

        if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") {
            do {
                let compiledURL = try MLModel.compileModel(at: modelURL)
                model = try MLModel(contentsOf: compiledURL)
                isModelLoaded = true
                print("✅ TireTread Core ML 模型加载成功 (compiled from mlmodel)")
                return
            } catch {
                errorMessage = "模型编译失败: \(error.localizedDescription)"
                print("❌ \(errorMessage!)")
            }
        }

        if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage"),
           let packagedModel = try? MLModel(contentsOf: modelURL) {
            model = packagedModel
            isModelLoaded = true
            print("✅ TireTread Core ML 模型加载成功 (mlpackage)")
            return
        }

        errorMessage = "Core ML 模型未找到，请确保 TireTreadDepth.mlmodel 或 TireTreadDepth.mlpackage 已添加到项目中"
        print("⚠️ \(errorMessage!)")
    }

    func predictDepths(from image: UIImage) async throws -> [Double] {
        guard let model = model else {
            throw TireTreadError.modelNotLoaded
        }

        isAnalyzing = true
        analysisProgress = 0.1

        defer {
            isAnalyzing = false
            analysisProgress = 1.0
        }

        analysisProgress = 0.2
        guard let pixelBuffer = image.toCVPixelBuffer(size: CGSize(width: inputSize.width, height: inputSize.height)) else {
            throw TireTreadError.preprocessingFailed
        }

        analysisProgress = 0.5
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": pixelBuffer])
            let output = try await model.prediction(from: input)

            analysisProgress = 0.8
            let possibleFeatureNames = ["depths", "output", "predictions", "regressor_output", "featureValue", "target", "targetProbability"]
            var multiArray: MLMultiArray? = nil

            for featureName in possibleFeatureNames {
                if let featureProvider = output.featureValue(for: featureName),
                   let array = featureProvider.multiArrayValue {
                    multiArray = array
                    print("✅ 找到输出特征: \(featureName)")
                    break
                }
            }

            if multiArray == nil {
                for featureName in output.featureNames {
                    if let featureProvider = output.featureValue(for: featureName),
                       let array = featureProvider.multiArrayValue {
                        multiArray = array
                        print("✅ 找到输出特征(遍历): \(featureName)")
                        break
                    }
                }
            }

            guard let finalArray = multiArray else {
                throw TireTreadError.invalidOutput("无法获取输出数组，可用特征: \(Array(output.featureNames))")
            }

            var depths: [Double] = []
            for i in 0..<min(3, finalArray.count) {
                depths.append(Double(finalArray[i].doubleValue))
            }

            while depths.count < 3 {
                depths.append(4.0)
            }

            analysisProgress = 1.0
            print("✅ 预测完成: 内侧=\(String(format: "%.2f", depths[0]))mm, 中间=\(String(format: "%.2f", depths[1]))mm, 外侧=\(String(format: "%.2f", depths[2]))mm")

            return depths

        } catch {
            throw TireTreadError.inferenceFailed(error.localizedDescription)
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// 转换为 CVPixelBuffer
    func toCVPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()

        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        guard let cgImage = resizedImage.cgImage else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        return buffer
    }
}

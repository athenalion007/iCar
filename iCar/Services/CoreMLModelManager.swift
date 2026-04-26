import Foundation
import CoreML
import Vision
#if canImport(UIKit)
import UIKit
#endif

class CoreMLModelManager: @unchecked Sendable {

    static let shared = CoreMLModelManager()

    private init() {}

    private var modelsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("Models", isDirectory: true)
    }

    func loadPaintScanModel() -> VNCoreMLModel? {
        let compiledModelURL = modelsDirectory.appendingPathComponent("PaintScanYOLO.mlmodelc")

        if FileManager.default.fileExists(atPath: compiledModelURL.path) {
            do {
                let model = try VNCoreMLModel(for: MLModel(contentsOf: compiledModelURL))
                return model
            } catch {
                print("加载编译模型失败: \(error)")
            }
        }

        let modelURL = modelsDirectory.appendingPathComponent("PaintScanYOLO.mlmodel")
        if FileManager.default.fileExists(atPath: modelURL.path) {
            do {
                let compiledURL = try MLModel.compileModel(at: modelURL)
                let model = try VNCoreMLModel(for: MLModel(contentsOf: compiledURL))
                try? FileManager.default.copyItem(at: compiledURL, to: compiledModelURL)
                return model
            } catch {
                print("编译模型失败: \(error)")
            }
        }

        return nil
    }

    func loadEngineEarModel() -> VNCoreMLModel? {
        let compiledModelURL = modelsDirectory.appendingPathComponent("EngineEarCNN.mlmodelc")

        if FileManager.default.fileExists(atPath: compiledModelURL.path) {
            do {
                let model = try VNCoreMLModel(for: MLModel(contentsOf: compiledModelURL))
                return model
            } catch {
                print("加载 EngineEar 模型失败: \(error)")
            }
        }

        let modelURL = modelsDirectory.appendingPathComponent("EngineEarCNN.mlmodel")
        if FileManager.default.fileExists(atPath: modelURL.path) {
            do {
                let compiledURL = try MLModel.compileModel(at: modelURL)
                let model = try VNCoreMLModel(for: MLModel(contentsOf: compiledURL))
                try? FileManager.default.copyItem(at: compiledURL, to: compiledModelURL)
                return model
            } catch {
                print("编译 EngineEar 模型失败: \(error)")
            }
        }

        return nil
    }

    func loadTireTreadModel() -> VNCoreMLModel? {
        let compiledModelURL = modelsDirectory.appendingPathComponent("TireTreadDepth.mlmodelc")

        if FileManager.default.fileExists(atPath: compiledModelURL.path) {
            do {
                let model = try VNCoreMLModel(for: MLModel(contentsOf: compiledModelURL))
                return model
            } catch {
                print("加载 TireTread 模型失败: \(error)")
            }
        }

        let modelURL = modelsDirectory.appendingPathComponent("TireTreadDepth.mlmodel")
        if FileManager.default.fileExists(atPath: modelURL.path) {
            do {
                let compiledURL = try MLModel.compileModel(at: modelURL)
                let model = try VNCoreMLModel(for: MLModel(contentsOf: compiledURL))
                try? FileManager.default.copyItem(at: compiledURL, to: compiledModelURL)
                return model
            } catch {
                print("编译 TireTread 模型失败: \(error)")
            }
        }

        return nil
    }

    func downloadModel(modelName: String, from url: URL, completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "CoreMLModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                }
                return
            }

            do {
                try FileManager.default.createDirectory(at: self!.modelsDirectory, withIntermediateDirectories: true)
                let destinationURL = self!.modelsDirectory.appendingPathComponent(modelName)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                DispatchQueue.main.async { completion(.success(destinationURL)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        task.resume()
    }

    func modelExists(modelName: String) -> Bool {
        let modelURL = modelsDirectory.appendingPathComponent(modelName)
        return FileManager.default.fileExists(atPath: modelURL.path)
    }

    func deleteModel(modelName: String) -> Bool {
        let modelURL = modelsDirectory.appendingPathComponent(modelName)
        do {
            try FileManager.default.removeItem(at: modelURL)
            return true
        } catch {
            print("删除模型失败: \(error)")
            return false
        }
    }

    func listDownloadedModels() -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
            return contents.map { $0.lastPathComponent }.filter { $0.hasSuffix(".mlmodel") || $0.hasSuffix(".mlmodelc") }
        } catch {
            return []
        }
    }

    func clearAllModels() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
            for url in contents {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print("清理模型失败: \(error)")
        }
    }

    func getModelInfo(modelName: String) -> [String: Any]? {
        let modelURL = modelsDirectory.appendingPathComponent(modelName)
        guard FileManager.default.fileExists(atPath: modelURL.path) else { return nil }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: modelURL.path)
            return [
                "name": modelName,
                "size": attributes[.size] as? Int64 ?? 0,
                "creationDate": attributes[.creationDate] as? Date ?? Date(),
                "modificationDate": attributes[.modificationDate] as? Date ?? Date()
            ]
        } catch {
            return nil
        }
    }

    func getModelSize(modelName: String) -> Double {
        let modelURL = modelsDirectory.appendingPathComponent(modelName)
        guard FileManager.default.fileExists(atPath: modelURL.path) else { return 0 }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: modelURL.path)
            let size = attributes[.size] as? Int64 ?? 0
            return Double(size) / (1024 * 1024)
        } catch {
            return 0
        }
    }
}

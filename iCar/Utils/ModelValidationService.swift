import Foundation
import CoreML

/// 模型文件验证服务
/// 用于系统性检测 CoreML 模型文件的问题
@MainActor
final class ModelValidationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var validationResults: [ModelValidationResult] = []
    @Published var isValidating = false
    @Published var totalModels = 0
    @Published var validatedModels = 0
    
    // MARK: - Singleton
    
    static let shared = ModelValidationService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 验证所有模型文件
    func validateAllModels() async {
        isValidating = true
        validationResults = []
        
        let models = getAllModelsToValidate()
        totalModels = models.count
        validatedModels = 0
        
        for model in models {
            let result = await validateModel(model)
            validationResults.append(result)
            validatedModels += 1
        }
        
        isValidating = false
        
        // 打印验证报告
        printValidationReport()
    }
    
    /// 验证单个模型
    func validateModel(_ model: ModelToValidate) async -> ModelValidationResult {
        var issues: [ModelIssue] = []
        
        // 1. 检查文件是否存在
        let fileExists = checkFileExists(model)
        if !fileExists {
            issues.append(.fileNotFound)
        }
        
        // 2. 检查文件大小
        if let fileSize = getFileSize(model) {
            if fileSize < 1024 { // 小于 1KB 可能是空文件
                issues.append(.fileTooSmall(fileSize))
            }
        }
        
        // 3. 检查能否加载
        if fileExists {
            let canLoad = await checkCanLoad(model)
            if !canLoad {
                issues.append(.cannotLoad)
            }
        }
        
        // 4. 检查 Xcode 项目配置
        let isInProject = checkProjectConfiguration(model)
        if !isInProject {
            issues.append(.notInProject)
        }
        
        // 5. 检查 Build Phases
        let isInResources = checkResourcesPhase(model)
        if !isInResources && model.type == .mlpackage {
            issues.append(.notInResourcesPhase)
        }
        
        let isInSources = checkSourcesPhase(model)
        if !isInSources && model.type == .mlmodel {
            issues.append(.notInSourcesPhase)
        }
        
        return ModelValidationResult(
            modelName: model.name,
            modelType: model.type,
            issues: issues,
            isValid: issues.isEmpty
        )
    }
    
    // MARK: - Private Methods
    
    private func getAllModelsToValidate() -> [ModelToValidate] {
        return [
            ModelToValidate(name: "EngineSoundClassifier", type: .mlpackage),
            ModelToValidate(name: "CarDamageDetector", type: .mlpackage),
            ModelToValidate(name: "TireTreadDepth", type: .mlmodel)
        ]
    }
    
    /// 检查文件是否存在
    private func checkFileExists(_ model: ModelToValidate) -> Bool {
        let possiblePaths = [
            Bundle.main.url(forResource: model.name, withExtension: model.type.rawValue),
            Bundle.main.resourceURL?.appendingPathComponent("\(model.name).\(model.type.rawValue)"),
            Bundle.main.resourceURL?.appendingPathComponent("Models/\(model.name).\(model.type.rawValue)")
        ]
        
        for path in possiblePaths {
            if let url = path {
                let exists = FileManager.default.fileExists(atPath: url.path)
                if exists {
                    print("✅ 找到模型文件: \(url.path)")
                    return true
                }
            }
        }
        
        print("❌ 找不到模型文件: \(model.name).\(model.type.rawValue)")
        return false
    }
    
    /// 获取文件大小
    private func getFileSize(_ model: ModelToValidate) -> Int? {
        guard let url = findModelURL(model) else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int
        } catch {
            return nil
        }
    }
    
    /// 查找模型 URL
    private func findModelURL(_ model: ModelToValidate) -> URL? {
        let possiblePaths = [
            Bundle.main.url(forResource: model.name, withExtension: model.type.rawValue),
            Bundle.main.resourceURL?.appendingPathComponent("\(model.name).\(model.type.rawValue)"),
            Bundle.main.resourceURL?.appendingPathComponent("Models/\(model.name).\(model.type.rawValue)")
        ]
        
        for path in possiblePaths {
            if let url = path, FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }
    
    /// 检查能否加载模型
    private func checkCanLoad(_ model: ModelToValidate) async -> Bool {
        guard let url = findModelURL(model) else { return false }
        
        do {
            switch model.type {
            case .mlpackage:
                let compiledURL = try await MLModel.compileModel(at: url)
                _ = try MLModel(contentsOf: compiledURL)
            case .mlmodel:
                _ = try MLModel(contentsOf: url)
            }
            return true
        } catch {
            print("❌ 模型加载失败 \(model.name): \(error)")
            return false
        }
    }
    
    /// 检查 Xcode 项目配置
    private func checkProjectConfiguration(_ model: ModelToValidate) -> Bool {
        // 读取 project.pbxproj 文件
        let projectPath = "/Users/macx/Documents/iCar/iCar.xcodeproj/project.pbxproj"
        
        guard let content = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
            return false
        }
        
        // 检查是否有该模型的引用
        let pattern = "\\b\(model.name)\\.\(model.type.rawValue)\\b"
        return content.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// 检查是否在 Resources build phase
    private func checkResourcesPhase(_ model: ModelToValidate) -> Bool {
        let projectPath = "/Users/macx/Documents/iCar/iCar.xcodeproj/project.pbxproj"
        
        guard let content = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
            return false
        }
        
        // 检查是否在 Resources build phase 中
        let pattern = "in Resources.*=.*isa = PBXBuildFile;.*fileRef.*\(model.name)"
        return content.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// 检查是否在 Sources build phase
    private func checkSourcesPhase(_ model: ModelToValidate) -> Bool {
        let projectPath = "/Users/macx/Documents/iCar/iCar.xcodeproj/project.pbxproj"
        
        guard let content = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
            return false
        }
        
        // 检查是否在 Sources build phase 中
        let pattern = "in Sources.*=.*isa = PBXBuildFile;.*fileRef.*\(model.name)"
        return content.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// 打印验证报告
    private func printValidationReport() {
        print("\n========== 模型验证报告 ==========\n")
        
        let validModels = validationResults.filter { $0.isValid }
        let invalidModels = validationResults.filter { !$0.isValid }
        
        print("✅ 通过验证: \(validModels.count)/\(validationResults.count)")
        print("❌ 未通过验证: \(invalidModels.count)/\(validationResults.count)\n")
        
        if !invalidModels.isEmpty {
            print("问题详情:\n")
            for result in invalidModels {
                print("📦 \(result.modelName).\(result.modelType.rawValue)")
                for issue in result.issues {
                    print("   ❌ \(issue.description)")
                }
                print("")
            }
        }
        
        print("==================================\n")
    }
}

// MARK: - Supporting Types

struct ModelToValidate {
    let name: String
    let type: ModelType
}

enum ModelType: String {
    case mlpackage
    case mlmodel
}

struct ModelValidationResult {
    let modelName: String
    let modelType: ModelType
    let issues: [ModelIssue]
    let isValid: Bool
}

enum ModelIssue: CustomStringConvertible {
    case fileNotFound
    case fileTooSmall(Int)
    case cannotLoad
    case notInProject
    case notInResourcesPhase
    case notInSourcesPhase
    
    var description: String {
        switch self {
        case .fileNotFound:
            return "模型文件不存在"
        case .fileTooSmall(let size):
            return "文件太小 (\(size) bytes)，可能是空文件"
        case .cannotLoad:
            return "无法加载模型，可能已损坏"
        case .notInProject:
            return "模型未添加到 Xcode 项目"
        case .notInResourcesPhase:
            return "mlpackage 未添加到 Resources build phase"
        case .notInSourcesPhase:
            return "mlmodel 未添加到 Sources build phase"
        }
    }
}

// MARK: - View Extension

import SwiftUI

struct ModelValidationView: View {
    @StateObject private var service = ModelValidationService.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task {
                            await service.validateAllModels()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.shield")
                            Text("验证所有模型")
                            Spacer()
                            if service.isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }
                    }
                    .disabled(service.isValidating)
                }
                
                if service.isValidating {
                    Section("进度") {
                        ProgressView(value: Double(service.validatedModels), total: Double(service.totalModels)) {
                            Text("验证中: \(service.validatedModels)/\(service.totalModels)")
                        }
                    }
                }
                
                if !service.validationResults.isEmpty {
                    Section("验证结果") {
                        ForEach(service.validationResults, id: \.modelName) { result in
                            ModelValidationRow(result: result)
                        }
                    }
                }
            }
            .navigationTitle("模型验证")
        }
    }
}

struct ModelValidationRow: View {
    let result: ModelValidationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.isValid ? .green : .red)
                Text("\(result.modelName).\(result.modelType.rawValue)")
                    .font(.headline)
                Spacer()
            }
            
            if !result.issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.issues, id: \.self) { issue in
                        Text("• \(issue.description)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension ModelIssue: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }
}

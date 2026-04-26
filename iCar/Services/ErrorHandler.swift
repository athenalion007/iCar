import Foundation
import SwiftUI

// MARK: - App Error Types

enum AppError: Error, LocalizedError {
    // 网络错误
    case networkError(String)
    case timeoutError
    case serverError(Int)
    
    // 权限错误
    case permissionDenied(String)
    case permissionNotDetermined(String)
    
    // 数据错误
    case invalidData
    case dataNotFound
    case dataCorrupted
    
    // AI模型错误
    case modelNotLoaded
    case modelPredictionFailed(String)
    case insufficientData
    
    // 音频错误
    case audioRecordingFailed(String)
    case audioAnalysisFailed(String)
    case invalidAudioFormat
    
    // 图像错误
    case imageProcessingFailed(String)
    case invalidImageFormat
    case cameraError(String)
    
    // 存储错误
    case storageFull
    case saveFailed(String)
    case loadFailed(String)
    
    // 通用错误
    case unknown(String)
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误: \(message)"
        case .timeoutError:
            return "请求超时，请检查网络连接"
        case .serverError(let code):
            return "服务器错误 (代码: \(code))"
        case .permissionDenied(let type):
            return "\(type)权限被拒绝"
        case .permissionNotDetermined(let type):
            return "\(type)权限未确定"
        case .invalidData:
            return "数据无效"
        case .dataNotFound:
            return "未找到数据"
        case .dataCorrupted:
            return "数据已损坏"
        case .modelNotLoaded:
            return "AI模型未加载"
        case .modelPredictionFailed(let reason):
            return "AI分析失败: \(reason)"
        case .insufficientData:
            return "数据不足，无法进行分析"
        case .audioRecordingFailed(let reason):
            return "录音失败: \(reason)"
        case .audioAnalysisFailed(let reason):
            return "音频分析失败: \(reason)"
        case .invalidAudioFormat:
            return "音频格式不支持"
        case .imageProcessingFailed(let reason):
            return "图像处理失败: \(reason)"
        case .invalidImageFormat:
            return "图像格式不支持"
        case .cameraError(let reason):
            return "相机错误: \(reason)"
        case .storageFull:
            return "存储空间不足"
        case .saveFailed(let reason):
            return "保存失败: \(reason)"
        case .loadFailed(let reason):
            return "加载失败: \(reason)"
        case .unknown(let message):
            return "未知错误: \(message)"
        case .userCancelled:
            return "用户已取消"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError, .timeoutError:
            return "请检查网络连接后重试"
        case .serverError:
            return "服务器暂时不可用，请稍后重试"
        case .permissionDenied:
            return "请在设置中开启相关权限"
        case .permissionNotDetermined:
            return "请允许应用获取相关权限"
        case .invalidData, .dataCorrupted:
            return "请重新输入或选择有效数据"
        case .dataNotFound:
            return "请检查数据是否存在"
        case .modelNotLoaded:
            return "正在加载AI模型，请稍候"
        case .modelPredictionFailed:
            return "请确保输入数据质量良好后重试"
        case .insufficientData:
            return "请提供更多数据进行分析"
        case .audioRecordingFailed:
            return "请检查麦克风权限和设备状态"
        case .audioAnalysisFailed:
            return "请确保录音质量良好"
        case .invalidAudioFormat:
            return "请使用支持的音频格式"
        case .imageProcessingFailed, .invalidImageFormat:
            return "请确保图像清晰且格式正确"
        case .cameraError:
            return "请检查相机权限和设备状态"
        case .storageFull:
            return "请清理存储空间后重试"
        case .saveFailed, .loadFailed:
            return "请检查存储权限和可用空间"
        case .unknown:
            return "请重试或联系技术支持"
        case .userCancelled:
            return nil
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .userCancelled:
            return false
        case .permissionDenied:
            return true
        default:
            return true
        }
    }
}

// MARK: - Error Handler

@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var showErrorAlert = false
    
    private init() {}
    
    func handle(_ error: Error, context: String? = nil) {
        let appError: AppError
        
        if let error = error as? AppError {
            appError = error
        } else {
            appError = .unknown(error.localizedDescription)
        }
        
        // 记录错误日志
        logError(appError, context: context)
        
        // 显示错误提示
        currentError = appError
        showErrorAlert = true
    }
    
    func handleAsync(_ error: Error, context: String? = nil) async {
        handle(error, context: context)
    }
    
    func clearError() {
        currentError = nil
        showErrorAlert = false
    }
    
    private func logError(_ error: AppError, context: String?) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let contextStr = context ?? "Unknown"
        print("[ERROR] \(timestamp) - Context: \(contextStr)")
        print("        Description: \(error.errorDescription ?? "Unknown")")
        if let suggestion = error.recoverySuggestion {
            print("        Suggestion: \(suggestion)")
        }
    }
}

// MARK: - Error Alert View Modifier

struct ErrorAlert: ViewModifier {
    @StateObject private var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert("错误", isPresented: $errorHandler.showErrorAlert) {
                if let error = errorHandler.currentError, error.isRecoverable {
                    Button("重试") {
                        // 可以在这里添加重试逻辑
                        errorHandler.clearError()
                    }
                }
                
                if let error = errorHandler.currentError,
                   case .permissionDenied = error {
                    Button("去设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        errorHandler.clearError()
                    }
                }
                
                Button("确定", role: .cancel) {
                    errorHandler.clearError()
                }
            } message: {
                if let error = errorHandler.currentError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.errorDescription ?? "发生未知错误")
                        
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorAlert())
    }
}

// MARK: - Result Extension

extension Result {
    func handleError(_ handler: @escaping (Error) -> Void) -> Self {
        if case .failure(let error) = self {
            handler(error)
        }
        return self
    }
}

// MARK: - ThrowingTaskGroup Extension

extension Task where Success == Void, Failure == Error {
    static func runWithErrorHandling(
        context: String,
        operation: @escaping () async throws -> Void
    ) -> Task<Void, Error> {
        Task {
            do {
                try await operation()
            } catch {
                await ErrorHandler.shared.handleAsync(error, context: context)
            }
        }
    }
}

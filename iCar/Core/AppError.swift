import Foundation

// MARK: - App Error

enum AppError: Error, LocalizedError {
    case modelLoadingFailed(String)
    case modelNotFound(String)
    case analysisFailed(String)
    case invalidInput(String)
    case invalidImage
    case invalidAudio
    case recordingFailed(String)
    case cameraPermissionDenied
    case microphonePermissionDenied
    case motionPermissionDenied
    case networkError(String)
    case persistenceError(String)
    case timeoutError
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .modelLoadingFailed(let model):
            return String(format: String(localized: "error.model.loading_failed"), model)
        case .modelNotFound(let model):
            return String(format: String(localized: "error.model.not_found"), model)
        case .analysisFailed(let reason):
            return String(format: String(localized: "error.analysis.failed"), reason)
        case .invalidInput(let detail):
            return String(format: String(localized: "error.invalid.input"), detail)
        case .invalidImage:
            return String(localized: "error.invalid.image")
        case .invalidAudio:
            return String(localized: "error.invalid.audio")
        case .recordingFailed(let reason):
            return String(format: String(localized: "error.recording.failed"), reason)
        case .cameraPermissionDenied:
            return String(localized: "permission.camera.denied")
        case .microphonePermissionDenied:
            return String(localized: "permission.microphone.denied")
        case .motionPermissionDenied:
            return String(localized: "permission.motion.denied")
        case .networkError(let detail):
            return String(format: String(localized: "error.network"), detail)
        case .persistenceError(let detail):
            return String(format: String(localized: "error.persistence"), detail)
        case .timeoutError:
            return String(localized: "error.timeout")
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .modelLoadingFailed, .modelNotFound:
            return false
        case .cameraPermissionDenied, .microphonePermissionDenied, .motionPermissionDenied:
            return true
        case .networkError:
            return true
        case .timeoutError:
            return true
        case .analysisFailed, .invalidInput, .invalidImage, .invalidAudio, .recordingFailed, .persistenceError:
            return true
        case .unknown:
            return false
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cameraPermissionDenied:
            return String(localized: "error.recovery.camera")
        case .microphonePermissionDenied:
            return String(localized: "error.recovery.microphone")
        case .motionPermissionDenied:
            return String(localized: "error.recovery.motion")
        case .networkError:
            return String(localized: "error.recovery.network")
        case .modelNotFound:
            return String(localized: "error.recovery.model")
        case .timeoutError:
            return String(localized: "error.recovery.network")
        default:
            return nil
        }
    }
}

// MARK: - Result Extension

extension Result where Failure == AppError {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }

    var error: AppError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

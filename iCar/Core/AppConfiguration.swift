import Foundation
import CoreGraphics

// MARK: - App Configuration

enum AppConfiguration {

    // MARK: - Model Configuration

    enum Models {
        static let engineSoundClassifier = "EngineSoundClassifier"
        static let carDamageDetector = "CarDamageDetector"
        static let tireTreadDepth = "TireTreadDepth"

        static let confidenceThreshold: Double = 0.5
        static let nmsThreshold: Double = 0.45
    }

    // MARK: - Audio Configuration

    enum Audio {
        static let sampleRate: Double = 44100.0
        static let maxRecordingDuration: TimeInterval = 5.0
        static let fftSize: Int = 2048
        static let melBands: Int = 128
    }

    // MARK: - Camera Configuration

    enum Camera {
        static let targetImageSize = CGSize(width: 640, height: 640)
        static let photoQuality: CGFloat = 0.85
    }

    // MARK: - Suspension Configuration

    enum Suspension {
        static let defaultMonitoringDuration: TimeInterval = 10.0
        static let accelerometerUpdateInterval: TimeInterval = 0.01
        static let fftSize: Int = 512
    }

    // MARK: - AC Configuration

    enum AC {
        static let beltAnalysisSampleStep: Int = 10000
        static let crackThreshold: Double = 0.02
        static let glazeThreshold: Double = 0.1
    }

    // MARK: - Storage Keys

    enum StorageKeys {
        static let userSettings = "user_settings"
        static let lastInspection = "last_inspection"
        static let onboardingCompleted = "onboarding_completed"
        static let privacyPolicyAccepted = "privacy_policy_accepted"
    }

    // MARK: - UI Configuration

    enum UI {
        static let animationDuration: Double = 0.3
        static let progressUpdateInterval: TimeInterval = 0.1
        static let maxRetryCount: Int = 3
    }

    // MARK: - Environment

    static var isDebug: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }
}

// MARK: - CGSize Extension

extension CGSize: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

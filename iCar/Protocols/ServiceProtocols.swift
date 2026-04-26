import Foundation
import CoreML
#if canImport(UIKit)
import UIKit
#endif
import AVFoundation
import CoreMotion

@MainActor
protocol CameraServiceProtocol: AnyObject {
    var isSessionRunning: Bool { get }
    var cameraPermissionStatus: AVAuthorizationStatus { get }
    func requestCameraPermission() async -> Bool
    func startSession()
    func stopSession()
    func capturePhoto()
}

@MainActor
protocol AudioRecordingServiceProtocol: AnyObject {
    var hasMicrophonePermission: Bool { get }
    func requestMicrophonePermission() async -> Bool
    func startRecording() async throws
    func stopRecording()
    func getRecordingFileURL() -> URL?
}

@MainActor
protocol EngineSoundClassifierProtocol: AnyObject {
    var isModelLoaded: Bool { get }
    var isLoading: Bool { get }
    func classify(audioURL: URL) async throws -> ClassificationResult
}

@MainActor
protocol CarDamageDetectorProtocol: AnyObject {
    var isModelLoaded: Bool { get }
    func detectDamages(in image: UIImage) async throws -> [DamageDetection]
}

@MainActor
protocol TireTreadAnalysisProtocol: AnyObject {
    var isModelLoaded: Bool { get }
    var isAnalyzing: Bool { get }
    func analyzeTires(_ photos: [TirePhoto]) async -> TireTreadReport
}

@MainActor
protocol SuspensionMonitorProtocol: AnyObject {
    var isMonitoring: Bool { get }
    var monitoringProgress: Double { get }
    func startMonitoring(duration: TimeInterval)
    func stopMonitoring()
    func performDiagnosis(drivingMode: SuspensionDiagnosisResult.DrivingMode) -> SuspensionDiagnosisResult
}

@MainActor
protocol ACMonitorProtocol: AnyObject {
    var isRecording: Bool { get }
    func startRecording(duration: TimeInterval)
    func stopRecording()
    func analyzeBeltFromImage(_ image: UIImage) -> BeltAnalysisResult
    func analyzeFanSound(audioURL: URL?) async throws -> FanSoundAnalysis
}

@MainActor
protocol PaintScanAIProtocol: AnyObject {
    var isProcessing: Bool { get }
    func analyzeImage(_ image: UIImage, position: PaintScanPosition) async throws -> DetectionResult
    func analyzeImages(_ photos: [CapturedPhoto]) async throws -> [DetectionResult]
}

@MainActor
protocol DataPersistenceProtocol: AnyObject {
    func loadAllData() async
    func createVehicle(brand: String, model: String, year: Int16, licensePlate: String, mileage: Double, fuelLevel: Double, color: String, vin: String, status: String) async throws -> CDVehicle
    func deleteVehicle(_ vehicle: CDVehicle) async throws
    func createInspectionReport(title: String, vehicle: CDVehicle?, carBrand: String, carModel: String, licensePlate: String, carColor: String, vin: String, mileage: Double, detectionResults: [DetectionResult], capturedPhotos: [CapturedPhotoInfo], overallScore: Int16, glossLevel: Double, clarity: Double, colorConsistency: Double, status: String, tags: [String]) async throws -> CDInspectionReport
    func deleteInspectionReport(_ report: CDInspectionReport) async throws
}

protocol AppCarServiceProtocol: Sendable {
    func fetchCars() async throws -> [Car]
    func saveCar(_ car: Car) async throws
    func deleteCar(by id: UUID) async throws
}

@MainActor
protocol NetworkMonitorProtocol: AnyObject {
    var isConnected: Bool { get }
    var connectionType: ConnectionType { get }
    func stopMonitoring()
}

enum ConnectionType: Sendable {
    case wifi
    case cellular
    case ethernet
    case unknown
}

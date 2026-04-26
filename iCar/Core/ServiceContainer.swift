import Foundation
import SwiftUI

@MainActor
protocol ServiceContainerProtocol {
    var cameraService: CameraServiceProtocol { get }
    var audioRecordingService: AudioRecordingServiceProtocol { get }
    var engineSoundClassifier: EngineSoundClassifierProtocol { get }
    var carDamageDetector: CarDamageDetectorProtocol { get }
    var tireTreadService: TireTreadAnalysisProtocol { get }
    var suspensionMonitor: SuspensionMonitorProtocol { get }
    var acMonitor: ACMonitorProtocol { get }
    var paintScanAI: PaintScanAIProtocol { get }
    var dataPersistence: DataPersistenceProtocol { get }
    var carService: AppCarServiceProtocol { get }
    var networkMonitor: NetworkMonitorProtocol { get }
}

@MainActor
final class ProductionServiceContainer: ServiceContainerProtocol {

    private lazy var _cameraService = CameraService.shared
    private lazy var _audioRecordingService = AudioRecordingService.shared
    private lazy var _engineSoundClassifier = EngineSoundClassifier()
    private lazy var _carDamageDetector = CarDamageDetectorService.shared
    private lazy var _tireTreadService = TireTreadAIService.shared
    private lazy var _suspensionMonitor = SuspensionMonitorService.shared
    private lazy var _acMonitor = ACMonitorService.shared
    private lazy var _paintScanAI = PaintScanAIService.shared
    private lazy var _dataPersistence = DataPersistenceService.shared
    private lazy var _carService = CarService()
    private lazy var _networkMonitor = NetworkMonitor.shared

    var cameraService: CameraServiceProtocol { _cameraService }
    var audioRecordingService: AudioRecordingServiceProtocol { _audioRecordingService }
    var engineSoundClassifier: EngineSoundClassifierProtocol { _engineSoundClassifier }
    var carDamageDetector: CarDamageDetectorProtocol { _carDamageDetector }
    var tireTreadService: TireTreadAnalysisProtocol { _tireTreadService }
    var suspensionMonitor: SuspensionMonitorProtocol { _suspensionMonitor }
    var acMonitor: ACMonitorProtocol { _acMonitor }
    var paintScanAI: PaintScanAIProtocol { _paintScanAI }
    var dataPersistence: DataPersistenceProtocol { _dataPersistence }
    var carService: AppCarServiceProtocol { _carService }
    var networkMonitor: NetworkMonitorProtocol { _networkMonitor }
}

private struct ServiceContainerKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ServiceContainerProtocol = ProductionServiceContainer()
}

extension EnvironmentValues {
    var serviceContainer: ServiceContainerProtocol {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

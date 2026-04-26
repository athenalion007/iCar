import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit

enum BatteryHealthStatus: String, CaseIterable, Codable {
    case excellent = "优秀"
    case good = "良好"
    case fair = "一般"
    case poor = "较差"
    case critical = "严重"

    var color: String {
        switch self {
        case .excellent: return "#34C759"
        case .good: return "#5AC8FA"
        case .fair: return "#FFCC00"
        case .poor: return "#FF9500"
        case .critical: return "#FF3B30"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "battery.100.bolt"
        case .good: return "battery.75"
        case .fair: return "battery.50"
        case .poor: return "battery.25"
        case .critical: return "battery.0"
        }
    }

    var description: String {
        switch self {
        case .excellent:
            return "电池状态极佳，性能如新"
        case .good:
            return "电池状态良好，正常使用"
        case .fair:
            return "电池有一定老化，建议关注"
        case .poor:
            return "电池老化明显，建议检查"
        case .critical:
            return "电池严重老化，建议更换"
        }
    }

    var scoreRange: ClosedRange<Int> {
        switch self {
        case .excellent: return 90...100
        case .good: return 75...89
        case .fair: return 60...74
        case .poor: return 40...59
        case .critical: return 0...39
        }
    }
}

enum ChargingPattern: String, Codable, CaseIterable {
    case normal = "正常充电"
    case fast = "快速充电"
    case trickle = "涓流充电"
    case intermittent = "间歇充电"

    var impactOnHealth: String {
        switch self {
        case .normal:
            return "对电池健康影响最小"
        case .fast:
            return "长期使用可能加速老化"
        case .trickle:
            return "有助于延长电池寿命"
        case .intermittent:
            return "频繁插拔可能影响寿命"
        }
    }
}

struct BatteryRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let voltage: Double
    let current: Double
    let temperature: Double
    let soc: Double
    let healthScore: Int
    let chargingPattern: ChargingPattern
    let location: BatteryLocation?

    struct BatteryLocation: Codable {
        let latitude: Double
        let longitude: Double
        let altitude: Double
    }
}

struct ChargingSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    let startSoc: Double
    var endSoc: Double?
    let pattern: ChargingPattern
    let location: String
    var averageVoltage: Double?
    var averageCurrent: Double?
    var estimatedCapacity: Double?
}

struct BatteryTrendData: Identifiable {
    let id = UUID()
    let date: Date
    let healthScore: Int
    let capacity: Double
    let voltage: Double
}

struct BatteryDiagnosisResult: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let overallScore: Int
    let healthStatus: BatteryHealthStatus
    let estimatedCapacity: Double
    let voltageStability: Double
    let temperaturePerformance: Double
    let chargingEfficiency: Double
    let recommendations: [String]
    let warnings: [String]
}

@MainActor
final class BatteryMonitorService: ObservableObject {

    @Published var isMonitoring = false
    @Published var currentVoltage: Double = 0
    @Published var currentTemperature: Double = 0
    @Published var currentSOC: Double = 0
    @Published var healthScore: Int = 0
    @Published var healthStatus: BatteryHealthStatus = .good
    @Published var records: [BatteryRecord] = []
    @Published var chargingSessions: [ChargingSession] = []
    @Published var trendData: [BatteryTrendData] = []
    @Published var currentSession: ChargingSession?
    @Published var errorMessage: String?

    private var monitoringTimer: Timer?
    private var recordTimer: Timer?
    private let userDefaults = UserDefaults.standard
    private let recordsKey = "batteryRecords"
    private let sessionsKey = "chargingSessions"

    static let shared = BatteryMonitorService()

    private init() {
        loadData()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        errorMessage = nil

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.readRealTimeData()
            }
        }

        recordTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordCurrentState()
            }
        }

        readRealTimeData()
        recordCurrentState()
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        recordTimer?.invalidate()
        monitoringTimer = nil
        recordTimer = nil
    }

    func startChargingSession(pattern: ChargingPattern, location: String) {
        let session = ChargingSession(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            startSoc: currentSOC,
            endSoc: nil,
            pattern: pattern,
            location: location,
            averageVoltage: nil,
            averageCurrent: nil,
            estimatedCapacity: nil
        )
        currentSession = session
    }

    func endChargingSession(voltage: Double, current: Double) {
        guard var session = currentSession else { return }

        session.endTime = Date()
        session.endSoc = currentSOC
        session.averageVoltage = voltage
        session.averageCurrent = current

        let chargedAmount = session.endSoc! - session.startSoc
        let duration = session.endTime!.timeIntervalSince(session.startTime) / 3600
        if duration > 0 {
            session.estimatedCapacity = (chargedAmount / 100.0) * 60.0 / duration
        }

        chargingSessions.append(session)
        currentSession = nil
        saveSessions()
    }

    func addChargingData(
        voltage: Double,
        current: Double,
        duration: TimeInterval,
        pattern: ChargingPattern
    ) -> BatteryDiagnosisResult {
        let voltageScore = calculateVoltageScore(voltage: voltage, current: current)
        let efficiencyScore = calculateEfficiencyScore(pattern: pattern, duration: duration)
        let temperatureScore = calculateTemperatureScore()

        let overallScore = Int((voltageScore + efficiencyScore + temperatureScore) / 3)
        let status = healthStatusFromScore(overallScore)

        var recommendations: [String] = []
        var warnings: [String] = []

        if voltage < 12.0 {
            warnings.append("电压偏低，可能存在充电不足")
            recommendations.append("检查发电机工作状态")
        }

        if pattern == .fast {
            warnings.append("频繁使用快充可能影响电池寿命")
            recommendations.append("尽量使用标准充电模式")
        }

        if overallScore < 70 {
            recommendations.append("建议到专业维修店进行电池检测")
        }

        if recommendations.isEmpty {
            recommendations.append("电池状态良好，继续保持")
        }

        let result = BatteryDiagnosisResult(
            id: UUID(),
            timestamp: Date(),
            overallScore: overallScore,
            healthStatus: status,
            estimatedCapacity: currentSOC,
            voltageStability: voltageScore,
            temperaturePerformance: temperatureScore,
            chargingEfficiency: efficiencyScore,
            recommendations: recommendations,
            warnings: warnings
        )

        healthScore = overallScore
        healthStatus = status

        return result
    }

    func getDiagnosis() -> BatteryDiagnosisResult {
        let voltageScore = calculateVoltageScore(voltage: currentVoltage, current: 0)
        let efficiencyScore = calculateEfficiencyScore(pattern: .normal, duration: 3600)
        let temperatureScore = calculateTemperatureScore()

        let overallScore = Int((voltageScore + efficiencyScore + temperatureScore) / 3)
        let status = healthStatusFromScore(overallScore)

        var recommendations: [String] = []
        var warnings: [String] = []

        if currentVoltage < 12.0 {
            warnings.append("当前电压偏低")
            recommendations.append("检查充电系统")
        }

        if currentTemperature > 40 {
            warnings.append("电池温度过高")
            recommendations.append("避免高温环境使用")
        }

        if recommendations.isEmpty {
            recommendations.append("电池状态正常")
        }

        return BatteryDiagnosisResult(
            id: UUID(),
            timestamp: Date(),
            overallScore: overallScore,
            healthStatus: status,
            estimatedCapacity: currentSOC,
            voltageStability: voltageScore,
            temperaturePerformance: temperatureScore,
            chargingEfficiency: efficiencyScore,
            recommendations: recommendations,
            warnings: warnings
        )
    }

    func clearAllData() {
        records.removeAll()
        chargingSessions.removeAll()
        trendData.removeAll()
        saveData()
        saveSessions()
    }

    private func readRealTimeData() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        currentSOC = Double(device.batteryLevel >= 0 ? device.batteryLevel * 100 : 0)

        switch device.batteryState {
        case .charging:
            currentVoltage = 13.8
        case .full:
            currentVoltage = 12.6
        case .unplugged:
            currentVoltage = 12.4
        default:
            currentVoltage = 12.0
        }

        currentTemperature = 25.0
    }

    private func recordCurrentState() {
        guard currentVoltage > 0 else {
            errorMessage = "未获取到有效的电池数据"
            return
        }

        let record = BatteryRecord(
            id: UUID(),
            timestamp: Date(),
            voltage: currentVoltage,
            current: 0,
            temperature: currentTemperature,
            soc: currentSOC,
            healthScore: healthScore,
            chargingPattern: detectChargingPattern(),
            location: nil
        )

        records.append(record)

        if records.count > 1000 {
            records.removeFirst(records.count - 1000)
        }

        saveData()
    }

    private func detectChargingPattern() -> ChargingPattern {
        if currentSOC > 90 {
            return .trickle
        } else if currentVoltage > 14.0 {
            return .fast
        } else {
            return .normal
        }
    }

    private func calculateVoltageScore(voltage: Double, current: Double) -> Double {
        let optimalVoltage = 12.6
        let deviation = abs(voltage - optimalVoltage)
        return max(0, 100 - deviation * 20)
    }

    private func calculateEfficiencyScore(pattern: ChargingPattern, duration: TimeInterval) -> Double {
        var baseScore = 85.0

        switch pattern {
        case .normal:
            baseScore += 10
        case .fast:
            baseScore -= 5
        case .trickle:
            baseScore += 15
        case .intermittent:
            baseScore -= 10
        }

        if duration > 8 * 3600 {
            baseScore -= 10
        }

        return max(0, min(100, baseScore))
    }

    private func calculateTemperatureScore() -> Double {
        let optimalTemp = 25.0
        let deviation = abs(currentTemperature - optimalTemp)
        return max(0, 100 - deviation * 3)
    }

    private func healthStatusFromScore(_ score: Int) -> BatteryHealthStatus {
        for status in BatteryHealthStatus.allCases {
            if status.scoreRange.contains(score) {
                return status
            }
        }
        return .critical
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(records) {
            userDefaults.set(data, forKey: recordsKey)
        }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(chargingSessions) {
            userDefaults.set(data, forKey: sessionsKey)
        }
    }

    private func loadData() {
        if let data = userDefaults.data(forKey: recordsKey),
           let loaded = try? JSONDecoder().decode([BatteryRecord].self, from: data) {
            records = loaded
        }

        if let data = userDefaults.data(forKey: sessionsKey),
           let loaded = try? JSONDecoder().decode([ChargingSession].self, from: data) {
            chargingSessions = loaded
        }
    }
}

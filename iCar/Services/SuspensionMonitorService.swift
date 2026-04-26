import Foundation
import CoreMotion
import Accelerate
import Combine

// MARK: - Suspension Status

enum SuspensionStatus: String, CaseIterable, Codable {
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
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.shield.fill"
        case .fair: return "exclamationmark.circle.fill"
        case .poor: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    var description: String {
        switch self {
        case .excellent:
            return "悬挂系统状态极佳"
        case .good:
            return "悬挂系统工作正常"
        case .fair:
            return "悬挂系统有轻微磨损"
        case .poor:
            return "悬挂系统需要检修"
        case .critical:
            return "悬挂系统存在严重问题"
        }
    }
}

// MARK: - Vibration Data Point

struct VibrationDataPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let x: Double
    let y: Double
    let z: Double
    let magnitude: Double
    
    init(timestamp: Date = Date(), x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
        self.magnitude = sqrt(x*x + y*y + z*z)
    }
}

// MARK: - Frequency Spectrum

struct FrequencySpectrum: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let frequencies: [Double]
    let magnitudes: [Double]
    let dominantFrequency: Double
    let totalEnergy: Double
}

// MARK: - Suspension Diagnosis Issue

enum SuspensionIssueType: String, CaseIterable, Codable {
    case normal = "正常"
    case shockAbsorberWear = "减震器磨损"
    case springFatigue = "弹簧疲劳"
    case bushingWear = "衬套磨损"
    case alignmentIssue = "定位问题"
    case tireImbalance = "轮胎不平衡"
    case wheelBearingWear = "轮毂轴承磨损"
    
    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .shockAbsorberWear: return "arrow.up.and.down"
        case .springFatigue: return "arrow.down.circle"
        case .bushingWear: return "circle.dotted"
        case .alignmentIssue: return "arrow.left.and.right"
        case .tireImbalance: return "circle.hexagongrid"
        case .wheelBearingWear: return "gear"
        }
    }
    
    var description: String {
        switch self {
        case .normal:
            return "悬挂系统工作正常，无异常振动"
        case .shockAbsorberWear:
            return "减震器阻尼下降，导致车身晃动增加"
        case .springFatigue:
            return "弹簧弹性减弱，车身高度可能降低"
        case .bushingWear:
            return "橡胶衬套老化，产生异响和松动感"
        case .alignmentIssue:
            return "车轮定位参数偏离，影响行驶稳定性"
        case .tireImbalance:
            return "轮胎动平衡不良，高速时产生抖动"
        case .wheelBearingWear:
            return "轮毂轴承磨损，产生嗡嗡声"
        }
    }
    
    var severity: SuspensionStatus {
        switch self {
        case .normal: return .excellent
        case .tireImbalance: return .fair
        case .bushingWear: return .fair
        case .alignmentIssue: return .poor
        case .springFatigue: return .poor
        case .shockAbsorberWear: return .poor
        case .wheelBearingWear: return .critical
        }
    }
    
    var recommendedAction: String {
        switch self {
        case .normal:
            return "继续保持定期保养"
        case .shockAbsorberWear:
            return "建议更换减震器"
        case .springFatigue:
            return "建议检查并更换弹簧"
        case .bushingWear:
            return "建议更换橡胶衬套"
        case .alignmentIssue:
            return "建议进行四轮定位"
        case .tireImbalance:
            return "建议进行轮胎动平衡"
        case .wheelBearingWear:
            return "建议尽快更换轮毂轴承"
        }
    }
    
    var frequencyRange: ClosedRange<Double> {
        switch self {
        case .normal: return 1...50
        case .shockAbsorberWear: return 1...5
        case .springFatigue: return 0.5...3
        case .bushingWear: return 5...15
        case .alignmentIssue: return 2...8
        case .tireImbalance: return 10...20
        case .wheelBearingWear: return 15...30
        }
    }
}

// MARK: - Suspension Diagnosis Result

struct SuspensionDiagnosisResult: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let overallScore: Int
    let status: SuspensionStatus
    let detectedIssues: [SuspensionIssueType]
    let vibrationData: [VibrationDataPoint]
    let spectrum: FrequencySpectrum?
    let recommendations: [String]
    let drivingMode: DrivingMode

    enum DrivingMode: String, Codable {
        case stationary = "静止"
        case city = "城市"
        case highway = "高速"
        case rough = "颠簸路面"
    }
}

// MARK: - Suspension Monitor Service

@MainActor
final class SuspensionMonitorService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isMonitoring = false
    @Published var currentVibration: VibrationDataPoint?
    @Published var vibrationHistory: [VibrationDataPoint] = []
    @Published var spectrumData: FrequencySpectrum?
    @Published var overallScore: Int = 85
    @Published var status: SuspensionStatus = .good
    @Published var detectedIssues: [SuspensionIssueType] = []
    @Published var monitoringProgress: Double = 0
    @Published var currentStep: String = ""
    @Published var errorMessage: String?
    
    // MARK: - Properties
    
    private let motionManager = CMMotionManager()
    private var monitoringTimer: Timer?
    private var recordingStartTime: Date?
    private var recordedData: [VibrationDataPoint] = []
    
    private let sampleRate = 100.0 // Hz
    private let fftSize = 1024
    
    // MARK: - Singleton
    
    static let shared = SuspensionMonitorService()
    
    private init() {
        setupMotionManager()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring(duration: TimeInterval = 10.0) {
        guard !isMonitoring else { return }
        guard motionManager.isAccelerometerAvailable else { return }
        
        isMonitoring = true
        recordedData.removeAll()
        recordingStartTime = Date()
        monitoringProgress = 0
        currentStep = "正在采集振动数据..."
        
        // 开始加速度计更新
        motionManager.accelerometerUpdateInterval = 1.0 / sampleRate
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            let point = VibrationDataPoint(
                timestamp: Date(),
                x: data.acceleration.x,
                y: data.acceleration.y,
                z: data.acceleration.z
            )
            
            self.recordedData.append(point)
            self.currentVibration = point
            
            // 限制数据量
            if self.recordedData.count > Int(self.sampleRate * duration) {
                self.recordedData.removeFirst()
            }
        }
        
        // 进度更新
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                
                let elapsed = Date().timeIntervalSince(startTime)
                self.monitoringProgress = min(1.0, elapsed / duration)
                
                if elapsed >= duration {
                    self.stopMonitoring()
                }
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        motionManager.stopAccelerometerUpdates()
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // 分析数据
        if !recordedData.isEmpty {
            analyzeRecordedData()
        }
    }
    
    func performDiagnosis(drivingMode: SuspensionDiagnosisResult.DrivingMode = .city) -> SuspensionDiagnosisResult {
        let realData = recordedData
        
        guard !realData.isEmpty else {
            errorMessage = "未采集到振动数据，请先开始监测"
            return SuspensionDiagnosisResult(
                id: UUID(),
                timestamp: Date(),
                overallScore: 0,
                status: .critical,
                detectedIssues: [.normal],
                vibrationData: [],
                spectrum: nil,
                recommendations: ["未采集到振动数据，请确保设备运动传感器正常工作并重试"],
                drivingMode: drivingMode
            )
        }
        
        guard let spectrum = performFFT(on: Array(realData.prefix(fftSize))) else {
            return SuspensionDiagnosisResult(
                id: UUID(),
                timestamp: Date(),
                overallScore: 0,
                status: .critical,
                detectedIssues: [.normal],
                vibrationData: realData,
                spectrum: nil,
                recommendations: [errorMessage ?? "频谱分析失败，请重试"],
                drivingMode: drivingMode
            )
        }
        
        let issues = analyzeIssues(from: spectrum)
        let score = calculateOverallScore(issues: issues, spectrum: spectrum)
        let status = statusFromScore(score)
        
        var recommendations: [String] = []
        if issues.contains(.shockAbsorberWear) {
            recommendations.append("检查减震器是否有漏油现象")
        }
        if issues.contains(.springFatigue) {
            recommendations.append("测量车身高度，检查弹簧是否下沉")
        }
        if issues.contains(.bushingWear) {
            recommendations.append("检查悬挂各连接点的橡胶衬套")
        }
        if issues.contains(.alignmentIssue) {
            recommendations.append("进行四轮定位检查")
        }
        if issues.contains(.tireImbalance) {
            recommendations.append("进行轮胎动平衡")
        }
        if issues.contains(.wheelBearingWear) {
            recommendations.append("检查轮毂轴承间隙")
        }
        
        if recommendations.isEmpty {
            recommendations.append("悬挂系统状态良好，继续保持定期保养")
        }
        
        let result = SuspensionDiagnosisResult(
            id: UUID(),
            timestamp: Date(),
            overallScore: score,
            status: status,
            detectedIssues: issues,
            vibrationData: realData,
            spectrum: spectrum,
            recommendations: recommendations,
            drivingMode: drivingMode
        )
        
        overallScore = score
        self.status = status
        detectedIssues = issues
        spectrumData = spectrum
        vibrationHistory = realData
        
        return result
    }
    
    func getFrequencyAnalysis() -> FrequencySpectrum? {
        return spectrumData
    }
    
    // MARK: - Private Methods
    
    private func setupMotionManager() {
        // 配置运动管理器
    }
    
    private func analyzeRecordedData() {
        guard recordedData.count >= fftSize else {
            errorMessage = "采集数据不足，需要至少 \(fftSize) 个数据点"
            return
        }
        
        guard let spectrum = performFFT(on: Array(recordedData.prefix(fftSize))) else {
            return
        }
        spectrumData = spectrum
        
        detectedIssues = analyzeIssues(from: spectrum)
        overallScore = calculateOverallScore(issues: detectedIssues, spectrum: spectrum)
        status = statusFromScore(overallScore)
        
        vibrationHistory = recordedData
    }
    
    private func performFFT(on data: [VibrationDataPoint]) -> FrequencySpectrum? {
        guard !data.isEmpty else {
            errorMessage = "振动数据为空，无法进行频谱分析"
            return nil
        }
        
        // 提取Z轴数据（垂直方向振动）
        let zData = data.map { Float($0.z) }
        
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            errorMessage = "FFT初始化失败，无法完成频谱分析"
            return nil
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // 准备数据
        var real = zData + [Float](repeating: 0, count: fftSize - zData.count)
        var imaginary = [Float](repeating: 0, count: fftSize)
        
        // 执行FFT
        real.withUnsafeMutableBufferPointer { realPtr in
            imaginary.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                   imagp: imagPtr.baseAddress!)
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        
        // 计算幅度谱
        let magnitudeCount = fftSize / 2
        var magnitudes = [Float](repeating: 0, count: magnitudeCount)
        
        for i in 0..<magnitudeCount {
            let realVal = real[i]
            let imagVal = imaginary[i]
            magnitudes[i] = sqrt(realVal * realVal + imagVal * imagVal)
        }
        
        // 生成频率数组
        let frequencies = (0..<magnitudeCount).map { Double($0) * sampleRate / Double(fftSize) }
        
        // 找到主导频率
        let maxIndex = magnitudes.indices.max { magnitudes[$0] < magnitudes[$1] } ?? 0
        let dominantFreq = frequencies[maxIndex]
        let totalEnergy = Double(magnitudes.reduce(0, +))
        
        return FrequencySpectrum(
            timestamp: Date(),
            frequencies: frequencies,
            magnitudes: magnitudes.map { Double($0) },
            dominantFrequency: dominantFreq,
            totalEnergy: totalEnergy
        )
    }
    
    private func analyzeIssues(from spectrum: FrequencySpectrum) -> [SuspensionIssueType] {
        var issues: [SuspensionIssueType] = []
        
        // 基于频谱特征检测问题
        let dominantFreq = spectrum.dominantFrequency
        let totalEnergy = spectrum.totalEnergy
        
        // 能量阈值
        let energyThreshold: Double = 100.0
        
        // 检测减震器磨损（低频振动增加）
        let lowFreqEnergy = calculateEnergyInRange(0.5...5, from: spectrum)
        if lowFreqEnergy > energyThreshold * 0.3 {
            issues.append(.shockAbsorberWear)
        }
        
        // 检测轮胎不平衡（中高频振动）
        let midFreqEnergy = calculateEnergyInRange(10...20, from: spectrum)
        if midFreqEnergy > energyThreshold * 0.2 {
            issues.append(.tireImbalance)
        }
        
        // 检测轮毂轴承磨损（高频振动）
        let highFreqEnergy = calculateEnergyInRange(15...30, from: spectrum)
        if highFreqEnergy > energyThreshold * 0.15 {
            issues.append(.wheelBearingWear)
        }
        
        // 检测衬套磨损
        let bushingFreqEnergy = calculateEnergyInRange(5...15, from: spectrum)
        if bushingFreqEnergy > energyThreshold * 0.25 {
            issues.append(.bushingWear)
        }
        
        // 如果没有检测到问题，标记为正常
        if issues.isEmpty {
            issues.append(.normal)
        }
        
        return issues
    }
    
    private func calculateEnergyInRange(_ range: ClosedRange<Double>, from spectrum: FrequencySpectrum) -> Double {
        var energy: Double = 0
        for (index, freq) in spectrum.frequencies.enumerated() {
            if range.contains(freq) && index < spectrum.magnitudes.count {
                energy += spectrum.magnitudes[index]
            }
        }
        return energy
    }
    
    private func calculateOverallScore(issues: [SuspensionIssueType], spectrum: FrequencySpectrum) -> Int {
        var score = 100
        
        // 根据问题扣减分数
        for issue in issues {
            switch issue {
            case .normal:
                break
            case .tireImbalance:
                score -= 5
            case .bushingWear:
                score -= 10
            case .alignmentIssue:
                score -= 15
            case .springFatigue:
                score -= 15
            case .shockAbsorberWear:
                score -= 20
            case .wheelBearingWear:
                score -= 25
            }
        }
        
        // 根据总能量调整分数
        if spectrum.totalEnergy > 500 {
            score -= 10
        } else if spectrum.totalEnergy > 300 {
            score -= 5
        }
        
        return max(0, score)
    }
    
    private func statusFromScore(_ score: Int) -> SuspensionStatus {
        switch score {
        case 90...100: return .excellent
        case 75...89: return .good
        case 60...74: return .fair
        case 40...59: return .poor
        default: return .critical
        }
    }
    
}

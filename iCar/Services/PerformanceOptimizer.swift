import Foundation
import CoreML
import Accelerate
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let inferenceTime: TimeInterval
    let memoryUsage: UInt64
    let cpuUsage: Double
    let batteryLevel: Float
    let thermalState: ProcessInfo.ThermalState
}

// MARK: - Model Configuration

enum ModelConfiguration {
    case highAccuracy
    case balanced
    case lowPower
    
    var computeUnits: MLComputeUnits {
        switch self {
        case .highAccuracy:
            return .all
        case .balanced:
            return .cpuAndGPU
        case .lowPower:
            return .cpuOnly
        }
    }
    
    var allowLowPrecisionAccumulationOnGPU: Bool {
        switch self {
        case .highAccuracy:
            return false
        case .balanced, .lowPower:
            return true
        }
    }
}

// MARK: - Performance Optimizer

@MainActor
final class PerformanceOptimizer {
    
    // MARK: - Singleton
    
    static let shared = PerformanceOptimizer()
    
    // MARK: - Properties
    
    private let processInfo = ProcessInfo.processInfo
    private var currentConfiguration: ModelConfiguration = .balanced
    private var memoryWarningCount = 0
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryWarningObserver()
        setupThermalStateObserver()
    }
    
    // MARK: - Public Methods
    
    /// 获取当前性能指标
    func getCurrentMetrics() -> PerformanceMetrics {
        return PerformanceMetrics(
            inferenceTime: 0,
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage(),
            batteryLevel: UIDevice.current.batteryLevel,
            thermalState: processInfo.thermalState
        )
    }
    
    /// 根据设备状态自动选择最佳模型配置
    func getOptimalConfiguration() -> ModelConfiguration {
        let thermalState = processInfo.thermalState
        let batteryLevel = UIDevice.current.batteryLevel
        let memoryUsage = getMemoryUsage()
        let totalMemory = processInfo.physicalMemory
        
        // 内存使用超过80%时降低精度
        if Double(memoryUsage) / Double(totalMemory) > 0.8 {
            return .lowPower
        }
        
        // 根据热状态调整
        switch thermalState {
        case .critical, .serious:
            return .lowPower
        case .fair:
            return .balanced
        case .nominal:
            // 电量充足时使用高精度
            if batteryLevel > 0.3 {
                return .highAccuracy
            } else {
                return .balanced
            }
        @unknown default:
            return .balanced
        }
    }
    
    /// 配置ML模型以优化性能
    func configureModel(for configuration: ModelConfiguration = .balanced) -> MLModelConfiguration {
        let config = MLModelConfiguration()
        config.computeUnits = configuration.computeUnits
        config.allowLowPrecisionAccumulationOnGPU = configuration.allowLowPrecisionAccumulationOnGPU
        
        // 启用模型优化
        if #available(iOS 17.0, *) {
            config.setValue(true, forKey: "allowBackgroundThreading")
        }
        
        return config
    }
    
    /// 优化图像预处理
    func optimizeImagePreprocessing(image: UIImage, targetSize: CGSize) -> CVPixelBuffer? {
        // 使用vImage进行快速图像处理
        guard let cgImage = image.cgImage else { return nil }
        
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        // 使用Core Graphics进行缩放
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
    
    /// 批量处理优化
    func batchProcess<T: Sendable>(items: [T], batchSize: Int = 4, processor: @Sendable ([T]) async throws -> Void) async rethrows {
        let chunks = items.chunked(into: batchSize)
        
        for chunk in chunks {
            try await processor(chunk)
            
            // 每批处理后检查内存
            if getMemoryUsage() > getMemoryThreshold() {
                // 触发内存警告处理
                await handleMemoryPressure()
            }
            
            // 让出时间片，避免阻塞主线程
            await Task.yield()
        }
    }
    
    /// 清理缓存以释放内存
    func clearCaches() {
        // 清除URL缓存
        URLCache.shared.removeAllCachedResponses()
        
        // 清除图像缓存
        clearImageCache()
        
        // 建议系统释放内存
        #if DEBUG
        print("Caches cleared. Memory usage: \(getMemoryUsage() / 1024 / 1024) MB")
        #endif
    }
    
    /// 监控电池状态
    func isLowPowerModeEnabled() -> Bool {
        return processInfo.isLowPowerModeEnabled
    }
    
    /// 根据电池状态调整功能
    func shouldEnableFeature(powerIntensive: Bool) -> Bool {
        if isLowPowerModeEnabled() && powerIntensive {
            return false
        }
        return true
    }
    
    /// 获取推荐的采样率
    func getRecommendedSampleRate() -> Double {
        let thermalState = processInfo.thermalState
        
        switch thermalState {
        case .critical:
            return 10.0 // 最低采样率
        case .serious:
            return 25.0
        case .fair:
            return 50.0
        case .nominal:
            return 100.0 // 正常采样率
        @unknown default:
            return 50.0
        }
    }
    
    /// 异步执行耗时操作
    func performAsync<T: Sendable>(operation: @Sendable @escaping () throws -> T) async throws -> T {
        return try await Task.detached(priority: .userInitiated) {
            try operation()
        }.value
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    private func setupThermalStateObserver() {
        // 热状态变化时自动调整配置
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentConfiguration = self?.getOptimalConfiguration() ?? .balanced
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        memoryWarningCount += 1
        clearCaches()
        
        // 如果频繁收到内存警告，降低模型精度
        if memoryWarningCount > 3 {
            currentConfiguration = .lowPower
        }
    }
    
    private func handleMemoryPressure() async {
        clearCaches()
        
        // 等待一小段时间让系统回收内存
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return 0
        }
        
        return info.resident_size
    }
    
    private func getCPUUsage() -> Double {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(TASK_THREAD_TIMES_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return 0.0
        }
        
        // 简化的CPU使用率计算
        return Double(info.user_time.microseconds + info.system_time.microseconds) / 1_000_000.0
    }
    
    private func getMemoryThreshold() -> UInt64 {
        let totalMemory = processInfo.physicalMemory
        // 使用80%的内存作为阈值
        return UInt64(Double(totalMemory) * 0.8)
    }
    
    private func clearImageCache() {
        // 清除NSCache中的图像缓存
        // 这里可以添加自定义图像缓存的清理逻辑
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Optimized ML Model Wrapper

class OptimizedMLModel: @unchecked Sendable {
    private let model: MLModel
    
    @MainActor
    init?(modelURL: URL) {
        let config = PerformanceOptimizer.shared.configureModel()
        
        do {
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
        } catch {
            print("Failed to load model: \(error)")
            return nil
        }
    }
    
    func prediction(from input: MLFeatureProvider) async throws -> MLFeatureProvider {
        return try self.model.prediction(from: input)
    }
}

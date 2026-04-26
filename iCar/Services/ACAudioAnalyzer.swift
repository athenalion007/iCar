import Foundation
import AVFoundation
import Accelerate

// MARK: - AC Audio Analyzer

/// 空调系统音频分析器 - 用于分析风机和压缩机的声音
class ACAudioAnalyzer {
    
    // MARK: - Properties
    
    private let sampleRate: Double = 44100.0
    private let fftSize = 2048
    
    // MARK: - Public Methods
    
    /// 分析音频文件，提取频谱特征
    func analyzeAudio(at url: URL) async throws -> AudioAnalysisResult {
        // 加载音频数据
        let audioData = try await loadAudioData(from: url)
        
        // 执行FFT分析
        let spectrum = try performFFT(on: audioData)
        
        // 提取特征
        let features = extractFeatures(from: spectrum, audioData: audioData)
        
        return features
    }
    
    /// 实时分析音频缓冲区
    func analyzeBuffer(_ buffer: AVAudioPCMBuffer) -> AudioAnalysisResult {
        guard let channelData = buffer.floatChannelData?[0] else {
            return AudioAnalysisResult.empty
        }
        
        let frameLength = Int(buffer.frameLength)
        let data = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        do {
            let spectrum = try performFFT(on: data)
            return extractFeatures(from: spectrum, audioData: data)
        } catch {
            return AudioAnalysisResult.empty
        }
    }
    
    // MARK: - Private Methods
    
    private func loadAudioData(from url: URL) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = UInt32(file.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ACAudioError.invalidAudioFile
        }
        
        try file.read(into: buffer)
        
        guard let channelData = buffer.floatChannelData?[0] else {
            throw ACAudioError.noAudioData
        }
        
        return Array(UnsafeBufferPointer(start: channelData, count: Int(frameCount)))
    }
    
    private func performFFT(on data: [Float]) throws -> [Float] {
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw ACAudioError.fftSetupFailed
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // 准备输入数据 - 使用单精度
        var real = Array(data.prefix(fftSize))
        // 如果数据不足，补零
        if real.count < fftSize {
            real.append(contentsOf: [Float](repeating: 0.0, count: fftSize - real.count))
        }
        var imaginary = [Float](repeating: 0.0, count: fftSize)
        
        // 执行FFT - 使用单精度版本
        real.withUnsafeMutableBufferPointer { realPtr in
            imaginary.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        
        // 计算幅度谱
        var magnitudes = [Float](repeating: 0.0, count: fftSize / 2)
        for i in 0..<fftSize / 2 {
            magnitudes[i] = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
        }
        
        // 转换为dB刻度 - 使用单精度版本
        var dbValues = [Float](repeating: 0.0, count: fftSize / 2)
        var zero: Float = 0.0
        vDSP_vdbcon(magnitudes, 1, &zero, &dbValues, 1, vDSP_Length(fftSize / 2), 1)
        
        return dbValues
    }
    
    private func extractFeatures(from spectrum: [Float], audioData: [Float]) -> AudioAnalysisResult {
        // 计算总能量
        let totalEnergy = spectrum.reduce(0) { $0 + $1 }
        
        // 计算RMS
        let rms = calculateRMS(audioData)
        
        // 计算频谱质心
        let centroid = calculateSpectralCentroid(spectrum)
        
        // 计算频谱平坦度
        let flatness = calculateSpectralFlatness(spectrum)
        
        // 检测峰值频率
        let peakFrequencies = detectPeakFrequencies(in: spectrum)
        
        // 分析轴承频率 (通常 50-500 Hz)
        let bearingRange = 50...500
        let bearingEnergy = calculateEnergyInRange(spectrum, range: bearingRange)
        
        // 分析叶片通过频率 (通常 100-1000 Hz)
        let bladeRange = 100...1000
        let bladeEnergy = calculateEnergyInRange(spectrum, range: bladeRange)
        
        // 分析电机电磁噪声 (通常 1000-8000 Hz)
        let motorRange = 1000...8000
        let motorEnergy = calculateEnergyInRange(spectrum, range: motorRange)
        
        return AudioAnalysisResult(
            spectrum: spectrum.map { Double($0) },
            totalEnergy: Double(totalEnergy),
            rms: rms,
            spectralCentroid: centroid,
            spectralFlatness: flatness,
            peakFrequencies: peakFrequencies,
            bearingEnergy: bearingEnergy,
            bladeEnergy: bladeEnergy,
            motorEnergy: motorEnergy
        )
    }
    
    private func calculateRMS(_ data: [Float]) -> Double {
        var sum: Float = 0
        for sample in data {
            sum += sample * sample
        }
        return Double(sqrt(sum / Float(data.count)))
    }
    
    private func calculateSpectralCentroid(_ spectrum: [Float]) -> Double {
        var weightedSum: Double = 0
        var sum: Double = 0
        
        for (index, magnitude) in spectrum.enumerated() {
            let frequency = Double(index) * sampleRate / Double(fftSize)
            weightedSum += frequency * Double(magnitude)
            sum += Double(magnitude)
        }
        
        return sum > 0 ? weightedSum / sum : 0
    }
    
    private func calculateSpectralFlatness(_ spectrum: [Float]) -> Double {
        let logSum = spectrum.reduce(0) { $0 + log(Double($0) + 1e-10) }
        let arithmeticMean = spectrum.reduce(0) { $0 + Double($1) } / Double(spectrum.count)
        let geometricMean = exp(logSum / Double(spectrum.count))
        
        return arithmeticMean > 0 ? geometricMean / arithmeticMean : 0
    }
    
    private func detectPeakFrequencies(in spectrum: [Float]) -> [Double] {
        var peaks: [Double] = []
        let threshold: Float = spectrum.max() ?? 0 * 0.3 // 30% of max
        
        for i in 1..<spectrum.count - 1 {
            if spectrum[i] > threshold &&
               spectrum[i] > spectrum[i - 1] &&
               spectrum[i] > spectrum[i + 1] {
                let frequency = Double(i) * sampleRate / Double(fftSize)
                peaks.append(frequency)
            }
        }
        
        return peaks.sorted().prefix(10).map { $0 }
    }
    
    private func calculateEnergyInRange(_ spectrum: [Float], range: ClosedRange<Int>) -> Double {
        let startIndex = Int(Double(range.lowerBound) * Double(fftSize) / sampleRate)
        let endIndex = min(Int(Double(range.upperBound) * Double(fftSize) / sampleRate), spectrum.count)
        
        guard startIndex < endIndex else { return 0 }
        
        let rangeData = Array(spectrum[startIndex..<endIndex])
        return Double(rangeData.reduce(0) { $0 + $1 })
    }
}

// MARK: - Audio Analysis Result

struct AudioAnalysisResult {
    let spectrum: [Double]
    let totalEnergy: Double
    let rms: Double
    let spectralCentroid: Double
    let spectralFlatness: Double
    let peakFrequencies: [Double]
    let bearingEnergy: Double
    let bladeEnergy: Double
    let motorEnergy: Double
    
    static let empty = AudioAnalysisResult(
        spectrum: [],
        totalEnergy: 0,
        rms: 0,
        spectralCentroid: 0,
        spectralFlatness: 0,
        peakFrequencies: [],
        bearingEnergy: 0,
        bladeEnergy: 0,
        motorEnergy: 0
    )
}

// MARK: - Errors

enum ACAudioError: Error {
    case invalidAudioFile
    case noAudioData
    case fftSetupFailed
}

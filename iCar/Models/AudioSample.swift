import Foundation
import Accelerate

struct AudioSample {
    let samples: [Float]
    let sampleRate: Double
    let timestamp: Date
    let channelCount: Int
    
    var duration: TimeInterval {
        Double(samples.count) / sampleRate
    }
    
    var frameCount: Int {
        samples.count
    }
    
    func rms() -> Float {
        guard !samples.isEmpty else { return 0 }
        var rms: Float = 0
        vDSP_measqv(samples, 1, &rms, vDSP_Length(samples.count))
        return sqrt(rms)
    }
    
    func peak() -> Float {
        guard !samples.isEmpty else { return 0 }
        var peak: Float = 0
        var index: vDSP_Length = 0
        vDSP_maxvi(samples, 1, &peak, &index, vDSP_Length(samples.count))
        return peak
    }
    
    func zeroCrossingRate() -> Float {
        guard samples.count > 1 else { return 0 }
        var crossings: Float = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i - 1] >= 0) {
                crossings += 1
            }
        }
        return crossings / Float(samples.count - 1)
    }
    
    func fftMagnitudes(binCount: Int = 512) -> [Float] {
        let n = samples.count
        guard n > 0 else { return [Float](repeating: 0, count: binCount) }
        
        let log2n = vDSP_Length(log2(Float(n)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return [Float](repeating: 0, count: binCount)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        let halfN = n / 2
        var realPart = [Float](repeating: 0, count: halfN)
        var imagPart = [Float](repeating: 0, count: halfN)

        var windowedSamples = [Float](repeating: 0, count: n)
        var hanningWindow = [Float](repeating: 0, count: n)
        vDSP_hann_window(&hanningWindow, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, hanningWindow, 1, &windowedSamples, 1, vDSP_Length(n))

        // 使用 withUnsafeMutableBufferPointer 创建 DSPSplitComplex
        let magnitudes = realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )

                windowedSamples.withUnsafeBufferPointer { sampleBP in
                    sampleBP.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
                    }
                }

                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                var mags = [Float](repeating: 0, count: halfN)
                vDSP_zvabs(&splitComplex, 1, &mags, 1, vDSP_Length(halfN))
                return mags
            }
        }
        
        var normalizedMagnitudes = [Float](repeating: 0, count: halfN)
        var scale: Float = 1.0 / Float(n)
        vDSP_vsmul(magnitudes, 1, &scale, &normalizedMagnitudes, 1, vDSP_Length(halfN))
        
        if binCount <= halfN {
            return Array(normalizedMagnitudes.prefix(binCount))
        } else {
            return normalizedMagnitudes + [Float](repeating: 0, count: binCount - halfN)
        }
    }
    
    func frequencyBin(for index: Int, totalBins: Int) -> Double {
        Double(index) * sampleRate / (2.0 * Double(totalBins))
    }
}

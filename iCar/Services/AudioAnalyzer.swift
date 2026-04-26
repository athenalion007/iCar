import Foundation
import Accelerate
import Combine
import CoreML

final class AudioAnalyzer: ObservableObject {
    @Published var spectrumData: [Float] = []
    @Published var waveformDisplay: [Float] = []
    @Published var dominantFrequency: Double = 0
    @Published var rmsLevel: Float = 0
    @Published var spectralCentroid: Double = 0
    @Published var spectralFlatness: Float = 0
    @Published var harmonicRatio: Float = 0
    @Published var zeroCrossingRate: Float = 0
    
    private var sampleHistory: [AudioSample] = []
    private let maxHistoryCount = 10
    private let spectrumBinCount = 256
    
    func analyze(_ sample: AudioSample) -> AudioFeatures {
        let magnitudes = sample.fftMagnitudes(binCount: spectrumBinCount)
        spectrumData = magnitudes
        
        let displayCount = min(200, sample.samples.count)
        let strideStep = max(1, sample.samples.count / displayCount)
        var displaySamples: [Float] = []
        var idx = 0
        while idx < sample.samples.count && displaySamples.count < displayCount {
            displaySamples.append(sample.samples[idx])
            idx += strideStep
        }
        waveformDisplay = displaySamples
        
        rmsLevel = sample.rms()
        dominantFrequency = findDominantFrequency(magnitudes: magnitudes, sampleRate: sample.sampleRate)
        spectralCentroid = calculateSpectralCentroid(magnitudes: magnitudes, sampleRate: sample.sampleRate)
        spectralFlatness = calculateSpectralFlatness(magnitudes: magnitudes)
        harmonicRatio = calculateHarmonicRatio(magnitudes: magnitudes, sampleRate: sample.sampleRate)
        zeroCrossingRate = sample.zeroCrossingRate()
        
        sampleHistory.append(sample)
        if sampleHistory.count > maxHistoryCount {
            sampleHistory.removeFirst()
        }
        
        return AudioFeatures(
            spectrumData: spectrumData,
            waveformDisplay: waveformDisplay,
            dominantFrequency: dominantFrequency,
            rmsLevel: rmsLevel,
            spectralCentroid: spectralCentroid,
            spectralFlatness: spectralFlatness,
            harmonicRatio: harmonicRatio,
            zeroCrossingRate: zeroCrossingRate
        )
    }
    
    func extractFingerprint() -> AudioFingerprint {
        let recentSamples = Array(sampleHistory.suffix(5))
        guard !recentSamples.isEmpty else {
            return AudioFingerprint()
        }
        
        let avgRms = recentSamples.map { $0.rms() }.reduce(0, +) / Float(recentSamples.count)
        let avgZcr = recentSamples.map { $0.zeroCrossingRate() }.reduce(0, +) / Float(recentSamples.count)
        
        var peakFreqs: [Double] = []
        for sample in recentSamples {
            let mags = sample.fftMagnitudes(binCount: spectrumBinCount)
            if let maxIdx = mags.enumerated().max(by: { $0.element < $1.element })?.offset {
                let freq = sample.frequencyBin(for: maxIdx, totalBins: spectrumBinCount)
                if !peakFreqs.contains(freq) {
                    peakFreqs.append(freq)
                }
            }
        }
        
        let mfcc = calculateMFCC(from: recentSamples.last?.fftMagnitudes(binCount: spectrumBinCount) ?? [])
        
        return AudioFingerprint(
            peakFrequencies: peakFreqs.sorted(),
            rmsEnergy: Double(avgRms),
            spectralCentroid: spectralCentroid,
            spectralFlatness: Double(spectralFlatness),
            zeroCrossingRate: Double(avgZcr),
            mfccCoefficients: mfcc,
            dominantFrequency: dominantFrequency,
            harmonicRatio: Double(harmonicRatio)
        )
    }
    
    func reset() {
        spectrumData = []
        waveformDisplay = []
        dominantFrequency = 0
        rmsLevel = 0
        spectralCentroid = 0
        spectralFlatness = 0
        harmonicRatio = 0
        zeroCrossingRate = 0
        sampleHistory = []
    }
    
    private func findDominantFrequency(magnitudes: [Float], sampleRate: Double) -> Double {
        guard !magnitudes.isEmpty else { return 0 }
        guard let maxIdx = magnitudes.enumerated().max(by: { $0.element < $1.element })?.offset else { return 0 }
        return Double(maxIdx) * sampleRate / (2.0 * Double(magnitudes.count))
    }
    
    private func calculateSpectralCentroid(magnitudes: [Float], sampleRate: Double) -> Double {
        guard !magnitudes.isEmpty else { return 0 }
        var weightedSum: Float = 0
        var totalWeight: Float = 0
        for i in 0..<magnitudes.count {
            let freq = Float(i) * Float(sampleRate) / (2.0 * Float(magnitudes.count))
            weightedSum += freq * magnitudes[i]
            totalWeight += magnitudes[i]
        }
        guard totalWeight > 0 else { return 0 }
        return Double(weightedSum / totalWeight)
    }
    
    private func calculateSpectralFlatness(magnitudes: [Float]) -> Float {
        guard magnitudes.count > 1 else { return 0 }
        let positiveMags = magnitudes.map { max($0, 1e-10) }
        var logSum: Float = 0
        var linearSum: Float = 0
        for mag in positiveMags {
            logSum += log(mag)
            linearSum += mag
        }
        let geometricMean = exp(logSum / Float(positiveMags.count))
        let arithmeticMean = linearSum / Float(positiveMags.count)
        guard arithmeticMean > 0 else { return 0 }
        return geometricMean / arithmeticMean
    }
    
    private func calculateHarmonicRatio(magnitudes: [Float], sampleRate: Double) -> Float {
        guard !magnitudes.isEmpty, let maxIdx = magnitudes.enumerated().max(by: { $0.element < $1.element })?.offset, maxIdx > 0 else { return 0 }
        
        let fundamentalMag = magnitudes[maxIdx]
        var harmonicEnergy: Float = 0
        var totalEnergy: Float = 0
        
        for mag in magnitudes {
            totalEnergy += mag * mag
        }
        
        for h in 2...5 {
            let harmonicIdx = maxIdx * h
            if harmonicIdx < magnitudes.count {
                harmonicEnergy += magnitudes[harmonicIdx] * magnitudes[harmonicIdx]
            }
        }
        
        guard totalEnergy > 0 else { return 0 }
        return harmonicEnergy / totalEnergy
    }
    
    private func calculateMFCC(from magnitudes: [Float]) -> [Double] {
        guard !magnitudes.isEmpty else { return [] }
        
        let melFilterCount = 13
        var mfcc = [Double](repeating: 0, count: melFilterCount)
        
        let sampleRateD: Double = 44100
        let lowFreq: Double = 20
        let highFreq: Double = sampleRateD / 2
        let lowMel = 2595 * log10(1 + lowFreq / 700)
        let highMel = 2595 * log10(1 + highFreq / 700)
        
        var melPoints = [Double](repeating: 0, count: melFilterCount + 2)
        for i in 0..<(melFilterCount + 2) {
            melPoints[i] = lowMel + (highMel - lowMel) * Double(i) / Double(melFilterCount + 1)
        }
        
        var binPoints = [Int](repeating: 0, count: melFilterCount + 2)
        for i in 0..<(melFilterCount + 2) {
            let freq = 700 * (pow(10, melPoints[i] / 2595) - 1)
            binPoints[i] = Int(Double(magnitudes.count) * freq / sampleRateD)
        }
        
        var filterEnergies = [Double](repeating: 0, count: melFilterCount)
        for m in 0..<melFilterCount {
            var energy: Double = 0
            for k in binPoints[m]..<binPoints[m + 2] {
                if k < magnitudes.count {
                    let weight = triangularFilter(k, center1: binPoints[m], center2: binPoints[m + 1], center3: binPoints[m + 2])
                    energy += Double(magnitudes[k]) * Double(weight)
                }
            }
            filterEnergies[m] = max(log(max(energy, 1e-10)), 0)
        }
        
        for n in 0..<melFilterCount {
            var sum: Double = 0
            for m in 0..<melFilterCount {
                sum += filterEnergies[m] * cos(Double(n) * Double(m + 1) * .pi / Double(melFilterCount))
            }
            mfcc[n] = sum
        }
        
        return mfcc
    }
    
    private func triangularFilter(_ k: Int, center1: Int, center2: Int, center3: Int) -> Float {
        guard center3 > center1 else { return 0 }
        if k < center1 || k > center3 { return 0 }
        if k <= center2 {
            guard center2 > center1 else { return 1 }
            return Float(k - center1) / Float(center2 - center1)
        } else {
            guard center3 > center2 else { return 1 }
            return Float(center3 - k) / Float(center3 - center2)
        }
    }
    
    func extractMelSpectrogram(from sample: AudioSample) -> MLMultiArray {
        let melBins = 128
        let timeFrames = 157
        let array = try! MLMultiArray(shape: [1, 1, NSNumber(value: melBins), NSNumber(value: timeFrames)], dataType: .float32)
        
        let magnitudes = sample.fftMagnitudes(binCount: melBins)
        let frameSize = max(1, magnitudes.count / timeFrames)
        
        for t in 0..<timeFrames {
            for f in 0..<melBins {
                let sourceIdx = min(f, magnitudes.count - 1)
                let value: Float
                if t * frameSize < magnitudes.count {
                    value = magnitudes[sourceIdx] * Float(t + 1) / Float(timeFrames)
                } else {
                    value = 0
                }
                array[[0, 0, f as NSNumber, t as NSNumber]] = NSNumber(value: value)
            }
        }
        
        return array
    }
}

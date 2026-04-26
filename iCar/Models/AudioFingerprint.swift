import Foundation

struct AudioFingerprint: Codable, Hashable {
    let peakFrequencies: [Double]
    let rmsEnergy: Double
    let spectralCentroid: Double
    let spectralFlatness: Double
    let zeroCrossingRate: Double
    let mfccCoefficients: [Double]
    let dominantFrequency: Double
    let harmonicRatio: Double
    
    init(
        peakFrequencies: [Double] = [],
        rmsEnergy: Double = 0,
        spectralCentroid: Double = 0,
        spectralFlatness: Double = 0,
        zeroCrossingRate: Double = 0,
        mfccCoefficients: [Double] = [],
        dominantFrequency: Double = 0,
        harmonicRatio: Double = 0
    ) {
        self.peakFrequencies = peakFrequencies
        self.rmsEnergy = rmsEnergy
        self.spectralCentroid = spectralCentroid
        self.spectralFlatness = spectralFlatness
        self.zeroCrossingRate = zeroCrossingRate
        self.mfccCoefficients = mfccCoefficients
        self.dominantFrequency = dominantFrequency
        self.harmonicRatio = harmonicRatio
    }
}

struct AudioFeatures {
    let spectrumData: [Float]
    let waveformDisplay: [Float]
    let dominantFrequency: Double
    let rmsLevel: Float
    let spectralCentroid: Double
    let spectralFlatness: Float
    let harmonicRatio: Float
    let zeroCrossingRate: Float
    
    init(
        spectrumData: [Float] = [],
        waveformDisplay: [Float] = [],
        dominantFrequency: Double = 0,
        rmsLevel: Float = 0,
        spectralCentroid: Double = 0,
        spectralFlatness: Float = 0,
        harmonicRatio: Float = 0,
        zeroCrossingRate: Float = 0
    ) {
        self.spectrumData = spectrumData
        self.waveformDisplay = waveformDisplay
        self.dominantFrequency = dominantFrequency
        self.rmsLevel = rmsLevel
        self.spectralCentroid = spectralCentroid
        self.spectralFlatness = spectralFlatness
        self.harmonicRatio = harmonicRatio
        self.zeroCrossingRate = zeroCrossingRate
    }
}

import SwiftUI

// MARK: - Spectrum View

struct SpectrumView: View {
    let spectrumData: SpectrumData
    let faultType: EngineFaultType?
    
    @State private var animationProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // 频谱图标题
            headerSection
            
            // 频谱图
            spectrumChart
            
            // 频谱分析信息
            spectrumInfoSection
            
            // 频率范围标注
            frequencyLegend
        }
        .padding(20)
        .background(.gray)
        .cornerRadius(12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("频谱分析")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("主导频率: \(String(format: "%.0f", spectrumData.dominantFrequency)) Hz")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if let fault = faultType {
                HStack(spacing: 4) {
                    Image(systemName: fault.icon)
                        .font(.system(size: 12))
                    Text(fault.rawValue)
                        .font(.caption)
                }
                .foregroundColor(Color(hex: fault.color))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: fault.color).opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Spectrum Chart
    
    private var spectrumChart: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景网格
                gridLines(in: geometry)
                
                // 频谱柱状图
                spectrumBars(in: geometry)
                
                // 故障类型频率范围标记
                if let fault = faultType {
                    frequencyRangeIndicator(for: fault, in: geometry)
                }
            }
        }
        .frame(height: 180)
    }
    
    // MARK: - Grid Lines
    
    private func gridLines(in geometry: GeometryProxy) -> some View {
        ZStack {
            // 水平网格线
            VStack(spacing: 0) {
                ForEach(0..<5) { i in
                    HStack {
                        Text("\(80 - i * 20)")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                            .frame(width: 20, alignment: .trailing)
                        
                        Rectangle()
                            .fill(.gray)
                            .frame(height: 0.5)
                    }
                    
                    if i < 4 {
                        Spacer()
                    }
                }
            }
            
            // 垂直网格线
            HStack {
                ForEach(0..<6) { i in
                    if i > 0 {
                        Rectangle()
                            .fill(.gray)
                            .frame(width: 0.5)
                    }
                    
                    if i < 5 {
                        Spacer()
                    }
                }
            }
            .padding(.leading, 24)
        }
    }
    
    // MARK: - Spectrum Bars
    
    private func spectrumBars(in geometry: GeometryProxy) -> some View {
        let chartWidth = geometry.size.width - 30
        let chartHeight = geometry.size.height
        
        // 降采样显示，避免柱状图过密
        let displayCount = 60
        let step = max(1, spectrumData.frequencies.count / displayCount)
        
        let validCount = min(displayCount, spectrumData.frequencies.count / step)
        
        return HStack(spacing: 1) {
            ForEach(0..<validCount, id: \.self) { index in
                self.barView(at: index, step: step, chartHeight: chartHeight, chartWidth: chartWidth, displayCount: displayCount)
            }
        }
        .padding(.leading, 30)
    }
    
    private func barView(at index: Int, step: Int, chartHeight: CGFloat, chartWidth: CGFloat, displayCount: Int) -> some View {
        let dataIndex = index * step
        guard dataIndex < spectrumData.magnitudes.count else {
            return AnyView(Color.clear)
        }
        
        let magnitude = spectrumData.magnitudes[dataIndex]
        let normalizedHeight = normalizeMagnitude(magnitude)
        let barHeight = chartHeight * normalizedHeight * animationProgress
        let barWidth = (chartWidth - CGFloat(displayCount)) / CGFloat(displayCount)
        
        return AnyView(
            RoundedRectangle(cornerRadius: 1)
                .fill(barColor(for: magnitude))
                .frame(width: barWidth, height: barHeight)
                .frame(maxHeight: .infinity, alignment: .bottom)
        )
    }
    
    // MARK: - Frequency Range Indicator
    
    private func frequencyRangeIndicator(for fault: EngineFaultType, in geometry: GeometryProxy) -> some View {
        let chartWidth = geometry.size.width - 30
        let range = fault.frequencyRange
        let maxFreq = spectrumData.frequencies.last ?? 8000
        
        let lowerBound = range.lowerBound
        let upperBound = range.upperBound
        let startX = CGFloat(lowerBound / maxFreq) * chartWidth
        let rangeWidth = upperBound - lowerBound
        let width = CGFloat(rangeWidth / maxFreq) * chartWidth
        let centerX = startX + width / 2 + 30
        let centerY = geometry.size.height / 2
        let height = geometry.size.height
        let faultColor = Color(hex: fault.color)
        
        return Rectangle()
            .fill(faultColor.opacity(0.15))
            .frame(width: width, height: height)
            .position(x: centerX, y: centerY)
            .overlay(
                Rectangle()
                    .stroke(faultColor.opacity(0.3), lineWidth: 1)
                    .frame(width: width, height: height)
                    .position(x: centerX, y: centerY)
            )
    }
    
    // MARK: - Spectrum Info Section
    
    private var spectrumInfoSection: some View {
        HStack(spacing: 24) {
            SpectrumInfoItem(
                title: "低频能量",
                value: String(format: "%.1f", calculateEnergyPercentage(in: 50...500)),
                unit: "%",
                color: .green
            )
            
            SpectrumInfoItem(
                title: "中频能量",
                value: String(format: "%.1f", calculateEnergyPercentage(in: 500...2000)),
                unit: "%",
                color: .orange
            )
            
            SpectrumInfoItem(
                title: "高频能量",
                value: String(format: "%.1f", calculateEnergyPercentage(in: 2000...8000)),
                unit: "%",
                color: .red
            )
        }
    }
    
    // MARK: - Frequency Legend
    
    private var frequencyLegend: some View {
        HStack {
            Text("0 Hz")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("2k")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("4k")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("6k")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("8k Hz")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(.leading, 30)
    }
    
    // MARK: - Helper Methods
    
    private func normalizeMagnitude(_ magnitude: Double) -> CGFloat {
        // 将dB值归一化到0-1范围 (假设范围 -80dB 到 0dB)
        let minDb: Double = -80
        let maxDb: Double = 0
        let normalized = (magnitude - minDb) / (maxDb - minDb)
        return CGFloat(max(0, min(1, normalized)))
    }
    
    private func barColor(for magnitude: Double) -> Color {
        let normalized = normalizeMagnitude(magnitude)
        
        if normalized > 0.7 {
            return .red
        } else if normalized > 0.4 {
            return .orange
        } else {
            return .blue
        }
    }
    
    private func calculateEnergyPercentage(in range: ClosedRange<Double>) -> Double {
        let rangeEnergy = spectrumData.energyInRange(range)
        let totalEnergy = spectrumData.totalEnergy
        guard totalEnergy > 0 else { return 0 }
        return (rangeEnergy / totalEnergy) * 100
    }
}

// MARK: - Spectrum Info Item

struct SpectrumInfoItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(color.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Real-time Spectrum View

struct RealtimeSpectrumView: View {
    let levels: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<min(levels.count, 32), id: \.self) { index in
                    let level = normalizedLevel(for: index)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: level))
                        .frame(width: (geometry.size.width - 62) / 32, height: geometry.size.height * level)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func normalizedLevel(for index: Int) -> CGFloat {
        guard index < levels.count else { return 0.05 }
        let level = levels[index]
        let normalized = (level + 60) / 60
        return CGFloat(max(0.05, min(1.0, normalized)))
    }
    
    private func barColor(for level: CGFloat) -> Color {
        if level > 0.8 {
            return .red
        } else if level > 0.5 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Frequency Band Indicator

struct FrequencyBandIndicator: View {
    let frequency: Double
    let magnitude: Double
    let isHighlighted: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // 频率值
            Text(formatFrequency(frequency))
                .font(.caption)
                .foregroundColor(isHighlighted ? .blue : .gray)
            
            // 幅度条
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isHighlighted ? .blue : .gray)
                    .frame(height: geometry.size.height * normalizedMagnitude)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: 30)
            
            // 幅度值
            Text("\(Int(magnitude))dB")
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
    }
    
    private var normalizedMagnitude: CGFloat {
        let minDb: Double = -80
        let maxDb: Double = 0
        let normalized = (magnitude - minDb) / (maxDb - minDb)
        return CGFloat(max(0.1, min(1, normalized)))
    }
    
    private func formatFrequency(_ freq: Double) -> String {
        if freq >= 1000 {
            return String(format: "%.1fk", freq / 1000)
        } else {
            return String(format: "%.0f", freq)
        }
    }
}

// MARK: - Preview

#Preview("Spectrum View") {
    let sampleFrequencies = Array(stride(from: 0.0, to: 8000.0, by: 10.0))
    let sampleMagnitudes = sampleFrequencies.map { freq in
        let baseNoise = -60.0
        let peak1 = -20 * exp(-pow(freq - 800, 2) / 10000)
        let peak2 = -15 * exp(-pow(freq - 2000, 2) / 50000)
        return baseNoise + peak1 + peak2
    }
    
    let sampleSpectrum = SpectrumData(
        frequencies: sampleFrequencies,
        magnitudes: sampleMagnitudes,
        sampleRate: 44100
    )
    
    ScrollView {
        VStack(spacing: 32) {
            SpectrumView(
                spectrumData: sampleSpectrum,
                faultType: .valveNoise
            )
            
            SpectrumView(
                spectrumData: sampleSpectrum,
                faultType: .normal
            )
        }
        .padding()
    }
}

#Preview("Realtime Spectrum") {
    RealtimeSpectrumView(levels: Array(repeating: -30, count: 32))
        .frame(height: 100)
        .padding()
}

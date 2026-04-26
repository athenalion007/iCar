import SwiftUI

// MARK: - Engine Ear Result View

struct EngineEarResultView: View {
    let result: EngineDiagnosisResult
    let onSave: () -> Void
    let onRetest: () -> Void
    let onShare: () -> Void
    
    @State private var showSpectrumDetail = false
    @State private var showSaveConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 诊断结果卡片
                diagnosisCard
                
                // 频谱分析
                SpectrumView(
                    spectrumData: result.spectrumData,
                    faultType: result.faultType
                )
                
                // 故障详情
                if !result.isNormal {
                    faultDetailCard
                }
                
                // 建议操作
                recommendationCard
                
                // 操作按钮
                actionButtons
            }
            .padding(20)
        }
        .background(Color.black)
        .alert("保存成功", isPresented: $showSaveConfirmation) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("诊断报告已保存到历史记录")
        }
    }
    
    // MARK: - Diagnosis Card
    
    private var diagnosisCard: some View {
        VStack(spacing: 24) {
            // 结果图标和状态
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(Color(hex: result.severity.color).opacity(0.2), lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: CGFloat(result.severity.score) / 100)
                    .stroke(
                        Color(hex: result.severity.color),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                // 中心内容
                VStack(spacing: 4) {
                    Image(systemName: result.faultType.icon)
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: result.faultType.color))
                    
                    Text(result.severity.rawValue)
                        .font(.caption)
                        .foregroundColor(Color(hex: result.severity.color))
                }
            }
            
            // 故障类型
            VStack(spacing: 8) {
                Text(result.faultType.rawValue)
                    .font(.title)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12))
                    Text("AI置信度: \(result.formattedConfidence)")
                        .font(.subheadline)
                }
                .foregroundColor(.gray)
            }
            
            // 时间戳
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text(formatDate(result.timestamp))
                    .font(.caption)
            }
            .foregroundColor(.gray)
        }
        .padding(32)
        .background(Color.gray.opacity(0.2))
        .cardStyle()
    }
    
    // MARK: - Fault Detail Card
    
    private var faultDetailCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: result.faultType.color))
                
                Text("故障详情")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                DetailRow(
                    icon: "doc.text",
                    title: "故障描述",
                    content: result.faultType.description
                )
                
                DetailRow(
                    icon: "waveform",
                    title: "特征频率",
                    content: "\(Int(result.faultType.frequencyRange.lowerBound))-\(Int(result.faultType.frequencyRange.upperBound)) Hz"
                )
                
                if let cost = result.estimatedRepairCost {
                    DetailRow(
                        icon: "yensign.circle",
                        title: "预估维修费用",
                        content: "¥\(String(format: "%.0f", cost))"
                    )
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.2))
        .cardStyle()
    }
    
    // MARK: - Recommendation Card
    
    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("建议操作")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(result.recommendedAction)
                    .font(.body)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            
            // 严重程度提示
            if result.severity == .severe {
                HStack(spacing: 16) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                    
                    Text("检测到严重故障，建议立即停车检查，避免造成更大损失")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.red.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // 保存按钮
                ActionButton(
                    icon: "square.and.arrow.down",
                    title: "保存",
                    color: .blue
                ) {
                    onSave()
                    showSaveConfirmation = true
                }
                
                // 分享按钮
                ActionButton(
                    icon: "square.and.arrow.up",
                    title: "分享",
                    color: .gray
                ) {
                    onShare()
                }
                
                // 重新测试按钮
                ActionButton(
                    icon: "arrow.counterclockwise",
                    title: "重测",
                    color: .green
                ) {
                    onRetest()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(content)
                    .font(.body)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(color.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = false
            }
        }
    }
}

// MARK: - Analysis Progress View

struct AnalysisProgressView: View {
    let progress: Double
    let currentStep: String
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // AI分析动画
                ZStack {
                    // 外圈
                    Circle()
                        .stroke(.blue.opacity(0.2), lineWidth: 4)
                        .frame(width: 100, height: 100)
                    
                    // 旋转圈
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(rotation))
                    
                    // 中心图标
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 16) {
                    Text("AI分析中...")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text(currentStep)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                    
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.blue)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                        }
                    }
                    .frame(width: 200, height: 6)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Diagnosis History Row

struct DiagnosisHistoryRow: View {
    let result: EngineDiagnosisResult
    
    var body: some View {
        HStack(spacing: 16) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(Color(hex: result.faultType.color).opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: result.faultType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: result.faultType.color))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.faultType.rawValue)
                    .font(.body)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(formatDate(result.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("置信度 \(result.formattedConfidence)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // 严重程度
            HStack(spacing: 4) {
                Image(systemName: result.severity.icon)
                    .font(.system(size: 12))
                Text(result.severity.rawValue)
                    .font(.caption2)
            }
            .foregroundColor(Color(hex: result.severity.color))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: result.severity.color).opacity(0.1))
            .cornerRadius(4)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.gray.opacity(0.2))
        .cardStyle()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Engine Ear Result - Normal") {
    let sampleSpectrum = SpectrumData(
        frequencies: Array(stride(from: 0.0, to: 8000.0, by: 10.0)),
        magnitudes: Array(repeating: -50.0, count: 800),
        sampleRate: 44100
    )
    
    let normalResult = EngineDiagnosisResult(
        faultType: .normal,
        confidence: 0.95,
        severity: .normal,
        spectrumData: sampleSpectrum,
        audioFingerprint: AudioFingerprint(),
        recommendedAction: "发动机状况良好，建议继续保持定期保养"
    )
    
    EngineEarResultView(
        result: normalResult,
        onSave: {},
        onRetest: {},
        onShare: {}
    )
}

#Preview("Engine Ear Result - Fault") {
    let sampleSpectrum = SpectrumData(
        frequencies: Array(stride(from: 0.0, to: 8000.0, by: 10.0)),
        magnitudes: Array(repeating: -40.0, count: 800),
        sampleRate: 44100
    )
    
    let faultResult = EngineDiagnosisResult(
        faultType: .knocking,
        confidence: 0.87,
        severity: .severe,
        spectrumData: sampleSpectrum,
        audioFingerprint: AudioFingerprint(),
        recommendedAction: "建议立即停车检查，更换高标号燃油，检查点火系统",
        estimatedRepairCost: 2500
    )
    
    EngineEarResultView(
        result: faultResult,
        onSave: {},
        onRetest: {},
        onShare: {}
    )
}

#Preview("Analysis Progress") {
    AnalysisProgressView(progress: 0.65, currentStep: "特征提取")
}

#Preview("Diagnosis History Row") {
    let sampleSpectrum = SpectrumData(
        frequencies: [],
        magnitudes: [],
        sampleRate: 44100
    )
    
    let result = EngineDiagnosisResult(
        faultType: .beltNoise,
        confidence: 0.82,
        severity: .moderate,
        spectrumData: sampleSpectrum,
        audioFingerprint: AudioFingerprint(),
        recommendedAction: "建议检查皮带张紧度"
    )
    
    DiagnosisHistoryRow(result: result)
        .padding()
}

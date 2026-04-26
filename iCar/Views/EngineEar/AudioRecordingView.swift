import SwiftUI
import AVFoundation

// MARK: - Audio Recording View

struct AudioRecordingView: View {
    
    // MARK: - Properties
    
    @StateObject private var recordingService = AudioRecordingService.shared
    @State private var showPermissionAlert = false
    @State private var pulseAnimation = false
    
    let onRecordingComplete: (URL) -> Void
    let onCancel: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 32) {
            // 顶部标题
            headerSection
            
            Spacer()
            
            // 录音可视化区域
            waveformSection
            
            Spacer()
            
            // 录音引导
            guideSection
            
            Spacer()
            
            // 控制按钮
            controlSection
        }
        .padding(20)
        .background(Color.black)
        .onAppear {
            recordingService.checkMicrophonePermission()
        }
        .alert("需要麦克风权限", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在设置中允许iCar访问麦克风，以进行发动机异响诊断")
        }
        .onChange(of: recordingService.state) { newState in
            if case .completed(let url) = newState {
                onRecordingComplete(url)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("发动机异响诊断")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 占位保持居中
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.clear)
            }
            
            Text("将手机靠近发动机，录制12秒音频")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Waveform Section
    
    private var waveformSection: some View {
        VStack(spacing: 24) {
            // 录音状态指示器
            recordingStatusIndicator
            
            // 波形可视化
            AudioWaveformView(
                levels: recordingService.audioLevels,
                isRecording: isRecording
            )
            .frame(height: 120)
            
            // 倒计时
            if case .recording(_, let timeRemaining) = recordingService.state {
                Text("\(timeRemaining)秒")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .monospacedDigit()
            } else {
                Text("准备录音")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Recording Status Indicator
    
    private var recordingStatusIndicator: some View {
        HStack(spacing: 16) {
            // 录音指示点
            if isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(pulseAnimation ? 1.0 : 0.3)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                    }
                    .onDisappear {
                        pulseAnimation = false
                    }
            }
            
            // 音质指示
            if let metrics = recordingService.currentMetrics {
                HStack(spacing: 4) {
                    Image(systemName: metrics.isQualityAcceptable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(Color(hex: metrics.qualityColor))
                    
                    Text(metrics.qualityDescription)
                        .font(.caption)
                        .foregroundColor(Color(hex: metrics.qualityColor))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: metrics.qualityColor).opacity(0.1))
                .cornerRadius(8)
            }
        }
        .frame(height: 30)
    }
    
    // MARK: - Guide Section
    
    private var guideSection: some View {
        VStack(spacing: 24) {
            // RPM 提示
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发动机转速")
                            .font(.body)
                            .foregroundColor(.white)
                        
                        Text("保持怠速状态 (700-1000 RPM)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                // RPM 指示条
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < 2 ? .green : .gray)
                            .frame(height: 8)
                    }
                }
            }
            .padding(20)
            .background(.gray)
            .cornerRadius(12)
            
            // 录音提示
            VStack(alignment: .leading, spacing: 16) {
                GuideRow(
                    icon: "mic.fill",
                    title: "保持安静",
                    description: "录音时请关闭车内音响，避免交谈"
                )
                
                GuideRow(
                    icon: "arrow.down.circle.fill",
                    title: "靠近声源",
                    description: "将手机麦克风靠近发动机舱，距离约30-50cm"
                )
                
                GuideRow(
                    icon: "hand.raised.fill",
                    title: "保持稳定",
                    description: "录音过程中请保持手机稳定，不要移动"
                )
            }
        }
    }
    
    // MARK: - Control Section
    
    private var controlSection: some View {
        VStack(spacing: 16) {
            if case .recording = recordingService.state {
                // 录音中显示取消按钮
                Button(action: {
                    recordingService.cancelRecording()
                }) {
                    Text("取消录音")
                        .font(.body)
                        .foregroundColor(.red)
                        .padding(.vertical, 16)
                }
            } else {
                // 录音按钮
                RecordButton(
                    isRecording: isRecording,
                    action: {
                        handleRecordButtonTap()
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var isRecording: Bool {
        if case .recording = recordingService.state {
            return true
        }
        return false
    }
    
    private func handleRecordButtonTap() {
        if recordingService.hasMicrophonePermission {
            Task {
                do {
                    try await recordingService.startRecording()
                } catch RecordingError.permissionDenied {
                    showPermissionAlert = true
                } catch {
                    print("录音启动失败: \(error)")
                }
            }
        } else {
            showPermissionAlert = true
        }
    }
}

// MARK: - Audio Waveform View

struct AudioWaveformView: View {
    let levels: [Float]
    let isRecording: Bool
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 3) {
                ForEach(0..<min(levels.count, 50), id: \.self) { index in
                    WaveformBar(
                        level: normalizedLevel(for: index),
                        isRecording: isRecording
                    )
                    .frame(width: (geometry.size.width - 147) / 50)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func normalizedLevel(for index: Int) -> CGFloat {
        guard index < levels.count else { return 0.1 }
        let level = levels[index]
        // 将 dB 转换为 0-1 范围
        let normalized = (level + 60) / 60
        return CGFloat(max(0.1, min(1.0, normalized)))
    }
}

// MARK: - Waveform Bar

struct WaveformBar: View {
    let level: CGFloat
    let isRecording: Bool
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(height: geometry.size.height * level)
                .frame(maxHeight: .infinity, alignment: .center)
        }
    }
    
    private var barColor: Color {
        if !isRecording {
            return .gray
        }
        if level > 0.7 {
            return .red
        } else if level > 0.4 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 外圈
                Circle()
                    .stroke(.blue.opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                // 内圈
                Circle()
                    .fill(.blue)
                    .frame(width: 80, height: 80)
                
                // 图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }
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

// MARK: - Guide Row

struct GuideRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Audio Recording") {
    AudioRecordingView { url in
        print("Recording completed: \(url)")
    } onCancel: {
        print("Cancelled")
    }
}

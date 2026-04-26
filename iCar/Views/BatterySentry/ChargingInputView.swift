import SwiftUI

// MARK: - Charging Input View

struct ChargingInputView: View {
    
    // MARK: - Properties
    
    @ObservedObject var service: BatteryMonitorService
    let onComplete: () -> Void
    
    @State private var voltage: String = ""
    @State private var current: String = ""
    @State private var duration: String = ""
    @State private var selectedPattern: ChargingPattern = .normal
    @State private var location: String = ""
    @State private var showResult = false
    @State private var diagnosisResult: BatteryDiagnosisResult?
    @State private var inputErrorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    
    private var isValidInput: Bool {
        !voltage.isEmpty && !current.isEmpty && !duration.isEmpty && !location.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 错误提示
                if let error = inputErrorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 标题
                headerSection
                
                // 充电参数输入
                chargingParametersSection
                
                // 充电模式选择
                chargingPatternSection
                
                // 位置输入
                locationSection
                
                // 提交按钮
                submitButton
            }
            .padding(20)
        }
        .background(.black)
        .navigationTitle("记录充电")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showResult) {
            if let result = diagnosisResult {
                ChargingResultSheet(result: result, onComplete: onComplete)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bolt.car.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            Text("记录充电数据")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("输入充电参数以评估电池健康状况")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Charging Parameters Section
    
    private var chargingParametersSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("充电参数")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                // 电压输入
                InputField(
                    icon: "bolt.fill",
                    title: "充电电压",
                    placeholder: "13.8",
                    unit: "V",
                    text: $voltage,
                    keyboardType: .decimalPad
                )
                
                Divider()
                
                // 电流输入
                InputField(
                    icon: "arrow.down.circle.fill",
                    title: "充电电流",
                    placeholder: "5.0",
                    unit: "A",
                    text: $current,
                    keyboardType: .decimalPad
                )
                
                Divider()
                
                // 时长输入
                InputField(
                    icon: "clock.fill",
                    title: "充电时长",
                    placeholder: "2.5",
                    unit: "小时",
                    text: $duration,
                    keyboardType: .decimalPad
                )
            }
            .padding(16)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Charging Pattern Section
    
    private var chargingPatternSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("充电模式")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                ForEach(ChargingPattern.allCases, id: \.self) { pattern in
                    PatternSelectionRow(
                        pattern: pattern,
                        isSelected: selectedPattern == pattern
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPattern = pattern
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("充电地点")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                TextField("例如：家里、公司、充电站", text: $location)
                    .font(.body)
                    .padding(16)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                // 快捷选择
                HStack(spacing: 16) {
                    QuickLocationButton(title: "家里", icon: "house.fill") {
                        location = "家里"
                    }
                    
                    QuickLocationButton(title: "公司", icon: "building.2.fill") {
                        location = "公司"
                    }
                    
                    QuickLocationButton(title: "充电站", icon: "bolt.fill") {
                        location = "充电站"
                    }
                    
                    QuickLocationButton(title: "其他", icon: "mappin.and.ellipse") {
                        location = "其他"
                    }
                }
            }
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        ICButton(
            title: "提交分析",
            icon: "checkmark.circle.fill",
            style: .primary,
            size: .large
        ) {
            submitChargingData()
        }
    }
    
    // MARK: - Helper Methods
    
    private func submitChargingData() {
        inputErrorMessage = nil
        
        guard !voltage.isEmpty, !current.isEmpty, !duration.isEmpty, !location.isEmpty else {
            inputErrorMessage = "请填写所有必填字段"
            return
        }
        
        guard let voltageValue = Double(voltage) else {
            inputErrorMessage = "电压格式无效，请输入数字"
            return
        }
        
        guard let currentValue = Double(current) else {
            inputErrorMessage = "电流格式无效，请输入数字"
            return
        }
        
        guard let durationValue = Double(duration) else {
            inputErrorMessage = "时长格式无效，请输入数字"
            return
        }
        
        guard voltageValue > 0, currentValue >= 0, durationValue > 0 else {
            inputErrorMessage = "所有数值必须大于0"
            return
        }
        
        // 创建充电会话
        service.startChargingSession(pattern: selectedPattern, location: location)
        
        // 添加充电数据并获取诊断结果
        let result = service.addChargingData(
            voltage: voltageValue,
            current: currentValue,
            duration: durationValue * 3600, // 转换为秒
            pattern: selectedPattern
        )
        
        // 结束充电会话
        service.endChargingSession()
        
        diagnosisResult = result
        showResult = true
    }
}

// MARK: - Input Field

struct InputField: View {
    let icon: String
    let title: String
    let placeholder: String
    let unit: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    TextField(placeholder, text: $text)
                        .font(.body)
                        .keyboardType(keyboardType)
                    
                    Text(unit)
                        .font(.body)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pattern Selection Row

struct PatternSelectionRow: View {
    let pattern: ChargingPattern
    let isSelected: Bool
    let action: () -> Void
    
    var patternIcon: String {
        switch pattern {
        case .normal:
            return "bolt.fill"
        case .fast:
            return "bolt.circle.fill"
        case .trickle:
            return "bolt.horizontal.fill"
        case .intermittent:
            return "bolt.badge.clock.fill"
        }
    }
    
    var patternColor: Color {
        switch pattern {
        case .normal:
            return .blue
        case .fast:
            return .orange
        case .trickle:
            return .green
        case .intermittent:
            return .yellow
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 选择指示器
                ZStack {
                    Circle()
                        .stroke(isSelected ? .blue : .gray4, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(.blue)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // 图标
                Image(systemName: patternIcon)
                    .font(.system(size: 24))
                    .foregroundColor(patternColor)
                    .frame(width: 40)
                
                // 内容
                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.rawValue)
                        .font(.bodyMedium)
                        .foregroundColor(.white)
                    
                    Text(pattern.impactOnHealth)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(16)
            .background(isSelected ? .blueUltraLight : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Location Button

struct QuickLocationButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Charging Result Sheet

struct ChargingResultSheet: View {
    let result: BatteryDiagnosisResult
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // 结果图标
                    resultIcon
                    
                    // 评分
                    scoreSection
                    
                    // 各项指标
                    metricsSection
                    
                    // 建议
                    if !result.recommendations.isEmpty {
                        recommendationsSection
                    }
                    
                    // 警告
                    if !result.warnings.isEmpty {
                        warningsSection
                    }
                    
                    // 完成按钮
                    ICButton(
                        title: "完成",
                        icon: "checkmark",
                        style: .primary,
                        size: .large
                    ) {
                        dismiss()
                        onComplete()
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                }
                .padding(20)
            }
            .background(.black)
            .navigationTitle("分析结果")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                        onComplete()
                    }
                }
            }
        }
    }
    
    private var resultIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: result.healthStatus.color).opacity(0.1))
                .frame(width: 120, height: 120)
            
            Image(systemName: result.healthStatus.icon)
                .font(.system(size: 60))
                .foregroundColor(Color(hex: result.healthStatus.color))
        }
        .padding(.top, 32)
    }
    
    private var scoreSection: some View {
        VStack(spacing: 16) {
            Text("\(result.overallScore)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: result.healthStatus.color))
            
            Text(result.healthStatus.rawValue)
                .font(.title2)
                .foregroundColor(.white)
            
            Text(result.healthStatus.description)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("详细指标")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                ChargingMetricRow(
                    icon: "bolt.fill",
                    title: "电压稳定性",
                    value: Int(result.voltageStability),
                    color: .blue
                )
                
                ChargingMetricRow(
                    icon: "thermometer",
                    title: "温度表现",
                    value: Int(result.temperaturePerformance),
                    color: .orange
                )
                
                ChargingMetricRow(
                    icon: "bolt.car.fill",
                    title: "充电效率",
                    value: Int(result.chargingEfficiency),
                    color: .green
                )
                
                ChargingMetricRow(
                    icon: "battery.100",
                    title: "预估容量",
                    value: Int(result.estimatedCapacity),
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.2))
        .cardStyle()
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text("建议")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(result.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 16) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        
                        Text(recommendation)
                            .font(.body)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(.greenLight)
        .cornerRadius(12)
    }
    
    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("警告")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(result.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 16) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        
                        Text(warning)
                            .font(.body)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(.orangeLight)
        .cornerRadius(12)
    }
}

// MARK: - Metric Row

struct ChargingMetricRow: View {
    let icon: String
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32)
            
            Text(title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(value)")
                .font(.bodyMedium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

#Preview("Charging Input") {
    NavigationView {
        ChargingInputView(service: BatteryMonitorService.shared) {}
    }
}

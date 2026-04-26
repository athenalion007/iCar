import SwiftUI

// MARK: - Damage Detection View

struct DamageDetectionView: View {
    
    // MARK: - Properties
    
    let image: UIImage
    let detections: [DamageDetection]
    let position: PaintScanPosition
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectedDetection: DamageDetection?
    @State private var showLabels = true
    @State private var showMasks = true
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                Color.black.ignoresSafeArea()
                
                // 图像和检测层
                ZStack {
                    // 原始图像
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                // 缩放手势
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 1.0), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    },
                                // 拖动手势
                                DragGesture()
                                    .onChanged { value in
                                        let deltaX = value.translation.width - lastOffset.width
                                        let deltaY = value.translation.height - lastOffset.height
                                        lastOffset = value.translation
                                        offset = CGSize(
                                            width: offset.width + deltaX,
                                            height: offset.height + deltaY
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = .zero
                                    }
                            )
                        )
                    
                    // 检测结果层
                    GeometryReader { imageGeometry in
                        ZStack {
                            ForEach(detections) { detection in
                                DetectionOverlay(
                                    detection: detection,
                                    imageSize: imageGeometry.size,
                                    isSelected: selectedDetection?.id == detection.id,
                                    showMask: showMasks,
                                    showLabel: showLabels
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedDetection = detection
                                    }
                                }
                            }
                        }
                        .scaleEffect(scale)
                        .offset(offset)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 顶部工具栏
                VStack {
                    HStack {
                        // 关闭按钮
                        Button(action: { }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // 显示选项
                        HStack(spacing: 12) {
                            ToggleButton(
                                icon: "tag.fill",
                                isOn: $showLabels
                            )
                            
                            ToggleButton(
                                icon: "circle.fill",
                                isOn: $showMasks
                            )
                        }
                        
                        Spacer()
                        
                        // 重置按钮
                        Button(action: resetView) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // 底部信息面板
                    bottomInfoPanel
                }
            }
        }
        .sheet(item: $selectedDetection) { detection in
            DetectionDetailSheet(detection: detection)
        }
    }
    
    // MARK: - Bottom Info Panel
    
    private var bottomInfoPanel: some View {
        VStack(spacing: 0) {
            // 损伤统计
            HStack(spacing: 16) {
                DamageStatItem(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(detections.count)",
                    label: "检测到的损伤",
                    color: detections.isEmpty ? .green : .orange
                )
                
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.3))
                
                let criticalCount = detections.filter { $0.severity == .severe }.count
                DamageStatItem(
                    icon: "xmark.octagon.fill",
                    value: "\(criticalCount)",
                    label: "严重损伤",
                    color: criticalCount > 0 ? .red : .green
                )
                
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.3))
                
                let avgConfidence = detections.isEmpty ? 0 : detections.reduce(0) { $0 + $1.confidence } / Double(detections.count)
                DamageStatItem(
                    icon: "checkmark.shield.fill",
                    value: String(format: "%.0f%%", avgConfidence * 100),
                    label: "平均置信度",
                    color: .blue
                )
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
            .padding(.horizontal)
            
            // 损伤类型图例
            if !detections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(damageTypeStats.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                            PaintDamageTypeBadge(type: type, count: count)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            
            // 提示文字
            Text("双指缩放查看细节，点击损伤区域查看详情")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var damageTypeStats: [DamageType: Int] {
        var stats: [DamageType: Int] = [:]
        for detection in detections {
            stats[detection.type, default: 0] += 1
        }
        return stats
    }
    
    // MARK: - Methods
    
    private func resetView() {
        withAnimation(.spring(response: 0.3)) {
            scale = 1.0
            offset = .zero
            selectedDetection = nil
        }
    }
}

// MARK: - Detection Overlay

struct DetectionOverlay: View {
    let detection: DamageDetection
    let imageSize: CGSize
    let isSelected: Bool
    let showMask: Bool
    let showLabel: Bool
    let onTap: () -> Void
    
    private var color: Color {
        Color(hex: detection.severity.color)
    }
    
    private var rect: CGRect {
        CGRect(
            x: detection.boundingBox.origin.x * imageSize.width,
            y: detection.boundingBox.origin.y * imageSize.height,
            width: detection.boundingBox.width * imageSize.width,
            height: detection.boundingBox.height * imageSize.height
        )
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 遮罩
            if showMask && !detection.mask.isEmpty {
                DamageMaskShape(mask: detection.mask, imageSize: imageSize)
                    .fill(color.opacity(isSelected ? 0.4 : 0.2))
                    .overlay(
                        DamageMaskShape(mask: detection.mask, imageSize: imageSize)
                            .stroke(color, lineWidth: isSelected ? 3 : 2)
                    )
            }
            
            // 边界框
            Rectangle()
                .strokeBorder(color, lineWidth: isSelected ? 3 : 2)
                .background(Color.clear)
                .frame(width: rect.width, height: rect.height)
            
            // 标签
            if showLabel {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: detection.type.icon)
                            .font(.system(size: 10))
                        Text(detection.type.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                        Text(detection.severity.rawValue)
                            .font(.system(size: 9))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(color.opacity(0.9))
                .cornerRadius(4)
                .offset(y: -35)
            }
            
            // 选中指示器
            if isSelected {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: -6, y: -6)
            }
        }
        .position(x: rect.midX, y: rect.midY)
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

// MARK: - Damage Mask Shape

struct DamageMaskShape: Shape {
    let mask: [CGPoint]
    let imageSize: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !mask.isEmpty else { return path }
        
        let firstPoint = CGPoint(
            x: mask[0].x * imageSize.width,
            y: mask[0].y * imageSize.height
        )
        path.move(to: firstPoint)
        
        for point in mask.dropFirst() {
            let scaledPoint = CGPoint(
                x: point.x * imageSize.width,
                y: point.y * imageSize.height
            )
            path.addLine(to: scaledPoint)
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Toggle Button

struct ToggleButton: View {
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isOn ? .white : .white.opacity(0.5))
                .frame(width: 40, height: 40)
                .background(isOn ? Color.white.opacity(0.3) : Color.black.opacity(0.5))
                .clipShape(Circle())
        }
    }
}

// MARK: - Stat Item

struct DamageStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Damage Type Badge

struct PaintDamageTypeBadge: View {
    let type: DamageType
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 12))
            Text(type.rawValue)
                .font(.system(size: 12, weight: .medium))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.2))
                .cornerRadius(2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: type.color).opacity(0.8))
        .cornerRadius(16)
    }
}

// MARK: - Detection Detail Sheet

struct DetectionDetailSheet: View {
    let detection: DamageDetection
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // 损伤类型卡片
                    DamageTypeCard(detection: detection)
                    
                    // 严重程度指示
                    SeveritySection(detection: detection)
                    
                    // 详细信息
                    DetailInfoSection(detection: detection)
                    
                    // 建议处理
                    RecommendationSection(detection: detection)
                }
                .padding(20)
            }
            .navigationTitle("损伤详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Damage Type Card

struct DamageTypeCard: View {
    let detection: DamageDetection
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: detection.type.color).opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: detection.type.icon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: detection.type.color))
            }
            
            VStack(spacing: 8) {
                Text(detection.type.rawValue)
                    .font(.title2)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Image(systemName: detection.severity.icon)
                        .foregroundColor(Color(hex: detection.severity.color))
                    Text(detection.severity.rawValue)
                        .font(.body)
                        .foregroundColor(Color(hex: detection.severity.color))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.2))
        .cardStyle()
    }
}

// MARK: - Severity Section

struct SeveritySection: View {
    let detection: DamageDetection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("严重程度评估")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                ForEach(DamageSeverity.allCases, id: \.self) { severity in
                    SeverityRow(
                        severity: severity,
                        isActive: detection.severity == severity
                    )
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.2))
        .cardStyle()
    }
}

// MARK: - Severity Row

struct SeverityRow: View {
    let severity: DamageSeverity
    let isActive: Bool
    
    var body: some View {
        HStack {
            Image(systemName: severity.icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: severity.color))
                .frame(width: 32)
            
            Text(severity.rawValue)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: severity.color))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isActive ? Color(hex: severity.color).opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Detail Info Section

struct DetailInfoSection: View {
    let detection: DamageDetection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("检测信息")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                DamageInfoRow(icon: "location.fill", label: "位置", value: detection.position.name)
                DamageInfoRow(icon: "percent", label: "置信度", value: detection.formattedConfidence)
                DamageInfoRow(icon: "arrow.up.left.and.arrow.down.right", label: "相对面积", value: String(format: "%.2f%%", detection.area * 100))
                DamageInfoRow(icon: "number", label: "检测ID", value: detection.id.uuidString.prefix(8).description)
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.2))
        .cardStyle()
    }
}

// MARK: - Info Row

struct DamageInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(label)
                .font(.body)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Recommendation Section

struct RecommendationSection: View {
    let detection: DamageDetection
    
    var recommendation: String {
        switch detection.type {
        case .scratch:
            return "建议使用划痕修复剂进行局部处理，严重划痕需要专业抛光或重新喷漆。"
        case .dent:
            return "建议到专业维修店进行凹陷修复，避免自行处理造成更大损伤。"
        case .paintLoss:
            return "建议尽快进行补漆处理，防止金属部分氧化生锈。"
        case .oxidation:
            return "建议使用抗氧化剂和抛光剂进行处理，恢复漆面光泽。"
        case .waterSpot:
            return "建议使用酸性清洁剂去除水渍，然后打蜡保护。"
        case .stoneChip:
            return "建议进行局部点漆修复，防止损伤扩大。"
        case .swirlMark:
            return "建议进行专业漆面抛光，去除旋涡纹并恢复光泽。"
        case .birdDropping:
            return "建议立即清洁并使用漆面修复剂处理腐蚀痕迹。"
        case .clearCoatFailure:
            return "建议尽快到专业店重新喷涂清漆，防止漆面进一步损坏。"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("处理建议")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                Text(recommendation)
                    .font(.body)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    DamageDetectionView(
        image: UIImage(systemName: "car.fill")!,
        detections: [
            DamageDetection(
                type: .scratch,
                severity: .moderate,
                boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.15, height: 0.1),
                confidence: 0.85,
                position: .front
            ),
            DamageDetection(
                type: .stoneChip,
                severity: .minor,
                boundingBox: CGRect(x: 0.6, y: 0.5, width: 0.08, height: 0.08),
                confidence: 0.92,
                position: .front
            )
        ],
        position: .front
    )
}

import SwiftUI

// MARK: - Card Style

/// 卡片样式类型
enum ICCardStyle {
    case `default`
    case elevated
    case outlined
    case filled
}

// MARK: - ICCard

/// iCar 卡片组件
/// 通用容器组件，支持多种样式
struct ICCard<Content: View>: View {
    
    // MARK: - Properties
    
    let style: ICCardStyle
    let padding: CGFloat
    let cornerRadius: CGFloat
    let content: Content
    
    @State private var isPressed = false
    
    // MARK: - Initialization
    
    init(
        style: ICCardStyle = .default,
        padding: CGFloat = ICTheme.Layout.pagePadding,
        cornerRadius: CGFloat = ICTheme.Layout.cardCornerRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        switch style {
        case .default, .elevated:
            return ICTheme.Colors.surface
        case .outlined:
            return ICTheme.Colors.surface
        case .filled:
            return ICTheme.Colors.secondaryBackground
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .outlined:
            return ICTheme.Colors.separator
        default:
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .outlined:
            return 1
        default:
            return 0
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .elevated:
            return Color.black.opacity(0.15)
        case .default:
            return Color.black.opacity(ICTheme.Layout.shadowOpacity)
        case .outlined, .filled:
            return .clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .elevated:
            return 8
        case .default:
            return ICTheme.Layout.shadowRadius
        case .outlined, .filled:
            return 0
        }
    }
    
    private var shadowOffset: CGFloat {
        switch style {
        case .elevated:
            return 4
        case .default:
            return ICTheme.Layout.shadowOffset
        case .outlined, .filled:
            return 0
        }
    }
}

// MARK: - ICTappableCard

/// 可点击的卡片组件
struct ICTappableCard<Content: View>: View {
    
    // MARK: - Properties
    
    let style: ICCardStyle
    let padding: CGFloat
    let cornerRadius: CGFloat
    let action: () -> Void
    let content: Content
    
    @State private var isPressed = false
    
    // MARK: - Initialization
    
    init(
        style: ICCardStyle = .default,
        padding: CGFloat = ICTheme.Layout.pagePadding,
        cornerRadius: CGFloat = ICTheme.Layout.cardCornerRadius,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.action = action
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            content
                .padding(padding)
        }
        .buttonStyle(ICCardButtonStyle(
            style: style,
            cornerRadius: cornerRadius,
            isPressed: $isPressed
        ))
    }
}

// MARK: - Card Button Style

struct ICCardButtonStyle: ButtonStyle {
    let style: ICCardStyle
    let cornerRadius: CGFloat
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
            }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .default, .elevated:
            return ICTheme.Colors.surface
        case .outlined:
            return ICTheme.Colors.surface
        case .filled:
            return ICTheme.Colors.secondaryBackground
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .outlined:
            return ICTheme.Colors.separator
        default:
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .outlined:
            return 1
        default:
            return 0
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .elevated:
            return Color.black.opacity(0.15)
        case .default:
            return Color.black.opacity(ICTheme.Layout.shadowOpacity)
        case .outlined, .filled:
            return .clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .elevated:
            return 8
        case .default:
            return ICTheme.Layout.shadowRadius
        case .outlined, .filled:
            return 0
        }
    }
    
    private var shadowOffset: CGFloat {
        switch style {
        case .elevated:
            return 4
        case .default:
            return ICTheme.Layout.shadowOffset
        case .outlined, .filled:
            return 0
        }
    }
}

// MARK: - ICInfoCard

/// 信息卡片组件
struct ICInfoCard: View {
    
    // MARK: - Properties
    
    let icon: String
    let title: String
    let description: String?
    let style: ICCardStyle
    let iconColor: Color
    let backgroundColor: Color
    
    // MARK: - Initialization
    
    init(
        icon: String,
        title: String,
        description: String? = nil,
        style: ICCardStyle = .default,
        iconColor: Color = ICTheme.Colors.primary,
        backgroundColor: Color = ICTheme.Colors.primaryUltraLight
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.style = style
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
    }
    
    // MARK: - Body
    
    var body: some View {
        ICCard(style: style) {
            HStack(spacing: ICTheme.Layout.spacingExtraLarge) {
                Image(systemName: icon)
                    .font(.system(size: ICTheme.Layout.iconLarge))
                    .foregroundColor(iconColor)
                    .frame(width: 48, height: 48)
                    .background(backgroundColor)
                    .cornerRadius(ICTheme.Layout.smallCornerRadius)
                
                VStack(alignment: .leading, spacing: ICTheme.Layout.spacingSmall) {
                    Text(title)
                        .font(ICTheme.Typography.headline)
                        .foregroundColor(ICTheme.Colors.textPrimary)
                    
                    if let description = description {
                        Text(description)
                            .font(ICTheme.Typography.subheadline)
                            .foregroundColor(ICTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - ICStatusCard

/// 状态卡片组件
struct ICStatusCard: View {
    
    // MARK: - Properties
    
    let title: String
    let value: String
    let unit: String?
    let icon: String
    let status: StatusType
    let trend: TrendType?
    
    enum StatusType {
        case normal
        case success
        case warning
        case error
        case info
        
        var color: Color {
            switch self {
            case .normal: return ICTheme.Colors.primary
            case .success: return ICTheme.Colors.success
            case .warning: return ICTheme.Colors.warning
            case .error: return ICTheme.Colors.error
            case .info: return ICTheme.Colors.info
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .normal: return ICTheme.Colors.primaryUltraLight
            case .success: return ICTheme.Colors.successLight
            case .warning: return ICTheme.Colors.warningLight
            case .error: return ICTheme.Colors.errorLight
            case .info: return ICTheme.Colors.infoLight
            }
        }
    }
    
    enum TrendType {
        case up
        case down
        case stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return ICTheme.Colors.success
            case .down: return ICTheme.Colors.error
            case .stable: return ICTheme.Colors.gray
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        title: String,
        value: String,
        unit: String? = nil,
        icon: String,
        status: StatusType = .normal,
        trend: TrendType? = nil
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.icon = icon
        self.status = status
        self.trend = trend
    }
    
    // MARK: - Body
    
    var body: some View {
        ICCard(style: .filled) {
            VStack(alignment: .leading, spacing: ICTheme.Layout.spacingLarge) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: ICTheme.Layout.iconMedium))
                        .foregroundColor(status.color)
                    
                    Spacer()
                    
                    if let trend = trend {
                        HStack(spacing: 2) {
                            Image(systemName: trend.icon)
                                .font(.system(size: 10))
                            Text("12%")
                                .font(ICTheme.Typography.captionMedium)
                        }
                        .foregroundColor(trend.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trend.color.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(ICTheme.Typography.largeNumber)
                            .foregroundColor(ICTheme.Colors.textPrimary)
                        
                        if let unit = unit {
                            Text(unit)
                                .font(ICTheme.Typography.footnote)
                                .foregroundColor(ICTheme.Colors.textSecondary)
                        }
                    }
                    
                    Text(title)
                        .font(ICTheme.Typography.caption)
                        .foregroundColor(ICTheme.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Card Styles") {
    ScrollView {
        VStack(spacing: ICTheme.Layout.spacingExtraLarge) {
            Group {
                Text("卡片样式").font(ICTheme.Typography.title2)
                
                ICCard(style: .default) {
                    Text("默认样式卡片")
                        .font(ICTheme.Typography.body)
                }
                
                ICCard(style: .elevated) {
                    Text(" elevated 样式卡片")
                        .font(ICTheme.Typography.body)
                }
                
                ICCard(style: .outlined) {
                    Text("描边样式卡片")
                        .font(ICTheme.Typography.body)
                }
                
                ICCard(style: .filled) {
                    Text("填充样式卡片")
                        .font(ICTheme.Typography.body)
                }
            }
            
            Divider()
            
            Group {
                Text("信息卡片").font(ICTheme.Typography.title2)
                
                ICInfoCard(
                    icon: "car.fill",
                    title: "车辆状态",
                    description: "查看实时车辆数据和诊断信息"
                )
                
                ICInfoCard(
                    icon: "location.fill",
                    title: "位置服务",
                    description: "追踪车辆位置和行驶轨迹",
                    iconColor: ICTheme.Colors.success,
                    backgroundColor: ICTheme.Colors.successLight
                )
            }
            
            Divider()
            
            Group {
                Text("状态卡片").font(ICTheme.Typography.title2)
                
                HStack(spacing: ICTheme.Layout.spacingMedium) {
                    ICStatusCard(
                        title: "总里程",
                        value: "12,580",
                        unit: "km",
                        icon: "speedometer",
                        status: .normal,
                        trend: .up
                    )
                    
                    ICStatusCard(
                        title: "油量",
                        value: "68",
                        unit: "%",
                        icon: "fuel.pump.fill",
                        status: .success,
                        trend: .stable
                    )
                }
                
                HStack(spacing: ICTheme.Layout.spacingMedium) {
                    ICStatusCard(
                        title: "胎压",
                        value: "2.3",
                        unit: "bar",
                        icon: "tirepressure",
                        status: .warning,
                        trend: .down
                    )
                    
                    ICStatusCard(
                        title: "电池",
                        value: "12.4",
                        unit: "V",
                        icon: "battery.100",
                        status: .error
                    )
                }
            }
            
            Divider()
            
            Group {
                Text("可点击卡片").font(ICTheme.Typography.title2)
                
                ICTappableCard(action: {}) {
                    HStack {
                        Image(systemName: "gear")
                            .font(.system(size: 24))
                            .foregroundColor(ICTheme.Colors.primary)
                        
                        Text("设置")
                            .font(ICTheme.Typography.body)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(ICTheme.Colors.gray)
                    }
                }
            }
        }
        .padding()
    }
}

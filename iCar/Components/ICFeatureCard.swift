import SwiftUI

// MARK: - Feature Card Style

/// 功能卡片样式
enum ICFeatureCardStyle {
    case standard
    case compact
    case prominent
}

// MARK: - Feature Card Color Scheme

/// 功能卡片配色方案
enum ICFeatureColorScheme {
    case primary
    case success
    case warning
    case error
    case info
    case purple
    case orange
    
    var mainColor: Color {
        switch self {
        case .primary: return ICTheme.Colors.primary
        case .success: return ICTheme.Colors.success
        case .warning: return ICTheme.Colors.warning
        case .error: return ICTheme.Colors.error
        case .info: return ICTheme.Colors.info
        case .purple: return Color(hex: "#AF52DE")
        case .orange: return Color(hex: "#FF9500")
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .primary: return ICTheme.Colors.primaryUltraLight
        case .success: return ICTheme.Colors.successLight
        case .warning: return ICTheme.Colors.warningLight
        case .error: return ICTheme.Colors.errorLight
        case .info: return ICTheme.Colors.infoLight
        case .purple: return Color(hex: "#F5E6FF")
        case .orange: return Color(hex: "#FFF4E5")
        }
    }
    
    var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                mainColor,
                mainColor.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - ICFeatureCard

/// iCar 功能模块入口卡片
/// 用于展示应用主要功能模块
struct ICFeatureCard: View {
    
    // MARK: - Properties
    
    let icon: String
    let title: String
    let subtitle: String?
    let badge: String?
    let style: ICFeatureCardStyle
    let colorScheme: ICFeatureColorScheme
    let action: () -> Void
    
    @State private var isPressed = false
    
    // MARK: - Initialization
    
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        style: ICFeatureCardStyle = .standard,
        colorScheme: ICFeatureColorScheme = .primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.style = style
        self.colorScheme = colorScheme
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .pressEvents {
            withAnimation(ICTheme.Animation.fast) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(ICTheme.Animation.fast) {
                isPressed = false
            }
        }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        switch style {
        case .standard:
            standardCard
        case .compact:
            compactCard
        case .prominent:
            prominentCard
        }
    }
    
    // MARK: - Standard Card
    
    private var standardCard: some View {
        HStack(spacing: ICTheme.Layout.spacingExtraLarge) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: ICTheme.Layout.smallCornerRadius)
                    .fill(colorScheme.backgroundColor)
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: ICTheme.Layout.iconLarge, weight: .semibold))
                    .foregroundColor(colorScheme.mainColor)
            }
            
            // 文字内容
            VStack(alignment: .leading, spacing: ICTheme.Layout.spacingSmall) {
                Text(title)
                    .font(ICTheme.Typography.headline)
                    .foregroundColor(ICTheme.Colors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(ICTheme.Typography.subheadline)
                        .foregroundColor(ICTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 徽章和箭头
            HStack(spacing: ICTheme.Layout.spacingMedium) {
                if let badge = badge {
                    Text(badge)
                        .font(ICTheme.Typography.captionMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorScheme.mainColor)
                        .cornerRadius(ICTheme.Layout.circleCornerRadius)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ICTheme.Colors.gray)
            }
        }
        .padding(ICTheme.Layout.pagePadding)
        .background(ICTheme.Colors.surface)
        .cornerRadius(ICTheme.Layout.cardCornerRadius)
        .shadow(
            color: Color.black.opacity(ICTheme.Layout.shadowOpacity),
            radius: ICTheme.Layout.shadowRadius,
            x: 0,
            y: ICTheme.Layout.shadowOffset
        )
    }
    
    // MARK: - Compact Card
    
    private var compactCard: some View {
        VStack(spacing: ICTheme.Layout.spacingMedium) {
            // 图标
            ZStack {
                Circle()
                    .fill(colorScheme.backgroundColor)
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: ICTheme.Layout.iconExtraLarge, weight: .semibold))
                    .foregroundColor(colorScheme.mainColor)
                
                // 徽章
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(colorScheme.mainColor)
                        .clipShape(Circle())
                        .offset(x: 20, y: -20)
                }
            }
            
            // 标题
            Text(title)
                .font(ICTheme.Typography.headline)
                .foregroundColor(ICTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(ICTheme.Typography.caption)
                    .foregroundColor(ICTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ICTheme.Layout.pagePadding)
        .background(ICTheme.Colors.surface)
        .cornerRadius(ICTheme.Layout.cardCornerRadius)
        .shadow(
            color: Color.black.opacity(ICTheme.Layout.shadowOpacity),
            radius: ICTheme.Layout.shadowRadius,
            x: 0,
            y: ICTheme.Layout.shadowOffset
        )
    }
    
    // MARK: - Prominent Card
    
    private var prominentCard: some View {
        VStack(alignment: .leading, spacing: ICTheme.Layout.spacingLarge) {
            // 顶部图标和徽章
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if let badge = badge {
                    Text(badge)
                        .font(ICTheme.Typography.captionMedium)
                        .foregroundColor(colorScheme.mainColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .cornerRadius(ICTheme.Layout.circleCornerRadius)
                }
            }
            
            // 文字内容
            VStack(alignment: .leading, spacing: ICTheme.Layout.spacingSmall) {
                Text(title)
                    .font(ICTheme.Typography.title3)
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(ICTheme.Typography.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
            
            // 底部箭头
            HStack {
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(ICTheme.Layout.pagePadding)
        .background(colorScheme.gradient)
        .cornerRadius(ICTheme.Layout.largeCornerRadius)
    }
}

// MARK: - ICFeatureGrid

/// 功能卡片网格布局
struct ICFeatureGrid: View {
    
    // MARK: - Properties
    
    let features: [FeatureItem]
    let columns: Int
    let spacing: CGFloat
    
    struct FeatureItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String?
        let badge: String?
        let colorScheme: ICFeatureColorScheme
        let action: () -> Void
        
        init(
            icon: String,
            title: String,
            subtitle: String? = nil,
            badge: String? = nil,
            colorScheme: ICFeatureColorScheme = .primary,
            action: @escaping () -> Void
        ) {
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.badge = badge
            self.colorScheme = colorScheme
            self.action = action
        }
    }
    
    // MARK: - Initialization
    
    init(
        features: [FeatureItem],
        columns: Int = 2,
        spacing: CGFloat = ICTheme.Layout.spacingMedium
    ) {
        self.features = features
        self.columns = columns
        self.spacing = spacing
    }
    
    // MARK: - Body
    
    var body: some View {
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
        
        LazyVGrid(columns: gridItems, spacing: spacing) {
            ForEach(features) { feature in
                ICFeatureCard(
                    icon: feature.icon,
                    title: feature.title,
                    subtitle: feature.subtitle,
                    badge: feature.badge,
                    style: .compact,
                    colorScheme: feature.colorScheme,
                    action: feature.action
                )
            }
        }
    }
}

// MARK: - ICFeatureList

/// 功能卡片列表布局
struct ICFeatureList: View {
    
    // MARK: - Properties
    
    let features: [ICFeatureGrid.FeatureItem]
    let spacing: CGFloat
    
    // MARK: - Initialization
    
    init(
        features: [ICFeatureGrid.FeatureItem],
        spacing: CGFloat = ICTheme.Layout.spacingMedium
    ) {
        self.features = features
        self.spacing = spacing
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(features) { feature in
                ICFeatureCard(
                    icon: feature.icon,
                    title: feature.title,
                    subtitle: feature.subtitle,
                    badge: feature.badge,
                    style: .standard,
                    colorScheme: feature.colorScheme,
                    action: feature.action
                )
            }
        }
    }
}

// MARK: - ICQuickActionButton

/// 快捷操作按钮
struct ICQuickActionButton: View {
    
    // MARK: - Properties
    
    let icon: String
    let title: String
    let colorScheme: ICFeatureColorScheme
    let action: () -> Void
    
    @State private var isPressed = false
    
    // MARK: - Initialization
    
    init(
        icon: String,
        title: String,
        colorScheme: ICFeatureColorScheme = .primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.colorScheme = colorScheme
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: ICTheme.Layout.spacingSmall) {
                ZStack {
                    Circle()
                        .fill(colorScheme.backgroundColor)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(colorScheme.mainColor)
                }
                
                Text(title)
                    .font(ICTheme.Typography.captionMedium)
                    .foregroundColor(ICTheme.Colors.textPrimary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .pressEvents {
            withAnimation(ICTheme.Animation.fast) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(ICTheme.Animation.fast) {
                isPressed = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Feature Cards") {
    ScrollView {
        VStack(spacing: ICTheme.Layout.spacingExtraLarge) {
            Group {
                Text("标准样式").font(ICTheme.Typography.title2)
                
                ICFeatureCard(
                    icon: "car.fill",
                    title: "车辆状态",
                    subtitle: "查看实时车辆数据和诊断信息",
                    style: .standard,
                    colorScheme: .primary,
                    action: {}
                )
                
                ICFeatureCard(
                    icon: "location.fill",
                    title: "位置服务",
                    subtitle: "追踪车辆位置和行驶轨迹",
                    badge: "NEW",
                    style: .standard,
                    colorScheme: .success,
                    action: {}
                )
            }
            
            Divider()
            
            Group {
                Text("紧凑样式（网格）").font(ICTheme.Typography.title2)
                
                ICFeatureGrid(
                    features: [
                        .init(icon: "car.fill", title: "车辆状态", subtitle: "实时监控", colorScheme: .primary, action: {}),
                        .init(icon: "map.fill", title: "导航", subtitle: "智能路线", colorScheme: .success, action: {}),
                        .init(icon: "wrench.fill", title: "保养", subtitle: "预约服务", badge: "3", colorScheme: .warning, action: {}),
                        .init(icon: "fuel.pump.fill", title: "油耗", subtitle: "统计分析", colorScheme: .info, action: {})
                    ],
                    columns: 2
                )
            }
            
            Divider()
            
            Group {
                Text("突出样式").font(ICTheme.Typography.title2)
                
                HStack(spacing: ICTheme.Layout.spacingMedium) {
                    ICFeatureCard(
                        icon: "bolt.fill",
                        title: "充电站",
                        subtitle: "查找附近充电桩",
                        style: .prominent,
                        colorScheme: .success,
                        action: {}
                    )
                    
                    ICFeatureCard(
                        icon: "parking.sign",
                        title: "停车",
                        subtitle: "智能停车助手",
                        badge: "HOT",
                        style: .prominent,
                        colorScheme: .purple,
                        action: {}
                    )
                }
            }
            
            Divider()
            
            Group {
                Text("快捷操作").font(ICTheme.Typography.title2)
                
                HStack(spacing: ICTheme.Layout.spacingExtraLarge) {
                    ICQuickActionButton(icon: "lock.fill", title: "锁车", colorScheme: .primary, action: {})
                    ICQuickActionButton(icon: "fanblades.fill", title: "空调", colorScheme: .info, action: {})
                    ICQuickActionButton(icon: "flashlight.on.fill", title: "寻车", colorScheme: .warning, action: {})
                    ICQuickActionButton(icon: "phone.fill", title: "救援", colorScheme: .error, action: {})
                }
            }
            
            Divider()
            
            Group {
                Text("列表布局").font(ICTheme.Typography.title2)
                
                ICFeatureList(
                    features: [
                        .init(icon: "gearshape.fill", title: "设置", subtitle: "应用偏好设置", colorScheme: .primary, action: {}),
                        .init(icon: "bell.fill", title: "通知", subtitle: "消息提醒设置", badge: "5", colorScheme: .warning, action: {}),
                        .init(icon: "person.fill", title: "个人中心", subtitle: "账户信息管理", colorScheme: .info, action: {}),
                        .init(icon: "questionmark.circle.fill", title: "帮助", subtitle: "常见问题解答", colorScheme: .purple, action: {})
                    ]
                )
            }
        }
        .padding()
    }
}

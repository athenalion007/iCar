import SwiftUI

// MARK: - iCar Theme System

/// iCar 应用主题系统
/// 定义颜色、字体、间距等设计规范
enum ICTheme {
    
    // MARK: - Colors
    
    /// 主色调 - 蓝色系
    struct Colors {
        /// 主色 - 品牌蓝 #007AFF
        static let primary = Color(hex: "#007AFF")
        /// 主色浅色变体
        static let primaryLight = Color(hex: "#5AC8FA")
        /// 主色深色变体
        static let primaryDark = Color(hex: "#0055B3")
        /// 主色极浅色（用于背景）
        static let primaryUltraLight = Color(hex: "#E5F2FF")
        
        /// 辅助色 - 靛蓝 #5856D6
        static let secondary = Color(hex: "#5856D6")
        /// 辅助色浅色
        static let secondaryLight = Color(hex: "#7F7EE8")
        
        /// 成功色 - 绿色 #34C759
        static let success = Color(hex: "#34C759")
        /// 成功色浅色（用于背景）
        static let successLight = Color(hex: "#E8F9ED")
        
        /// 警告色 - 橙色 #FF9500
        static let warning = Color(hex: "#FF9500")
        /// 警告色浅色（用于背景）
        static let warningLight = Color(hex: "#FFF4E5")
        
        /// 错误色 - 红色 #FF3B30
        static let error = Color(hex: "#FF3B30")
        /// 错误色浅色（用于背景）
        static let errorLight = Color(hex: "#FFE5E3")
        
        /// 信息色 - 青色 #5AC8FA
        static let info = Color(hex: "#5AC8FA")
        /// 信息色浅色（用于背景）
        static let infoLight = Color(hex: "#E5F7FF")
        
        // MARK: - Semantic Colors
        
        /// 背景色 - 自动适配深色模式
        static let background = Color(.systemBackground)
        /// 二级背景色
        static let secondaryBackground = Color(.secondarySystemBackground)
        /// 三级背景色
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        
        /// 分组背景色
        static let groupedBackground = Color(.systemGroupedBackground)
        static let secondaryGroupedBackground = Color(.secondarySystemGroupedBackground)
        
        /// 表面色（卡片等）
        static let surface = Color(.systemBackground)
        
        /// 文本主色
        static let textPrimary = Color(.label)
        /// 文本二级色
        static let textSecondary = Color(.secondaryLabel)
        /// 文本三级色
        static let textTertiary = Color(.tertiaryLabel)
        /// 占位符文本色
        static let textPlaceholder = Color(.placeholderText)
        
        /// 分隔线颜色
        static let separator = Color(.separator)
        /// 不透明分隔线颜色
        static let opaqueSeparator = Color(.opaqueSeparator)
        
        /// 填充色
        static let fill = Color(.systemFill)
        static let secondaryFill = Color(.secondarySystemFill)
        static let tertiaryFill = Color(.tertiarySystemFill)
        static let quaternaryFill = Color(.quaternarySystemFill)
        
        /// 灰色系
        static let gray = Color(.systemGray)
        static let gray2 = Color(.systemGray2)
        static let gray3 = Color(.systemGray3)
        static let gray4 = Color(.systemGray4)
        static let gray5 = Color(.systemGray5)
        static let gray6 = Color(.systemGray6)
        
        /// 扩展颜色
        static let cyan = Color.cyan
    }
    
    // MARK: - Typography
    
    /// 字体系统 - 使用系统字体支持动态字体
    struct Typography {
        /// 大标题 - 用于页面主标题
        static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
        
        /// 标题1
        static let title1 = Font.system(.title, design: .default, weight: .bold)
        /// 标题2
        static let title2 = Font.system(.title2, design: .default, weight: .semibold)
        /// 标题3
        static let title3 = Font.system(.title3, design: .default, weight: .semibold)
        
        /// 正文 - 常规
        static let body = Font.system(.body, design: .default, weight: .regular)
        /// 正文 - 中等
        static let bodyMedium = Font.system(.body, design: .default, weight: .medium)
        /// 正文 - 粗体
        static let bodyBold = Font.system(.body, design: .default, weight: .bold)
        
        /// 小标题
        static let headline = Font.system(.headline, design: .default, weight: .semibold)
        /// 小标题 - 中等
        static let headlineMedium = Font.system(.headline, design: .default, weight: .medium)
        
        /// 副标题
        static let subheadline = Font.system(.subheadline, design: .default, weight: .regular)
        /// 副标题 - 中等
        static let subheadlineMedium = Font.system(.subheadline, design: .default, weight: .medium)
        
        /// 脚注
        static let footnote = Font.system(.footnote, design: .default, weight: .regular)
        /// 脚注 - 中等
        static let footnoteMedium = Font.system(.footnote, design: .default, weight: .medium)
        
        /// 说明文字
        static let caption = Font.system(.caption, design: .default, weight: .regular)
        /// 说明文字 - 中等
        static let captionMedium = Font.system(.caption, design: .default, weight: .medium)
        /// 说明文字2
        static let caption2 = Font.system(.caption2, design: .default, weight: .regular)
        
        /// 数字字体 - 等宽
        static let number = Font.system(.body, design: .monospaced, weight: .medium)
        /// 大数字
        static let largeNumber = Font.system(.title, design: .monospaced, weight: .semibold)
    }
    
    // MARK: - Layout
    
    /// 布局规范
    struct Layout {
        /// 页面边距
        static let pagePadding: CGFloat = 16
        /// 小边距
        static let smallPadding: CGFloat = 8
        /// 中等边距
        static let mediumPadding: CGFloat = 12
        /// 大边距
        static let largePadding: CGFloat = 20
        /// 超大边距
        static let extraLargePadding: CGFloat = 24
        
        /// 卡片圆角
        static let cardCornerRadius: CGFloat = 12
        /// 按钮圆角
        static let buttonCornerRadius: CGFloat = 10
        /// 小圆角
        static let smallCornerRadius: CGFloat = 8
        /// 大圆角
        static let largeCornerRadius: CGFloat = 16
        /// 超大圆角
        static let extraLargeCornerRadius: CGFloat = 20
        /// 圆形
        static let circleCornerRadius: CGFloat = 9999
        
        /// 元素间距 - 小
        static let spacingSmall: CGFloat = 4
        /// 元素间距 - 中
        static let spacingMedium: CGFloat = 8
        /// 元素间距 - 大
        static let spacingLarge: CGFloat = 12
        /// 元素间距 - 超大
        static let spacingExtraLarge: CGFloat = 16
        /// 元素间距 - 巨大
        static let spacingHuge: CGFloat = 24
        
        /// 图标尺寸 - 小
        static let iconSmall: CGFloat = 16
        /// 图标尺寸 - 中
        static let iconMedium: CGFloat = 24
        /// 图标尺寸 - 大
        static let iconLarge: CGFloat = 32
        /// 图标尺寸 - 超大
        static let iconExtraLarge: CGFloat = 48
        /// 图标尺寸 - 巨大
        static let iconHuge: CGFloat = 64
        
        /// 按钮高度 - HIG: 最小触控区域 44pt
        static let buttonHeight: CGFloat = 50
        /// 小按钮高度 - HIG: 最小触控区域 44pt
        static let buttonSmallHeight: CGFloat = 44
        /// 大按钮高度
        static let buttonLargeHeight: CGFloat = 56
        
        /// 阴影半径
        static let shadowRadius: CGFloat = 4
        /// 阴影偏移
        static let shadowOffset: CGFloat = 2
        /// 阴影不透明度
        static let shadowOpacity: CGFloat = 0.1
    }
    
    // MARK: - Animation
    
    /// 动画规范
    struct Animation {
        /// 快速动画
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        /// 标准动画
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        /// 慢速动画
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.35)
        /// 弹簧动画
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
        /// 弹性动画
        static let bouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
}

// MARK: - View Modifiers

/// 卡片样式修饰符
struct CardStyle: ViewModifier {
    var backgroundColor: Color = ICTheme.Colors.surface
    var cornerRadius: CGFloat = ICTheme.Layout.cardCornerRadius
    var shadowRadius: CGFloat = ICTheme.Layout.shadowRadius
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: Color.black.opacity(ICTheme.Layout.shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: ICTheme.Layout.shadowOffset
            )
    }
}

/// 主按钮样式修饰符
struct PrimaryButtonStyle: ViewModifier {
    var isEnabled: Bool = true
    var isLoading: Bool = false
    
    func body(content: Content) -> some View {
        content
            .font(ICTheme.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ICTheme.Layout.buttonHeight)
            .background(isEnabled ? ICTheme.Colors.primary : ICTheme.Colors.gray4)
            .cornerRadius(ICTheme.Layout.buttonCornerRadius)
            .opacity(isLoading ? 0.8 : 1.0)
    }
}

/// 次要按钮样式修饰符
struct SecondaryButtonStyle: ViewModifier {
    var isEnabled: Bool = true
    
    func body(content: Content) -> some View {
        content
            .font(ICTheme.Typography.headline)
            .foregroundColor(ICTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: ICTheme.Layout.buttonHeight)
            .background(ICTheme.Colors.primaryUltraLight)
            .cornerRadius(ICTheme.Layout.buttonCornerRadius)
    }
}

// MARK: - View Extensions

extension View {
    /// 应用卡片样式
    func cardStyle(
        backgroundColor: Color = ICTheme.Colors.surface,
        cornerRadius: CGFloat = ICTheme.Layout.cardCornerRadius,
        shadowRadius: CGFloat = ICTheme.Layout.shadowRadius
    ) -> some View {
        modifier(CardStyle(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius
        ))
    }
    
    /// 应用主按钮样式
    func primaryButtonStyle(isEnabled: Bool = true, isLoading: Bool = false) -> some View {
        modifier(PrimaryButtonStyle(isEnabled: isEnabled, isLoading: isLoading))
    }
    
    /// 应用次要按钮样式
    func secondaryButtonStyle(isEnabled: Bool = true) -> some View {
        modifier(SecondaryButtonStyle(isEnabled: isEnabled))
    }
}



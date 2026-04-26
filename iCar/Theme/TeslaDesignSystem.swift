import SwiftUI

// MARK: - Tesla Design System
// 对标Tesla App的极简、科技感设计风格

enum TeslaDesignSystem {
    
    // MARK: - Colors
    enum Colors {
        // 背景色
        static let background = Color(hex: "000000")
        static let surface = Color(hex: "1C1C1E")
        static let surfaceElevated = Color(hex: "2C2C2E")
        
        // 文字色
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "8E8E93")
        static let textTertiary = Color(hex: "636366")
        
        // 强调色
        static let accent = Color(hex: "E82127") // Tesla红
        static let accentGreen = Color(hex: "34C759")
        static let accentYellow = Color(hex: "FFCC00")
        static let accentBlue = Color(hex: "007AFF")
        
        // 状态色
        static let success = Color(hex: "34C759")
        static let warning = Color(hex: "FF9500")
        static let error = Color(hex: "FF3B30")
        
        // 功能模块色（Tesla风格 - 低饱和度）
        static let engine = Color(hex: "FF6B35") // 暖橙
        static let tire = Color(hex: "5856D6")   // 紫蓝
        static let paint = Color(hex: "AF52DE")  // 紫色
        static let battery = Color(hex: "34C759") // 绿色
        static let suspension = Color(hex: "5AC8FA") // 蓝色
        static let ac = Color(hex: "64D2FF")     // 青色
    }
    
    // MARK: - Typography
    enum Typography {
        // 大标题 - 车辆名称等
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        
        // 标题 - 页面标题
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        
        // 小标题 - 卡片标题
        static let headline = Font.system(size: 20, weight: .semibold, design: .rounded)
        
        // 正文 - 主要内容
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        
        // 小字 - 辅助信息
        static let caption = Font.system(size: 15, weight: .regular, design: .default)
        
        // 数据 - 大数字显示
        static let dataLarge = Font.system(size: 48, weight: .bold, design: .rounded)
        static let dataMedium = Font.system(size: 32, weight: .bold, design: .rounded)
        static let dataSmall = Font.system(size: 24, weight: .semibold, design: .rounded)
        
        // 标签 - 小标签文字
        static let label = Font.system(size: 13, weight: .medium, design: .default)
    }
    
    // MARK: - Layout
    enum Layout {
        // 间距
        static let spacingXS: CGFloat = 4
        static let spacingSM: CGFloat = 8
        static let spacingMD: CGFloat = 16
        static let spacingLG: CGFloat = 24
        static let spacingXL: CGFloat = 32
        static let spacingXXL: CGFloat = 48
        
        // 圆角
        static let radiusSM: CGFloat = 8
        static let radiusMD: CGFloat = 12
        static let radiusLG: CGFloat = 16
        static let radiusXL: CGFloat = 24
        static let radiusFull: CGFloat = 9999
        
        // 内边距
        static let paddingScreen: CGFloat = 20
        static let paddingCard: CGFloat = 20
        static let paddingButton: CGFloat = 16
        
        // 卡片高度
        static let cardHeightSmall: CGFloat = 100
        static let cardHeightMedium: CGFloat = 160
        static let cardHeightLarge: CGFloat = 240
    }
    
    // MARK: - Shadows
    enum Shadows {
        static let card = ShadowStyle(
            color: Color.black.opacity(0.3),
            radius: 20,
            x: 0,
            y: 10
        )
        
        static let elevated = ShadowStyle(
            color: Color.black.opacity(0.4),
            radius: 30,
            x: 0,
            y: 15
        )
        
        static let glow = ShadowStyle(
            color: Colors.accent.opacity(0.5),
            radius: 20,
            x: 0,
            y: 0
        )
    }
    
    // MARK: - Animations
    enum Animations {
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let easeOut = Animation.easeOut(duration: 0.3)
        static let easeInOut = Animation.easeInOut(duration: 0.3)
        static let linear = Animation.linear(duration: 0.2)
    }
}

// MARK: - Shadow Style
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct TeslaCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TeslaDesignSystem.Colors.surface)
            .cornerRadius(TeslaDesignSystem.Layout.radiusLG)
            .shadow(
                color: TeslaDesignSystem.Shadows.card.color,
                radius: TeslaDesignSystem.Shadows.card.radius,
                x: TeslaDesignSystem.Shadows.card.x,
                y: TeslaDesignSystem.Shadows.card.y
            )
    }
}

struct TeslaButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TeslaDesignSystem.Typography.body)
            .fontWeight(.semibold)
            .foregroundColor(isPrimary ? .white : TeslaDesignSystem.Colors.textPrimary)
            .padding(.horizontal, TeslaDesignSystem.Layout.paddingButton)
            .padding(.vertical, 12)
            .background(
                isPrimary 
                    ? TeslaDesignSystem.Colors.accent 
                    : TeslaDesignSystem.Colors.surfaceElevated
            )
            .cornerRadius(TeslaDesignSystem.Layout.radiusFull)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(TeslaDesignSystem.Animations.spring, value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func teslaCard() -> some View {
        modifier(TeslaCardStyle())
    }
    
    func teslaButton(isPrimary: Bool = true) -> some View {
        buttonStyle(TeslaButtonStyle(isPrimary: isPrimary))
    }
}

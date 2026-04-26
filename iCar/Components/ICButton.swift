import SwiftUI

// MARK: - Button Style Enum

/// 按钮样式类型
enum ICButtonStyle {
    case primary
    case secondary
    case outline
    case ghost
    case danger
    case success
}

/// 按钮尺寸
enum ICButtonSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small: return ICTheme.Layout.buttonSmallHeight
        case .medium: return ICTheme.Layout.buttonHeight
        case .large: return ICTheme.Layout.buttonLargeHeight
        }
    }
    
    var font: Font {
        switch self {
        case .small: return ICTheme.Typography.subheadlineMedium
        case .medium: return ICTheme.Typography.headline
        case .large: return ICTheme.Typography.title3
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small: return ICTheme.Layout.iconSmall
        case .medium: return ICTheme.Layout.iconMedium
        case .large: return ICTheme.Layout.iconLarge
        }
    }
    
    var padding: CGFloat {
        switch self {
        case .small: return ICTheme.Layout.mediumPadding
        case .medium: return ICTheme.Layout.pagePadding
        case .large: return ICTheme.Layout.largePadding
        }
    }
}

// MARK: - ICButton

/// iCar 自定义按钮组件
/// 支持多种样式、尺寸和状态
struct ICButton: View {
    
    // MARK: - Properties
    
    let title: String
    let icon: String?
    let style: ICButtonStyle
    let size: ICButtonSize
    let isLoading: Bool
    let isFullWidth: Bool
    let action: () -> Void
    
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false
    
    // MARK: - Initialization
    
    init(
        title: String,
        icon: String? = nil,
        style: ICButtonStyle = .primary,
        size: ICButtonSize = .medium,
        isLoading: Bool = false,
        isFullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isFullWidth = isFullWidth
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            if !isLoading && isEnabled {
                action()
            }
        }) {
            HStack(spacing: ICTheme.Layout.spacingMedium) {
                if isLoading {
                    ICProgressView(size: .small, color: loadingIndicatorColor)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(size.font)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, size.padding)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: ICTheme.Layout.buttonCornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .cornerRadius(ICTheme.Layout.buttonCornerRadius)
            .opacity(opacity)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled || isLoading)
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
    
    // MARK: - Computed Properties
    
    private var foregroundColor: Color {
        guard isEnabled else { return ICTheme.Colors.gray }
        
        switch style {
        case .primary, .danger, .success:
            return .white
        case .secondary:
            return ICTheme.Colors.primary
        case .outline:
            return ICTheme.Colors.primary
        case .ghost:
            return ICTheme.Colors.primary
        }
    }
    
    private var backgroundColor: Color {
        guard isEnabled else { return ICTheme.Colors.gray5 }
        
        switch style {
        case .primary:
            return ICTheme.Colors.primary
        case .secondary:
            return ICTheme.Colors.primaryUltraLight
        case .outline:
            return .clear
        case .ghost:
            return .clear
        case .danger:
            return ICTheme.Colors.error
        case .success:
            return ICTheme.Colors.success
        }
    }
    
    private var borderColor: Color {
        guard isEnabled else { return .clear }
        
        switch style {
        case .outline:
            return ICTheme.Colors.primary
        default:
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .outline:
            return 1.5
        default:
            return 0
        }
    }
    
    private var opacity: Double {
        isLoading ? 0.8 : 1.0
    }
    
    private var loadingIndicatorColor: Color {
        switch style {
        case .primary, .danger, .success:
            return .white
        default:
            return ICTheme.Colors.primary
        }
    }
}

// MARK: - Icon Button

/// 图标按钮组件
struct ICIconButton: View {
    let icon: String
    let style: ICButtonStyle
    let size: ICButtonSize
    let action: () -> Void
    
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false
    
    init(
        icon: String,
        style: ICButtonStyle = .ghost,
        size: ICButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: size.height, height: size.height)
                .background(backgroundColor)
                .cornerRadius(ICTheme.Layout.smallCornerRadius)
                .opacity(isEnabled ? 1.0 : 0.5)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
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
    
    private var foregroundColor: Color {
        guard isEnabled else { return ICTheme.Colors.gray }
        
        switch style {
        case .primary, .danger, .success:
            return .white
        case .secondary, .outline, .ghost:
            return ICTheme.Colors.primary
        }
    }
    
    private var backgroundColor: Color {
        guard isEnabled else { return ICTheme.Colors.gray5 }
        
        switch style {
        case .primary:
            return ICTheme.Colors.primary
        case .secondary:
            return ICTheme.Colors.primaryUltraLight
        case .outline:
            return ICTheme.Colors.primary.opacity(0.1)
        case .ghost:
            return .clear
        case .danger:
            return ICTheme.Colors.error
        case .success:
            return ICTheme.Colors.success
        }
    }
}

// MARK: - Floating Action Button

/// 浮动操作按钮
struct ICFloatingButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: ICTheme.Layout.iconLarge, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(ICTheme.Colors.primary)
                .clipShape(Circle())
                .shadow(
                    color: ICTheme.Colors.primary.opacity(0.4),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .pressEvents {
            withAnimation(ICTheme.Animation.spring) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(ICTheme.Animation.spring) {
                isPressed = false
            }
        }
    }
}

// MARK: - Press Events Modifier

/// 按钮按下事件修饰符
struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onPress()
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Preview

#Preview("Button Styles") {
    ScrollView {
        VStack(spacing: ICTheme.Layout.spacingExtraLarge) {
            Group {
                ICButton(title: "主要按钮", action: {})
                ICButton(title: "次要按钮", style: .secondary, action: {})
                ICButton(title: "描边按钮", style: .outline, action: {})
                ICButton(title: "幽灵按钮", style: .ghost, action: {})
                ICButton(title: "危险按钮", style: .danger, action: {})
                ICButton(title: "成功按钮", style: .success, action: {})
            }
            
            Divider()
            
            Group {
                ICButton(title: "带图标", icon: "arrow.right", action: {})
                ICButton(title: "加载中", isLoading: true, action: {})
                ICButton(title: "禁用", action: {})
                    .disabled(true)
            }
            
            Divider()
            
            Group {
                ICButton(title: "小按钮", size: .small, action: {})
                ICButton(title: "中按钮", size: .medium, action: {})
                ICButton(title: "大按钮", size: .large, action: {})
            }
            
            Divider()
            
            HStack(spacing: ICTheme.Layout.spacingMedium) {
                ICIconButton(icon: "plus", action: {})
                ICIconButton(icon: "minus", style: .secondary, action: {})
                ICIconButton(icon: "trash", style: .danger, action: {})
                ICIconButton(icon: "checkmark", style: .success, action: {})
            }
            
            Divider()
            
            ICFloatingButton(icon: "plus") {}
        }
        .padding()
    }
}

import SwiftUI

// MARK: - Progress Size

/// 进度指示器尺寸
enum ICProgressSize {
    case small
    case medium
    case large
    
    var dimension: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 24
        case .large: return 32
        }
    }
    
    var strokeWidth: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 2.5
        case .large: return 3
        }
    }
}

// MARK: - ICProgressView

/// iCar 进度指示器组件
/// 支持多种样式和尺寸
struct ICProgressView: View {
    
    // MARK: - Properties
    
    let size: ICProgressSize
    let color: Color
    
    @State private var isAnimating = false
    
    // MARK: - Initialization
    
    init(
        size: ICProgressSize = .medium,
        color: Color = ICTheme.Colors.primary
    ) {
        self.size = size
        self.color = color
    }
    
    // MARK: - Body
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: size.strokeWidth,
                    lineCap: .round
                )
            )
            .frame(width: size.dimension, height: size.dimension)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(
                Animation.linear(duration: 1)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
            .onDisappear {
                isAnimating = false
            }
    }
}

// MARK: - ICLinearProgressView

/// 线性进度条组件
struct ICLinearProgressView: View {
    
    // MARK: - Properties
    
    let progress: Double
    let color: Color
    let backgroundColor: Color
    let height: CGFloat
    let showPercentage: Bool
    
    // MARK: - Initialization
    
    init(
        progress: Double,
        color: Color = ICTheme.Colors.primary,
        backgroundColor: Color = ICTheme.Colors.gray5,
        height: CGFloat = 8,
        showPercentage: Bool = false
    ) {
        self.progress = max(0, min(1, progress))
        self.color = color
        self.backgroundColor = backgroundColor
        self.height = height
        self.showPercentage = showPercentage
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(backgroundColor)
                    .frame(height: height)
                
                // 进度
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(progressColor)
                    .frame(width: geometry.size.width * progress, height: height)
                    .animation(ICTheme.Animation.standard, value: progress)
            }
        }
        .frame(height: height)
        .overlay(
            showPercentage ?
            Text("\(Int(progress * 100))%")
                .font(ICTheme.Typography.captionMedium)
                .foregroundColor(progress > 0.5 ? .white : ICTheme.Colors.textPrimary)
            : nil
        )
    }
    
    private var progressColor: Color {
        if progress >= 1.0 {
            return ICTheme.Colors.success
        } else if progress >= 0.6 {
            return color
        } else if progress >= 0.3 {
            return ICTheme.Colors.warning
        } else {
            return ICTheme.Colors.error
        }
    }
}

// MARK: - ICCircularProgressView

/// 环形进度条组件
struct ICCircularProgressView: View {
    
    // MARK: - Properties
    
    let progress: Double
    let size: ICProgressSize
    let color: Color
    let showPercentage: Bool
    let lineWidth: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    // MARK: - Initialization
    
    init(
        progress: Double,
        size: ICProgressSize = .large,
        color: Color = ICTheme.Colors.primary,
        showPercentage: Bool = true,
        lineWidth: CGFloat? = nil
    ) {
        self.progress = max(0, min(1, progress))
        self.size = size
        self.color = color
        self.showPercentage = showPercentage
        self.lineWidth = lineWidth ?? size.strokeWidth * 1.5
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(
                    ICTheme.Colors.gray5,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
            
            // 进度圆环
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(Angle(degrees: -90))
                .onAppear {
                    withAnimation(ICTheme.Animation.slow) {
                        animatedProgress = progress
                    }
                }
                .onChange(of: progress) { newValue in
                    withAnimation(ICTheme.Animation.slow) {
                        animatedProgress = newValue
                    }
                }
            
            // 百分比文字
            if showPercentage {
                VStack(spacing: 0) {
                    Text("\(Int(animatedProgress * 100))")
                        .font(size == .large ? ICTheme.Typography.title1 : ICTheme.Typography.title2)
                        .foregroundColor(ICTheme.Colors.textPrimary)
                    Text("%")
                        .font(ICTheme.Typography.caption)
                        .foregroundColor(ICTheme.Colors.textSecondary)
                }
            }
        }
        .frame(width: size.dimension * 3, height: size.dimension * 3)
    }
    
    private var progressColor: Color {
        if progress >= 1.0 {
            return ICTheme.Colors.success
        } else if progress >= 0.6 {
            return color
        } else if progress >= 0.3 {
            return ICTheme.Colors.warning
        } else {
            return ICTheme.Colors.error
        }
    }
}

// MARK: - ICStepProgressView

/// 步骤进度组件
struct ICStepProgressView: View {
    
    // MARK: - Properties
    
    let steps: [String]
    let currentStep: Int
    let color: Color
    
    // MARK: - Initialization
    
    init(
        steps: [String],
        currentStep: Int,
        color: Color = ICTheme.Colors.primary
    ) {
        self.steps = steps
        self.currentStep = currentStep
        self.color = color
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 0) {
                    // 步骤圆圈
                    ZStack {
                        Circle()
                            .fill(stepBackgroundColor(for: index))
                            .frame(width: 28, height: 28)
                        
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(ICTheme.Typography.captionMedium)
                                .foregroundColor(stepForegroundColor(for: index))
                        }
                    }
                    
                    // 步骤标题
                    Text(step)
                        .font(ICTheme.Typography.caption)
                        .foregroundColor(stepTitleColor(for: index))
                        .padding(.leading, 6)
                    
                    // 连接线
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(lineColor(for: index))
                            .frame(height: 2)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }
    
    private func stepBackgroundColor(for index: Int) -> Color {
        if index < currentStep {
            return ICTheme.Colors.success
        } else if index == currentStep {
            return color
        } else {
            return ICTheme.Colors.gray5
        }
    }
    
    private func stepForegroundColor(for index: Int) -> Color {
        if index <= currentStep {
            return .white
        } else {
            return ICTheme.Colors.gray
        }
    }
    
    private func stepTitleColor(for index: Int) -> Color {
        if index < currentStep {
            return ICTheme.Colors.success
        } else if index == currentStep {
            return color
        } else {
            return ICTheme.Colors.textSecondary
        }
    }
    
    private func lineColor(for index: Int) -> Color {
        if index < currentStep {
            return ICTheme.Colors.success
        } else {
            return ICTheme.Colors.gray5
        }
    }
}

// MARK: - ICSkeletonView

/// 骨架屏组件
struct ICSkeletonView: View {
    
    // MARK: - Properties
    
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isAnimating = false
    
    // MARK: - Initialization
    
    init(
        width: CGFloat? = nil,
        height: CGFloat = 16,
        cornerRadius: CGFloat = 4
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    // MARK: - Body
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(ICTheme.Colors.gray5)
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Preview

#Preview("Progress Views") {
    ScrollView {
        VStack(spacing: ICTheme.Layout.spacingExtraLarge) {
            Group {
                Text("加载指示器").font(ICTheme.Typography.title2)
                
                HStack(spacing: ICTheme.Layout.spacingExtraLarge) {
                    ICProgressView(size: .small)
                    ICProgressView(size: .medium)
                    ICProgressView(size: .large)
                }
                
                HStack(spacing: ICTheme.Layout.spacingExtraLarge) {
                    ICProgressView(size: .medium, color: ICTheme.Colors.success)
                    ICProgressView(size: .medium, color: ICTheme.Colors.warning)
                    ICProgressView(size: .medium, color: ICTheme.Colors.error)
                }
            }
            
            Divider()
            
            Group {
                Text("线性进度条").font(ICTheme.Typography.title2)
                
                ICLinearProgressView(progress: 0.25)
                ICLinearProgressView(progress: 0.5)
                ICLinearProgressView(progress: 0.75)
                ICLinearProgressView(progress: 1.0)
                
                ICLinearProgressView(progress: 0.65, showPercentage: true)
                    .frame(height: 20)
            }
            
            Divider()
            
            Group {
                Text("环形进度条").font(ICTheme.Typography.title2)
                
                HStack(spacing: ICTheme.Layout.spacingExtraLarge) {
                    ICCircularProgressView(progress: 0.25)
                    ICCircularProgressView(progress: 0.65, color: ICTheme.Colors.success)
                    ICCircularProgressView(progress: 0.9, color: ICTheme.Colors.warning)
                }
            }
            
            Divider()
            
            Group {
                Text("步骤进度").font(ICTheme.Typography.title2)
                
                ICStepProgressView(
                    steps: ["提交", "审核", "完成"],
                    currentStep: 1
                )
                
                ICStepProgressView(
                    steps: ["选择", "确认", "支付", "完成"],
                    currentStep: 2,
                    color: ICTheme.Colors.success
                )
            }
            
            Divider()
            
            Group {
                Text("骨架屏").font(ICTheme.Typography.title2)
                
                VStack(spacing: ICTheme.Layout.spacingMedium) {
                    ICSkeletonView(width: 200, height: 20, cornerRadius: 4)
                    ICSkeletonView(width: 150, height: 16, cornerRadius: 4)
                    ICSkeletonView(height: 100, cornerRadius: ICTheme.Layout.cardCornerRadius)
                }
            }
        }
        .padding()
    }
}

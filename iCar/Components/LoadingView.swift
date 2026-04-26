import SwiftUI

// MARK: - Tesla Style Loading View

struct TeslaLoadingView: View {
    let message: String
    let progress: Double?
    
    var body: some View {
        VStack(spacing: TeslaDesignSystem.Layout.spacingLG) {
            // 进度指示器
            if let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(TeslaProgressStyle())
                    .frame(width: 200)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: TeslaDesignSystem.Colors.accent))
                    .scaleEffect(1.5)
            }
            
            // 提示文字
            Text(message)
                .font(TeslaDesignSystem.Typography.body)
                .foregroundColor(TeslaDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(TeslaDesignSystem.Layout.spacingXL)
        .background(TeslaDesignSystem.Colors.surface)
        .cornerRadius(TeslaDesignSystem.Layout.radiusLG)
        .shadow(color: TeslaDesignSystem.Colors.accent.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Tesla Progress Style

struct TeslaProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: 4)
                    .fill(TeslaDesignSystem.Colors.surfaceElevated)
                    .frame(height: 8)
                
                // 进度
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [TeslaDesignSystem.Colors.accent, TeslaDesignSystem.Colors.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: CGFloat(configuration.fractionCompleted ?? 0) * geometry.size.width, height: 8)
                    .animation(TeslaDesignSystem.Animations.easeInOut, value: configuration.fractionCompleted)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Skeleton Loading View

struct SkeletonLoadingView: View {
    var body: some View {
        VStack(spacing: TeslaDesignSystem.Layout.spacingMD) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: TeslaDesignSystem.Layout.radiusMD)
                    .fill(TeslaDesignSystem.Colors.surfaceElevated)
                    .frame(height: 80)
                    .shimmer()
            }
        }
        .padding(TeslaDesignSystem.Layout.paddingScreen)
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            TeslaDesignSystem.Colors.textPrimary.opacity(0.1),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Empty State View

struct TeslaEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: TeslaDesignSystem.Layout.spacingLG) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(TeslaDesignSystem.Colors.textSecondary)
            
            Text(title)
                .font(TeslaDesignSystem.Typography.headline)
                .foregroundColor(TeslaDesignSystem.Colors.textPrimary)
            
            Text(message)
                .font(TeslaDesignSystem.Typography.body)
                .foregroundColor(TeslaDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(TeslaDesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, TeslaDesignSystem.Layout.paddingButton)
                        .padding(.vertical, 12)
                        .background(TeslaDesignSystem.Colors.accent)
                        .cornerRadius(TeslaDesignSystem.Layout.radiusFull)
                }
                .padding(.top, TeslaDesignSystem.Layout.spacingMD)
            }
        }
        .padding(TeslaDesignSystem.Layout.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View

struct TeslaErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: TeslaDesignSystem.Layout.spacingLG) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(TeslaDesignSystem.Colors.warning)
            
            Text("出错了")
                .font(TeslaDesignSystem.Typography.headline)
                .foregroundColor(TeslaDesignSystem.Colors.textPrimary)
            
            Text(error.localizedDescription)
                .font(TeslaDesignSystem.Typography.body)
                .foregroundColor(TeslaDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(TeslaDesignSystem.Typography.body)
                    .fontWeight(.semibold)
            }
            .teslaButton(isPrimary: true)
            .padding(.top, TeslaDesignSystem.Layout.spacingMD)
        }
        .padding(TeslaDesignSystem.Layout.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

struct LoadingComponents_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            TeslaDesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                TeslaLoadingView(message: "正在分析...", progress: 0.6)
                
                TeslaEmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "暂无历史记录",
                    message: "开始您的第一次车辆检测吧",
                    actionTitle: "开始检测",
                    action: {}
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

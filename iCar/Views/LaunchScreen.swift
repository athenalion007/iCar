import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false
    @State private var progress: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 纯黑背景
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Logo 动画
                ZStack {
                    // 外圈
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 120, height: 120)
                    
                    // 进度圈
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.5), value: progress)
                    
                    // 中心图标
                    Image(systemName: "car.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.5)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                // App 名称
                Text("iCar")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // 副标题
                Text("智能车况诊断")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .tracking(2)
                
                Spacer()
                
                // 底部版本信息
                VStack(spacing: 4) {
                    Text("版本 1.0.0")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("© 2025 iCar Team")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.4))
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isAnimating = true
            progress = 1.0
        }
    }
}

// MARK: - Launch Screen Controller

struct LaunchScreenController: View {
    @State private var isLoading = true
    @State private var showMainApp = false
    
    var body: some View {
        ZStack {
            if showMainApp {
                MainTabView()
                    .transition(.opacity)
            } else {
                LaunchScreen()
                    .opacity(isLoading ? 1 : 0)
            }
        }
        .onAppear {
            // 模拟启动加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isLoading = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showMainApp = true
                    }
                }
            }
        }
    }
}

#Preview("Launch Screen") {
    LaunchScreen()
}

#Preview("Launch Controller") {
    LaunchScreenController()
}

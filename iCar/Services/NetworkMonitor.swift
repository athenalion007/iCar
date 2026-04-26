import Foundation
import Network
import Combine
import SwiftUI

// MARK: - Network Monitor

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false
    
    private let monitor = NWPathMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path: path)
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    private func updateConnectionStatus(path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        
        switch path.usesInterfaceType(.wifi) {
        case true:
            connectionType = .wifi
        case false:
            if path.usesInterfaceType(.cellular) {
                connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionType = .ethernet
            } else {
                connectionType = .unknown
            }
        }
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

// MARK: - Retry Handler

class RetryHandler: @unchecked Sendable {
    static let shared = RetryHandler()
    
    private init() {}
    
    /// 带重试的异步操作
    func retry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxAttempts {
                    let waitTime = delay * pow(2.0, Double(attempt - 1)) // 指数退避
                    try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AppError.networkError("重试失败")
    }
    
    /// 带超时的异步操作
    func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AppError.timeoutError
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Loading State Manager

@MainActor
class LoadingStateManager: ObservableObject {
    static let shared = LoadingStateManager()
    
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var loadingProgress: Double = 0
    
    private init() {}
    
    func startLoading(message: String = "加载中...") {
        isLoading = true
        loadingMessage = message
        loadingProgress = 0
    }
    
    func updateProgress(_ progress: Double) {
        loadingProgress = min(max(progress, 0), 1)
    }
    
    func stopLoading() {
        isLoading = false
        loadingMessage = ""
        loadingProgress = 0
    }
}

// MARK: - Loading View Modifier

struct LoadingOverlay: ViewModifier {
    @StateObject private var loadingManager = LoadingStateManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if loadingManager.isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text(loadingManager.loadingMessage)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            if loadingManager.loadingProgress > 0 {
                                ProgressView(value: loadingManager.loadingProgress)
                                    .frame(width: 200)
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
            }
    }
}

extension View {
    func withLoadingOverlay() -> some View {
        modifier(LoadingOverlay())
    }
}

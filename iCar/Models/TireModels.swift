import SwiftUI

// MARK: - Wear Pattern Type

enum WearPatternType: String, CaseIterable, Identifiable, Codable {
    case normal = "normal"
    case uneven = "uneven"
    case feathering = "feathering"
    case cupping = "cupping"
    case scalloping = "scalloping"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal: return "正常磨损"
        case .uneven: return "偏磨"
        case .feathering: return "羽状磨损"
        case .cupping: return "杯状磨损"
        case .scalloping: return "锯齿磨损"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .uneven: return "arrow.left.and.right.circle.fill"
        case .feathering: return "wave.3.right.circle.fill"
        case .cupping: return "circle.dotted.circle.fill"
        case .scalloping: return "chart.bar.fill"
        }
    }

    var color: Color {
        switch self {
        case .normal: return ICTheme.Colors.success
        case .uneven: return ICTheme.Colors.warning
        case .feathering: return ICTheme.Colors.warning
        case .cupping: return ICTheme.Colors.error
        case .scalloping: return ICTheme.Colors.warning
        }
    }

    var description: String {
        switch self {
        case .normal:
            return "轮胎磨损均匀，花纹深度一致，属于正常磨损状态。"
        case .uneven:
            return "轮胎一侧磨损比另一侧严重，可能是轮胎定位不准或悬挂系统问题。"
        case .feathering:
            return "花纹边缘呈现锯齿状，通常是前束角不正确导致。"
        case .cupping:
            return "轮胎表面出现不规则凹陷，可能是减震器故障或轮胎不平衡。"
        case .scalloping:
            return "轮胎出现波浪状磨损，可能是轮胎气压不足或悬挂部件松动。"
        }
    }

    var recommendation: String {
        switch self {
        case .normal:
            return "继续保持良好的驾驶习惯和定期检查。"
        case .uneven:
            return "建议进行四轮定位检查，调整轮胎角度。"
        case .feathering:
            return "建议检查并调整前束角，必要时进行轮胎换位。"
        case .cupping:
            return "建议检查减震器和轮胎平衡，必要时更换减震器。"
        case .scalloping:
            return "建议检查轮胎气压和悬挂系统，确保各部件紧固。"
        }
    }
}

// MARK: - Tire Health Status

enum TireHealthStatus: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .excellent: return "极佳"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        case .critical: return "危险"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return Color(hex: "#00C853")
        case .good: return ICTheme.Colors.success
        case .fair: return ICTheme.Colors.warning
        case .poor: return ICTheme.Colors.error
        case .critical: return Color(hex: "#B71C1C")
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "star.circle.fill"
        case .good: return "checkmark.shield.fill"
        case .fair: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.octagon.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

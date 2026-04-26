import SwiftUI

// MARK: - Content View
// 应用入口，使用启动屏 + Tab导航

struct ContentView: View {
    var body: some View {
        LaunchScreenController()
    }
}

// MARK: - Feature Module

enum FeatureModule: String, CaseIterable, Identifiable, Hashable {
    case engineEar = "EngineEar"
    case tireTread = "TireTread"
    case paintScan = "PaintScan"
    case suspensionIQ = "SuspensionIQ"
    case acDoctor = "ACDoctor"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .engineEar: return "引擎听诊"
        case .tireTread: return "轮胎检测"
        case .paintScan: return "漆面扫描"
        case .suspensionIQ: return "悬挂监测"
        case .acDoctor: return "空调诊断"
        }
    }
    
    var icon: String {
        switch self {
        case .engineEar: return "gearshape.2"
        case .tireTread: return "circle.hexagongrid"
        case .paintScan: return "paintbrush.fill"
        case .suspensionIQ: return "waveform.path.ecg"
        case .acDoctor: return "snowflake"
        }
    }
    
    var description: String {
        switch self {
        case .engineEar: return "AI分析发动机声音，检测潜在故障"
        case .tireTread: return "拍摄轮胎照片，测量胎纹深度"
        case .paintScan: return "扫描车身漆面，识别划痕损伤"
        case .suspensionIQ: return "分析行驶数据，评估悬挂系统"
        case .acDoctor: return "全面检测空调系统运行状态"
        }
    }
}

// MARK: - Minimal Feature Row

struct MinimalFeatureRow: View {
    let module: FeatureModule

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: module.icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(module.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(module.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(module.displayName)
        .accessibilityHint(module.description)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

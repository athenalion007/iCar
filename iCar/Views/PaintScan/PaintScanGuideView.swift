import SwiftUI

// MARK: - Paint Scan Position

enum PaintScanPosition: String, CaseIterable, Identifiable, Codable {
    case front = "front"
    case rear = "rear"
    case leftFront = "left_front"
    case leftRear = "left_rear"
    case rightFront = "right_front"
    case rightRear = "right_rear"
    case roof = "roof"
    case hood = "hood"
    case trunk = "trunk"
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .front: return "车头正面"
        case .rear: return "车尾正面"
        case .leftFront: return "左前45°"
        case .leftRear: return "左后45°"
        case .rightFront: return "右前45°"
        case .rightRear: return "右后45°"
        case .roof: return "车顶"
        case .hood: return "引擎盖"
        case .trunk: return "后备箱"
        }
    }
    
    var icon: String {
        switch self {
        case .front: return "car.side.front.open.fill"
        case .rear: return "car.side.rear.open.fill"
        case .leftFront: return "arrow.up.left"
        case .leftRear: return "arrow.down.left"
        case .rightFront: return "arrow.up.right"
        case .rightRear: return "arrow.down.right"
        case .roof: return "rectangle.topthird.inset.filled"
        case .hood: return "rectangle.inset.filled"
        case .trunk: return "archivebox.fill"
        }
    }
    
    var description: String {
        switch self {
        case .front:
            return "正对车头，拍摄整个前脸区域，包括大灯、格栅、保险杠"
        case .rear:
            return "正对车尾，拍摄整个尾部区域，包括尾灯、后保险杠"
        case .leftFront:
            return "站在车辆左前方45°角，拍摄左前翼子板和左前门"
        case .leftRear:
            return "站在车辆左后方45°角，拍摄左后翼子板和左后门"
        case .rightFront:
            return "站在车辆右前方45°角，拍摄右前翼子板和右前门"
        case .rightRear:
            return "站在车辆右后方45°角，拍摄右后翼子板和右后门"
        case .roof:
            return "从上方拍摄车顶全景，确保天窗和车顶漆面完整可见"
        case .hood:
            return "俯拍引擎盖，确保整个引擎盖漆面在画面中"
        case .trunk:
            return "俯拍后备箱盖，确保整个后备箱漆面在画面中"
        }
    }
    
    var sampleImageName: String {
        return "car.position.\(rawValue)"
    }
    
    var isRequired: Bool {
        switch self {
        case .front, .rear, .leftFront, .leftRear, .rightFront, .rightRear:
            return true
        case .roof, .hood, .trunk:
            return false
        }
    }
}

// MARK: - Paint Scan Guide View

struct PaintScanGuideView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: PaintScanViewModel
    @State private var selectedPosition: PaintScanPosition?
    @State private var showPhotoPreview = false
    
    var onStartScan: (() -> Void)?
    var onViewResults: (() -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 进度卡片
                progressCard
                
                // 拍摄位置列表
                positionsSection
                
                // 已拍摄照片预览
                if !viewModel.capturedPhotos.isEmpty {
                    capturedPhotosSection
                }
                
                // 底部按钮
                bottomActions
            }
            .padding(20)
        }
        .background(.black)
        .navigationTitle("漆面检测")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedPosition) { position in
            PositionDetailSheet(
                position: position,
                isCompleted: viewModel.isPositionCompleted(position),
                onStartCapture: {
                    viewModel.currentPosition = position
                    onStartScan?()
                }
            )
        }
    }
    
    // MARK: - Progress Card
    
    private var progressCard: some View {
        VStack(spacing: 24) {
            // 进度标题
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("拍摄进度")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("\(viewModel.completedPositions.count)/\(PaintScanPosition.allCases.count) 个位置")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 进度百分比
                ZStack {
                    Circle()
                        .stroke(.blue.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.progressPercentage)
                        .stroke(.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progressPercentage)
                    
                    Text("\(Int(viewModel.progressPercentage * 100))%")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * viewModel.progressPercentage, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progressPercentage)
                }
            }
            .frame(height: 8)
            
            // 状态提示
            HStack(spacing: 16) {
                PaintScanStatusBadge(
                    count: viewModel.completedPositions.count,
                    label: "已完成",
                    color: .green
                )
                
                PaintScanStatusBadge(
                    count: viewModel.pendingPositions.count,
                    label: "待拍摄",
                    color: .orange
                )
                
                if viewModel.hasRequiredPositionsCompleted {
                    PaintScanStatusBadge(
                        count: 0,
                        label: "可提交",
                        color: .blue
                    )
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.2))
        .cardStyle()
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .blue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Positions Section
    
    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("拍摄位置")
                .font(.title3)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(PaintScanPosition.allCases) { position in
                    PositionCard(
                        position: position,
                        isCompleted: viewModel.isPositionCompleted(position),
                        isRequired: position.isRequired
                    ) {
                        selectedPosition = position
                    }
                }
            }
        }
    }
    
    // MARK: - Captured Photos Section
    
    private var capturedPhotosSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("已拍摄照片")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showPhotoPreview = true
                }) {
                    Text("查看全部")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.capturedPhotos) { photo in
                        CapturedPhotoThumbnail(photo: photo) {
                            // 查看照片详情
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPhotoPreview) {
            PhotoPreviewSheet(photos: viewModel.capturedPhotos) { photo in
                viewModel.removePhoto(photo)
            }
        }
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        VStack(spacing: 16) {
            // 开始拍摄按钮
            ICButton(
                title: viewModel.hasRequiredPositionsCompleted ? "继续拍摄" : "开始拍摄",
                icon: "camera.fill",
                style: .primary,
                size: .large
            ) {
                viewModel.currentPosition = viewModel.nextPendingPosition
                onStartScan?()
            }
            
            // 查看结果按钮（完成必需位置后显示）
            if viewModel.hasRequiredPositionsCompleted {
                ICButton(
                    title: "查看检测结果",
                    icon: "doc.text.magnifyingglass",
                    style: .secondary,
                    size: .medium
                ) {
                    onViewResults?()
                }
            }
        }
    }
}

// MARK: - Position Card

struct PositionCard: View {
    let position: PaintScanPosition
    let isCompleted: Bool
    let isRequired: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(isCompleted ? .green.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: position.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(position.name)
                            .font(.body)
                            .foregroundColor(.white)
                        
                        if isRequired {
                            Text("必拍")
                                .font(.caption2)
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(2)
                        }
                    }
                    
                    Text(isCompleted ? "已完成" : "待拍摄")
                        .font(.caption)
                        .foregroundColor(isCompleted ? .green : .gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.gray.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCompleted ? .green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Status Badge

struct PaintScanStatusBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text("\(count) \(label)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Captured Photo Thumbnail

struct CapturedPhotoThumbnail: View {
    let photo: CapturedPhoto
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(photo.position.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: 120)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Position Detail Sheet

struct PositionDetailSheet: View {
    let position: PaintScanPosition
    let isCompleted: Bool
    let onStartCapture: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // 位置示意图
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.gray)
                            .frame(height: 200)
                        
                        Image(systemName: "car.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.gray)
                        
                        // 位置标记
                        PositionIndicator(position: position)
                    }
                    
                    // 说明文字
                    VStack(alignment: .leading, spacing: 16) {
                        Text("拍摄说明")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(position.description)
                            .font(.body)
                            .foregroundColor(.gray)
                            .lineSpacing(4)
                        
                        // 拍摄要点
                        VStack(alignment: .leading, spacing: 8) {
                            RequirementRow(icon: "sun.max.fill", text: "确保光线充足，避免阴影")
                            RequirementRow(icon: "hand.raised.fill", text: "保持手机稳定，避免模糊")
                            RequirementRow(icon: "arrow.up.and.down", text: "漆面与镜头保持垂直")
                            RequirementRow(icon: "eye.fill", text: "确保漆面在画面中央")
                        }
                        .padding(.top, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    // 操作按钮
                    VStack(spacing: 16) {
                        ICButton(
                            title: isCompleted ? "重新拍摄" : "开始拍摄",
                            icon: "camera.fill",
                            style: .primary,
                            size: .large
                        ) {
                            dismiss()
                            onStartCapture()
                        }
                        
                        if isCompleted {
                            ICButton(
                                title: "保持现有照片",
                                style: .ghost,
                                size: .medium
                            ) {
                                dismiss()
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(position.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Position Indicator

struct PositionIndicator: View {
    let position: PaintScanPosition
    
    var body: some View {
        let offset = indicatorOffset
        
        ZStack {
            Circle()
                .fill(.blue.opacity(0.3))
                .frame(width: 60, height: 60)
            
            Circle()
                .fill(.blue)
                .frame(width: 40, height: 40)
            
            Image(systemName: position.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
        .offset(x: offset.x, y: offset.y)
    }
    
    private var indicatorOffset: CGPoint {
        switch position {
        case .front:
            return CGPoint(x: 0, y: 50)
        case .rear:
            return CGPoint(x: 0, y: -50)
        case .leftFront:
            return CGPoint(x: -60, y: 30)
        case .leftRear:
            return CGPoint(x: -60, y: -30)
        case .rightFront:
            return CGPoint(x: 60, y: 30)
        case .rightRear:
            return CGPoint(x: 60, y: -30)
        case .roof:
            return CGPoint(x: 0, y: 0)
        case .hood:
            return CGPoint(x: 0, y: 25)
        case .trunk:
            return CGPoint(x: 0, y: -25)
        }
    }
}

// MARK: - Requirement Row

struct RequirementRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

// MARK: - Photo Preview Sheet

struct PhotoPreviewSheet: View {
    let photos: [CapturedPhoto]
    let onDelete: (CapturedPhoto) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ForEach(photos) { photo in
                        PhotoGridItem(photo: photo) {
                            onDelete(photo)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("已拍摄照片 (\(photos.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Photo Grid Item

struct PhotoGridItem: View {
    let photo: CapturedPhoto
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .offset(x: 4, y: -4)
            }
            
            Text(photo.position.name)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(photo.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .alert("删除照片", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除这张照片吗？")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        PaintScanGuideView(viewModel: PaintScanViewModel())
    }
}

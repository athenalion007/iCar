import SwiftUI

// MARK: - Vehicle Management View

struct VehicleManagementView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataService = DataPersistenceService.shared
    
    // MARK: - State
    
    @State private var showingAddVehicle = false
    @State private var showingEditVehicle = false
    @State private var selectedVehicle: CDVehicle?
    @State private var showingDeleteConfirmation = false
    @State private var vehicleToDelete: CDVehicle?
    @State private var searchText = ""
    @State private var selectedStatusFilter: CarStatus?
    
    // MARK: - Computed Properties
    
    var filteredVehicles: [CDVehicle] {
        var vehicles = dataService.vehicles
        
        // 搜索过滤
        if !searchText.isEmpty {
            vehicles = vehicles.filter { vehicle in
                vehicle.displayName.localizedCaseInsensitiveContains(searchText) ||
                (vehicle.licensePlate ?? "").localizedCaseInsensitiveContains(searchText) ||
                (vehicle.vin ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 状态过滤
        if let status = selectedStatusFilter {
            vehicles = vehicles.filter { $0.statusEnum == status }
        }
        
        return vehicles
    }
    
    var vehicleStatistics: (total: Int, active: Int, maintenance: Int, inactive: Int) {
        let total = dataService.vehicles.count
        let active = dataService.vehicles.filter { $0.statusEnum == .active }.count
        let maintenance = dataService.vehicles.filter { $0.statusEnum == .maintenance }.count
        let inactive = dataService.vehicles.filter { $0.statusEnum == .inactive || $0.statusEnum == .sold }.count
        return (total, active, maintenance, inactive)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 统计卡片
                statisticsSection
                
                // 搜索和过滤
                searchAndFilterSection
                
                // 车辆列表
                vehicleListSection
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("车辆管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddVehicle = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddEditVehicleView(mode: .add)
            }
            .sheet(isPresented: $showingEditVehicle) {
                if let vehicle = selectedVehicle {
                    AddEditVehicleView(mode: .edit(vehicle))
                }
            }
            .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let vehicle = vehicleToDelete {
                        deleteVehicle(vehicle)
                    }
                }
            } message: {
                Text("删除后，该车辆的所有相关数据（检测报告、维护记录）也将被删除。此操作无法撤销。")
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                VehicleStatCard(
                    title: "全部车辆",
                    value: "\(vehicleStatistics.total)",
                    icon: "car.2.fill",
                    color: .blue
                )
                
                VehicleStatCard(
                    title: "正常使用",
                    value: "\(vehicleStatistics.active)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                VehicleStatCard(
                    title: "维修中",
                    value: "\(vehicleStatistics.maintenance)",
                    icon: "wrench.fill",
                    color: .orange
                )
                
                VehicleStatCard(
                    title: "停用",
                    value: "\(vehicleStatistics.inactive)",
                    icon: "pause.circle.fill",
                    color: .gray
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 8) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索车辆", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemFill))
            .cornerRadius(10)
            
            // 状态过滤器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "全部",
                        isSelected: selectedStatusFilter == nil
                    ) {
                        selectedStatusFilter = nil
                    }
                    
                    ForEach(CarStatus.allCases, id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: selectedStatusFilter == status
                        ) {
                            selectedStatusFilter = status
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Vehicle List Section
    
    private var vehicleListSection: some View {
        List {
            if filteredVehicles.isEmpty {
                Section {
                    EmptyStateView(
                        icon: "car",
                        title: "暂无车辆",
                        message: searchText.isEmpty ? "点击右上角添加您的第一辆车" : "没有找到匹配的车辆"
                    )
                }
            } else {
                Section(header: Text("共 \(filteredVehicles.count) 辆车")) {
                    ForEach(filteredVehicles, id: \.id) { vehicle in
                        VehicleRow(vehicle: vehicle)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVehicle = vehicle
                                showingEditVehicle = true
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    vehicleToDelete = vehicle
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    selectedVehicle = vehicle
                                    showingEditVehicle = true
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await dataService.loadAllData()
        }
    }
    
    // MARK: - Actions
    
    private func deleteVehicle(_ vehicle: CDVehicle) {
        Task {
            do {
                try await dataService.deleteVehicle(vehicle)
            } catch {
                print("Failed to delete vehicle: \(error)")
            }
        }
    }
}

// MARK: - Vehicle Row

struct VehicleRow: View {
    let vehicle: CDVehicle
    
    var body: some View {
        HStack(spacing: 12) {
            // 车辆图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "car.fill")
                    .font(.title3)
                    .foregroundColor(statusColor)
            }
            
            // 车辆信息
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(vehicle.licensePlate ?? "", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(vehicle.formattedMileage, systemImage: "speedometer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    VehicleStatusBadge(status: vehicle.statusEnum)
                    
                    if vehicle.year > 0 {
                        Text("\(vehicle.year)款")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // 箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch vehicle.statusEnum {
        case .active:
            return .green
        case .maintenance:
            return .orange
        case .inactive:
            return .gray
        case .sold:
            return .red
        }
    }
}

// MARK: - Status Badge

struct VehicleStatusBadge: View {
    let status: CarStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .maintenance:
            return .orange
        case .inactive:
            return .gray
        case .sold:
            return .red
        }
    }
}

// MARK: - Stat Card

struct VehicleStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .frame(width: 110, height: 90)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                .cornerRadius(16)
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Add/Edit Vehicle View

struct AddEditVehicleView: View {
    
    enum Mode {
        case add
        case edit(CDVehicle)
    }
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataService = DataPersistenceService.shared
    
    // MARK: - Properties
    
    let mode: Mode
    
    // MARK: - State
    
    @State private var brand = ""
    @State private var model = ""
    @State private var year = ""
    @State private var licensePlate = ""
    @State private var mileage = ""
    @State private var fuelLevel: Double = 100
    @State private var color = "白色"
    @State private var vin = ""
    @State private var status: CarStatus = .active
    @State private var showingColorPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // MARK: - Computed Properties
    
    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    var title: String {
        isEditing ? "编辑车辆" : "添加车辆"
    }
    
    var isValid: Bool {
        !brand.isEmpty && !model.isEmpty && !licensePlate.isEmpty && !year.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本信息
                Section(header: Text("基本信息")) {
                    TextField("品牌", text: $brand)
                    TextField("型号", text: $model)
                    TextField("年份", text: $year)
                        .keyboardType(.numberPad)
                    TextField("车牌号", text: $licensePlate)
                        .autocapitalization(.allCharacters)
                }
                
                // 车辆状态
                Section(header: Text("车辆状态")) {
                    Picker("状态", selection: $status) {
                        ForEach(CarStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    
                    HStack {
                        Text("油量")
                        Spacer()
                        Text("\(Int(fuelLevel))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $fuelLevel, in: 0...100, step: 1)
                }
                
                // 详细信息
                Section(header: Text("详细信息")) {
                    HStack {
                        Text("颜色")
                        Spacer()
                        Text(color)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingColorPicker = true
                    }
                    
                    TextField("里程数 (km)", text: $mileage)
                        .keyboardType(.decimalPad)
                    
                    TextField("VIN码", text: $vin)
                        .autocapitalization(.allCharacters)
                }
                
                // 删除按钮（仅编辑模式）
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            deleteVehicle()
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除车辆")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveVehicle()
                    }
                    .disabled(!isValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingColorPicker) {
                ColorPickerView(selectedColor: $color)
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "保存失败")
            }
            .onAppear {
                loadExistingData()
            }
        }
    }
    
    // MARK: - Methods
    
    private func loadExistingData() {
        if case .edit(let vehicle) = mode {
            brand = vehicle.brand ?? ""
            model = vehicle.model ?? ""
            year = String(vehicle.year)
            licensePlate = vehicle.licensePlate ?? ""
            mileage = String(vehicle.mileage)
            fuelLevel = vehicle.fuelLevel
            color = vehicle.color ?? "白色"
            vin = vehicle.vin ?? ""
            status = vehicle.statusEnum
        }
    }
    
    private func saveVehicle() {
        isSaving = true
        
        Task {
            do {
                let yearValue = Int16(year) ?? 2024
                let mileageValue = Double(mileage) ?? 0
                
                if case .edit(let vehicle) = mode {
                    vehicle.brand = brand
                    vehicle.model = model
                    vehicle.year = yearValue
                    vehicle.licensePlate = licensePlate
                    vehicle.mileage = mileageValue
                    vehicle.fuelLevel = fuelLevel
                    vehicle.color = color
                    vehicle.vin = vin
                    vehicle.status = status.rawValue
                    
                    try await dataService.updateVehicle(vehicle)
                } else {
                    _ = try await dataService.createVehicle(
                        brand: brand,
                        model: model,
                        year: yearValue,
                        licensePlate: licensePlate,
                        mileage: mileageValue,
                        fuelLevel: fuelLevel,
                        color: color,
                        vin: vin,
                        status: status.rawValue
                    )
                }
                
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                isSaving = false
            }
        }
    }
    
    private func deleteVehicle() {
        if case .edit(let vehicle) = mode {
            Task {
                do {
                    try await dataService.deleteVehicle(vehicle)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Color Picker View

struct ColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: String
    
    let colors = [
        "白色", "黑色", "银色", "灰色", "红色", "蓝色",
        "绿色", "黄色", "橙色", "棕色", "金色", "紫色"
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(colors, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                        dismiss()
                    }) {
                        HStack {
                            Circle()
                                .fill(colorFromName(color))
                                .frame(width: 24, height: 24)
                            
                            Text(color)
                            
                            Spacer()
                            
                            if color == selectedColor {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择颜色")
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
    
    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "白色": return .white
        case "黑色": return .black
        case "银色": return .gray
        case "灰色": return .gray
        case "红色": return .red
        case "蓝色": return .blue
        case "绿色": return .green
        case "黄色": return .yellow
        case "橙色": return .orange
        case "棕色": return .brown
        case "金色": return .yellow
        case "紫色": return .purple
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VehicleManagementView()
}

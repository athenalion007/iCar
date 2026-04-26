import Foundation

struct Car: Identifiable, Codable, Equatable {
    let id: UUID
    var brand: String
    var model: String
    var year: Int
    var licensePlate: String
    var mileage: Double
    var fuelLevel: Double
    var lastMaintenanceDate: Date?
    var nextMaintenanceDate: Date?
    var status: CarStatus
    var color: String
    var vin: String
    
    init(
        id: UUID = UUID(),
        brand: String,
        model: String,
        year: Int,
        licensePlate: String,
        mileage: Double = 0,
        fuelLevel: Double = 100,
        lastMaintenanceDate: Date? = nil,
        nextMaintenanceDate: Date? = nil,
        status: CarStatus = .active,
        color: String = "白色",
        vin: String = ""
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.year = year
        self.licensePlate = licensePlate
        self.mileage = mileage
        self.fuelLevel = fuelLevel
        self.lastMaintenanceDate = lastMaintenanceDate
        self.nextMaintenanceDate = nextMaintenanceDate
        self.status = status
        self.color = color
        self.vin = vin
    }
    
    var displayName: String {
        "\(brand) \(model)"
    }
    
    var formattedMileage: String {
        String(format: "%.1f km", mileage)
    }
    
    var formattedFuelLevel: String {
        String(format: "%.0f%%", fuelLevel)
    }
}

enum CarStatus: String, Codable, CaseIterable {
    case active = "active"
    case maintenance = "maintenance"
    case inactive = "inactive"
    case sold = "sold"
    
    var displayName: String {
        switch self {
        case .active:
            return "正常使用"
        case .maintenance:
            return "维修中"
        case .inactive:
            return "停用"
        case .sold:
            return "已出售"
        }
    }
    
    var color: String {
        switch self {
        case .active:
            return "green"
        case .maintenance:
            return "orange"
        case .inactive:
            return "gray"
        case .sold:
            return "red"
        }
    }
}

struct MaintenanceRecord: Identifiable, Codable {
    let id: UUID
    let carId: UUID
    var date: Date
    var type: MaintenanceType
    var description: String
    var cost: Double
    var mileage: Double
    var serviceProvider: String
    var notes: String
    
    init(
        id: UUID = UUID(),
        carId: UUID,
        date: Date = Date(),
        type: MaintenanceType,
        description: String,
        cost: Double,
        mileage: Double,
        serviceProvider: String,
        notes: String = ""
    ) {
        self.id = id
        self.carId = carId
        self.date = date
        self.type = type
        self.description = description
        self.cost = cost
        self.mileage = mileage
        self.serviceProvider = serviceProvider
        self.notes = notes
    }
}

enum MaintenanceType: String, Codable, CaseIterable {
    case routine = "routine"
    case repair = "repair"
    case inspection = "inspection"
    case tireChange = "tireChange"
    case oilChange = "oilChange"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .routine:
            return "常规保养"
        case .repair:
            return "维修"
        case .inspection:
            return "检查"
        case .tireChange:
            return "轮胎更换"
        case .oilChange:
            return "机油更换"
        case .other:
            return "其他"
        }
    }
}

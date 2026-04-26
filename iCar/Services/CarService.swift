import Foundation

protocol CarServiceProtocol {
    func fetchCars() async throws -> [Car]
    func fetchCar(by id: UUID) async throws -> Car?
    func saveCar(_ car: Car) async throws
    func deleteCar(by id: UUID) async throws
    func fetchMaintenanceRecords(for carId: UUID) async throws -> [MaintenanceRecord]
    func saveMaintenanceRecord(_ record: MaintenanceRecord) async throws
}

class CarService: CarServiceProtocol, @unchecked Sendable {
    
    private let networkManager = NetworkManager.shared
    private let cacheManager = CacheManager.shared
    
    func fetchCars() async throws -> [Car] {
        // 模拟网络请求延迟
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // 返回示例数据
        return [
            Car(
                brand: "特斯拉",
                model: "Model 3",
                year: 2023,
                licensePlate: "京A12345",
                mileage: 15000,
                fuelLevel: 85,
                status: .active,
                color: "红色",
                vin: "5YJ3E1EA8PF000001"
            ),
            Car(
                brand: "比亚迪",
                model: "汉EV",
                year: 2022,
                licensePlate: "沪B67890",
                mileage: 28000,
                fuelLevel: 60,
                status: .active,
                color: "黑色",
                vin: "LGXC16D38K0000002"
            ),
            Car(
                brand: "蔚来",
                model: "ES6",
                year: 2023,
                licensePlate: "粤C11111",
                mileage: 8000,
                fuelLevel: 95,
                status: .active,
                color: "蓝色",
                vin: "LJU70W1S7KG000003"
            )
        ]
    }
    
    func fetchCar(by id: UUID) async throws -> Car? {
        let cars = try await fetchCars()
        return cars.first { $0.id == id }
    }
    
    func saveCar(_ car: Car) async throws {
        // 模拟保存操作
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Car saved: \(car.displayName)")
    }
    
    func deleteCar(by id: UUID) async throws {
        // 模拟删除操作
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Car deleted with id: \(id)")
    }
    
    func fetchMaintenanceRecords(for carId: UUID) async throws -> [MaintenanceRecord] {
        try await Task.sleep(nanoseconds: 400_000_000)
        
        return [
            MaintenanceRecord(
                carId: carId,
                date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                type: .routine,
                description: "常规保养",
                cost: 800,
                mileage: 10000,
                serviceProvider: "4S店"
            ),
            MaintenanceRecord(
                carId: carId,
                date: Date().addingTimeInterval(-90 * 24 * 60 * 60),
                type: .oilChange,
                description: "更换机油",
                cost: 500,
                mileage: 5000,
                serviceProvider: "维修中心"
            )
        ]
    }
    
    func saveMaintenanceRecord(_ record: MaintenanceRecord) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Maintenance record saved: \(record.type.displayName)")
    }
}

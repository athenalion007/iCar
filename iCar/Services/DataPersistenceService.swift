import Foundation
import CoreData
import Combine

// MARK: - Data Persistence Service

@MainActor
final class DataPersistenceService: ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    
    @Published var vehicles: [CDVehicle] = []
    @Published var inspectionReports: [CDInspectionReport] = []
    @Published var userSettings: CDUserSettings?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Core Data Stack
    
    private let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext
    
    // MARK: - Singleton
    
    static let shared = DataPersistenceService()
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "DataModel")
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }

        context = persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        // 初始化数据 - 使用主线程
        Task { @MainActor in
            await initializeDefaultData()
            await loadAllData()
        }
    }
    
    // MARK: - Initialization
    
    private func initializeDefaultData() async {
        // 检查是否已有用户设置
        let fetchRequest: NSFetchRequest<CDUserSettings> = CDUserSettings.fetchRequest()
        
        do {
            let existingSettings = try context.fetch(fetchRequest)
            if existingSettings.isEmpty {
                // 创建默认用户设置
                let settings = CDUserSettings(context: context)
                settings.id = UUID()
                settings.createdAt = Date()
                settings.updatedAt = Date()
                settings.isDataEncryptionEnabled = true
                settings.isAutoBackupEnabled = false
                settings.backupFrequency = "weekly"
                settings.isAnalyticsEnabled = false
                settings.isCrashReportingEnabled = true
                settings.privacyPolicyAccepted = false
                settings.dataRetentionDays = 365
                settings.themePreference = "system"
                settings.languagePreference = "zh-Hans"
                
                try context.save()
                print("Default user settings created")
            }
        } catch {
            print("Failed to initialize default data: \(error)")
        }
    }
    
    // MARK: - Data Loading
    
    func loadAllData() async {
        isLoading = true
        defer { isLoading = false }
        
        await loadVehicles()
        await loadInspectionReports()
        await loadUserSettings()
    }
    
    func loadVehicles() async {
        let fetchRequest: NSFetchRequest<CDVehicle> = CDVehicle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isMarkedDeleted == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            vehicles = try context.fetch(fetchRequest)
        } catch {
            errorMessage = "加载车辆数据失败: \(error.localizedDescription)"
        }
    }
    
    func loadInspectionReports() async {
        let fetchRequest: NSFetchRequest<CDInspectionReport> = CDInspectionReport.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isMarkedDeleted == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            inspectionReports = try context.fetch(fetchRequest)
        } catch {
            errorMessage = "加载检测报告失败: \(error.localizedDescription)"
        }
    }
    
    func loadUserSettings() async {
        let fetchRequest: NSFetchRequest<CDUserSettings> = CDUserSettings.fetchRequest()
        
        do {
            userSettings = try context.fetch(fetchRequest).first
        } catch {
            errorMessage = "加载用户设置失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Vehicle CRUD
    
    func createVehicle(
        brand: String,
        model: String,
        year: Int16,
        licensePlate: String,
        mileage: Double = 0,
        fuelLevel: Double = 100,
        color: String = "白色",
        vin: String = "",
        status: String = "active"
    ) async throws -> CDVehicle {
        let vehicle = CDVehicle(context: context)
        vehicle.id = UUID()
        vehicle.brand = brand
        vehicle.model = model
        vehicle.year = year
        vehicle.licensePlate = licensePlate
        vehicle.mileage = mileage
        vehicle.fuelLevel = fuelLevel
        vehicle.color = color
        vehicle.vin = vin
        vehicle.status = status
        vehicle.createdAt = Date()
        vehicle.updatedAt = Date()
        vehicle.isMarkedDeleted = false
        
        try context.save()
        await loadVehicles()
        return vehicle
    }
    
    func updateVehicle(_ vehicle: CDVehicle) async throws {
        vehicle.updatedAt = Date()
        try context.save()
        await loadVehicles()
    }
    
    func deleteVehicle(_ vehicle: CDVehicle) async throws {
        vehicle.isMarkedDeleted = true
        vehicle.updatedAt = Date()
        try context.save()
        await loadVehicles()
    }
    
    func permanentlyDeleteVehicle(_ vehicle: CDVehicle) async throws {
        context.delete(vehicle)
        try context.save()
        await loadVehicles()
    }
    
    func getVehicle(by id: UUID) -> CDVehicle? {
        vehicles.first { $0.id == id }
    }
    
    // MARK: - Inspection Report CRUD
    
    func createInspectionReport(
        title: String,
        vehicle: CDVehicle? = nil,
        carBrand: String,
        carModel: String,
        licensePlate: String,
        carColor: String,
        vin: String = "",
        mileage: Double = 0,
        detectionResults: [DetectionResult] = [],
        capturedPhotos: [CapturedPhotoInfo] = [],
        overallScore: Int16 = 0,
        glossLevel: Double = 0,
        clarity: Double = 0,
        colorConsistency: Double = 0,
        status: String = "draft",
        tags: [String] = []
    ) async throws -> CDInspectionReport {
        let report = CDInspectionReport(context: context)
        report.id = UUID()
        report.title = title
        report.vehicle = vehicle
        report.carBrand = carBrand
        report.carModel = carModel
        report.licensePlate = licensePlate
        report.carColor = carColor
        report.vin = vin
        report.mileage = mileage
        report.createdAt = Date()
        report.updatedAt = Date()
        report.overallScore = overallScore
        report.glossLevel = glossLevel
        report.clarity = clarity
        report.colorConsistency = colorConsistency
        report.status = status
        report.isFavorite = false
        report.isMarkedDeleted = false
        
        // 编码复杂数据类型
        let encoder = JSONEncoder()
        report.detectionResultsData = try encoder.encode(detectionResults)
        report.capturedPhotosData = try encoder.encode(capturedPhotos)
        report.tagsData = try encoder.encode(tags)
        
        try context.save()
        await loadInspectionReports()
        return report
    }
    
    func updateInspectionReport(_ report: CDInspectionReport) async throws {
        report.updatedAt = Date()
        try context.save()
        await loadInspectionReports()
    }
    
    func deleteInspectionReport(_ report: CDInspectionReport) async throws {
        report.isMarkedDeleted = true
        report.updatedAt = Date()
        try context.save()
        await loadInspectionReports()
    }
    
    func permanentlyDeleteInspectionReport(_ report: CDInspectionReport) async throws {
        context.delete(report)
        try context.save()
        await loadInspectionReports()
    }
    
    func toggleFavorite(for report: CDInspectionReport) async throws {
        report.isFavorite.toggle()
        report.updatedAt = Date()
        try context.save()
        await loadInspectionReports()
    }
    
    func updateReportStatus(_ report: CDInspectionReport, to status: String) async throws {
        report.status = status
        report.updatedAt = Date()
        try context.save()
        await loadInspectionReports()
    }
    
    // MARK: - Maintenance Record CRUD
    
    func createMaintenanceRecord(
        for vehicle: CDVehicle,
        type: String,
        description: String,
        cost: Double,
        mileage: Double,
        serviceProvider: String,
        notes: String = ""
    ) async throws -> CDMaintenanceRecord {
        let record = CDMaintenanceRecord(context: context)
        record.id = UUID()
        record.vehicle = vehicle
        record.type = type
        record.descriptionText = description
        record.cost = cost
        record.mileage = mileage
        record.serviceProvider = serviceProvider
        record.notes = notes
        record.date = Date()
        record.isMarkedDeleted = false
        
        try context.save()
        return record
    }
    
    func deleteMaintenanceRecord(_ record: CDMaintenanceRecord) async throws {
        record.isMarkedDeleted = true
        try context.save()
    }
    
    func getMaintenanceRecords(for vehicle: CDVehicle) -> [CDMaintenanceRecord] {
        let fetchRequest: NSFetchRequest<CDMaintenanceRecord> = CDMaintenanceRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "vehicle == %@ AND isMarkedDeleted == NO", vehicle)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch maintenance records: \(error)")
            return []
        }
    }
    
    // MARK: - User Settings CRUD
    
    func updateUserSettings(_ updates: (CDUserSettings) -> Void) async throws {
        guard let settings = userSettings else {
            throw DataPersistenceError.userSettingsNotFound
        }
        
        updates(settings)
        settings.updatedAt = Date()
        try context.save()
        await loadUserSettings()
    }
    
    func acceptPrivacyPolicy() async throws {
        guard let settings = userSettings else {
            throw DataPersistenceError.userSettingsNotFound
        }
        
        settings.privacyPolicyAccepted = true
        settings.privacyPolicyAcceptedDate = Date()
        settings.updatedAt = Date()
        try context.save()
        await loadUserSettings()
    }
    
    // MARK: - Data Migration
    
    func migrateFromJSON(cars: [Car], reports: [InspectionReport]) async throws {
        // 迁移车辆数据
        for car in cars {
            let existingVehicle = vehicles.first { $0.id == car.id }
            if existingVehicle == nil {
                _ = try await createVehicle(
                    brand: car.brand,
                    model: car.model,
                    year: Int16(car.year),
                    licensePlate: car.licensePlate,
                    mileage: car.mileage,
                    fuelLevel: car.fuelLevel,
                    color: car.color,
                    vin: car.vin,
                    status: car.status.rawValue
                )
            }
        }
        
        // 迁移报告数据
        for report in reports {
            let existingReport = inspectionReports.first { $0.id == report.id }
            if existingReport == nil {
                let encoder = JSONEncoder()
                let vehicle = vehicles.first { $0.id == report.carId }
                
                _ = try await createInspectionReport(
                    title: report.title,
                    vehicle: vehicle,
                    carBrand: report.carBrand,
                    carModel: report.carModel,
                    licensePlate: report.licensePlate,
                    carColor: report.carColor,
                    vin: report.vin,
                    mileage: report.mileage,
                    detectionResults: report.detectionResults,
                    capturedPhotos: report.capturedPhotos,
                    overallScore: Int16(report.overallScore),
                    glossLevel: report.glossLevel,
                    clarity: report.clarity,
                    colorConsistency: report.colorConsistency,
                    status: report.status.rawValue,
                    tags: report.tags
                )
            }
        }
    }
    
    // MARK: - Data Export
    
    func exportAllData() async throws -> DataExportPackage {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // 导出车辆数据
        let vehicleData = try encoder.encode(vehicles.map { vehicle in
            VehicleExport(
                id: vehicle.id,
                brand: vehicle.brand,
                model: vehicle.model,
                year: Int(vehicle.year),
                licensePlate: vehicle.licensePlate,
                mileage: vehicle.mileage,
                fuelLevel: vehicle.fuelLevel,
                color: vehicle.color,
                vin: vehicle.vin,
                status: vehicle.status,
                createdAt: vehicle.createdAt,
                updatedAt: vehicle.updatedAt
            )
        })
        
        // 导出报告数据
        let reportData = try encoder.encode(inspectionReports.map { report in
            ReportExport(
                id: report.id,
                title: report.title,
                carBrand: report.carBrand,
                carModel: report.carModel,
                licensePlate: report.licensePlate,
                carColor: report.carColor,
                vin: report.vin,
                mileage: report.mileage,
                overallScore: Int(report.overallScore),
                glossLevel: report.glossLevel,
                clarity: report.clarity,
                colorConsistency: report.colorConsistency,
                status: report.status,
                isFavorite: report.isFavorite,
                createdAt: report.createdAt,
                updatedAt: report.updatedAt
            )
        })
        
        return DataExportPackage(
            vehicles: vehicleData,
            reports: reportData,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }
    
    // MARK: - Data Cleanup
    
    func cleanupOldData(olderThan days: Int) async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        // 清理旧的已删除数据
        let vehicleFetchRequest: NSFetchRequest<CDVehicle> = CDVehicle.fetchRequest()
        vehicleFetchRequest.predicate = NSPredicate(format: "isMarkedDeleted == YES AND updatedAt < %@", cutoffDate as NSDate)
        
        let reportFetchRequest: NSFetchRequest<CDInspectionReport> = CDInspectionReport.fetchRequest()
        reportFetchRequest.predicate = NSPredicate(format: "isMarkedDeleted == YES AND updatedAt < %@", cutoffDate as NSDate)
        
        var deletedCount = 0
        
        let oldVehicles = try context.fetch(vehicleFetchRequest)
        for vehicle in oldVehicles {
            context.delete(vehicle)
            deletedCount += 1
        }
        
        let oldReports = try context.fetch(reportFetchRequest)
        for report in oldReports {
            context.delete(report)
            deletedCount += 1
        }
        
        try context.save()
        
        await loadAllData()
        
        return deletedCount
    }
    
    func clearAllData() async throws {
        let entities = ["CDVehicle", "CDInspectionReport", "CDInspectionRecord", "CDMaintenanceRecord"]
        
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                }
            } catch {
                print("Failed to clear entity \(entityName): \(error)")
            }
        }
        
        await loadAllData()
    }
    
    // MARK: - Background Context
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum DataPersistenceError: LocalizedError {
    case userSettingsNotFound
    case vehicleNotFound
    case reportNotFound
    case saveFailed(Error)
    case migrationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .userSettingsNotFound:
            return "用户设置未找到"
        case .vehicleNotFound:
            return "车辆未找到"
        case .reportNotFound:
            return "检测报告未找到"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "数据迁移失败: \(error.localizedDescription)"
        }
    }
}

struct DataExportPackage {
    let vehicles: Data
    let reports: Data
    let exportDate: Date
    let appVersion: String
    
    func generateJSON() throws -> [String: Any] {
        let vehiclesJSON = try JSONSerialization.jsonObject(with: vehicles) as? [[String: Any]] ?? []
        let reportsJSON = try JSONSerialization.jsonObject(with: reports) as? [[String: Any]] ?? []
        
        return [
            "exportDate": ISO8601DateFormatter().string(from: exportDate),
            "appVersion": appVersion,
            "vehicles": vehiclesJSON,
            "reports": reportsJSON
        ]
    }
}

struct VehicleExport: Codable {
    let id: UUID?
    let brand: String?
    let model: String?
    let year: Int
    let licensePlate: String?
    let mileage: Double
    let fuelLevel: Double
    let color: String?
    let vin: String?
    let status: String?
    let createdAt: Date?
    let updatedAt: Date?
}

struct ReportExport: Codable {
    let id: UUID?
    let title: String?
    let carBrand: String?
    let carModel: String?
    let licensePlate: String?
    let carColor: String?
    let vin: String?
    let mileage: Double
    let overallScore: Int
    let glossLevel: Double
    let clarity: Double
    let colorConsistency: Double
    let status: String?
    let isFavorite: Bool
    let createdAt: Date?
    let updatedAt: Date?
}

// MARK: - Core Data Extensions

extension CDVehicle {
    var displayName: String {
        "\(brand ?? "") \(model ?? "")"
    }
    
    var formattedMileage: String {
        String(format: "%.1f km", mileage)
    }
    
    var formattedFuelLevel: String {
        String(format: "%.0f%%", fuelLevel)
    }
    
    var statusEnum: CarStatus {
        CarStatus(rawValue: status ?? "active") ?? .active
    }
}

extension CDInspectionReport {
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return "\(carBrand ?? "") \(carModel ?? "") - \(formattedDate)"
    }
    
    var formattedDate: String {
        guard let date = createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    var statusEnum: ReportStatus {
        ReportStatus(rawValue: status ?? "draft") ?? .draft
    }
    
    func decodedDetectionResults() -> [DetectionResult] {
        guard let data = detectionResultsData else { return [] }
        return (try? JSONDecoder().decode([DetectionResult].self, from: data)) ?? []
    }
    
    func decodedCapturedPhotos() -> [CapturedPhotoInfo] {
        guard let data = capturedPhotosData else { return [] }
        return (try? JSONDecoder().decode([CapturedPhotoInfo].self, from: data)) ?? []
    }
    
    func decodedTags() -> [String] {
        guard let data = tagsData else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

extension CDMaintenanceRecord {
    var typeEnum: MaintenanceType {
        MaintenanceType(rawValue: type ?? "other") ?? .other
    }
    
    var formattedDate: String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

extension CDUserSettings {
    var backupFrequencyEnum: BackupFrequency {
        BackupFrequency(rawValue: backupFrequency ?? "weekly") ?? .weekly
    }
    
    var themePreferenceEnum: ThemePreference {
        ThemePreference(rawValue: themePreference ?? "system") ?? .system
    }
}

enum BackupFrequency: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "每天"
        case .weekly: return "每周"
        case .monthly: return "每月"
        }
    }
}

enum ThemePreference: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        }
    }
}

import SwiftUI
import CoreData

@main
struct iCarApp: App {
    
    let persistenceController = PersistenceController.shared
    
    @StateObject private var dataService = DataPersistenceService.shared
    @StateObject private var privacyService = PrivacyService.shared
    @StateObject private var encryptionService = EncryptionService.shared
    
    private let serviceContainer = ProductionServiceContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.serviceContainer, serviceContainer)
                .environmentObject(dataService)
                .environmentObject(privacyService)
                .environmentObject(encryptionService)
                .onAppear {
                    initializeApp()
                }
        }
    }
    
    // MARK: - Initialization
    
    private func initializeApp() {
        // 检查隐私政策接受状态
        if !privacyService.hasAcceptedPrivacyPolicy() {
            // 首次启动，显示隐私政策
            print("First launch - showing privacy policy")
        }
        
        // 检查并请求必要权限
        privacyService.checkAllPermissions()
        
        // 加载数据
        Task {
            await dataService.loadAllData()
        }
    }
}

// MARK: - Persistence Controller

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }
    
    // MARK: - Preview Support
    
    nonisolated(unsafe) static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建示例数据
        for i in 0..<5 {
            let vehicle = CDVehicle(context: viewContext)
            vehicle.id = UUID()
            vehicle.brand = ["特斯拉", "比亚迪", "宝马", "奔驰", "奥迪"][i]
            vehicle.model = ["Model 3", "汉EV", "X5", "E300", "A6L"][i]
            vehicle.year = 2023
            vehicle.licensePlate = "京A1234\(i)"
            vehicle.mileage = Double(10000 + i * 5000)
            vehicle.fuelLevel = 85
            vehicle.color = ["红色", "黑色", "白色", "银色", "蓝色"][i]
            vehicle.vin = "VIN1234567890\(i)"
            vehicle.status = "active"
            vehicle.createdAt = Date()
            vehicle.updatedAt = Date()
            vehicle.isMarkedDeleted = false
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return result
    }()
}

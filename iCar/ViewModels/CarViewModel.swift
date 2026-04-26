import Foundation
import Combine

@MainActor
class CarViewModel: ObservableObject {
    @Published var cars: [Car] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let carService: AppCarServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(carService: AppCarServiceProtocol = CarService()) {
        self.carService = carService
        loadInitialData()
    }
    
    func loadInitialData() {
        refreshData()
    }
    
    func refreshData() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let fetchedCars = try await carService.fetchCars()
                self.cars = fetchedCars
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }
    
    func addCar(_ car: Car) {
        cars.append(car)
    }
    
    func removeCar(at indexSet: IndexSet) {
        cars.remove(atOffsets: indexSet)
    }
    
    func updateCar(_ car: Car) {
        if let index = cars.firstIndex(where: { $0.id == car.id }) {
            cars[index] = car
        }
    }
}

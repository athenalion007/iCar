import Foundation

class CacheManager: @unchecked Sendable {
    static let shared = CacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("iCarCache")
        
        try? fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - UserDefaults Cache
    
    func set<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    // MARK: - File Cache
    
    func saveToFile<T: Codable>(_ data: T, filename: String) throws {
        let url = cacheDirectory.appendingPathComponent(filename)
        let encodedData = try JSONEncoder().encode(data)
        try encodedData.write(to: url)
    }
    
    func loadFromFile<T: Codable>(_ type: T.Type, filename: String) throws -> T? {
        let url = cacheDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
    
    func deleteFile(filename: String) throws {
        let url = cacheDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    func clearAllCache() throws {
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
    
    // MARK: - Cache Expiration
    
    func setCacheExpiration(forKey key: String, expirationInterval: TimeInterval) {
        let expirationDate = Date().addingTimeInterval(expirationInterval)
        userDefaults.set(expirationDate, forKey: "\(key)_expiration")
    }
    
    func isCacheValid(forKey key: String) -> Bool {
        guard let expirationDate = userDefaults.object(forKey: "\(key)_expiration") as? Date else {
            return false
        }
        return Date() < expirationDate
    }
    
    func invalidateCache(forKey key: String) {
        userDefaults.removeObject(forKey: "\(key)_expiration")
        remove(forKey: key)
    }
}

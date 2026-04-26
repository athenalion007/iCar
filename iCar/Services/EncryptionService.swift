import Foundation
import CryptoKit
import Security
import LocalAuthentication

// MARK: - Encryption Service

@MainActor
final class EncryptionService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isEncryptionEnabled: Bool = true
    @Published var isBiometricAuthAvailable: Bool = false
    @Published var biometricType: BiometricType = .none
    
    // MARK: - Properties
    
    private let keychainService = "com.icar.encryption"
    private let keychainAccount = "encryption-key"
    private let keyTag = "com.icar.encryptionkey"
    
    // MARK: - Singleton
    
    static let shared = EncryptionService()
    
    private init() {
        checkBiometricAvailability()
        loadEncryptionSettings()
    }
    
    // MARK: - Biometric Authentication
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        isBiometricAuthAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        
        if isBiometricAuthAvailable {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            case .opticID:
                biometricType = .opticID
            default:
                biometricType = .none
            }
        }
    }
    
    func authenticateWithBiometry(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            print("Biometric authentication failed: \(error)")
            return false
        }
    }
    
    func authenticateWithPasscode(reason: String) async -> Bool {
        let context = LAContext()
        
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            print("Passcode authentication failed: \(error)")
            return false
        }
    }
    
    // MARK: - Key Management
    
    private func loadEncryptionSettings() {
        isEncryptionEnabled = UserDefaults.standard.bool(forKey: "encryption_enabled")
        if !UserDefaults.standard.objectIsForced(forKey: "encryption_enabled") {
            isEncryptionEnabled = true // 默认启用
        }
    }
    
    func setEncryptionEnabled(_ enabled: Bool) {
        isEncryptionEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "encryption_enabled")
    }
    
    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        // 尝试从 Keychain 获取现有密钥
        if let existingKey = try? retrieveKeyFromKeychain() {
            return existingKey
        }
        
        // 生成新密钥
        let newKey = SymmetricKey(size: .bits256)
        try storeKeyInKeychain(newKey)
        return newKey
    }
    
    private func retrieveKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
    
    private func storeKeyInKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 删除现有密钥
        SecItemDelete(query as CFDictionary)
        
        // 存储新密钥
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keyStorageFailed(status)
        }
    }
    
    func deleteEncryptionKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EncryptionError.keyDeletionFailed(status)
        }
    }
    
    func rotateEncryptionKey() throws -> SymmetricKey {
        // 删除旧密钥
        try deleteEncryptionKey()
        // 生成并存储新密钥
        let newKey = SymmetricKey(size: .bits256)
        try storeKeyInKeychain(newKey)
        return newKey
    }
    
    // MARK: - Data Encryption (AES-256-GCM)
    
    func encrypt(data: Data) throws -> EncryptedData {
        guard isEncryptionEnabled else {
            // 如果加密被禁用，返回原始数据并标记为未加密
            return EncryptedData(
                ciphertext: data,
                nonce: Data(),
                tag: Data(),
                isEncrypted: false
            )
        }
        
        let key = try getOrCreateEncryptionKey()
        let nonce = AES.GCM.Nonce()
        
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return EncryptedData(
            ciphertext: sealedBox.ciphertext,
            nonce: Data(nonce),
            tag: sealedBox.tag,
            isEncrypted: true
        )
    }
    
    func decrypt(encryptedData: EncryptedData) throws -> Data {
        guard encryptedData.isEncrypted else {
            // 如果数据未加密，直接返回
            return encryptedData.ciphertext
        }
        
        let key = try getOrCreateEncryptionKey()
        let nonce = try AES.GCM.Nonce(data: encryptedData.nonce)
        
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: encryptedData.ciphertext,
            tag: encryptedData.tag
        )
        
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - String Encryption
    
    func encrypt(string: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.stringEncodingFailed
        }
        
        let encrypted = try encrypt(data: data)
        let combinedData = encrypted.nonce + encrypted.ciphertext + encrypted.tag
        return combinedData.base64EncodedString()
    }
    
    func decrypt(string: String) throws -> String {
        guard let combinedData = Data(base64Encoded: string) else {
            throw EncryptionError.invalidBase64String
        }
        
        // 提取 nonce (12 bytes), ciphertext 和 tag (16 bytes)
        let nonceSize = 12
        let tagSize = 16
        
        guard combinedData.count > nonceSize + tagSize else {
            throw EncryptionError.invalidEncryptedData
        }
        
        let nonce = combinedData.prefix(nonceSize)
        let tag = combinedData.suffix(tagSize)
        let ciphertext = combinedData.dropFirst(nonceSize).dropLast(tagSize)
        
        let encryptedData = EncryptedData(
            ciphertext: Data(ciphertext),
            nonce: Data(nonce),
            tag: Data(tag),
            isEncrypted: true
        )
        
        let decryptedData = try decrypt(encryptedData: encryptedData)
        
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.stringDecodingFailed
        }
        
        return decryptedString
    }
    
    // MARK: - File Encryption
    
    func encryptFile(at url: URL) throws -> URL {
        let data = try Data(contentsOf: url)
        let encrypted = try encrypt(data: data)
        
        let encryptedURL = url.appendingPathExtension("encrypted")
        let encryptedFileData = encrypted.nonce + encrypted.ciphertext + encrypted.tag
        try encryptedFileData.write(to: encryptedURL)
        
        return encryptedURL
    }
    
    func decryptFile(at url: URL) throws -> URL {
        let encryptedData = try Data(contentsOf: url)
        
        let nonceSize = 12
        let tagSize = 16
        
        guard encryptedData.count > nonceSize + tagSize else {
            throw EncryptionError.invalidEncryptedData
        }
        
        let nonce = encryptedData.prefix(nonceSize)
        let tag = encryptedData.suffix(tagSize)
        let ciphertext = encryptedData.dropFirst(nonceSize).dropLast(tagSize)
        
        let encrypted = EncryptedData(
            ciphertext: Data(ciphertext),
            nonce: Data(nonce),
            tag: Data(tag),
            isEncrypted: true
        )
        
        let decryptedData = try decrypt(encryptedData: encrypted)
        
        let decryptedURL = url.deletingPathExtension()
        try decryptedData.write(to: decryptedURL)
        
        return decryptedURL
    }
    
    // MARK: - Secure Data Storage
    
    func storeSecureData(_ data: Data, forKey key: String) throws {
        let encrypted = try encrypt(data: data)
        let combinedData = encrypted.nonce + encrypted.ciphertext + encrypted.tag
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: combinedData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 删除现有数据
        SecItemDelete(query as CFDictionary)
        
        // 存储新数据
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.secureStorageFailed(status)
        }
    }
    
    func retrieveSecureData(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let combinedData = result as? Data else {
            return nil
        }
        
        let nonceSize = 12
        let tagSize = 16
        
        guard combinedData.count > nonceSize + tagSize else {
            return combinedData // 可能是未加密数据
        }
        
        let nonce = combinedData.prefix(nonceSize)
        let tag = combinedData.suffix(tagSize)
        let ciphertext = combinedData.dropFirst(nonceSize).dropLast(tagSize)
        
        let encrypted = EncryptedData(
            ciphertext: Data(ciphertext),
            nonce: Data(nonce),
            tag: Data(tag),
            isEncrypted: true
        )
        
        return try decrypt(encryptedData: encrypted)
    }
    
    func deleteSecureData(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EncryptionError.secureDeletionFailed(status)
        }
    }
    
    // MARK: - Password Hashing
    
    func hashPassword(_ password: String, salt: Data? = nil) throws -> PasswordHash {
        let actualSalt = salt ?? generateSalt()
        let passwordData = Data(password.utf8)
        
        let derivedKeyData = deriveKey(from: passwordData, salt: actualSalt)
        
        return PasswordHash(
            hash: derivedKeyData,
            salt: actualSalt,
            iterations: 100000,
            algorithm: "PBKDF2-HMAC-SHA256"
        )
    }
    
    func verifyPassword(_ password: String, against hash: PasswordHash) throws -> Bool {
        let passwordData = Data(password.utf8)
        let derivedKeyData = deriveKey(from: passwordData, salt: hash.salt, iterations: hash.iterations)
        
        return derivedKeyData == hash.hash
    }
    
    private func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        return salt
    }
    
    private func deriveKey(from password: Data, salt: Data, iterations: Int = 100000) -> Data {
        var derivedKeyData = Data(count: 32)
        
        _ = password.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,
                        32
                    )
                }
            }
        }
        
        return derivedKeyData
    }
}

// MARK: - Supporting Types

struct EncryptedData {
    let ciphertext: Data
    let nonce: Data
    let tag: Data
    let isEncrypted: Bool
}

struct PasswordHash {
    let hash: Data
    let salt: Data
    let iterations: Int
    let algorithm: String
    
    func toString() -> String {
        "\(algorithm):\(iterations):\(salt.base64EncodedString()):\(hash.base64EncodedString())"
    }
    
    static func fromString(_ string: String) -> PasswordHash? {
        let components = string.split(separator: ":")
        guard components.count == 4,
              let iterations = Int(components[1]),
              let salt = Data(base64Encoded: String(components[2])),
              let hash = Data(base64Encoded: String(components[3])) else {
            return nil
        }
        
        return PasswordHash(
            hash: hash,
            salt: salt,
            iterations: iterations,
            algorithm: String(components[0])
        )
    }
}

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    
    var displayName: String {
        switch self {
        case .none:
            return "无"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }
    
    var icon: String {
        switch self {
        case .none:
            return "lock.slash"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "eye"
        }
    }
}

enum EncryptionError: LocalizedError {
    case keyStorageFailed(OSStatus)
    case keyRetrievalFailed(OSStatus)
    case keyDeletionFailed(OSStatus)
    case encryptionFailed
    case decryptionFailed
    case stringEncodingFailed
    case stringDecodingFailed
    case invalidBase64String
    case invalidEncryptedData
    case secureStorageFailed(OSStatus)
    case secureRetrievalFailed(OSStatus)
    case secureDeletionFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .keyStorageFailed(let status):
            return "密钥存储失败 (错误码: \(status))"
        case .keyRetrievalFailed(let status):
            return "密钥获取失败 (错误码: \(status))"
        case .keyDeletionFailed(let status):
            return "密钥删除失败 (错误码: \(status))"
        case .encryptionFailed:
            return "加密失败"
        case .decryptionFailed:
            return "解密失败"
        case .stringEncodingFailed:
            return "字符串编码失败"
        case .stringDecodingFailed:
            return "字符串解码失败"
        case .invalidBase64String:
            return "无效的Base64字符串"
        case .invalidEncryptedData:
            return "无效的加密数据"
        case .secureStorageFailed(let status):
            return "安全存储失败 (错误码: \(status))"
        case .secureRetrievalFailed(let status):
            return "安全读取失败 (错误码: \(status))"
        case .secureDeletionFailed(let status):
            return "安全删除失败 (错误码: \(status))"
        }
    }
}

// MARK: - CommonCrypto Import

import CommonCrypto

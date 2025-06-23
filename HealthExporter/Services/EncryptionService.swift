import Foundation
import CryptoKit

class EncryptionService {
    private let keyDerivationIterations = 100_000
    
    func encrypt(data: Data, password: String) throws -> Data {
        let salt = generateSalt()
        let key = try deriveKey(from: password, salt: salt)
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        var result = Data()
        result.append(salt)
        result.append(encryptedData)
        
        return result
    }
    
    func decrypt(data: Data, password: String) throws -> Data {
        guard data.count > 32 else {
            throw EncryptionError.invalidData
        }
        
        let salt = data.prefix(32)
        let encryptedData = data.dropFirst(32)
        
        let key = try deriveKey(from: password, salt: Data(salt))
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return decryptedData
    }
    
    private func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        return salt
    }
    
    private func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidPassword
        }
        
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: Data("HealthExporter".utf8),
            outputByteCount: 32
        )
        
        return derivedKey
    }
}

enum EncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case invalidPassword
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidData:
            return "Invalid encrypted data format"
        case .invalidPassword:
            return "Invalid password"
        }
    }
}
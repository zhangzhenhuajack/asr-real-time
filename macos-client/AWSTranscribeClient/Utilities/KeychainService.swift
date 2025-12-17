import Foundation
import Security

class KeychainService {
    private let serviceName = "com.awstranscribe.client"
    private let accessKeyAccount = "aws_access_key"
    private let secretKeyAccount = "aws_secret_key"
    private let regionAccount = "aws_region"
    
    // MARK: - Save Credentials
    
    func saveAccessKey(_ key: String) -> Bool {
        return saveToKeychain(account: accessKeyAccount, value: key)
    }
    
    func saveSecretKey(_ key: String) -> Bool {
        return saveToKeychain(account: secretKeyAccount, value: key)
    }
    
    func saveRegion(_ region: String) -> Bool {
        return saveToKeychain(account: regionAccount, value: region)
    }
    
    // MARK: - Get Credentials
    
    func getAccessKey() -> String? {
        return getFromKeychain(account: accessKeyAccount)
    }
    
    func getSecretKey() -> String? {
        return getFromKeychain(account: secretKeyAccount)
    }
    
    func getRegion() -> String? {
        return getFromKeychain(account: regionAccount) ?? "us-east-1"
    }
    
    // MARK: - Delete Credentials
    
    func deleteAccessKey() -> Bool {
        return deleteFromKeychain(account: accessKeyAccount)
    }
    
    func deleteSecretKey() -> Bool {
        return deleteFromKeychain(account: secretKeyAccount)
    }
    
    func deleteRegion() -> Bool {
        return deleteFromKeychain(account: regionAccount)
    }
    
    func deleteAllCredentials() -> Bool {
        let accessKeyDeleted = deleteAccessKey()
        let secretKeyDeleted = deleteSecretKey()
        let regionDeleted = deleteRegion()
        return accessKeyDeleted && secretKeyDeleted && regionDeleted
    }
    
    // MARK: - Private Keychain Methods
    
    private func saveToKeychain(account: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // First try to delete existing item
        deleteFromKeychain(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func deleteFromKeychain(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

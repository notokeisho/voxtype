import Foundation
import Security

/// Helper class for secure token storage in Keychain.
final class KeychainHelper {
    /// Service identifier for Keychain items.
    private static let service = "com.voxtype.app"

    /// Keychain key for JWT token.
    static let tokenKey = "jwt_token"

    // MARK: - Save

    /// Save a string value to Keychain.
    /// - Parameters:
    ///   - value: The string value to save.
    ///   - key: The key to associate with the value.
    /// - Returns: `true` if save was successful, `false` otherwise.
    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        print("💾 [Keychain] save: key=\(key), value長さ=\(value.count)")

        guard let data = value.data(using: .utf8) else {
            print("❌ [Keychain] save: UTF8変換失敗")
            return false
        }

        // Delete existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Delete when app is uninstalled
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        print("💾 [Keychain] save: status=\(status) (0=成功)")
        return status == errSecSuccess
    }

    // MARK: - Load

    /// Load a string value from Keychain.
    /// - Parameter key: The key associated with the value.
    /// - Returns: The stored string value, or `nil` if not found.
    static func load(forKey key: String) -> String? {
        print("📖 [Keychain] load: key=\(key)")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        print("📖 [Keychain] load: status=\(status) (-25300=見つからない, 0=成功)")

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            print("📖 [Keychain] load: 結果=nil")
            return nil
        }

        print("📖 [Keychain] load: 結果=値あり (長さ: \(string.count))")
        return string
    }

    // MARK: - Delete

    /// Delete a value from Keychain.
    /// - Parameter key: The key associated with the value to delete.
    /// - Returns: `true` if deletion was successful or item didn't exist, `false` otherwise.
    @discardableResult
    static func delete(forKey key: String) -> Bool {
        print("🗑️ [Keychain] delete: key=\(key)")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        print("🗑️ [Keychain] delete: status=\(status) (0=成功, -25300=元々なかった)")
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Check Existence

    /// Check if a value exists in Keychain.
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists, `false` otherwise.
    static func exists(forKey key: String) -> Bool {
        load(forKey: key) != nil
    }
}

import Foundation
import Security

/// Reads/writes the API key as a login-keychain generic password item.
public enum Keychain {
    public static func apiKey(service: String = "polish", account: String = "api-key") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    /// Stores (or clears, when `value` is empty) the API key.
    /// Returns the raw keychain `OSStatus` (`errSecSuccess` == 0 on success).
    @discardableResult
    public static func set(apiKey value: String, service: String = "polish", account: String = "api-key") -> OSStatus {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        if value.isEmpty {
            let status = SecItemDelete(base as CFDictionary)
            return status == errSecItemNotFound ? errSecSuccess : status
        }

        let data = Data(value.utf8)

        // Update if the item already exists; otherwise add it.
        if SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecSuccess {
            return errSecSuccess
        }
        var add = base
        add[kSecValueData as String] = data
        return SecItemAdd(add as CFDictionary, nil)
    }
}

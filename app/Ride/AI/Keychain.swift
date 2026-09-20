import Foundation
import Security

enum Keychain {
    static let service = "dev.ride.Ride"

    static func read(_ account: String) -> String? {
        var query = base(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            delete(account)
            return
        }
        let update = [kSecValueData as String: data]
        if SecItemUpdate(base(account) as CFDictionary, update as CFDictionary) == errSecSuccess {
            return
        }
        var add = base(account)
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func delete(_ account: String) {
        SecItemDelete(base(account) as CFDictionary)
    }

    private static func base(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

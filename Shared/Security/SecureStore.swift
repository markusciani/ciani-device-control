import Foundation
import Security

enum SecureStore {
    static func set(_ value: String, for account: String) {
        let data = Data(value.utf8)
        let query = baseQuery(account: account, synchronizable: kSecAttrSynchronizableAny)
        SecItemDelete(query as CFDictionary)

        var add = baseQuery(account: account, synchronizable: true)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if SecItemAdd(add as CFDictionary, nil) != errSecSuccess {
            // Local Keychain remains available when iCloud Keychain is disabled.
            add.removeValue(forKey: kSecAttrSynchronizable as String)
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func get(_ account: String) -> String? {
        var query = baseQuery(account: account, synchronizable: kSecAttrSynchronizableAny)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        SecItemDelete(baseQuery(account: account, synchronizable: kSecAttrSynchronizableAny) as CFDictionary)
    }

    private static func baseQuery(account: String, synchronizable: Any) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ciani.device-control",
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: synchronizable
        ]
    }
}

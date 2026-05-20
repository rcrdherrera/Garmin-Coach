import Foundation
import Security

enum KeychainHelper {

    private static let service = Bundle.main.bundleIdentifier ?? "GarminCoach"

    // MARK: - Server URL & Token

    static func saveServerURL(_ url: String) { save(key: "serverURL", value: url) }
    static func loadServerURL() -> String?   { load(key: "serverURL") }

    static func saveServerToken(_ token: String) { save(key: "serverToken", value: token) }
    static func loadServerToken() -> String?      { load(key: "serverToken") }

    static func hasServerConfig() -> Bool {
        !(loadServerURL() ?? "").isEmpty && !(loadServerToken() ?? "").isEmpty
    }

    static func deleteServerConfig() {
        delete(key: "serverURL")
        delete(key: "serverToken")
    }

    // MARK: - Generic Keychain primitives

    private static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

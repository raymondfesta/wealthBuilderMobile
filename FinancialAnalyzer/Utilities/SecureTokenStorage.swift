import Foundation
import Security

final class SecureTokenStorage {
    static let shared = SecureTokenStorage()

    private let service: String = {
        #if DEBUG
        return "com.financialanalyzer.auth.dev"
        #else
        return "com.financialanalyzer.auth"
        #endif
    }()

    private enum Key {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let userId = "user_id"
        static let userEmail = "user_email"
        static let userDisplayName = "user_display_name"
    }

    private init() {}

    // MARK: - Access Token

    var accessToken: String? {
        get { load(for: Key.accessToken) }
        set {
            if let value = newValue {
                save(value, for: Key.accessToken)
            } else {
                delete(for: Key.accessToken)
            }
        }
    }

    // MARK: - Refresh Token

    var refreshToken: String? {
        get { load(for: Key.refreshToken) }
        set {
            if let value = newValue {
                save(value, for: Key.refreshToken)
            } else {
                delete(for: Key.refreshToken)
            }
        }
    }

    // MARK: - User ID

    var userId: String? {
        get { load(for: Key.userId) }
        set {
            if let value = newValue {
                save(value, for: Key.userId)
            } else {
                delete(for: Key.userId)
            }
        }
    }

    // MARK: - User Email

    var userEmail: String? {
        get { load(for: Key.userEmail) }
        set {
            if let value = newValue {
                save(value, for: Key.userEmail)
            } else {
                delete(for: Key.userEmail)
            }
        }
    }

    // MARK: - User Display Name

    var userDisplayName: String? {
        get { load(for: Key.userDisplayName) }
        set {
            if let value = newValue {
                save(value, for: Key.userDisplayName)
            } else {
                delete(for: Key.userDisplayName)
            }
        }
    }

    // MARK: - Bulk Operations

    func saveAuthTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func saveUser(_ user: AuthUser) {
        userId = user.id
        userEmail = user.email
        userDisplayName = user.displayName
    }

    func clearAll() {
        accessToken = nil
        refreshToken = nil
        userId = nil
        userEmail = nil
        userDisplayName = nil
        print("🔐 [SecureTokenStorage] All auth tokens cleared")
    }

    var isAuthenticated: Bool {
        accessToken != nil && userId != nil
    }

    // MARK: - Private Keychain Operations

    private func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(newQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("❌ [SecureTokenStorage] Failed to save \(key): \(status)")
        }
    }

    private func load(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }
}

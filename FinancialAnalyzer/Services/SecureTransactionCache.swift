import Foundation
import CryptoKit

/// Encrypted local cache for transaction and account data.
/// Uses AES-256-GCM encryption with Keychain-stored keys.
/// Cache expires after 24 hours.
final class SecureTransactionCache {
    static let shared = SecureTransactionCache()

    private let cacheDirectory: URL
    private let keyIdentifier: String
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24 hours

    private init() {
        // Use different cache directories for dev vs production
        #if DEBUG
        self.keyIdentifier = "com.financialanalyzer.cache.key.dev"
        #else
        self.keyIdentifier = "com.financialanalyzer.cache.key"
        #endif

        // Create cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cacheDir.appendingPathComponent("SecureFinancialCache", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        print("🔐 [SecureCache] Initialized at: \(cacheDirectory.path)")
    }

    // MARK: - Transaction Cache

    func cacheTransactions(_ transactions: [Transaction], for itemId: String) {
        let cacheFile = cacheDirectory.appendingPathComponent("txn_\(itemId).enc")

        do {
            let cacheData = CachedTransactions(transactions: transactions, timestamp: Date())
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let plaintext = try encoder.encode(cacheData)

            let encrypted = try encrypt(plaintext)
            try encrypted.write(to: cacheFile, options: [.atomic, .completeFileProtection])

            print("🔐 [SecureCache] Cached \(transactions.count) transactions for itemId: \(itemId.prefix(10))...")
        } catch {
            print("❌ [SecureCache] Failed to cache transactions: \(error.localizedDescription)")
        }
    }

    func loadTransactions(for itemId: String) -> (transactions: [Transaction], isExpired: Bool)? {
        let cacheFile = cacheDirectory.appendingPathComponent("txn_\(itemId).enc")

        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            print("📂 [SecureCache] No transaction cache for itemId: \(itemId.prefix(10))...")
            return nil
        }

        do {
            let encrypted = try Data(contentsOf: cacheFile)
            let plaintext = try decrypt(encrypted)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cacheData = try decoder.decode(CachedTransactions.self, from: plaintext)

            let isExpired = Date().timeIntervalSince(cacheData.timestamp) > cacheValidityDuration
            let ageMinutes = Int(Date().timeIntervalSince(cacheData.timestamp) / 60)

            print("🔐 [SecureCache] Loaded \(cacheData.transactions.count) transactions (age: \(ageMinutes)m, expired: \(isExpired))")
            return (cacheData.transactions, isExpired)
        } catch {
            print("❌ [SecureCache] Failed to load transactions: \(error.localizedDescription)")
            // Delete corrupted cache
            try? FileManager.default.removeItem(at: cacheFile)
            return nil
        }
    }

    // MARK: - Account Cache

    func cacheAccounts(_ accounts: [BankAccount], for userId: String) {
        let cacheFile = cacheDirectory.appendingPathComponent("acct_\(userId).enc")

        do {
            let cacheData = CachedAccounts(accounts: accounts, timestamp: Date())
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let plaintext = try encoder.encode(cacheData)

            let encrypted = try encrypt(plaintext)
            try encrypted.write(to: cacheFile, options: [.atomic, .completeFileProtection])

            print("🔐 [SecureCache] Cached \(accounts.count) accounts for userId: \(userId.prefix(10))...")
        } catch {
            print("❌ [SecureCache] Failed to cache accounts: \(error.localizedDescription)")
        }
    }

    func loadAccounts(for userId: String) -> (accounts: [BankAccount], isExpired: Bool)? {
        let cacheFile = cacheDirectory.appendingPathComponent("acct_\(userId).enc")

        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            print("📂 [SecureCache] No account cache for userId: \(userId.prefix(10))...")
            return nil
        }

        do {
            let encrypted = try Data(contentsOf: cacheFile)
            let plaintext = try decrypt(encrypted)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cacheData = try decoder.decode(CachedAccounts.self, from: plaintext)

            let isExpired = Date().timeIntervalSince(cacheData.timestamp) > cacheValidityDuration
            let ageMinutes = Int(Date().timeIntervalSince(cacheData.timestamp) / 60)

            print("🔐 [SecureCache] Loaded \(cacheData.accounts.count) accounts (age: \(ageMinutes)m, expired: \(isExpired))")
            return (cacheData.accounts, isExpired)
        } catch {
            print("❌ [SecureCache] Failed to load accounts: \(error.localizedDescription)")
            // Delete corrupted cache
            try? FileManager.default.removeItem(at: cacheFile)
            return nil
        }
    }

    // MARK: - Cache Management

    func invalidateCache(for itemId: String) {
        let txnFile = cacheDirectory.appendingPathComponent("txn_\(itemId).enc")
        try? FileManager.default.removeItem(at: txnFile)
        print("🗑️ [SecureCache] Invalidated transaction cache for itemId: \(itemId.prefix(10))...")
    }

    func invalidateAccountCache(for userId: String) {
        let acctFile = cacheDirectory.appendingPathComponent("acct_\(userId).enc")
        try? FileManager.default.removeItem(at: acctFile)
        print("🗑️ [SecureCache] Invalidated account cache for userId: \(userId.prefix(10))...")
    }

    func clearAllCaches() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "enc" {
                try FileManager.default.removeItem(at: file)
            }
            print("🗑️ [SecureCache] Cleared all caches (\(files.count) files)")
        } catch {
            print("❌ [SecureCache] Failed to clear caches: \(error.localizedDescription)")
        }
    }

    func cacheAge(for itemId: String) -> TimeInterval? {
        let cacheFile = cacheDirectory.appendingPathComponent("txn_\(itemId).enc")

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: cacheFile.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return nil
        }

        return Date().timeIntervalSince(modDate)
    }

    // MARK: - Encryption

    private func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try AES.GCM.seal(data, using: key)

        guard let combined = sealedBox.combined else {
            throw SecureCacheError.encryptionFailed
        }

        return combined
    }

    private func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Key Management

    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        // Try to load existing key from Keychain
        if let keyData = try? KeychainService.shared.load(for: keyIdentifier),
           let data = Data(base64Encoded: keyData) {
            return SymmetricKey(data: data)
        }

        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try KeychainService.shared.save(keyData.base64EncodedString(), for: keyIdentifier)
        print("🔐 [SecureCache] Generated new encryption key")
        return newKey
    }

    func deleteEncryptionKey() {
        try? KeychainService.shared.delete(for: keyIdentifier)
        print("🗑️ [SecureCache] Deleted encryption key")
    }

    // MARK: - Cache Data Models

    private struct CachedTransactions: Codable {
        let transactions: [Transaction]
        let timestamp: Date
    }

    private struct CachedAccounts: Codable {
        let accounts: [BankAccount]
        let timestamp: Date
    }
}

// MARK: - Errors

enum SecureCacheError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt cache data"
        case .decryptionFailed:
            return "Failed to decrypt cache data"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        }
    }
}

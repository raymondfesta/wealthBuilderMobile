import Foundation
import LinkKit

class PlaidService: ObservableObject {
    @Published var isLinkActive = false
    @Published var linkedAccounts: [BankAccount] = []
    @Published var error: PlaidError?

    private let baseURL: String
    private var linkHandler: Handler?

    // Link token caching
    private var cachedLinkToken: String?
    private var linkTokenExpiration: Date?
    private let linkTokenValidityDuration: TimeInterval = 20 * 60 // 20 minutes (tokens expire at 30, we refresh at 20)

    init(baseURL: String = "http://192.168.1.8:3000") {
        self.baseURL = baseURL
    }

    // MARK: - Link Token Creation

    /// Gets a valid link token, using cache if available
    func getLinkToken() async throws -> String {
        // Check if we have a valid cached token
        if let token = cachedLinkToken,
           let expiration = linkTokenExpiration,
           expiration > Date() {
            print("✅ [PlaidService] Using cached link token (expires in \(Int(expiration.timeIntervalSinceNow))s)")
            return token
        }

        // Cache miss or expired, create new token
        print("🔄 [PlaidService] Creating new link token...")
        let token = try await createLinkToken()
        cachedLinkToken = token
        linkTokenExpiration = Date().addingTimeInterval(linkTokenValidityDuration)
        print("✅ [PlaidService] Link token created and cached")
        return token
    }

    /// Force refresh the link token (for background refresh)
    func refreshLinkToken() async throws {
        print("🔄 [PlaidService] Refreshing link token in background...")
        let token = try await createLinkToken()
        cachedLinkToken = token
        linkTokenExpiration = Date().addingTimeInterval(linkTokenValidityDuration)
        print("✅ [PlaidService] Link token refreshed successfully")
    }

    private func createLinkToken() async throws -> String {
        let endpoint = "\(baseURL)/api/plaid/create_link_token"

        guard let url = URL(string: endpoint) else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.networkError
        }

        let linkTokenResponse = try JSONDecoder().decode(LinkTokenResponse.self, from: data)
        return linkTokenResponse.linkToken
    }

    // MARK: - Plaid Link Flow

    func presentPlaidLink(linkToken: String, from viewController: UIViewController?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            var configuration = LinkTokenConfiguration(token: linkToken) { success in
                Task {
                    do {
                        try await self.exchangePublicToken(success.publicToken)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            configuration.onExit = { exit in
                if let error = exit.error {
                    continuation.resume(throwing: PlaidError.linkExited(error.localizedDescription))
                } else {
                    continuation.resume(throwing: PlaidError.userCancelled)
                }
            }

            // Plaid Link UI operations must happen on the main thread
            DispatchQueue.main.async {
                let result = Plaid.create(configuration)

                switch result {
                case .success(let handler):
                    self.linkHandler = handler
                    if let vc = viewController {
                        handler.open(presentUsing: .viewController(vc))
                    } else {
                        handler.open(presentUsing: .custom({ linkViewController in
                            // Present modally since we don't have a view controller
                            // Already on main thread, no need for dispatch
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let rootVC = window.rootViewController {
                                rootVC.present(linkViewController, animated: true)
                            }
                        }))
                    }
                case .failure(let error):
                    continuation.resume(throwing: PlaidError.linkCreationFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Token Exchange

    private func exchangePublicToken(_ publicToken: String) async throws {
        print("🔄 [PlaidService] Exchanging public token for access token...")
        let endpoint = "\(baseURL)/api/plaid/exchange_public_token"

        guard let url = URL(string: endpoint) else {
            print("❌ [PlaidService] Invalid URL: \(endpoint)")
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["public_token": publicToken]
        request.httpBody = try JSONEncoder().encode(body)

        print("🔄 [PlaidService] Calling \(endpoint)...")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PlaidService] Invalid HTTP response")
            throw PlaidError.networkError
        }

        print("🔄 [PlaidService] Response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("❌ [PlaidService] Error response: \(responseStr)")
            }
            throw PlaidError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: data)
        print("✅ [PlaidService] Token exchanged successfully, itemId: \(tokenResponse.itemId)")

        // Store access token securely
        try KeychainService.shared.save(
            tokenResponse.accessToken,
            for: tokenResponse.itemId
        )
        print("✅ [PlaidService] Access token saved to Keychain for itemId: \(tokenResponse.itemId)")

        // Trigger transaction refresh so Plaid populates transactions
        await refreshTransactions(accessToken: tokenResponse.accessToken)
    }

    // MARK: - Fetch Accounts

    func fetchAccounts(accessToken: String) async throws -> [BankAccount] {
        print("🔄 [PlaidService] Fetching accounts...")
        let endpoint = "\(baseURL)/api/plaid/accounts"

        guard let url = URL(string: endpoint) else {
            print("❌ [PlaidService] Invalid URL: \(endpoint)")
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["access_token": accessToken]
        request.httpBody = try JSONEncoder().encode(body)

        print("🔄 [PlaidService] Calling \(endpoint)...")
        print("🔄 [PlaidService] Access token (first 10 chars): \(String(accessToken.prefix(10)))...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PlaidService] Invalid HTTP response")
            throw PlaidError.networkError
        }

        print("🔄 [PlaidService] Response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("❌ [PlaidService] Error response: \(responseStr)")
            }
            throw PlaidError.accountFetchFailed
        }

        // Log raw response for debugging
        if let responseStr = String(data: data, encoding: .utf8) {
            print("🔄 [PlaidService] Raw response: \(responseStr)")
        }

        let accountsResponse = try JSONDecoder().decode(AccountsResponse.self, from: data)
        print("✅ [PlaidService] Fetched \(accountsResponse.accounts.count) account(s)")

        // Log details about each account
        for (index, account) in accountsResponse.accounts.enumerated() {
            print("✅ [PlaidService]   Account \(index + 1): \(account.name) (id: \(account.id), itemId: \(account.itemId))")
        }

        return accountsResponse.accounts
    }

    // MARK: - Fetch Transactions

    func fetchTransactions(
        accessToken: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [Transaction] {
        let endpoint = "\(baseURL)/api/plaid/transactions"

        guard let url = URL(string: endpoint) else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Increase timeout to 120 seconds for transaction fetching (can be slow on first sync)
        request.timeoutInterval = 120

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let body: [String: String] = [
            "access_token": accessToken,
            "start_date": dateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate)
        ]
        request.httpBody = try JSONEncoder().encode(body)

        print("🔄 [PlaidService] Fetching transactions from \(dateFormatter.string(from: startDate)) to \(dateFormatter.string(from: endDate))...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("❌ [PlaidService] Transaction fetch failed with status: \(statusCode)")
            print("❌ [PlaidService] Response: \(responseBody)")
            throw PlaidError.transactionFetchFailed
        }

        // Log raw response size for debugging
        print("📊 [PlaidService] Response size: \(data.count) bytes")

        let transactionsResponse = try JSONDecoder().decode(TransactionsResponse.self, from: data)
        print("✅ [PlaidService] Successfully fetched \(transactionsResponse.transactions.count) transactions (total reported: \(transactionsResponse.totalTransactions))")
        return transactionsResponse.transactions
    }

    // MARK: - Refresh Transactions

    /// Triggers Plaid to refresh transactions for an item
    /// Call after token exchange to ensure transactions are populated
    func refreshTransactions(accessToken: String) async {
        print("🔄 [PlaidService] Triggering transaction refresh...")

        guard let url = URL(string: "\(baseURL)/api/plaid/transactions/refresh") else {
            print("❌ [PlaidService] Invalid refresh URL: \(baseURL)/api/plaid/transactions/refresh")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(["access_token": accessToken])
        } catch {
            print("❌ [PlaidService] Failed to encode refresh request: \(error)")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [PlaidService] Invalid HTTP response for refresh")
                return
            }

            let statusCode = httpResponse.statusCode
            let responseStr = String(data: data, encoding: .utf8) ?? "(no body)"

            if statusCode == 202 {
                print("✅ [PlaidService] Transactions refresh triggered (status: \(statusCode))")
            } else {
                print("⚠️ [PlaidService] Transactions refresh returned status \(statusCode): \(responseStr)")
            }
        } catch {
            print("❌ [PlaidService] Transactions refresh network error: \(error.localizedDescription)")
        }
    }

    // MARK: - Remove Account

    func removeAccount(accessToken: String) async throws -> String {
        let endpoint = "\(baseURL)/api/plaid/item/remove"

        guard let url = URL(string: endpoint) else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["access_token": accessToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.accountRemovalFailed
        }

        let removeResponse = try JSONDecoder().decode(RemoveItemResponse.self, from: data)

        guard let itemId = removeResponse.itemId else {
            throw PlaidError.accountRemovalFailed
        }

        return itemId
    }
}

// MARK: - Response Models

private struct LinkTokenResponse: Decodable {
    let linkToken: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

private struct AccessTokenResponse: Decodable {
    let accessToken: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case itemId = "item_id"
    }
}

private struct AccountsResponse: Decodable {
    let accounts: [BankAccount]
}

private struct TransactionsResponse: Decodable {
    let transactions: [Transaction]
    let totalTransactions: Int

    enum CodingKeys: String, CodingKey {
        case transactions
        case totalTransactions = "total_transactions"
    }
}

private struct RemoveItemResponse: Decodable {
    let removed: Bool
    let itemId: String?

    enum CodingKeys: String, CodingKey {
        case removed
        case itemId = "item_id"
    }
}

// MARK: - Error Handling

enum PlaidError: LocalizedError {
    case invalidURL
    case networkError
    case tokenExchangeFailed
    case accountFetchFailed
    case transactionFetchFailed
    case accountRemovalFailed
    case linkCreationFailed(String)
    case linkExited(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint"
        case .networkError:
            return "Network connection failed"
        case .tokenExchangeFailed:
            return "Failed to exchange token"
        case .accountFetchFailed:
            return "Failed to fetch accounts"
        case .transactionFetchFailed:
            return "Failed to fetch transactions"
        case .accountRemovalFailed:
            return "Failed to remove account"
        case .linkCreationFailed(let message):
            return "Link creation failed: \(message)"
        case .linkExited(let message):
            return "Link exited: \(message)"
        case .userCancelled:
            return "User cancelled the link process"
        }
    }
}

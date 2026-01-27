import Foundation
import LinkKit

class PlaidService: ObservableObject {
    @Published var isLinkActive = false
    @Published var linkedAccounts: [BankAccount] = []
    @Published var error: PlaidError?

    private let baseURL: String
    private var linkHandler: Handler?
    private let tokenStorage = SecureTokenStorage.shared

    // Link token caching
    private var cachedLinkToken: String?
    private var linkTokenExpiration: Date?
    private let linkTokenValidityDuration: TimeInterval = 20 * 60 // 20 minutes (tokens expire at 30, we refresh at 20)

    init(baseURL: String = AppConfig.baseURL) {
        self.baseURL = baseURL
    }

    // MARK: - Auth Header Helper

    /// Adds Authorization header if user is authenticated
    private func addAuthHeader(to request: inout URLRequest) {
        if let accessToken = tokenStorage.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔐 [PlaidService] Auth header added (token: \(accessToken.prefix(20))...)")
        } else {
            print("⚠️ [PlaidService] No access token available - request will be unauthenticated")
        }
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
        addAuthHeader(to: &request)

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
        print("🔄 [PlaidService] Exchanging public token...")
        let endpoint = "\(baseURL)/api/plaid/exchange_public_token"

        guard let url = URL(string: endpoint) else {
            print("❌ [PlaidService] Invalid URL: \(endpoint)")
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

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

        let tokenResponse = try JSONDecoder().decode(ExchangeTokenResponse.self, from: data)
        print("✅ [PlaidService] Token exchanged successfully, itemId: \(tokenResponse.itemId)")

        // Store itemId in Keychain (backend now handles access tokens)
        // We use a placeholder value since backend stores the actual token
        try KeychainService.shared.save("backend-managed", for: tokenResponse.itemId)
        print("✅ [PlaidService] ItemId saved to Keychain: \(tokenResponse.itemId)")

        // Trigger transaction refresh so Plaid populates transactions
        await refreshTransactions(itemId: tokenResponse.itemId)
    }

    // MARK: - Fetch Accounts

    func fetchAccounts(itemId: String) async throws -> [BankAccount] {
        print("🔄 [PlaidService] Fetching accounts for item: \(itemId)")
        let endpoint = "\(baseURL)/api/plaid/accounts"

        guard let url = URL(string: endpoint) else {
            print("❌ [PlaidService] Invalid URL: \(endpoint)")
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        let body = ["item_id": itemId]
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
            throw PlaidError.accountFetchFailed
        }

        let accountsResponse = try JSONDecoder().decode(AccountsResponse.self, from: data)
        print("✅ [PlaidService] Fetched \(accountsResponse.accounts.count) account(s)")

        return accountsResponse.accounts
    }

    // MARK: - Fetch Transactions

    func fetchTransactions(
        itemId: String,
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
        addAuthHeader(to: &request)
        // Increase timeout to 120 seconds for transaction fetching (can be slow on first sync)
        request.timeoutInterval = 120

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let body: [String: String] = [
            "item_id": itemId,
            "start_date": dateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate)
        ]
        request.httpBody = try JSONEncoder().encode(body)

        print("🔄 [PlaidService] Fetching transactions for item \(itemId) from \(dateFormatter.string(from: startDate)) to \(dateFormatter.string(from: endDate))...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("❌ [PlaidService] Transaction fetch failed with status: \(statusCode)")
            print("❌ [PlaidService] Response: \(responseBody)")
            throw PlaidError.transactionFetchFailed
        }

        let transactionsResponse = try JSONDecoder().decode(TransactionsResponse.self, from: data)
        print("✅ [PlaidService] Successfully fetched \(transactionsResponse.transactions.count) transactions")
        return transactionsResponse.transactions
    }

    // MARK: - Refresh Transactions

    /// Triggers Plaid to refresh transactions for an item
    /// Call after token exchange to ensure transactions are populated
    func refreshTransactions(itemId: String) async {
        print("🔄 [PlaidService] Triggering transaction refresh for item: \(itemId)")

        guard let url = URL(string: "\(baseURL)/api/plaid/transactions/refresh") else {
            print("❌ [PlaidService] Invalid refresh URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        do {
            request.httpBody = try JSONEncoder().encode(["item_id": itemId])
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
                print("✅ [PlaidService] Transactions refresh triggered")
            } else {
                print("⚠️ [PlaidService] Transactions refresh returned status \(statusCode): \(responseStr)")
            }
        } catch {
            print("❌ [PlaidService] Transactions refresh network error: \(error.localizedDescription)")
        }
    }

    // MARK: - Remove Account

    func removeAccount(itemId: String) async throws {
        print("🗑️ [PlaidService] Removing item: \(itemId)")
        let endpoint = "\(baseURL)/api/plaid/item/remove"

        guard let url = URL(string: endpoint) else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        let body = ["item_id": itemId]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "(no body)"
            print("❌ [PlaidService] Remove failed: \(responseStr)")
            throw PlaidError.accountRemovalFailed
        }

        let removeResponse = try JSONDecoder().decode(RemoveItemResponse.self, from: data)
        print("✅ [PlaidService] Item removed: \(removeResponse.itemId ?? itemId)")
    }

    // MARK: - Get User's Plaid Items

    func getPlaidItems() async throws -> [PlaidItem] {
        print("📋 [PlaidService] Fetching user's Plaid items...")
        let response = try await getPlaidItemsWithStatus()
        return response.items.map { item in
            PlaidItem(
                itemId: item.itemId,
                institutionName: item.institutionName,
                createdAt: item.createdAt
            )
        }
    }

    /// Fetches user's Plaid items with onboarding status from backend
    func getPlaidItemsWithStatus() async throws -> PlaidItemsWithStatusResponse {
        print("📋 [PlaidService] Fetching user's Plaid items with status...")

        guard let url = URL(string: "\(baseURL)/api/plaid/items") else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaidError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "(no body)"
            print("❌ [PlaidService] Get items failed: \(responseStr)")
            throw PlaidError.serverError("Status: \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(PlaidItemsWithStatusResponse.self, from: data)
        print("✅ [PlaidService] Found \(result.items.count) Plaid item(s), onboarding: \(result.onboardingCompleted)")
        return result
    }

    // MARK: - Allocation Plan

    /// Fetches user's allocation plan from backend
    func getAllocationPlan() async throws -> AllocationPlanResponse {
        print("📋 [PlaidService] Fetching allocation plan...")

        guard let url = URL(string: "\(baseURL)/api/user/allocation-plan") else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.serverError("Failed to fetch allocation plan")
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(AllocationPlanResponse.self, from: data)

        print("✅ [PlaidService] Fetched \(result.allocations.count) allocation(s), hasPlan: \(result.hasPlan)")
        return result
    }

    /// Saves user's allocation plan to backend
    func saveAllocationPlan(allocations: [AllocationBucket], paycheckSchedule: PaycheckSchedule?) async throws {
        print("💾 [PlaidService] Saving allocation plan...")

        guard let url = URL(string: "\(baseURL)/api/user/allocation-plan") else {
            throw PlaidError.invalidURL
        }

        // Convert to request format
        let allocationsToSave = allocations.map { bucket in
            AllocationToSave(
                bucketType: bucket.type.rawValue,
                percentage: bucket.percentageOfIncome,
                targetAmount: bucket.targetAmount,
                linkedAccountId: bucket.linkedAccountIds.first,
                linkedAccountName: nil, // Account name resolved on restore
                isCustomized: bucket.changeFromOriginal != 0,
                presetTier: bucket.selectedPresetTier.rawValue
            )
        }

        var paycheckToSave: PaycheckScheduleToSave?
        if let schedule = paycheckSchedule {
            let formatter = ISO8601DateFormatter()
            let nextDates = schedule.nextPaycheckDates(from: Date(), count: 1)
            paycheckToSave = PaycheckScheduleToSave(
                frequency: schedule.frequency.rawValue,
                estimatedAmount: schedule.estimatedAmount,
                nextPaycheckDate: nextDates.first.map { formatter.string(from: $0) },
                isConfirmed: schedule.isUserConfirmed,
                detectedEmployer: nil
            )
        }

        let requestBody = SaveAllocationPlanRequest(
            allocations: allocationsToSave,
            paycheckSchedule: paycheckToSave
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlaidError.serverError("Failed to save allocation plan: \(errorBody)")
        }

        print("✅ [PlaidService] Allocation plan saved")
    }

    /// Marks onboarding as complete in backend
    func completeOnboarding() async throws {
        print("🎯 [PlaidService] Marking onboarding complete...")

        guard let url = URL(string: "\(baseURL)/api/user/complete-onboarding") else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaidError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlaidError.serverError("Failed to complete onboarding: \(errorBody)")
        }

        print("✅ [PlaidService] Onboarding marked complete")
    }
}

// MARK: - Plaid Item Model

struct PlaidItem: Decodable, Identifiable {
    let itemId: String
    let institutionName: String?
    let createdAt: String?

    var id: String { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case institutionName = "institution_name"
        case createdAt = "created_at"
    }
}

// MARK: - Response Models

private struct LinkTokenResponse: Decodable {
    let linkToken: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

private struct ExchangeTokenResponse: Decodable {
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
    }
}

// PlaidItemsWithStatusResponse is now defined in Models/UserStatus.swift

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
    case serverError(String)

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
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

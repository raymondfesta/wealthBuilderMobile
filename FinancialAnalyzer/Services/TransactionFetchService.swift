import Foundation

/// Cache-first transaction fetching with retry logic.
/// Wraps PlaidService to add encrypted caching layer.
final class TransactionFetchService {
    static let shared = TransactionFetchService()

    private let plaidService: PlaidService
    private let cache = SecureTransactionCache.shared
    private let baseURL: String

    private init() {
        self.plaidService = PlaidService()

        #if DEBUG
        self.baseURL = "http://localhost:3000"
        #else
        self.baseURL = "https://api.yourproductionserver.com"
        #endif
    }

    // For dependency injection in tests
    init(plaidService: PlaidService, baseURL: String = "http://localhost:3000") {
        self.plaidService = plaidService
        self.baseURL = baseURL
    }

    // MARK: - Fetch Transactions (Cache-First)

    /// Fetches transactions with cache-first strategy.
    /// Returns cached data if valid, otherwise fetches from Plaid.
    /// - Parameters:
    ///   - itemId: Item ID for API calls and cache lookup
    ///   - startDate: Start date for transaction range
    ///   - endDate: End date for transaction range
    ///   - forceRefresh: Skip cache and fetch fresh data
    /// - Returns: Tuple of transactions and whether they came from cache
    func fetchTransactions(
        itemId: String,
        startDate: Date,
        endDate: Date,
        forceRefresh: Bool = false
    ) async throws -> (transactions: [Transaction], fromCache: Bool) {

        // Check cache first (unless force refresh)
        if !forceRefresh {
            if let cached = cache.loadTransactions(for: itemId) {
                if !cached.isExpired {
                    print("✅ [FetchService] Cache hit: \(cached.transactions.count) transactions")
                    return (cached.transactions, true)
                } else {
                    print("⏰ [FetchService] Cache expired, returning stale data + refreshing in background")
                    // Return stale data immediately, refresh in background
                    Task {
                        await self.refreshInBackground(
                            itemId: itemId,
                            startDate: startDate,
                            endDate: endDate
                        )
                    }
                    return (cached.transactions, true)
                }
            }
        }

        // No cache or force refresh - fetch from API
        print("🔄 [FetchService] Cache miss, fetching from Plaid...")

        // Check sync status first
        let isReady = await checkSyncStatus(itemId: itemId)
        if !isReady {
            print("⏳ [FetchService] Waiting for Plaid sync...")
            try await waitForSync(itemId: itemId)
        }

        let transactions = try await fetchWithRetry(
            itemId: itemId,
            startDate: startDate,
            endDate: endDate
        )

        // Cache the results
        cache.cacheTransactions(transactions, for: itemId)

        return (transactions, false)
    }

    // MARK: - Sync Status

    private func checkSyncStatus(itemId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/plaid/sync-status") else {
            return true // Assume ready if can't check
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        addAuthHeader(to: &request)

        do {
            request.httpBody = try JSONEncoder().encode(["item_id": itemId])
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SyncStatusResponse.self, from: data)
            return response.status == "ready"
        } catch {
            print("⚠️ [FetchService] Sync status check failed: \(error.localizedDescription)")
            return true // Assume ready on error
        }
    }

    private func waitForSync(itemId: String, maxAttempts: Int = 15) async throws {
        for attempt in 1...maxAttempts {
            let isReady = await checkSyncStatus(itemId: itemId)
            if isReady {
                print("✅ [FetchService] Plaid sync ready after \(attempt) check(s)")
                return
            }

            print("⏳ [FetchService] Waiting for sync... (\(attempt)/\(maxAttempts))")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }

        print("⚠️ [FetchService] Sync wait timeout, proceeding anyway")
    }

    private func addAuthHeader(to request: inout URLRequest) {
        if let accessToken = SecureTokenStorage.shared.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }

    // MARK: - Retry Logic

    private func fetchWithRetry(
        itemId: String,
        startDate: Date,
        endDate: Date,
        maxRetries: Int = 3
    ) async throws -> [Transaction] {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                return try await plaidService.fetchTransactions(
                    itemId: itemId,
                    startDate: startDate,
                    endDate: endDate
                )
            } catch {
                lastError = error
                print("⚠️ [FetchService] Attempt \(attempt)/\(maxRetries) failed: \(error.localizedDescription)")

                // Don't retry on certain errors
                if case PlaidError.invalidURL = error { throw error }
                if case PlaidError.accountFetchFailed = error { throw error }

                if attempt < maxRetries {
                    // Exponential backoff: 2s, 4s, 8s
                    let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? PlaidError.transactionFetchFailed
    }

    // MARK: - Background Refresh

    private func refreshInBackground(
        itemId: String,
        startDate: Date,
        endDate: Date
    ) async {
        do {
            let transactions = try await fetchWithRetry(
                itemId: itemId,
                startDate: startDate,
                endDate: endDate
            )
            cache.cacheTransactions(transactions, for: itemId)
            print("✅ [FetchService] Background refresh complete: \(transactions.count) transactions")
        } catch {
            print("⚠️ [FetchService] Background refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Cache Management

    func invalidateCache(for itemId: String) {
        cache.invalidateCache(for: itemId)
    }

    func clearAllCaches() {
        cache.clearAllCaches()
    }

    func getCacheAge(for itemId: String) -> TimeInterval? {
        cache.cacheAge(for: itemId)
    }

    // MARK: - Response Models

    private struct SyncStatusResponse: Decodable {
        let status: String
        let transactionsAvailable: Int

        enum CodingKeys: String, CodingKey {
            case status
            case transactionsAvailable = "transactions_available"
        }
    }
}

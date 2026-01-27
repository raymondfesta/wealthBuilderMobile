//
//  DataRefreshService.swift
//  FinancialAnalyzer
//
//  Centralized data refresh strategy and execution
//

import Foundation
import Combine

/// Refresh strategy based on cache age and context
enum RefreshStrategy: Equatable {
    /// No refresh needed - cache is fresh
    case none

    /// Refresh balances only (fast, background)
    case balancesOnly

    /// Full refresh in background (user sees cached data)
    case backgroundFull

    /// Full refresh in foreground (user sees loading)
    case foregroundFull

    /// User-initiated refresh (always full)
    case userInitiated

    var description: String {
        switch self {
        case .none: return "No refresh needed"
        case .balancesOnly: return "Refreshing balances"
        case .backgroundFull: return "Updating data"
        case .foregroundFull: return "Loading data"
        case .userInitiated: return "Refreshing"
        }
    }

    var showsLoadingUI: Bool {
        switch self {
        case .none, .balancesOnly, .backgroundFull:
            return false
        case .foregroundFull, .userInitiated:
            return true
        }
    }

    var showsSubtleIndicator: Bool {
        switch self {
        case .balancesOnly, .backgroundFull:
            return true
        default:
            return false
        }
    }
}

/// Result of a refresh operation
struct RefreshResult {
    let strategy: RefreshStrategy
    let accountsUpdated: Int
    let transactionsUpdated: Int
    let balancesUpdated: Bool
    let error: Error?
    let duration: TimeInterval

    var success: Bool { error == nil }
}

/// Centralized data refresh service
@MainActor
final class DataRefreshService: ObservableObject {

    // MARK: - Singleton

    static let shared = DataRefreshService()

    // MARK: - Configuration

    /// Time thresholds for refresh decisions
    enum Thresholds {
        /// Balances considered fresh (15 minutes)
        static let balancesFresh: TimeInterval = 15 * 60

        /// Transactions considered fresh (4 hours)
        static let transactionsFresh: TimeInterval = 4 * 60 * 60

        /// Data considered very stale - show loading UI (7 days)
        static let veryStale: TimeInterval = 7 * 24 * 60 * 60
    }

    // MARK: - Published State

    @Published private(set) var isRefreshing = false
    @Published private(set) var currentStrategy: RefreshStrategy = .none
    @Published private(set) var lastRefreshResult: RefreshResult?

    /// Whether device is offline (observed from NetworkMonitor)
    var isOffline: Bool {
        !NetworkMonitor.shared.isConnected
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        observeNetworkStatus()
    }

    // MARK: - Strategy Determination

    /// Determines the appropriate refresh strategy based on cache metadata
    func determineStrategy(
        metadata: CacheMetadata,
        isAppLaunch: Bool = false,
        isUserInitiated: Bool = false
    ) -> RefreshStrategy {

        // User-initiated always does full refresh
        if isUserInitiated {
            return .userInitiated
        }

        // No cached data = must do foreground refresh
        if !metadata.hasData {
            return .foregroundFull
        }

        // Check network availability
        if isOffline {
            return .none  // Can't refresh without network
        }

        // Determine based on cache age
        let balancesAge = metadata.balancesAge ?? .infinity
        let transactionsAge = metadata.transactionsAge ?? .infinity

        // Very stale data = foreground refresh
        if transactionsAge > Thresholds.veryStale {
            return .foregroundFull
        }

        // Stale transactions = background full refresh
        if transactionsAge > Thresholds.transactionsFresh {
            return .backgroundFull
        }

        // Stale balances only = quick balance refresh
        if balancesAge > Thresholds.balancesFresh {
            return .balancesOnly
        }

        // Everything is fresh
        return .none
    }

    // MARK: - Refresh Execution

    /// Execute refresh with the given strategy
    func executeRefresh(
        strategy: RefreshStrategy,
        itemIds: [String],
        plaidService: PlaidService,
        onAccountsUpdated: @escaping ([BankAccount]) -> Void,
        onTransactionsUpdated: @escaping ([Transaction]) -> Void,
        onBalancesUpdated: @escaping ([BankAccount]) -> Void
    ) async -> RefreshResult {

        guard strategy != .none else {
            return RefreshResult(
                strategy: strategy,
                accountsUpdated: 0,
                transactionsUpdated: 0,
                balancesUpdated: false,
                error: nil,
                duration: 0
            )
        }

        let startTime = Date()
        isRefreshing = true
        currentStrategy = strategy

        defer {
            isRefreshing = false
            currentStrategy = .none
        }

        do {
            var accountsUpdated = 0
            var transactionsUpdated = 0
            var balancesUpdated = false

            switch strategy {
            case .balancesOnly:
                // Quick balance refresh
                let accounts = try await fetchBalances(itemIds: itemIds, plaidService: plaidService)
                onBalancesUpdated(accounts)
                balancesUpdated = true
                accountsUpdated = accounts.count

            case .backgroundFull, .foregroundFull, .userInitiated:
                // Full refresh
                let (accounts, transactions) = try await fetchFullData(
                    itemIds: itemIds,
                    plaidService: plaidService
                )
                onAccountsUpdated(accounts)
                onTransactionsUpdated(transactions)
                accountsUpdated = accounts.count
                transactionsUpdated = transactions.count
                balancesUpdated = true

            case .none:
                break
            }

            let result = RefreshResult(
                strategy: strategy,
                accountsUpdated: accountsUpdated,
                transactionsUpdated: transactionsUpdated,
                balancesUpdated: balancesUpdated,
                error: nil,
                duration: Date().timeIntervalSince(startTime)
            )

            lastRefreshResult = result
            print("✅ [Refresh] \(strategy.description) completed in \(String(format: "%.1f", result.duration))s - \(accountsUpdated) accounts, \(transactionsUpdated) transactions")

            return result

        } catch {
            let result = RefreshResult(
                strategy: strategy,
                accountsUpdated: 0,
                transactionsUpdated: 0,
                balancesUpdated: false,
                error: error,
                duration: Date().timeIntervalSince(startTime)
            )

            lastRefreshResult = result
            print("❌ [Refresh] \(strategy.description) failed: \(error.localizedDescription)")

            return result
        }
    }

    // MARK: - Private Methods

    /// Fetch balances only (fast)
    private func fetchBalances(itemIds: [String], plaidService: PlaidService) async throws -> [BankAccount] {
        var allAccounts: [BankAccount] = []

        for itemId in itemIds {
            let accounts = try await plaidService.fetchAccounts(itemId: itemId)
            allAccounts.append(contentsOf: accounts)
        }

        return allAccounts
    }

    /// Fetch full data (accounts + transactions)
    private func fetchFullData(
        itemIds: [String],
        plaidService: PlaidService
    ) async throws -> ([BankAccount], [Transaction]) {
        var allAccounts: [BankAccount] = []
        var allTransactions: [Transaction] = []

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate) ?? endDate

        for itemId in itemIds {
            // Fetch accounts
            let accounts = try await plaidService.fetchAccounts(itemId: itemId)
            for account in accounts {
                if account.itemId.isEmpty {
                    account.itemId = itemId
                }
            }
            allAccounts.append(contentsOf: accounts)

            // Fetch transactions
            let transactions = try await plaidService.fetchTransactions(
                itemId: itemId,
                startDate: startDate,
                endDate: endDate
            )
            allTransactions.append(contentsOf: transactions)
        }

        return (allAccounts, allTransactions)
    }

    /// Observe network status changes
    private func observeNetworkStatus() {
        NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    print("🌐 [DataRefresh] Network restored")
                } else {
                    print("📴 [DataRefresh] Network lost - refresh disabled")
                }
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

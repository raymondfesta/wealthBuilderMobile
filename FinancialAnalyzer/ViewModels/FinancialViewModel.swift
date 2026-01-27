import Foundation
import SwiftUI

@MainActor
class FinancialViewModel: ObservableObject {
    @Published var summary: AnalysisSnapshot?
    @Published var accounts: [BankAccount] = []
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var error: Error?

    // Loading progress tracking
    @Published var loadingStep: LoadingStep = .idle
    @Published var showLoadingOverlay = false

    // Success feedback
    @Published var showSuccessBanner = false
    @Published var successMessage: String = ""

    // Budget and goal management
    @Published var budgetManager: BudgetManager
    @Published var currentAlert: ProactiveAlert?
    @Published var isShowingGuidance = false

    // Analysis snapshot for Analysis Complete screen
    @Published var analysisSnapshot: AnalysisSnapshot?

    // Allocation schedule
    @Published var allocationScheduleConfig: AllocationScheduleConfig?
    @Published var scheduledAllocations: [ScheduledAllocation] = []
    @Published var allocationHistory: [AllocationExecution] = []

    // Notification navigation
    var navigationCoordinator: NotificationNavigationCoordinator?

    /// Tracks user's progress through the financial planning flow
    @Published var userJourneyState: UserJourneyState = .noAccountsConnected {
        didSet {
            print("📍 [State] \(oldValue.rawValue) → \(userJourneyState.rawValue)")
            validateStateConsistency()
        }
    }

    private let plaidService: PlaidService
    private let transactionFetchService = TransactionFetchService.shared
    private var linkTokenRefreshTask: Task<Void, Never>?

    /// Current authenticated user ID for scoping cache data
    private var currentUserId: String?

    init(plaidService: PlaidService = PlaidService()) {
        self.plaidService = plaidService

        // Set userId BEFORE creating BudgetManager so cache keys are scoped correctly
        if let userId = AuthService.shared.userId {
            self.currentUserId = userId
            print("👤 [ViewModel] Init with user: \(userId.prefix(8))...")
        }

        self.budgetManager = BudgetManager(userId: currentUserId)

        // Skip cache loading if auto-reset is enabled
        // This ensures we start with truly fresh data
        if ProcessInfo.processInfo.arguments.contains("-ResetDataOnLaunch") {
            print("🔄 [ViewModel] Auto-reset detected - skipping cache load for fresh start")
            // State will remain at default: .noAccountsConnected
        } else {
            loadFromCache()
        }

        setupNotificationObservers()
        startLinkTokenPreloading()
    }

    deinit {
        linkTokenRefreshTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - User Session Management

    /// Returns user-scoped cache key. Falls back to base key if no user set.
    private func cacheKey(_ base: String) -> String {
        guard let userId = currentUserId, !userId.isEmpty else { return base }
        return "user_\(userId)_\(base)"
    }

    /// Sets current user and reloads cache with user-scoped keys
    func setCurrentUser(_ userId: String) {
        guard currentUserId != userId else { return }
        print("👤 [ViewModel] Setting current user: \(userId.prefix(8))...")
        currentUserId = userId
        budgetManager.setUserId(userId)
        loadFromCache()
    }

    // MARK: - Link Token Preloading

    /// Preloads link token and refreshes it periodically
    private func startLinkTokenPreloading() {
        linkTokenRefreshTask = Task { @MainActor in
            // Delay initial preload to let app initialize
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Initial preload
            do {
                try await plaidService.refreshLinkToken()
            } catch {
                print("⚠️ [ViewModel] Failed to preload initial link token: \(error.localizedDescription)")
            }

            // Periodic refresh every 15 minutes
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000) // 15 minutes
                guard !Task.isCancelled else { break }

                do {
                    try await plaidService.refreshLinkToken()
                } catch {
                    print("⚠️ [ViewModel] Failed to refresh link token: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Plaid Link

    func connectBankAccount(from viewController: UIViewController?) async {
        print("🔗 [Connect] Starting bank account connection...")

        do {
            // Use cached token for instant modal presentation
            print("🔗 [Connect] Getting link token...")
            let linkToken = try await plaidService.getLinkToken()
            print("🔗 [Connect] Link token obtained, presenting Plaid Link...")
            try await plaidService.presentPlaidLink(linkToken: linkToken, from: viewController)
            print("✅ [Connect] Plaid Link completed successfully!")

            // After successful link, fetch accounts only (Phase 2: stepwise flow)
            print("🔗 [Connect] Fetching accounts after successful link...")
            await fetchAccountsOnly()
            print("✅ [Connect] Account fetch complete!")
        } catch {
            // Handle user cancellation gracefully (not an error, just user choice)
            if case PlaidError.userCancelled = error {
                print("ℹ️ [Connect] User cancelled bank connection")
                // Don't set error - this is intentional user action, not a failure
            } else {
                // Real errors (network, API failures) should be shown to user
                print("❌ [Connect] Error connecting bank account: \(error.localizedDescription)")
                print("❌ [Connect] Error details: \(error)")
                self.error = error
            }
        }
    }

    // MARK: - Phase 2: Stepwise Data Operations

    /// Fetches only account information without transactions or analysis
    /// Used after successful bank connection to show accounts immediately
    func fetchAccountsOnly() async {
        print("🔄 [Fetch Accounts Only] Starting account fetch...")
        isLoading = true
        showLoadingOverlay = true
        loadingStep = .fetchingAccounts
        defer {
            isLoading = false
            showLoadingOverlay = false
            loadingStep = .idle
        }

        do {
            // Get all stored itemIds from Keychain
            print("🔄 [Fetch Accounts Only] Loading itemIds from Keychain...")
            let itemIds = try KeychainService.shared.allKeys()
            print("🔄 [Fetch Accounts Only] Found \(itemIds.count) stored itemId(s): \(itemIds)")

            var allAccounts: [BankAccount] = []

            // Fetch accounts for each linked item
            for itemId in itemIds {
                print("🔄 [Fetch Accounts Only] Processing itemId: \(itemId)")

                do {
                    // Fetch accounts with retry logic (Plaid sandbox may need time to sync)
                    var accounts: [BankAccount] = []
                    var lastError: Error?
                    let maxRetries = 3

                    for attempt in 1...maxRetries {
                        do {
                            print("🔄 [Fetch Accounts Only] Fetching accounts for itemId: \(itemId) (attempt \(attempt)/\(maxRetries))...")
                            accounts = try await plaidService.fetchAccounts(itemId: itemId)
                            print("🔄 [Fetch Accounts Only] Fetched \(accounts.count) account(s) for itemId: \(itemId)")
                            lastError = nil
                            break // Success - exit retry loop
                        } catch {
                            lastError = error
                            print("❌ [Fetch Accounts Only] Attempt \(attempt) failed: \(error.localizedDescription)")

                            // Don't retry on certain errors
                            let errorString = error.localizedDescription.lowercased()
                            if errorString.contains("item") && errorString.contains("not found") {
                                print("⚠️ [Fetch Accounts Only] Item not found - won't retry")
                                break
                            }

                            // Wait before retry (exponential backoff: 1s, 2s, 4s)
                            if attempt < maxRetries {
                                let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000) // nanoseconds
                                print("⚠️ [Fetch Accounts Only] Retrying in \(delay / 1_000_000_000)s...")
                                try? await Task.sleep(nanoseconds: delay)
                            }
                        }
                    }

                    // If all retries failed, throw the last error
                    if let error = lastError {
                        throw error
                    }

                    // Set itemId on each account (should come from backend, but ensure it's set)
                    for account in accounts {
                        if account.itemId.isEmpty {
                            account.itemId = itemId
                        }
                    }

                    allAccounts.append(contentsOf: accounts)
                    print("🔄 [Fetch Accounts Only] Total accounts so far: \(allAccounts.count)")

                } catch {
                    print("❌ [Fetch Accounts Only] Failed to fetch accounts for itemId \(itemId): \(error.localizedDescription)")

                    // Clean up orphaned itemIds
                    let errorString = error.localizedDescription.lowercased()
                    if errorString.contains("item") && errorString.contains("not found") {
                        print("⚠️ [Fetch Accounts Only] Item not found, cleaning up itemId: \(itemId)")
                        try? KeychainService.shared.delete(for: itemId)
                    }
                }
            }

            // Validate we have accounts before proceeding
            guard !allAccounts.isEmpty else {
                print("⚠️ [Fetch Accounts Only] No accounts were fetched, aborting state transition")
                await MainActor.run {
                    self.error = NSError(
                        domain: "FinancialViewModel",
                        code: 100,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Unable to fetch bank accounts. This could be due to a connection issue or the institution may not have provided account data yet. Please try again in a few moments."
                        ]
                    )
                }
                return
            }

            // Update ALL state on main actor in a single synchronous block
            // This ensures accounts array and userJourneyState update atomically
            print("🔄 [Fetch Accounts Only] Updating state with \(allAccounts.count) account(s)")
            await MainActor.run {
                // Update accounts first
                self.accounts = allAccounts
                print("🔄 [Fetch Accounts Only] Accounts array updated: \(self.accounts.count)")

                // Save accounts to cache immediately while we have them
                self.saveToCache()

                // Transition state ONLY after accounts are set
                print("🔄 [Fetch Accounts Only] Setting state to .accountsConnected")
                self.userJourneyState = .accountsConnected

                // Show success message
                self.successMessage = "Connected \(allAccounts.count) account(s)"
                self.showSuccessBanner = true
                print("🔄 [Fetch Accounts Only] Success banner shown with message: \(self.successMessage)")

                // Clear errors on success
                self.error = nil

                // Force objectWillChange notification to ensure SwiftUI picks up ALL changes
                self.objectWillChange.send()
            }

            print("✅ [Fetch Accounts Only] Account fetch completed - \(allAccounts.count) accounts loaded")
            print("✅ [Fetch Accounts Only] Current state: \(userJourneyState.rawValue)")
            print("✅ [Fetch Accounts Only] Published accounts count: \(self.accounts.count)")

            // Auto-dismiss success banner after 4 seconds
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    showSuccessBanner = false
                }
            }

        } catch {
            print("❌ [Fetch Accounts Only] Critical error: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
            }
        }
    }

    /// Analyzes transactions and generates financial summary
    /// Only fetches transactions, does not create budgets or goals
    func analyzeMyFinances() async {
        print("📊 [Analyze Finances] Starting financial analysis...")

        // Validate precondition: accounts must exist
        guard !accounts.isEmpty else {
            print("❌ [Analyze Finances] Cannot analyze - no accounts connected")
            error = NSError(domain: "FinancialViewModel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Please connect bank accounts first"])
            return
        }

        isLoading = true
        showLoadingOverlay = true
        loadingStep = .analyzingTransactions(count: 0)
        defer {
            isLoading = false
            showLoadingOverlay = false
            loadingStep = .idle
        }

        do {
            let itemIds = try KeychainService.shared.allKeys()
            print("📊 [Analyze Finances] Analyzing \(itemIds.count) account connection(s)")

            var allTransactions: [Transaction] = []

            // Fetch 3 months of transactions (reduced from 6 for faster sync)
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate) ?? endDate

            // Allow Plaid time to sync transactions after initial connection
            print("⏳ [Analyze Finances] Waiting 3s for Plaid to sync transactions...")
            try await Task.sleep(nanoseconds: 3_000_000_000)

            for itemId in itemIds {
                print("📊 [Analyze Finances] Fetching transactions for itemId: \(itemId)...")

                do {
                    let (transactions, fromCache) = try await transactionFetchService.fetchTransactions(
                        itemId: itemId,
                        startDate: startDate,
                        endDate: endDate
                    )
                    let source = fromCache ? "cache" : "Plaid"
                    print("📊 [Analyze Finances] Got \(transactions.count) transaction(s) from \(source) for itemId: \(itemId)")
                    allTransactions.append(contentsOf: transactions)

                    // Update loading step with current count
                    loadingStep = .analyzingTransactions(count: allTransactions.count)

                } catch {
                    print("❌ [Analyze Finances] Failed to fetch transactions for itemId \(itemId): \(error.localizedDescription)")
                    // Continue with other accounts even if one fails
                }
            }

            // Update transactions
            self.transactions = allTransactions

            // Calculate financial snapshot
            let calculatedSnapshot = TransactionAnalyzer.generateSnapshot(
                transactions: allTransactions,
                accounts: accounts
            )
            self.summary = calculatedSnapshot

            // Generate analysis snapshot for the Analysis Complete screen
            self.analysisSnapshot = TransactionAnalyzer.generateAnalysisSnapshot(
                transactions: allTransactions,
                accounts: accounts
            )
            print("📊 [Analyze Finances] ✅ Analysis snapshot generated")

            // Save to cache
            saveToCache()

            // Update state: show analysis results
            userJourneyState = .analysisComplete

            // Mark complete
            loadingStep = .complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Show success message
            successMessage = "Analyzed \(allTransactions.count) transactions across \(accounts.count) account(s)"
            showSuccessBanner = true

            // Auto-dismiss after 4 seconds
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    showSuccessBanner = false
                }
            }

            print("✅ [Analyze Finances] Analysis complete - \(allTransactions.count) transactions analyzed")

            if !allTransactions.isEmpty {
                self.error = nil
            }

        } catch {
            print("❌ [Analyze Finances] Critical error: \(error.localizedDescription)")
            self.error = error
        }
    }

    /// Proceeds from health report to plan creation (DEPRECATED - now goes directly to allocation planning)
    func proceedToCreatePlan() async {
        // No longer needed - analysis goes directly to allocation planning
        // Kept for backward compatibility but does nothing
        print("⚠️ [Create Plan] proceedToCreatePlan is deprecated")
    }

    /// Creates personalized budget and goal recommendations based on transaction history
    func createMyPlan() async {
        print("🎯 [Create Plan] Starting plan creation...")

        // Validate preconditions
        guard !accounts.isEmpty else {
            print("❌ [Create Plan] Cannot create plan - no accounts connected")
            error = NSError(domain: "FinancialViewModel", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Please connect bank accounts first"])
            return
        }

        guard !transactions.isEmpty else {
            print("❌ [Create Plan] Cannot create plan - no transaction data available")
            error = NSError(domain: "FinancialViewModel", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Please analyze your finances first"])
            return
        }

        isLoading = true
        showLoadingOverlay = true
        loadingStep = .generatingBudgets
        defer {
            isLoading = false
            showLoadingOverlay = false
            loadingStep = .idle
        }

        do {
            print("🎯 [Create Plan] Calculating financial summary...")

            // Calculate monthly income and expenses
            guard let summary = self.summary else {
                print("❌ [Create Plan] No summary available")
                error = NSError(domain: "FinancialViewModel", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "Financial summary not available"])
                return
            }

            let monthlyIncome = summary.avgMonthlyIncome
            var monthlyExpenses = summary.avgMonthlyExpenses

            // Guard against NaN or negative values
            if monthlyExpenses.isNaN || monthlyExpenses.isInfinite || monthlyExpenses < 0 {
                monthlyExpenses = 0
            }

            print("🎯 [Create Plan] Income: \(monthlyIncome), Expenses: \(monthlyExpenses)")

            // Calculate category breakdown for API
            let categoryBreakdown = calculateCategoryBreakdown(transactions)

            // Calculate current savings and debt
            let currentSavings = accounts
                .filter { $0.type == "depository" }
                .compactMap { $0.availableBalance ?? $0.currentBalance }
                .reduce(0, +)

            let totalDebt = accounts
                .filter { $0.type == "credit" || $0.subtype?.contains("loan") == true }
                .compactMap { $0.currentBalance }
                .reduce(0, +)

            print("🎯 [Create Plan] Current savings: \(currentSavings), Total debt: \(totalDebt)")

            print("🎯 [Create Plan] Generating allocation buckets...")

            // Generate allocation buckets (calls backend API)
            try await budgetManager.generateAllocationBuckets(
                monthlyIncome: monthlyIncome,
                monthlyExpenses: monthlyExpenses,
                currentSavings: currentSavings,
                totalDebt: totalDebt,
                categoryBreakdown: categoryBreakdown,
                transactions: transactions,
                accounts: accounts
            )

            print("🎯 [Create Plan] Generated \(budgetManager.allocationBuckets.count) allocation bucket(s)")

            // Save to cache
            saveToCache()

            // Transition to allocation planning state (user must review and confirm)
            userJourneyState = .allocationPlanning

            // Mark complete
            loadingStep = .complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Show success message
            successMessage = "Allocation recommendations ready for review"
            showSuccessBanner = true

            // Auto-dismiss after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    showSuccessBanner = false
                }
            }

            print("✅ [Create Plan] Allocation planning ready - user must review and confirm")
            self.error = nil

        } catch {
            print("❌ [Create Plan] Critical error: \(error.localizedDescription)")
            self.error = error
        }
    }

    /// Confirms allocation plan and creates budgets/goals from allocations
    func confirmAllocationPlan() async {
        print("🎯 [Confirm Plan] Confirming allocation plan...")

        isLoading = true
        defer { isLoading = false }

        // 1. Get confirmed allocation buckets
        let buckets = budgetManager.allocationBuckets

        guard !buckets.isEmpty else {
            print("❌ [Confirm Plan] No allocation buckets to confirm")
            error = NSError(domain: "FinancialViewModel", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "No allocation plan available"])
            return
        }

        // 2. Generate category budgets from allocation buckets
        print("🎯 [Confirm Plan] Generating budgets from \(transactions.count) transactions...")
        budgetManager.generateBudgets(from: transactions)

        print("🎯 [Confirm Plan] Generated \(budgetManager.budgets.count) budget(s)")

        // 3. Create emergency fund goal if allocation exists
        if let emergencyBucket = buckets.first(where: { $0.type == .emergencyFund }),
           let targetAmount = emergencyBucket.targetAmount {
            print("🎯 [Confirm Plan] Creating emergency fund goal with target: \(targetAmount)")

            budgetManager.createGoal(
                name: "Emergency Fund",
                targetAmount: targetAmount,
                targetDate: nil,
                goalType: .emergencyFund,
                priority: .high
            )
        }

        // 4. Save everything
        saveToCache()

        // 5. Transition to plan created
        userJourneyState = .planCreated

        // 6. Show success
        successMessage = "Financial plan created with \(buckets.count) allocation buckets!"
        showSuccessBanner = true

        // Auto-dismiss after 4 seconds
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                showSuccessBanner = false
            }
        }

        // 7. Check for savings opportunities
        if let savingsAlert = AlertRulesEngine.evaluateSavingsOpportunity(
            budgets: budgetManager.budgets,
            goals: budgetManager.goals,
            transactions: transactions
        ) {
            // Schedule savings notification
            Task {
                try? await NotificationService.shared.scheduleSavingsOpportunityAlert(
                    surplusAmount: savingsAlert.impactSummary.currentRemaining,
                    recommendedGoal: budgetManager.goals.first?.name ?? "Emergency Fund",
                    triggerInSeconds: 5
                )
            }
        }

        print("✅ [Confirm Plan] Plan confirmed and created - \(budgetManager.budgets.count) budgets, \(budgetManager.goals.count) goals")
    }

    // MARK: - Helper Methods

    /// Calculates category breakdown from transactions
    private func calculateCategoryBreakdown(_ transactions: [Transaction]) -> [String: Double] {
        var breakdown: [String: Double] = [:]
        for transaction in transactions where transaction.amount > 0 {
            let category = transaction.category.first ?? "Uncategorized"
            breakdown[category, default: 0] += transaction.amount
        }
        return breakdown
    }

    // MARK: - Data Refresh

    /// Convenience wrapper for refreshAllData() to maintain backward compatibility
    func refreshData() async {
        await refreshAllData()
    }

    /// Refreshes all financial data: accounts, transactions, analysis, and budgets
    /// This is the "all-in-one" refresh function that performs all steps at once
    /// For stepwise onboarding, use fetchAccountsOnly() → analyzeMyFinances() → createMyPlan()
    func refreshAllData() async {
        print("🔄 [Refresh All Data] Starting comprehensive data refresh...")
        isLoading = true
        showLoadingOverlay = true
        loadingStep = .fetchingAccounts
        defer {
            isLoading = false
            showLoadingOverlay = false
            loadingStep = .idle
        }

        do {
            // Get all stored access tokens
            print("🔄 [Refresh All Data] Loading itemIds from Keychain...")
            let itemIds = try KeychainService.shared.allKeys()
            print("🔄 [Refresh All Data] Found \(itemIds.count) stored itemId(s): \(itemIds)")

            var allAccounts: [BankAccount] = []
            var allTransactions: [Transaction] = []

            // Fetch data for each linked account
            for itemId in itemIds {
                print("🔄 [Refresh All Data] Processing itemId: \(itemId)")

                do {
                    // Fetch accounts
                    print("🔄 [Refresh All Data] Fetching accounts for itemId: \(itemId)...")
                    let accounts = try await plaidService.fetchAccounts(itemId: itemId)
                    print("🔄 [Refresh All Data] Fetched \(accounts.count) account(s) for itemId: \(itemId)")

                    // Set itemId on each account if needed
                    for account in accounts {
                        if account.itemId.isEmpty {
                            account.itemId = itemId
                        }
                    }

                    allAccounts.append(contentsOf: accounts)
                    print("🔄 [Refresh All Data] Total accounts so far: \(allAccounts.count)")

                    // Fetch 6 months of transactions
                    let endDate = Date()
                    let startDate = Calendar.current.date(byAdding: .month, value: -6, to: endDate) ?? endDate

                    print("🔄 [Refresh All Data] Fetching transactions for itemId: \(itemId)...")
                    loadingStep = .analyzingTransactions(count: 0)
                    let transactions = try await plaidService.fetchTransactions(
                        itemId: itemId,
                        startDate: startDate,
                        endDate: endDate
                    )
                    print("🔄 [Refresh All Data] Fetched \(transactions.count) transaction(s) for itemId: \(itemId)")
                    allTransactions.append(contentsOf: transactions)

                    // Update loading step with actual transaction count
                    loadingStep = .analyzingTransactions(count: allTransactions.count)
                } catch {
                    print("❌ [Refresh All Data] Failed to fetch data for itemId \(itemId): \(error.localizedDescription)")

                    // Clean up orphaned itemIds if item not found
                    let errorString = error.localizedDescription.lowercased()
                    if errorString.contains("item") && errorString.contains("not found") {
                        print("⚠️ [Refresh All Data] Item not found, cleaning up itemId: \(itemId)")
                        try? KeychainService.shared.delete(for: itemId)
                    }
                }
            }

            // Update published properties
            self.accounts = allAccounts
            self.transactions = allTransactions

            // Calculate snapshot
            self.summary = TransactionAnalyzer.generateSnapshot(
                transactions: allTransactions,
                accounts: allAccounts
            )

            // Generate budgets from transaction history
            loadingStep = .generatingBudgets
            budgetManager.generateBudgets(from: allTransactions)

            // Save to cache
            saveToCache()

            // Mark complete
            loadingStep = .complete

            // Small delay to let user see "Complete" message
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Show success banner with summary
            successMessage = "Reviewed \(allTransactions.count) transactions and generated \(budgetManager.budgets.count) budgets"
            showSuccessBanner = true

            // Auto-dismiss success banner after 4 seconds
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    showSuccessBanner = false
                }
            }

            // Check for savings opportunities
            if let savingsAlert = AlertRulesEngine.evaluateSavingsOpportunity(
                budgets: budgetManager.budgets,
                goals: budgetManager.goals,
                transactions: allTransactions
            ) {
                // Schedule savings notification
                Task {
                    try? await NotificationService.shared.scheduleSavingsOpportunityAlert(
                        surplusAmount: savingsAlert.impactSummary.currentRemaining,
                        recommendedGoal: budgetManager.goals.first?.name ?? "Emergency Fund",
                        triggerInSeconds: 5
                    )
                }
            }

            print("✅ [Refresh All Data] Data refresh completed")
            print("✅ [Refresh All Data] Total accounts loaded: \(allAccounts.count)")
            print("✅ [Refresh All Data] Total transactions loaded: \(allTransactions.count)")

            // Clear any previous errors if we successfully loaded data
            if !allAccounts.isEmpty {
                self.error = nil
            }

        } catch {
            print("❌ [Refresh All Data] Critical error during refresh: \(error.localizedDescription)")
            print("❌ [Refresh All Data] Error details: \(error)")

            // Only set error if we couldn't load ANY accounts
            // (Individual account failures are handled in the loop above)
            self.error = error
        }
    }

    // MARK: - Account Management

    /// Removes a linked account and cleans up all associated data
    func removeLinkedAccount(itemId: String) async {
        print("🗑️ [Account Removal] Starting removal for itemId: \(itemId)")
        print("🗑️ [Account Removal] Current account count: \(accounts.count)")

        isLoading = true
        defer { isLoading = false }

        do {
            // Call backend to remove the account from Plaid and SQLite
            print("🗑️ [Account Removal] Calling backend to remove account...")
            try await plaidService.removeAccount(itemId: itemId)
            print("🗑️ [Account Removal] Backend removed item successfully")

            // Remove itemId from Keychain
            print("🗑️ [Account Removal] Deleting itemId from Keychain...")
            try KeychainService.shared.delete(for: itemId)
            print("🗑️ [Account Removal] ItemId deleted from Keychain")

            let removedItemId = itemId

            // Invalidate encrypted transaction cache for this item
            transactionFetchService.invalidateCache(for: removedItemId)
            print("🗑️ [Account Removal] Invalidated transaction cache")

            // Filter out accounts belonging to removed itemId
            let accountsToRemove = accounts.filter { $0.itemId == removedItemId }
            print("🗑️ [Account Removal] Found \(accountsToRemove.count) account(s) to remove")

            if accountsToRemove.isEmpty {
                print("⚠️ [Account Removal] WARNING: No accounts found with itemId '\(removedItemId)'")
                print("⚠️ [Account Removal] Current accounts and their itemIds:")
                for account in accounts {
                    print("⚠️ [Account Removal]   - '\(account.name)' (id: \(account.id)) has itemId: '\(account.itemId)'")
                }
            } else {
                print("🗑️ [Account Removal] Account IDs to remove: \(accountsToRemove.map { $0.id })")
            }

            let accountIdsToRemove = Set(accountsToRemove.map { $0.id })

            // Ensure UI updates happen on main thread
            await MainActor.run {
                let countBefore = accounts.count
                accounts.removeAll { $0.itemId == removedItemId }
                print("🗑️ [Account Removal] Accounts removed: \(countBefore) -> \(accounts.count)")

                // Filter out transactions from removed accounts
                let transactionCountBefore = transactions.count
                transactions.removeAll { transaction in
                    accountIdsToRemove.contains(transaction.accountId)
                }
                print("🗑️ [Account Removal] Transactions removed: \(transactionCountBefore) -> \(transactions.count)")

                // Force a refresh of the published properties
                objectWillChange.send()
            }

            // Recalculate snapshot with remaining data
            if !accounts.isEmpty {
                print("🗑️ [Account Removal] Recalculating snapshot with remaining \(accounts.count) account(s)")
                summary = TransactionAnalyzer.generateSnapshot(
                    transactions: transactions,
                    accounts: accounts
                )

                // Regenerate budgets from remaining transaction history
                budgetManager.generateBudgets(from: transactions)
            } else {
                print("🗑️ [Account Removal] No accounts left, clearing all data")
                // No accounts left, clear everything
                summary = nil
                budgetManager.budgets.removeAll()
            }

            // Update cache to persist changes
            print("🗑️ [Account Removal] Saving updated data to cache...")
            saveToCache()

            // Clear any current alerts as they may be stale
            currentAlert = nil
            isShowingGuidance = false

            print("✅ [Account Removal] Account removal completed successfully")

        } catch {
            print("❌ [Account Removal] Error occurred: \(error.localizedDescription)")
            print("❌ [Account Removal] Error details: \(error)")
            self.error = error
        }
    }

    // MARK: - Data Analysis

    func expenseBreakdown() -> [String: Double] {
        return TransactionAnalyzer.expensesByCategory(from: transactions)
    }

    func monthlyTrends(for bucket: BucketCategory) -> [Date: Double] {
        return TransactionAnalyzer.monthlyTrends(from: transactions, bucket: bucket)
    }

    func recentTransactions(limit: Int = 10) -> [Transaction] {
        return Array(transactions
            .sorted(by: { $0.date > $1.date })
            .prefix(limit))
    }

    // MARK: - Proactive Guidance

    /// Evaluates a potential purchase and shows guidance
    func evaluatePurchase(amount: Double, merchantName: String, category: String) {
        let alerts = AlertRulesEngine.evaluatePurchase(
            amount: amount,
            merchantName: merchantName,
            category: category,
            budgets: budgetManager.budgets,
            goals: budgetManager.goals,
            transactions: transactions,
            disposableIncome: summary?.disposableIncome ?? 0
        )

        if let alert = alerts.first {
            // Show alert immediately with loading state for AI
            alert.isLoadingAIInsight = true
            currentAlert = alert
            isShowingGuidance = true

            // Fetch AI insight asynchronously
            Task {
                do {
                    // Build budget context if available
                    let budgetContext: BudgetStatusContext
                    if let budget = alert.relatedBudget {
                        budgetContext = BudgetStatusContext(
                            currentSpent: budget.currentSpent,
                            limit: budget.monthlyLimit,
                            remaining: budget.remaining,
                            daysRemaining: alert.impactSummary.daysUntilMonthEnd
                        )
                    } else {
                        // Create fallback context from impact summary
                        budgetContext = BudgetStatusContext(
                            currentSpent: 0,
                            limit: amount,
                            remaining: alert.impactSummary.currentRemaining,
                            daysRemaining: alert.impactSummary.daysUntilMonthEnd
                        )
                    }

                    // Build spending pattern context
                    let spendingPattern: SpendingPatternContext? = nil // Could analyze transactions here

                    // Fetch AI insight
                    let insight = try await AIInsightService.shared.getPurchaseInsight(
                        amount: amount,
                        merchantName: merchantName,
                        category: category,
                        budgetStatus: budgetContext,
                        spendingPattern: spendingPattern
                    )

                    // Update alert with AI insight and clear loading state
                    await MainActor.run {
                        alert.aiInsight = insight
                        alert.isLoadingAIInsight = false
                    }
                } catch {
                    print("❌ [AIInsight] Failed to fetch insight: \(error)")
                    // Clear loading state (alert will show fallback text)
                    await MainActor.run {
                        alert.isLoadingAIInsight = false
                    }
                }
            }
        }
    }

    /// Handles action from proactive guidance view
    func handleGuidanceAction(_ action: AlertAction) {
        switch action.actionType {
        case .confirmPurchase:
            if let alert = currentAlert,
               let budget = alert.relatedBudget {
                budgetManager.confirmPurchase(
                    amount: alert.impactSummary.currentRemaining - alert.impactSummary.afterPurchaseRemaining,
                    category: budget.categoryName,
                    merchantName: "Purchase"
                )
            }

        case .reallocateBudget:
            if let sourceBudgetId = action.metadata["sourceBudgetId"],
               let sourceBudget = budgetManager.budgets.first(where: { $0.id == sourceBudgetId }),
               let amount = action.metadata["amount"],
               let amountValue = Double(amount),
               let alert = currentAlert,
               let destinationBudget = alert.relatedBudget {
                _ = budgetManager.reallocateBudget(
                    from: sourceBudget,
                    to: destinationBudget.categoryName,
                    amount: amountValue
                )
            }

        case .contributeToGoal:
            if let goalId = action.metadata["goalId"],
               let goal = budgetManager.goals.first(where: { $0.id == goalId }),
               let amount = action.metadata["amount"],
               let amountValue = Double(amount) {
                budgetManager.contributeToGoal(goal, amount: amountValue)
            }

        default:
            break
        }

        isShowingGuidance = false
        currentAlert = nil
    }

    // MARK: - Notification Handling

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .notificationTapped,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo as? [String: Any],
                  let data = userInfo["data"] as? [AnyHashable: Any] else {
                return
            }

            Task { @MainActor in
                self.navigationCoordinator?.handleNotificationTap(userInfo: data)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .purchaseConfirmed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let amount = userInfo["amount"] as? Double,
                  let category = userInfo["category"] as? String,
                  let merchantName = userInfo["merchantName"] as? String else {
                return
            }

            Task { @MainActor in
                self.budgetManager.confirmPurchase(
                    amount: amount,
                    category: category,
                    merchantName: merchantName
                )
            }
        }
    }

    /// Handle notification tap from coordinator
    func handleNotificationNavigation(userInfo: [AnyHashable: Any]) {
        navigationCoordinator?.handleNotificationTap(userInfo: userInfo)
    }

    // MARK: - Transaction Validation Helpers

    /// Returns all transactions that need user validation
    var transactionsNeedingValidation: [Transaction] {
        transactions.filter { $0.needsValidation && !$0.userValidated }
    }

    /// Returns validation progress (validated count, total count)
    var validationProgress: (validated: Int, total: Int) {
        let needsValidation = transactions.filter { $0.needsValidation }
        let validated = needsValidation.filter { $0.userValidated }
        return (validated.count, needsValidation.count)
    }

    /// Returns count of transactions needing validation for a specific bucket category
    func needsValidationCount(for bucket: BucketCategory) -> Int {
        let bucketTransactions = TransactionAnalyzer.transactionsForBucket(bucket, from: transactions)
        return bucketTransactions.filter { $0.needsValidation && !$0.userValidated }.count
    }

    /// Persists accounts to UserDefaults (for tag changes)
    func saveAccounts() {
        print("💾 [Persistence] Saving accounts with tags...")
        let encoder = JSONEncoder()
        if let accountsData = try? encoder.encode(accounts) {
            UserDefaults.standard.set(accountsData, forKey: "cached_accounts")
            print("💾 [Persistence] ✅ Saved \(accounts.count) accounts")
        } else {
            print("💾 [Persistence] ❌ Failed to encode accounts")
        }
    }

    /// Persists transactions to UserDefaults (for validation state changes)
    func saveTransactions() {
        print("💾 [Persistence] Saving transactions with validation states...")
        let encoder = JSONEncoder()
        if let transactionsData = try? encoder.encode(transactions) {
            UserDefaults.standard.set(transactionsData, forKey: "cached_transactions")
            print("💾 [Persistence] ✅ Saved \(transactions.count) transactions")
        } else {
            print("💾 [Persistence] ❌ Failed to encode transactions")
        }
    }

    /// Validates a transaction with optional bulk validation for similar transactions
    /// - Parameters:
    ///   - transaction: The transaction being validated
    ///   - correctedCategory: New category if user corrected it, nil if confirming Plaid's category
    ///   - applyToAll: If true, applies validation to all transactions with same Plaid detailed category
    /// - Returns: Number of transactions validated
    @discardableResult
    func validateTransaction(
        _ transaction: Transaction,
        correctedCategory: BucketCategory?,
        applyToAll: Bool
    ) -> Int {
        print("✅ [Validation] Starting validation for transaction: \(transaction.name)")
        print("✅ [Validation] Corrected category: \(correctedCategory?.rawValue ?? "none")")
        print("✅ [Validation] Apply to all: \(applyToAll)")

        var validatedCount = 0

        if applyToAll, let pfc = transaction.personalFinanceCategory {
            // Find all transactions with same Plaid detailed category and bucket category
            let targetBucketCategory = correctedCategory ?? transaction.bucketCategory
            let matchingTransactions = transactions.filter { t in
                // Match by Plaid detailed category
                guard let tPfc = t.personalFinanceCategory else { return false }
                guard tPfc.detailed == pfc.detailed else { return false }

                // Only apply to unvalidated transactions in the same bucket
                guard !t.userValidated else { return false }
                guard t.bucketCategory == targetBucketCategory else { return false }

                return true
            }

            print("✅ [Validation] Found \(matchingTransactions.count) matching transactions")

            // Apply validation to all matching transactions
            for matchingTransaction in matchingTransactions {
                if let corrected = correctedCategory {
                    matchingTransaction.userCorrectedCategory = corrected
                }
                matchingTransaction.userValidated = true
                validatedCount += 1
            }
        } else {
            // Apply to just this one transaction
            if let corrected = correctedCategory {
                transaction.userCorrectedCategory = corrected
            }
            transaction.userValidated = true
            validatedCount = 1
        }

        print("✅ [Validation] Validated \(validatedCount) transaction(s)")

        // Persist changes
        saveTransactions()

        // Force SwiftUI to detect changes by reassigning the array
        // This triggers @Published wrapper to notify all observers (including badge counts)
        self.transactions = self.transactions

        return validatedCount
    }

    /// Counts matching transactions for bulk validation preview
    /// - Parameter transaction: Transaction to find matches for
    /// - Returns: Number of other unvalidated transactions with same Plaid detailed category
    func countMatchingTransactions(_ transaction: Transaction) -> Int {
        guard let pfc = transaction.personalFinanceCategory else { return 0 }

        let targetBucketCategory = transaction.bucketCategory
        let matchingCount = transactions.filter { t in
            // Don't count the transaction itself
            guard t.id != transaction.id else { return false }

            // Match by Plaid detailed category
            guard let tPfc = t.personalFinanceCategory else { return false }
            guard tPfc.detailed == pfc.detailed else { return false }

            // Only count unvalidated transactions in the same bucket
            guard !t.userValidated else { return false }
            guard t.bucketCategory == targetBucketCategory else { return false }

            return true
        }.count

        return matchingCount
    }

    // MARK: - Private Helpers

    /// Validates and fixes itemIds for cached accounts
    /// Called when loading from cache to ensure accounts are properly linked to tokens
    private func validateAndFixAccountItemIds() {
        guard !accounts.isEmpty else { return }

        do {
            let storedItemIds = try KeychainService.shared.allKeys()
            print("🔍 [ItemId Validation] Checking \(accounts.count) cached accounts against \(storedItemIds.count) stored itemIds")

            // Check for accounts with missing itemIds
            let accountsWithoutItemId = accounts.filter { $0.itemId.isEmpty }
            if !accountsWithoutItemId.isEmpty {
                print("⚠️ [ItemId Validation] Found \(accountsWithoutItemId.count) accounts with empty itemId")
                print("⚠️ [ItemId Validation] This should not happen with the new decoder, but handling gracefully")
            }

            // Log itemId status for all accounts
            for account in accounts {
                if account.itemId.isEmpty {
                    print("❌ [ItemId Validation] Account '\(account.name)' (id: \(account.id)) has EMPTY itemId")
                } else {
                    print("✅ [ItemId Validation] Account '\(account.name)' (id: \(account.id)) has itemId: \(account.itemId)")
                }
            }

        } catch {
            print("⚠️ [ItemId Validation] Failed to validate itemIds: \(error)")
        }
    }

    private func saveToCache() {
        print("💾 [Cache Save] Starting cache save...")
        print("💾 [Cache Save] Accounts to save: \(accounts.count)")
        print("💾 [Cache Save] Transactions to save: \(transactions.count)")

        let encoder = JSONEncoder()

        // Save accounts to encrypted cache (grouped by itemId)
        let accountsByItem = Dictionary(grouping: accounts) { $0.itemId }
        for (itemId, itemAccounts) in accountsByItem where !itemId.isEmpty {
            SecureTransactionCache.shared.cacheAccounts(itemAccounts, for: itemId)
        }
        print("💾 [Cache Save] ✅ Saved \(accounts.count) accounts to encrypted cache")

        // Save transactions to encrypted cache (grouped by itemId via accounts)
        for (itemId, itemAccounts) in accountsByItem where !itemId.isEmpty {
            let accountIds = Set(itemAccounts.map { $0.id })
            let itemTransactions = transactions.filter { accountIds.contains($0.accountId) }
            if !itemTransactions.isEmpty {
                SecureTransactionCache.shared.cacheTransactions(itemTransactions, for: itemId)
            }
        }
        print("💾 [Cache Save] ✅ Saved \(transactions.count) transactions to encrypted cache")

        // Save summary (user-scoped)
        if let summaryData = try? encoder.encode(summary) {
            UserDefaults.standard.set(summaryData, forKey: cacheKey("summary"))
            print("💾 [Cache Save] ✅ Saved summary")
        } else {
            print("💾 [Cache Save] ❌ Failed to encode summary")
        }

        // Save user journey state (user-scoped)
        if let stateData = try? encoder.encode(userJourneyState) {
            UserDefaults.standard.set(stateData, forKey: cacheKey("journey_state"))
            print("💾 [Cache] Saved journey state: \(userJourneyState.rawValue)")
        }

        // Save allocation schedule
        allocationScheduleConfig?.save()
        scheduledAllocations.save()
        allocationHistory.save()

        print("💾 [Cache Save] Cache save complete")
    }

    private func loadFromCache() {
        print("💾 [Cache Load] Starting cache load...")
        let decoder = JSONDecoder()

        // Try to load from encrypted cache first, falling back to UserDefaults migration
        var loadedAccounts: [BankAccount] = []
        var loadedTransactions: [Transaction] = []
        var needsMigration = false

        // Check for legacy UserDefaults cache (for migration)
        if let accountsData = UserDefaults.standard.data(forKey: "cached_accounts"),
           let legacyAccounts = try? decoder.decode([BankAccount].self, from: accountsData) {
            print("💾 [Cache Load] Found legacy UserDefaults accounts, will migrate to encrypted cache")
            loadedAccounts = legacyAccounts
            needsMigration = true
        }

        if let transactionsData = UserDefaults.standard.data(forKey: "cached_transactions"),
           let legacyTransactions = try? decoder.decode([Transaction].self, from: transactionsData) {
            print("💾 [Cache Load] Found legacy UserDefaults transactions, will migrate to encrypted cache")
            loadedTransactions = legacyTransactions
            needsMigration = true
        }

        // If no legacy data, try loading from encrypted cache
        if loadedAccounts.isEmpty {
            // Load accounts from encrypted cache using known itemIds from Keychain
            if let itemIds = try? KeychainService.shared.allKeys() {
                for itemId in itemIds {
                    if let cached = SecureTransactionCache.shared.loadAccounts(for: itemId) {
                        loadedAccounts.append(contentsOf: cached.accounts)
                    }
                }
            }
            print("💾 [Cache Load] Loaded \(loadedAccounts.count) account(s) from encrypted cache")
        }

        if loadedTransactions.isEmpty {
            // Load transactions from encrypted cache using known itemIds from Keychain
            if let itemIds = try? KeychainService.shared.allKeys() {
                for itemId in itemIds {
                    if let cached = SecureTransactionCache.shared.loadTransactions(for: itemId) {
                        loadedTransactions.append(contentsOf: cached.transactions)
                    }
                }
            }
            print("💾 [Cache Load] Loaded \(loadedTransactions.count) transaction(s) from encrypted cache")
        }

        // Apply loaded data
        self.accounts = loadedAccounts
        self.transactions = loadedTransactions

        // Validate that cached accounts have proper itemIds
        if !loadedAccounts.isEmpty {
            validateAndFixAccountItemIds()
        }

        // Migrate legacy data to encrypted cache and clear old UserDefaults
        if needsMigration && !loadedAccounts.isEmpty {
            print("💾 [Cache Load] Migrating to encrypted cache...")
            let accountsByItem = Dictionary(grouping: loadedAccounts) { $0.itemId }
            for (itemId, itemAccounts) in accountsByItem where !itemId.isEmpty {
                SecureTransactionCache.shared.cacheAccounts(itemAccounts, for: itemId)

                let accountIds = Set(itemAccounts.map { $0.id })
                let itemTransactions = loadedTransactions.filter { accountIds.contains($0.accountId) }
                if !itemTransactions.isEmpty {
                    SecureTransactionCache.shared.cacheTransactions(itemTransactions, for: itemId)
                }
            }

            // Clear legacy UserDefaults cache
            UserDefaults.standard.removeObject(forKey: "cached_accounts")
            UserDefaults.standard.removeObject(forKey: "cached_transactions")
            print("💾 [Cache Load] ✅ Migration complete, legacy cache cleared")
        }

        // Load summary (user-scoped)
        if let summaryData = UserDefaults.standard.data(forKey: cacheKey("summary")) {
            print("💾 [Cache Load] Found cached summary data (\(summaryData.count) bytes)")
            if let summary = try? decoder.decode(AnalysisSnapshot.self, from: summaryData) {
                self.summary = summary
                print("💾 [Cache Load] ✅ Decoded summary from cache")
            } else {
                print("💾 [Cache Load] ❌ Failed to decode summary from cache")
            }
        } else {
            print("💾 [Cache Load] No cached summary data found")
        }

        // Regenerate budgets from cached transactions if available
        if !transactions.isEmpty {
            budgetManager.generateBudgets(from: transactions)
            print("💾 [Cache Load] Regenerated \(budgetManager.budgets.count) budget(s) from cached transactions")
        } else {
            print("💾 [Cache Load] No transactions available for budget generation")
        }

        // Load user journey state (user-scoped)
        if let stateData = UserDefaults.standard.data(forKey: cacheKey("journey_state")),
           let state = try? decoder.decode(UserJourneyState.self, from: stateData) {
            self.userJourneyState = state
            print("📂 [Cache] Loaded journey state: \(state.rawValue)")
        } else {
            // Infer state from cached data for existing users
            inferStateFromCache()
        }

        // Load allocation schedule
        allocationScheduleConfig = AllocationScheduleConfig.load()
        scheduledAllocations = [ScheduledAllocation].load()
        allocationHistory = [AllocationExecution].load()

        print("💾 [Cache Load] Cache load complete - Accounts: \(accounts.count), Transactions: \(transactions.count)")
    }

    /// Infers user journey state from cached data (for existing users after app update)
    private func inferStateFromCache() {
        print("🔍 [State] Inferring state from cached data...")
        print("   - Accounts: \(accounts.count)")
        print("   - Summary: \(summary != nil ? "exists" : "nil")")
        print("   - Budgets: \(budgetManager.budgets.count)")
        print("   - Allocation Buckets: \(budgetManager.allocationBuckets.count)")

        if accounts.isEmpty {
            userJourneyState = .noAccountsConnected
            print("✅ [State] Inferred: .noAccountsConnected (no accounts)")
        } else if budgetManager.budgets.isEmpty && budgetManager.allocationBuckets.isEmpty && summary == nil {
            userJourneyState = .accountsConnected
            print("✅ [State] Inferred: .accountsConnected (accounts exist, no analysis)")
        } else if summary != nil && budgetManager.allocationBuckets.isEmpty {
            // Has summary but no allocation buckets - analysis complete
            userJourneyState = .analysisComplete
            print("✅ [State] Inferred: .analysisComplete (summary exists, awaiting plan creation)")
        } else if budgetManager.budgets.isEmpty && !budgetManager.allocationBuckets.isEmpty {
            // Has allocation buckets but no budgets - in allocation planning
            userJourneyState = .allocationPlanning
            print("✅ [State] Inferred: .allocationPlanning (allocation buckets exist, awaiting confirmation)")
        } else if !budgetManager.budgets.isEmpty {
            userJourneyState = .planCreated
            print("✅ [State] Inferred: .planCreated (budgets exist)")
        } else {
            // Default to accountsConnected if unclear
            userJourneyState = .accountsConnected
            print("✅ [State] Inferred: .accountsConnected (default fallback)")
        }
    }

    /// Validates that state matches actual data (debug only)
    private func validateStateConsistency() {
        #if DEBUG
        switch userJourneyState {
        case .noAccountsConnected:
            if !accounts.isEmpty {
                print("⚠️ [State] WARNING: State is .noAccountsConnected but accounts exist (\(accounts.count))")
            }

        case .accountsConnected:
            if accounts.isEmpty {
                print("⚠️ [State] WARNING: State is .accountsConnected but accounts is empty")
            }

        case .analysisComplete:
            if summary == nil {
                print("⚠️ [State] WARNING: State is .analysisComplete but summary is nil")
            }
            if accounts.isEmpty {
                print("⚠️ [State] WARNING: State is .analysisComplete but accounts is empty")
            }

        case .allocationPlanning:
            if summary == nil {
                print("⚠️ [State] WARNING: State is .allocationPlanning but summary is nil")
            }
            if budgetManager.allocationBuckets.isEmpty {
                print("⚠️ [State] WARNING: State is .allocationPlanning but allocation buckets is empty")
            }

        case .planCreated:
            if budgetManager.budgets.isEmpty {
                print("⚠️ [State] WARNING: State is .planCreated but budgets is empty")
            }
        }
        #endif
    }

    // MARK: - Allocation Schedule Management

    /// Sets up allocation schedule after paycheck detection
    func setupAllocationSchedule(paycheckSchedule: PaycheckSchedule) async {
        print("📅 [AllocationSchedule] Setting up schedule...")

        isLoading = true
        defer { isLoading = false }

        // Create configuration
        let config = AllocationScheduleConfig(paycheckSchedule: paycheckSchedule)
        allocationScheduleConfig = config

        // Generate scheduled allocations
        let scheduler = AllocationScheduler()
        scheduledAllocations = scheduler.generateSchedule(
            paycheckSchedule: paycheckSchedule,
            allocationBuckets: budgetManager.allocationBuckets,
            monthsAhead: config.upcomingMonthsToShow
        )

        // Schedule notifications
        do {
            try await NotificationService.shared.scheduleAllocationNotifications(
                scheduledAllocations: scheduledAllocations,
                config: config
            )
        } catch {
            print("❌ [AllocationSchedule] Failed to schedule notifications: \(error)")
        }

        // Save to cache
        saveToCache()

        print("✅ [AllocationSchedule] Schedule setup complete with \(scheduledAllocations.count) allocations")
    }

    /// Updates allocation schedule configuration
    func updateAllocationSchedule(config: AllocationScheduleConfig) async {
        print("📅 [AllocationSchedule] Updating schedule...")

        isLoading = true
        defer { isLoading = false }

        // Update configuration
        allocationScheduleConfig = config

        // Regenerate scheduled allocations
        let scheduler = AllocationScheduler()
        scheduledAllocations = scheduler.regenerateSchedule(
            paycheckSchedule: config.paycheckSchedule,
            allocationBuckets: budgetManager.allocationBuckets,
            existingAllocations: scheduledAllocations,
            monthsAhead: config.upcomingMonthsToShow
        )

        // Reschedule notifications
        await NotificationService.shared.cancelAllAllocationNotifications()
        do {
            try await NotificationService.shared.scheduleAllocationNotifications(
                scheduledAllocations: scheduledAllocations,
                config: config
            )
        } catch {
            print("❌ [AllocationSchedule] Failed to reschedule notifications: \(error)")
        }

        // Save to cache
        saveToCache()

        print("✅ [AllocationSchedule] Schedule updated")
    }

    /// Completes allocations (marks as done and logs to history)
    func completeAllocations(_ completedItems: [(ScheduledAllocation, Double)]) async {
        print("✅ [AllocationSchedule] Completing \(completedItems.count) allocation(s)...")

        let tracker = AllocationExecutionTracker()

        // Record executions to history
        for (allocation, actualAmount) in completedItems {
            let execution = tracker.recordExecution(
                scheduledAllocation: allocation,
                actualAmount: actualAmount,
                wasAutomatic: false
            )
            allocationHistory.append(execution)

            // Update scheduled allocation status
            if let index = scheduledAllocations.firstIndex(where: { $0.id == allocation.id }) {
                scheduledAllocations[index].markCompleted(executionId: execution.id)
            }
        }

        // Cancel notifications for this payday
        if let firstAllocation = completedItems.first {
            NotificationService.shared.cancelAllocationNotifications(for: firstAllocation.0.paycheckDate)
        }

        // Show completion notification
        let totalAmount = completedItems.reduce(0) { $0 + $1.1 }
        do {
            try await NotificationService.shared.showCompletionConfirmation(
                allocatedAmount: totalAmount,
                bucketCount: completedItems.count
            )
        } catch {
            print("❌ [AllocationSchedule] Failed to show completion notification: \(error)")
        }

        // Prune old history
        allocationHistory = tracker.pruneOldExecutions(
            executions: allocationHistory,
            retentionMonths: allocationScheduleConfig?.historyMonthsToKeep ?? 12
        )

        // Save to cache
        saveToCache()

        print("✅ [AllocationSchedule] Completed \(completedItems.count) allocation(s)")
    }

    /// Skips allocations for a specific payday
    func skipAllocation(paycheckDate: Date) async {
        print("⏭️ [AllocationSchedule] Skipping allocations for \(paycheckDate)...")

        // Mark all allocations for this payday as skipped
        for index in scheduledAllocations.indices {
            if Calendar.current.isDate(scheduledAllocations[index].paycheckDate, inSameDayAs: paycheckDate) {
                scheduledAllocations[index].markSkipped()
            }
        }

        // Cancel notifications
        NotificationService.shared.cancelAllocationNotifications(for: paycheckDate)

        // Save to cache
        saveToCache()

        print("✅ [AllocationSchedule] Skipped allocations for \(paycheckDate)")
    }
}

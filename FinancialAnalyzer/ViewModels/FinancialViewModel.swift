import Foundation
import SwiftUI

/// Represents different loading steps in the account connection flow
enum LoadingStep: Equatable {
    case idle
    case connectingToBank
    case fetchingAccounts
    case analyzingTransactions(count: Int)
    case generatingBudgets
    case complete

    var stepNumber: Int {
        switch self {
        case .idle: return -1
        case .connectingToBank: return 0
        case .fetchingAccounts: return 1
        case .analyzingTransactions: return 2
        case .generatingBudgets: return 3
        case .complete: return 4
        }
    }

    var title: String {
        switch self {
        case .idle:
            return "Preparing..."
        case .connectingToBank:
            return "Connecting to Bank"
        case .fetchingAccounts:
            return "Fetching Accounts"
        case .analyzingTransactions(let count):
            if count > 0 {
                return "Analyzing \(count) Transactions"
            } else {
                return "Analyzing Transactions"
            }
        case .generatingBudgets:
            return "Generating Budgets"
        case .complete:
            return "Complete"
        }
    }

    var message: String {
        switch self {
        case .idle:
            return "Setting up your connection..."
        case .connectingToBank:
            return "Establishing secure connection..."
        case .fetchingAccounts:
            return "Loading your account information..."
        case .analyzingTransactions(let count):
            if count > 0 {
                return "Processing your spending patterns..."
            } else {
                return "Retrieving transaction history..."
            }
        case .generatingBudgets:
            return "Creating personalized budgets..."
        case .complete:
            return "Your financial data is ready!"
        }
    }

    static let allSteps: [LoadingStep] = [
        .connectingToBank,
        .fetchingAccounts,
        .analyzingTransactions(count: 0),
        .generatingBudgets,
        .complete
    ]
}

@MainActor
class FinancialViewModel: ObservableObject {
    @Published var summary: FinancialSummary?
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
    private var linkTokenRefreshTask: Task<Void, Never>?

    init(plaidService: PlaidService = PlaidService()) {
        self.plaidService = plaidService
        self.budgetManager = BudgetManager()
        loadFromCache()
        setupNotificationObservers()
        startLinkTokenPreloading()
    }

    deinit {
        linkTokenRefreshTask?.cancel()
        NotificationCenter.default.removeObserver(self)
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
            print("❌ [Connect] Error connecting bank account: \(error.localizedDescription)")
            print("❌ [Connect] Error details: \(error)")
            self.error = error
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
            // Get all stored access tokens
            print("🔄 [Fetch Accounts Only] Loading itemIds from Keychain...")
            let itemIds = try KeychainService.shared.allKeys()
            print("🔄 [Fetch Accounts Only] Found \(itemIds.count) stored itemId(s): \(itemIds)")

            var allAccounts: [BankAccount] = []

            // Fetch accounts for each linked item
            for itemId in itemIds {
                print("🔄 [Fetch Accounts Only] Processing itemId: \(itemId)")

                do {
                    let accessToken = try KeychainService.shared.load(for: itemId)
                    print("🔄 [Fetch Accounts Only] Access token loaded for itemId: \(itemId)")

                    // Fetch accounts with retry logic (Plaid sandbox may need time to sync)
                    var accounts: [BankAccount] = []
                    var lastError: Error?
                    let maxRetries = 3

                    for attempt in 1...maxRetries {
                        do {
                            print("🔄 [Fetch Accounts Only] Fetching accounts for itemId: \(itemId) (attempt \(attempt)/\(maxRetries))...")
                            accounts = try await plaidService.fetchAccounts(accessToken: accessToken)
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

                    // Set itemId on each account
                    for account in accounts {
                        if account.itemId.isEmpty {
                            print("⚠️ [Fetch Accounts Only] Account '\(account.name)' has EMPTY itemId - setting manually")
                            account.itemId = itemId
                        } else if account.itemId != itemId {
                            print("⚠️ [Fetch Accounts Only] Account '\(account.name)' has MISMATCHED itemId - fixing")
                            account.itemId = itemId
                        } else {
                            print("✅ [Fetch Accounts Only] Account '\(account.name)' correctly has itemId: '\(itemId)'")
                        }
                    }

                    allAccounts.append(contentsOf: accounts)
                    print("🔄 [Fetch Accounts Only] Total accounts so far: \(allAccounts.count)")

                } catch {
                    print("❌ [Fetch Accounts Only] Failed to fetch accounts for itemId \(itemId) after all retries: \(error.localizedDescription)")

                    // Clean up orphaned tokens
                    let errorString = error.localizedDescription.lowercased()
                    if errorString.contains("item") && errorString.contains("not found") {
                        print("⚠️ [Fetch Accounts Only] Item removed from Plaid, cleaning up itemId: \(itemId)")
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

            // Fetch 6 months of transactions for each account
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .month, value: -6, to: endDate) ?? endDate

            for itemId in itemIds {
                print("📊 [Analyze Finances] Fetching transactions for itemId: \(itemId)...")

                do {
                    let accessToken = try KeychainService.shared.load(for: itemId)

                    let transactions = try await plaidService.fetchTransactions(
                        accessToken: accessToken,
                        startDate: startDate,
                        endDate: endDate
                    )
                    print("📊 [Analyze Finances] Fetched \(transactions.count) transaction(s) for itemId: \(itemId)")
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

            // Calculate financial summary
            self.summary = TransactionAnalyzer.calculateSummary(
                transactions: allTransactions,
                accounts: accounts
            )

            // Save to cache
            saveToCache()

            // Update state: analysis complete but no plan yet
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
            let monthlyExpenses = summary.avgMonthlyExpenses

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
                    let accessToken = try KeychainService.shared.load(for: itemId)
                    print("🔄 [Refresh All Data] Access token loaded for itemId: \(itemId)")

                    // Fetch accounts
                    print("🔄 [Refresh All Data] Fetching accounts for itemId: \(itemId)...")
                    let accounts = try await plaidService.fetchAccounts(accessToken: accessToken)
                    print("🔄 [Refresh All Data] Fetched \(accounts.count) account(s) for itemId: \(itemId)")

                    // Verify and log itemId assignment
                    // Note: Backend now injects item_id into response, so decoder should set it automatically
                    for account in accounts {
                        if account.itemId.isEmpty {
                            print("⚠️ [Refresh All Data] Account '\(account.name)' has EMPTY itemId after decode - setting manually")
                            account.itemId = itemId
                        } else if account.itemId != itemId {
                            print("⚠️ [Refresh All Data] Account '\(account.name)' has MISMATCHED itemId: '\(account.itemId)' vs expected '\(itemId)' - fixing")
                            account.itemId = itemId
                        } else {
                            print("✅ [Refresh All Data] Account '\(account.name)' (id: \(account.id)) correctly has itemId: '\(itemId)'")
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
                        accessToken: accessToken,
                        startDate: startDate,
                        endDate: endDate
                    )
                    print("🔄 [Refresh All Data] Fetched \(transactions.count) transaction(s) for itemId: \(itemId)")
                    allTransactions.append(contentsOf: transactions)

                    // Update loading step with actual transaction count
                    loadingStep = .analyzingTransactions(count: allTransactions.count)
                } catch {
                    print("❌ [Refresh All Data] Failed to fetch data for itemId \(itemId): \(error.localizedDescription)")
                    print("❌ [Refresh All Data] Error details: \(error)")

                    // Only delete from Keychain if it's a Plaid "item not found" error
                    // For other errors (network, decode, etc), keep the itemId
                    let errorString = error.localizedDescription.lowercased()
                    if errorString.contains("item") && errorString.contains("not found") {
                        print("⚠️ [Refresh All Data] Item was removed from Plaid, cleaning up orphaned itemId: \(itemId)")
                        try? KeychainService.shared.delete(for: itemId)
                        print("✅ [Refresh All Data] Orphaned itemId removed from Keychain")
                    } else {
                        print("⚠️ [Refresh All Data] Keeping itemId in Keychain despite error (may be temporary network issue)")
                        // Keep the accounts we already fetched, just skip transactions for this item
                    }
                }
            }

            // Update published properties
            self.accounts = allAccounts
            self.transactions = allTransactions

            // Calculate summary
            self.summary = TransactionAnalyzer.calculateSummary(
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
            // Get access token for this itemId
            print("🗑️ [Account Removal] Loading access token from Keychain...")
            let accessToken = try KeychainService.shared.load(for: itemId)
            print("🗑️ [Account Removal] Access token loaded successfully")

            // Call Plaid API to remove the account
            print("🗑️ [Account Removal] Calling backend to remove account...")
            let removedItemId = try await plaidService.removeAccount(accessToken: accessToken)
            print("🗑️ [Account Removal] Backend returned removed itemId: \(removedItemId)")

            // Remove access token from Keychain
            print("🗑️ [Account Removal] Deleting access token from Keychain...")
            try KeychainService.shared.delete(for: removedItemId)
            print("🗑️ [Account Removal] Access token deleted from Keychain")

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

            // Recalculate summary with remaining data
            if !accounts.isEmpty {
                print("🗑️ [Account Removal] Recalculating summary with remaining \(accounts.count) account(s)")
                summary = TransactionAnalyzer.calculateSummary(
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
            availableToSpend: summary?.availableToSpend ?? 0
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

        // Save accounts
        if let accountsData = try? encoder.encode(accounts) {
            UserDefaults.standard.set(accountsData, forKey: "cached_accounts")
            print("💾 [Cache Save] ✅ Saved \(accounts.count) accounts")

            // Log itemId status for each account being saved
            for account in accounts {
                if account.itemId.isEmpty {
                    print("💾 [Cache Save] ⚠️ Saving account '\(account.name)' with EMPTY itemId!")
                } else {
                    print("💾 [Cache Save] ✅ Saving account '\(account.name)' with itemId: \(account.itemId)")
                }
            }
        } else {
            print("💾 [Cache Save] ❌ Failed to encode accounts")
        }

        // Save transactions
        if let transactionsData = try? encoder.encode(transactions) {
            UserDefaults.standard.set(transactionsData, forKey: "cached_transactions")
            print("💾 [Cache Save] ✅ Saved \(transactions.count) transactions")
        } else {
            print("💾 [Cache Save] ❌ Failed to encode transactions")
        }

        // Save summary
        if let summaryData = try? encoder.encode(summary) {
            UserDefaults.standard.set(summaryData, forKey: "cached_summary")
            print("💾 [Cache Save] ✅ Saved summary")
        } else {
            print("💾 [Cache Save] ❌ Failed to encode summary")
        }

        // Save user journey state
        if let stateData = try? encoder.encode(userJourneyState) {
            UserDefaults.standard.set(stateData, forKey: "cached_journey_state")
            print("💾 [Cache] Saved journey state: \(userJourneyState.rawValue)")
        }

        print("💾 [Cache Save] Cache save complete")
    }

    private func loadFromCache() {
        print("💾 [Cache Load] Starting cache load...")
        let decoder = JSONDecoder()

        // Load accounts
        if let accountsData = UserDefaults.standard.data(forKey: "cached_accounts") {
            print("💾 [Cache Load] Found cached accounts data (\(accountsData.count) bytes)")
            if let accounts = try? decoder.decode([BankAccount].self, from: accountsData) {
                self.accounts = accounts
                print("💾 [Cache Load] ✅ Decoded \(accounts.count) account(s) from cache")

                // Validate that cached accounts have proper itemIds
                validateAndFixAccountItemIds()
            } else {
                print("💾 [Cache Load] ❌ Failed to decode accounts from cache")
            }
        } else {
            print("💾 [Cache Load] No cached accounts data found")
        }

        // Load transactions
        if let transactionsData = UserDefaults.standard.data(forKey: "cached_transactions") {
            print("💾 [Cache Load] Found cached transactions data (\(transactionsData.count) bytes)")
            if let transactions = try? decoder.decode([Transaction].self, from: transactionsData) {
                self.transactions = transactions
                print("💾 [Cache Load] ✅ Decoded \(transactions.count) transaction(s) from cache")
            } else {
                print("💾 [Cache Load] ❌ Failed to decode transactions from cache")
            }
        } else {
            print("💾 [Cache Load] No cached transactions data found")
        }

        // Load summary
        if let summaryData = UserDefaults.standard.data(forKey: "cached_summary") {
            print("💾 [Cache Load] Found cached summary data (\(summaryData.count) bytes)")
            if let summary = try? decoder.decode(FinancialSummary.self, from: summaryData) {
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

        // Load user journey state
        if let stateData = UserDefaults.standard.data(forKey: "cached_journey_state"),
           let state = try? decoder.decode(UserJourneyState.self, from: stateData) {
            self.userJourneyState = state
            print("📂 [Cache] Loaded journey state: \(state.rawValue)")
        } else {
            // Infer state from cached data for existing users
            inferStateFromCache()
        }

        print("💾 [Cache Load] Cache load complete - Accounts: \(accounts.count), Transactions: \(transactions.count)")
    }

    /// Infers user journey state from cached data (for existing users after app update)
    private func inferStateFromCache() {
        print("🔍 [State] Inferring state from cached data...")
        print("   - Accounts: \(accounts.count)")
        print("   - Summary: \(summary != nil ? "exists" : "nil")")
        print("   - Budgets: \(budgetManager.budgets.count)")

        if accounts.isEmpty {
            userJourneyState = .noAccountsConnected
            print("✅ [State] Inferred: .noAccountsConnected (no accounts)")
        } else if budgetManager.budgets.isEmpty && summary == nil {
            userJourneyState = .accountsConnected
            print("✅ [State] Inferred: .accountsConnected (accounts exist, no analysis)")
        } else if budgetManager.budgets.isEmpty && summary != nil {
            userJourneyState = .analysisComplete
            print("✅ [State] Inferred: .analysisComplete (analysis exists, no budgets)")
        } else {
            userJourneyState = .planCreated
            print("✅ [State] Inferred: .planCreated (budgets exist)")
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
            if summary != nil {
                print("⚠️ [State] WARNING: State is .accountsConnected but summary exists (analysis already run)")
            }

        case .analysisComplete:
            if summary == nil {
                print("⚠️ [State] WARNING: State is .analysisComplete but summary is nil")
            }
            if !budgetManager.budgets.isEmpty {
                print("⚠️ [State] WARNING: State is .analysisComplete but budgets exist (plan already created)")
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
}

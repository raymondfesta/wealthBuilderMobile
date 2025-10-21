import Foundation
import SwiftUI

@MainActor
class FinancialViewModel: ObservableObject {
    @Published var summary: FinancialSummary?
    @Published var accounts: [BankAccount] = []
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var error: Error?

    // Budget and goal management
    @Published var budgetManager: BudgetManager
    @Published var currentAlert: ProactiveAlert?
    @Published var isShowingGuidance = false

    // Notification navigation
    var navigationCoordinator: NotificationNavigationCoordinator?

    private let plaidService: PlaidService

    init(plaidService: PlaidService = PlaidService()) {
        self.plaidService = plaidService
        self.budgetManager = BudgetManager()
        loadFromCache()
        setupNotificationObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Plaid Link

    func connectBankAccount(from viewController: UIViewController?) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let linkToken = try await plaidService.createLinkToken()
            try await plaidService.presentPlaidLink(linkToken: linkToken, from: viewController)

            // After successful link, fetch accounts and transactions
            await refreshData()
        } catch {
            self.error = error
        }
    }

    // MARK: - Data Refresh

    func refreshData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Get all stored access tokens
            let itemIds = try KeychainService.shared.allKeys()

            var allAccounts: [BankAccount] = []
            var allTransactions: [Transaction] = []

            // Fetch data for each linked account
            for itemId in itemIds {
                let accessToken = try KeychainService.shared.load(for: itemId)

                // Fetch accounts
                let accounts = try await plaidService.fetchAccounts(accessToken: accessToken)
                allAccounts.append(contentsOf: accounts)

                // Fetch 6 months of transactions
                let endDate = Date()
                let startDate = Calendar.current.date(byAdding: .month, value: -6, to: endDate) ?? endDate

                let transactions = try await plaidService.fetchTransactions(
                    accessToken: accessToken,
                    startDate: startDate,
                    endDate: endDate
                )
                allTransactions.append(contentsOf: transactions)
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
            budgetManager.generateBudgets(from: allTransactions)

            // Save to cache
            saveToCache()

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

        } catch {
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

        if let firstAlert = alerts.first {
            currentAlert = firstAlert
            isShowingGuidance = true
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

    private func saveToCache() {
        let encoder = JSONEncoder()
        if let accountsData = try? encoder.encode(accounts) {
            UserDefaults.standard.set(accountsData, forKey: "cached_accounts")
        }
        if let transactionsData = try? encoder.encode(transactions) {
            UserDefaults.standard.set(transactionsData, forKey: "cached_transactions")
        }
        if let summaryData = try? encoder.encode(summary) {
            UserDefaults.standard.set(summaryData, forKey: "cached_summary")
        }
    }

    private func loadFromCache() {
        let decoder = JSONDecoder()
        if let accountsData = UserDefaults.standard.data(forKey: "cached_accounts"),
           let accounts = try? decoder.decode([BankAccount].self, from: accountsData) {
            self.accounts = accounts
        }
        if let transactionsData = UserDefaults.standard.data(forKey: "cached_transactions"),
           let transactions = try? decoder.decode([Transaction].self, from: transactionsData) {
            self.transactions = transactions
        }
        if let summaryData = UserDefaults.standard.data(forKey: "cached_summary"),
           let summary = try? decoder.decode(FinancialSummary.self, from: summaryData) {
            self.summary = summary
        }
    }
}

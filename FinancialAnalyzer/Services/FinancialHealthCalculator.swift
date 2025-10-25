import Foundation

/// Calculates comprehensive financial health metrics from transaction and account data
/// Focus on opportunity-based, non-judgmental analysis
struct FinancialHealthCalculator {

    // MARK: - Public Interface

    /// Main entry point: calculates all health metrics from financial summary and transactions
    static func calculateHealthMetrics(
        summary: FinancialSummary,
        transactions: [Transaction],
        accounts: [BankAccount]
    ) -> FinancialHealthMetrics {

        print("📊 [HealthCalculator] Starting health metrics calculation...")

        // Calculate savings metrics using actual savings behavior
        let monthlySavings = calculateMonthlySavings(summary, transactions: transactions, accounts: accounts)
        let savingsTrend = calculateSavingsTrend(transactions, accounts: accounts)

        // Calculate emergency fund metrics using ONLY designated accounts
        let essentialSpending = calculateEssentialSpending(transactions)
        let emergencyFundAccounts = accounts.filter { $0.isEmergencyFund }
        let emergencyFundBalance = emergencyFundAccounts.compactMap { $0.availableBalance ?? $0.currentBalance }.reduce(0, +)
        let emergencyMonths = essentialSpending > 0 ? emergencyFundBalance / essentialSpending : 0
        let emergencyTarget = essentialSpending * 6 // Default to 6 months, adjust based on income stability

        // Calculate income stability
        let incomeStability = calculateIncomeStability(transactions)

        // Calculate debt metrics
        let debtPayments = calculateMonthlyDebtPayments(transactions)
        let monthsToDebtFree = calculateDebtPayoffTimeline(
            totalDebt: summary.totalDebt,
            monthlyPayment: debtPayments
        )

        // Calculate spending breakdown
        let discretionary = calculateDiscretionarySpending(transactions)
        let spendingTrend = calculateSpendingTrend(transactions)

        // Backend-only metrics (for AI decision making)
        let savingsRate = summary.avgMonthlyIncome > 0 ? monthlySavings / summary.avgMonthlyIncome : 0
        let debtToIncome = summary.avgMonthlyIncome > 0 ? debtPayments / summary.avgMonthlyIncome : 0
        let healthScore = calculateHealthScore(
            savingsRate: savingsRate,
            emergencyFundRatio: emergencyMonths / 6.0,
            debtToIncome: debtToIncome,
            incomeStability: incomeStability
        )

        print("📊 [HealthCalculator] Results:")
        print("   Monthly Savings: $\(String(format: "%.2f", monthlySavings)) (\(savingsTrend.rawValue))")
        print("   Emergency Fund: \(String(format: "%.1f", emergencyMonths)) months")
        print("   Income Stability: \(incomeStability.rawValue)")
        print("   Health Score: \(String(format: "%.1f", healthScore))/100 (backend only)")

        return FinancialHealthMetrics(
            monthlySavings: monthlySavings,
            monthlySavingsTrend: savingsTrend,
            emergencyFundMonthsCovered: emergencyMonths,
            emergencyFundTarget: emergencyTarget,
            monthlyIncome: summary.avgMonthlyIncome,
            incomeStability: incomeStability,
            monthlyDebtPayments: debtPayments,
            monthsToDebtFree: monthsToDebtFree,
            discretionarySpending: discretionary,
            essentialSpending: essentialSpending,
            spendingTrend: spendingTrend,
            healthScore: healthScore,
            savingsRate: savingsRate,
            debtToIncomeRatio: debtToIncome,
            calculatedAt: Date(),
            analysisMonths: summary.monthsAnalyzed
        )
    }

    // MARK: - Private Calculation Methods

    /// Calculates monthly savings using actual savings behavior
    /// Detects transfers to savings/investment accounts, not just income - expenses
    private static func calculateMonthlySavings(
        _ summary: FinancialSummary,
        transactions: [Transaction],
        accounts: [BankAccount]
    ) -> Double {
        // IMPROVED: Detect actual savings behavior from transactions and account balance changes

        // Method 1: Detect transfers to savings and investment accounts
        guard let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) else {
            return 0
        }

        // Find savings accounts (checking subtype savings, money market, or user-tagged)
        let savingsAccountIds = accounts.filter { account in
            // Plaid subtypes for savings
            if let subtype = account.subtype?.lowercased() {
                if subtype.contains("savings") || subtype.contains("money market") {
                    return true
                }
            }
            // User-tagged savings accounts
            if account.isSavingsGoal || account.isEmergencyFund {
                return true
            }
            return false
        }.map { $0.id }

        // Find investment account IDs
        let investmentAccountIds = accounts.filter { $0.isInvestment }.map { $0.id }

        // Calculate transfers TO savings/investment accounts
        let savingsTransfers = transactions
            .filter { $0.date >= sixMonthsAgo }
            .filter { transaction in
                // Transfers to savings accounts
                savingsAccountIds.contains(transaction.accountId) && transaction.amount < 0
            }
            .reduce(0) { $0 + abs($1.amount) }

        let investmentContributions = transactions
            .filter { $0.date >= sixMonthsAgo }
            .filter { $0.bucketCategory == .invested }
            .reduce(0) { $0 + $1.amount }

        let totalSavings = (savingsTransfers + investmentContributions) / 6.0

        // If we detected actual savings behavior, use it
        if totalSavings > 0 {
            print("📊 [HealthCalculator] Detected actual savings: $\(String(format: "%.2f", totalSavings))/month")
            return totalSavings
        }

        // FALLBACK: If no savings detected, check if there's positive cash flow
        // But be HONEST - if we can't detect savings, show "Insufficient data"
        let cashFlow = summary.avgMonthlyIncome - summary.avgMonthlyExpenses
        if cashFlow > 0 {
            print("⚠️ [HealthCalculator] No savings detected, using cash flow estimate: $\(String(format: "%.2f", cashFlow))/month")
            return max(cashFlow, 0)
        }

        print("⚠️ [HealthCalculator] Unable to calculate savings - insufficient data")
        return 0
    }

    /// Determines savings trend by comparing recent 3 months vs previous 3 months using actual savings behavior
    private static func calculateSavingsTrend(_ transactions: [Transaction], accounts: [BankAccount]) -> TrendIndicator {
        let calendar = Calendar.current
        let now = Date()

        guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now),
              let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) else {
            return .stable
        }

        // Recent period (last 3 months)
        let recentTransactions = transactions.filter { $0.date >= threeMonthsAgo }
        let recentIncome = recentTransactions
            .filter { $0.bucketCategory == .income }
            .reduce(0) { $0 + abs($1.amount) }
        let recentExpenses = recentTransactions
            .filter { $0.bucketCategory == .expenses }
            .reduce(0) { $0 + $1.amount }
        let recentSavings = recentIncome - recentExpenses

        // Older period (3-6 months ago)
        let olderTransactions = transactions.filter { $0.date >= sixMonthsAgo && $0.date < threeMonthsAgo }
        let olderIncome = olderTransactions
            .filter { $0.bucketCategory == .income }
            .reduce(0) { $0 + abs($1.amount) }
        let olderExpenses = olderTransactions
            .filter { $0.bucketCategory == .expenses }
            .reduce(0) { $0 + $1.amount }
        let olderSavings = olderIncome - olderExpenses

        // Calculate change
        let change = recentSavings - olderSavings
        let changePercent = abs(olderSavings) > 0 ? abs(change) / abs(olderSavings) : 0

        // Threshold of 5% for significance
        if changePercent < 0.05 { return .stable }
        return change > 0 ? .increasing : .decreasing
    }

    /// Calculates average monthly essential spending
    /// Essential categories: Groceries, Rent, Mortgage, Utilities, Transportation, Insurance, Healthcare, Childcare
    private static func calculateEssentialSpending(_ transactions: [Transaction]) -> Double {
        let essentialCategories = ["Groceries", "Rent", "Mortgage", "Utilities", "Transportation", "Insurance", "Healthcare", "Childcare", "Gas", "Public Transportation"]

        guard let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) else {
            return 0
        }

        let essentialTotal = transactions
            .filter { $0.date >= sixMonthsAgo && $0.bucketCategory == .expenses }
            .filter { transaction in
                essentialCategories.contains(where: { essential in
                    transaction.category.contains(where: { $0.localizedCaseInsensitiveContains(essential) })
                })
            }
            .reduce(0) { $0 + $1.amount }

        let months = 6.0
        return essentialTotal / months
    }

    /// Determines income stability based on coefficient of variation across months
    private static func calculateIncomeStability(_ transactions: [Transaction]) -> IncomeStabilityLevel {
        guard let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) else {
            return .inconsistent
        }

        let incomeTransactions = transactions.filter {
            $0.date >= sixMonthsAgo && $0.bucketCategory == .income
        }

        guard !incomeTransactions.isEmpty else { return .inconsistent }

        // Group by month
        var monthlyIncomes: [Double] = []
        let calendar = Calendar.current

        for monthOffset in 0..<6 {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) else { continue }
            guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }

            let monthIncome = incomeTransactions
                .filter { $0.date >= monthStart && $0.date < monthEnd }
                .reduce(0) { $0 + abs($1.amount) }

            monthlyIncomes.append(monthIncome)
        }

        guard monthlyIncomes.count >= 3 else { return .inconsistent }

        // Calculate coefficient of variation (standard deviation / mean)
        let average = monthlyIncomes.reduce(0, +) / Double(monthlyIncomes.count)
        guard average > 0 else { return .inconsistent }

        let variance = monthlyIncomes.reduce(0) { $0 + pow($1 - average, 2) } / Double(monthlyIncomes.count)
        let stdDev = sqrt(variance)
        let coefficientOfVariation = stdDev / average

        // Classify stability
        if coefficientOfVariation < 0.15 { return .stable }
        if coefficientOfVariation < 0.30 { return .variable }
        return .inconsistent
    }

    /// Calculates average monthly debt payments
    private static func calculateMonthlyDebtPayments(_ transactions: [Transaction]) -> Double {
        guard let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) else {
            return 0
        }

        let debtTotal = transactions
            .filter { $0.date >= sixMonthsAgo && $0.bucketCategory == .debt }
            .reduce(0) { $0 + $1.amount }

        return debtTotal / 6.0
    }

    /// Estimates months until debt-free based on current payment rate
    private static func calculateDebtPayoffTimeline(totalDebt: Double, monthlyPayment: Double) -> Int? {
        guard totalDebt > 0, monthlyPayment > 0 else { return nil }
        return Int(ceil(totalDebt / monthlyPayment))
    }

    /// Calculates average monthly discretionary spending
    /// Discretionary categories: Entertainment, Dining, Shopping, Travel, Subscriptions, Hobbies
    private static func calculateDiscretionarySpending(_ transactions: [Transaction]) -> Double {
        let discretionaryCategories = ["Entertainment", "Dining", "Restaurant", "Shopping", "Travel", "Subscription", "Hobbies", "Recreation", "Food and Drink"]

        guard let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) else {
            return 0
        }

        let discretionaryTotal = transactions
            .filter { $0.date >= sixMonthsAgo && $0.bucketCategory == .expenses }
            .filter { transaction in
                discretionaryCategories.contains(where: { category in
                    transaction.category.contains(where: { $0.localizedCaseInsensitiveContains(category) })
                })
            }
            .reduce(0) { $0 + $1.amount }

        return discretionaryTotal / 6.0
    }

    /// Determines overall spending trend by comparing recent vs older expenses
    private static func calculateSpendingTrend(_ transactions: [Transaction]) -> TrendIndicator {
        let calendar = Calendar.current
        let now = Date()

        guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now),
              let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) else {
            return .stable
        }

        let recentExpenses = transactions
            .filter { $0.date >= threeMonthsAgo && $0.bucketCategory == .expenses }
            .reduce(0) { $0 + $1.amount }

        let olderExpenses = transactions
            .filter { $0.date >= sixMonthsAgo && $0.date < threeMonthsAgo && $0.bucketCategory == .expenses }
            .reduce(0) { $0 + $1.amount }

        guard olderExpenses > 0 else { return .stable }

        let change = recentExpenses - olderExpenses
        let changePercent = abs(change) / abs(olderExpenses)

        // Threshold of 5% for significance
        if changePercent < 0.05 { return .stable }
        return change > 0 ? .increasing : .decreasing
    }

    /// Calculates overall health score (0-100) for backend AI decision-making
    /// NEVER shown to customer - used only for allocation recommendations
    ///
    /// Formula:
    /// - Savings Rate: 30% weight (0-30 points)
    /// - Emergency Fund Coverage: 25% weight (0-25 points)
    /// - Debt Health: 20% weight (0-20 points)
    /// - Income Stability: 15% weight (0-15 points)
    /// - Spending Discipline: 10% weight (0-10 points)
    private static func calculateHealthScore(
        savingsRate: Double,
        emergencyFundRatio: Double,
        debtToIncome: Double,
        incomeStability: IncomeStabilityLevel
    ) -> Double {
        // Savings component (0-30 points)
        // 15% savings rate = full 30 points, scale linearly
        let savingsComponent = min(savingsRate * 2, 1.0) * 30

        // Emergency fund component (0-25 points)
        // 6 months coverage = full 25 points
        let emergencyComponent = min(emergencyFundRatio, 1.0) * 25

        // Debt component (0-20 points)
        // 0% DTI = 20 points, 50%+ DTI = 0 points
        let debtComponent = max(1 - (debtToIncome * 2), 0) * 20

        // Income stability component (0-15 points)
        let stabilityComponent: Double
        switch incomeStability {
        case .stable:
            stabilityComponent = 15
        case .variable:
            stabilityComponent = 10
        case .inconsistent:
            stabilityComponent = 5
        }

        // Spending discipline component (0-10 points)
        // Give baseline 10 points for positive savings rate
        let spendingComponent: Double = savingsRate > 0 ? 10 : 5

        let totalScore = savingsComponent + emergencyComponent + debtComponent + stabilityComponent + spendingComponent

        return totalScore
    }
}

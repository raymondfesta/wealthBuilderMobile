import Foundation

struct TransactionAnalyzer {
    // MARK: - Category to Bucket Mapping

    static func categorizeToBucket(
        amount: Double,
        category: [String],
        categoryId: String?
    ) -> BucketCategory {
        // Income transactions (negative amounts in Plaid = money in)
        if amount < 0 {
            return .income
        }

        // Debt payments - credit cards, loans
        if let primaryCategory = category.first?.lowercased() {
            if primaryCategory.contains("credit card") ||
               primaryCategory.contains("loan payments") ||
               primaryCategory.contains("mortgage") {
                return .debt
            }
        }

        // Investment transfers
        if let primaryCategory = category.first?.lowercased() {
            if primaryCategory.contains("transfer") &&
               (primaryCategory.contains("investment") ||
                primaryCategory.contains("brokerage") ||
                primaryCategory.contains("retirement")) {
                return .invested
            }
        }

        // Default to expenses for positive amounts
        return .expenses
    }

    // MARK: - Financial Summary Calculation

    static func calculateSummary(
        transactions: [Transaction],
        accounts: [BankAccount]
    ) -> FinancialSummary {
        // Filter last 6 months of transactions
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let filteredTransactions = transactions.filter { $0.date >= sixMonthsAgo }

        // Calculate date range
        let analysisStartDate = filteredTransactions.map { $0.date }.min() ?? Date()
        let analysisEndDate = filteredTransactions.map { $0.date }.max() ?? Date()

        // Calculate months between dates
        let monthsAnalyzed = max(
            Calendar.current.dateComponents([.month], from: analysisStartDate, to: analysisEndDate).month ?? 6,
            1
        )

        // Group transactions by bucket category
        var incomeTotal: Double = 0
        var expensesTotal: Double = 0

        for transaction in filteredTransactions where !transaction.pending {
            let category = transaction.bucketCategory

            switch category {
            case .income:
                // Plaid uses negative for income, so negate to get positive
                incomeTotal += abs(transaction.amount)
            case .expenses, .debt, .invested:
                // All outgoing money: regular expenses, debt payments, and investments
                expensesTotal += transaction.amount
            default:
                break
            }
        }

        // Calculate averages
        let avgMonthlyIncome = incomeTotal / Double(monthsAnalyzed)
        let avgMonthlyExpenses = expensesTotal / Double(monthsAnalyzed)

        // Calculate debt from credit/loan accounts
        let totalDebt = accounts
            .filter { $0.isCredit || $0.isLoan }
            .compactMap { $0.currentBalance }
            .reduce(0, +)

        // Calculate investments
        let totalInvested = accounts
            .filter { $0.isInvestment }
            .compactMap { $0.currentBalance }
            .reduce(0, +)

        // Calculate cash available
        let totalCashAvailable = accounts
            .filter { $0.isDepository }
            .compactMap { $0.availableBalance ?? $0.currentBalance }
            .reduce(0, +)

        // Calculate disposable income
        // Formula: Average monthly income - average monthly expenses
        // Note: Expenses already include debt payments, so no need to subtract them separately
        let availableToSpend = avgMonthlyIncome - avgMonthlyExpenses

        return FinancialSummary(
            avgMonthlyIncome: avgMonthlyIncome,
            avgMonthlyExpenses: avgMonthlyExpenses,
            totalDebt: totalDebt,
            totalInvested: totalInvested,
            totalCashAvailable: totalCashAvailable,
            availableToSpend: max(availableToSpend, 0), // Don't show negative disposable income
            analysisStartDate: analysisStartDate,
            analysisEndDate: analysisEndDate,
            monthsAnalyzed: monthsAnalyzed,
            totalTransactions: filteredTransactions.count,
            lastUpdated: Date()
        )
    }

    // MARK: - Category Breakdown

    static func expensesByCategory(
        from transactions: [Transaction]
    ) -> [String: Double] {
        var breakdown: [String: Double] = [:]

        for transaction in transactions where transaction.bucketCategory == .expenses {
            let categoryName = transaction.category.first ?? "Uncategorized"
            breakdown[categoryName, default: 0] += transaction.amount
        }

        return breakdown
    }

    // MARK: - Trend Analysis

    static func monthlyTrends(
        from transactions: [Transaction],
        bucket: BucketCategory
    ) -> [Date: Double] {
        var monthlyData: [Date: Double] = [:]
        let calendar = Calendar.current

        for transaction in transactions where transaction.bucketCategory == bucket {
            // Get start of month for this transaction
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            guard let monthStart = calendar.date(from: components) else { continue }

            if bucket == .income {
                monthlyData[monthStart, default: 0] += abs(transaction.amount)
            } else {
                monthlyData[monthStart, default: 0] += transaction.amount
            }
        }

        return monthlyData
    }

    // MARK: - Category Detail Helpers

    static func transactionsForBucket(
        _ bucket: BucketCategory,
        from transactions: [Transaction]
    ) -> [Transaction] {
        return transactions.filter { $0.bucketCategory == bucket }
    }

    static func topContributors(
        for bucket: BucketCategory,
        from transactions: [Transaction],
        limit: Int = 10
    ) -> [Transaction] {
        let filtered = transactionsForBucket(bucket, from: transactions)

        return filtered.sorted { transaction1, transaction2 in
            if bucket == .income {
                return abs(transaction1.amount) > abs(transaction2.amount)
            } else {
                return transaction1.amount > transaction2.amount
            }
        }.prefix(limit).map { $0 }
    }

    static func contributingAccounts(
        for bucket: BucketCategory,
        from accounts: [BankAccount]
    ) -> [BankAccount] {
        switch bucket {
        case .debt:
            return accounts.filter { $0.isCredit || $0.isLoan }
        case .invested:
            return accounts.filter { $0.isInvestment }
        case .cash:
            return accounts.filter { $0.isDepository }
        default:
            return []
        }
    }

    static func calculationExplanation(for bucket: BucketCategory) -> String {
        switch bucket {
        case .income:
            return "Total income deposits divided by number of months analyzed"
        case .expenses:
            return "Total expenses divided by number of months analyzed"
        case .debt:
            return "Sum of current balances on all credit cards and loans"
        case .invested:
            return "Sum of current balances in all investment and retirement accounts"
        case .cash:
            return "Sum of available balances in all checking and savings accounts"
        case .disposable:
            return "Average Monthly Income - Average Monthly Expenses"
        }
    }
}

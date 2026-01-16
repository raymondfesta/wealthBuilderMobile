import Foundation

struct TransactionAnalyzer {
    // MARK: - Category to Bucket Mapping

    /// Categorizes a transaction into a high-level bucket using Plaid's Personal Finance Category
    /// Leverages 90%+ accuracy from Plaid's PFC taxonomy with confidence scoring
    static func categorizeToBucket(
        amount: Double,
        category: [String],
        categoryId: String?,
        personalFinanceCategory: PersonalFinanceCategory? = nil
    ) -> BucketCategory {
        // PRIORITY 1: Use Plaid Personal Finance Category if available with HIGH confidence
        if let pfc = personalFinanceCategory,
           pfc.confidenceLevel == .veryHigh || pfc.confidenceLevel == .high {
            let bucket = mapPFCToBucket(pfc.primary, detailed: pfc.detailed, amount: amount)
            print("📊 [PFC] Using Plaid category '\(pfc.primary)' (\(pfc.confidenceLevel.rawValue)) → \(bucket.rawValue)")
            return bucket
        }

        // PRIORITY 2: Use Plaid PFC even with lower confidence (better than keyword matching)
        if let pfc = personalFinanceCategory {
            let bucket = mapPFCToBucket(pfc.primary, detailed: pfc.detailed, amount: amount)
            print("⚠️ [PFC] Using Plaid category '\(pfc.primary)' (\(pfc.confidenceLevel.rawValue) confidence) → \(bucket.rawValue)")
            return bucket
        }

        // FALLBACK: Use legacy keyword matching (less accurate, should trigger validation)
        print("⚠️ [Legacy] No PFC data, using keyword matching (needs validation)")
        return legacyCategorizeToBucket(amount: amount, category: category, categoryId: categoryId)
    }

    /// Maps Plaid's Personal Finance Category to our 6 high-level buckets
    /// Based on Plaid's 16 primary categories
    private static func mapPFCToBucket(_ primary: String, detailed: String, amount: Double) -> BucketCategory {
        let primaryUpper = primary.uppercased()

        switch primaryUpper {
        case "INCOME":
            return .income

        case "TRANSFER_IN":
            // Money coming in - treat as income unless it's between own accounts
            if detailed.contains("ACCOUNT") {
                return .cash // Internal transfer
            }
            return .income

        case "TRANSFER_OUT":
            // Check if it's going to investment/savings
            if detailed.contains("INVESTMENT") || detailed.contains("RETIREMENT") || detailed.contains("SAVINGS") {
                return .invested
            }
            // Check if it's a loan/debt payment
            if detailed.contains("LOAN") || detailed.contains("CREDIT") {
                return .debt
            }
            return .expenses

        case "LOAN_PAYMENTS":
            return .debt

        case "BANK_FEES", "RENT_AND_UTILITIES", "FOOD_AND_DRINK",
             "GENERAL_MERCHANDISE", "HOME_IMPROVEMENT", "MEDICAL",
             "PERSONAL_CARE", "GENERAL_SERVICES", "GOVERNMENT_AND_NON_PROFIT",
             "TRANSPORTATION", "TRAVEL", "ENTERTAINMENT":
            return .expenses

        default:
            // Unknown PFC category - use amount to guess
            return amount < 0 ? .income : .expenses
        }
    }

    /// Legacy categorization using keyword matching (less accurate, kept as fallback)
    private static func legacyCategorizeToBucket(
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
        var investmentContributionsTotal: Double = 0
        var incomeCount = 0
        var expenseCount = 0
        var debtCount = 0
        var investedCount = 0
        var otherCount = 0

        for transaction in filteredTransactions where !transaction.pending {
            let category = transaction.bucketCategory

            switch category {
            case .income:
                // Plaid uses negative for income, so negate to get positive
                incomeTotal += abs(transaction.amount)
                incomeCount += 1
            case .expenses:
                expensesTotal += transaction.amount
                expenseCount += 1
            case .debt:
                expensesTotal += transaction.amount
                debtCount += 1
            case .invested:
                // Track investment contributions separately - NOT as expenses
                // These are wealth-building transfers, not spending
                investmentContributionsTotal += transaction.amount
                investedCount += 1
            default:
                otherCount += 1
            }
        }

        // Calculate averages
        let avgMonthlyIncome = incomeTotal / Double(monthsAnalyzed)
        let avgMonthlyExpenses = expensesTotal / Double(monthsAnalyzed)
        let monthlyInvestmentContributions = investmentContributionsTotal / Double(monthsAnalyzed)

        // Debug logging
        print("📊 Transaction Analysis:")
        print("   Total transactions: \(filteredTransactions.count)")
        print("   Income txns: \(incomeCount), Expense txns: \(expenseCount)")
        print("   Debt txns: \(debtCount), Investment txns: \(investedCount), Other: \(otherCount)")
        print("   Months analyzed: \(monthsAnalyzed)")
        print("   Income total: $\(incomeTotal)")
        print("   Expenses total: $\(expensesTotal) (excludes investments)")
        print("   Investment contributions: $\(investmentContributionsTotal)")
        print("   Avg Monthly Income: $\(avgMonthlyIncome)")
        print("   Avg Monthly Expenses: $\(avgMonthlyExpenses)")
        print("   Monthly Investment Contributions: $\(monthlyInvestmentContributions)")
        print("   Discretionary Income: $\(avgMonthlyIncome - avgMonthlyExpenses)")

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

        // Calculate available to spend using a smart approach
        // Strategy: Use actual cash available and adjust for monthly spending rate
        // This gives users a realistic view of what they can spend NOW
        let daysInMonth = 30.0
        let calendar = Calendar.current
        let today = Date()
        let daysRemainingInMonth = Double(calendar.range(of: .day, in: .month, for: today)!.count - calendar.component(.day, from: today))

        // Calculate daily spending rate
        let dailyExpenseRate = avgMonthlyExpenses / daysInMonth

        // Estimated spending for rest of month
        let estimatedRemainingExpenses = dailyExpenseRate * daysRemainingInMonth

        // Available to spend = Cash on hand - estimated remaining expenses for this month
        // This tells the user: "After your usual expenses, you have this much to spend"
        let availableToSpend = max(totalCashAvailable - estimatedRemainingExpenses, 0)

        print("📊 Available to Spend Calculation:")
        print("   Total Cash Available: $\(totalCashAvailable)")
        print("   Avg Monthly Expenses: $\(avgMonthlyExpenses)")
        print("   Days remaining in month: \(Int(daysRemainingInMonth))")
        print("   Estimated remaining expenses: $\(estimatedRemainingExpenses)")
        print("   ✅ Available to Spend: $\(availableToSpend)")

        return FinancialSummary(
            avgMonthlyIncome: avgMonthlyIncome,
            avgMonthlyExpenses: avgMonthlyExpenses,
            totalDebt: totalDebt,
            totalInvested: totalInvested,
            totalCashAvailable: totalCashAvailable,
            availableToSpend: availableToSpend,
            monthlyInvestmentContributions: monthlyInvestmentContributions,
            analysisStartDate: analysisStartDate,
            analysisEndDate: analysisEndDate,
            monthsAnalyzed: monthsAnalyzed,
            totalTransactions: filteredTransactions.count,
            lastUpdated: Date()
        )
    }

    // MARK: - Analysis Snapshot Generation

    /// Generates a complete analysis snapshot with MonthlyFlow and FinancialPosition
    /// This is the primary output for the Analysis Complete screen
    static func generateAnalysisSnapshot(
        transactions: [Transaction],
        accounts: [BankAccount]
    ) -> AnalysisSnapshot {
        // Filter last 6 months of transactions
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let filteredTransactions = transactions.filter { $0.date >= sixMonthsAgo }

        // Calculate date range
        let analysisStartDate = filteredTransactions.map { $0.date }.min() ?? Date()
        let analysisEndDate = filteredTransactions.map { $0.date }.max() ?? Date()
        let monthsAnalyzed = max(
            Calendar.current.dateComponents([.month], from: analysisStartDate, to: analysisEndDate).month ?? 6,
            1
        )

        // Aggregate transaction data
        var incomeTotal: Double = 0
        var expensesTotal: Double = 0
        var investmentContributionsTotal: Double = 0

        for transaction in filteredTransactions where !transaction.pending {
            switch transaction.bucketCategory {
            case .income:
                incomeTotal += abs(transaction.amount)
            case .expenses:
                expensesTotal += transaction.amount
            case .debt:
                expensesTotal += transaction.amount
            case .invested:
                investmentContributionsTotal += transaction.amount
            default:
                break
            }
        }

        // Calculate monthly averages
        let monthDivisor = Double(monthsAnalyzed)
        let avgMonthlyIncome = incomeTotal / monthDivisor
        let avgMonthlyExpenses = expensesTotal / monthDivisor
        let monthlyInvestmentContributions = investmentContributionsTotal / monthDivisor

        // Calculate debt minimums from accounts
        let debtMinimums = calculateDebtMinimums(accounts: accounts)

        // Calculate position from accounts
        let totalDebt = accounts
            .filter { $0.isCredit || $0.isLoan }
            .compactMap { $0.currentBalance }
            .reduce(0, +)

        let totalInvested = accounts
            .filter { $0.isInvestment }
            .compactMap { $0.currentBalance }
            .reduce(0, +)

        let emergencyCash = accounts
            .filter { $0.isDepository }
            .compactMap { $0.availableBalance ?? $0.currentBalance }
            .reduce(0, +)

        // Count transactions needing validation
        let transactionsNeedingValidation = filteredTransactions.filter { $0.needsValidation }.count

        // Build the snapshot
        let monthlyFlow = MonthlyFlow(
            income: avgMonthlyIncome,
            essentialExpenses: avgMonthlyExpenses,
            debtMinimums: debtMinimums
        )

        let position = FinancialPosition(
            emergencyCash: emergencyCash,
            totalDebt: totalDebt,
            investmentBalances: totalInvested,
            monthlyInvestmentContributions: monthlyInvestmentContributions
        )

        let metadata = AnalysisMetadata(
            monthsAnalyzed: monthsAnalyzed,
            accountsConnected: Set(accounts.map { $0.itemId }).count,
            transactionsAnalyzed: filteredTransactions.count,
            transactionsNeedingValidation: transactionsNeedingValidation,
            lastUpdated: Date()
        )

        print("📊 [AnalysisSnapshot] Generated:")
        print("   Income: $\(Int(avgMonthlyIncome))/mo")
        print("   Expenses: $\(Int(avgMonthlyExpenses))/mo")
        print("   Debt Minimums: $\(Int(debtMinimums))/mo")
        print("   Discretionary: $\(Int(monthlyFlow.discretionaryIncome))/mo")
        print("   Emergency Fund: $\(Int(emergencyCash))")
        print("   Investment Contributions: $\(Int(monthlyInvestmentContributions))/mo")
        print("   Needs Validation: \(transactionsNeedingValidation) txns")

        return AnalysisSnapshot(
            monthlyFlow: monthlyFlow,
            position: position,
            metadata: metadata
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
            return "Cash Available - Estimated Remaining Expenses (based on your spending patterns)"
        }
    }

    // MARK: - Debt Minimums Calculation

    /// Calculates estimated minimum debt payments from account balances
    /// Credit cards: ~2.5% of balance (minimum $25)
    /// Loans: Based on typical payment schedules
    static func calculateDebtMinimums(accounts: [BankAccount]) -> Double {
        let debtAccounts = accounts.filter { $0.isCredit || $0.isLoan }

        return debtAccounts.reduce(0) { total, account in
            let balance = account.currentBalance ?? 0
            guard balance > 0 else { return total }

            if account.isCredit {
                // Credit cards: typically 2-3% of balance, minimum $25
                let minimumPayment = max(25, balance * 0.025)
                return total + minimumPayment
            } else if account.isLoan {
                // Estimate loan minimums based on subtype
                let subtype = account.subtype?.lowercased() ?? ""
                let estimatedPayment: Double

                switch subtype {
                case _ where subtype.contains("student"):
                    // Student loans: ~1% of balance monthly
                    estimatedPayment = balance * 0.01
                case _ where subtype.contains("auto"):
                    // Auto loans: ~1.5-2% of balance monthly
                    estimatedPayment = balance * 0.018
                case _ where subtype.contains("mortgage"):
                    // Mortgage: ~0.4-0.5% of balance monthly
                    estimatedPayment = balance * 0.005
                case _ where subtype.contains("personal"):
                    // Personal loans: ~2-3% of balance monthly
                    estimatedPayment = balance * 0.025
                default:
                    // Conservative estimate for unknown loan types
                    estimatedPayment = balance * 0.015
                }

                return total + estimatedPayment
            }

            return total
        }
    }
}

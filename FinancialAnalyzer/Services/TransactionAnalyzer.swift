// FinancialAnalyzer/Services/TransactionAnalyzer.swift

import Foundation

/// Analyzes transactions to calculate monthly flow and financial position
/// CRITICAL: This is the core calculation engine - accuracy is paramount
struct TransactionAnalyzer {

    // MARK: - Main Analysis Function (Plan Compatibility)

    /// Generates a complete financial snapshot from transactions and accounts
    /// - Parameters:
    ///   - transactions: All transactions from connected accounts
    ///   - accounts: All connected bank accounts
    /// - Returns: Complete FinancialSnapshot for display and algorithm
    static func generateSnapshot(
        transactions: [Transaction],
        accounts: [BankAccount]
    ) -> AnalysisSnapshot {
        generateAnalysisSnapshot(transactions: transactions, accounts: accounts)
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
        let filteredTransactions = transactions.filter {
            $0.date >= sixMonthsAgo && !$0.pending
        }

        // Calculate date range
        let analysisStartDate = filteredTransactions.map { $0.date }.min() ?? Date()
        let analysisEndDate = filteredTransactions.map { $0.date }.max() ?? Date()
        let monthsAnalyzed = max(
            Calendar.current.dateComponents([.month], from: analysisStartDate, to: analysisEndDate).month ?? 1,
            1
        )

        // Calculate monthly flow using new classification logic
        let monthlyFlow = calculateMonthlyFlow(
            transactions: filteredTransactions,
            accounts: accounts,
            months: monthsAnalyzed
        )

        // Calculate financial position
        let position = calculateFinancialPosition(
            transactions: filteredTransactions,
            accounts: accounts,
            months: monthsAnalyzed
        )

        // Count transactions needing validation
        let transactionsNeedingValidation = filteredTransactions.filter { $0.needsValidation }.count

        // Compute overall confidence
        let validationRatio = filteredTransactions.isEmpty ? 0.0 :
            Double(filteredTransactions.count - transactionsNeedingValidation) / Double(filteredTransactions.count)
        let expenseConfidence = monthlyFlow.expenseBreakdown?.confidence ?? 0.5
        let overallConfidence = (expenseConfidence + validationRatio) / 2.0

        let metadata = AnalysisMetadata(
            monthsAnalyzed: monthsAnalyzed,
            accountsConnected: Set(accounts.map { $0.itemId }).count,
            transactionsAnalyzed: filteredTransactions.count,
            transactionsNeedingValidation: transactionsNeedingValidation,
            overallConfidence: overallConfidence,
            lastUpdated: Date()
        )

        print("📊 [AnalysisSnapshot] Generated:")
        print("   Income: $\(Int(monthlyFlow.income))/mo")
        print("   Expenses: $\(Int(monthlyFlow.essentialExpenses))/mo")
        print("   Debt Minimums: $\(Int(monthlyFlow.debtMinimums))/mo")
        print("   Disposable Income: $\(Int(monthlyFlow.disposableIncome))/mo")
        print("   Emergency Cash: $\(Int(position.emergencyCash))")
        print("   Monthly Investment Contributions: $\(Int(position.monthlyInvestmentContributions))/mo")

        return AnalysisSnapshot(
            monthlyFlow: monthlyFlow,
            position: position,
            metadata: metadata
        )
    }

    // MARK: - Monthly Flow Calculation

    /// Calculate monthly cash flow from transactions
    static func calculateMonthlyFlow(
        transactions: [Transaction],
        accounts: [BankAccount],
        months: Int
    ) -> MonthlyFlow {
        guard months > 0 else {
            print("⚠️ [MonthlyFlow] months=0, returning empty")
            return .empty
        }

        // DIAGNOSTIC: Log all negative-amount transactions (potential income)
        let negativeAmounts = transactions.filter { $0.amount < 0 }
        print("📊 [MonthlyFlow] === DIAGNOSTIC START ===")
        print("📊 [MonthlyFlow] Total transactions: \(transactions.count)")
        print("📊 [MonthlyFlow] Negative amount (potential income): \(negativeAmounts.count)")
        print("📊 [MonthlyFlow] Months analyzed: \(months)")

        // Calculate monthly income (ONLY actual income, not transfers)
        let incomeTransactions = transactions.filter { transaction in
            isActualIncome(transaction) && !isInvestmentContribution(transaction)
        }
        let totalIncome = incomeTransactions.reduce(0) { $0 + abs($1.amount) }
        let monthlyIncome = totalIncome / Double(months)

        print("📊 [MonthlyFlow] Income transactions found: \(incomeTransactions.count)")
        print("📊 [MonthlyFlow] Total income over period: $\(Int(totalIncome))")
        print("📊 [MonthlyFlow] Monthly income: $\(Int(monthlyIncome))")

        // Log sample income transactions
        for txn in incomeTransactions.prefix(5) {
            print("   💰 Income: '\(txn.name)' $\(Int(abs(txn.amount))) (PFC: \(txn.personalFinanceCategory?.primary ?? "none"))")
        }

        // Log missed income candidates (negative amounts not classified as income)
        let missedIncome = negativeAmounts.filter { txn in
            !incomeTransactions.contains { $0.id == txn.id }
        }
        if !missedIncome.isEmpty {
            print("📊 [MonthlyFlow] ⚠️ Missed income candidates: \(missedIncome.count)")
            for txn in missedIncome.prefix(5) {
                let pfc = txn.personalFinanceCategory
                print("   ❌ Missed: '\(txn.name)' $\(Int(abs(txn.amount))) cat:\(txn.category.first ?? "none") PFC:\(pfc?.primary ?? "none")/\(pfc?.detailed ?? "none")")
            }
        }

        // Calculate essential expenses (EXCLUDE investment contributions and transfers)
        let essentialTransactions = transactions.filter { transaction in
            isEssentialExpense(transaction) && !isInvestmentContribution(transaction)
        }
        let expenseBreakdown = categorizeEssentialExpenses(essentialTransactions, months: months)

        print("📊 [MonthlyFlow] Expense transactions: \(essentialTransactions.count)")
        print("📊 [MonthlyFlow] Monthly expenses: $\(Int(expenseBreakdown.total))")

        // Calculate minimum debt payments from accounts
        let debtMinimums = calculateDebtMinimums(accounts: accounts)

        print("📊 [MonthlyFlow] Debt minimums: $\(Int(debtMinimums))")
        print("📊 [MonthlyFlow] Disposable: $\(Int(monthlyIncome - expenseBreakdown.total - debtMinimums))")
        print("📊 [MonthlyFlow] === DIAGNOSTIC END ===")

        return MonthlyFlow(
            income: monthlyIncome,
            expenseBreakdown: expenseBreakdown,
            debtMinimums: debtMinimums
        )
    }

    // MARK: - Financial Position Calculation

    /// Calculate current financial position from account balances
    static func calculateFinancialPosition(
        transactions: [Transaction],
        accounts: [BankAccount],
        months: Int
    ) -> FinancialPosition {
        // Emergency cash (liquid depository accounts only)
        let liquidAccounts = accounts.filter { account in
            account.isDepository && account.subtype != "cd"
        }
        let emergencyCash = liquidAccounts.reduce(0) {
            $0 + ($1.availableBalance ?? $1.currentBalance ?? 0)
        }

        // Debt accounts
        let debtAccounts = accounts.filter {
            $0.isCredit || $0.isLoan
        }.map { DebtAccount(from: $0) }

        // Investment balances
        let investmentAccounts = accounts.filter { $0.isInvestment }
        let investmentBalances = investmentAccounts.reduce(0) {
            $0 + ($1.currentBalance ?? 0)
        }

        // Track investment contributions separately (NOT as expense)
        let investmentContributions = transactions.filter { isInvestmentContribution($0) }
        let totalContributions = investmentContributions.reduce(0) { $0 + abs($1.amount) }
        let monthlyContributions = months > 0 ? totalContributions / Double(months) : 0

        return FinancialPosition(
            emergencyCash: emergencyCash,
            debtBalances: debtAccounts,
            investmentBalances: investmentBalances,
            monthlyInvestmentContributions: monthlyContributions
        )
    }

    // MARK: - Transaction Classification Helpers

    /// Determines if a transaction is actual income (not a transfer or contribution)
    /// CRITICAL: This prevents investment contributions from being counted as income
    static func isActualIncome(_ transaction: Transaction) -> Bool {
        // In Plaid, negative amounts = money flowing INTO the account
        guard transaction.amount < 0 else { return false }

        // Check PFC first (most reliable)
        if let pfc = transaction.personalFinanceCategory {
            let primary = pfc.primary.uppercased()
            if primary == "INCOME" {
                return true
            }
            // TRANSFER_IN that's not internal
            if primary == "TRANSFER_IN" && !pfc.detailed.uppercased().contains("ACCOUNT") {
                // Check if it's investment-related
                if pfc.detailed.uppercased().contains("INVESTMENT") ||
                   pfc.detailed.uppercased().contains("RETIREMENT") {
                    return false
                }
                return true
            }
        }

        // Check for income-related legacy categories
        let incomeCategories = [
            "INCOME", "PAYROLL", "DIRECT_DEPOSIT", "INTEREST",
            "DIVIDEND", "TAX_REFUND", "UNEMPLOYMENT", "SOCIAL_SECURITY"
        ]

        if let category = transaction.category.first?.uppercased() {
            if incomeCategories.contains(where: { category.contains($0) }) {
                return true
            }
            // Exclude transfers - these are NOT income
            if category.contains("TRANSFER") {
                return false
            }
        }

        // Check transaction name for payroll patterns (expanded for sandbox)
        let incomeMerchants = [
            "payroll", "direct dep", "direct deposit", "salary", "wages",
            "ach deposit", "employer", "dd ", "paycheck", "payment received",
            "credit", "deposit"
        ]
        let nameLower = transaction.name.lowercased()

        // Exclude refunds and returns from being counted as income
        let refundTerms = ["refund", "return", "reversal", "adjustment", "cashback"]
        if refundTerms.contains(where: { nameLower.contains($0) }) {
            return false
        }

        if incomeMerchants.contains(where: { nameLower.contains($0) }) {
            // Additional validation: "credit" and "deposit" are generic, need context
            if nameLower.contains("credit") || nameLower.contains("deposit") {
                // Must NOT be a transfer or payment
                if nameLower.contains("transfer") || nameLower.contains("payment to") {
                    return false
                }
            }
            return true
        }

        // Interest and dividend payments
        if nameLower.contains("interest") || nameLower.contains("dividend") {
            return true
        }

        // Plaid sandbox often uses "United Airlines" for payroll - detect regular large negative deposits
        // This is a fallback for sandbox data that may not have proper categories
        if transaction.personalFinanceCategory == nil && transaction.category.isEmpty {
            // FIRST: Reject transfer/funding keywords that indicate internal moves, not income
            let transferKeywords = [
                "transfer", "funding", "buffer", "emergency fund", "savings",
                "contribution", "investment", "401k", "ira", "brokerage"
            ]
            if transferKeywords.contains(where: { nameLower.contains($0) }) {
                return false
            }

            // Large negative amount with no category = likely income in sandbox
            if abs(transaction.amount) > 500 {
                return true
            }
        }

        return false
    }

    /// Determines if a transaction is an investment contribution
    /// CRITICAL: These should NOT be counted as expenses
    static func isInvestmentContribution(_ transaction: Transaction) -> Bool {
        // Check PFC first
        if let pfc = transaction.personalFinanceCategory {
            let primary = pfc.primary.uppercased()
            let detailed = pfc.detailed.uppercased()

            if primary == "TRANSFER_OUT" {
                if detailed.contains("INVESTMENT") ||
                   detailed.contains("RETIREMENT") ||
                   detailed.contains("SAVINGS") {
                    return true
                }
            }
        }

        // Check Plaid category codes for investment transfers
        let investmentCategories = [
            "TRANSFER_OUT_INVESTMENT", "TRANSFER_OUT_RETIREMENT",
            "TRANSFER_IN_INVESTMENT", "TRANSFER_IN_RETIREMENT",
            "401K", "IRA", "CONTRIBUTION", "INVESTMENT"
        ]

        if let category = transaction.category.first?.uppercased() {
            if investmentCategories.contains(where: { category.contains($0) }) {
                return true
            }
        }

        // Check merchant name patterns
        let investmentMerchants = [
            "vanguard", "fidelity", "schwab", "betterment", "wealthfront",
            "robinhood", "etrade", "td ameritrade", "merrill", "401k",
            "retirement", "roth", "ira"
        ]
        let nameLower = transaction.name.lowercased()
        if investmentMerchants.contains(where: { nameLower.contains($0) }) {
            // Additional check: make sure it's a contribution
            let contributionTerms = ["contribution", "transfer", "deposit", "buy", "purchase"]
            if contributionTerms.contains(where: { nameLower.contains($0) }) {
                return true
            }
            // If it's FROM checking/savings TO investment (positive amount = outflow)
            if transaction.amount > 0 {
                return true
            }
        }

        // Check for employee contribution patterns
        if nameLower.contains("employee contribution") ||
           nameLower.contains("employer match") ||
           nameLower.contains("monthly contribution") {
            return true
        }

        return false
    }

    /// Determines if a transaction is an internal transfer (between user's own accounts)
    static func isInternalTransfer(_ transaction: Transaction) -> Bool {
        // Check PFC
        if let pfc = transaction.personalFinanceCategory {
            let detailed = pfc.detailed.uppercased()
            if detailed.contains("ACCOUNT_TRANSFER") ||
               detailed.contains("SAME_INSTITUTION") {
                return true
            }
        }

        let transferCategories = [
            "TRANSFER_INTERNAL", "TRANSFER_SAME_INSTITUTION"
        ]

        if let category = transaction.category.first?.uppercased() {
            if transferCategories.contains(where: { category.contains($0) }) {
                return true
            }
        }

        let nameLower = transaction.name.lowercased()
        let transferTerms = [
            "transfer to", "transfer from", "internal transfer",
            "online transfer", "funds transfer",
            // Debt payment patterns (should not count as expenses)
            "credit card payment", "card payment", "loan payment",
            "autopay", "auto pay", "payment - chase", "payment - citi",
            "payment - amex", "payment - discover", "payment - capital one"
        ]

        return transferTerms.contains(where: { nameLower.contains($0) })
    }

    /// Determines if a transaction is an essential expense
    private static func isEssentialExpense(_ transaction: Transaction) -> Bool {
        // Must be an outflow (positive amount in Plaid = money OUT)
        guard transaction.amount > 0 else { return false }

        // Must NOT be an investment contribution
        guard !isInvestmentContribution(transaction) else { return false }

        // Must NOT be an internal transfer
        guard !isInternalTransfer(transaction) else { return false }

        return true
    }

    /// Convenience method for other services to check if transaction should be excluded
    static func shouldExcludeFromBudget(_ transaction: Transaction) -> Bool {
        isInvestmentContribution(transaction) || isInternalTransfer(transaction)
    }

    // MARK: - Essential vs Discretionary Classification

    /// Determines if a transaction is essential spending (housing, utilities, groceries, healthcare, transportation basics)
    /// Used by My Plan to calculate Essential Spending bucket
    static func isEssentialSpending(_ transaction: Transaction) -> Bool {
        // Must be an outflow that qualifies as an expense
        guard isEssentialExpense(transaction) else { return false }

        if let pfc = transaction.personalFinanceCategory {
            let primary = pfc.primary.uppercased()
            let detailed = pfc.detailed.uppercased()

            // Always essential primaries
            if ["RENT_AND_UTILITIES", "LOAN_PAYMENTS", "BANK_FEES",
                "GOVERNMENT_AND_NON_PROFIT", "MEDICAL"].contains(primary) {
                return true
            }

            // Food: Groceries = essential, Restaurants = discretionary
            if primary == "FOOD_AND_DRINK" {
                return ["GROCERIES", "SUPERMARKET", "WAREHOUSE_CLUB"]
                    .contains(where: { detailed.contains($0) })
            }

            // Transportation: Daily transit = essential, Travel = discretionary
            if primary == "TRANSPORTATION" {
                return !["AIRLINE", "HOTEL", "VACATION", "CRUISE", "RESORT"]
                    .contains(where: { detailed.contains($0) })
            }

            // Travel is discretionary
            if primary == "TRAVEL" { return false }

            // Entertainment is discretionary
            if primary == "ENTERTAINMENT" { return false }

            // General merchandise: Check for essentials vs discretionary
            if primary == "GENERAL_MERCHANDISE" {
                return ["PHARMACY", "HEALTHCARE", "PET_FOOD"]
                    .contains(where: { detailed.contains($0) })
            }

            // General services: Childcare, education = essential; others = discretionary
            if primary == "GENERAL_SERVICES" {
                return ["CHILDCARE", "EDUCATION", "VETERINARY", "AUTOMOTIVE"]
                    .contains(where: { detailed.contains($0) })
            }

            // Home improvement - consider essential (maintenance)
            if primary == "HOME_IMPROVEMENT" { return true }

            // Insurance anywhere in detailed = essential
            if detailed.contains("INSURANCE") { return true }

            // Default to discretionary for uncategorized
            return false
        }

        // Fallback: keyword matching for essential merchants
        let nameLower = transaction.name.lowercased()
        let essentialKeywords = [
            "rent", "mortgage", "hoa", "property management",
            "electric", "water", "gas bill", "pge", "con edison",
            "internet", "comcast", "verizon", "at&t", "spectrum",
            "grocery", "safeway", "kroger", "publix", "whole foods", "trader joe",
            "walmart", "target", "costco", "aldi",
            "pharmacy", "cvs", "walgreens", "medical", "doctor", "hospital",
            "dental", "vision", "healthcare", "clinic",
            "insurance", "geico", "progressive", "state farm",
            "gas station", "shell", "chevron", "exxon",
            "parking", "transit", "metro", "toll"
        ]

        return essentialKeywords.contains(where: { nameLower.contains($0) })
    }

    /// Determines if a transaction is discretionary spending (dining, entertainment, shopping, subscriptions)
    static func isDiscretionarySpending(_ transaction: Transaction) -> Bool {
        // Must be an outflow that qualifies as an expense
        guard isEssentialExpense(transaction) else { return false }

        // If it's not essential, it's discretionary
        return !isEssentialSpending(transaction)
    }

    // MARK: - Cycle Spending Calculations

    /// Calculates total spending for a specific allocation bucket within a billing cycle
    static func spentThisCycle(
        for bucketType: AllocationBucketType,
        transactions: [Transaction],
        cycleStart: Date,
        cycleEnd: Date = Date()
    ) -> Double {
        let cycleTransactions = transactions.filter {
            $0.date >= cycleStart && $0.date <= cycleEnd && !$0.pending
        }

        switch bucketType {
        case .essentialSpending:
            return cycleTransactions
                .filter { isEssentialSpending($0) }
                .reduce(0) { $0 + abs($1.amount) }

        case .discretionarySpending:
            return cycleTransactions
                .filter { isDiscretionarySpending($0) }
                .reduce(0) { $0 + abs($1.amount) }

        case .emergencyFund, .investments, .debtPaydown:
            // These buckets use account balances, not transaction sums
            return 0
        }
    }

    /// Calculates daily burn rate for a spending bucket
    static func dailyBurnRate(
        for bucketType: AllocationBucketType,
        transactions: [Transaction],
        cycleStart: Date
    ) -> Double {
        let spent = spentThisCycle(
            for: bucketType,
            transactions: transactions,
            cycleStart: cycleStart
        )

        let daysElapsed = Calendar.current.dateComponents([.day], from: cycleStart, to: Date()).day ?? 1
        return spent / Double(max(1, daysElapsed))
    }

    /// Projects end-of-cycle spending based on current burn rate
    static func projectedCycleSpend(
        for bucketType: AllocationBucketType,
        transactions: [Transaction],
        cycleStart: Date,
        cycleEnd: Date
    ) -> Double {
        let burnRate = dailyBurnRate(
            for: bucketType,
            transactions: transactions,
            cycleStart: cycleStart
        )

        let totalDays = Calendar.current.dateComponents([.day], from: cycleStart, to: cycleEnd).day ?? 30
        return burnRate * Double(totalDays)
    }

    /// Gets detailed category breakdown for a bucket (used for off-track diagnosis)
    static func categoryBreakdown(
        for bucketType: AllocationBucketType,
        transactions: [Transaction],
        cycleStart: Date,
        cycleEnd: Date = Date()
    ) -> [(category: String, amount: Double)] {
        let cycleTransactions = transactions.filter {
            $0.date >= cycleStart && $0.date <= cycleEnd && !$0.pending
        }

        let relevantTransactions: [Transaction]
        switch bucketType {
        case .essentialSpending:
            relevantTransactions = cycleTransactions.filter { isEssentialSpending($0) }
        case .discretionarySpending:
            relevantTransactions = cycleTransactions.filter { isDiscretionarySpending($0) }
        default:
            return []
        }

        var breakdown: [String: Double] = [:]

        for transaction in relevantTransactions {
            let category: String
            if let pfc = transaction.personalFinanceCategory {
                category = pfc.detailed
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
            } else {
                category = transaction.category.first ?? "Other"
            }

            breakdown[category, default: 0] += abs(transaction.amount)
        }

        return breakdown
            .map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - Expense Categorization

    /// Categorizes essential expenses with confidence scoring
    static func categorizeEssentialExpenses(
        _ transactions: [Transaction],
        months: Int
    ) -> ExpenseBreakdown {
        guard months > 0 else { return .empty }

        var housing = 0.0
        var food = 0.0
        var transportation = 0.0
        var utilities = 0.0
        var insurance = 0.0
        var subscriptions = 0.0
        var healthcare = 0.0
        var other = 0.0
        var highConfidenceCount = 0
        var totalCount = 0

        for transaction in transactions {
            let amount = abs(transaction.amount)
            totalCount += 1

            // Use PFC if available
            if let pfc = transaction.personalFinanceCategory {
                if pfc.confidenceLevel == .high || pfc.confidenceLevel == .veryHigh {
                    highConfidenceCount += 1
                }

                let primary = pfc.primary.uppercased()
                let detailed = pfc.detailed.uppercased()

                switch primary {
                case "RENT_AND_UTILITIES":
                    if detailed.contains("RENT") || detailed.contains("MORTGAGE") {
                        housing += amount
                    } else {
                        utilities += amount
                    }

                case "FOOD_AND_DRINK":
                    food += amount

                case "TRANSPORTATION", "TRAVEL":
                    transportation += amount

                case "HOME_IMPROVEMENT":
                    housing += amount

                case "MEDICAL":
                    if detailed.contains("INSURANCE") {
                        insurance += amount
                    } else {
                        healthcare += amount
                    }

                case "ENTERTAINMENT", "GENERAL_SERVICES":
                    if detailed.contains("SUBSCRIPTION") || detailed.contains("STREAMING") ||
                       detailed.contains("MUSIC") || detailed.contains("VIDEO") ||
                       detailed.contains("MEMBERSHIP") || detailed.contains("GYM") {
                        subscriptions += amount
                    } else {
                        other += amount
                    }

                case "LOAN_PAYMENTS", "BANK_FEES", "GOVERNMENT_AND_NON_PROFIT", "GENERAL_MERCHANDISE":
                    other += amount

                default:
                    other += amount
                }
            } else {
                // Fallback to legacy keyword matching
                let categoryString = transaction.category.joined(separator: " ").lowercased()
                let nameLower = transaction.name.lowercased()

                if categoryString.contains("rent") || categoryString.contains("mortgage") ||
                   categoryString.contains("housing") {
                    housing += amount
                } else if categoryString.contains("groceries") || categoryString.contains("food") ||
                          categoryString.contains("restaurant") || categoryString.contains("dining") {
                    food += amount
                } else if categoryString.contains("gas") || categoryString.contains("uber") ||
                          categoryString.contains("lyft") || categoryString.contains("transit") ||
                          categoryString.contains("parking") || categoryString.contains("auto") {
                    transportation += amount
                } else if categoryString.contains("electric") || categoryString.contains("utility") ||
                          categoryString.contains("water") || categoryString.contains("internet") ||
                          categoryString.contains("phone") {
                    utilities += amount
                } else if categoryString.contains("insurance") {
                    insurance += amount
                } else if categoryString.contains("subscription") || nameLower.contains("netflix") ||
                          nameLower.contains("spotify") || nameLower.contains("gym") {
                    subscriptions += amount
                } else if categoryString.contains("medical") || categoryString.contains("pharmacy") ||
                          categoryString.contains("healthcare") {
                    healthcare += amount
                } else {
                    other += amount
                }
            }
        }

        let confidence = totalCount > 0 ? Double(highConfidenceCount) / Double(totalCount) : 0.5
        let divisor = Double(months)

        return ExpenseBreakdown(
            housing: housing / divisor,
            food: food / divisor,
            transportation: transportation / divisor,
            utilities: utilities / divisor,
            insurance: insurance / divisor,
            subscriptions: subscriptions / divisor,
            healthcare: healthcare / divisor,
            other: other / divisor,
            confidence: confidence
        )
    }

    // MARK: - Debt Calculation Helpers

    /// Calculates total minimum debt payments from accounts
    static func calculateDebtMinimums(accounts: [BankAccount]) -> Double {
        let debtAccounts = accounts.filter { $0.isCredit || $0.isLoan }
        return debtAccounts.reduce(0) { sum, account in
            sum + (account.minimumPayment ?? estimateMinimumPayment(for: account))
        }
    }

    /// Estimates minimum payment if not provided by Plaid
    private static func estimateMinimumPayment(for account: BankAccount) -> Double {
        guard let balance = account.currentBalance, balance > 0 else { return 0 }

        if account.isCredit {
            return max(balance * 0.025, 25)
        } else if account.isLoan {
            let subtype = account.subtype?.lowercased() ?? ""
            switch subtype {
            case _ where subtype.contains("student"):
                return balance / 120
            case _ where subtype.contains("auto"):
                return balance / 60
            case _ where subtype.contains("mortgage"):
                return (balance / 360) * 1.5
            case _ where subtype.contains("personal"):
                return balance / 36
            default:
                return balance * 0.015
            }
        }

        return 0
    }

    // MARK: - Category to Bucket Mapping

    /// Categorizes a transaction into a high-level bucket using Plaid's Personal Finance Category
    static func categorizeToBucket(
        amount: Double,
        category: [String],
        categoryId: String?,
        personalFinanceCategory: PersonalFinanceCategory? = nil,
        transaction: Transaction? = nil
    ) -> BucketCategory {
        // If we have the full transaction, use the new classification
        if let txn = transaction {
            if isActualIncome(txn) && !isInvestmentContribution(txn) {
                return .income
            }
            if isInvestmentContribution(txn) {
                return .invested
            }
            if isInternalTransfer(txn) {
                return .cash
            }
        }

        // Use PFC if available
        if let pfc = personalFinanceCategory {
            let bucket = mapPFCToBucket(pfc.primary, detailed: pfc.detailed, amount: amount)
            return bucket
        }

        // Fallback to category-based classification
        return legacyCategorizeToBucket(amount: amount, category: category, categoryId: categoryId)
    }

    /// Maps Plaid's Personal Finance Category to our 6 high-level buckets
    private static func mapPFCToBucket(_ primary: String, detailed: String, amount: Double) -> BucketCategory {
        let primaryUpper = primary.uppercased()

        switch primaryUpper {
        case "INCOME":
            return .income

        case "TRANSFER_IN":
            if detailed.uppercased().contains("ACCOUNT") {
                return .cash
            }
            return .income

        case "TRANSFER_OUT":
            if detailed.uppercased().contains("INVESTMENT") ||
               detailed.uppercased().contains("RETIREMENT") ||
               detailed.uppercased().contains("SAVINGS") {
                return .invested
            }
            if detailed.uppercased().contains("LOAN") ||
               detailed.uppercased().contains("CREDIT") {
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
            return amount < 0 ? .income : .expenses
        }
    }

    /// Legacy categorization using keyword matching (fallback)
    private static func legacyCategorizeToBucket(
        amount: Double,
        category: [String],
        categoryId: String?
    ) -> BucketCategory {
        // Check category for investment/transfer patterns FIRST
        if let primaryCategory = category.first?.uppercased() {
            if primaryCategory.contains("TRANSFER") {
                if primaryCategory.contains("INVESTMENT") ||
                   primaryCategory.contains("401K") ||
                   primaryCategory.contains("IRA") ||
                   primaryCategory.contains("RETIREMENT") {
                    return .invested
                }
            }
        }

        // Income transactions (negative amounts in Plaid = money in)
        // But NOT if it's a transfer
        if amount < 0 {
            if let primaryCategory = category.first?.uppercased() {
                if primaryCategory.contains("TRANSFER") {
                    return .invested
                }
            }
            return .income
        }

        // Debt payments
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

        return .expenses
    }

    // MARK: - Legacy Support (for backward compatibility)
    // MARK: - Category Detail Helpers

    static func expensesByCategory(from transactions: [Transaction]) -> [String: Double] {
        var breakdown: [String: Double] = [:]

        for transaction in transactions {
            guard isEssentialExpense(transaction) else { continue }
            let categoryName = transaction.category.first ?? "Uncategorized"
            breakdown[categoryName, default: 0] += transaction.amount
        }

        return breakdown
    }

    static func monthlyTrends(
        from transactions: [Transaction],
        bucket: BucketCategory
    ) -> [Date: Double] {
        var monthlyData: [Date: Double] = [:]
        let calendar = Calendar.current

        for transaction in transactions where transaction.bucketCategory == bucket {
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

    static func monthlyTrends(
        from transactions: [Transaction],
        filter: (Transaction) -> Bool
    ) -> [Date: Double] {
        var monthlyData: [Date: Double] = [:]
        let calendar = Calendar.current

        for transaction in transactions where filter(transaction) {
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            guard let monthStart = calendar.date(from: components) else { continue }
            monthlyData[monthStart, default: 0] += abs(transaction.amount)
        }

        return monthlyData
    }

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
            return "Monthly income minus essential expenses and minimum debt payments"
        }
    }
}

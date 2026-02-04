import Foundation

/// Complete financial snapshot combining flow and position
/// This is what gets displayed on the Analysis Complete screen
struct AnalysisSnapshot: Codable, Equatable {
    /// Monthly cash flow data (income, expenses, discretionary)
    let monthlyFlow: MonthlyFlow

    /// Current financial position (balances)
    let position: FinancialPosition

    /// Metadata about the analysis
    let metadata: AnalysisMetadata

    /// Convenience accessor for discretionary income
    var discretionaryIncome: Double {
        monthlyFlow.discretionaryIncome
    }

    /// Convenience accessor for total essential expenses
    var monthlyEssentialExpenses: Double {
        monthlyFlow.essentialExpenses
    }

    /// Whether this snapshot is ready for plan generation
    var isReadyForPlan: Bool {
        monthlyFlow.isPositive && metadata.transactionsAnalyzed > 0
    }

    // MARK: - Plan Compatibility Accessors

    /// Disposable income available for allocation
    var disposableIncome: Double {
        monthlyFlow.disposableIncome
    }

    /// Monthly income
    var monthlyIncome: Double {
        monthlyFlow.income
    }

    /// Total debt
    var totalDebt: Double {
        position.totalDebt
    }

    /// Total invested
    var totalInvested: Double {
        position.investmentBalances
    }

    /// Total cash available
    var totalCashAvailable: Double {
        position.emergencyCash
    }

    /// Emergency fund months
    var emergencyFundMonths: Double {
        position.emergencyFundMonths(monthlyExpenses: monthlyEssentialExpenses)
    }

    /// Net worth
    var netWorth: Double {
        position.netWorth
    }

    /// Monthly net income (income - expenses, before allocation)
    var monthlyNetIncome: Double {
        monthlyFlow.income - monthlyFlow.essentialExpenses
    }

    // MARK: - FinancialSummary Backward Compatibility

    /// Average monthly income (backward compatibility)
    var avgMonthlyIncome: Double {
        monthlyFlow.income
    }

    /// Average monthly expenses (backward compatibility)
    var avgMonthlyExpenses: Double {
        monthlyFlow.essentialExpenses
    }

    /// Amount available to allocate (deprecated - use disposableIncome)
    @available(*, deprecated, renamed: "disposableIncome")
    var availableToSpend: Double {
        monthlyFlow.disposableIncome
    }

    /// Alias for availableToSpend (deprecated)
    @available(*, deprecated, renamed: "disposableIncome")
    var toAllocate: Double {
        monthlyFlow.disposableIncome
    }

    /// Months analyzed (backward compatibility)
    var monthsAnalyzed: Int {
        metadata.monthsAnalyzed
    }

    /// Total transactions analyzed (backward compatibility)
    var totalTransactions: Int {
        metadata.transactionsAnalyzed
    }

    /// Last updated date (backward compatibility)
    var lastUpdated: Date {
        metadata.lastUpdated
    }

    /// Investment contributions per month (backward compatibility)
    var monthlyInvestmentContributions: Double {
        position.monthlyInvestmentContributions
    }

    /// BucketCategory value accessor (backward compatibility)
    func bucketValue(for category: BucketCategory) -> Double {
        switch category {
        case .income:
            return monthlyFlow.income
        case .expenses:
            return monthlyFlow.essentialExpenses
        case .debt:
            return position.totalDebt
        case .invested:
            return position.investmentBalances
        case .cash:
            return position.emergencyCash
        case .disposable:
            return monthlyFlow.disposableIncome
        case .excluded:
            return 0 // Excluded transactions don't contribute to any value
        }
    }

    // MARK: - Validation

    /// Whether financial snapshot is valid for algorithm
    var isValidForAllocation: Bool {
        monthlyFlow.disposableIncome > 0 &&
        metadata.overallConfidence >= 0.5
    }

    /// Validation error message if not valid
    var validationError: String? {
        if monthlyFlow.disposableIncome <= 0 {
            return "Your expenses exceed your income. Please review your numbers before we can create an allocation plan."
        }
        if metadata.overallConfidence < 0.5 {
            return "We couldn't confidently analyze your transactions. Please connect more accounts or review the classifications."
        }
        return nil
    }

    // MARK: - Empty State

    /// Empty snapshot for initialization/error states
    static var empty: AnalysisSnapshot {
        AnalysisSnapshot(
            monthlyFlow: .empty,
            position: .empty,
            metadata: AnalysisMetadata(
                monthsAnalyzed: 0,
                accountsConnected: 0,
                transactionsAnalyzed: 0,
                transactionsNeedingValidation: 0,
                overallConfidence: 0,
                lastUpdated: Date()
            )
        )
    }
}

/// Metadata about the analysis
struct AnalysisMetadata: Codable, Equatable {
    /// Number of months of transaction data analyzed
    let monthsAnalyzed: Int

    /// Number of accounts connected
    let accountsConnected: Int

    /// Total transactions analyzed
    let transactionsAnalyzed: Int

    /// Number of transactions needing user validation (low confidence)
    let transactionsNeedingValidation: Int

    /// Overall confidence in the analysis (0.0 - 1.0)
    let overallConfidence: Double

    /// When the analysis was last updated
    let lastUpdated: Date

    /// Whether user should review low-confidence transactions
    var needsValidationReview: Bool {
        transactionsNeedingValidation > 0
    }

    /// Validation completion percentage
    var validationProgress: Double {
        guard transactionsNeedingValidation > 0 else { return 100 }
        // This would be updated based on actual validation state
        return 0
    }

    /// Whether to show confidence warnings to user
    var shouldShowConfidenceWarning: Bool {
        overallConfidence < 0.85
    }

    /// Days since last update
    var daysSinceUpdate: Int {
        Calendar.current.dateComponents([.day], from: lastUpdated, to: Date()).day ?? 0
    }

    /// Whether data is stale (>7 days old)
    var isStale: Bool {
        daysSinceUpdate > 7
    }
}

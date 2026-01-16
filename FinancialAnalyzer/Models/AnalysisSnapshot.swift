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
}

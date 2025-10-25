import Foundation

/// Comprehensive financial health metrics calculated from transaction and account data
/// Customer-facing metrics focus on opportunity and progress, while backend metrics drive AI decisions
struct FinancialHealthMetrics: Codable {
    // MARK: - Customer-Facing Metrics

    /// Amount saved per month (income - expenses)
    let monthlySavings: Double

    /// Trend indicator for savings (increasing, stable, decreasing)
    let monthlySavingsTrend: TrendIndicator

    /// Number of months of essential expenses covered by current savings
    let emergencyFundMonthsCovered: Double

    /// Target emergency fund amount (6-12 months of essential expenses)
    let emergencyFundTarget: Double

    /// Average monthly income over analysis period
    let monthlyIncome: Double

    /// Income consistency level (stable, variable, inconsistent)
    let incomeStability: IncomeStabilityLevel

    /// Average monthly debt payments (credit cards, loans, mortgage)
    let monthlyDebtPayments: Double

    /// Estimated months until debt-free (nil if no debt or not calculable)
    let monthsToDebtFree: Int?

    /// Monthly discretionary spending (entertainment, dining, shopping, etc.)
    let discretionarySpending: Double

    /// Monthly essential spending (housing, groceries, utilities, transportation)
    let essentialSpending: Double

    /// Trend indicator for overall spending
    let spendingTrend: TrendIndicator

    // MARK: - Backend-Only Metrics (Not Shown to Customer)

    /// Overall financial health score (0-100) used by AI for recommendations
    /// NEVER display this to customers - used only for backend decision-making
    let healthScore: Double

    /// Savings rate as percentage of income (0.0 to 1.0)
    let savingsRate: Double

    /// Debt-to-income ratio as percentage (0.0 to 1.0+)
    let debtToIncomeRatio: Double

    // MARK: - Metadata

    /// When these metrics were calculated
    let calculatedAt: Date

    /// Number of months analyzed for calculations
    let analysisMonths: Int
}

// MARK: - Supporting Enums

/// Indicates trend direction for metrics
enum TrendIndicator: String, Codable {
    case increasing = "↑"
    case stable = "→"
    case decreasing = "↓"
}

/// Classifies income consistency over time
enum IncomeStabilityLevel: String, Codable {
    case stable        // Coefficient of variation < 15%
    case variable      // Coefficient of variation 15-30%
    case inconsistent  // Coefficient of variation > 30%

    var displayText: String {
        switch self {
        case .stable:
            return "Consistent"
        case .variable:
            return "Varies month to month"
        case .inconsistent:
            return "Fluctuates significantly"
        }
    }

    var explanation: String {
        switch self {
        case .stable:
            return "Your income is consistent, making budgeting predictable."
        case .variable:
            return "Your income varies, so we'll help you plan for fluctuations."
        case .inconsistent:
            return "Your income changes significantly, so we recommend a larger emergency fund."
        }
    }

    /// Recommended emergency fund coverage in months
    var recommendedEmergencyMonths: Int {
        switch self {
        case .stable:
            return 6
        case .variable:
            return 9
        case .inconsistent:
            return 12
        }
    }
}

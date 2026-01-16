import Foundation

/// Represents monthly cash flow (averages over analysis period)
/// This is FLOW data - what happens each month on average
struct MonthlyFlow: Codable, Equatable {
    /// Average monthly income from all sources
    let income: Double

    /// Average monthly essential expenses (housing, food, utilities, etc.)
    let essentialExpenses: Double

    /// Estimated minimum debt payments (credit cards, loans)
    let debtMinimums: Double

    /// Discretionary income available to allocate
    /// = income - essentialExpenses - debtMinimums
    var discretionaryIncome: Double {
        income - essentialExpenses - debtMinimums
    }

    /// Whether user has positive discretionary income
    var isPositive: Bool {
        discretionaryIncome > 0
    }

    /// Essential expenses as percentage of income
    var essentialExpensesPercentage: Double {
        guard income > 0 else { return 0 }
        return (essentialExpenses / income) * 100
    }

    /// Debt minimums as percentage of income
    var debtMinimumsPercentage: Double {
        guard income > 0 else { return 0 }
        return (debtMinimums / income) * 100
    }

    /// Discretionary income as percentage of income
    var discretionaryPercentage: Double {
        guard income > 0 else { return 0 }
        return (discretionaryIncome / income) * 100
    }
}

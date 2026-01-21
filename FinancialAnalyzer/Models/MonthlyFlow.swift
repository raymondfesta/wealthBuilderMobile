import Foundation

/// Represents monthly cash flow (averages over analysis period)
/// This is FLOW data - what happens each month on average
struct MonthlyFlow: Codable, Equatable {
    /// Average monthly income from all sources
    let income: Double

    /// Detailed breakdown of essential expenses by category (optional for backward compatibility)
    let expenseBreakdown: ExpenseBreakdown?

    /// Legacy essential expenses total (used when breakdown unavailable)
    private let _essentialExpenses: Double

    /// Estimated minimum debt payments (credit cards, loans)
    let debtMinimums: Double

    /// Average monthly essential expenses - uses breakdown total if available
    var essentialExpenses: Double {
        expenseBreakdown?.total ?? _essentialExpenses
    }

    /// Whether detailed expense breakdown is available
    var hasDetailedBreakdown: Bool {
        expenseBreakdown != nil
    }

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

    // MARK: - Initializers

    /// Full initializer with expense breakdown
    init(
        income: Double,
        expenseBreakdown: ExpenseBreakdown?,
        debtMinimums: Double
    ) {
        self.income = income
        self.expenseBreakdown = expenseBreakdown
        self._essentialExpenses = expenseBreakdown?.total ?? 0
        self.debtMinimums = debtMinimums
    }

    /// Legacy initializer without breakdown (for backward compatibility)
    init(
        income: Double,
        essentialExpenses: Double,
        debtMinimums: Double
    ) {
        self.income = income
        self.expenseBreakdown = nil
        self._essentialExpenses = essentialExpenses
        self.debtMinimums = debtMinimums
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case income
        case expenseBreakdown
        case _essentialExpenses = "essentialExpenses"
        case debtMinimums
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        income = try container.decode(Double.self, forKey: .income)
        expenseBreakdown = try container.decodeIfPresent(ExpenseBreakdown.self, forKey: .expenseBreakdown)
        _essentialExpenses = try container.decode(Double.self, forKey: ._essentialExpenses)
        debtMinimums = try container.decode(Double.self, forKey: .debtMinimums)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(income, forKey: .income)
        try container.encodeIfPresent(expenseBreakdown, forKey: .expenseBreakdown)
        try container.encode(_essentialExpenses, forKey: ._essentialExpenses)
        try container.encode(debtMinimums, forKey: .debtMinimums)
    }

    // MARK: - Equatable

    static func == (lhs: MonthlyFlow, rhs: MonthlyFlow) -> Bool {
        lhs.income == rhs.income &&
        lhs.expenseBreakdown == rhs.expenseBreakdown &&
        lhs._essentialExpenses == rhs._essentialExpenses &&
        lhs.debtMinimums == rhs.debtMinimums
    }
}

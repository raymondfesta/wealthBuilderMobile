import Foundation

/// Represents point-in-time financial position (balances)
/// This is POSITION data - current state, not monthly flow
struct FinancialPosition: Codable, Equatable {
    /// Total liquid cash in depository accounts (checking, savings)
    let emergencyCash: Double

    /// All debt accounts with balances
    let debtBalances: [DebtAccount]

    /// Total balance in investment and retirement accounts
    let investmentBalances: Double

    /// Current monthly investment contributions (detected from transaction patterns)
    let monthlyInvestmentContributions: Double

    // MARK: - Computed Properties

    /// Total debt across all accounts
    var totalDebt: Double {
        debtBalances.reduce(0) { $0 + $1.balance }
    }

    /// Total minimum payments required monthly
    var totalMinimumPayments: Double {
        debtBalances.reduce(0) { $0 + $1.minimumPayment }
    }

    /// Weighted average APR across all debt
    var weightedAverageAPR: Double {
        guard totalDebt > 0 else { return 0 }
        let weightedSum = debtBalances.reduce(0.0) { sum, debt in
            sum + (debt.balance * debt.apr)
        }
        return weightedSum / totalDebt
    }

    /// Whether user has high-interest debt (>15% APR)
    var hasHighInterestDebt: Bool {
        debtBalances.contains { $0.apr > 0.15 }
    }

    /// Highest APR debt account
    var highestAPRDebt: DebtAccount? {
        debtBalances.max(by: { $0.apr < $1.apr })
    }

    /// Calculate emergency fund coverage in months
    /// - Parameter monthlyExpenses: Monthly essential expenses
    /// - Returns: Number of months of expenses covered by emergency cash
    func emergencyFundMonths(monthlyExpenses: Double) -> Double {
        guard monthlyExpenses > 0 else { return 0 }
        return emergencyCash / monthlyExpenses
    }

    /// Calculate net worth
    var netWorth: Double {
        emergencyCash + investmentBalances - totalDebt
    }

    /// Whether user has debt
    var hasDebt: Bool {
        totalDebt > 0
    }

    /// Whether user is actively investing
    var isInvesting: Bool {
        monthlyInvestmentContributions > 0
    }

    /// Empty position for initialization/error states
    static var empty: FinancialPosition {
        FinancialPosition(
            emergencyCash: 0,
            debtBalances: [],
            investmentBalances: 0,
            monthlyInvestmentContributions: 0
        )
    }

    // MARK: - Backward Compatibility

    /// Convenience initializer with just total debt (backward compatibility)
    init(
        emergencyCash: Double,
        totalDebt: Double,
        investmentBalances: Double,
        monthlyInvestmentContributions: Double
    ) {
        self.emergencyCash = emergencyCash
        // Create single "aggregate" debt account for legacy callers
        if totalDebt > 0 {
            self.debtBalances = [
                DebtAccount(
                    id: "aggregate",
                    name: "Total Debt",
                    type: .other,
                    balance: totalDebt,
                    apr: 0.10, // Estimate 10% average
                    minimumPayment: totalDebt * 0.02 // Estimate 2% minimum
                )
            ]
        } else {
            self.debtBalances = []
        }
        self.investmentBalances = investmentBalances
        self.monthlyInvestmentContributions = monthlyInvestmentContributions
    }

    /// Standard initializer with debt accounts array
    init(
        emergencyCash: Double,
        debtBalances: [DebtAccount],
        investmentBalances: Double,
        monthlyInvestmentContributions: Double
    ) {
        self.emergencyCash = emergencyCash
        self.debtBalances = debtBalances
        self.investmentBalances = investmentBalances
        self.monthlyInvestmentContributions = monthlyInvestmentContributions
    }
}

// MARK: - Debt Account

/// Individual debt account
struct DebtAccount: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let type: DebtType
    let balance: Double
    let apr: Double
    let minimumPayment: Double

    /// Monthly interest cost
    var monthlyInterestCost: Double {
        (balance * apr) / 12.0
    }

    /// Whether this is high-interest debt (>15% APR)
    var isHighInterest: Bool {
        apr > 0.15
    }

    /// Estimated months to payoff at minimum payments
    var monthsToPayoffAtMinimum: Int? {
        guard minimumPayment > monthlyInterestCost else { return nil }
        let principalPayment = minimumPayment - monthlyInterestCost
        guard principalPayment > 0 else { return nil }
        return Int(ceil(balance / principalPayment))
    }

    /// Create from BankAccount (for credit/loan accounts)
    init(from account: BankAccount) {
        self.id = account.id
        self.name = account.name
        self.type = DebtType(from: account.subtype ?? account.type)
        self.balance = abs(account.currentBalance ?? 0)
        self.apr = account.apr ?? Self.defaultAPR(for: DebtType(from: account.subtype ?? account.type))
        self.minimumPayment = account.minimumPayment ?? Self.estimateMinimumPayment(
            balance: abs(account.currentBalance ?? 0),
            type: DebtType(from: account.subtype ?? account.type)
        )
    }

    /// Standard initializer
    init(id: String, name: String, type: DebtType, balance: Double, apr: Double, minimumPayment: Double) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.apr = apr
        self.minimumPayment = minimumPayment
    }

    /// Estimate minimum payment when not provided by Plaid
    static func estimateMinimumPayment(balance: Double, type: DebtType) -> Double {
        switch type {
        case .creditCard:
            // Credit cards: typically 2-3% of balance, minimum $25
            return max(balance * 0.025, 25)
        case .studentLoan:
            // Student loans: estimate based on standard 10-year repayment
            return balance / 120
        case .autoLoan:
            // Auto loans: estimate based on 5-year term
            return balance / 60
        case .personalLoan:
            // Personal loans: estimate based on 3-year term
            return balance / 36
        case .mortgage:
            // Mortgage: estimate based on 30-year term + rough interest
            return (balance / 360) * 1.5
        case .other:
            // Default: 2% of balance, minimum $25
            return max(balance * 0.02, 25)
        }
    }

    /// Default APR when not provided by Plaid
    static func defaultAPR(for type: DebtType) -> Double {
        switch type {
        case .creditCard: return 0.20  // 20% average credit card APR
        case .studentLoan: return 0.06
        case .autoLoan: return 0.07
        case .personalLoan: return 0.12
        case .mortgage: return 0.07
        case .other: return 0.10
        }
    }
}

// MARK: - Debt Type

/// Types of debt accounts
enum DebtType: String, Codable {
    case creditCard = "credit_card"
    case studentLoan = "student_loan"
    case autoLoan = "auto_loan"
    case personalLoan = "personal_loan"
    case mortgage = "mortgage"
    case other = "other"

    init(from subtype: String) {
        switch subtype.lowercased() {
        case "credit card", "credit_card":
            self = .creditCard
        case "student", "student loan", "student_loan":
            self = .studentLoan
        case "auto", "auto loan", "auto_loan", "vehicle":
            self = .autoLoan
        case "personal", "personal loan", "personal_loan":
            self = .personalLoan
        case "mortgage", "home":
            self = .mortgage
        default:
            self = .other
        }
    }

    var displayName: String {
        switch self {
        case .creditCard: return "Credit Card"
        case .studentLoan: return "Student Loan"
        case .autoLoan: return "Auto Loan"
        case .personalLoan: return "Personal Loan"
        case .mortgage: return "Mortgage"
        case .other: return "Other Debt"
        }
    }
}

import Foundation

/// Represents point-in-time financial position (balances)
/// This is POSITION data - current state, not monthly flow
struct FinancialPosition: Codable, Equatable {
    /// Total liquid cash in depository accounts (checking, savings)
    let emergencyCash: Double

    /// Total debt balance across all credit cards and loans
    let totalDebt: Double

    /// Total balance in investment and retirement accounts
    let investmentBalances: Double

    /// Current monthly investment contributions (detected from transaction patterns)
    let monthlyInvestmentContributions: Double

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
}

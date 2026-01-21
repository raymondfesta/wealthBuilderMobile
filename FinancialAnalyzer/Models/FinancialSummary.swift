import Foundation

struct FinancialSummary: Codable {
    // High-level buckets
    var avgMonthlyIncome: Double
    var avgMonthlyExpenses: Double
    var totalDebt: Double
    var totalInvested: Double
    var totalCashAvailable: Double
    var availableToSpend: Double

    /// Alias for availableToSpend - renamed for clarity
    /// This is the income available to allocate, not "spend"
    var toAllocate: Double {
        availableToSpend
    }

    // Investment contributions (tracked separately from expenses)
    var monthlyInvestmentContributions: Double

    // Supporting data
    var analysisStartDate: Date
    var analysisEndDate: Date
    var monthsAnalyzed: Int
    var totalTransactions: Int
    var lastUpdated: Date

    init(
        avgMonthlyIncome: Double = 0,
        avgMonthlyExpenses: Double = 0,
        totalDebt: Double = 0,
        totalInvested: Double = 0,
        totalCashAvailable: Double = 0,
        availableToSpend: Double = 0,
        monthlyInvestmentContributions: Double = 0,
        analysisStartDate: Date = Date(),
        analysisEndDate: Date = Date(),
        monthsAnalyzed: Int = 0,
        totalTransactions: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.avgMonthlyIncome = avgMonthlyIncome
        self.avgMonthlyExpenses = avgMonthlyExpenses
        self.totalDebt = totalDebt
        self.totalInvested = totalInvested
        self.totalCashAvailable = totalCashAvailable
        self.availableToSpend = availableToSpend
        self.monthlyInvestmentContributions = monthlyInvestmentContributions
        self.analysisStartDate = analysisStartDate
        self.analysisEndDate = analysisEndDate
        self.monthsAnalyzed = monthsAnalyzed
        self.totalTransactions = totalTransactions
        self.lastUpdated = lastUpdated
    }

    func bucketValue(for category: BucketCategory) -> Double {
        switch category {
        case .income:
            return avgMonthlyIncome
        case .expenses:
            return avgMonthlyExpenses
        case .debt:
            return totalDebt
        case .invested:
            return totalInvested
        case .cash:
            return totalCashAvailable
        case .disposable:
            return toAllocate
        }
    }

    var netWorth: Double {
        return totalCashAvailable + totalInvested - totalDebt
    }

    var monthlyNetIncome: Double {
        return avgMonthlyIncome - avgMonthlyExpenses
    }
}

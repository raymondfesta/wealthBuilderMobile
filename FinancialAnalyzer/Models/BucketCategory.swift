import Foundation

enum BucketCategory: String, Codable, CaseIterable {
    case income = "Avg Monthly Income"
    case expenses = "Avg Monthly Expenses"
    case debt = "Total Debt"
    case invested = "Total Invested"
    case cash = "Total Cash Available"
    case disposable = "Available to Spend"

    var description: String {
        switch self {
        case .income:
            return "Money coming in from salary, freelance, investments, etc."
        case .expenses:
            return "Money going out for bills, shopping, entertainment, etc."
        case .debt:
            return "Outstanding loan and credit card balances"
        case .invested:
            return "Stocks, bonds, retirement accounts, and other investments"
        case .cash:
            return "Available cash in checking and savings accounts"
        case .disposable:
            return "Income minus expenses and debt obligations"
        }
    }

    var iconName: String {
        switch self {
        case .income:
            return "arrow.down.circle.fill"
        case .expenses:
            return "arrow.up.circle.fill"
        case .debt:
            return "creditcard.fill"
        case .invested:
            return "chart.line.uptrend.xyaxis"
        case .cash:
            return "dollarsign.circle.fill"
        case .disposable:
            return "banknote.fill"
        }
    }

    var color: String {
        switch self {
        case .income:
            return "green"
        case .expenses:
            return "red"
        case .debt:
            return "orange"
        case .invested:
            return "blue"
        case .cash:
            return "mint"
        case .disposable:
            return "purple"
        }
    }
}

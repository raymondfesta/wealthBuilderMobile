import Foundation
import SwiftUI

enum BucketCategory: String, Codable, CaseIterable {
    case income = "Avg Monthly Income"
    case expenses = "Avg Monthly Expenses"
    case debt = "Total Debt"
    case invested = "Total Invested"
    case cash = "Total Cash Available"
    case disposable = "Disposable Income"
    case excluded = "Excluded"

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
            return "Income available to allocate after essential expenses and debt minimums"
        case .excluded:
            return "Transfers, refunds, or one-time items excluded from analysis"
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
        case .excluded:
            return "eye.slash"
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
        case .excluded:
            return "gray"
        }
    }

    /// Design system color for dark theme
    var designColor: Color {
        switch self {
        case .income:
            return DesignTokens.Colors.progressGreen
        case .expenses:
            return DesignTokens.Colors.opportunityOrange  // Encouraging, not punishing
        case .debt:
            return DesignTokens.Colors.opportunityOrange
        case .invested:
            return DesignTokens.Colors.wealthPurple
        case .cash:
            return DesignTokens.Colors.protectionMint
        case .disposable:
            return DesignTokens.Colors.accentPrimary
        case .excluded:
            return Color.secondary
        }
    }

    /// Categories that users can select when correcting a transaction
    /// Excludes computed categories like .disposable
    static var userSelectableCases: [BucketCategory] {
        [.income, .expenses, .debt, .invested, .cash, .excluded]
    }
}

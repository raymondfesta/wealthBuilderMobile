import Foundation

/// Detailed breakdown of essential monthly expenses by category
/// Used to show users exactly where their money is going
struct ExpenseBreakdown: Codable, Equatable {
    /// Housing costs (rent, mortgage, property tax, HOA)
    let housing: Double

    /// Food expenses (groceries, dining out)
    let food: Double

    /// Transportation costs (gas, car payment, transit, parking, rideshare)
    let transportation: Double

    /// Utility bills (electric, gas, water, internet, phone)
    let utilities: Double

    /// Insurance premiums (health, life, home/renters - excludes auto which is in transportation)
    let insurance: Double

    /// Recurring subscriptions (streaming, gym, software, memberships)
    let subscriptions: Double

    /// Healthcare expenses (medical, dental, prescriptions)
    let healthcare: Double

    /// Other essential expenses that don't fit above categories
    let other: Double

    /// Confidence in categorization accuracy (0.0-1.0)
    /// Based on Plaid PFC confidence levels of underlying transactions
    let confidence: Double

    /// Total of all expense categories
    var total: Double {
        housing + food + transportation + utilities + insurance + subscriptions + healthcare + other
    }

    /// Breakdown as array for UI iteration
    var categories: [ExpenseCategory] {
        [
            ExpenseCategory(name: "Housing", amount: housing, icon: "house.fill", color: "blue"),
            ExpenseCategory(name: "Food", amount: food, icon: "cart.fill", color: "green"),
            ExpenseCategory(name: "Transportation", amount: transportation, icon: "car.fill", color: "orange"),
            ExpenseCategory(name: "Utilities", amount: utilities, icon: "bolt.fill", color: "yellow"),
            ExpenseCategory(name: "Insurance", amount: insurance, icon: "shield.fill", color: "purple"),
            ExpenseCategory(name: "Subscriptions", amount: subscriptions, icon: "repeat.circle.fill", color: "pink"),
            ExpenseCategory(name: "Healthcare", amount: healthcare, icon: "heart.fill", color: "red"),
            ExpenseCategory(name: "Other", amount: other, icon: "ellipsis.circle.fill", color: "gray")
        ].filter { $0.amount > 0 }
    }

    /// Non-zero category count for display
    var categoryCount: Int {
        categories.count
    }

    /// Confidence level for UI display
    var confidenceLevel: ExpenseConfidenceLevel {
        if confidence >= 0.85 { return .high }
        if confidence >= 0.70 { return .medium }
        return .low
    }

    /// Empty breakdown for edge cases
    static var empty: ExpenseBreakdown {
        ExpenseBreakdown(
            housing: 0, food: 0, transportation: 0, utilities: 0,
            insurance: 0, subscriptions: 0, healthcare: 0, other: 0, confidence: 0
        )
    }
}

/// Individual expense category for UI display
struct ExpenseCategory: Identifiable {
    var id: String { name }
    let name: String
    let amount: Double
    let icon: String
    let color: String

    /// Percentage of total expenses (requires total to be passed in)
    func percentage(of total: Double) -> Double {
        guard total > 0 else { return 0 }
        return (amount / total) * 100
    }
}

/// Confidence level for expense categorization
enum ExpenseConfidenceLevel: String, Codable {
    case high
    case medium
    case low

    /// System color name for SwiftUI
    var systemColor: String {
        switch self {
        case .high: return "green"
        case .medium: return "orange"
        case .low: return "red"
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "xmark.circle.fill"
        }
    }

    /// User-friendly message explaining confidence level
    var message: String {
        switch self {
        case .high:
            return "Highly confident in these classifications based on clear transaction patterns."
        case .medium:
            return "Some transactions were difficult to classify. Review and adjust if needed."
        case .low:
            return "Many transactions were ambiguous. Please review carefully."
        }
    }

    /// Whether to show review prompt
    var shouldPromptReview: Bool {
        self != .high
    }
}

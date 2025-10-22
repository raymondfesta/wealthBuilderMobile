import Foundation
import Combine

/// Represents an allocation bucket for distributing income across financial priorities
@MainActor
final class AllocationBucket: Identifiable, ObservableObject {
    @Published var id: String
    @Published var type: AllocationBucketType
    @Published var allocatedAmount: Double // Dollar amount allocated
    @Published var percentageOfIncome: Double // Percentage (0-100)
    @Published var linkedBudgetCategories: [String] // Category names from budgets
    @Published var explanation: String // AI-generated explanation
    @Published var targetAmount: Double? // For emergency fund only
    @Published var monthsToTarget: Int? // For emergency fund only
    @Published var createdAt: Date
    @Published var updatedAt: Date

    // Computed property to calculate current balance from linked budgets
    // This would be calculated by summing remaining amounts from linked Budget objects
    var currentBalance: Double {
        // This will be calculated by BudgetManager based on linked budgets
        // For now, return 0 - the ViewModel will need to calculate this
        return 0
    }

    var displayName: String {
        type.displayName
    }

    var icon: String {
        type.icon
    }

    var color: String {
        type.color
    }

    var description: String {
        type.description
    }

    /// Indicates whether this bucket's allocation can be modified by the user
    var isModifiable: Bool {
        // Essential Spending is calculated from actual data and cannot be modified
        return type != .essentialSpending
    }

    init(
        id: String = UUID().uuidString,
        type: AllocationBucketType,
        allocatedAmount: Double,
        percentageOfIncome: Double,
        linkedCategories: [String] = [],
        explanation: String,
        targetAmount: Double? = nil,
        monthsToTarget: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.allocatedAmount = allocatedAmount
        self.percentageOfIncome = percentageOfIncome
        self.linkedBudgetCategories = linkedCategories
        self.explanation = explanation
        self.targetAmount = targetAmount
        self.monthsToTarget = monthsToTarget
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Updates the allocation amount and percentage
    func updateAllocation(amount: Double, percentage: Double) {
        self.allocatedAmount = amount
        self.percentageOfIncome = percentage
        self.updatedAt = Date()
    }
}

// MARK: - Codable conformance
extension AllocationBucket: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case allocatedAmount
        case percentageOfIncome
        case linkedBudgetCategories
        case explanation
        case targetAmount
        case monthsToTarget
        case createdAt
        case updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(allocatedAmount, forKey: .allocatedAmount)
        try container.encode(percentageOfIncome, forKey: .percentageOfIncome)
        try container.encode(linkedBudgetCategories, forKey: .linkedBudgetCategories)
        try container.encode(explanation, forKey: .explanation)
        try container.encodeIfPresent(targetAmount, forKey: .targetAmount)
        try container.encodeIfPresent(monthsToTarget, forKey: .monthsToTarget)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let type = try container.decode(AllocationBucketType.self, forKey: .type)
        let allocatedAmount = try container.decode(Double.self, forKey: .allocatedAmount)
        let percentageOfIncome = try container.decode(Double.self, forKey: .percentageOfIncome)
        let linkedCategories = try container.decode([String].self, forKey: .linkedBudgetCategories)
        let explanation = try container.decode(String.self, forKey: .explanation)
        let targetAmount = try? container.decode(Double.self, forKey: .targetAmount)
        let monthsToTarget = try? container.decode(Int.self, forKey: .monthsToTarget)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        self.init(
            id: id,
            type: type,
            allocatedAmount: allocatedAmount,
            percentageOfIncome: percentageOfIncome,
            linkedCategories: linkedCategories,
            explanation: explanation,
            targetAmount: targetAmount,
            monthsToTarget: monthsToTarget,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Allocation Bucket Type

enum AllocationBucketType: String, Codable, CaseIterable {
    case essentialSpending = "Essential Spending"
    case emergencyFund = "Emergency Fund"
    case discretionarySpending = "Discretionary Spending"
    case investments = "Investments"

    var displayName: String {
        self.rawValue
    }

    var icon: String {
        switch self {
        case .essentialSpending:
            return "house.fill"
        case .emergencyFund:
            return "cross.case.fill"
        case .discretionarySpending:
            return "cart.fill"
        case .investments:
            return "chart.line.uptrend.xyaxis"
        }
    }

    var color: String {
        switch self {
        case .essentialSpending:
            return "#007AFF" // Blue
        case .emergencyFund:
            return "#FF3B30" // Red
        case .discretionarySpending:
            return "#FF9500" // Orange
        case .investments:
            return "#34C759" // Green
        }
    }

    var description: String {
        switch self {
        case .essentialSpending:
            return "Core living expenses including housing, utilities, groceries, transportation, and healthcare"
        case .emergencyFund:
            return "Safety net for unexpected expenses. Target: 3-6 months of essential expenses"
        case .discretionarySpending:
            return "Non-essential spending on entertainment, dining out, shopping, and hobbies"
        case .investments:
            return "Long-term wealth building through retirement accounts, stocks, and other investments"
        }
    }

    /// Default category mappings for each allocation type
    var defaultCategoryMappings: [String] {
        switch self {
        case .essentialSpending:
            return [
                "Groceries",
                "Rent",
                "Utilities",
                "Transportation",
                "Insurance",
                "Healthcare",
                "Childcare",
                "Debt Payments"
            ]
        case .emergencyFund:
            return [] // Virtual bucket - not tied to spending categories
        case .discretionarySpending:
            return [
                "Entertainment",
                "Dining",
                "Shopping",
                "Travel",
                "Hobbies",
                "Subscriptions"
            ]
        case .investments:
            return [] // Virtual bucket - not tied to spending categories
        }
    }
}

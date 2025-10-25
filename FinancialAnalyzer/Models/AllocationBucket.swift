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
    @Published var changeFromOriginal: Double = 0 // Track change for visual indicators
    @Published var isLocked: Bool = false // Whether this bucket is protected from auto-adjustment

    /// Recommended minimum allocation as a percentage of income
    var recommendedMinimumPercentage: Double {
        switch type {
        case .essentialSpending:
            return 0 // Cannot be modified, no minimum needed
        case .emergencyFund:
            return 10 // Minimum 10% for basic safety net
        case .discretionarySpending:
            return 0 // Can be zero if needed
        case .investments:
            return 5 // Minimum 5% for wealth building
        }
    }

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

    /// Validates discretionary spending limits (35% warning, 50% hard limit)
    func validateDiscretionarySpending(monthlyIncome: Double) -> DiscretionarySpendingValidation {
        guard type == .discretionarySpending, monthlyIncome > 0 else {
            return .valid
        }

        let percentage = (allocatedAmount / monthlyIncome) * 100

        if percentage >= 50 {
            return .hardLimit(currentPercentage: percentage)
        } else if percentage >= 35 {
            return .warning(currentPercentage: percentage)
        } else {
            return .valid
        }
    }

    /// Calculates the effective duration (in months) that the Emergency Fund target represents
    /// Based on current target amount and essential spending
    func calculateEffectiveDuration(essentialSpending: Double) -> Int {
        guard type == .emergencyFund, let target = targetAmount, essentialSpending > 0 else {
            return 6 // Default to 6 months if not applicable
        }

        let months = Int(round(target / essentialSpending))

        // Map to closest valid option (3, 6, or 12 months)
        if months <= 4 {
            return 3
        } else if months <= 9 {
            return 6
        } else {
            return 12
        }
    }

    /// Calculates the maximum safe allocation for this bucket given income and other buckets
    /// Returns the dollar amount that represents the safe maximum
    func getMaxSafeAllocation(monthlyIncome: Double, otherBuckets: [AllocationBucket]) -> Double {
        guard monthlyIncome > 0 else { return 0 }

        // Calculate minimum required for other buckets
        var minimumForOthers: Double = 0
        for bucket in otherBuckets {
            if bucket.id != self.id {
                let minPercentage = bucket.recommendedMinimumPercentage
                minimumForOthers += (monthlyIncome * minPercentage / 100)
            }
        }

        // Maximum for this bucket is income minus minimums for others
        let maximum = monthlyIncome - minimumForOthers

        // Apply type-specific hard limits
        switch type {
        case .discretionarySpending:
            // Hard limit of 50% for discretionary
            return min(maximum, monthlyIncome * 0.50)
        case .essentialSpending:
            // Essential spending is locked and calculated, but return current value
            return allocatedAmount
        case .emergencyFund, .investments:
            // No hard upper limit beyond what's left after minimums
            return max(0, maximum)
        }
    }

    /// Returns the recommended minimum allocation amount in dollars
    func getRecommendedMinimum(monthlyIncome: Double) -> Double {
        return monthlyIncome * recommendedMinimumPercentage / 100
    }

    // MARK: - Initializer

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

    /// Sets the original amount baseline for change tracking
    func setOriginalAmount(_ amount: Double) {
        self.changeFromOriginal = 0
    }

    /// Updates the change indicator
    func updateChange(from originalAmount: Double) {
        self.changeFromOriginal = self.allocatedAmount - originalAmount
    }
}

// MARK: - Discretionary Spending Validation

enum DiscretionarySpendingValidation {
    case valid
    case warning(currentPercentage: Double)
    case hardLimit(currentPercentage: Double)

    var isValid: Bool {
        if case .hardLimit = self {
            return false
        }
        return true
    }

    var message: String {
        switch self {
        case .valid:
            return ""
        case .warning(let percentage):
            return "⚠️ Discretionary spending is at \(Int(percentage))%. Consider keeping it below 35% for better financial health."
        case .hardLimit(let percentage):
            return "🚫 Discretionary spending limit exceeded (\(Int(percentage))%). Please reduce to 50% or less of your income."
        }
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
        case changeFromOriginal
        case isLocked
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
        try container.encode(changeFromOriginal, forKey: .changeFromOriginal)
        try container.encode(isLocked, forKey: .isLocked)
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
        let changeFromOriginal = (try? container.decode(Double.self, forKey: .changeFromOriginal)) ?? 0
        let isLocked = (try? container.decode(Bool.self, forKey: .isLocked)) ?? false

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
        self.changeFromOriginal = changeFromOriginal
        self.isLocked = isLocked
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

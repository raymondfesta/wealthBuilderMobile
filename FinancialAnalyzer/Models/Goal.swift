import Foundation

/// Represents a financial goal (emergency fund, vacation, debt payoff, etc.)
final class Goal: Identifiable, Codable {
    var id: String
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: Date?
    var goalType: GoalType
    var priority: GoalPriority
    var iconName: String
    var colorHex: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var notes: String?

    // Computed properties
    var remaining: Double {
        return max(targetAmount - currentAmount, 0)
    }

    var percentComplete: Double {
        guard targetAmount > 0 else { return 0 }
        return min((currentAmount / targetAmount) * 100, 100)
    }

    var isComplete: Bool {
        return currentAmount >= targetAmount
    }

    var monthsRemaining: Int? {
        guard let targetDate = targetDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: Date(), to: targetDate)
        return max(components.month ?? 0, 0)
    }

    var suggestedMonthlyContribution: Double? {
        guard let months = monthsRemaining, months > 0 else { return nil }
        return remaining / Double(months)
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        targetDate: Date? = nil,
        goalType: GoalType = .other,
        priority: GoalPriority = .medium,
        iconName: String = "target",
        colorHex: String = "#007AFF",
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.goalType = goalType
        self.priority = priority
        self.iconName = iconName
        self.colorHex = colorHex
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notes = notes
    }

    /// Adds money to the goal
    func contribute(_ amount: Double) {
        currentAmount += amount
        updatedAt = Date()
    }

    /// Withdraws money from the goal
    func withdraw(_ amount: Double) {
        currentAmount = max(currentAmount - amount, 0)
        updatedAt = Date()
    }

    /// Returns a progress status message
    func progressMessage() -> String {
        if isComplete {
            return "Goal completed! 🎉"
        }

        let percent = Int(percentComplete)
        if let months = monthsRemaining, months > 0 {
            return "\(percent)% complete • \(months) months remaining"
        } else if let _ = targetDate {
            return "\(percent)% complete • Past target date"
        } else {
            return "\(percent)% complete"
        }
    }
}

enum GoalType: String, Codable, CaseIterable {
    case emergencyFund = "Emergency Fund"
    case vacation = "Vacation"
    case debtPayoff = "Debt Payoff"
    case homeDownPayment = "Home Down Payment"
    case carPurchase = "Car Purchase"
    case education = "Education"
    case retirement = "Retirement"
    case investment = "Investment"
    case wedding = "Wedding"
    case other = "Other"

    var defaultIcon: String {
        switch self {
        case .emergencyFund:
            return "cross.case.fill"
        case .vacation:
            return "airplane"
        case .debtPayoff:
            return "creditcard.fill"
        case .homeDownPayment:
            return "house.fill"
        case .carPurchase:
            return "car.fill"
        case .education:
            return "graduationcap.fill"
        case .retirement:
            return "chart.line.uptrend.xyaxis"
        case .investment:
            return "dollarsign.circle.fill"
        case .wedding:
            return "heart.fill"
        case .other:
            return "target"
        }
    }

    var defaultColor: String {
        switch self {
        case .emergencyFund:
            return "#FF3B30" // Red
        case .vacation:
            return "#FF9500" // Orange
        case .debtPayoff:
            return "#FF2D55" // Pink
        case .homeDownPayment:
            return "#5856D6" // Purple
        case .carPurchase:
            return "#007AFF" // Blue
        case .education:
            return "#34C759" // Green
        case .retirement:
            return "#5AC8FA" // Light Blue
        case .investment:
            return "#32ADE6" // Teal
        case .wedding:
            return "#FF2D55" // Pink
        case .other:
            return "#8E8E93" // Gray
        }
    }

    var description: String {
        switch self {
        case .emergencyFund:
            return "Financial safety net for unexpected expenses"
        case .vacation:
            return "Save for your dream vacation"
        case .debtPayoff:
            return "Pay off loans and credit cards"
        case .homeDownPayment:
            return "Save for a down payment on a home"
        case .carPurchase:
            return "Buy or upgrade your vehicle"
        case .education:
            return "Fund education or training"
        case .retirement:
            return "Long-term retirement savings"
        case .investment:
            return "Build wealth through investments"
        case .wedding:
            return "Save for your special day"
        case .other:
            return "Custom financial goal"
        }
    }
}

enum GoalPriority: String, Codable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var sortOrder: Int {
        switch self {
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    var color: String {
        switch self {
        case .high:
            return "red"
        case .medium:
            return "orange"
        case .low:
            return "blue"
        }
    }
}

/// Helper to create common goal templates
struct GoalTemplate {
    static func emergencyFund(monthlyExpenses: Double) -> Goal {
        let targetAmount = monthlyExpenses * 6 // Standard 6-month emergency fund
        return Goal(
            name: "Emergency Fund",
            targetAmount: targetAmount,
            goalType: .emergencyFund,
            priority: .high,
            iconName: GoalType.emergencyFund.defaultIcon,
            colorHex: GoalType.emergencyFund.defaultColor,
            notes: "Recommended: 6 months of expenses for financial security"
        )
    }

    static func debtPayoff(totalDebt: Double, monthlyPayment: Double) -> Goal {
        let monthsToPayoff = totalDebt / monthlyPayment
        let targetDate = Calendar.current.date(byAdding: .month, value: Int(monthsToPayoff), to: Date())

        return Goal(
            name: "Pay Off Debt",
            targetAmount: totalDebt,
            targetDate: targetDate,
            goalType: .debtPayoff,
            priority: .high,
            iconName: GoalType.debtPayoff.defaultIcon,
            colorHex: GoalType.debtPayoff.defaultColor,
            notes: "Eliminate debt to improve financial health"
        )
    }

    static func vacation(targetAmount: Double, targetDate: Date) -> Goal {
        return Goal(
            name: "Dream Vacation",
            targetAmount: targetAmount,
            targetDate: targetDate,
            goalType: .vacation,
            priority: .medium,
            iconName: GoalType.vacation.defaultIcon,
            colorHex: GoalType.vacation.defaultColor
        )
    }
}

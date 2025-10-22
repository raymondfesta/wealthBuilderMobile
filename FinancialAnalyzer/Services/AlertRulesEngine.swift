import Foundation

/// Engine that evaluates rules and triggers proactive alerts
struct AlertRulesEngine {

    // MARK: - Evaluate Pending Transaction

    /// Evaluates a pending or about-to-happen transaction and generates alerts
    static func evaluatePurchase(
        amount: Double,
        merchantName: String,
        category: String,
        budgets: [Budget],
        goals: [Goal],
        transactions: [Transaction],
        availableToSpend: Double
    ) -> [ProactiveAlert] {
        var alerts: [ProactiveAlert] = []

        // Find relevant budget
        if let budget = budgets.first(where: { $0.categoryName == category && $0.month == Date().startOfMonth }) {
            let afterPurchase = budget.currentSpent + amount
            let remaining = budget.monthlyLimit - afterPurchase

            // Generate budget-specific alerts
            if afterPurchase > budget.monthlyLimit {
                // Over budget alert
                let overage = afterPurchase - budget.monthlyLimit
                let otherBudgets = budgets.filter {
                    $0.categoryName != category &&
                    $0.remaining > overage &&
                    $0.status != .exceeded
                }

                alerts.append(
                    ProactiveAlert(
                        type: .budgetExceeded,
                        severity: .high,
                        title: "Over Budget: \(category)",
                        message: "This $\(Int(amount)) purchase exceeds your \(category) budget by $\(Int(overage)).",
                        actionOptions: generateReallocationOptions(
                            neededAmount: overage,
                            availableBudgets: otherBudgets,
                            availableToSpend: availableToSpend
                        ),
                        relatedBudget: budget,
                        impactSummary: ImpactSummary(
                            currentRemaining: budget.remaining,
                            afterPurchaseRemaining: remaining,
                            daysUntilMonthEnd: Date().daysRemainingInMonth,
                            percentOfBudgetUsed: (afterPurchase / budget.monthlyLimit) * 100
                        )
                    )
                )
            } else if budget.status == .warning || budget.status == .caution {
                // Approaching limit alert
                alerts.append(
                    ProactiveAlert(
                        type: .budgetWarning,
                        severity: .medium,
                        title: "Budget Check: \(category)",
                        message: "You have $\(Int(remaining)) left in \(category) after this purchase.",
                        actionOptions: [
                            AlertAction(
                                title: "Confirm Purchase",
                                actionType: .confirmPurchase,
                                description: "Continue with purchase"
                            ),
                            AlertAction(
                                title: "Review Budget",
                                actionType: .reviewBudget,
                                description: "See full budget breakdown"
                            )
                        ],
                        relatedBudget: budget,
                        impactSummary: ImpactSummary(
                            currentRemaining: budget.remaining,
                            afterPurchaseRemaining: remaining,
                            daysUntilMonthEnd: Date().daysRemainingInMonth,
                            percentOfBudgetUsed: (afterPurchase / budget.monthlyLimit) * 100
                        )
                    )
                )
            } else {
                // On track - positive reinforcement
                alerts.append(
                    ProactiveAlert(
                        type: .budgetOnTrack,
                        severity: .low,
                        title: "\(category): On Track ✓",
                        message: "You'll have $\(Int(remaining)) left after this purchase. You're doing great!",
                        actionOptions: [
                            AlertAction(
                                title: "Confirm Purchase",
                                actionType: .confirmPurchase,
                                description: nil
                            )
                        ],
                        relatedBudget: budget,
                        impactSummary: ImpactSummary(
                            currentRemaining: budget.remaining,
                            afterPurchaseRemaining: remaining,
                            daysUntilMonthEnd: Date().daysRemainingInMonth,
                            percentOfBudgetUsed: (afterPurchase / budget.monthlyLimit) * 100
                        )
                    )
                )
            }
        }

        // Check merchant spending patterns
        let merchantPattern = SpendingPatternAnalyzer.merchantPattern(
            merchantName: merchantName,
            transactions: transactions
        )

        if amount > merchantPattern.averageAmount * 2 && merchantPattern.averageAmount > 0 {
            alerts.append(
                ProactiveAlert(
                    type: .unusualSpending,
                    severity: .medium,
                    title: "Unusual \(merchantName) Purchase",
                    message: "This is \(Int((amount / merchantPattern.averageAmount) * 100))% of your typical \(merchantName) spending ($\(Int(merchantPattern.averageAmount))).",
                    actionOptions: [
                        AlertAction(
                            title: "It's a Special Purchase",
                            actionType: .confirmPurchase,
                            description: "Proceed anyway"
                        ),
                        AlertAction(
                            title: "Review History",
                            actionType: .viewMerchantHistory,
                            description: "See past \(merchantName) purchases"
                        )
                    ],
                    impactSummary: ImpactSummary(
                        currentRemaining: availableToSpend,
                        afterPurchaseRemaining: availableToSpend - amount,
                        daysUntilMonthEnd: Date().daysRemainingInMonth,
                        percentOfBudgetUsed: 0
                    )
                )
            )
        }

        // Check impact on high-priority goals
        let highPriorityGoals = goals.filter { $0.priority == .high && !$0.isComplete && $0.isActive }
        for goal in highPriorityGoals {
            if let monthlyContribution = goal.suggestedMonthlyContribution,
               amount > monthlyContribution * 0.5 {
                alerts.append(
                    ProactiveAlert(
                        type: .goalImpact,
                        severity: .low,
                        title: "Goal Impact: \(goal.name)",
                        message: "This purchase equals \(Int((amount / monthlyContribution) * 100))% of your monthly \(goal.name) contribution.",
                        actionOptions: [
                            AlertAction(
                                title: "Worth It",
                                actionType: .confirmPurchase,
                                description: "This is a priority"
                            ),
                            AlertAction(
                                title: "Add to Goal Instead",
                                actionType: .contributeToGoal,
                                description: "Save $\(Int(amount)) toward \(goal.name)",
                                metadata: ["goalId": goal.id, "amount": String(amount)]
                            )
                        ],
                        relatedGoal: goal,
                        impactSummary: ImpactSummary(
                            currentRemaining: goal.remaining,
                            afterPurchaseRemaining: goal.remaining,
                            daysUntilMonthEnd: Date().daysRemainingInMonth,
                            percentOfBudgetUsed: 0
                        )
                    )
                )
            }
        }

        return alerts
    }

    // MARK: - Evaluate Savings Opportunity

    /// Detects when user is under budget and suggests savings
    static func evaluateSavingsOpportunity(
        budgets: [Budget],
        goals: [Goal],
        transactions: [Transaction]
    ) -> ProactiveAlert? {
        let underBudgetCategories = budgets.filter {
            $0.remaining > 50 && $0.percentUsed < 80
        }

        guard !underBudgetCategories.isEmpty else { return nil }

        let totalUnderBudget = underBudgetCategories.map { $0.remaining }.reduce(0, +)
        let activeGoals = goals.filter { $0.isActive && !$0.isComplete }
        let highPriorityGoal = activeGoals.first { $0.priority == .high }

        var actions: [AlertAction] = []

        // Suggest contributing to high-priority goal
        if let goal = highPriorityGoal {
            let suggestedAmount = min(totalUnderBudget * 0.5, goal.remaining)
            actions.append(
                AlertAction(
                    title: "Add to \(goal.name)",
                    actionType: .contributeToGoal,
                    description: "$\(Int(suggestedAmount)) → \(Int(goal.percentComplete + (suggestedAmount/goal.targetAmount)*100))% complete",
                    metadata: ["goalId": goal.id, "amount": String(suggestedAmount)]
                )
            )
        }

        // Offer to keep as buffer
        actions.append(
            AlertAction(
                title: "Keep as Flexible Buffer",
                actionType: .keepAsBuffer,
                description: "Available for unexpected expenses"
            )
        )

        return ProactiveAlert(
            type: .savingsOpportunity,
            severity: .low,
            title: "✨ You're $\(Int(totalUnderBudget)) Under Budget!",
            message: "Great job staying on track. What would you like to do with this surplus?",
            actionOptions: actions,
            relatedGoal: highPriorityGoal,
            impactSummary: ImpactSummary(
                currentRemaining: totalUnderBudget,
                afterPurchaseRemaining: totalUnderBudget,
                daysUntilMonthEnd: Date().daysRemainingInMonth,
                percentOfBudgetUsed: 0
            )
        )
    }

    // MARK: - Evaluate Cash Flow Risk

    /// Checks for upcoming bills that might cause cash flow issues
    static func evaluateCashFlowRisk(
        transactions: [Transaction],
        accounts: [BankAccount],
        daysAhead: Int = 7
    ) -> ProactiveAlert? {
        let prediction = SpendingPatternAnalyzer.predictCashFlow(
            transactions: transactions,
            accounts: accounts,
            daysAhead: daysAhead
        )

        guard prediction.riskLevel == .high || prediction.riskLevel == .medium else {
            return nil
        }

        let upcomingBills = prediction.upcomingExpenses
            .map { "• \($0.merchantName): $\(Int($0.amount)) (in \(Calendar.current.dateComponents([.day], from: Date(), to: $0.expectedDate).day ?? 0) days)" }
            .joined(separator: "\n")

        let severity: AlertSeverity = prediction.riskLevel == .high ? .high : .medium

        return ProactiveAlert(
            type: .cashFlowWarning,
            severity: severity,
            title: "⚡ Cash Flow Alert",
            message: "You have $\(Int(prediction.currentBalance)) available, but $\(Int(prediction.upcomingExpenses.map { $0.amount }.reduce(0, +))) in upcoming bills.\n\n\(upcomingBills)",
            actionOptions: [
                AlertAction(
                    title: "Move Money from Savings",
                    actionType: .transferMoney,
                    description: "Transfer to checking to cover bills"
                ),
                AlertAction(
                    title: "Review Upcoming Bills",
                    actionType: .viewUpcomingBills,
                    description: "See all predicted expenses"
                ),
                AlertAction(
                    title: "I'll Handle It",
                    actionType: .dismiss,
                    description: nil
                )
            ],
            impactSummary: ImpactSummary(
                currentRemaining: prediction.currentBalance,
                afterPurchaseRemaining: prediction.projectedBalance,
                daysUntilMonthEnd: Date().daysRemainingInMonth,
                percentOfBudgetUsed: 0
            )
        )
    }

    // MARK: - Private Helpers

    private static func generateReallocationOptions(
        neededAmount: Double,
        availableBudgets: [Budget],
        availableToSpend: Double
    ) -> [AlertAction] {
        var options: [AlertAction] = []

        // Option 1: Pull from other budget categories
        for budget in availableBudgets.prefix(2) {
            options.append(
                AlertAction(
                    title: "Pull from \(budget.categoryName)",
                    actionType: .reallocateBudget,
                    description: "$\(Int(budget.remaining)) available",
                    metadata: [
                        "sourceBudgetId": budget.id,
                        "amount": String(neededAmount)
                    ]
                )
            )
        }

        // Option 2: Use available to spend
        if availableToSpend > neededAmount {
            options.append(
                AlertAction(
                    title: "Use Disposable Income",
                    actionType: .useDisposableIncome,
                    description: "$\(Int(availableToSpend)) available"
                )
            )
        }

        // Option 3: Wait
        options.append(
            AlertAction(
                title: "Wait Until Next Month",
                actionType: .deferPurchase,
                description: "Budget resets in \(Date().daysRemainingInMonth) days"
            )
        )

        return options
    }
}

// MARK: - Supporting Types

class ProactiveAlert: Identifiable, ObservableObject {
    let id = UUID()
    let type: AlertType
    let severity: AlertSeverity
    let title: String
    let message: String
    let actionOptions: [AlertAction]
    var relatedBudget: Budget?
    var relatedGoal: Goal?
    var impactSummary: ImpactSummary
    @Published var aiInsight: String?  // AI-generated insight from backend
    @Published var isLoadingAIInsight: Bool  // Indicates AI fetch in progress
    let createdAt: Date

    init(
        type: AlertType,
        severity: AlertSeverity,
        title: String,
        message: String,
        actionOptions: [AlertAction],
        relatedBudget: Budget? = nil,
        relatedGoal: Goal? = nil,
        impactSummary: ImpactSummary,
        aiInsight: String? = nil,
        isLoadingAIInsight: Bool = false
    ) {
        self.type = type
        self.severity = severity
        self.title = title
        self.message = message
        self.actionOptions = actionOptions
        self.relatedBudget = relatedBudget
        self.relatedGoal = relatedGoal
        self.impactSummary = impactSummary
        self.aiInsight = aiInsight
        self.isLoadingAIInsight = isLoadingAIInsight
        self.createdAt = Date()
    }

    enum AlertType {
        case budgetExceeded
        case budgetWarning
        case budgetOnTrack
        case unusualSpending
        case savingsOpportunity
        case goalImpact
        case cashFlowWarning
        case subscriptionIncrease
    }
}

enum AlertSeverity {
    case low       // Informational, positive
    case medium    // Caution, worth reviewing
    case high      // Warning, requires attention

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }

    var iconName: String {
        switch self {
        case .low: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.octagon.fill"
        }
    }
}

struct AlertAction: Identifiable {
    let id = UUID()
    let title: String
    let actionType: ActionType
    let description: String?
    var metadata: [String: String] = [:]

    enum ActionType {
        case confirmPurchase
        case reallocateBudget
        case useDisposableIncome
        case deferPurchase
        case contributeToGoal
        case reviewBudget
        case viewMerchantHistory
        case transferMoney
        case viewUpcomingBills
        case keepAsBuffer
        case dismiss
    }
}

struct ImpactSummary {
    let currentRemaining: Double
    let afterPurchaseRemaining: Double
    let daysUntilMonthEnd: Int
    let percentOfBudgetUsed: Double

    var dailyBudgetBefore: Double {
        guard daysUntilMonthEnd > 0 else { return 0 }
        return currentRemaining / Double(daysUntilMonthEnd)
    }

    var dailyBudgetAfter: Double {
        guard daysUntilMonthEnd > 0 else { return 0 }
        return afterPurchaseRemaining / Double(daysUntilMonthEnd)
    }
}

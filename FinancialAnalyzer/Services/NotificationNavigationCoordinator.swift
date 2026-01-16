import Foundation
import SwiftUI

/// Coordinates navigation from notification taps to appropriate views
@MainActor
class NotificationNavigationCoordinator: ObservableObject {
    @Published var activeNotification: NotificationNavigation?
    @Published var shouldNavigate: Bool = false

    private var viewModel: FinancialViewModel?

    func setViewModel(_ viewModel: FinancialViewModel) {
        self.viewModel = viewModel
    }

    /// Handle notification tap and route to appropriate view
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "purchase_alert":
            handlePurchaseAlert(userInfo: userInfo)

        case "savings_opportunity":
            handleSavingsOpportunity(userInfo: userInfo)

        case "cash_flow_warning":
            handleCashFlowWarning(userInfo: userInfo)

        case "goal_milestone":
            handleGoalMilestone(userInfo: userInfo)

        case "weekly_review":
            handleWeeklyReview()

        case "pre_payday_reminder":
            handlePrePaydayReminder(userInfo: userInfo)

        case "allocation_day":
            handleAllocationDay(userInfo: userInfo)

        case "allocation_follow_up":
            handleAllocationFollowUp(userInfo: userInfo)

        default:
            break
        }
    }

    // MARK: - Notification Type Handlers

    private func handlePurchaseAlert(userInfo: [AnyHashable: Any]) {
        guard let amount = userInfo["amount"] as? Double,
              let merchantName = userInfo["merchantName"] as? String,
              let category = userInfo["category"] as? String,
              let budgetRemaining = userInfo["budgetRemaining"] as? Double else {
            return
        }

        // Recreate the alert from notification data
        if let viewModel = viewModel,
           let budget = viewModel.budgetManager.budgets.first(where: {
               $0.categoryName == category && $0.month == Date().startOfMonth
           }) {

            let afterPurchase = budget.currentSpent + amount
            let remaining = budget.monthlyLimit - afterPurchase

            let alert = ProactiveAlert(
                type: budgetRemaining > amount ? .budgetWarning : .budgetExceeded,
                severity: budgetRemaining > amount ? .medium : .high,
                title: "Budget Check: \(category)",
                message: budgetRemaining > amount
                    ? "You have $\(Int(remaining)) left in \(category) after this \(merchantName) purchase."
                    : "This $\(Int(amount)) purchase at \(merchantName) exceeds your \(category) budget.",
                actionOptions: createPurchaseActions(budget: budget, amount: amount),
                relatedBudget: budget,
                impactSummary: ImpactSummary(
                    currentRemaining: budget.remaining,
                    afterPurchaseRemaining: remaining,
                    daysUntilMonthEnd: Date().daysRemainingInMonth,
                    percentOfBudgetUsed: (afterPurchase / budget.monthlyLimit) * 100
                )
            )

            // Show the guidance view
            viewModel.currentAlert = alert
            viewModel.isShowingGuidance = true
        }
    }

    private func handleSavingsOpportunity(userInfo: [AnyHashable: Any]) {
        guard let amount = userInfo["amount"] as? Double,
              let recommendedGoal = userInfo["recommendedGoal"] as? String,
              let viewModel = viewModel else {
            return
        }

        // Find the goal
        let goal = viewModel.budgetManager.goals.first { $0.name == recommendedGoal }

        var actions: [AlertAction] = []

        if let goal = goal {
            let suggestedAmount = min(amount, goal.remaining)
            actions.append(
                AlertAction(
                    title: "Add to \(goal.name)",
                    actionType: .contributeToGoal,
                    description: "$\(Int(suggestedAmount)) → \(Int(goal.percentComplete + (suggestedAmount/goal.targetAmount)*100))% complete",
                    metadata: ["goalId": goal.id, "amount": String(suggestedAmount)]
                )
            )
        }

        actions.append(
            AlertAction(
                title: "Keep as Flexible Buffer",
                actionType: .keepAsBuffer,
                description: "Available for unexpected expenses"
            )
        )

        let alert = ProactiveAlert(
            type: .savingsOpportunity,
            severity: .low,
            title: "✨ Savings Opportunity",
            message: "You're $\(Int(amount)) under budget! Consider adding to \(recommendedGoal).",
            actionOptions: actions,
            relatedGoal: goal,
            impactSummary: ImpactSummary(
                currentRemaining: amount,
                afterPurchaseRemaining: amount,
                daysUntilMonthEnd: Date().daysRemainingInMonth,
                percentOfBudgetUsed: 0
            )
        )

        viewModel.currentAlert = alert
        viewModel.isShowingGuidance = true
    }

    private func handleCashFlowWarning(userInfo: [AnyHashable: Any]) {
        guard let currentBalance = userInfo["currentBalance"] as? Double,
              let upcomingExpenses = userInfo["upcomingExpenses"] as? Double,
              let daysAhead = userInfo["daysAhead"] as? Int,
              let viewModel = viewModel else {
            return
        }

        let alert = ProactiveAlert(
            type: .cashFlowWarning,
            severity: .high,
            title: "⚡ Cash Flow Alert",
            message: "You have $\(Int(currentBalance)) available, but $\(Int(upcomingExpenses)) in bills coming in \(daysAhead) days.",
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
                currentRemaining: currentBalance,
                afterPurchaseRemaining: currentBalance - upcomingExpenses,
                daysUntilMonthEnd: Date().daysRemainingInMonth,
                percentOfBudgetUsed: 0
            )
        )

        viewModel.currentAlert = alert
        viewModel.isShowingGuidance = true
    }

    private func handleGoalMilestone(userInfo: [AnyHashable: Any]) {
        guard let goalName = userInfo["goalName"] as? String,
              let percentComplete = userInfo["percentComplete"] as? Double,
              let viewModel = viewModel else {
            return
        }

        let goal = viewModel.budgetManager.goals.first { $0.name == goalName }

        let alert = ProactiveAlert(
            type: .goalImpact,
            severity: .low,
            title: "🎯 Goal Milestone!",
            message: "You're \(Int(percentComplete))% of the way to your \(goalName) goal. Keep it up!",
            actionOptions: [
                AlertAction(
                    title: "View Goal Progress",
                    actionType: .reviewBudget,
                    description: "See detailed progress"
                ),
                AlertAction(
                    title: "Great!",
                    actionType: .dismiss,
                    description: nil
                )
            ],
            relatedGoal: goal,
            impactSummary: ImpactSummary(
                currentRemaining: goal?.remaining ?? 0,
                afterPurchaseRemaining: goal?.remaining ?? 0,
                daysUntilMonthEnd: Date().daysRemainingInMonth,
                percentOfBudgetUsed: percentComplete
            )
        )

        viewModel.currentAlert = alert
        viewModel.isShowingGuidance = true
    }

    private func handleWeeklyReview() {
        // Navigate to dashboard or budget summary
        activeNotification = .dashboard
        shouldNavigate = true
    }

    private func handlePrePaydayReminder(userInfo: [AnyHashable: Any]) {
        // Navigate to schedule tab
        activeNotification = .scheduleTab
        shouldNavigate = true
    }

    private func handleAllocationDay(userInfo: [AnyHashable: Any]) {
        guard let paycheckTimestamp = userInfo["paycheckDate"] as? Double,
              let allocationIds = userInfo["allocationIds"] as? [String],
              let viewModel = viewModel else {
            return
        }

        // Find allocations for this payday
        let paycheckDate = Date(timeIntervalSince1970: paycheckTimestamp)
        let allocations = viewModel.scheduledAllocations.filter { allocation in
            allocationIds.contains(allocation.id) &&
            Calendar.current.isDate(allocation.paycheckDate, inSameDayAs: paycheckDate)
        }

        if !allocations.isEmpty {
            // Show allocation reminder sheet
            activeNotification = .allocationReminder(allocations)
            shouldNavigate = true
        }
    }

    private func handleAllocationFollowUp(userInfo: [AnyHashable: Any]) {
        // Same as allocation day handler
        handleAllocationDay(userInfo: userInfo)
    }

    // MARK: - Helper Methods

    private func createPurchaseActions(budget: Budget, amount: Double) -> [AlertAction] {
        let afterPurchase = budget.currentSpent + amount

        if afterPurchase > budget.monthlyLimit {
            // Over budget - offer reallocation options
            let overage = afterPurchase - budget.monthlyLimit
            var actions: [AlertAction] = []

            // Find other budgets with available funds
            if let viewModel = viewModel {
                let otherBudgets = viewModel.budgetManager.budgets.filter {
                    $0.categoryName != budget.categoryName &&
                    $0.remaining > overage &&
                    $0.status != .exceeded
                }

                for otherBudget in otherBudgets.prefix(2) {
                    actions.append(
                        AlertAction(
                            title: "Pull from \(otherBudget.categoryName)",
                            actionType: .reallocateBudget,
                            description: "$\(Int(otherBudget.remaining)) available",
                            metadata: [
                                "sourceBudgetId": otherBudget.id,
                                "amount": String(overage)
                            ]
                        )
                    )
                }
            }

            actions.append(
                AlertAction(
                    title: "Wait Until Next Month",
                    actionType: .deferPurchase,
                    description: "Budget resets in \(Date().daysRemainingInMonth) days"
                )
            )

            return actions
        } else {
            // Within budget
            return [
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
            ]
        }
    }
}

// MARK: - Navigation Destination

enum NotificationNavigation: Identifiable {
    case purchaseAlert(ProactiveAlert)
    case savingsOpportunity(ProactiveAlert)
    case cashFlowWarning(ProactiveAlert)
    case goalMilestone(ProactiveAlert)
    case dashboard
    case scheduleTab
    case allocationReminder([ScheduledAllocation])

    var id: String {
        switch self {
        case .purchaseAlert: return "purchase_alert"
        case .savingsOpportunity: return "savings_opportunity"
        case .cashFlowWarning: return "cash_flow_warning"
        case .goalMilestone: return "goal_milestone"
        case .dashboard: return "dashboard"
        case .scheduleTab: return "schedule_tab"
        case .allocationReminder: return "allocation_reminder"
        }
    }
}

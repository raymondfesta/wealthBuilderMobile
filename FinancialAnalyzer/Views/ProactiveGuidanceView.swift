import SwiftUI

/// Main view for displaying proactive purchase guidance alerts
struct ProactiveGuidanceView: View {
    let alert: ProactiveAlert
    let onActionSelected: (AlertAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with icon and title
                    headerSection

                    // Main message
                    messageSection

                    // Impact summary card
                    if let budget = alert.relatedBudget {
                        budgetImpactSection(budget: budget)
                    }

                    // AI Insight (if available)
                    // This would be populated from backend API call
                    aiInsightSection

                    // Action buttons
                    actionsSection

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Budget Guidance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: alert.severity.iconName)
                .font(.system(size: 40))
                .foregroundColor(severityColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(severityText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(severityColor.opacity(0.1))
        )
    }

    private var messageSection: some View {
        Text(alert.message)
            .font(.body)
            .foregroundColor(.primary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
    }

    private func budgetImpactSection(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Budget Impact")
                .font(.headline)

            VStack(spacing: 12) {
                // Current status
                HStack {
                    Text("Current Remaining")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(alert.impactSummary.currentRemaining))
                        .fontWeight(.semibold)
                }

                Divider()

                // After purchase
                HStack {
                    Text("After Purchase")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(alert.impactSummary.afterPurchaseRemaining))
                        .fontWeight(.semibold)
                        .foregroundColor(alert.impactSummary.afterPurchaseRemaining < 0 ? .red : .primary)
                }

                Divider()

                // Days remaining
                HStack {
                    Text("Days Until Month End")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(alert.impactSummary.daysUntilMonthEnd) days")
                        .fontWeight(.semibold)
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Budget Used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(alert.impactSummary.percentOfBudgetUsed))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    ProgressView(value: min(alert.impactSummary.percentOfBudgetUsed, 100), total: 100)
                        .tint(progressColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var aiInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Insight")
                    .font(.headline)
                Spacer()

                // Show loading indicator while fetching AI insight
                if alert.isLoadingAIInsight {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            // Show loading message or actual insight
            if alert.isLoadingAIInsight {
                HStack {
                    ProgressView()
                    Text("Analyzing your purchase...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                // Context-aware AI insight based on alert type
                Text(aiInsightText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    private var aiInsightText: String {
        // Use AI-generated insight if available, otherwise fall back to hardcoded text
        if let aiInsight = alert.aiInsight, !aiInsight.isEmpty {
            return aiInsight
        }

        // Fallback to context-aware hardcoded insights
        switch alert.type {
        case .budgetExceeded:
            if let budget = alert.relatedBudget {
                return "You've spent \(Int(alert.impactSummary.percentOfBudgetUsed))% of your \(budget.categoryName) budget with \(alert.impactSummary.daysUntilMonthEnd) days left. Consider reallocating from categories where you're under budget."
            }
            return "This purchase exceeds your budget. Review your spending patterns to stay on track."

        case .budgetWarning:
            if let budget = alert.relatedBudget {
                let dailyRemaining = alert.impactSummary.afterPurchaseRemaining / Double(max(alert.impactSummary.daysUntilMonthEnd, 1))
                return "After this purchase, you'll have about $\(Int(dailyRemaining))/day for \(budget.categoryName). You're pacing well—this keeps you within your monthly target."
            }
            return "You're approaching your budget limit. This purchase is manageable if you stay mindful for the rest of the month."

        case .budgetOnTrack:
            if let budget = alert.relatedBudget {
                return "Great job! You're \(Int(100 - alert.impactSummary.percentOfBudgetUsed))% under budget in \(budget.categoryName). This spending pattern gives you flexibility for the rest of the month."
            }
            return "You're doing great! Your spending is well within budget and sustainable."

        case .savingsOpportunity:
            if let goal = alert.relatedGoal {
                let amountToGoal = alert.impactSummary.currentRemaining
                let newPercent = goal.percentComplete + (amountToGoal / goal.targetAmount * 100)
                return "Contributing this surplus would boost your \(goal.name) to \(Int(newPercent))% complete. You're on track to reach your goal \(goal.targetDate != nil ? "ahead of schedule" : "faster than expected")!"
            }
            return "You're under budget this month! This surplus can accelerate your financial goals or serve as a buffer for unexpected expenses."

        case .unusualSpending:
            return "This purchase is significantly higher than your typical spending at this merchant. Double-check that the amount is correct before proceeding."

        case .goalImpact:
            if let goal = alert.relatedGoal {
                return "This purchase equals a significant portion of your monthly \(goal.name) contribution. Consider if this expense aligns with your priority goals."
            }
            return "This purchase may impact your ability to meet your savings goals this month."

        case .cashFlowWarning:
            return "Based on your recurring expenses, you may not have enough to cover upcoming bills. Consider transferring funds or adjusting your spending to avoid overdraft fees."

        case .subscriptionIncrease:
            return "This subscription cost has increased. Review if you're still getting value, or look for alternative options to save money."
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Text("What would you like to do?")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(alert.actionOptions) { action in
                ActionButton(
                    action: action,
                    onTap: {
                        onActionSelected(action)
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    private var severityColor: Color {
        switch alert.severity {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var severityText: String {
        switch alert.severity {
        case .low: return "Looking good"
        case .medium: return "Review recommended"
        case .high: return "Action needed"
        }
    }

    private var progressColor: Color {
        let percent = alert.impactSummary.percentOfBudgetUsed
        if percent >= 100 { return .red }
        if percent >= 90 { return .orange }
        if percent >= 75 { return .yellow }
        return .green
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let action: AlertAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if let description = action.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(actionBorderColor, lineWidth: isPrimaryAction ? 2 : 1)
            )
        }
    }

    private var isPrimaryAction: Bool {
        action.actionType == .confirmPurchase || action.actionType == .contributeToGoal
    }

    private var actionBorderColor: Color {
        if isPrimaryAction {
            return .blue
        }
        return Color.gray.opacity(0.2)
    }
}

// MARK: - Quick Decision Sheet (Simplified)

struct QuickDecisionSheet: View {
    let purchaseAmount: Double
    let merchantName: String
    let budgetRemaining: Double
    let onDecision: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            // Merchant and amount
            VStack(spacing: 8) {
                Text(merchantName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(formatCurrency(purchaseAmount))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.blue)
            }
            .padding(.top)

            // Quick stats
            HStack(spacing: 20) {
                QuickStat(
                    label: "Remaining",
                    value: formatCurrency(budgetRemaining),
                    color: budgetRemaining > purchaseAmount ? .green : .orange
                )

                Divider()
                    .frame(height: 40)

                QuickStat(
                    label: "After",
                    value: formatCurrency(budgetRemaining - purchaseAmount),
                    color: (budgetRemaining - purchaseAmount) < 0 ? .red : .green
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )

            // Decision buttons
            VStack(spacing: 12) {
                Button(action: {
                    onDecision(true)
                    dismiss()
                }) {
                    Text("Confirm Purchase")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button(action: {
                    onDecision(false)
                    dismiss()
                }) {
                    Text("Not Now")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct QuickStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

#Preview("Budget Warning") {
    let budget = Budget(
        categoryName: "Shopping",
        monthlyLimit: 300,
        currentSpent: 250
    )

    let alert = ProactiveAlert(
        type: .budgetWarning,
        severity: .medium,
        title: "Shopping: Approaching Limit",
        message: "You have $50 left in Shopping after this $87 purchase.",
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
            currentRemaining: 50,
            afterPurchaseRemaining: -37,
            daysUntilMonthEnd: 12,
            percentOfBudgetUsed: 83
        )
    )

    return ProactiveGuidanceView(alert: alert) { action in
        print("Selected action: \(action.title)")
    }
}

#Preview("Quick Decision") {
    QuickDecisionSheet(
        purchaseAmount: 87.43,
        merchantName: "Target",
        budgetRemaining: 112
    ) { confirmed in
        print("Purchase confirmed: \(confirmed)")
    }
}

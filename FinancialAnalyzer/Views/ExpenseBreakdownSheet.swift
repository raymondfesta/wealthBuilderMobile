import SwiftUI

/// Shows detailed breakdown of essential expenses by category
/// Displayed when user taps "Essential Expenses" in AnalysisCompleteView
struct ExpenseBreakdownSheet: View {
    let breakdown: ExpenseBreakdown
    let monthlyAverage: Double
    var transactions: [Transaction] = []
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed Properties

    private var expenseTransactions: [Transaction] {
        transactions
            .filter { $0.bucketCategory == .expenses }
            .sorted { $0.date > $1.date }
    }

    private var transactionsNeedingValidation: [Transaction] {
        expenseTransactions.filter { $0.needsValidation }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Summary section with confidence indicator
                    summarySection

                    // Category breakdown
                    categoryBreakdownSection

                    // Needs review section
                    if !transactionsNeedingValidation.isEmpty {
                        needsReviewSection
                    }

                    // All expenses section
                    if !expenseTransactions.isEmpty {
                        allExpensesSection
                    }

                    // Explanation footer
                    explanationSection
                }
                .padding(DesignTokens.Spacing.md)
            }
            .primaryBackgroundGradient()
            .navigationTitle("Expense Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        GlassmorphicCard(title: "Monthly Average", showDivider: false) {
            VStack(spacing: DesignTokens.Spacing.md) {
                // Amount and icon
                HStack {
                    Text(formatCurrency(monthlyAverage))
                        .titleValueStyle()

                    Spacer()

                    Image(systemName: "cart.fill")
                        .font(.largeTitle)
                        .foregroundColor(DesignTokens.Colors.opportunityOrange)
                }

                // Confidence badge
                confidenceBadge
            }
        }
    }

    private var confidenceBadge: some View {
        let level = breakdown.confidenceLevel

        return HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: level.iconName)
                .foregroundColor(confidenceColor(for: level))

            Text("\(Int(breakdown.confidence * 100))% confident")
                .subheadlineStyle()

            Spacer()

            if level.shouldPromptReview {
                Text("Review recommended")
                    .captionStyle(color: DesignTokens.Colors.opportunityOrange)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(confidenceColor(for: level).opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }

    private func confidenceColor(for level: ExpenseConfidenceLevel) -> Color {
        switch level {
        case .high:
            return DesignTokens.Colors.progressGreen
        case .medium:
            return DesignTokens.Colors.accentPrimary
        case .low:
            return DesignTokens.Colors.opportunityOrange
        }
    }

    // MARK: - Category Breakdown Section

    private var categoryBreakdownSection: some View {
        GlassmorphicCard(title: "Breakdown by Category") {
            VStack(spacing: 0) {
                ForEach(breakdown.categories) { category in
                    ExpenseCategoryRow(
                        category: category,
                        totalExpenses: breakdown.total
                    )

                    if category.id != breakdown.categories.last?.id {
                        Rectangle()
                            .fill(DesignTokens.Colors.divider)
                            .frame(height: 1)
                    }
                }

                Rectangle()
                    .fill(DesignTokens.Colors.divider)
                    .frame(height: 1)
                    .padding(.vertical, DesignTokens.Spacing.xs)

                // Total row
                HStack {
                    Text("Total")
                        .headlineStyle()
                    Spacer()
                    Text(formatCurrency(breakdown.total))
                        .titleValueStyle()
                }
                .padding(.top, DesignTokens.Spacing.xs)
            }
        }
    }

    // MARK: - Needs Review Section

    private var needsReviewSection: some View {
        GlassmorphicCard(title: "Needs Review (\(transactionsNeedingValidation.count))") {
            VStack(spacing: 0) {
                ForEach(transactionsNeedingValidation) { transaction in
                    HStack {
                        TransactionRow(transaction: transaction)
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(DesignTokens.Colors.opportunityOrange)
                    }

                    if transaction.id != transactionsNeedingValidation.last?.id {
                        Rectangle()
                            .fill(DesignTokens.Colors.divider)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: - All Expenses Section

    private var allExpensesSection: some View {
        GlassmorphicCard(title: "All Expenses") {
            VStack(spacing: 0) {
                ForEach(Array(expenseTransactions.prefix(50))) { transaction in
                    TransactionRow(transaction: transaction)

                    if transaction.id != expenseTransactions.prefix(50).last?.id {
                        Rectangle()
                            .fill(DesignTokens.Colors.divider)
                            .frame(height: 1)
                    }
                }

                if expenseTransactions.count > 50 {
                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(height: 1)

                    Text("+ \(expenseTransactions.count - 50) more")
                        .captionStyle()
                        .padding(.top, DesignTokens.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Explanation Section

    private var explanationSection: some View {
        GlassmorphicCard(showDivider: false) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("How we categorized")
                    .headlineStyle()

                Text("We analyzed your transactions using Plaid's AI-powered categorization. Categories are assigned based on merchant information, transaction descriptions, and spending patterns.")
                    .captionStyle()

                if breakdown.confidenceLevel != .high {
                    Text(breakdown.confidenceLevel.message)
                        .captionStyle(color: DesignTokens.Colors.opportunityOrange)
                        .padding(.top, DesignTokens.Spacing.xxs)
                }
            }
        }
    }
}

// MARK: - Category Row Component

private struct ExpenseCategoryRow: View {
    let category: ExpenseCategory
    let totalExpenses: Double

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundColor(categoryColor)
                .frame(width: 24)

            // Name and percentage
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)

                Text("\(Int(category.percentage(of: totalExpenses)))% of expenses")
                    .captionStyle()
            }

            Spacer()

            // Amount
            Text(formatCurrency(category.amount))
                .headlineStyle()
                .monospacedDigit()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var categoryColor: Color {
        // Map category colors to design system
        switch category.color {
        case "blue":
            return DesignTokens.Colors.stableBlue
        case "green":
            return DesignTokens.Colors.progressGreen
        case "orange":
            return DesignTokens.Colors.opportunityOrange
        case "purple":
            return DesignTokens.Colors.wealthPurple
        case "mint", "teal":
            return DesignTokens.Colors.protectionMint
        default:
            return DesignTokens.Colors.accentSecondary
        }
    }
}

// MARK: - Helpers

private func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "$0"
}

// MARK: - Preview

#if DEBUG
struct ExpenseBreakdownSheet_Previews: PreviewProvider {
    static var previewTransactions: [Transaction] {
        [
            Transaction(
                id: "exp_1", accountId: "acc_1", amount: 89.50, date: Date(),
                name: "Whole Foods Market", merchantName: "Whole Foods",
                category: ["Food and Drink", "Groceries"],
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_GROCERIES",
                    confidenceLevel: .veryHigh
                ),
                userCorrectedCategory: .expenses
            ),
            Transaction(
                id: "exp_2", accountId: "acc_1", amount: 1200, date: Date().addingTimeInterval(-86400 * 3),
                name: "Rent Payment", merchantName: nil,
                category: ["Rent"],
                userCorrectedCategory: .expenses
            ),
            Transaction(
                id: "exp_3", accountId: "acc_1", amount: 45.00, date: Date().addingTimeInterval(-86400 * 5),
                name: "Shell Gas Station", merchantName: "Shell",
                category: ["Transportation"],
                userCorrectedCategory: .expenses
            ),
            Transaction(
                id: "exp_4", accountId: "acc_1", amount: 150, date: Date().addingTimeInterval(-86400 * 7),
                name: "Unknown Merchant", merchantName: nil,
                category: ["General Merchandise"],
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "GENERAL_MERCHANDISE", detailed: "GENERAL_MERCHANDISE_OTHER",
                    confidenceLevel: .low
                ),
                userCorrectedCategory: .expenses
            ),
            Transaction(
                id: "exp_5", accountId: "acc_1", amount: 12.99, date: Date().addingTimeInterval(-86400 * 10),
                name: "Netflix", merchantName: "Netflix",
                category: ["Entertainment"],
                userCorrectedCategory: .expenses
            ),
        ]
    }

    static var previews: some View {
        ExpenseBreakdownSheet(
            breakdown: ExpenseBreakdown(
                housing: 1800,
                food: 650,
                transportation: 350,
                utilities: 200,
                insurance: 150,
                subscriptions: 80,
                healthcare: 120,
                other: 150,
                confidence: 0.78
            ),
            monthlyAverage: 3500,
            transactions: previewTransactions
        )
        .preferredColorScheme(.dark)
    }
}
#endif

import SwiftUI

/// Shows detailed breakdown of essential expenses by category
/// Displayed when user taps "Essential Expenses" in AnalysisCompleteView
struct ExpenseBreakdownSheet: View {
    let breakdown: ExpenseBreakdown
    let monthlyAverage: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Summary section with confidence indicator
                    summarySection

                    // Category breakdown
                    categoryBreakdownSection

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
            monthlyAverage: 3500
        )
        .preferredColorScheme(.dark)
    }
}
#endif

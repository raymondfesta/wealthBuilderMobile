import SwiftUI

/// Shows detailed breakdown of income sources
/// Displayed when user taps "Income" in AnalysisCompleteView
struct IncomeBreakdownSheet: View {
    let transactions: [Transaction]
    let monthlyAverage: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Summary section
                    summarySection

                    // Income sources breakdown
                    incomeSourcesSection

                    // Explanation footer
                    explanationSection
                }
                .padding(DesignTokens.Spacing.md)
            }
            .primaryBackgroundGradient()
            .navigationTitle("Income Breakdown")
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
            HStack {
                Text(formatCurrency(monthlyAverage))
                    .titleValueStyle()

                Spacer()

                Image(systemName: "arrow.down.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(DesignTokens.Colors.progressGreen)
            }
        }
    }

    // MARK: - Income Sources Section

    private var incomeSourcesSection: some View {
        GlassmorphicCard(title: "Income Sources") {
            VStack(spacing: 0) {
                ForEach(groupedIncomeSources, id: \.name) { source in
                    IncomeSourceRow(source: source, total: totalIncome)

                    if source.name != groupedIncomeSources.last?.name {
                        Rectangle()
                            .fill(DesignTokens.Colors.divider)
                            .frame(height: 1)
                    }
                }

                if !groupedIncomeSources.isEmpty {
                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(height: 1)
                        .padding(.vertical, DesignTokens.Spacing.xs)

                    // Total row
                    HStack {
                        Text("Total")
                            .headlineStyle()
                        Spacer()
                        Text(formatCurrency(totalIncome))
                            .titleValueStyle()
                    }
                    .padding(.top, DesignTokens.Spacing.xs)
                }
            }
        }
    }

    // MARK: - Explanation Section

    private var explanationSection: some View {
        GlassmorphicCard(showDivider: false) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("How we calculated")
                    .headlineStyle()

                Text("Income is identified from deposits, payroll, and transfers in. We analyze patterns over 6 months to calculate your average monthly income.")
                    .captionStyle()
            }
        }
    }

    // MARK: - Computed Properties

    private var incomeTransactions: [Transaction] {
        transactions.filter { $0.bucketCategory == .income }
    }

    private var totalIncome: Double {
        incomeTransactions.reduce(0) { $0 + abs($1.amount) }
    }

    private var groupedIncomeSources: [IncomeSource] {
        var sources: [String: Double] = [:]

        for transaction in incomeTransactions {
            let name = transaction.merchantName ?? transaction.name
            sources[name, default: 0] += abs(transaction.amount)
        }

        return sources
            .map { IncomeSource(name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}

// MARK: - Income Source Model

private struct IncomeSource {
    let name: String
    let amount: Double

    func percentage(of total: Double) -> Double {
        guard total > 0 else { return 0 }
        return (amount / total) * 100
    }
}

// MARK: - Income Source Row

private struct IncomeSourceRow: View {
    let source: IncomeSource
    let total: Double

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title3)
                .foregroundColor(DesignTokens.Colors.progressGreen)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Text("\(Int(source.percentage(of: total)))% of income")
                    .captionStyle()
            }

            Spacer()

            Text(formatCurrency(source.amount))
                .headlineStyle()
                .monospacedDigit()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
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
struct IncomeBreakdownSheet_Previews: PreviewProvider {
    static var previewTransactions: [Transaction] {
        [
            Transaction(
                id: "inc_1", accountId: "chk-1", amount: -3200,
                date: Date(), name: "ACME Corp Payroll",
                merchantName: "ACME Corp",
                category: ["Transfer", "Payroll"],
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "INCOME", detailed: "INCOME_WAGES",
                    confidenceLevel: .veryHigh
                ),
                userCorrectedCategory: .income
            ),
            Transaction(
                id: "inc_2", accountId: "chk-1", amount: -3200,
                date: Date().addingTimeInterval(-86400 * 14), name: "ACME Corp Payroll",
                merchantName: "ACME Corp",
                category: ["Transfer", "Payroll"],
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "INCOME", detailed: "INCOME_WAGES",
                    confidenceLevel: .veryHigh
                ),
                userCorrectedCategory: .income
            ),
            Transaction(
                id: "inc_3", accountId: "chk-1", amount: -750,
                date: Date().addingTimeInterval(-86400 * 5), name: "Upwork Payment",
                merchantName: "Upwork",
                category: ["Transfer", "Third Party"],
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "INCOME", detailed: "INCOME_OTHER",
                    confidenceLevel: .high
                ),
                userCorrectedCategory: .income
            ),
            Transaction(
                id: "inc_4", accountId: "inv-1", amount: -42.50,
                date: Date().addingTimeInterval(-86400 * 10), name: "Vanguard Dividend",
                merchantName: "Vanguard",
                category: ["Transfer", "Dividend"],
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "INCOME", detailed: "INCOME_DIVIDENDS",
                    confidenceLevel: .veryHigh
                ),
                userCorrectedCategory: .income
            ),
        ]
    }

    static var previews: some View {
        IncomeBreakdownSheet(
            transactions: previewTransactions,
            monthlyAverage: 7192
        )
        .preferredColorScheme(.dark)
    }
}
#endif

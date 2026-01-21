import SwiftUI

/// Shows analysis results after account connection
/// Mimics financial advisor discovery presentation: facts first, recommendations later
struct AnalysisCompleteView: View {
    let snapshot: AnalysisSnapshot
    let onSeePlan: () -> Void
    let onDrillDown: (DrillDownType) -> Void

    enum DrillDownType {
        case income
        case expenses
        case debtMinimums
        case emergencyFund
        case debt
        case investments
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // Header
                headerSection

                // Card 1: Financial Position (FIRST per mockup)
                financialPositionCard

                // Card 2: Monthly Money Flow (SECOND per mockup)
                monthlyFlowCard

                // Validation indicator if needed
                if snapshot.metadata.transactionsNeedingValidation > 0 {
                    validationIndicator
                }

                Spacer(minLength: 100)
            }
            .padding(.top, DesignTokens.Spacing.md)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Create my allocation plan", action: onSeePlan)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.xs)
                .background(
                    DesignTokens.Colors.backgroundPrimary
                        .opacity(0.95)
                        .blur(radius: 10)
                )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Analysis complete")
                .displayStyle()

            Text("Analyzed \(snapshot.metadata.transactionsAnalyzed) transactions over \(snapshot.metadata.monthsAnalyzed) months.")
                .subheadlineStyle()
        }
    }

    // MARK: - Financial Position Card

    private var financialPositionCard: some View {
        GlassmorphicCard(
            title: "Your Financial Position",
            subtitle: "A real-time snapshot of where your money stands today."
        ) {
            VStack(spacing: 0) {
                // Emergency Fund row
                FinancialMetricRow(
                    label: "Emergency Fund",
                    value: snapshot.position.emergencyCash
                ) {
                    onDrillDown(.emergencyFund)
                }

                cardDivider

                // Total Debt row
                FinancialMetricRow(
                    label: "Total Debt:",
                    value: snapshot.position.totalDebt
                ) {
                    onDrillDown(.debt)
                }

                cardDivider

                // Investments row
                FinancialMetricRow(
                    label: "Investments:",
                    value: snapshot.position.investmentBalances,
                    showChevron: true
                ) {
                    onDrillDown(.investments)
                }
            }
        }
    }

    // MARK: - Monthly Flow Card

    private var monthlyFlowCard: some View {
        GlassmorphicCard(
            title: "Your monthly money flow",
            subtitle: "A clear picture of your monthly inflows and outflows."
        ) {
            VStack(spacing: 0) {
                // Income row
                FinancialMetricRow(
                    label: "Income:",
                    value: snapshot.monthlyFlow.income,
                    valueColor: DesignTokens.Colors.progressGreen
                ) {
                    onDrillDown(.income)
                }

                cardDivider

                // Essential Expenses row
                FinancialMetricRow(
                    label: "Essential Expenses:",
                    value: -snapshot.monthlyFlow.essentialExpenses
                ) {
                    onDrillDown(.expenses)
                }

                cardDivider

                // Debt Minimums row
                FinancialMetricRow(
                    label: "Debt Minimums:",
                    value: -snapshot.monthlyFlow.debtMinimums
                ) {
                    onDrillDown(.debtMinimums)
                }

                // To Allocate row (highlighted)
                HStack {
                    Text("To Allocate:")
                        .headlineStyle(color: DesignTokens.Colors.accentPrimary)

                    Spacer()

                    Text(formatCurrency(snapshot.monthlyFlow.discretionaryIncome))
                        .title3Style(color: DesignTokens.Colors.accentPrimary)
                }
                .padding(.top, DesignTokens.Spacing.md)
            }
        }
    }

    // MARK: - Validation Indicator

    private var validationIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(DesignTokens.Colors.opportunityOrange)

            Text("\(snapshot.metadata.transactionsNeedingValidation) transactions need review")
                .subheadlineStyle()
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity)
        .primaryCardStyle()
    }

    // MARK: - Helpers

    private var cardDivider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.divider)
            .frame(height: 1)
            .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview

#if DEBUG
struct AnalysisCompleteView_Previews: PreviewProvider {
    static var previews: some View {
        AnalysisCompleteView(
            snapshot: AnalysisSnapshot(
                monthlyFlow: MonthlyFlow(
                    income: 2542,
                    expenseBreakdown: ExpenseBreakdown(
                        housing: 1200,
                        food: 400,
                        transportation: 200,
                        utilities: 100,
                        insurance: 50,
                        subscriptions: 30,
                        other: 12,
                        confidence: 0.85
                    ),
                    debtMinimums: 35
                ),
                position: FinancialPosition(
                    emergencyCash: 22800,
                    totalDebt: 1850,
                    investmentBalances: 81250,
                    monthlyInvestmentContributions: 500
                ),
                metadata: AnalysisMetadata(
                    monthsAnalyzed: 6,
                    accountsConnected: 3,
                    transactionsAnalyzed: 1000,
                    transactionsNeedingValidation: 0,
                    lastUpdated: Date()
                )
            ),
            onSeePlan: {},
            onDrillDown: { _ in }
        )
        .preferredColorScheme(.dark)
    }
}
#endif

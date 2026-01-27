import SwiftUI

/// Comprehensive financial health report - shows empty state or full report
/// Focus: Educational, opportunity-focused, non-judgmental
struct FinancialHealthReportView: View {
    let healthMetrics: FinancialHealthMetrics?
    let onSetupHealthReport: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            if let metrics = healthMetrics {
                // Full health report
                fullHealthReport(metrics: metrics)
            } else {
                // Empty state - setup required
                HealthReportEmptyStateView(
                    onSetup: onSetupHealthReport,
                    onDismiss: onDismiss
                )
            }
        }
    }

    // MARK: - Full Health Report

    @ViewBuilder
    private func fullHealthReport(metrics: FinancialHealthMetrics) -> some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                // Header
                headerSection(metrics: metrics)

                // Key Metrics Cards
                metricsSection(metrics: metrics)

                // Spending Breakdown
                spendingBreakdownSection(metrics: metrics)

                // Bottom padding
                Spacer().frame(height: DesignTokens.Spacing.xl)
            }
            .padding(DesignTokens.Spacing.md)
        }
        .primaryBackgroundGradient()
        .navigationTitle("Your Financial Health")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private func headerSection(metrics: FinancialHealthMetrics) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(DesignTokens.Colors.stableBlue.gradient)

            Text("Here's what we learned from your transactions")
                .title3Style()
                .multilineTextAlignment(.center)

            Text("Analyzed \(metrics.analysisMonths) months of financial activity")
                .subheadlineStyle()
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }

    private func metricsSection(metrics: FinancialHealthMetrics) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Savings Metric
            MetricCard(
                icon: "arrow.up.circle.fill",
                iconColor: DesignTokens.Colors.progressGreen,
                title: "Monthly Savings",
                value: metrics.monthlySavings > 0 ? formatCurrency(metrics.monthlySavings) : "Insufficient data",
                subtitle: metrics.monthlySavings > 0 ? trendText(metrics.monthlySavingsTrend, context: "from last period") : "Tag your savings accounts to improve detection",
                explanation: "The amount remaining after your monthly expenses. This is what you can allocate toward goals and future needs.",
                progress: nil
            )

            // Emergency Fund Metric
            MetricCard(
                icon: "shield.fill",
                iconColor: DesignTokens.Colors.stableBlue,
                title: "Emergency Fund",
                value: metrics.emergencyFundMonthsCovered > 0 ? "\(String(format: "%.1f", metrics.emergencyFundMonthsCovered)) months" : "Not tagged",
                subtitle: metrics.emergencyFundMonthsCovered > 0 ? "Covers \(String(format: "%.1f", metrics.emergencyFundMonthsCovered)) months of essential expenses" : "Tag an account as 'Emergency Fund' in Connected Accounts",
                explanation: "Your current savings divided by monthly essential expenses. Financial advisors recommend \(metrics.incomeStability.recommendedEmergencyMonths) months for your income stability level.",
                progress: metrics.emergencyFundMonthsCovered > 0 ? ProgressData(
                    current: metrics.emergencyFundMonthsCovered,
                    target: Double(metrics.incomeStability.recommendedEmergencyMonths),
                    unit: "months"
                ) : nil
            )

            // Income Metric
            MetricCard(
                icon: "dollarsign.circle.fill",
                iconColor: DesignTokens.Colors.protectionMint,
                title: "Monthly Income",
                value: formatCurrency(metrics.monthlyIncome),
                subtitle: stabilityText(metrics.incomeStability, analysisMonths: metrics.analysisMonths),
                explanation: "Your average monthly income over the analysis period. \(metrics.incomeStability.explanation)",
                progress: nil
            )

            // Debt Metric (conditional - only show if debt exists)
            if metrics.monthlyDebtPayments > 0 {
                MetricCard(
                    icon: "creditcard.fill",
                    iconColor: DesignTokens.Colors.opportunityOrange,
                    title: "Debt Payments",
                    value: formatCurrency(metrics.monthlyDebtPayments),
                    subtitle: debtPayoffText(metrics.monthsToDebtFree),
                    explanation: "Your monthly debt obligations including credit cards, loans, and mortgages. Consistent payments build financial stability.",
                    progress: metrics.monthsToDebtFree.map { months in
                        ProgressData(
                            current: Double(months),
                            target: 0,
                            unit: "months until debt-free",
                            reversed: true
                        )
                    }
                )
            }
        }
    }

    private func spendingBreakdownSection(metrics: FinancialHealthMetrics) -> some View {
        GlassmorphicCard(
            title: "How You Allocate Your Income"
        ) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Essential Expenses
                SpendingBreakdownRow(
                    label: "Essential Expenses",
                    amount: metrics.essentialSpending,
                    total: metrics.monthlyIncome,
                    color: DesignTokens.Colors.stableBlue,
                    description: "Housing, groceries, utilities, transportation"
                )

                // Discretionary Spending
                SpendingBreakdownRow(
                    label: "Discretionary Spending",
                    amount: metrics.discretionarySpending,
                    total: metrics.monthlyIncome,
                    color: DesignTokens.Colors.opportunityOrange,
                    description: "Entertainment, dining, shopping, hobbies"
                )

                // Debt Payments (conditional)
                if metrics.monthlyDebtPayments > 0 {
                    SpendingBreakdownRow(
                        label: "Debt Payments",
                        amount: metrics.monthlyDebtPayments,
                        total: metrics.monthlyIncome,
                        color: DesignTokens.Colors.opportunityOrange,
                        description: "Credit cards, loans, mortgage"
                    )
                }

                // Savings
                SpendingBreakdownRow(
                    label: "Savings",
                    amount: metrics.monthlySavings,
                    total: metrics.monthlyIncome,
                    color: DesignTokens.Colors.progressGreen,
                    description: "Available for goals and future needs"
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func trendText(_ trend: TrendIndicator, context: String) -> String {
        switch trend {
        case .increasing:
            return "\(trend.rawValue) Up \(context)"
        case .stable:
            return "\(trend.rawValue) Stable \(context)"
        case .decreasing:
            return "\(trend.rawValue) Down \(context)"
        }
    }

    private func stabilityText(_ stability: IncomeStabilityLevel, analysisMonths: Int) -> String {
        switch stability {
        case .stable:
            return "Consistent over \(analysisMonths) months"
        case .variable:
            return "Varies month to month"
        case .inconsistent:
            return "Fluctuates significantly"
        }
    }

    private func debtPayoffText(_ months: Int?) -> String {
        guard let months = months else {
            return "Making progress on debt payoff"
        }

        if months <= 12 {
            return "On track to pay off in \(months) month\(months == 1 ? "" : "s")"
        } else {
            let years = months / 12
            let remainingMonths = months % 12
            if remainingMonths == 0 {
                return "On track to pay off in \(years) year\(years == 1 ? "" : "s")"
            } else {
                return "On track to pay off in \(years)yr \(remainingMonths)mo"
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct FinancialHealthReportView_Previews: PreviewProvider {
    static var previews: some View {
        // Healthy profile scenario
        let healthyMetrics = FinancialHealthMetrics(
            monthlySavings: 800,
            monthlySavingsTrend: .increasing,
            emergencyFundMonthsCovered: 4.5,
            emergencyFundTarget: 18000,
            monthlyIncome: 5000,
            incomeStability: .stable,
            monthlyDebtPayments: 400,
            monthsToDebtFree: 24,
            discretionarySpending: 600,
            essentialSpending: 3000,
            spendingTrend: .stable,
            healthScore: 75,
            savingsRate: 0.16,
            debtToIncomeRatio: 0.08,
            calculatedAt: Date(),
            analysisMonths: 6
        )

        // Low savings scenario
        let challengingMetrics = FinancialHealthMetrics(
            monthlySavings: 150,
            monthlySavingsTrend: .decreasing,
            emergencyFundMonthsCovered: 1.2,
            emergencyFundTarget: 18000,
            monthlyIncome: 4500,
            incomeStability: .variable,
            monthlyDebtPayments: 800,
            monthsToDebtFree: 36,
            discretionarySpending: 800,
            essentialSpending: 3000,
            spendingTrend: .increasing,
            healthScore: 35,
            savingsRate: 0.03,
            debtToIncomeRatio: 0.18,
            calculatedAt: Date(),
            analysisMonths: 6
        )

        Group {
            FinancialHealthReportView(
                healthMetrics: healthyMetrics,
                onSetupHealthReport: { print("Setup tapped") },
                onDismiss: { print("Dismiss tapped") }
            )
            .previewDisplayName("Healthy Profile")

            FinancialHealthReportView(
                healthMetrics: challengingMetrics,
                onSetupHealthReport: { print("Setup tapped") },
                onDismiss: { print("Dismiss tapped") }
            )
            .previewDisplayName("Challenging Profile")

            FinancialHealthReportView(
                healthMetrics: nil,
                onSetupHealthReport: { print("Setup tapped") },
                onDismiss: { print("Dismiss tapped") }
            )
            .previewDisplayName("Empty State")
        }
    }
}
#endif

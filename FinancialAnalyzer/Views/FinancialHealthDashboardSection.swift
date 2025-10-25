import SwiftUI

/// Compact collapsible section showing financial health metrics on the dashboard
/// Focus: Quick insights with month-over-month progress tracking
struct FinancialHealthDashboardSection: View {
    let healthMetrics: FinancialHealthMetrics
    let previousMetrics: FinancialHealthMetrics?  // For month-over-month comparison
    let onViewFullReport: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with expand/collapse
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Financial Health")
                        .font(.headline)

                    if let change = monthOverMonthChange {
                        Text(change)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                // Compact metrics
                VStack(spacing: 12) {
                    CompactMetricRow(
                        icon: "arrow.up.circle.fill",
                        iconColor: .progressGreen,
                        label: "Monthly Savings",
                        value: formatCurrency(healthMetrics.monthlySavings),
                        change: savingsChange
                    )

                    CompactMetricRow(
                        icon: "shield.fill",
                        iconColor: .stableBlue,
                        label: "Emergency Fund",
                        value: "\(String(format: "%.1f", healthMetrics.emergencyFundMonthsCovered)) months",
                        change: emergencyFundChange
                    )

                    if healthMetrics.monthlyDebtPayments > 0 {
                        CompactMetricRow(
                            icon: "creditcard.fill",
                            iconColor: .opportunityOrange,
                            label: "Debt Payments",
                            value: formatCurrency(healthMetrics.monthlyDebtPayments),
                            change: nil
                        )
                    }
                }

                // View full report button
                Button {
                    onViewFullReport()
                } label: {
                    HStack {
                        Text("View Full Health Report")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Image(systemName: "arrow.right.circle")
                    }
                    .foregroundColor(.stableBlue)
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Computed Properties

    private var monthOverMonthChange: String? {
        guard let previous = previousMetrics else { return nil }

        let savingsChange = healthMetrics.monthlySavings - previous.monthlySavings

        // Only show if change is meaningful (>$10)
        if abs(savingsChange) < 10 {
            return "Stable this month"
        }

        let direction = savingsChange > 0 ? "up" : "down"
        return "Savings \(direction) \(formatCurrency(abs(savingsChange))) from last month"
    }

    private var savingsChange: String? {
        guard let previous = previousMetrics else { return nil }
        let change = healthMetrics.monthlySavings - previous.monthlySavings

        // Only show if meaningful change
        if abs(change) < 10 { return nil }

        return change > 0
            ? "↑ \(formatCurrency(change))"
            : "↓ \(formatCurrency(abs(change)))"
    }

    private var emergencyFundChange: String? {
        guard let previous = previousMetrics else { return nil }
        let change = healthMetrics.emergencyFundMonthsCovered - previous.emergencyFundMonthsCovered

        // Only show if meaningful change (>0.1 months)
        if abs(change) < 0.1 { return nil }

        return change > 0
            ? "↑ \(String(format: "%.1f", change)) mo"
            : "↓ \(String(format: "%.1f", abs(change))) mo"
    }

    // MARK: - Helper Methods

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Compact Metric Row

/// Compact row for displaying a single metric in the dashboard section
struct CompactMetricRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let change: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor.gradient)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Spacer()

            if let change = change {
                Text(change)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct FinancialHealthDashboardSection_Previews: PreviewProvider {
    static var previews: some View {
        let currentMetrics = FinancialHealthMetrics(
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

        let previousMetrics = FinancialHealthMetrics(
            monthlySavings: 650,
            monthlySavingsTrend: .stable,
            emergencyFundMonthsCovered: 4.0,
            emergencyFundTarget: 18000,
            monthlyIncome: 5000,
            incomeStability: .stable,
            monthlyDebtPayments: 400,
            monthsToDebtFree: 26,
            discretionarySpending: 650,
            essentialSpending: 3000,
            spendingTrend: .stable,
            healthScore: 70,
            savingsRate: 0.13,
            debtToIncomeRatio: 0.08,
            calculatedAt: Calendar.current.date(byAdding: .month, value: -1, to: Date())!,
            analysisMonths: 6
        )

        VStack {
            // With previous metrics (shows changes)
            FinancialHealthDashboardSection(
                healthMetrics: currentMetrics,
                previousMetrics: previousMetrics,
                onViewFullReport: { print("View full report tapped") }
            )
            .padding()

            Spacer()

            // Without previous metrics (first time)
            FinancialHealthDashboardSection(
                healthMetrics: currentMetrics,
                previousMetrics: nil,
                onViewFullReport: { print("View full report tapped") }
            )
            .padding()
        }
        .background(Color(.systemBackground))
    }
}
#endif

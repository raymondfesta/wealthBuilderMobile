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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.progressGreen)

                    Text("Analysis Complete")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Based on \(snapshot.metadata.monthsAnalyzed) months of data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)

                // Card 1: Monthly Money Flow
                MonthlyFlowCard(
                    flow: snapshot.monthlyFlow,
                    onDrillDown: onDrillDown
                )

                // Card 2: Financial Position
                FinancialPositionCard(
                    position: snapshot.position,
                    monthlyExpenses: snapshot.monthlyFlow.essentialExpenses,
                    onDrillDown: onDrillDown
                )

                // Validation indicator if needed
                if snapshot.metadata.transactionsNeedingValidation > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.opportunityOrange)
                        Text("\(snapshot.metadata.transactionsNeedingValidation) transactions need review")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal)
        }
        .safeAreaInset(edge: .bottom) {
            // CTA Button - Green pill with glow (Figma)
            Button(action: onSeePlan) {
                Text("Create my allocation plan")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "#0B0D10"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 6)
                    .shadow(color: Color.green.opacity(0.35), radius: 12, x: 0, y: 0)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Monthly Flow Card

private struct MonthlyFlowCard: View {
    let flow: MonthlyFlow
    let onDrillDown: (AnalysisCompleteView.DrillDownType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Monthly Money Flow")
                .font(.headline)

            VStack(spacing: 0) {
                // Income row
                FlowRow(
                    label: "Income",
                    value: flow.income,
                    isPositive: true,
                    showChevron: true
                ) {
                    onDrillDown(.income)
                }

                Divider()

                // Essential Expenses row
                FlowRow(
                    label: "Essential Expenses",
                    value: -flow.essentialExpenses,
                    isPositive: false,
                    showChevron: true
                ) {
                    onDrillDown(.expenses)
                }

                Divider()

                // Debt Minimums row
                FlowRow(
                    label: "Debt Minimums",
                    value: -flow.debtMinimums,
                    isPositive: false,
                    showChevron: true
                ) {
                    onDrillDown(.debtMinimums)
                }

                // To Allocate row (highlighted with top border)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(height: 1)
                        .padding(.top, 8)

                    HStack {
                        Text("To Allocate")
                            .font(.headline)
                            .foregroundColor(.green)

                        Spacer()

                        Text(formatCurrency(flow.discretionaryIncome))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Financial Position Card

private struct FinancialPositionCard: View {
    let position: FinancialPosition
    let monthlyExpenses: Double
    let onDrillDown: (AnalysisCompleteView.DrillDownType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Financial Position")
                .font(.headline)

            VStack(spacing: 0) {
                // Emergency Fund row
                PositionRow(
                    icon: "shield.fill",
                    iconColor: .stableBlue,
                    label: "Emergency Fund",
                    value: position.emergencyCash,
                    subtitle: "\(formattedMonths) months coverage",
                    showChevron: true
                ) {
                    onDrillDown(.emergencyFund)
                }

                Divider()

                // Total Debt row
                PositionRow(
                    icon: "creditcard.fill",
                    iconColor: .opportunityOrange,
                    label: "Total Debt",
                    value: position.totalDebt,
                    subtitle: nil,
                    showChevron: true
                ) {
                    onDrillDown(.debt)
                }

                Divider()

                // Investments row
                PositionRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .wealthPurple,
                    label: "Investments",
                    value: position.investmentBalances,
                    subtitle: contributionsSubtitle,
                    showChevron: true
                ) {
                    onDrillDown(.investments)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var formattedMonths: String {
        let months = position.emergencyFundMonths(monthlyExpenses: monthlyExpenses)
        if months >= 1 {
            return String(format: "%.1f", months)
        } else {
            return "< 1"
        }
    }

    private var contributionsSubtitle: String? {
        guard position.monthlyInvestmentContributions > 0 else { return nil }
        return "Contributing \(formatCurrency(position.monthlyInvestmentContributions))/mo"
    }
}

// MARK: - Row Components

private struct FlowRow: View {
    let label: String
    let value: Double
    let isPositive: Bool
    let showChevron: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .foregroundColor(.primary)

                Spacer()

                Text(formatCurrency(value))
                    .foregroundColor(isPositive ? .primary : .secondary)

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct PositionRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: Double
    let subtitle: String?
    let showChevron: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .foregroundColor(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(formatCurrency(abs(value)))
                    .foregroundColor(.primary)

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
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
struct AnalysisCompleteView_Previews: PreviewProvider {
    static var previews: some View {
        AnalysisCompleteView(
            snapshot: AnalysisSnapshot(
                monthlyFlow: MonthlyFlow(
                    income: 5000,
                    essentialExpenses: 3000,
                    debtMinimums: 200
                ),
                position: FinancialPosition(
                    emergencyCash: 12000,
                    totalDebt: 5000,
                    investmentBalances: 45000,
                    monthlyInvestmentContributions: 500
                ),
                metadata: AnalysisMetadata(
                    monthsAnalyzed: 6,
                    accountsConnected: 3,
                    transactionsAnalyzed: 245,
                    transactionsNeedingValidation: 5,
                    lastUpdated: Date()
                )
            ),
            onSeePlan: {},
            onDrillDown: { _ in }
        )
    }
}
#endif

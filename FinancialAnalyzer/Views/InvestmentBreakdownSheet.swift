import SwiftUI

/// Shows detailed breakdown of investment accounts
/// Displayed when user taps "Investments" in AnalysisCompleteView
struct InvestmentBreakdownSheet: View {
    let accounts: [BankAccount]
    let totalInvested: Double
    let monthlyContributions: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Summary section
                    summarySection

                    // Investment accounts breakdown
                    accountsSection

                    // Explanation footer
                    explanationSection
                }
                .padding(DesignTokens.Spacing.md)
            }
            .primaryBackgroundGradient()
            .navigationTitle("Investments")
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
        GlassmorphicCard(title: "Total Invested", showDivider: false) {
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack {
                    Text(formatCurrency(totalInvested))
                        .titleValueStyle()

                    Spacer()

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(DesignTokens.Colors.wealthPurple)
                }

                // Monthly contributions badge
                if monthlyContributions > 0 {
                    contributionsBadge
                }
            }
        }
    }

    private var contributionsBadge: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(DesignTokens.Colors.progressGreen)

            Text("\(formatCurrency(monthlyContributions))/mo contributions")
                .subheadlineStyle()

            Spacer()

            Text("Keep it up!")
                .captionStyle(color: DesignTokens.Colors.progressGreen)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.progressGreen.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        GlassmorphicCard(title: "Investment Accounts") {
            VStack(spacing: 0) {
                ForEach(investmentAccounts) { account in
                    InvestmentAccountRow(account: account, totalInvested: totalInvested)

                    if account.id != investmentAccounts.last?.id {
                        Rectangle()
                            .fill(DesignTokens.Colors.divider)
                            .frame(height: 1)
                    }
                }

                if !investmentAccounts.isEmpty {
                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(height: 1)
                        .padding(.vertical, DesignTokens.Spacing.xs)

                    // Total row
                    HStack {
                        Text("Total")
                            .headlineStyle()
                        Spacer()
                        Text(formatCurrency(calculatedTotal))
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
                Text("Investment growth")
                    .headlineStyle()

                Text("Consistent investing over time harnesses the power of compound growth. Even small regular contributions can grow significantly over decades.")
                    .captionStyle()

                if monthlyContributions == 0 {
                    Text("Consider setting up automatic contributions to build wealth over time.")
                        .captionStyle(color: DesignTokens.Colors.opportunityOrange)
                        .padding(.top, DesignTokens.Spacing.xxs)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var investmentAccounts: [BankAccount] {
        accounts.filter { $0.isInvestment }
    }

    private var calculatedTotal: Double {
        investmentAccounts.reduce(0) { $0 + ($1.currentBalance ?? 0) }
    }
}

// MARK: - Investment Account Row

private struct InvestmentAccountRow: View {
    let account: BankAccount
    let totalInvested: Double

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: accountIcon)
                .font(.title3)
                .foregroundColor(DesignTokens.Colors.wealthPurple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Text(accountType)
                    .captionStyle()
            }

            Spacer()

            Text(formatCurrency(account.currentBalance ?? 0))
                .headlineStyle()
                .monospacedDigit()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var accountIcon: String {
        let subtype = account.subtype?.lowercased() ?? ""
        if subtype.contains("401") || subtype.contains("retirement") { return "building.columns.fill" }
        if subtype.contains("ira") { return "shield.fill" }
        if subtype.contains("brokerage") { return "chart.bar.fill" }
        return "chart.line.uptrend.xyaxis"
    }

    private var accountType: String {
        account.subtype?.capitalized ?? "Investment"
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
struct InvestmentBreakdownSheet_Previews: PreviewProvider {
    static var previewAccounts: [BankAccount] {
        [
            BankAccount(
                id: "inv-1", itemId: "item-2", name: "Vanguard Brokerage",
                type: "investment", subtype: "brokerage", mask: "5566",
                currentBalance: 42500
            ),
            BankAccount(
                id: "inv-2", itemId: "item-2", name: "Fidelity 401(k)",
                type: "investment", subtype: "401k", mask: "1122",
                currentBalance: 68750
            ),
            BankAccount(
                id: "inv-3", itemId: "item-3", name: "Roth IRA",
                type: "investment", subtype: "ira", mask: "9900",
                currentBalance: 15200
            ),
        ]
    }

    static var previews: some View {
        InvestmentBreakdownSheet(
            accounts: previewAccounts,
            totalInvested: 126450,
            monthlyContributions: 750
        )
        .preferredColorScheme(.dark)
    }
}
#endif

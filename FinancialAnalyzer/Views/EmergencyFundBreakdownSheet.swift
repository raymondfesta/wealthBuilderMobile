import SwiftUI

/// Shows detailed breakdown of emergency fund accounts
/// Displayed when user taps "Emergency Fund" in AnalysisCompleteView
struct EmergencyFundBreakdownSheet: View {
    let accounts: [BankAccount]
    let totalCash: Double
    let monthsCovered: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Summary section
                    summarySection

                    // Contributing accounts
                    accountsSection

                    // Explanation footer
                    explanationSection
                }
                .padding(DesignTokens.Spacing.md)
            }
            .primaryBackgroundGradient()
            .navigationTitle("Emergency Fund")
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
        GlassmorphicCard(title: "Total Emergency Fund", showDivider: false) {
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack {
                    Text(formatCurrency(totalCash))
                        .titleValueStyle()

                    Spacer()

                    Image(systemName: "shield.fill")
                        .font(.largeTitle)
                        .foregroundColor(DesignTokens.Colors.stableBlue)
                }

                // Coverage badge
                coverageBadge
            }
        }
    }

    private var coverageBadge: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: coverageIcon)
                .foregroundColor(coverageColor)

            Text(coverageText)
                .subheadlineStyle()

            Spacer()

            if monthsCovered < 3 {
                Text("Build more")
                    .captionStyle(color: DesignTokens.Colors.opportunityOrange)
            } else if monthsCovered >= 6 {
                Text("Well funded")
                    .captionStyle(color: DesignTokens.Colors.progressGreen)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(coverageColor.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }

    private var coverageIcon: String {
        if monthsCovered >= 6 { return "checkmark.shield.fill" }
        if monthsCovered >= 3 { return "shield.lefthalf.filled" }
        return "exclamationmark.shield"
    }

    private var coverageColor: Color {
        if monthsCovered >= 6 { return DesignTokens.Colors.progressGreen }
        if monthsCovered >= 3 { return DesignTokens.Colors.accentPrimary }
        return DesignTokens.Colors.opportunityOrange
    }

    private var coverageText: String {
        let months = String(format: "%.1f", monthsCovered)
        return "\(months) months of expenses covered"
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        GlassmorphicCard(title: "Contributing Accounts") {
            VStack(spacing: 0) {
                ForEach(cashAccounts) { account in
                    CashAccountRow(account: account, totalCash: totalCash)

                    if account.id != cashAccounts.last?.id {
                        Rectangle()
                            .fill(DesignTokens.Colors.divider)
                            .frame(height: 1)
                    }
                }

                if !cashAccounts.isEmpty {
                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(height: 1)
                        .padding(.vertical, DesignTokens.Spacing.xs)

                    // Total row
                    HStack {
                        Text("Total")
                            .headlineStyle()
                        Spacer()
                        Text(formatCurrency(totalCash))
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
                Text("Emergency fund guidance")
                    .headlineStyle()

                Text("Financial experts recommend keeping 3-6 months of essential expenses in easily accessible accounts. This provides a safety net for unexpected events like job loss or medical emergencies.")
                    .captionStyle()

                if monthsCovered < 3 {
                    Text("Consider prioritizing building your emergency fund before other savings goals.")
                        .captionStyle(color: DesignTokens.Colors.opportunityOrange)
                        .padding(.top, DesignTokens.Spacing.xxs)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var cashAccounts: [BankAccount] {
        accounts.filter { $0.isDepository }
    }
}

// MARK: - Cash Account Row

private struct CashAccountRow: View {
    let account: BankAccount
    let totalCash: Double

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: accountIcon)
                .font(.title3)
                .foregroundColor(DesignTokens.Colors.stableBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Text(account.subtype ?? account.type)
                    .captionStyle()
            }

            Spacer()

            Text(formatCurrency(account.availableBalance ?? account.currentBalance ?? 0))
                .headlineStyle()
                .monospacedDigit()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var accountIcon: String {
        let subtype = account.subtype?.lowercased() ?? ""
        if subtype.contains("saving") { return "banknote.fill" }
        if subtype.contains("checking") { return "creditcard.fill" }
        return "building.columns.fill"
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
struct EmergencyFundBreakdownSheet_Previews: PreviewProvider {
    static var previewAccounts: [BankAccount] {
        [
            BankAccount(
                id: "chk-1", itemId: "item-1", name: "Primary Checking",
                type: "depository", subtype: "checking", mask: "4521",
                currentBalance: 3200, availableBalance: 3100
            ),
            BankAccount(
                id: "sav-1", itemId: "item-1", name: "Emergency Savings",
                type: "depository", subtype: "savings", mask: "7890",
                currentBalance: 18500, availableBalance: 18500
            ),
            BankAccount(
                id: "sav-2", itemId: "item-2", name: "High-Yield Savings",
                type: "depository", subtype: "savings", mask: "2233",
                currentBalance: 4300, availableBalance: 4300
            ),
        ]
    }

    static var previews: some View {
        EmergencyFundBreakdownSheet(
            accounts: previewAccounts,
            totalCash: 25900,
            monthsCovered: 7.4
        )
        .preferredColorScheme(.dark)
    }
}
#endif

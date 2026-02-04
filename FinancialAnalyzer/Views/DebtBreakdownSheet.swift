import SwiftUI

/// Shows detailed breakdown of all debt accounts
/// Displayed when user taps "Total Debt" in AnalysisCompleteView
struct DebtBreakdownSheet: View {
    let accounts: [BankAccount]
    let totalDebt: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Summary section
                    summarySection

                    // Debt accounts breakdown
                    debtAccountsSection

                    // Explanation footer
                    explanationSection
                }
                .padding(DesignTokens.Spacing.md)
            }
            .primaryBackgroundGradient()
            .navigationTitle("Debt Breakdown")
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
        GlassmorphicCard(title: "Total Debt", showDivider: false) {
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack {
                    Text(formatCurrency(totalDebt))
                        .titleValueStyle()

                    Spacer()

                    Image(systemName: "creditcard.fill")
                        .font(.largeTitle)
                        .foregroundColor(DesignTokens.Colors.opportunityOrange)
                }

                // APR badge if we have high-interest debt
                if hasHighInterestDebt {
                    highInterestBadge
                }
            }
        }
    }

    private var highInterestBadge: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DesignTokens.Colors.opportunityOrange)

            Text("High-interest debt detected")
                .subheadlineStyle()

            Spacer()

            Text("Prioritize payoff")
                .captionStyle(color: DesignTokens.Colors.opportunityOrange)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.opportunityOrange.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }

    // MARK: - Debt Accounts Section

    private var debtAccountsSection: some View {
        GlassmorphicCard(title: "Debt Accounts") {
            VStack(spacing: 0) {
                ForEach(debtAccounts) { account in
                    DebtAccountDetailRow(account: account, totalDebt: totalDebt)

                    if account.id != debtAccounts.last?.id {
                        Rectangle()
                            .fill(DesignTokens.Colors.divider)
                            .frame(height: 1)
                    }
                }

                if !debtAccounts.isEmpty {
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
                Text("Debt payoff strategy")
                    .headlineStyle()

                Text("Focus on high-interest debt first (avalanche method) to minimize total interest paid. Alternatively, pay off smallest balances first (snowball method) for psychological wins.")
                    .captionStyle()

                if hasHighInterestDebt {
                    Text("Consider paying more than minimums on high-APR accounts to reduce interest costs.")
                        .captionStyle(color: DesignTokens.Colors.opportunityOrange)
                        .padding(.top, DesignTokens.Spacing.xxs)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var debtAccounts: [BankAccount] {
        accounts.filter { $0.isCredit || $0.isLoan }
    }

    private var calculatedTotal: Double {
        debtAccounts.reduce(0) { $0 + abs($1.currentBalance ?? 0) }
    }

    private var hasHighInterestDebt: Bool {
        debtAccounts.contains { ($0.apr ?? 0) > 0.15 }
    }
}

// MARK: - Debt Account Detail Row

private struct DebtAccountDetailRow: View {
    let account: BankAccount
    let totalDebt: Double

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: accountIcon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(debtType)
                        .captionStyle()

                    if let apr = account.apr, apr > 0 {
                        Text("\(String(format: "%.1f", apr * 100))% APR")
                            .captionStyle(color: apr > 0.15 ? DesignTokens.Colors.opportunityOrange : DesignTokens.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(abs(account.currentBalance ?? 0)))
                    .headlineStyle()
                    .monospacedDigit()

                if let minimum = estimatedMinimum {
                    Text("Min: \(formatCurrency(minimum))")
                        .captionStyle()
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var accountIcon: String {
        if account.isCredit { return "creditcard.fill" }
        let subtype = account.subtype?.lowercased() ?? ""
        if subtype.contains("student") { return "graduationcap.fill" }
        if subtype.contains("auto") { return "car.fill" }
        if subtype.contains("mortgage") { return "house.fill" }
        return "banknote.fill"
    }

    private var iconColor: Color {
        if (account.apr ?? 0) > 0.15 {
            return DesignTokens.Colors.opportunityOrange
        }
        return DesignTokens.Colors.accentSecondary
    }

    private var debtType: String {
        if account.isCredit { return "Credit Card" }
        return account.subtype?.capitalized ?? "Loan"
    }

    private var estimatedMinimum: Double? {
        if let minimum = account.minimumPayment { return minimum }
        let balance = abs(account.currentBalance ?? 0)
        guard balance > 0 else { return nil }

        if account.isCredit {
            return max(25, balance * 0.025)
        } else {
            let subtype = account.subtype?.lowercased() ?? ""
            if subtype.contains("student") { return balance * 0.01 }
            if subtype.contains("auto") { return balance * 0.018 }
            if subtype.contains("mortgage") { return balance * 0.005 }
            return balance * 0.015
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
struct DebtBreakdownSheet_Previews: PreviewProvider {
    static var previewAccounts: [BankAccount] {
        [
            BankAccount(
                id: "cc-1", itemId: "item-1", name: "Chase Sapphire",
                type: "credit", subtype: "credit card", mask: "3344",
                currentBalance: 1850, limit: 10000, minimumPayment: 35, apr: 0.2199
            ),
            BankAccount(
                id: "cc-2", itemId: "item-1", name: "Amex Blue Cash",
                type: "credit", subtype: "credit card", mask: "8821",
                currentBalance: 3200, limit: 15000, minimumPayment: 64, apr: 0.1899
            ),
            BankAccount(
                id: "loan-1", itemId: "item-1", name: "Auto Loan",
                type: "loan", subtype: "auto", mask: "9012",
                currentBalance: 14500, minimumPayment: 350, apr: 0.069
            ),
            BankAccount(
                id: "loan-2", itemId: "item-1", name: "Student Loan",
                type: "loan", subtype: "student", mask: "5500",
                currentBalance: 28000, minimumPayment: 280, apr: 0.045
            ),
        ]
    }

    static var previews: some View {
        DebtBreakdownSheet(
            accounts: previewAccounts,
            totalDebt: 47550
        )
        .preferredColorScheme(.dark)
    }
}
#endif

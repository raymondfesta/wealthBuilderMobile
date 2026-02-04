import SwiftUI

/// Shows detailed breakdown of monthly debt minimum payments
/// Displayed when user taps "Debt Minimums" in AnalysisCompleteView
struct DebtMinimumsBreakdownSheet: View {
    let accounts: [BankAccount]
    let monthlyMinimums: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Summary section
                    summarySection

                    // Minimum payments breakdown
                    minimumsSection

                    // Explanation footer
                    explanationSection
                }
                .padding(DesignTokens.Spacing.md)
            }
            .primaryBackgroundGradient()
            .navigationTitle("Debt Minimums")
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
        GlassmorphicCard(title: "Monthly Minimums", showDivider: false) {
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack {
                    Text(formatCurrency(monthlyMinimums))
                        .titleValueStyle()

                    Spacer()

                    Image(systemName: "calendar.badge.minus")
                        .font(.largeTitle)
                        .foregroundColor(DesignTokens.Colors.opportunityOrange)
                }

                // Required payment badge
                requiredPaymentBadge
            }
        }
    }

    private var requiredPaymentBadge: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(DesignTokens.Colors.accentPrimary)

            Text("Required monthly payment")
                .subheadlineStyle()

            Spacer()

            Text("Due each cycle")
                .captionStyle()
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.accentPrimary.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }

    // MARK: - Minimums Section

    private var minimumsSection: some View {
        GlassmorphicCard(title: "Payment Breakdown") {
            VStack(spacing: 0) {
                ForEach(debtAccounts) { account in
                    MinimumPaymentRow(account: account)

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
                        Text("Total Minimums")
                            .headlineStyle()
                        Spacer()
                        Text(formatCurrency(calculatedMinimums))
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
                Text("How minimums are calculated")
                    .headlineStyle()

                Text("Minimum payments are based on your account balances. Credit cards typically require 2-3% of balance (minimum $25). Loans vary by type and term length.")
                    .captionStyle()

                Text("Paying only minimums extends payoff time and increases total interest paid. Consider paying extra when possible.")
                    .captionStyle(color: DesignTokens.Colors.opportunityOrange)
                    .padding(.top, DesignTokens.Spacing.xxs)
            }
        }
    }

    // MARK: - Computed Properties

    private var debtAccounts: [BankAccount] {
        accounts.filter { $0.isCredit || $0.isLoan }
    }

    private var calculatedMinimums: Double {
        debtAccounts.reduce(0) { total, account in
            total + estimatedMinimum(for: account)
        }
    }

    private func estimatedMinimum(for account: BankAccount) -> Double {
        if let minimum = account.minimumPayment { return minimum }
        let balance = abs(account.currentBalance ?? 0)
        guard balance > 0 else { return 0 }

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

// MARK: - Minimum Payment Row

private struct MinimumPaymentRow: View {
    let account: BankAccount

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: accountIcon)
                .font(.title3)
                .foregroundColor(DesignTokens.Colors.accentSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Text("Balance: \(formatCurrency(abs(account.currentBalance ?? 0)))")
                    .captionStyle()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(estimatedMinimum))
                    .headlineStyle()
                    .monospacedDigit()

                Text("minimum")
                    .captionStyle()
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

    private var estimatedMinimum: Double {
        if let minimum = account.minimumPayment { return minimum }
        let balance = abs(account.currentBalance ?? 0)
        guard balance > 0 else { return 0 }

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
struct DebtMinimumsBreakdownSheet_Previews: PreviewProvider {
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
        DebtMinimumsBreakdownSheet(
            accounts: previewAccounts,
            monthlyMinimums: 729
        )
        .preferredColorScheme(.dark)
    }
}
#endif

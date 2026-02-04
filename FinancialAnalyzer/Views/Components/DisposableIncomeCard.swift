import SwiftUI

/// Card showing disposable income with soft warning for negative amounts
struct DisposableIncomeCard: View {
    let disposableIncome: Double
    let monthlyIncome: Double
    let monthlyExpenses: Double
    let hasFlaggedTransactions: Bool
    let onReviewTransactions: () -> Void
    let onProceedAnyway: () -> Void

    private var isNegative: Bool {
        disposableIncome < 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: isNegative ? "exclamationmark.triangle.fill" : "sparkles")
                    .foregroundColor(isNegative ? DesignTokens.Colors.opportunityOrange : DesignTokens.Colors.wealthPurple)

                Text("Available to Allocate")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()
            }

            // Amount
            Text(formatCurrency(disposableIncome))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(isNegative ? DesignTokens.Colors.opportunityOrange : DesignTokens.Colors.wealthPurple)

            // Calculation breakdown
            HStack(spacing: 4) {
                Text("Income")
                    .foregroundColor(.secondary)
                Text(formatCurrency(monthlyIncome))
                    .fontWeight(.medium)
                Text("-")
                    .foregroundColor(.secondary)
                Text("Expenses")
                    .foregroundColor(.secondary)
                Text(formatCurrency(monthlyExpenses))
                    .fontWeight(.medium)
            }
            .font(.caption)

            // Warning section (only if negative)
            if isNegative {
                warningSection
            } else {
                // Positive messaging
                Text("This is what you have available to put toward savings, investments, and debt paydown.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your expenses exceed your income")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.opportunityOrange)

            Text("This usually means:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                bulletPoint("Some transfers were counted as expenses")
                bulletPoint("One-time purchases skewed the average")
                bulletPoint("Income wasn't fully captured")
            }

            if hasFlaggedTransactions {
                Text("Review the flagged transactions above to fix this.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            // Action buttons
            HStack(spacing: 12) {
                if hasFlaggedTransactions {
                    Button(action: onReviewTransactions) {
                        Text("Review Transactions")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .tint(DesignTokens.Colors.opportunityOrange)
                }

                Button(action: onProceedAnyway) {
                    Text("Proceed Anyway")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.Colors.opportunityOrange.opacity(0.1))
        )
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.secondary)
        }
        .font(.caption)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let absAmount = abs(amount)
        let result = formatter.string(from: NSNumber(value: absAmount)) ?? "$0"
        return amount < 0 ? "-\(result)" : result
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Positive
        DisposableIncomeCard(
            disposableIncome: 1300,
            monthlyIncome: 4500,
            monthlyExpenses: 3200,
            hasFlaggedTransactions: false,
            onReviewTransactions: {},
            onProceedAnyway: {}
        )

        // Negative
        DisposableIncomeCard(
            disposableIncome: -850,
            monthlyIncome: 4500,
            monthlyExpenses: 5350,
            hasFlaggedTransactions: true,
            onReviewTransactions: {},
            onProceedAnyway: {}
        )
    }
    .padding()
}

import SwiftUI

/// Inline section showing transactions that need user review
/// Surfaces potential transfers and miscategorized transactions with quick actions
struct TransactionReviewSection: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var selectedTransaction: Transaction?

    private var reviewableTransactions: [Transaction] {
        viewModel.transactionsNeedingTransferReview
            .sorted { abs($0.amount) > abs($1.amount) }  // Largest impact first
    }

    private var displayedTransactions: [Transaction] {
        Array(reviewableTransactions.prefix(5))
    }

    var body: some View {
        if !reviewableTransactions.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DesignTokens.Colors.opportunityOrange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(reviewableTransactions.count) Transaction\(reviewableTransactions.count == 1 ? "" : "s") to Review")
                            .font(.headline)

                        Text("These might be transfers between your accounts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Impact summary
                if viewModel.flaggedTransactionsMonthlyImpact > 0 {
                    HStack {
                        Text("Potential monthly impact:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(formatCurrency(viewModel.flaggedTransactionsMonthlyImpact))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Colors.opportunityOrange)
                    }
                }

                // Transaction cards (show up to 5)
                VStack(spacing: 8) {
                    ForEach(displayedTransactions) { transaction in
                        ReviewableTransactionCard(
                            transaction: transaction,
                            similarCount: viewModel.countMatchingTransactions(transaction),
                            onExclude: { applyToSimilar in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    _ = viewModel.markAsExcluded(transaction, applyToSimilar: applyToSimilar)
                                }
                            },
                            onKeep: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    _ = viewModel.confirmAsExpense(transaction)
                                }
                            },
                            onTapDetails: {
                                selectedTransaction = transaction
                            }
                        )
                    }

                    // "More" indicator
                    if reviewableTransactions.count > 5 {
                        HStack {
                            Spacer()
                            Text("+ \(reviewableTransactions.count - 5) more to review")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding()
            .background {
                let warningColor: Color = .opportunityOrange
                RoundedRectangle(cornerRadius: 12)
                    .fill(warningColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(warningColor.opacity(0.3), lineWidth: 1)
                    )
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionValidationSheet(
                    transaction: transaction,
                    matchingCount: viewModel.countMatchingTransactions(transaction),
                    onValidate: { correctedCategory, applyToAll in
                        viewModel.validateTransaction(
                            transaction,
                            correctedCategory: correctedCategory,
                            applyToAll: applyToAll
                        )
                        // Recalculate if excluded
                        if correctedCategory == .excluded {
                            viewModel.recalculateAnalysis()
                        }
                    }
                )
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Reviewable Transaction Card

/// Individual transaction card with quick actions
struct ReviewableTransactionCard: View {
    let transaction: Transaction
    let similarCount: Int
    let onExclude: (Bool) -> Void  // Bool = apply to similar
    let onKeep: () -> Void
    let onTapDetails: () -> Void

    @State private var showingSimilarOption = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Transaction info row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.merchantName ?? transaction.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let pfc = transaction.personalFinanceCategory {
                            Text("\u{2022}")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCategory(pfc.detailed))
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Text(formatCurrency(abs(transaction.amount)))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            // Quick action buttons
            HStack(spacing: 8) {
                // "It's a Transfer" button
                Button {
                    if similarCount > 0 {
                        showingSimilarOption = true
                    } else {
                        onExclude(false)
                    }
                } label: {
                    Label("Transfer / Exclude", systemImage: "eye.slash")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                // "It's an Expense" button
                Button {
                    onKeep()
                } label: {
                    Label("It's an Expense", systemImage: "checkmark")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Spacer()

                // Details button
                Button(action: onTapDetails) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
        .confirmationDialog(
            "Apply to similar transactions?",
            isPresented: $showingSimilarOption,
            titleVisibility: .visible
        ) {
            Button("Exclude just this one") {
                onExclude(false)
            }
            Button("Exclude all \(similarCount + 1) similar") {
                onExclude(true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Found \(similarCount) other similar transaction\(similarCount == 1 ? "" : "s") from the same source.")
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func formatCategory(_ detailed: String) -> String {
        detailed
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }
}

// MARK: - Preview

#Preview {
    TransactionReviewSection(
        viewModel: FinancialViewModel()
    )
    .padding()
}

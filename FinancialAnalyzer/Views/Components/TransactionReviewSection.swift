import SwiftUI

/// Clean summary card for transactions needing review
/// Shows count and impact with CTA to dedicated review screen
struct TransactionReviewSection: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var showingReviewSheet = false

    private var reviewableTransactions: [Transaction] {
        viewModel.transactionsNeedingTransferReview
            .sorted { abs($0.amount) > abs($1.amount) }
    }

    var body: some View {
        if !reviewableTransactions.isEmpty {
            Button(action: { showingReviewSheet = true }) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(DesignTokens.Colors.opportunityOrange)
                        .frame(width: 40)

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(reviewableTransactions.count) transaction\(reviewableTransactions.count == 1 ? "" : "s") need review")
                            .headlineStyle(color: DesignTokens.Colors.textPrimary)
                            .multilineTextAlignment(.leading)

                        if viewModel.flaggedTransactionsMonthlyImpact > 0 {
                            Text("May impact budget by \(formatCurrency(viewModel.flaggedTransactionsMonthlyImpact))/mo")
                                .subheadlineStyle(color: DesignTokens.Colors.textSecondary)
                        } else {
                            Text("Potential transfers between accounts")
                                .subheadlineStyle(color: DesignTokens.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .padding(DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignTokens.Colors.opportunityOrange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignTokens.Colors.opportunityOrange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingReviewSheet) {
                TransactionReviewSheet(viewModel: viewModel)
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

// MARK: - Transaction Review Sheet

/// Full-screen sheet for reviewing flagged transactions
struct TransactionReviewSheet: View {
    @ObservedObject var viewModel: FinancialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTransaction: Transaction?

    private var reviewableTransactions: [Transaction] {
        viewModel.transactionsNeedingTransferReview
            .sorted { abs($0.amount) > abs($1.amount) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // Impact summary
                    if viewModel.flaggedTransactionsMonthlyImpact > 0 {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Potential monthly impact")
                                .subheadlineStyle(color: DesignTokens.Colors.textSecondary)

                            Text(formatCurrency(viewModel.flaggedTransactionsMonthlyImpact))
                                .titleValueStyle(color: DesignTokens.Colors.opportunityOrange)
                        }
                        .padding(DesignTokens.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .primaryCardStyle()
                    }

                    // Explanation
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Why review these?")
                            .headlineStyle()

                        Text("These look like transfers between your accounts. Excluding them prevents counting the same money twice in your budget.")
                            .subheadlineStyle(color: DesignTokens.Colors.textSecondary)
                    }

                    // Transaction cards
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(reviewableTransactions) { transaction in
                            ReviewableTransactionCard(
                                transaction: transaction,
                                similarCount: viewModel.countMatchingTransactions(transaction),
                                onExclude: { applyToSimilar in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        _ = viewModel.markAsExcluded(transaction, applyToSimilar: applyToSimilar)
                                        // Auto-dismiss if all done
                                        if viewModel.transactionsNeedingTransferReview.isEmpty {
                                            dismiss()
                                        }
                                    }
                                },
                                onKeep: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        _ = viewModel.confirmAsExpense(transaction)
                                        // Auto-dismiss if all done
                                        if viewModel.transactionsNeedingTransferReview.isEmpty {
                                            dismiss()
                                        }
                                    }
                                },
                                onTapDetails: {
                                    selectedTransaction = transaction
                                }
                            )
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .primaryBackgroundGradient()
            .navigationTitle("Review Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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

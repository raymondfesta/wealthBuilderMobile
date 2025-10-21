import SwiftUI
import Charts

struct CategoryDetailView: View {
    let category: BucketCategory
    let amount: Double
    let summary: FinancialSummary
    let transactions: [Transaction]
    let accounts: [BankAccount]

    private var categoryTransactions: [Transaction] {
        TransactionAnalyzer.transactionsForBucket(category, from: transactions)
    }

    private var topContributors: [Transaction] {
        TransactionAnalyzer.topContributors(for: category, from: transactions, limit: 10)
    }

    private var contributingAccounts: [BankAccount] {
        TransactionAnalyzer.contributingAccounts(for: category, from: accounts)
    }

    private var monthlyTrends: [(Date, Double)] {
        let trends = TransactionAnalyzer.monthlyTrends(from: transactions, bucket: category)
        return trends.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Card
                headerCard

                // How It's Calculated Section
                calculationSection

                // Monthly Trend Chart
                if !monthlyTrends.isEmpty {
                    trendChartSection
                }

                // Key Contributors Section
                if isTransactionBased {
                    topContributorsSection
                } else if !contributingAccounts.isEmpty {
                    contributingAccountsSection
                }

                // All Transactions Section
                if !categoryTransactions.isEmpty {
                    allTransactionsSection
                }
            }
            .padding()
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Subviews

    private var headerCard: some View {
        VStack(spacing: 16) {
            Image(systemName: category.iconName)
                .font(.system(size: 60))
                .foregroundColor(categoryColor)

            VStack(spacing: 8) {
                Text(formattedAmount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(categoryColor)

                Text(category.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(categoryColor.opacity(0.1))
        )
    }

    private var calculationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It's Calculated")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(TransactionAnalyzer.calculationExplanation(for: category))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Specific breakdown for disposable income
                if category == .disposable {
                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        breakdownRow(
                            label: "Avg Monthly Income",
                            value: summary.avgMonthlyIncome,
                            color: .green
                        )
                        breakdownRow(
                            label: "Avg Monthly Expenses",
                            value: -summary.avgMonthlyExpenses,
                            color: .red
                        )

                        Divider()
                            .padding(.vertical, 4)

                        breakdownRow(
                            label: "Available to Spend",
                            value: summary.availableToSpend,
                            color: .purple,
                            isBold: true
                        )
                    }
                }

                // Analysis period
                if isTransactionBased {
                    Divider()
                        .padding(.vertical, 4)

                    HStack {
                        Text("Analysis Period:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(summary.monthsAnalyzed) months (\(summary.totalTransactions) transactions)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
        }
    }

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("6-Month Trend")
                .font(.headline)

            Chart {
                ForEach(monthlyTrends, id: \.0) { date, value in
                    LineMark(
                        x: .value("Month", date),
                        y: .value("Amount", value)
                    )
                    .foregroundStyle(categoryColor.gradient)

                    AreaMark(
                        x: .value("Month", date),
                        y: .value("Amount", value)
                    )
                    .foregroundStyle(categoryColor.opacity(0.2).gradient)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCurrency(amount))
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
        }
    }

    private var topContributorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Contributors")
                    .font(.headline)

                Spacer()

                Text("\(topContributors.count) of \(categoryTransactions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(topContributors, id: \.id) { transaction in
                    ContributorTransactionRow(transaction: transaction, category: category)
                }
            }
        }
    }

    private var contributingAccountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Contributing Accounts")
                    .font(.headline)

                Spacer()

                Text("\(contributingAccounts.count) accounts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(contributingAccounts, id: \.id) { account in
                    CategoryAccountRow(account: account)
                }
            }
        }
    }

    private var allTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Transactions")
                    .font(.headline)

                Spacer()

                Text("\(categoryTransactions.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(categoryTransactions.sorted(by: { $0.date > $1.date }).prefix(20), id: \.id) { transaction in
                    TransactionRow(transaction: transaction)
                }

                if categoryTransactions.count > 20 {
                    Text("Showing 20 of \(categoryTransactions.count) transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func breakdownRow(label: String, value: Double, color: Color, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? .subheadline.bold() : .subheadline)
                .foregroundColor(isBold ? .primary : .secondary)

            Spacer()

            Text(formatCurrency(value))
                .font(isBold ? .subheadline.bold() : .subheadline)
                .foregroundColor(color)
        }
    }

    // MARK: - Computed Properties

    private var isTransactionBased: Bool {
        category == .income || category == .expenses || category == .disposable
    }

    private var categoryColor: Color {
        switch category.color {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "mint": return .mint
        case "purple": return .purple
        default: return .gray
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let absValue = abs(value)
        let result = formatter.string(from: NSNumber(value: absValue)) ?? "$0"
        return value < 0 ? "-\(result)" : result
    }
}

// MARK: - Contributor Transaction Row

struct ContributorTransactionRow: View {
    let transaction: Transaction
    let category: BucketCategory

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Bar indicator
            Rectangle()
                .fill(transactionColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let merchantName = transaction.merchantName {
                        Text(merchantName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(transaction.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transactionColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }

    private var transactionColor: Color {
        category == .income ? .green : .primary
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2

        if category == .income {
            return formatter.string(from: NSNumber(value: abs(transaction.amount))) ?? "$0.00"
        } else {
            return formatter.string(from: NSNumber(value: transaction.amount)) ?? "$0.00"
        }
    }
}

// MARK: - Account Row

struct CategoryAccountRow: View {
    let account: BankAccount

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: accountIcon)
                .font(.title3)
                .foregroundColor(accountColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let mask = account.mask {
                    Text("••••\(mask)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let balance = account.currentBalance {
                    Text(formatCurrency(balance))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                if let available = account.availableBalance, available != account.currentBalance {
                    Text("Avail: \(formatCurrency(available))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }

    private var accountIcon: String {
        if account.isDepository {
            return "banknote.fill"
        } else if account.isCredit {
            return "creditcard.fill"
        } else if account.isLoan {
            return "doc.text.fill"
        } else if account.isInvestment {
            return "chart.line.uptrend.xyaxis"
        }
        return "dollarsign.circle.fill"
    }

    private var accountColor: Color {
        if account.isDepository {
            return .mint
        } else if account.isCredit {
            return .orange
        } else if account.isLoan {
            return .red
        } else if account.isInvestment {
            return .blue
        }
        return .gray
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

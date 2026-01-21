import SwiftUI

// MARK: - Income Detail Sheet

struct IncomeDetailSheet: View {
    let transactions: [Transaction]
    let monthlyAverage: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly Average")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(monthlyAverage))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.progressGreen)
                        }
                        Spacer()
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.progressGreen)
                    }
                    .padding(.vertical, 8)
                }

                // Transactions section
                Section("Income Sources") {
                    ForEach(incomeTransactions) { transaction in
                        AnalysisTransactionRow(transaction: transaction)
                    }
                }
            }
            .navigationTitle("Income Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var incomeTransactions: [Transaction] {
        transactions
            .filter { $0.bucketCategory == .income }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Expense Detail Sheet

struct ExpenseDetailSheet: View {
    let transactions: [Transaction]
    let monthlyAverage: Double
    let expenseBreakdown: ExpenseBreakdown?
    let onValidateTransaction: (Transaction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Summary section with confidence indicator
                summarySection

                // Category breakdown - use new 7-category if available
                if let breakdown = expenseBreakdown {
                    Section("Breakdown by Category") {
                        ForEach(breakdown.categories) { category in
                            HStack(spacing: 12) {
                                Image(systemName: category.icon)
                                    .font(.title3)
                                    .foregroundColor(Color(category.color))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                        .font(.subheadline)
                                    Text("\(Int(category.percentage(of: breakdown.total)))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(formatCurrency(category.amount))
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    // Legacy category breakdown (Plaid categories)
                    Section("By Category") {
                        ForEach(categoryBreakdown, id: \.category) { item in
                            HStack {
                                Text(item.category)
                                Spacer()
                                Text(formatCurrency(item.total))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Transactions needing validation
                if !transactionsNeedingValidation.isEmpty {
                    Section {
                        ForEach(transactionsNeedingValidation) { transaction in
                            Button {
                                onValidateTransaction(transaction)
                            } label: {
                                HStack {
                                    AnalysisTransactionRow(transaction: transaction)
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundColor(.opportunityOrange)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text("Needs Review")
                            Spacer()
                            Text("\(transactionsNeedingValidation.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // All transactions
                Section("All Expenses") {
                    ForEach(expenseTransactions.prefix(50)) { transaction in
                        AnalysisTransactionRow(transaction: transaction)
                    }
                    if expenseTransactions.count > 50 {
                        Text("+ \(expenseTransactions.count - 50) more")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Expense Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Average")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(monthlyAverage))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    Image(systemName: "cart.fill")
                        .font(.largeTitle)
                        .foregroundColor(.opportunityOrange)
                }

                // Confidence badge (if breakdown available)
                if let breakdown = expenseBreakdown {
                    let level = breakdown.confidenceLevel
                    HStack(spacing: 8) {
                        Image(systemName: level.iconName)
                            .foregroundColor(Color(level.systemColor))
                        Text("\(Int(breakdown.confidence * 100))% confident")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(level.systemColor).opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Computed Properties

    private var expenseTransactions: [Transaction] {
        transactions
            .filter { $0.bucketCategory == .expenses }
            .sorted { $0.date > $1.date }
    }

    private var transactionsNeedingValidation: [Transaction] {
        expenseTransactions.filter { $0.needsValidation }
    }

    private var categoryBreakdown: [(category: String, total: Double)] {
        var breakdown: [String: Double] = [:]
        for transaction in expenseTransactions {
            let category = transaction.category.first ?? "Uncategorized"
            breakdown[category, default: 0] += transaction.amount
        }
        return breakdown
            .map { (category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }
}

// MARK: - Debt Minimums Detail Sheet

struct DebtMinimumsDetailSheet: View {
    let accounts: [BankAccount]
    let monthlyMinimums: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly Minimums")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(monthlyMinimums))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        Image(systemName: "creditcard.fill")
                            .font(.largeTitle)
                            .foregroundColor(.opportunityOrange)
                    }
                    .padding(.vertical, 8)
                }

                // Debt accounts
                Section("Debt Accounts") {
                    ForEach(debtAccounts) { account in
                        DebtAccountRow(account: account)
                    }
                }

                // Explanation
                Section {
                    Text("Minimum payments are estimated based on account balances. Credit cards use 2.5% of balance, loans vary by type.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Debt Minimums")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var debtAccounts: [BankAccount] {
        accounts.filter { $0.isCredit || $0.isLoan }
    }
}

// MARK: - Emergency Fund Detail Sheet

struct EmergencyFundDetailSheet: View {
    let accounts: [BankAccount]
    let totalCash: Double
    let monthsCovered: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Emergency Fund")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(totalCash))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.stableBlue)
                            }
                            Spacer()
                            Image(systemName: "shield.fill")
                                .font(.largeTitle)
                                .foregroundColor(.stableBlue)
                        }

                        HStack {
                            Text("Coverage")
                            Spacer()
                            Text("\(String(format: "%.1f", monthsCovered)) months")
                                .fontWeight(.semibold)
                                .foregroundColor(.stableBlue)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Cash accounts
                Section("Contributing Accounts") {
                    ForEach(cashAccounts) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                Text(account.subtype ?? account.type)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(formatCurrency(account.availableBalance ?? account.currentBalance ?? 0))
                        }
                    }
                }
            }
            .navigationTitle("Emergency Fund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var cashAccounts: [BankAccount] {
        accounts.filter { $0.isDepository }
    }
}

// MARK: - Investment Detail Sheet

struct InvestmentDetailSheet: View {
    let accounts: [BankAccount]
    let totalInvested: Double
    let monthlyContributions: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Invested")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(totalInvested))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.wealthPurple)
                            }
                            Spacer()
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.largeTitle)
                                .foregroundColor(.wealthPurple)
                        }

                        if monthlyContributions > 0 {
                            HStack {
                                Text("Monthly Contributions")
                                Spacer()
                                Text(formatCurrency(monthlyContributions) + "/mo")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.wealthPurple)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Investment accounts
                Section("Investment Accounts") {
                    ForEach(investmentAccounts) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                Text(account.subtype ?? "Investment")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(formatCurrency(account.currentBalance ?? 0))
                        }
                    }
                }
            }
            .navigationTitle("Investments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var investmentAccounts: [BankAccount] {
        accounts.filter { $0.isInvestment }
    }
}

// MARK: - Supporting Views

private struct AnalysisTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName ?? transaction.name)
                    .lineLimit(1)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(abs(transaction.amount)))
                .foregroundColor(transaction.amount < 0 ? .progressGreen : .primary)
        }
    }
}

private struct DebtAccountRow: View {
    let account: BankAccount

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                Text(account.subtype ?? account.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(account.currentBalance ?? 0))
                Text("Min: \(formatCurrency(estimatedMinimum))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var estimatedMinimum: Double {
        let balance = account.currentBalance ?? 0
        guard balance > 0 else { return 0 }

        if account.isCredit {
            return max(25, balance * 0.025)
        } else {
            // Loan estimate
            let subtype = account.subtype?.lowercased() ?? ""
            switch subtype {
            case _ where subtype.contains("student"):
                return balance * 0.01
            case _ where subtype.contains("auto"):
                return balance * 0.018
            case _ where subtype.contains("mortgage"):
                return balance * 0.005
            default:
                return balance * 0.015
            }
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

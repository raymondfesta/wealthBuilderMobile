import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: FinancialViewModel
    @State private var selectedBucket: BucketCategory?

    init(viewModel: FinancialViewModel = FinancialViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Financial Buckets
                    if let summary = viewModel.summary {
                        bucketsGrid(summary: summary)
                    } else {
                        emptyState
                    }

                    // Recent Transactions
                    recentTransactionsSection

                    // Refresh Button
                    refreshButton
                }
                .padding()
            }
            .navigationTitle("Financial Overview")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.connectBankAccount(from: nil)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
        .task {
            await viewModel.refreshData()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Financial Summary")
                .font(.title2)
                .fontWeight(.bold)

            if let summary = viewModel.summary {
                Text("Analysis of \(summary.totalTransactions) transactions over \(summary.monthsAnalyzed) months")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Last updated: \(summary.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bucketsGrid(summary: FinancialSummary) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(BucketCategory.allCases, id: \.self) { bucket in
                BucketCard(
                    category: bucket,
                    amount: summary.bucketValue(for: bucket),
                    isSelected: selectedBucket == bucket
                )
                .onTapGesture {
                    selectedBucket = bucket
                    print("Tapped bucket: \(bucket.rawValue)")
                }
            }
        }
        .navigationDestination(item: $selectedBucket) { bucket in
            CategoryDetailView(
                category: bucket,
                amount: summary.bucketValue(for: bucket),
                summary: summary,
                transactions: viewModel.transactions,
                accounts: viewModel.accounts
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Financial Data")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Connect your bank account to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.connectBankAccount(from: nil)
                }
            } label: {
                Label("Connect Bank Account", systemImage: "building.columns.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 40)
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.recentTransactions(limit: 5), id: \.id) { transaction in
                TransactionRow(transaction: transaction)
            }

            if !viewModel.transactions.isEmpty {
                NavigationLink {
                    TransactionsListView(transactions: viewModel.transactions)
                } label: {
                    Text("View All Transactions")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
    }

    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.refreshData()
            }
        } label: {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Label("Refresh Data", systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isLoading)
    }
}

// MARK: - Bucket Card

struct BucketCard: View {
    let category: BucketCategory
    let amount: Double
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.iconName)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()
            }

            Text(category.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(formattedAmount)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? color : Color.clear, lineWidth: 2)
        )
    }

    private var color: Color {
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
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let merchantName = transaction.merchantName {
                    Text(merchantName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.amount < 0 ? .green : .primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        let value = transaction.amount < 0 ? abs(transaction.amount) : transaction.amount
        let sign = transaction.amount < 0 ? "+" : "-"
        return sign + (formatter.string(from: NSNumber(value: value)) ?? "$0.00")
    }
}

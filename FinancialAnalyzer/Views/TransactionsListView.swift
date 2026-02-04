import SwiftUI

struct TransactionsListView: View {
    let transactions: [Transaction]
    @State private var searchText = ""
    @State private var selectedCategory: String?

    var filteredTransactions: [Transaction] {
        var result = transactions

        if !searchText.isEmpty {
            result = result.filter { transaction in
                transaction.name.localizedCaseInsensitiveContains(searchText) ||
                transaction.merchantName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category.first == category }
        }

        return result.sorted(by: { $0.date > $1.date })
    }

    var categories: [String] {
        Array(Set(transactions.compactMap { $0.category.first })).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Toolbar
                HStack {
                    Text("Transactions")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(white: 0.75))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                // Category filter chips
                if !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(categories, id: \.self) { category in
                                CategoryChip(title: category, isSelected: selectedCategory == category) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Transaction cards by month
                ForEach(groupedByMonth.keys.sorted(by: >), id: \.self) { month in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(monthFormatter.string(from: month))
                            .font(.headline)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .padding(.horizontal, 16)

                        transactionCard(for: month)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .searchable(text: $searchText, prompt: "Search transactions")
        .navigationBarHidden(true)
        .primaryBackgroundGradient()
    }

    private var groupedByMonth: [Date: [Transaction]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            let components = Calendar.current.dateComponents([.year, .month], from: transaction.date)
            return Calendar.current.date(from: components) ?? transaction.date
        }
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    @ViewBuilder
    private func transactionCard(for month: Date) -> some View {
        let transactions = groupedByMonth[month] ?? []
        GlassmorphicCard(showDivider: false) {
            VStack(spacing: 0) {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                    TransactionRow(transaction: transaction)

                    if index < transactions.count - 1 {
                        Rectangle()
                            .fill(DesignTokens.Colors.divider)
                            .frame(height: 1)
                            .padding(.vertical, 16)
                    }
                }
            }
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Preview

#Preview {
    TransactionsListView(transactions: .mock)
        .preferredColorScheme(.dark)
}

private extension Array where Element == Transaction {
    static var mock: [Transaction] {
        [
            Transaction(
                id: "1",
                accountId: "acc1",
                amount: 500.00,
                date: Date(),
                name: "Alpine Bikes LLC",
                merchantName: "Alpine Bikes",
                category: ["Vendor", "Shopping"],
                pending: false
            ),
            Transaction(
                id: "2",
                accountId: "acc1",
                amount: 500.00,
                date: Date(),
                name: "Alpine Bikes LLC",
                merchantName: "Alpine Bikes",
                category: ["Vendor", "Shopping"],
                pending: false
            ),
            Transaction(
                id: "3",
                accountId: "acc1",
                amount: 500.00,
                date: Date(),
                name: "Alpine Bikes LLC",
                merchantName: "Alpine Bikes",
                category: ["Vendor", "Shopping"],
                pending: false
            )
        ]
    }
}

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
        List {
            // Category filter
            if !categories.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            CategoryChip(
                                title: "All",
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }

                            ForEach(categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Transactions grouped by month
            ForEach(groupedByMonth.keys.sorted(by: >), id: \.self) { month in
                Section {
                    ForEach(groupedByMonth[month] ?? [], id: \.id) { transaction in
                        TransactionRow(transaction: transaction)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                } header: {
                    Text(monthFormatter.string(from: month))
                        .font(.headline)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search transactions")
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
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

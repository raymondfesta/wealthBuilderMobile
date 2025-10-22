import SwiftUI

/// Sheet for manually creating a budget when auto-generation is insufficient
struct AddBudgetSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var budgetManager: BudgetManager

    @State private var categoryName: String = ""
    @State private var monthlyLimit: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // Common spending categories
    private let suggestedCategories = [
        "Groceries",
        "Dining",
        "Transportation",
        "Entertainment",
        "Shopping",
        "Utilities",
        "Healthcare",
        "Personal Care",
        "Subscriptions",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $categoryName)
                        .autocapitalization(.words)

                    // Quick select buttons for common categories
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestedCategories, id: \.self) { category in
                                Button(category) {
                                    categoryName = category
                                }
                                .buttonStyle(.bordered)
                                .tint(categoryName == category ? .blue : .gray)
                            }
                        }
                    }
                } header: {
                    Text("Category")
                } footer: {
                    Text("Choose a spending category to track")
                }

                Section {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0", text: $monthlyLimit)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Monthly Limit")
                } footer: {
                    Text("How much you want to spend in this category each month")
                }

                Section {
                    Button("Create Budget") {
                        createBudget()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(categoryName.isEmpty || monthlyLimit.isEmpty)
                }
            }
            .navigationTitle("Add Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func createBudget() {
        // Validate input
        guard !categoryName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a category name"
            showError = true
            return
        }

        guard let limit = Double(monthlyLimit), limit > 0 else {
            errorMessage = "Please enter a valid amount greater than $0"
            showError = true
            return
        }

        // Check if budget already exists for this category
        let trimmedCategory = categoryName.trimmingCharacters(in: .whitespaces)
        let currentMonth = Date().startOfMonth
        if budgetManager.budgets.contains(where: {
            $0.categoryName.lowercased() == trimmedCategory.lowercased() &&
            $0.month == currentMonth
        }) {
            errorMessage = "A budget already exists for \(trimmedCategory) this month"
            showError = true
            return
        }

        // Create budget
        budgetManager.setBudget(category: trimmedCategory, limit: limit)

        print("✅ [AddBudgetSheet] Created manual budget: \(trimmedCategory) - $\(limit)/month")

        // Dismiss sheet
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddBudgetSheet(budgetManager: BudgetManager())
}

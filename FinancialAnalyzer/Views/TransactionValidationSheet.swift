import SwiftUI

/// Sheet for validating or correcting transaction categorizations
struct TransactionValidationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: Transaction
    let matchingCount: Int
    let onValidate: (BucketCategory?, Bool) -> Void

    @State private var selectedCategory: BucketCategory
    @State private var showBulkConfirmation = false

    init(
        transaction: Transaction,
        matchingCount: Int = 0,
        onValidate: @escaping (BucketCategory?, Bool) -> Void
    ) {
        self.transaction = transaction
        self.matchingCount = matchingCount
        self.onValidate = onValidate
        // Initialize with current category (either corrected or Plaid's category)
        self._selectedCategory = State(initialValue: transaction.bucketCategory)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Transaction Details
                    transactionDetailsSection

                    // Plaid Categorization
                    plaidCategorizationSection

                    // Category Picker
                    categoryPickerSection
                }
                .padding()
            }
            .navigationTitle("Validate Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedCategory == transaction.bucketCategory {
                        // User confirms Plaid's categorization
                        Button("Confirm") {
                            handleValidation(correctedCategory: nil)
                        }
                        .fontWeight(.semibold)
                    } else {
                        // User corrects the category
                        Button("Correct") {
                            handleValidation(correctedCategory: selectedCategory)
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    }
                }
            }
            .alert("Apply to Similar Transactions?", isPresented: $showBulkConfirmation) {
                Button("Just This One") {
                    onValidate(selectedCategory == transaction.bucketCategory ? nil : selectedCategory, false)
                    dismiss()
                }

                Button("Apply to All (\(matchingCount + 1))") {
                    onValidate(selectedCategory == transaction.bucketCategory ? nil : selectedCategory, true)
                    dismiss()
                }

                Button("Cancel", role: .cancel) {
                    // User cancelled, don't dismiss sheet
                }
            } message: {
                if let pfc = transaction.personalFinanceCategory {
                    let categoryName = formatPFCCategory(pfc.detailed)
                    Text("Found \(matchingCount) other \(categoryName) transaction\(matchingCount == 1 ? "" : "s"). Apply your \(selectedCategory == transaction.bucketCategory ? "confirmation" : "correction") to all?")
                } else {
                    Text("Found \(matchingCount) other similar transaction\(matchingCount == 1 ? "" : "s"). Apply your \(selectedCategory == transaction.bucketCategory ? "confirmation" : "correction") to all?")
                }
            }
        }
    }

    // MARK: - Actions

    private func handleValidation(correctedCategory: BucketCategory?) {
        // If there are matching transactions, show bulk confirmation dialog
        if matchingCount > 0 {
            showBulkConfirmation = true
        } else {
            // No matches, just validate this one
            onValidate(correctedCategory, false)
            dismiss()
        }
    }

    // MARK: - Sections

    private var transactionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transaction Details")
                .font(.headline)

            VStack(spacing: 12) {
                detailRow(
                    icon: "building.2.fill",
                    label: "Merchant",
                    value: transaction.merchantName ?? transaction.name
                )

                detailRow(
                    icon: "dollarsign.circle.fill",
                    label: "Amount",
                    value: formatCurrency(transaction.amount)
                )

                detailRow(
                    icon: "calendar",
                    label: "Date",
                    value: transaction.date.formatted(date: .abbreviated, time: .omitted)
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
        }
    }

    private var plaidCategorizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Our Analysis")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                if let pfc = transaction.personalFinanceCategory {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(confidenceColor(pfc.confidenceLevel))

                        Text("We think this is:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        // Confidence badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(confidenceColor(pfc.confidenceLevel))
                                .frame(width: 8, height: 8)

                            Text(pfc.confidenceLevel.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Image(systemName: transaction.bucketCategory.iconName)
                            .font(.title2)
                            .foregroundColor(categoryColor(transaction.bucketCategory))

                        Text(transaction.bucketCategory.rawValue)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 4)

                    Divider()
                        .padding(.vertical, 4)

                    Text("Based on: \(pfc.detailed.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)

                        Text("Limited data - please verify")
                            .font(.subheadline)
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

    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Correct Category")
                .font(.headline)

            Text("If our analysis is wrong, select the correct category below:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(BucketCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack {
                            Image(systemName: category.iconName)
                                .font(.title3)
                                .foregroundColor(categoryColor(category))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(category.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if selectedCategory == category {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedCategory == category ? Color.blue.opacity(0.1) : Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedCategory == category ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Helper Views

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Helpers

    private func confidenceColor(_ level: ConfidenceLevel) -> Color {
        switch level {
        case .veryHigh, .high: return .green
        case .medium: return .yellow
        case .low, .unknown: return .orange
        }
    }

    private func categoryColor(_ category: BucketCategory) -> Color {
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

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
    }

    private func formatPFCCategory(_ detailed: String) -> String {
        // Convert "FOOD_AND_DRINK_RESTAURANTS" to "Food And Drink Restaurants"
        return detailed
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Preview

#Preview {
    TransactionValidationSheet(
        transaction: Transaction(
            id: "1",
            accountId: "account_1",
            amount: 87.43,
            date: Date(),
            name: "TARGET",
            merchantName: "Target",
            category: ["Shopping", "General Merchandise"],
            categoryId: "12345",
            personalFinanceCategory: PersonalFinanceCategory(
                primary: "GENERAL_MERCHANDISE",
                detailed: "GENERAL_MERCHANDISE_SUPERSTORES",
                confidenceLevel: .medium
            )
        ),
        matchingCount: 5,
        onValidate: { correctedCategory, applyToAll in
            print("Validated with category: \(String(describing: correctedCategory)), applyToAll: \(applyToAll)")
        }
    )
}

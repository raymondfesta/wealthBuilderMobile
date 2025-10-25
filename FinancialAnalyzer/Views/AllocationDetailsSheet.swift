import SwiftUI

/// Bottom drawer sheet showing detailed information about an allocation bucket
struct AllocationDetailsSheet: View {
    @ObservedObject var bucket: AllocationBucket
    let monthlyIncome: Double
    let essentialSpendingAmount: Double?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with icon and amount
                    headerSection

                    // AI Explanation section
                    aiExplanationSection

                    // Emergency Fund specific details
                    if bucket.type == .emergencyFund,
                       let targetAmount = bucket.targetAmount {
                        emergencyFundSection(targetAmount: targetAmount)
                    }

                    // Linked categories (for spending buckets)
                    if !bucket.linkedBudgetCategories.isEmpty {
                        linkedCategoriesSection
                    }

                    // Non-modifiable explanation
                    if !bucket.isModifiable {
                        nonModifiableSection
                    }

                    Spacer().frame(height: 20)
                }
                .padding(20)
            }
            .navigationTitle("Allocation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: bucket.color).opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: bucket.icon)
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: bucket.color))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(bucket.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(formatCurrency(bucket.allocatedAmount) + "/month")
                    .font(.title3)
                    .foregroundColor(Color(hex: bucket.color))

                Text("\(Int(bucket.percentageOfIncome))% of monthly income")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var aiExplanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Recommendation")
                    .font(.headline)
            }

            Text(bucket.explanation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    private func emergencyFundSection(targetAmount: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.orange)
                Text("Emergency Fund Goal")
                    .font(.headline)
            }

            // Standard recommendation callout
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Financial experts recommend 6 months of essential expenses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // Calculation breakdown
            if let essentialSpending = essentialSpendingAmount {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How We Calculate")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Essential Spending")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(essentialSpending))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Image(systemName: "multiply")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Target Coverage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("6 months")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }

                    Divider()

                    // Current coverage
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Monthly Allocation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(bucket.allocatedAmount))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Covers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            let monthsCovered = bucket.allocatedAmount / essentialSpending
                            Text(String(format: "%.1f months", monthsCovered))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(monthsCovered >= 6 ? .green : .orange)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Target Amount")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formatCurrency(essentialSpending * 6))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            // Timeline
            if let monthsToTarget = bucket.monthsToTarget, monthsToTarget > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Savings Timeline")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly Contribution")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(bucket.allocatedAmount))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Time to Goal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(monthsToTarget) months")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }

                    // Progress bar
                    let progress = min(1.0, 0.3) // Placeholder - would calculate from actual savings
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green)
                                .frame(width: geometry.size.width * progress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text("On track to reach your goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }

    private var linkedCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                Text("Included Categories")
                    .font(.headline)
            }

            Text("This allocation covers your spending in the following categories:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(bucket.linkedBudgetCategories, id: \.self) { category in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: bucket.color))

                        Text(category)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        // Badge
                        Text(categoryBadge(for: category))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: bucket.color).opacity(0.15))
                            .foregroundColor(Color(hex: bucket.color))
                            .cornerRadius(6)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            Text("Your actual spending in these categories was analyzed to determine this allocation amount.")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }

    private var nonModifiableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.blue)
                Text("Why Can't I Change This?")
                    .font(.headline)
            }

            Text("Essential Spending is calculated from your actual spending data in essential categories like rent, groceries, utilities, and transportation. This ensures your allocation covers your real needs.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("To reduce this amount, focus on cutting costs in specific categories rather than adjusting the overall allocation.")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helper Methods

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func categoryBadge(for category: String) -> String {
        let essentialCategories = ["Groceries", "Rent", "Utilities", "Transportation", "Insurance", "Healthcare"]
        let discretionaryCategories = ["Entertainment", "Dining", "Shopping", "Travel", "Hobbies"]

        if essentialCategories.contains(category) {
            return "ESSENTIAL"
        } else if discretionaryCategories.contains(category) {
            return "LIFESTYLE"
        } else {
            return "TRACKED"
        }
    }
}

// MARK: - Preview

#Preview("Emergency Fund Details") {
    AllocationDetailsSheet(
        bucket: AllocationBucket(
            type: .emergencyFund,
            allocatedAmount: 500,
            percentageOfIncome: 10,
            linkedCategories: [],
            explanation: "Build a 6-month emergency fund to cover essential expenses. This provides a safety net for unexpected events like job loss, medical emergencies, or major repairs. At $500/month, you'll reach your $19,200 target in 38 months.",
            targetAmount: 19200,
            monthsToTarget: 38
        ),
        monthlyIncome: 5000,
        essentialSpendingAmount: 3200
    )
}

#Preview("Essential Spending Details") {
    AllocationDetailsSheet(
        bucket: AllocationBucket(
            type: .essentialSpending,
            allocatedAmount: 3200,
            percentageOfIncome: 64,
            linkedCategories: ["Rent", "Groceries", "Utilities", "Transportation", "Insurance"],
            explanation: "Your essential expenses cover rent, groceries, utilities, transportation, and insurance. These are your must-have monthly costs that keep your life running smoothly.",
            targetAmount: nil,
            monthsToTarget: nil
        ),
        monthlyIncome: 5000,
        essentialSpendingAmount: 3200
    )
}

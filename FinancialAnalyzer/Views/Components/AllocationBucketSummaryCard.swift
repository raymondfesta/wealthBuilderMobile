import SwiftUI

/// Compact read-only card for displaying allocation bucket on dashboard
struct AllocationBucketSummaryCard: View {
    let bucket: AllocationBucket
    let budgetManager: BudgetManager

    var body: some View {
        NavigationLink(destination: AllocationBucketDetailView(
            bucket: bucket,
            budgetManager: budgetManager
        )) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Image(systemName: bucket.icon)
                        .font(.title3)
                        .foregroundColor(Color(hex: bucket.color))
                    Spacer()
                }

                Text(bucket.displayName)
                    .captionStyle()
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(formatCurrency(bucket.allocatedAmount))
                    .titleValueStyle()
                    .lineLimit(1)

                Text("\(Int(bucket.percentageOfIncome))% of income")
                    .captionStyle()
            }
            .padding(DesignTokens.Spacing.md)
            .primaryCardStyle()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(bucket.displayName), \(formatCurrency(bucket.allocatedAmount)), \(Int(bucket.percentageOfIncome))% of income")
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

#if DEBUG
struct AllocationBucketSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        AllocationBucketSummaryCard(
            bucket: AllocationBucket(
                type: .essentialSpending,
                allocatedAmount: 3200,
                percentageOfIncome: 64,
                linkedCategories: ["Rent", "Groceries"],
                explanation: "Essential expenses"
            ),
            budgetManager: BudgetManager()
        )
        .frame(width: 160)
        .padding()
        .primaryBackgroundGradient()
    }
}
#endif

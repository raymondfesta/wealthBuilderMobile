import SwiftUI

/// Row displaying a single transaction with amount
struct TransactionRow: View {
    let transaction: Transaction

    private var categoryLabel: String {
        transaction.category.first ?? "Uncategorized"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(categoryLabel)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Text(Self.dateFormatter.string(from: transaction.date))
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Text(formattedAmount)
                .font(.system(size: 16))
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        let value = abs(transaction.amount)
        let sign = transaction.amount < 0 ? "+" : "-"
        return sign + (formatter.string(from: NSNumber(value: value)) ?? "$0.00")
    }
}

#if DEBUG
struct TransactionRow_Previews: PreviewProvider {
    static var previews: some View {
        let transaction = Transaction(
            id: "1",
            accountId: "acc1",
            amount: 500.00,
            date: Date(),
            name: "Alpine Bikes LLC",
            merchantName: "Alpine Bikes",
            category: ["Vendor", "Shopping"],
            pending: false
        )
        return TransactionRow(transaction: transaction)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
            .padding()
            .primaryBackgroundGradient()
    }
}
#endif

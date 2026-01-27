import SwiftUI

/// Row displaying a single transaction with amount
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(transaction.name)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)

                if let merchantName = transaction.merchantName {
                    Text(merchantName)
                        .captionStyle()
                }

                Text(transaction.date, style: .date)
                    .captionStyle()
            }

            Spacer()

            Text(formattedAmount)
                .subheadlineStyle(color: transaction.amount < 0 ? DesignTokens.Colors.progressGreen : DesignTokens.Colors.textPrimary)
        }
        .padding(DesignTokens.Spacing.md)
        .primaryCardStyle()
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

#if DEBUG
struct TransactionRow_Previews: PreviewProvider {
    static var previews: some View {
        let transaction = Transaction(
            id: "1",
            accountId: "acc1",
            amount: 5.50,
            date: Date(),
            name: "Coffee Shop",
            merchantName: "Starbucks",
            category: ["Food and Drink", "Coffee Shop"],
            pending: false
        )
        return TransactionRow(transaction: transaction)
            .padding()
            .primaryBackgroundGradient()
    }
}
#endif

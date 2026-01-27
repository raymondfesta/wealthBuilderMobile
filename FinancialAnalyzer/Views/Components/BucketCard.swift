import SwiftUI

/// Card displaying a financial bucket category with amount
struct BucketCard: View {
    let category: BucketCategory
    let amount: Double
    let isSelected: Bool
    var needsValidationCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: category.iconName)
                    .font(.title2)
                    .foregroundColor(category.designColor)

                Spacer()

                if needsValidationCount > 0 {
                    ZStack {
                        Circle()
                            .fill(DesignTokens.Colors.opportunityOrange)
                            .frame(width: 24, height: 24)

                        Text("\(needsValidationCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }

            Text(category.rawValue)
                .captionStyle()
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(formattedAmount)
                .titleValueStyle()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 120)
        .primaryCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(isSelected ? category.designColor : Color.clear, lineWidth: 2)
        )
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

#if DEBUG
struct BucketCard_Previews: PreviewProvider {
    static var previews: some View {
        BucketCard(
            category: .income,
            amount: 5000,
            isSelected: false,
            needsValidationCount: 2
        )
        .frame(width: 160)
        .padding()
        .primaryBackgroundGradient()
    }
}
#endif

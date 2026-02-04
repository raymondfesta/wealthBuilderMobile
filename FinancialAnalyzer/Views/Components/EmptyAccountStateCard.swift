import SwiftUI

/// Empty state card for missing account types (debt, investments)
struct EmptyAccountStateCard: View {
    let title: String
    let message: String
    let iconName: String
    let actionTitle: String
    let onAddAccount: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onAddAccount) {
                Label(actionTitle, systemImage: "plus.circle")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundColor(.secondary.opacity(0.3))
                )
        )
    }
}

// MARK: - Convenience Initializers

extension EmptyAccountStateCard {
    /// Empty state for debt accounts
    static func debt(onAddAccount: @escaping () -> Void) -> EmptyAccountStateCard {
        EmptyAccountStateCard(
            title: "Debt Accounts",
            message: "No credit cards or loans connected",
            iconName: "creditcard",
            actionTitle: "Add Credit Card or Loan",
            onAddAccount: onAddAccount
        )
    }

    /// Empty state for investment accounts
    static func investments(onAddAccount: @escaping () -> Void) -> EmptyAccountStateCard {
        EmptyAccountStateCard(
            title: "Investment Accounts",
            message: "No brokerage or retirement accounts connected",
            iconName: "chart.line.uptrend.xyaxis",
            actionTitle: "Add Investment Account",
            onAddAccount: onAddAccount
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        EmptyAccountStateCard.debt(onAddAccount: {})
        EmptyAccountStateCard.investments(onAddAccount: {})
    }
    .padding()
}

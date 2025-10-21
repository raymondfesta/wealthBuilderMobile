import SwiftUI

struct AccountsView: View {
    let accounts: [BankAccount]

    var groupedAccounts: [String: [BankAccount]] {
        Dictionary(grouping: accounts) { $0.type }
    }

    var body: some View {
        List {
            ForEach(groupedAccounts.keys.sorted(), id: \.self) { type in
                Section {
                    ForEach(groupedAccounts[type] ?? [], id: \.id) { account in
                        AccountRow(account: account)
                    }
                } header: {
                    Text(type.capitalized)
                }
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Account Row

struct AccountRow: View {
    let account: BankAccount

    var body: some View {
        HStack {
            // Icon
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)

            // Account info
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)

                if let officialName = account.officialName {
                    Text(officialName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let mask = account.mask {
                    Text("••••\(mask)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 4) {
                if let balance = account.currentBalance {
                    Text(formattedBalance(balance))
                        .font(.headline)
                        .foregroundColor(balanceColor)
                }

                if let subtype = account.subtype {
                    Text(subtype.capitalized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var iconName: String {
        switch account.type {
        case "depository":
            return "building.columns.fill"
        case "credit":
            return "creditcard.fill"
        case "loan":
            return "banknote.fill"
        case "investment", "brokerage":
            return "chart.line.uptrend.xyaxis"
        default:
            return "dollarsign.circle.fill"
        }
    }

    private var iconColor: Color {
        switch account.type {
        case "depository":
            return .blue
        case "credit":
            return .orange
        case "loan":
            return .red
        case "investment", "brokerage":
            return .green
        default:
            return .gray
        }
    }

    private var balanceColor: Color {
        if account.isCredit || account.isLoan {
            return .orange
        }
        return .primary
    }

    private func formattedBalance(_ balance: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: balance)) ?? "$0.00"
    }
}

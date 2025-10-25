import SwiftUI

/// Sheet for tagging accounts with their purpose (Emergency Fund, Savings Goal, etc.)
struct AccountTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    let account: BankAccount
    let allAccounts: [BankAccount]
    let onSave: (Set<AccountTag>) -> Void

    @State private var selectedTags: Set<AccountTag>

    init(account: BankAccount, allAccounts: [BankAccount], onSave: @escaping (Set<AccountTag>) -> Void) {
        self.account = account
        self.allAccounts = allAccounts
        self.onSave = onSave
        self._selectedTags = State(initialValue: account.tags)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Account Info
                    accountInfoSection

                    // Tag Selection
                    tagSelectionSection
                }
                .padding()
            }
            .navigationTitle("Tag Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedTags)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedTags == account.tags) // No changes
                }
            }
        }
    }

    // MARK: - Sections

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)

            HStack {
                Image(systemName: accountIcon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let mask = account.mask {
                        Text("••••\(mask)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let balance = account.currentBalance {
                    Text(formatCurrency(balance))
                        .font(.subheadline)
                        .fontWeight(.medium)
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

    private var tagSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Purpose Tags")
                .font(.headline)

            Text("Tag this account to improve financial health calculations")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(AccountTag.allCases, id: \.self) { tag in
                    Button {
                        toggleTag(tag)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: tag.icon)
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(tag.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(tag.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                // Warning if emergency fund already exists
                                if tag == .emergencyFund && !selectedTags.contains(.emergencyFund) {
                                    if let existingEmergencyFund = allAccounts.first(where: { $0.isEmergencyFund && $0.id != account.id }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                            Text("'\(existingEmergencyFund.name)' is already tagged as Emergency Fund")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.orange)
                                        .padding(.top, 4)
                                    }
                                }
                            }

                            Spacer()

                            if selectedTags.contains(tag) {
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
                                .fill(selectedTags.contains(tag) ? Color.blue.opacity(0.1) : Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedTags.contains(tag) ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggleTag(_ tag: AccountTag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            // If adding Emergency Fund tag, remove it from other accounts
            // (only one account can be emergency fund)
            if tag == .emergencyFund {
                // Just add it - the parent will handle removing from other accounts
                selectedTags.insert(tag)
            } else {
                selectedTags.insert(tag)
            }
        }
    }

    private var accountIcon: String {
        if account.isDepository {
            return "banknote.fill"
        } else if account.isCredit {
            return "creditcard.fill"
        } else if account.isLoan {
            return "doc.text.fill"
        } else if account.isInvestment {
            return "chart.line.uptrend.xyaxis"
        }
        return "dollarsign.circle.fill"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview

#Preview {
    AccountTagSheet(
        account: BankAccount(
            id: "1",
            itemId: "item_1",
            name: "Chase Savings",
            officialName: "Chase Savings Account",
            type: "depository",
            subtype: "savings",
            mask: "1234",
            currentBalance: 5000.00,
            availableBalance: 5000.00
        ),
        allAccounts: [],
        onSave: { tags in
            print("Saved tags: \(tags)")
        }
    )
}

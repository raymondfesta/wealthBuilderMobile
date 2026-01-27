import SwiftUI

/// Bottom sheet displaying connected accounts grouped by type with tag management
struct ConnectedAccountsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: FinancialViewModel

    @State private var selectedAccount: BankAccount?
    @State private var showTagSheet = false

    private var groupedAccounts: [String: [BankAccount]] {
        Dictionary(grouping: viewModel.accounts) { $0.type }
    }

    /// Only enable tagging after plan is created (not during onboarding)
    private var taggingEnabled: Bool {
        viewModel.userJourneyState == .planCreated
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedAccounts.keys.sorted(), id: \.self) { type in
                    Section {
                        ForEach(groupedAccounts[type] ?? [], id: \.id) { account in
                            AccountRowWithTags(
                                account: account,
                                showTagButton: taggingEnabled
                            ) {
                                selectedAccount = account
                                showTagSheet = true
                            }
                        }
                    } header: {
                        Text(type.capitalized)
                    }
                }
            }
            .navigationTitle("Connected Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTagSheet) {
                if let account = selectedAccount {
                    AccountTagSheet(
                        account: account,
                        allAccounts: viewModel.accounts,
                        onSave: { newTags in
                            // Update tags
                            account.tags = newTags

                            // If Emergency Fund tag was added, remove it from other accounts
                            if newTags.contains(.emergencyFund) {
                                for otherAccount in viewModel.accounts where otherAccount.id != account.id {
                                    otherAccount.tags.remove(.emergencyFund)
                                }
                            }

                            // Persist changes
                            viewModel.saveAccounts()
                        }
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Account Row with Tags

struct AccountRowWithTags: View {
    let account: BankAccount
    let showTagButton: Bool  // Controls whether tagging UI is visible
    let onTagTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Account info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

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
                        .fontWeight(.semibold)
                }
            }

            // Tags (if any)
            if !account.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(account.tags), id: \.self) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: tag.icon)
                                    .font(.caption2)
                                Text(tag.rawValue)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Add/Edit Tags button (only shown after plan created)
            if showTagButton {
                Button {
                    onTagTapped()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: account.tags.isEmpty ? "tag" : "tag.fill")
                            .font(.caption)
                        Text(account.tags.isEmpty ? "Add Tags" : "Edit Tags")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    ConnectedAccountsSheet(viewModel: FinancialViewModel())
}

import SwiftUI

struct AccountsView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var accountToRemove: BankAccount?
    @State private var showRemovalConfirmation = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var removedAccountName = ""

    var accounts: [BankAccount] {
        viewModel.accounts
    }

    var groupedAccounts: [String: [BankAccount]] {
        Dictionary(grouping: accounts) { $0.type }
    }

    var body: some View {
        ZStack {
            if accounts.isEmpty && !viewModel.isLoading {
                // Empty state
                VStack(spacing: DesignTokens.Spacing.xl) {
                    Spacer()

                    Image(systemName: "building.columns.circle")
                        .font(.system(size: 60))
                        .foregroundColor(DesignTokens.Colors.accentPrimary.opacity(0.6))

                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text("No accounts connected")
                            .headlineStyle()

                        Text("Connect your first account to start tracking your finances")
                            .subheadlineStyle()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.Spacing.xl)
                    }

                    PrimaryButton(title: "Connect Account", action: {
                        Task {
                            await viewModel.connectBankAccount(from: nil)
                        }
                    })
                    .padding(.horizontal, DesignTokens.Spacing.xl)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .primaryBackgroundGradient()
            } else {
                List {
                    ForEach(groupedAccounts.keys.sorted(), id: \.self) { type in
                        Section {
                            ForEach(groupedAccounts[type] ?? [], id: \.id) { account in
                                AccountRow(account: account)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            accountToRemove = account
                                            showRemovalConfirmation = true
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            accountToRemove = account
                                            showRemovalConfirmation = true
                                        } label: {
                                            Label("Remove Account", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text(type.capitalized)
                        }
                    }
                }
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .alert("Remove Account", isPresented: $showRemovalConfirmation) {
            Button("Cancel", role: .cancel) {
                accountToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let account = accountToRemove {
                    removedAccountName = account.name
                    print("🗑️ [UI] User confirmed removal of account: \(account.name) (itemId: \(account.itemId))")
                    Task {
                        await viewModel.removeLinkedAccount(itemId: account.itemId)
                        accountToRemove = nil

                        // Check if error occurred
                        if viewModel.error != nil {
                            print("❌ [UI] Error detected after removal attempt")
                            showErrorAlert = true
                        } else {
                            print("✅ [UI] No error detected, showing success alert")
                            showSuccessAlert = true
                        }
                    }
                }
            }
        } message: {
            if let account = accountToRemove {
                Text("Are you sure you want to remove \(account.name)? This will delete all associated transactions, budgets, and financial data. This action cannot be undone.")
            }
        }
        .alert("Account Removed", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("\(removedAccountName) has been successfully removed. All associated data has been deleted.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text("Failed to remove account: \(error.localizedDescription)")
            }
        }
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

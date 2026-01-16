import SwiftUI

/// Sheet for viewing and managing account-to-bucket linkages
struct AccountLinkingDetailSheet: View {
    let bucketType: AllocationBucketType
    let allAccounts: [BankAccount]
    @Binding var linkedAccountIds: [String]
    @Binding var linkageMethods: [String: BucketLinkageMethod]
    let onSave: ([String], [String: BucketLinkageMethod]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localLinkedIds: [String] = []
    @State private var localMethods: [String: BucketLinkageMethod] = [:]
    @State private var showingSuggestions = true

    private let linkingService = AccountLinkingService()

    var body: some View {
        NavigationView {
            List {
                // Current balance section
                if !localLinkedIds.isEmpty {
                    Section {
                        currentBalanceCard
                    }
                }

                // Linked accounts section
                if !localLinkedIds.isEmpty {
                    Section("Linked Accounts") {
                        ForEach(linkedAccounts) { account in
                            linkedAccountRow(account)
                        }
                        .onDelete(perform: unlinkAccounts)
                    }
                }

                // Suggested accounts section
                if showingSuggestions && !suggestedAccounts.isEmpty {
                    Section {
                        ForEach(suggestedAccounts) { suggestion in
                            suggestedAccountRow(suggestion)
                        }
                    } header: {
                        HStack {
                            Text("Suggested Accounts")
                            Spacer()
                            Button("Hide") {
                                withAnimation {
                                    showingSuggestions = false
                                }
                            }
                            .font(.caption)
                            .textCase(nil)
                        }
                    }
                }

                // Available accounts section
                if !availableAccounts.isEmpty {
                    Section("Available Accounts") {
                        ForEach(availableAccounts) { account in
                            availableAccountRow(account)
                        }
                    }
                }

                // Empty state
                if localLinkedIds.isEmpty && availableAccounts.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "link.circle")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No accounts available to link")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Connect bank accounts to link them to this allocation bucket")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
            }
            .navigationTitle(bucketType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(localLinkedIds, localMethods)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                localLinkedIds = linkedAccountIds
                localMethods = linkageMethods
            }
        }
    }

    // MARK: - Computed Properties

    private var linkedAccounts: [BankAccount] {
        allAccounts.filter { localLinkedIds.contains($0.id) }
    }

    private var availableAccounts: [BankAccount] {
        let eligible = linkingService.getEligibleAccounts(for: bucketType, from: allAccounts)
        return eligible.filter { !localLinkedIds.contains($0.id) && !isSuggested($0) }
    }

    private var suggestedAccounts: [AccountLinkingService.LinkSuggestion] {
        let suggestions = linkingService.suggestBucketLinks(for: allAccounts)
        return suggestions.filter {
            $0.bucketType == bucketType &&
            !localLinkedIds.contains($0.id)
        }
    }

    private var totalBalance: Double {
        linkingService.calculateBucketBalance(
            for: bucketType,
            linkedAccountIds: localLinkedIds,
            accounts: allAccounts
        )
    }

    private func isSuggested(_ account: BankAccount) -> Bool {
        suggestedAccounts.contains { $0.id == account.id }
    }

    // MARK: - Views

    @ViewBuilder
    private var currentBalanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Balance")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formattedAmount(totalBalance))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: bucketType.color))

            Text("From \(localLinkedIds.count) linked account\(localLinkedIds.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: bucketType.color).opacity(0.1))
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func linkedAccountRow(_ account: BankAccount) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.icon)
                .font(.title3)
                .foregroundColor(Color(hex: bucketType.color))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    if let method = localMethods[account.id] {
                        methodBadge(method)
                    }

                    Text((account.subtype ?? "").capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount(account.currentBalance ?? 0))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(account.mask ?? "")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func suggestedAccountRow(_ suggestion: AccountLinkingService.LinkSuggestion) -> some View {
        if let account = allAccounts.first(where: { $0.id == suggestion.id }) {
            Button {
                linkAccount(account, method: .automatic)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: account.icon)
                        .font(.title3)
                        .foregroundColor(Color.protectionMint)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(suggestion.reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        confidenceBadge(suggestion.confidence)

                        Button {
                            linkAccount(account, method: .automatic)
                        } label: {
                            Text("Link")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.protectionMint)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func availableAccountRow(_ account: BankAccount) -> some View {
        Button {
            linkAccount(account, method: .manual)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: account.icon)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text((account.subtype ?? "").capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formattedAmount(account.currentBalance ?? 0))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Image(systemName: "plus.circle")
                    .foregroundColor(Color(hex: bucketType.color))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func methodBadge(_ method: BucketLinkageMethod) -> some View {
        Text(method == .automatic ? "AUTO" : "MANUAL")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(method == .automatic ? Color.protectionMint : Color.gray)
            .cornerRadius(4)
    }

    @ViewBuilder
    private func confidenceBadge(_ confidence: AccountLinkingService.LinkConfidence) -> some View {
        let (label, color) = confidenceInfo(confidence)
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    // MARK: - Actions

    private func linkAccount(_ account: BankAccount, method: BucketLinkageMethod) {
        let result = linkingService.canLink(accountId: account.id, to: bucketType, accounts: allAccounts)
        guard result.canLink else {
            // Could show alert with result.reason
            return
        }

        withAnimation {
            if !localLinkedIds.contains(account.id) {
                localLinkedIds.append(account.id)
                localMethods[account.id] = method
            }
        }
    }

    private func unlinkAccounts(at offsets: IndexSet) {
        let accountsToUnlink = offsets.map { linkedAccounts[$0] }
        withAnimation {
            for account in accountsToUnlink {
                localLinkedIds.removeAll { $0 == account.id }
                localMethods.removeValue(forKey: account.id)
            }
        }
    }

    // MARK: - Helpers

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func confidenceInfo(_ confidence: AccountLinkingService.LinkConfidence) -> (String, Color) {
        switch confidence {
        case .high: return ("HIGH MATCH", Color.progressGreen)
        case .medium: return ("GOOD MATCH", Color.opportunityOrange)
        case .low: return ("POSSIBLE", Color.gray)
        }
    }
}

extension BankAccount {
    var icon: String {
        switch type.lowercased() {
        case "depository":
            return (subtype ?? "").lowercased().contains("savings") ? "building.columns.circle.fill" : "creditcard.circle.fill"
        case "credit":
            return "creditcard.circle.fill"
        case "loan":
            return "dollarsign.circle.fill"
        case "investment":
            return "chart.line.uptrend.xyaxis.circle.fill"
        default:
            return "banknote.circle.fill"
        }
    }
}

// MARK: - Preview
struct AccountLinkingDetailSheet_Previews: PreviewProvider {
    static var previews: some View {
        AccountLinkingDetailSheet(
            bucketType: .emergencyFund,
            allAccounts: [
                BankAccount(
                    id: "acc1",
                    itemId: "item_1",
                    name: "Chase Savings HYSA",
                    officialName: "Chase High Yield Savings",
                    type: "depository",
                    subtype: "savings",
                    mask: "4567",
                    currentBalance: 10000,
                    availableBalance: 10000
                ),
                BankAccount(
                    id: "acc2",
                    itemId: "item_2",
                    name: "Emergency Fund",
                    officialName: "Ally Online Savings",
                    type: "depository",
                    subtype: "savings",
                    mask: "7890",
                    currentBalance: 5000,
                    availableBalance: 5000
                ),
                BankAccount(
                    id: "acc3",
                    itemId: "item_3",
                    name: "Primary Checking",
                    officialName: "Wells Fargo Checking",
                    type: "depository",
                    subtype: "checking",
                    mask: "1234",
                    currentBalance: 3500,
                    availableBalance: 3500
                )
            ],
            linkedAccountIds: .constant(["acc1"]),
            linkageMethods: .constant(["acc1": .automatic]),
            onSave: { ids, methods in
                print("Saved links: \(ids)")
            }
        )
    }
}

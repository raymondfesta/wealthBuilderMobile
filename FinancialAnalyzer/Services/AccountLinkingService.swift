import Foundation

/// Service for automatically linking bank accounts to allocation buckets
/// Uses account metadata (name, type, subtype) to suggest intelligent bucket assignments
@MainActor
class AccountLinkingService {

    /// Confidence level for auto-linking suggestions
    enum LinkConfidence {
        case high      // Very confident (e.g., "Emergency Savings" → Emergency Fund)
        case medium    // Moderately confident (e.g., checking account → Essential Spending)
        case low       // Low confidence, user should review
    }

    /// Suggested link between an account and a bucket
    struct LinkSuggestion: Identifiable {
        var id: String { accountId }  // Use accountId as the unique identifier
        let accountId: String
        let bucketType: AllocationBucketType
        let confidence: LinkConfidence
        let reason: String
    }

    // MARK: - Auto-Linking Logic

    /// Analyze accounts and suggest bucket links
    /// Returns map of accountId → suggested bucket type
    func suggestBucketLinks(for accounts: [BankAccount]) -> [LinkSuggestion] {
        var suggestions: [LinkSuggestion] = []

        // Track which buckets have been assigned to avoid duplicates
        var hasEmergencyFund = false
        var hasEssentialChecking = false
        var hasDiscretionaryAccount = false

        for account in accounts {
            // Skip investment and loan accounts temporarily
            // They'll be handled separately
            guard account.isDepository || account.isCredit else { continue }

            let accountName = account.name.lowercased()
            let officialName = (account.officialName ?? "").lowercased()
            let combinedName = "\(accountName) \(officialName)"

            // PRIORITY 1: Emergency Fund Detection (Savings accounts)
            if !hasEmergencyFund && account.type == "depository" && account.subtype == "savings" {
                if containsEmergencyKeywords(combinedName) {
                    suggestions.append(LinkSuggestion(
                        accountId: account.id,
                        bucketType: .emergencyFund,
                        confidence: .high,
                        reason: "Savings account with 'emergency' or 'safety' in name"
                    ))
                    hasEmergencyFund = true
                    continue
                }

                // Generic savings accounts likely emergency fund
                if combinedName.contains("savings") || combinedName.contains("hysa") {
                    suggestions.append(LinkSuggestion(
                        accountId: account.id,
                        bucketType: .emergencyFund,
                        confidence: .medium,
                        reason: "High-yield savings account typically used for emergency funds"
                    ))
                    hasEmergencyFund = true
                    continue
                }
            }

            // PRIORITY 2: Essential Spending (Primary checking)
            if !hasEssentialChecking && account.type == "depository" && account.subtype == "checking" {
                // First checking account is typically primary
                suggestions.append(LinkSuggestion(
                    accountId: account.id,
                    bucketType: .essentialSpending,
                    confidence: .high,
                    reason: "Primary checking account for bills and essential expenses"
                ))
                hasEssentialChecking = true
                continue
            }

            // PRIORITY 3: Discretionary Spending (Secondary checking, "fun money")
            if account.type == "depository" && account.subtype == "checking" {
                if containsDiscretionaryKeywords(combinedName) {
                    suggestions.append(LinkSuggestion(
                        accountId: account.id,
                        bucketType: .discretionarySpending,
                        confidence: .high,
                        reason: "Account name suggests discretionary spending"
                    ))
                    continue
                }

                // Second checking account often discretionary
                if !hasDiscretionaryAccount {
                    suggestions.append(LinkSuggestion(
                        accountId: account.id,
                        bucketType: .discretionarySpending,
                        confidence: .medium,
                        reason: "Secondary checking account typically for discretionary spending"
                    ))
                    hasDiscretionaryAccount = true
                    continue
                }
            }

            // PRIORITY 4: Debt Paydown (Credit cards, exclude mortgage)
            if account.isCredit {
                // Exclude mortgages by default
                if let subtype = account.subtype, subtype.contains("mortgage") {
                    continue
                }

                suggestions.append(LinkSuggestion(
                    accountId: account.id,
                    bucketType: .debtPaydown,
                    confidence: .high,
                    reason: "Credit card account for debt paydown tracking"
                ))
                continue
            }
        }

        // PRIORITY 5: Investment accounts (handled separately due to different type)
        for account in accounts {
            if account.isInvestment {
                suggestions.append(LinkSuggestion(
                    accountId: account.id,
                    bucketType: .investments,
                    confidence: .high,
                    reason: "Investment/retirement account (401k, IRA, brokerage)"
                ))
            }
        }

        // PRIORITY 6: Loan accounts (student loans, auto loans)
        for account in accounts {
            if account.isLoan {
                // Exclude mortgages
                if let subtype = account.subtype, subtype.contains("mortgage") {
                    continue
                }

                suggestions.append(LinkSuggestion(
                    accountId: account.id,
                    bucketType: .debtPaydown,
                    confidence: .high,
                    reason: "Loan account for debt paydown tracking"
                ))
            }
        }

        return suggestions
    }

    // MARK: - Keyword Detection

    private func containsEmergencyKeywords(_ name: String) -> Bool {
        let keywords = ["emergency", "safety", "rainy day", "e-fund", "efund"]
        return keywords.contains { name.contains($0) }
    }

    private func containsDiscretionaryKeywords(_ name: String) -> Bool {
        let keywords = ["fun", "spending", "discretionary", "entertainment", "personal"]
        return keywords.contains { name.contains($0) }
    }

    // MARK: - Manual Linking

    /// Link an account to a bucket (manual user override)
    func linkAccount(
        _ accountId: String,
        to bucketType: AllocationBucketType,
        method: BucketLinkageMethod = .manual
    ) -> Bool {
        // This will be stored in UserDefaults via AllocationPlanStorage
        // Just validate the link is valid
        return true
    }

    /// Unlink an account from a bucket
    func unlinkAccount(_ accountId: String, from bucketType: AllocationBucketType) -> Bool {
        return true
    }

    // MARK: - Balance Calculation

    /// Calculate total balance from linked accounts for a specific bucket
    func calculateBucketBalance(
        for bucketType: AllocationBucketType,
        linkedAccountIds: [String],
        accounts: [BankAccount]
    ) -> Double {
        let linkedAccounts = accounts.filter { linkedAccountIds.contains($0.id) }

        // For debt, sum up debt balances (should be positive for display)
        if bucketType == .debtPaydown {
            return linkedAccounts.reduce(0) { sum, account in
                // Credit cards: use current balance (what's owed)
                // Loans: use current balance (principal remaining)
                if account.isCredit || account.isLoan {
                    return sum + abs(account.currentBalance ?? 0)
                }
                return sum
            }
        }

        // For other buckets, sum current balances
        return linkedAccounts.reduce(0) { sum, account in
            sum + (account.currentBalance ?? 0)
        }
    }

    // MARK: - Account Filtering

    /// Get accounts that can be linked to a specific bucket type
    func getEligibleAccounts(for bucketType: AllocationBucketType, from accounts: [BankAccount]) -> [BankAccount] {
        switch bucketType {
        case .essentialSpending:
            // Checking accounts only
            return accounts.filter { $0.type == "depository" && $0.subtype == "checking" }

        case .emergencyFund:
            // Savings accounts primarily, but allow checking
            return accounts.filter {
                $0.type == "depository" && ($0.subtype == "savings" || $0.subtype == "checking")
            }

        case .discretionarySpending:
            // Checking or savings accounts
            return accounts.filter { $0.isDepository }

        case .investments:
            // Investment accounts only
            return accounts.filter { $0.isInvestment }

        case .debtPaydown:
            // Credit cards and loans (excluding mortgage)
            return accounts.filter { account in
                if account.isCredit {
                    // Exclude mortgage if in subtype
                    if let subtype = account.subtype, subtype.contains("mortgage") {
                        return false
                    }
                    return true
                }

                if account.isLoan {
                    // Exclude mortgage loans
                    if let subtype = account.subtype, subtype.contains("mortgage") {
                        return false
                    }
                    return true
                }

                return false
            }
        }
    }

    // MARK: - Validation

    /// Check if an account can be linked to a bucket type
    func canLink(accountId: String, to bucketType: AllocationBucketType, accounts: [BankAccount]) -> (canLink: Bool, reason: String?) {
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            return (false, "Account not found")
        }

        let eligible = getEligibleAccounts(for: bucketType, from: accounts)

        if eligible.contains(where: { $0.id == accountId }) {
            return (true, nil)
        }

        // Provide helpful error message
        let reason: String
        switch bucketType {
        case .essentialSpending:
            reason = "Only checking accounts can be linked to Essential Spending"
        case .emergencyFund:
            reason = "Only savings and checking accounts can be linked to Emergency Fund"
        case .discretionarySpending:
            reason = "Only deposit accounts can be linked to Discretionary Spending"
        case .investments:
            reason = "Only investment accounts can be linked to Investments"
        case .debtPaydown:
            reason = "Only credit cards and loans can be linked to Debt Paydown"
        }

        return (false, reason)
    }
}

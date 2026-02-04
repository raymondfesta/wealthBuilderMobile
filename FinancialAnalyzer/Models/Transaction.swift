import Foundation

final class Transaction: Identifiable {
    var id: String
    var accountId: String
    var amount: Double
    var date: Date
    var name: String
    var merchantName: String?
    var category: [String]
    var categoryId: String?
    var pending: Bool
    var transactionType: String?
    var iso_currency_code: String?

    // Plaid Personal Finance Category with confidence scoring
    var personalFinanceCategory: PersonalFinanceCategory?

    // User validation tracking
    var userValidated: Bool = false
    var userCorrectedCategory: BucketCategory?

    // Computed property for high-level bucket categorization
    var bucketCategory: BucketCategory {
        // Use user correction if available
        if let corrected = userCorrectedCategory {
            return corrected
        }

        // Use Plaid PFC with confidence
        return TransactionAnalyzer.categorizeToBucket(
            amount: amount,
            category: category,
            categoryId: categoryId,
            personalFinanceCategory: personalFinanceCategory
        )
    }

    // Whether this transaction needs user validation
    var needsValidation: Bool {
        // Already validated by user
        if userValidated {
            return false
        }

        // Check Plaid confidence level
        if let pfc = personalFinanceCategory {
            return pfc.confidenceLevel.needsValidation
        }

        // No PFC data - assume needs validation
        return true
    }

    /// Whether this transaction has characteristics suggesting it might be a transfer
    /// These are flagged for user review, not auto-excluded
    var needsTransferReview: Bool {
        // Already validated by user - no review needed
        if userValidated { return false }

        // Already marked as excluded - no review needed
        if userCorrectedCategory == .excluded { return false }

        // Only check outflows (expenses)
        guard amount > 0 else { return false }

        // Check for transfer-like characteristics
        let nameLower = name.lowercased()
        let merchantLower = (merchantName ?? "").lowercased()

        // Pattern 1: Contains "transfer" keyword
        let hasTransferKeyword = nameLower.contains("transfer") ||
                                 nameLower.contains("xfer") ||
                                 merchantLower.contains("transfer")

        // Pattern 2: Contains bank name (suggesting inter-bank transfer)
        let bankNames = [
            "usaa", "chase", "wells fargo", "bank of america", "bofa",
            "capital one", "citi", "pnc", "td bank", "us bank", "ally",
            "discover", "marcus", "synchrony", "navy federal", "schwab",
            "fidelity", "vanguard", "etrade", "ameritrade"
        ]
        let hasBankName = bankNames.contains { nameLower.contains($0) || merchantLower.contains($0) }

        // Pattern 3: Round amount ($100, $500, $1000, etc.) - transfers are often round
        let isRoundAmount = amount.truncatingRemainder(dividingBy: 100) == 0 && abs(amount) >= 100

        // Pattern 4: Plaid category suggests transfer but not internal/same-institution
        let plaidSaysTransfer: Bool = {
            guard let pfc = personalFinanceCategory else { return false }
            let primary = pfc.primary.uppercased()
            let detailed = pfc.detailed.uppercased()

            // Must contain TRANSFER
            guard primary.contains("TRANSFER") || detailed.contains("TRANSFER") else { return false }

            // But NOT be same-institution (those are auto-handled)
            if detailed.contains("INTERNAL") || detailed.contains("SAME_INSTITUTION") {
                return false
            }

            return true
        }()

        // Flag for review if:
        // - Has transfer keyword AND round amount
        // - Has bank name AND round amount
        // - Plaid says transfer but not internal
        if hasTransferKeyword && isRoundAmount { return true }
        if hasBankName && isRoundAmount { return true }
        if plaidSaysTransfer { return true }

        return false
    }

    /// Combined flag: needs either confidence review OR transfer review
    var needsAnyReview: Bool {
        needsValidation || needsTransferReview
    }

    // Confidence level for UI display
    var confidenceLevel: ConfidenceLevel {
        return personalFinanceCategory?.confidenceLevel ?? .unknown
    }

    /// Numeric confidence score from PFC (plan compatibility)
    /// Returns 0.0-1.0 based on Plaid confidence level
    var categoryConfidence: Double? {
        switch personalFinanceCategory?.confidenceLevel {
        case .veryHigh: return 0.98
        case .high: return 0.90
        case .medium: return 0.75
        case .low: return 0.50
        case .unknown: return 0.25
        case .none: return nil
        }
    }

    init(
        id: String,
        accountId: String,
        amount: Double,
        date: Date,
        name: String,
        merchantName: String? = nil,
        category: [String] = [],
        categoryId: String? = nil,
        pending: Bool = false,
        transactionType: String? = nil,
        iso_currency_code: String? = nil,
        personalFinanceCategory: PersonalFinanceCategory? = nil,
        userValidated: Bool = false,
        userCorrectedCategory: BucketCategory? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.amount = amount
        self.date = date
        self.name = name
        self.merchantName = merchantName
        self.category = category
        self.categoryId = categoryId
        self.pending = pending
        self.transactionType = transactionType
        self.iso_currency_code = iso_currency_code
        self.personalFinanceCategory = personalFinanceCategory
        self.userValidated = userValidated
        self.userCorrectedCategory = userCorrectedCategory
    }
}

// MARK: - Codable for Plaid API response
extension Transaction: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case accountId
        case amount
        case date
        case name
        case merchantName
        case category
        case categoryId
        case pending
        case transactionType
        case iso_currency_code
        case personalFinanceCategory
        case userValidated
        case userCorrectedCategory
    }

    enum PlaidCodingKeys: String, CodingKey {
        case id = "transaction_id"
        case accountId = "account_id"
        case amount
        case date
        case name
        case merchantName = "merchant_name"
        case category
        case categoryId = "category_id"
        case pending
        case transactionType = "transaction_type"
        case iso_currency_code
        case personalFinanceCategory = "personal_finance_category"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(amount, forKey: .amount)
        try container.encode(date, forKey: .date)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(merchantName, forKey: .merchantName)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(pending, forKey: .pending)
        try container.encodeIfPresent(transactionType, forKey: .transactionType)
        try container.encodeIfPresent(iso_currency_code, forKey: .iso_currency_code)
        try container.encodeIfPresent(personalFinanceCategory, forKey: .personalFinanceCategory)
        try container.encode(userValidated, forKey: .userValidated)
        try container.encodeIfPresent(userCorrectedCategory, forKey: .userCorrectedCategory)
    }

    convenience init(from decoder: Decoder) throws {
        // Try Plaid format first
        if let container = try? decoder.container(keyedBy: PlaidCodingKeys.self) {
            let id = try container.decode(String.self, forKey: .id)
            let accountId = try container.decode(String.self, forKey: .accountId)
            let amount = try container.decode(Double.self, forKey: .amount)
            let dateString = try container.decode(String.self, forKey: .date)
            let name = try container.decode(String.self, forKey: .name)
            let merchantName = try? container.decode(String.self, forKey: .merchantName)
            let category = try container.decodeIfPresent([String].self, forKey: .category) ?? []
            let categoryId = try? container.decode(String.self, forKey: .categoryId)
            let pending = try container.decode(Bool.self, forKey: .pending)
            let transactionType = try? container.decode(String.self, forKey: .transactionType)
            let iso_currency_code = try? container.decode(String.self, forKey: .iso_currency_code)
            let personalFinanceCategory = try? container.decode(PersonalFinanceCategory.self, forKey: .personalFinanceCategory)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let date = formatter.date(from: dateString) ?? Date()

            self.init(
                id: id,
                accountId: accountId,
                amount: amount,
                date: date,
                name: name,
                merchantName: merchantName,
                category: category,
                categoryId: categoryId,
                pending: pending,
                transactionType: transactionType,
                iso_currency_code: iso_currency_code,
                personalFinanceCategory: personalFinanceCategory
            )
            return
        }

        // Fall back to standard format
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let accountId = try container.decode(String.self, forKey: .accountId)
        let amount = try container.decode(Double.self, forKey: .amount)
        let date = try container.decode(Date.self, forKey: .date)
        let name = try container.decode(String.self, forKey: .name)
        let merchantName = try? container.decode(String.self, forKey: .merchantName)
        let category = try container.decodeIfPresent([String].self, forKey: .category) ?? []
        let categoryId = try? container.decode(String.self, forKey: .categoryId)
        let pending = try container.decode(Bool.self, forKey: .pending)
        let transactionType = try? container.decode(String.self, forKey: .transactionType)
        let iso_currency_code = try? container.decode(String.self, forKey: .iso_currency_code)
        let personalFinanceCategory = try? container.decode(PersonalFinanceCategory.self, forKey: .personalFinanceCategory)
        let userValidated = try container.decodeIfPresent(Bool.self, forKey: .userValidated) ?? false
        let userCorrectedCategory = try? container.decode(BucketCategory.self, forKey: .userCorrectedCategory)

        self.init(
            id: id,
            accountId: accountId,
            amount: amount,
            date: date,
            name: name,
            merchantName: merchantName,
            category: category,
            categoryId: categoryId,
            pending: pending,
            transactionType: transactionType,
            iso_currency_code: iso_currency_code,
            personalFinanceCategory: personalFinanceCategory,
            userValidated: userValidated,
            userCorrectedCategory: userCorrectedCategory
        )
    }
}

import Foundation

/// User-defined tags for account designation
/// Allows users to mark accounts for specific purposes to improve health calculations
enum AccountTag: String, Codable, CaseIterable, Hashable {
    case emergencyFund = "Emergency Fund"
    case savingsGoal = "Savings Goal"
    case retirement = "Retirement"
    case investment = "Investment"
    case billPay = "Bill Pay"
    case discretionary = "Discretionary Spending"

    var icon: String {
        switch self {
        case .emergencyFund: return "shield.fill"
        case .savingsGoal: return "target"
        case .retirement: return "chart.line.uptrend.xyaxis"
        case .investment: return "chart.bar.fill"
        case .billPay: return "dollarsign.circle.fill"
        case .discretionary: return "creditcard.fill"
        }
    }

    var description: String {
        switch self {
        case .emergencyFund:
            return "3-12 months of essential expenses for emergencies"
        case .savingsGoal:
            return "Saving for specific goals (vacation, home, etc.)"
        case .retirement:
            return "Long-term retirement savings (401k, IRA, etc.)"
        case .investment:
            return "Investment accounts for wealth building"
        case .billPay:
            return "Primary account for paying bills and expenses"
        case .discretionary:
            return "Spending money for non-essential purchases"
        }
    }
}

final class BankAccount: Identifiable {
    var id: String
    var itemId: String
    var name: String
    var officialName: String?
    var type: String
    var subtype: String?
    var mask: String?
    var currentBalance: Double?
    var availableBalance: Double?
    var limit: Double?
    var minimumPayment: Double?
    var apr: Double?
    var isoCurrencyCode: String?
    var lastSyncDate: Date?

    // User-defined tags for account purposes
    var tags: Set<AccountTag> = []

    init(
        id: String,
        itemId: String,
        name: String,
        officialName: String? = nil,
        type: String,
        subtype: String? = nil,
        mask: String? = nil,
        currentBalance: Double? = nil,
        availableBalance: Double? = nil,
        limit: Double? = nil,
        minimumPayment: Double? = nil,
        apr: Double? = nil,
        isoCurrencyCode: String? = nil,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.name = name
        self.officialName = officialName
        self.type = type
        self.subtype = subtype
        self.mask = mask
        self.currentBalance = currentBalance
        self.availableBalance = availableBalance
        self.limit = limit
        self.minimumPayment = minimumPayment
        self.apr = apr
        self.isoCurrencyCode = isoCurrencyCode
        self.lastSyncDate = lastSyncDate
    }
}

// MARK: - Account Types
extension BankAccount {
    var isDepository: Bool {
        type == "depository"
    }

    var isCredit: Bool {
        type == "credit"
    }

    var isLoan: Bool {
        type == "loan"
    }

    var isInvestment: Bool {
        type == "investment" || type == "brokerage"
    }

    // MARK: - Tag Helpers

    var isEmergencyFund: Bool {
        tags.contains(.emergencyFund)
    }

    var isSavingsGoal: Bool {
        tags.contains(.savingsGoal)
    }

    func addTag(_ tag: AccountTag) {
        tags.insert(tag)
    }

    func removeTag(_ tag: AccountTag) {
        tags.remove(tag)
    }

    func hasTag(_ tag: AccountTag) -> Bool {
        tags.contains(tag)
    }
}

// MARK: - Codable for Plaid API response
extension BankAccount: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case itemId
        case name
        case officialName
        case type
        case subtype
        case mask
        case currentBalance
        case availableBalance
        case limit
        case minimumPayment
        case apr
        case isoCurrencyCode
        case lastSyncDate
        case tags
    }

    enum PlaidCodingKeys: String, CodingKey {
        case id = "account_id"
        case itemId = "item_id"
        case name
        case officialName = "official_name"
        case type
        case subtype
        case mask
        case balances
    }

    enum BalanceKeys: String, CodingKey {
        case current
        case available
        case limit
        case isoCurrencyCode = "iso_currency_code"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(itemId, forKey: .itemId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(officialName, forKey: .officialName)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(subtype, forKey: .subtype)
        try container.encodeIfPresent(mask, forKey: .mask)
        try container.encodeIfPresent(currentBalance, forKey: .currentBalance)
        try container.encodeIfPresent(availableBalance, forKey: .availableBalance)
        try container.encodeIfPresent(limit, forKey: .limit)
        try container.encodeIfPresent(minimumPayment, forKey: .minimumPayment)
        try container.encodeIfPresent(apr, forKey: .apr)
        try container.encodeIfPresent(isoCurrencyCode, forKey: .isoCurrencyCode)
        try container.encodeIfPresent(lastSyncDate, forKey: .lastSyncDate)
        try container.encode(Array(tags), forKey: .tags) // Encode Set as Array
    }

    convenience init(from decoder: Decoder) throws {
        // Try Plaid format first
        if let container = try? decoder.container(keyedBy: PlaidCodingKeys.self) {
            let id = try container.decode(String.self, forKey: .id)
            // Decode item_id from backend-injected field (backend adds this)
            let itemId = (try? container.decode(String.self, forKey: .itemId)) ?? ""
            let name = try container.decode(String.self, forKey: .name)
            let officialName = try? container.decode(String.self, forKey: .officialName)
            let type = try container.decode(String.self, forKey: .type)
            let subtype = try? container.decode(String.self, forKey: .subtype)
            let mask = try? container.decode(String.self, forKey: .mask)

            // Parse balances
            let balancesContainer = try container.nestedContainer(keyedBy: BalanceKeys.self, forKey: .balances)
            let currentBalance = try? balancesContainer.decode(Double.self, forKey: .current)
            let availableBalance = try? balancesContainer.decode(Double.self, forKey: .available)
            let limit = try? balancesContainer.decode(Double.self, forKey: .limit)
            let isoCurrencyCode = try? balancesContainer.decode(String.self, forKey: .isoCurrencyCode)

            self.init(
                id: id,
                itemId: itemId,
                name: name,
                officialName: officialName,
                type: type,
                subtype: subtype,
                mask: mask,
                currentBalance: currentBalance,
                availableBalance: availableBalance,
                limit: limit,
                isoCurrencyCode: isoCurrencyCode
            )
            return
        }

        // Fall back to standard format
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let itemId = try container.decode(String.self, forKey: .itemId)
        let name = try container.decode(String.self, forKey: .name)
        let officialName = try? container.decode(String.self, forKey: .officialName)
        let type = try container.decode(String.self, forKey: .type)
        let subtype = try? container.decode(String.self, forKey: .subtype)
        let mask = try? container.decode(String.self, forKey: .mask)
        let currentBalance = try? container.decode(Double.self, forKey: .currentBalance)
        let availableBalance = try? container.decode(Double.self, forKey: .availableBalance)
        let limit = try? container.decode(Double.self, forKey: .limit)
        let minimumPayment = try? container.decode(Double.self, forKey: .minimumPayment)
        let apr = try? container.decode(Double.self, forKey: .apr)
        let isoCurrencyCode = try? container.decode(String.self, forKey: .isoCurrencyCode)
        let lastSyncDate = try? container.decode(Date.self, forKey: .lastSyncDate)
        let tagsArray = try container.decodeIfPresent([AccountTag].self, forKey: .tags) ?? []

        self.init(
            id: id,
            itemId: itemId,
            name: name,
            officialName: officialName,
            type: type,
            subtype: subtype,
            mask: mask,
            currentBalance: currentBalance,
            availableBalance: availableBalance,
            limit: limit,
            minimumPayment: minimumPayment,
            apr: apr,
            isoCurrencyCode: isoCurrencyCode,
            lastSyncDate: lastSyncDate
        )

        // Apply tags after initialization
        self.tags = Set(tagsArray)
    }
}

import Foundation

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
    var isoCurrencyCode: String?
    var lastSyncDate: Date?

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
        case isoCurrencyCode
        case lastSyncDate
    }

    enum PlaidCodingKeys: String, CodingKey {
        case id = "account_id"
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
        try container.encodeIfPresent(isoCurrencyCode, forKey: .isoCurrencyCode)
        try container.encodeIfPresent(lastSyncDate, forKey: .lastSyncDate)
    }

    convenience init(from decoder: Decoder) throws {
        // Try Plaid format first
        if let container = try? decoder.container(keyedBy: PlaidCodingKeys.self) {
            let id = try container.decode(String.self, forKey: .id)
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
                itemId: "",
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
        let isoCurrencyCode = try? container.decode(String.self, forKey: .isoCurrencyCode)
        let lastSyncDate = try? container.decode(Date.self, forKey: .lastSyncDate)

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
            isoCurrencyCode: isoCurrencyCode,
            lastSyncDate: lastSyncDate
        )
    }
}

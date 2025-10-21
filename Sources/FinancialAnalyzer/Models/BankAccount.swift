import Foundation
import SwiftData

@Model
final class BankAccount {
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

// MARK: - Decodable for Plaid API response
extension BankAccount: Decodable {
    enum CodingKeys: String, CodingKey {
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

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

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
            itemId: "", // Will be set by the service
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
    }
}

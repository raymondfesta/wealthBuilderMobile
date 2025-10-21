import Foundation
import SwiftData

@Model
final class Transaction {
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

    // Computed property for high-level bucket categorization
    var bucketCategory: BucketCategory {
        return TransactionAnalyzer.categorizeToBucket(
            amount: amount,
            category: category,
            categoryId: categoryId
        )
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
        iso_currency_code: String? = nil
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
    }
}

// MARK: - Decodable for Plaid API response
extension Transaction: Decodable {
    enum CodingKeys: String, CodingKey {
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
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

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

        // Parse date string (format: YYYY-MM-DD)
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
            iso_currency_code: iso_currency_code
        )
    }
}

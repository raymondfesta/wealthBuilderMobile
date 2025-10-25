import Foundation

/// Represents Plaid's Personal Finance Category with confidence level
/// Provides 90%+ categorization accuracy with transparency about uncertainty
struct PersonalFinanceCategory: Codable {
    /// High-level category (16 primary categories)
    /// Examples: INCOME, TRANSFER_IN, TRANSFER_OUT, LOAN_PAYMENTS, etc.
    let primary: String

    /// Granular category (104 detailed categories)
    /// Examples: INCOME_WAGES, FOOD_AND_DRINK_RESTAURANTS, etc.
    let detailed: String

    /// Plaid's confidence in this categorization
    let confidenceLevel: ConfidenceLevel

    enum CodingKeys: String, CodingKey {
        case primary
        case detailed
        case confidenceLevel = "confidence_level"
    }
}

/// Plaid's confidence levels for transaction categorization
enum ConfidenceLevel: String, Codable {
    /// More than 98% confident this category reflects the transaction's intent
    case veryHigh = "VERY_HIGH"

    /// More than 90% confident this category reflects the transaction's intent
    case high = "HIGH"

    /// Moderately confident this category reflects the transaction's intent
    case medium = "MEDIUM"

    /// Low confidence in this categorization
    case low = "LOW"

    /// Unable to determine confidence
    case unknown = "UNKNOWN"

    /// Whether this transaction needs user validation
    /// Only transactions with LOW or UNKNOWN confidence need validation
    /// MEDIUM confidence is still reasonably accurate (~85-90%) and typically correct
    var needsValidation: Bool {
        switch self {
        case .veryHigh, .high, .medium:
            return false
        case .low, .unknown:
            return true
        }
    }

    /// Color indicator for UI display
    var displayColor: String {
        switch self {
        case .veryHigh, .high:
            return "green"
        case .medium:
            return "yellow"
        case .low, .unknown:
            return "orange"
        }
    }

    /// User-friendly description
    var description: String {
        switch self {
        case .veryHigh:
            return "Very confident (>98%)"
        case .high:
            return "Confident (>90%)"
        case .medium:
            return "Moderately confident"
        case .low:
            return "Low confidence"
        case .unknown:
            return "Uncertain"
        }
    }
}

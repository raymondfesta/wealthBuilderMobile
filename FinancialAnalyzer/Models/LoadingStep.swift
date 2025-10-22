import Foundation

/// Represents different loading steps in the account connection flow
enum LoadingStep: Equatable {
    case idle
    case connectingToBank
    case fetchingAccounts
    case analyzingTransactions(count: Int)
    case generatingBudgets
    case complete

    var stepNumber: Int {
        switch self {
        case .idle: return -1
        case .connectingToBank: return 0
        case .fetchingAccounts: return 1
        case .analyzingTransactions: return 2
        case .generatingBudgets: return 3
        case .complete: return 4
        }
    }

    var title: String {
        switch self {
        case .idle:
            return "Preparing..."
        case .connectingToBank:
            return "Connecting to Bank"
        case .fetchingAccounts:
            return "Fetching Accounts"
        case .analyzingTransactions(let count):
            if count > 0 {
                return "Analyzing \(count) Transactions"
            } else {
                return "Analyzing Transactions"
            }
        case .generatingBudgets:
            return "Generating Budgets"
        case .complete:
            return "Complete"
        }
    }

    var message: String {
        switch self {
        case .idle:
            return "Setting up your connection..."
        case .connectingToBank:
            return "Establishing secure connection..."
        case .fetchingAccounts:
            return "Loading your account information..."
        case .analyzingTransactions(let count):
            if count > 0 {
                return "Processing your spending patterns..."
            } else {
                return "Retrieving transaction history..."
            }
        case .generatingBudgets:
            return "Creating personalized budgets..."
        case .complete:
            return "Your financial data is ready!"
        }
    }

    static let allSteps: [LoadingStep] = [
        .connectingToBank,
        .fetchingAccounts,
        .analyzingTransactions(count: 0),
        .generatingBudgets,
        .complete
    ]
}

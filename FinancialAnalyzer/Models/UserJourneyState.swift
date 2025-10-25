import Foundation

/// Tracks user's progress through the financial planning flow
enum UserJourneyState: String, Codable {
    case noAccountsConnected     // Empty state - no data
    case accountsConnected       // Accounts visible, analysis not run yet
    case analysisComplete        // Analysis report available, plan not created
    case allocationPlanning      // User is reviewing allocation recommendations
    case planCreated             // Budget plan exists and is active

    /// Human-readable title for each state
    var title: String {
        switch self {
        case .noAccountsConnected:
            return "Get Started"
        case .accountsConnected:
            return "Accounts Connected"
        case .analysisComplete:
            return "Analysis Complete"
        case .allocationPlanning:
            return "Review Your Plan"
        case .planCreated:
            return "Plan Active"
        }
    }

    /// Description of what happens in this state
    var description: String {
        switch self {
        case .noAccountsConnected:
            return "Connect your bank account to begin"
        case .accountsConnected:
            return "Ready to analyze your finances"
        case .analysisComplete:
            return "Review your spending breakdown"
        case .allocationPlanning:
            return "Review AI-generated allocation recommendations"
        case .planCreated:
            return "Your plan is active and tracking"
        }
    }

    /// Next action title for CTA buttons
    var nextActionTitle: String {
        switch self {
        case .noAccountsConnected:
            return "Connect Your Bank Account"
        case .accountsConnected:
            return "Analyze My Transactions"
        case .analysisComplete:
            return "Create My Financial Plan"
        case .allocationPlanning:
            return "Accept Plan"
        case .planCreated:
            return "View My Plan"
        }
    }

    /// Whether certain actions are allowed in this state
    var canConnectAccount: Bool {
        true // Always allow connecting additional accounts
    }

    var canAnalyze: Bool {
        self == .accountsConnected || self == .planCreated
    }

    var canCreatePlan: Bool {
        self == .analysisComplete || self == .allocationPlanning
    }

    var canReviewAllocation: Bool {
        self == .allocationPlanning
    }
}

# Proactive Decision-Point Guidance with AI

## Overview

This feature transforms your financial app from a **reactive tracker** into a **proactive advisor** that helps users make better spending decisions in real-time, before they happen.

## Key Problem Solved

Based on the market research analysis, existing finance apps fail because they:
- Show where money *went* instead of guiding where it *should go*
- Provide post-mortem analysis after purchases are made
- Aren't present at decision points when users need guidance most

**This feature solves that by being there when users are about to spend.**

---

## Feature Components

### 1. **Core Data Models**

#### Budget Model ([Budget.swift](Sources/FinancialAnalyzer/Models/Budget.swift))
- Tracks spending limits per category per month
- Auto-generates budgets from spending history
- Provides real-time status (on track, warning, exceeded)
- Calculates remaining budget and daily averages

#### Goal Model ([Goal.swift](Sources/FinancialAnalyzer/Models/Goal.swift))
- Emergency funds, vacations, debt payoff, etc.
- Priority-based goal tracking
- Progress monitoring with milestone notifications
- Suggested monthly contribution calculations

### 2. **Intelligence Layer**

#### SpendingPatternAnalyzer ([SpendingPatternAnalyzer.swift](Sources/FinancialAnalyzer/Services/SpendingPatternAnalyzer.swift))
- Analyzes 3+ months of transaction history
- Detects merchant-specific patterns (avg spend, frequency)
- Identifies category trends (increasing, stable, decreasing)
- Predicts upcoming bills and cash flow
- Detects spending anomalies (unusually high, too frequent)

#### AlertRulesEngine ([AlertRulesEngine.swift](Sources/FinancialAnalyzer/Services/AlertRulesEngine.swift))
- Evaluates purchases before they happen
- Generates context-aware alerts:
  - Budget exceeded warnings with reallocation options
  - On-track positive reinforcement
  - Unusual spending pattern alerts
  - Goal impact notifications
  - Cash flow risk warnings
  - Savings opportunity suggestions

### 3. **AI-Powered Insights**

#### Backend API ([backend/server.js](backend/server.js))
**New endpoints:**

##### `POST /api/ai/purchase-insight`
Generates personalized AI insights for purchase decisions
```json
{
  "amount": 87.43,
  "merchantName": "Target",
  "category": "Shopping",
  "budgetStatus": {
    "currentSpent": 250,
    "limit": 300,
    "remaining": 50,
    "daysRemaining": 12
  },
  "spendingPattern": {
    "averageAmount": 45,
    "frequency": 2.5
  }
}
```

**Response:**
```json
{
  "insight": "You typically spend $140/month at Target. This keeps you 38% below your usual spending. You have enough cushion for groceries this week.",
  "usage": { "total_tokens": 127 }
}
```

##### `POST /api/ai/savings-recommendation`
Recommends how to allocate surplus money
```json
{
  "surplusAmount": 200,
  "monthlyExpenses": 2500,
  "currentSavings": 3000,
  "goals": [
    { "name": "Emergency Fund", "current": 3000, "target": 15000, "priority": "high" }
  ]
}
```

### 4. **User Experience**

#### ProactiveGuidanceView ([ProactiveGuidanceView.swift](Sources/FinancialAnalyzer/Views/ProactiveGuidanceView.swift))

**Full Alert Screen:**
- Clear visual hierarchy (icon, severity, title)
- Budget impact summary with before/after comparison
- AI-generated insights in dedicated section
- Multiple action buttons with clear descriptions
- Progress bars and remaining days display

**Quick Decision Sheet:**
- Simplified bottom sheet for fast decisions
- Shows merchant name and amount prominently
- Before/after budget comparison
- Two-button choice: Confirm or Not Now

#### NotificationService ([NotificationService.swift](Sources/FinancialAnalyzer/Services/NotificationService.swift))

**Notification Types:**
1. **Purchase Alerts** - "💡 Budget Check: Target"
2. **Savings Opportunities** - "✨ Smart Money Alert"
3. **Cash Flow Warnings** - "⚡ Cash Flow Alert"
4. **Weekly Reviews** - "📊 Weekly Financial Review"
5. **Goal Milestones** - "🎯 Goal Milestone!"

**Interactive Actions:**
- Swipe to confirm purchase
- Swipe to review budget
- Tap to open full guidance view

#### BudgetManager ([BudgetManager.swift](Sources/FinancialAnalyzer/Services/BudgetManager.swift))

**Budget Operations:**
- Auto-generate budgets from history
- Track spending in real-time
- Reallocate between categories
- Reset monthly budgets

**Goal Operations:**
- Create/update/delete goals
- Contribute to goals
- Milestone tracking with auto-notifications
- Priority-based recommendations

**Quick Actions:**
- Confirm purchase → Updates budget immediately
- Defer purchase → Schedules reminder for next month
- Transfer money → (Future: Plaid Transfer API integration)

---

## Customer Experience Flows

### Flow 1: Pre-Purchase Budget Check

```
User is at Target checkout with $87.43 purchase
    ↓
App detects pending transaction (or user manually enters)
    ↓
AlertRulesEngine evaluates:
  - Current Shopping budget: $250/$300 spent
  - After purchase: $337.43 (over by $37.43)
  - Days remaining: 12
    ↓
Push notification: "💡 Budget Check: Target"
Body: "⚠️ This exceeds your Shopping budget"
    ↓
User taps notification
    ↓
ProactiveGuidanceView opens showing:
  - "Over Budget: Shopping"
  - Impact: Current $50 → After -$37.43
  - AI Insight: "You typically spend $140/month at Target..."
  - Actions:
    • Pull from Entertainment ($175 available)
    • Use Disposable Income ($1,247)
    • Wait Until Next Month (12 days)
    ↓
User selects "Pull from Entertainment"
    ↓
BudgetManager.reallocateBudget() executes
    ↓
Budget updated: Entertainment $175→$138, Shopping $300→$337
    ↓
Purchase confirmed ✓
```

### Flow 2: Savings Opportunity

```
It's day 15 of month
    ↓
User spent $200 less than budgeted
    ↓
AlertRulesEngine.evaluateSavingsOpportunity() runs
    ↓
Notification: "✨ Smart Money Alert"
Body: "You're $200 under budget! Consider adding to Emergency Fund."
    ↓
User taps
    ↓
ProactiveGuidanceView shows:
  - "You're $200 Under Budget!"
  - AI Recommendation: "Add $200 to Emergency Fund
    to reach your goal 3 months faster"
  - Actions:
    • Add to Emergency Fund → $3,200/$5,000 (72% complete)
    • Add to Vacation Fund → $1,450/$3,000
    • Keep as Flexible Buffer
    ↓
User selects "Add to Emergency Fund"
    ↓
BudgetManager.contributeToGoal() executes
    ↓
Goal updated: $3,000 → $3,200
    ↓
Success confirmation ✓
```

### Flow 3: Cash Flow Warning

```
7 days before large bill ($199 Netflix annual)
    ↓
SpendingPatternAnalyzer.predictCashFlow() runs:
  - Current checking: $847
  - Upcoming bills (7 days):
    • Netflix: $199 (in 3 days)
    • Electric: $127 (in 5 days)
  - Projected balance: $521
  - Risk level: Medium
    ↓
Notification: "⚡ Cash Flow Alert"
Body: "$326 in bills coming in 7 days. Current balance: $847"
    ↓
User taps
    ↓
ProactiveGuidanceView shows:
  - "Cash Flow Alert"
  - Upcoming bills list with dates
  - Projected balance: $521
  - Actions:
    • Move $200 from Savings
    • Review Upcoming Bills
    • I'll Handle It
    ↓
User selects "Move $200 from Savings"
    ↓
BudgetManager.transferMoney() executes
    ↓
Checking updated: $847 → $1,047
Savings updated: $3,200 → $3,000
    ↓
Cash flow secured ✓
```

---

## Setup Instructions

### 1. Backend Setup

**Install dependencies:**
```bash
cd backend
npm install openai
```

**Add OpenAI API key to `.env`:**
```bash
OPENAI_API_KEY=sk-your-key-here
```

**Test the AI endpoints:**
```bash
npm run dev

# In another terminal:
curl -X POST http://localhost:3000/api/ai/purchase-insight \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 87.43,
    "merchantName": "Target",
    "category": "Shopping",
    "budgetStatus": {
      "currentSpent": 250,
      "limit": 300,
      "remaining": 50,
      "daysRemaining": 12
    }
  }'
```

### 2. iOS App Setup

**Update App Delegate to register notifications:**

In your app's initialization (e.g., `FinancialAnalyzerApp.swift`):

```swift
import SwiftUI
import UserNotifications

@main
struct FinancialAnalyzerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate()

        // Register notification actions
        NotificationService.shared.registerNotificationActions()

        // Request notification permission
        Task {
            try? await NotificationService.shared.requestAuthorization()
        }

        return true
    }
}
```

**Add Info.plist entry for notifications:**
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>We'll send you helpful alerts about your budget and spending decisions to help you stay on track.</string>
```

### 3. Integration with Existing App

**Update FinancialViewModel to include budget tracking:**

```swift
@MainActor
class FinancialViewModel: ObservableObject {
    // ... existing properties

    @Published var budgetManager: BudgetManager

    init(plaidService: PlaidService = PlaidService(), modelContext: ModelContext? = nil) {
        self.plaidService = plaidService
        self.modelContext = modelContext
        self.budgetManager = BudgetManager(modelContext: modelContext)
    }

    func refreshData() async {
        // ... existing code

        // Generate budgets from transactions
        budgetManager.generateBudgets(from: allTransactions)

        // Check for savings opportunities
        if let savingsAlert = AlertRulesEngine.evaluateSavingsOpportunity(
            budgets: budgetManager.budgets,
            goals: budgetManager.goals,
            transactions: allTransactions
        ) {
            // Show alert or schedule notification
            try? await NotificationService.shared.scheduleSavingsOpportunityAlert(
                surplusAmount: 200,
                recommendedGoal: "Emergency Fund"
            )
        }
    }
}
```

### 4. Add Budget Dashboard View

Create a new tab or section to display budgets:

```swift
struct BudgetDashboardView: View {
    @ObservedObject var budgetManager: BudgetManager

    var body: some View {
        List {
            Section("Budget Summary") {
                let summary = budgetManager.getCurrentMonthSummary()
                SummaryCard(summary: summary)
            }

            Section("Categories") {
                ForEach(budgetManager.budgets) { budget in
                    BudgetRow(budget: budget)
                }
            }

            Section("Goals") {
                ForEach(budgetManager.goals) { goal in
                    GoalRow(goal: goal)
                }
            }
        }
    }
}
```

---

## Testing the Feature

### Test Scenario 1: Budget Alert

```swift
// In a test view or button action:
let testBudget = Budget(
    categoryName: "Dining",
    monthlyLimit: 200,
    currentSpent: 180
)

let alert = AlertRulesEngine.evaluatePurchase(
    amount: 50,
    merchantName: "Starbucks",
    category: "Dining",
    budgets: [testBudget],
    goals: [],
    transactions: [],
    availableToSpend: 1200
)

// Show the alert
showProactiveGuidance(alert: alert.first!)
```

### Test Scenario 2: Notification

```swift
Task {
    try await NotificationService.shared.schedulePurchaseAlert(
        amount: 87.43,
        merchantName: "Target",
        budgetRemaining: 112,
        category: "Shopping",
        triggerInSeconds: 5 // 5 seconds for testing
    )
}
```

### Test Scenario 3: AI Insight

```bash
# Test backend API
curl -X POST http://localhost:3000/api/ai/purchase-insight \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 200,
    "merchantName": "Whole Foods",
    "category": "Groceries",
    "budgetStatus": {
      "currentSpent": 300,
      "limit": 400,
      "remaining": 100,
      "daysRemaining": 10
    }
  }'
```

---

## Next Steps for Production

### Phase 1: Enhanced AI Context
- [ ] Add user spending personality detection (frugal, balanced, spender)
- [ ] Learn from user decisions (which alerts they follow/ignore)
- [ ] Personalize AI tone based on user preferences
- [ ] Add seasonal spending pattern recognition

### Phase 2: Real-Time Purchase Detection
- [ ] Integrate with Plaid Transactions Webhooks for instant alerts
- [ ] Add location-based merchant proximity alerts (CoreLocation)
- [ ] Support for linked credit card pending transactions
- [ ] Apple Pay transaction interception (if possible via Apple Wallet)

### Phase 3: Advanced Money Movement
- [ ] Integrate Plaid Transfer API for actual money transfers
- [ ] Add bill payment scheduling and optimization
- [ ] Implement round-up savings (like Acorns)
- [ ] Auto-allocate surplus to goals based on priority

### Phase 4: Social & Accountability
- [ ] Partner/family budget sharing
- [ ] Accountability buddy system
- [ ] Community spending benchmarks
- [ ] Financial coach integration for premium tier

### Phase 5: Analytics & Improvement
- [ ] Track alert effectiveness (open rate, action rate)
- [ ] A/B test notification timing and wording
- [ ] Measure budget adherence improvement
- [ ] User satisfaction surveys after 30/60/90 days

---

## Success Metrics

**Engagement Metrics:**
- Notification open rate (Target: >40%)
- Action taken rate (Target: >25%)
- 7-day active users who received alerts (Target: >60%)

**Financial Outcome Metrics:**
- Budget adherence improvement (Target: +15%)
- Savings rate increase (Target: +10%)
- Reduced overdrafts/declined transactions (Target: -50%)

**User Satisfaction:**
- "Helpful" rating on alerts (Target: >70%)
- 30-day retention of feature users (Target: >60%)
- NPS score for feature (Target: >40)

---

## Architecture Decisions

### Why Local Notifications?
- Works even when backend is down
- Faster response time (no network latency)
- Better privacy (no need to send notifications through server)
- Leverages iOS notification system UX

### Why OpenAI GPT-4o-mini?
- Cost-effective ($0.15/1M input tokens vs $5 for GPT-4)
- Fast response times (<2s typical)
- Sufficient quality for 2-3 sentence insights
- Easy to upgrade to GPT-4 if needed

### Why SwiftData?
- Native iOS persistence (no external dependencies)
- Type-safe queries
- Automatic iCloud sync (if enabled)
- Better performance than CoreData for modern apps

### Why Pattern Analysis vs Pure ML?
- Transparent logic users can understand
- No training data required
- Works from day 1 with minimal history
- Can be explained in UI ("You typically spend...")
- Easy to debug and improve

---

## Security & Privacy Considerations

### Data Minimization
- Never send raw transaction data to OpenAI
- Use aggregated summaries only (amounts, categories, patterns)
- Anonymize merchant names in AI prompts when possible

### Local-First Architecture
- Budgets and goals stored locally in SwiftData
- Only budget summaries sent to backend for AI
- Notifications generated and scheduled locally
- User retains full control over data

### API Key Protection
- OpenAI key stored in backend `.env` (never in app)
- Rate limiting on AI endpoints (prevent abuse)
- API cost monitoring and alerts
- Fallback to rule-based insights if API fails

### User Consent
- Explicit permission for notifications
- Opt-in for AI-powered insights
- Clear explanation of what data is used
- Easy opt-out in settings

---

## Files Created

**Models:**
- `Sources/FinancialAnalyzer/Models/Budget.swift`
- `Sources/FinancialAnalyzer/Models/Goal.swift`

**Services:**
- `Sources/FinancialAnalyzer/Services/SpendingPatternAnalyzer.swift`
- `Sources/FinancialAnalyzer/Services/AlertRulesEngine.swift`
- `Sources/FinancialAnalyzer/Services/NotificationService.swift`
- `Sources/FinancialAnalyzer/Services/BudgetManager.swift`

**Views:**
- `Sources/FinancialAnalyzer/Views/ProactiveGuidanceView.swift`

**Backend:**
- Updated `backend/server.js` with AI endpoints
- Updated `backend/package.json` with OpenAI dependency

**Documentation:**
- This file: `PROACTIVE_GUIDANCE_FEATURE.md`

---

## Questions or Issues?

This feature represents a significant enhancement to your financial app. The key differentiator is being **proactive instead of reactive** - exactly what the market research identified as the critical gap.

For questions about:
- **Implementation**: Check the inline code comments and Swift previews
- **Testing**: See "Testing the Feature" section above
- **Integration**: See "Integration with Existing App" section
- **Backend**: Test the `/api/ai/*` endpoints with curl or Postman

**Remember:** Start simple. Get the basic budget alerts working first, then layer on AI insights, then add goal tracking. Each component works independently.

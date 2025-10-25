# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A native iOS financial app (SwiftUI) with Node.js backend that connects to bank accounts via Plaid API and provides proactive AI-powered financial guidance. The app analyzes transactions, categorizes spending into 6 high-level buckets, and uses GPT-4 to provide decision-point guidance before purchases happen.

## Development Commands

### Backend
```bash
# Start development server with auto-reload
cd backend
npm run dev

# Production server
npm start

# Install dependencies
npm install
```

### iOS App
```bash
# Build and run (from Xcode)
# Select simulator/device, then Cmd+R

# Clean build
# Shift+Cmd+K in Xcode

# Reset package caches
# File → Packages → Reset Package Caches in Xcode
```

### Testing

#### Plaid Sandbox Test Users

**Basic Test User (Minimal Data):**
```bash
Username: user_good
Password: pass_good
MFA Code: 1234
```
Use this for quick connectivity tests, but data is minimal (few transactions, simple account structure).

**Stress Test User (Recommended - Rich Data):**
```bash
Username: user_custom
Password: [paste contents of plaid_custom_user_config.json]
```

The custom user configuration provides:
- **10 accounts** across checking, savings, investments, and credit cards
- **~230 transactions** over 7 months (April - October 2025) with realistic spending patterns
- **Complex money flows** between accounts (transfers, payments, contributions)
- **Edge cases** including refunds, dividends, interest income, employer matches
- **Auto-categorized transactions** via Plaid's Personal Finance Categories (assigned after creation)

**How to Use Custom User:**
1. Copy the entire contents of `plaid_custom_user_config.json`
2. In Plaid Link modal, enter:
   - Username: `user_custom`
   - Password: Paste the JSON (yes, the entire JSON object!)
3. Complete the flow - Plaid will create all 10 accounts with transaction history
4. **Wait 10-15 seconds** after connection for Plaid to assign transaction categories
5. Pull to refresh to see updated categories with confidence levels

**Alternative: Persona-Based Users (Medium Complexity):**
- `user_yuppie` - Young professional with varied spending
- `user_small_business` - Small business account
- `user_credit_profile_excellent` - High earner, positive cash flow
- `user_credit_profile_good` - Moderate income, gig economy
- Password: any value

#### API Testing
```bash
# Test AI endpoints
curl -X POST http://localhost:3000/api/ai/purchase-insight \
  -H "Content-Type: application/json" \
  -d '{"amount": 87.43, "merchantName": "Target", "category": "Shopping", "budgetStatus": {"currentSpent": 250, "limit": 300, "remaining": 50, "daysRemaining": 12}}'

# Check server health
curl http://localhost:3000/health

# Debug stored items
curl http://localhost:3000/api/debug/items
```

## Architecture

### Tech Stack
- **iOS**: SwiftUI + MVVM pattern
- **Backend**: Node.js/Express
- **APIs**: Plaid (banking), OpenAI GPT-4o-mini (insights)
- **Storage**: iOS Keychain (tokens), UserDefaults (cache), JSON file (backend tokens)
- **Notifications**: iOS UserNotifications framework

### Project Structure
```
FinancialAnalyzer/
├── Models/                    # Data models
│   ├── Transaction.swift      # Plaid transaction model
│   ├── BankAccount.swift      # Account data with itemId tracking
│   ├── Budget.swift           # Monthly spending limits per category
│   ├── Goal.swift             # Financial goals (emergency fund, etc)
│   ├── FinancialHealthMetrics.swift # Health metrics (customer + backend)
│   ├── AllocationBucket.swift # 4 allocation buckets (essential, emergency, discretionary, investment)
│   └── UserJourneyState.swift # User onboarding state machine
├── Services/                  # Business logic
│   ├── PlaidService.swift     # Plaid API integration + link token caching
│   ├── BudgetManager.swift    # Budget/goal CRUD + health-aware allocation
│   ├── FinancialHealthCalculator.swift # Calculates health score & metrics
│   ├── AlertRulesEngine.swift # Evaluates purchases, generates alerts
│   ├── SpendingPatternAnalyzer.swift # Pattern detection from history
│   └── NotificationService.swift # Push notifications + actions
├── ViewModels/
│   └── FinancialViewModel.swift # Main app state + data flow coordination
├── Views/
│   ├── DashboardView.swift    # Shows health section + allocation buckets
│   ├── FinancialHealthReportView.swift # Comprehensive health report (onboarding)
│   ├── FinancialHealthDashboardSection.swift # Compact health monitoring
│   ├── AllocationPlannerView.swift # 4-bucket allocation interface
│   ├── ProactiveGuidanceView.swift # Alert UI with AI insights
│   ├── ProactiveGuidanceDemoView.swift # Testing interface
│   └── Components/
│       └── HealthReportComponents.swift # Reusable metric cards, progress bars
└── Utilities/
    ├── ColorPalette.swift     # Encouraging color design system
    └── DataResetManager.swift # Centralized data reset for testing

backend/
├── server.js                  # Express server with Plaid + OpenAI routes + health-aware allocation
└── plaid_tokens.json         # Persistent token storage (gitignored)
```

### Data Flow: Bank Account Connection
1. User taps "+" button → `FinancialViewModel.connectBankAccount()`
2. Gets cached link token from `PlaidService.getLinkToken()` (preloaded in background)
3. Opens Plaid Link modal → user authenticates with bank
4. Plaid returns `public_token` → exchange for `access_token` via backend `/api/plaid/exchange_public_token`
5. Backend stores token in `plaid_tokens.json` + returns `item_id`
6. iOS stores `access_token` in Keychain with `item_id` as key
7. Fetch accounts + 6 months transactions → analyze → update UI
8. Generate budgets from transaction history → check for savings opportunities

### Data Flow: Proactive Guidance
1. User enters purchase amount in Demo tab (or real transaction detected)
2. `AlertRulesEngine.evaluatePurchase()` runs:
   - Check current budget status for category
   - Analyze spending patterns (avg amount, frequency)
   - Calculate impact on goals
   - Generate context for AI
3. Call backend `/api/ai/purchase-insight` with anonymized data
4. Display `ProactiveGuidanceView` with:
   - Budget impact (before/after)
   - AI-generated insight
   - Action buttons (confirm, reallocate, defer)
5. User selects action → `BudgetManager` updates state → persist

### Data Flow: Financial Health Report

The Financial Health Report feature provides customers with a comprehensive yet encouraging view of their financial situation, using metrics that foster progress rather than judgment.

#### User Journey Flow

1. **Account Connection** → User connects bank accounts via Plaid
2. **Transaction Analysis** → `FinancialViewModel.analyzeMyFinances()` fetches 6 months of transactions
3. **Health Calculation** → `FinancialHealthCalculator.calculateHealthMetrics()` computes metrics:
   - **Customer-facing metrics**: Monthly savings (with trend), emergency fund months covered, monthly income (with stability), debt payoff timeline
   - **Backend-only metrics**: Health score (0-100), savings rate, debt-to-income ratio
4. **State Transition** → Journey state moves from `.accountsConnected` to `.healthReportReady`
5. **Report Display** → `FinancialHealthReportView` shows comprehensive onboarding education
6. **Plan Creation** → User taps "Create My Financial Plan" → backend generates health-aware allocation
7. **Ongoing Monitoring** → `FinancialHealthDashboardSection` displays key metrics with month-over-month comparison

#### Health Score Calculation (Backend-Only)

**Critical**: The health score is NEVER shown to customers. It's used only by the backend AI to make personalized recommendations.

Formula (weighted average):
- **Savings Rate** (30%): `monthlySavings / monthlyIncome`
- **Emergency Fund Adequacy** (25%): `currentCoverage / targetMonths` (target = 6/9/12 based on income stability)
- **Debt Management** (20%): `1.0 - (debtToIncomeRatio / 0.5)` (capped at 50%)
- **Income Stability** (15%): stable = 1.0, variable = 0.7, inconsistent = 0.4
- **Spending Discipline** (10%): `1.0 - (discretionarySpending / income)` normalized

Health Score Ranges:
- **71-100**: Good financial health → Standard 24-month savings period
- **41-70**: Moderate health → Accelerated 18-month savings period
- **0-40**: Needs improvement → Aggressive 12-month savings period

#### Health-Aware Allocation Logic

The backend `/api/ai/allocation-recommendation` endpoint uses health metrics to dynamically adjust recommendations:

1. **Emergency Fund Target Adjustment**:
   - Stable income → 6 months of essential expenses
   - Variable income → 9 months of essential expenses
   - Inconsistent income → 12 months of essential expenses

2. **Savings Period Determination**:
   - Health score < 40 OR emergency fund < 3 months → 12-month period (aggressive)
   - Health score < 70 OR emergency fund < 4.5 months → 18-month period (moderate)
   - High debt (> 3x monthly income) → 18-month period (moderate)
   - Otherwise → 24-month period (standard)

3. **AI Prompt Enhancement**:
   - Includes income stability context in emergency fund explanations
   - References current emergency fund coverage for personalized guidance
   - Focuses on opportunity and progress, never discouragement

#### Caching and Month-over-Month Tracking

Health metrics are cached in UserDefaults with a dual-caching strategy:
- **Current metrics**: Latest calculated values
- **Previous metrics**: Last month's values for comparison

This enables the dashboard section to show trends (↑↓→) without recalculation:
```swift
let savingsChange = currentMetrics.monthlySavings - (previousMetrics?.monthlySavings ?? 0)
let trend: TrendIndicator = savingsChange > 0 ? .up : savingsChange < 0 ? .down : .flat
```

#### UI Components

**FinancialHealthReportView** (Comprehensive Onboarding):
- Shows 4 expandable metric cards: Savings, Emergency Fund, Income, Debt (conditional)
- Spending breakdown with visual bars and category descriptions
- Progress bars with encouraging targets
- Sticky bottom CTA: "Create My Financial Plan"
- Uses `ColorPalette` design system for encouraging, non-judgmental colors

**FinancialHealthDashboardSection** (Ongoing Monitoring):
- Collapsible section at top of dashboard
- Shows 2-3 key metrics with month-over-month changes
- "View Full Health Report" button opens sheet with comprehensive view
- Compact design optimized for quick scanning

**ColorPalette Design System**:
- `progressGreen` (#34C759): Savings, growth opportunities
- `stableBlue` (#007AFF): Emergency fund, financial security
- `opportunityOrange` (#FF9500): Discretionary spending, flexibility
- `protectionMint` (#00C7BE): Cash flow, liquidity
- `wealthPurple` (#AF52DE): Investments, long-term wealth

### Key Architectural Patterns

#### Link Token Preloading
`PlaidService` preloads and caches link tokens in background (refreshes every 15 min). This makes Plaid Link open instantly when user taps "+", avoiding the 2-3 second network delay.

#### ItemId → AccessToken Mapping
Plaid uses `item_id` to identify bank connections. We store `access_token` in Keychain using `item_id` as the key. This allows multiple bank accounts and proper cleanup when removing accounts. **Critical**: `BankAccount.itemId` must be set after fetching accounts since Plaid API doesn't return it.

#### Cache-First Loading
On app launch, load cached accounts/transactions from UserDefaults for instant UI. Then refresh from Plaid in background. This provides perceived performance even with slow network.

#### Orphaned Token Cleanup
If Plaid returns error when fetching account data (e.g., user removed via Plaid dashboard), automatically delete the orphaned `item_id` from Keychain to prevent stale data.

#### AI Data Minimization
Never send raw transaction data to OpenAI. Only send aggregated summaries (totals, averages, patterns) to protect privacy and reduce costs.

#### Local Notification Actions
Notifications include interactive actions (Confirm, Review) that route to specific views via `NotificationNavigationCoordinator`. The coordinator bridges notification taps → view model state updates.

## Environment Configuration

### Backend `.env` (Required)
```bash
PLAID_CLIENT_ID=your_client_id      # From Plaid dashboard
PLAID_SECRET=your_sandbox_secret    # Use sandbox for dev
PLAID_ENV=sandbox                   # or development/production
PORT=3000
OPENAI_API_KEY=sk-your-key          # For AI insights feature
```

### iOS Configuration
- **For Simulator**: Use `http://localhost:3000` in `PlaidService.swift`
- **For Physical Device**: Get Mac IP (`ipconfig getifaddr en0`) and use `http://YOUR_IP:3000`
- **Info.plist**: Must include `NSAllowsLocalNetworking` = YES for dev

## Common Development Workflows

### Adding a New Financial Category
1. Update `BucketCategory` enum in `BucketCategory.swift`
2. Modify category mapping logic in `TransactionAnalyzer.swift`
3. Add budget generation rules in `BudgetManager.generateBudgets()`
4. Update `AlertRulesEngine` evaluation logic if needed

### Adding New Alert Types
1. Define alert case in `AlertRulesEngine.ProactiveAlert`
2. Implement evaluation logic in `AlertRulesEngine` (e.g., `evaluateGoalMilestone()`)
3. Add notification template in `NotificationService` (e.g., `scheduleGoalMilestoneAlert()`)
4. Update `ProactiveGuidanceView` to render the new alert type
5. Add action handler in `FinancialViewModel.handleGuidanceAction()`

### Debugging Account Removal
Account removal is complex due to multiple storage locations:
1. Check backend logs for itemId lookup
2. Verify Keychain access (`KeychainService.shared.allKeys()`)
3. Confirm itemId set on accounts (`account.itemId` must match storage key)
4. Use debug endpoint: `curl http://localhost:3000/api/debug/items`
5. Check logs prefixed with `🗑️ [Account Removal]` for detailed flow

### Testing Notifications Locally
1. Use `ProactiveGuidanceDemoView` (Demo tab) to trigger alerts
2. Schedule test notification: `NotificationService.shared.schedulePurchaseAlert(..., triggerInSeconds: 5)`
3. Background app to see notification
4. Tap notification to test navigation flow
5. Check logs for `[NotificationService]` and `[NotificationCoordinator]` prefixes

### Automated Testing Reset (Recommended)

**Problem:** Every time you update the app, you must manually navigate to Demo tab, tap "Clear All Data & Restart", confirm, wait for exit, and relaunch. This wastes 2-3 minutes per test cycle.

**Solution:** Use the `-ResetDataOnLaunch` launch argument to automatically clear all data every time you build and run from Xcode.

#### Setup (One-time):
1. In Xcode: **Product → Scheme → Edit Scheme** (or Cmd+<)
2. Select **"Run"** in left sidebar
3. Go to **"Arguments"** tab
4. Under "Arguments Passed On Launch", you should see `-ResetDataOnLaunch` (already added to shared scheme)
5. **Check the checkbox** next to `-ResetDataOnLaunch` to enable it
6. Close the scheme editor

#### Usage:
- **With auto-reset enabled:** Just hit **Cmd+R** to build and run. App launches with completely fresh data every time.
- **To disable:** Uncheck the `-ResetDataOnLaunch` checkbox in scheme settings. App will preserve data between launches (normal mode).

#### What Gets Cleared:
- **Backend tokens** (if backend is running at localhost:3000)
- **Keychain** (all Plaid access tokens)
- **UserDefaults** (cached accounts, transactions, budgets, goals, allocation buckets, onboarding state)
- **ViewModel state** (all in-memory data)
- **Notifications** (all pending alerts)

#### Console Output:
Look for logs prefixed with `🔄 [Launch]` to verify auto-reset is working:
```
🔄 [Launch] Detected -ResetDataOnLaunch argument
🔄 [Launch] Performing automatic data reset...
🗑️ [Reset] ===== STARTING COMPLETE DATA WIPE =====
✅ [Reset] Backend tokens cleared (2 items removed)
🗑️ [Reset] Keychain cleared (2 items removed)
🗑️ [Reset] UserDefaults cleared (8 keys removed)
🗑️ [Reset] ViewModel state cleared
🗑️ [Reset] All notifications canceled
✅ [Reset] ===== DATA WIPE COMPLETE =====
🔄 [Launch] Automatic reset complete, app ready with fresh data
```

#### Benefits:
- **Zero manual intervention** - Just Cmd+R and start testing immediately
- **Saves 2+ minutes per test cycle** - No more clicking through Demo tab
- **Backend integration** - Automatically clears backend tokens if server is running
- **Flexible** - Toggle on/off in Xcode scheme without code changes
- **Team-friendly** - Shared scheme works for all developers

#### Troubleshooting:
- **Backend tokens not clearing:** Make sure backend is running (`cd backend && npm run dev`)
- **iOS data persists:** Verify checkbox is enabled in scheme settings
- **No reset logs:** Check console output for `🔄 [Launch]` prefix

#### Manual Reset (Still Available):
The manual "Clear All Data & Restart" button in the Demo tab still works if you need it. Auto-reset just makes the workflow faster.

**Implementation:** See `DataResetManager.swift` for centralized reset logic used by both manual and automatic reset.

## Important Implementation Notes

### Never Skip Keychain Access
Always use `KeychainService.shared` for access tokens. Direct UserDefaults storage is insecure for sensitive credentials.

### Always Set itemId on Accounts
After fetching accounts from Plaid, manually set `account.itemId = itemId` in the loop. Plaid's API doesn't include this field, but we need it for account removal.

### Budget Generation Timing
Only call `budgetManager.generateBudgets(from:)` after you have at least 1 month of transaction history. With insufficient data, budgets will be unrealistically low.

### AI Prompt Engineering
Keep AI prompts factual and structured (see `buildPurchaseContext()` in `server.js`). Include numbers, context, and clear questions. Vague prompts produce generic responses.

### Notification Permission Timing
Request notification permission early in app lifecycle (`AppDelegate.application(_:didFinishLaunchingWithOptions:)`). iOS only prompts once; denied permissions require Settings app.

### Transaction Date Format
Plaid expects dates as `YYYY-MM-DD` strings. Use `DateFormatter` with that format when calling `/api/plaid/transactions`.

## Security Considerations

- Never commit `.env` file (already in `.gitignore`)
- Never commit `plaid_tokens.json` (contains access tokens)
- Never log full access tokens (log first 10 chars + "..." only)
- Validate all backend inputs (amount, category, itemId)
- Rate limit AI endpoints to prevent API key abuse
- Use HTTPS in production (localhost HTTP is dev-only)

## Custom User Testing Scenarios

The `plaid_custom_user_config.json` configuration stress-tests your app with real-world complexity. Here are the key scenarios it validates:

### 1. Multi-Account Architecture (10 Accounts)

**Accounts Created:**
- 4 Checking/Cash Management: Primary, Bills, Discretionary, Emergency Buffer
- 2 Savings: Emergency Fund HYSA, Short-Term Goals
- 3 Investments: 401k, Roth IRA, Taxable Brokerage
- 1 Credit Card: Chase Sapphire Reserve

**What This Tests:**
- Account grouping and aggregation logic
- Handling multiple accounts of the same type
- Account tagging/categorization UI
- Performance with realistic account counts
- **Note:** Optimized to Plaid's 10-account limit per custom user

### 2. Inter-Account Transfer Detection

**Transfer Scenarios:**
- Primary → Bills Checking ($1,200/month)
- Primary → Discretionary Cash ($800/month)
- Primary → Emergency Fund ($500/month)
- Primary → Short-Term Goals ($300/month)
- Primary → Credit Card Payment ($450/month to Chase Sapphire)
- Paycheck → Investment Contributions (401k, Roth IRA, Brokerage)

**What This Tests:**
- Transfers shouldn't be counted as income or expenses
- Duplicate transaction detection (same transfer in 2 accounts)
- Net cash flow calculation accuracy
- `TRANSFER_IN` and `TRANSFER_OUT` PFC category handling

### 3. Complex Income Sources

**Income Types:**
- W-2 Salary: $2,500 semi-monthly (1st and 15th) - 14 paychecks over 7 months
- Q2 Bonus: $750 (one-time)
- Interest Income: HYSA monthly (~$35-42)
- Dividend Income: Brokerage monthly (~$22-32)
- Employer 401k Match: $250 per paycheck (most paychecks)

**What This Tests:**
- Multiple income stream aggregation
- Regular vs. irregular income detection
- Income stability classification (stable W-2)
- Total compensation calculation

### 4. Allocation Bucket Mapping

**Essential Spending (50% of income):**
- Rent: $1,800/month
- Utilities: Gas ($110-120), Internet ($65), Water ($45)
- Groceries: ~$400/month across multiple stores (Whole Foods, Trader Joes, Costco, Safeway)
- Transportation: Gas ($150-200/month), Auto Insurance ($250/month), Auto Loan ($350/month)
- Healthcare: CVS Pharmacy, doctor visits
- Subscriptions: Netflix, Spotify, iCloud

**Discretionary Spending (15-20%):**
- Dining: Chipotle, Panera, Starbucks, fine dining (~$400/month)
- Entertainment: Movies, streaming services, books
- Shopping: Amazon, Target, Best Buy, clothing
- Travel: Flights, hotels (occasional)

**Emergency Fund Contributions (10%):**
- Monthly automated transfers ($500)
- Interest accumulation

**Investment Contributions (20%):**
- 401k: $500 per paycheck + $250 employer match
- Roth IRA: $500/month
- Taxable Brokerage: $300/month (VTI index fund) + occasional stock purchases (AAPL, MSFT)

**What This Tests:**
- Category → Bucket mapping accuracy
- PFC primary category handling (auto-assigned by Plaid)
- Essential vs. discretionary classification
- Investment detection across account types
- **Note:** Personal Finance Categories are NOT included in config JSON; Plaid assigns them automatically after account creation

### 5. Edge Cases and Special Transactions

**Refunds:**
- Amazon return: -$50 (negative expense on credit card)

**Annual Expenses:**
- Gym membership annual renewal ($200)

**Recurring vs. One-Time:**
- Monthly: Rent, utilities, subscriptions
- Weekly: Groceries, gas, dining
- Quarterly: Bonuses, dividends
- Annual: Insurance premiums, memberships

**Pending Transactions:**
- None in current config, but can be added by setting `date_posted` in future

**What This Tests:**
- Negative transaction handling (refunds)
- Recurring pattern detection
- Expense smoothing algorithms

### 6. Credit Card Management

**Credit Card:**
- Chase Sapphire Reserve: $1,850 balance
- Monthly payment: $450 (from Primary Checking)
- Purchases: Groceries, gas, dining, travel, pharmacy

**What This Tests:**
- Credit card payment tracking
- Duplicate detection (payment appears in both checking and credit accounts)
- Purchase categorization across essential + discretionary

### 7. Financial Health Metrics Validation

**Expected Metrics (based on 7-month analysis):**
- Monthly Income: ~$5,820 (salary + bonus + interest + dividends + match)
- Monthly Expenses: ~$3,350 (essential + discretionary)
- Savings Rate: ~42%
- Emergency Fund Coverage: 4.6 months (based on essential expenses ~$2,500/month)
- Emergency Fund Target: 6 months (stable W-2 income)
- Credit Utilization: $1,850 balance (no limit data in sandbox)
- Income Stability: Stable (consistent W-2 payroll)
- Health Score: ~78 (good health)

**What This Tests:**
- Health score calculation algorithm
- Savings rate computation
- Emergency fund adequacy assessment
- Income stability detection
- Health-aware allocation recommendations

### 8. Transaction Volume and Performance

**Transaction Count:**
- 7 months of data (April - October 2025): ~230 transactions
- Average: ~33 transactions per month
- Distributed across 10 accounts: ~23 per account average

**What This Tests:**
- Transaction list rendering performance
- Date range filtering efficiency
- Category breakdown calculations
- Monthly trend analysis speed
- Search and filter responsiveness

### 9. Real-World UX Challenges

**Account Organization:**
- How to group 10 accounts logically?
- Which accounts show on main dashboard vs. details view?
- Account tagging/favorites functionality?
- Best practices: Separate checking for bills vs. discretionary

**Cash Flow Complexity:**
- With money moving between 10 accounts, how to show net position?
- How to explain "available to spend" with multiple checking accounts?
- Should discretionary cash account balance be highlighted differently?

**Investment Aggregation:**
- Total invested across 3 accounts
- Retirement (401k + Roth IRA) vs. taxable distinction
- Track total contributions vs. current value

**What This Tests:**
- Navigation and information hierarchy
- Account grouping/filtering UI
- Net worth calculation
- Available cash vs. total assets distinction

### 10. Data Consistency Checks

**Validation Tests:**
- Income total matches sum of salary + bonuses + interest + dividends
- Expense total matches sum of all outflows minus transfers
- Account balances reconcile with transaction history
- Credit card payments match expenses on cards
- Investment contributions sum to account growth

**What This Tests:**
- Transaction categorization accuracy
- Double-counting prevention
- Balance calculation logic
- Data integrity monitoring

## Testing Financial Health Scenarios

The Financial Health Report feature can be tested with different financial situations to verify the health-aware allocation logic. Use the following curl commands to test backend behavior:

### Scenario 1: High Savings, Stable Income (Good Health)

**Profile**: Tech professional with strong savings, emergency fund fully funded, stable W-2 income.

```bash
curl -X POST http://localhost:3000/api/ai/allocation-recommendation \
  -H "Content-Type: application/json" \
  -d '{
    "monthlyIncome": 5000,
    "monthlyExpenses": 3000,
    "currentSavings": 15000,
    "totalDebt": 0,
    "categoryBreakdown": {
      "Groceries": 400, "Rent": 1200, "Utilities": 150, "Transportation": 200,
      "Entertainment": 300, "Dining": 400, "Shopping": 350
    },
    "healthMetrics": {
      "healthScore": 85,
      "savingsRate": 0.40,
      "emergencyFundMonthsCovered": 7.5,
      "debtToIncomeRatio": 0,
      "incomeStability": "stable",
      "monthlySavings": 2000,
      "monthlySavingsTrend": "up"
    }
  }'
```

**Expected Results**:
- Emergency fund target: 6 months (stable income)
- Savings period: 24 months (standard)
- Emergency fund allocation: ~$488/month (~10%)
- Investment allocation: ~$750/month (~15%)

### Scenario 2: Low Savings, Variable Income (Needs Improvement)

**Profile**: Freelance consultant with irregular income, minimal emergency fund, moderate debt.

```bash
curl -X POST http://localhost:3000/api/ai/allocation-recommendation \
  -H "Content-Type: application/json" \
  -d '{
    "monthlyIncome": 4000,
    "monthlyExpenses": 3500,
    "currentSavings": 2000,
    "totalDebt": 5000,
    "categoryBreakdown": {
      "Groceries": 350, "Rent": 1400, "Utilities": 120, "Transportation": 250,
      "Entertainment": 200, "Dining": 300, "Shopping": 880
    },
    "healthMetrics": {
      "healthScore": 35,
      "savingsRate": 0.125,
      "emergencyFundMonthsCovered": 1.0,
      "debtToIncomeRatio": 0.31,
      "incomeStability": "variable",
      "monthlySavings": 500,
      "monthlySavingsTrend": "flat"
    }
  }'
```

**Expected Results**:
- Emergency fund target: 9 months (variable income)
- Savings period: 12 months (aggressive)
- Emergency fund allocation: ~$1590/month (~40%) → adjusted to fit budget
- Reduced discretionary spending to prioritize emergency fund

### Scenario 3: Zero Debt, Inconsistent Income (Moderate Health)

**Profile**: Small business owner with irregular income, some emergency fund, no debt.

```bash
curl -X POST http://localhost:3000/api/ai/allocation-recommendation \
  -H "Content-Type: application/json" \
  -d '{
    "monthlyIncome": 6000,
    "monthlyExpenses": 4000,
    "currentSavings": 8000,
    "totalDebt": 0,
    "categoryBreakdown": {
      "Groceries": 500, "Rent": 1800, "Utilities": 200, "Transportation": 300,
      "Entertainment": 400, "Dining": 500, "Shopping": 300
    },
    "healthMetrics": {
      "healthScore": 62,
      "savingsRate": 0.33,
      "emergencyFundMonthsCovered": 3.2,
      "debtToIncomeRatio": 0,
      "incomeStability": "inconsistent",
      "monthlySavings": 2000,
      "monthlySavingsTrend": "up"
    }
  }'
```

**Expected Results**:
- Emergency fund target: 12 months (inconsistent income)
- Savings period: 18 months (moderate)
- Emergency fund allocation: ~$1867/month (~31%) → adjusted to fit budget
- Balanced approach between security and flexibility

### Monitoring Backend Logs

After running tests, check server logs for health-aware decision making:

```bash
# Watch logs in real-time
tail -f backend/server.log

# Or if running via npm run dev, logs appear in terminal
```

Look for these log patterns:
- `🎯 [Allocation] Health Metrics: Score=X, SavingsRate=X%, EmergencyFund=X months`
- `🎯 [Allocation] Using [aggressive|moderate|standard] X-month period`
- `🎯 [Allocation] Emergency Fund - Target: $X (X months for [stable|variable|inconsistent] income)`

## Troubleshooting

### "Failed to create link token"
Backend not running or wrong URL. Check `baseURL` in `PlaidService.swift` matches server.

### "Invalid credentials" from Plaid
Wrong `PLAID_CLIENT_ID` or `PLAID_SECRET` in `.env`. Must use matching environment (sandbox secret for sandbox env).

### Accounts show but transactions empty
Need to wait 10-15 seconds for Plaid to sync data. Pull-to-refresh. Check backend logs for errors.

### Notification not appearing
Check permission granted (`UNUserNotificationCenter.current().getNotificationSettings()`). Ensure app is backgrounded. Check trigger delay is reasonable.

### Account removal not working
Verify itemId matches between Keychain and backend. Check logs for orphaned token warnings. Use debug endpoint to see stored items.

## Production Deployment Checklist

- [ ] Switch `PLAID_ENV=development` in backend `.env`
- [ ] Update `baseURL` in `PlaidService.swift` to production API
- [ ] Use production Plaid credentials
- [ ] Implement user authentication (OAuth/JWT)
- [ ] Replace JSON file storage with encrypted database
- [ ] Add rate limiting on all endpoints
- [ ] Set up HTTPS with valid certificate
- [ ] Configure App Store privacy policy URL
- [ ] Add error tracking (Sentry, etc)
- [ ] Set OpenAI API cost alerts
- [ ] Implement user consent flow for AI features
- [ ] Add analytics to measure alert effectiveness

## Feature Documentation

See `PROACTIVE_GUIDANCE_FEATURE.md` for comprehensive documentation on the proactive guidance system including customer flows, testing scenarios, and architecture decisions.

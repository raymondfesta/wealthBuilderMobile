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
```bash
# Test Plaid sandbox credentials
# Username: user_good, Password: pass_good, MFA: 1234

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
│   └── Goal.swift             # Financial goals (emergency fund, etc)
├── Services/                  # Business logic
│   ├── PlaidService.swift     # Plaid API integration + link token caching
│   ├── BudgetManager.swift    # Budget/goal CRUD + reallocation logic
│   ├── AlertRulesEngine.swift # Evaluates purchases, generates alerts
│   ├── SpendingPatternAnalyzer.swift # Pattern detection from history
│   └── NotificationService.swift # Push notifications + actions
├── ViewModels/
│   └── FinancialViewModel.swift # Main app state + data flow coordination
└── Views/
    ├── DashboardView.swift    # 6 financial buckets display
    ├── ProactiveGuidanceView.swift # Alert UI with AI insights
    └── ProactiveGuidanceDemoView.swift # Testing interface

backend/
├── server.js                  # Express server with Plaid + OpenAI routes
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

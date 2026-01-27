# Wealth Builder Mobile

## Project Overview

Native iOS financial app (SwiftUI) with Node.js backend. Connects bank accounts via Plaid API and provides AI-powered financial guidance.

**Target Users:** Individuals wanting proactive help managing income allocation and building savings habits.

**Key Value Proposition:** Analyzes transactions, calculates financial health metrics, and helps users allocate income across smart buckets (Essential, Emergency Fund, Discretionary, Investments, Debt Paydown) with AI-generated recommendations.

**Core Features:**
- Financial Health Report with customer-friendly metrics
- Interactive Allocation Planner (Low/Rec/High presets, account linking)
- Allocation Schedule & Execution (paycheck detection, notifications, history)
- Proactive Guidance via GPT-4o-mini

## Tech Stack

### iOS (SwiftUI)
- Swift 5.9, SwiftUI
- MVVM architecture
- Plaid Link SDK 5.0+ (via SPM)
- iOS 16.0+ target
- Keychain for secure token storage
- Encrypted transaction cache (AES-256-GCM)

### Backend (Node.js)
- Express 4.18.2
- Plaid SDK 21.0.0
- OpenAI 6.2.0
- Rate limiting (express-rate-limit)
- JWT handling (jose, jsonwebtoken)

### Testing
- XCTest for unit tests
- Automated reset via launch arguments
- Plaid sandbox with custom user configs

### Development Tools
- Xcode 16+
- npm/nodemon for backend
- No CI/CD (manual builds)

## Architecture Patterns

### Project Structure
```
FinancialAnalyzer/
├── Models/                    # 24 data models
│   ├── Transaction.swift      # Plaid transaction + categoryConfidence
│   ├── BankAccount.swift      # Account with itemId, minimumPayment, apr
│   ├── FinancialPosition.swift # Balances + DebtAccount[], DebtType
│   ├── MonthlyFlow.swift      # Cash flow with expense breakdown
│   ├── AnalysisSnapshot.swift # Combined flow + position + metadata
│   ├── FinancialSnapshot.swift # Typealias for AnalysisSnapshot
│   ├── ExpenseBreakdown.swift # 8 categories incl. healthcare
│   ├── FinancialHealthMetrics.swift
│   ├── AllocationBucket.swift # 4-5 allocation buckets
│   ├── PaycheckSchedule.swift
│   └── UserJourneyState.swift # Onboarding state machine
├── Services/                  # 16 service files
│   ├── PlaidService.swift     # Plaid API + link token caching
│   ├── SecureTransactionCache.swift # AES-256-GCM encrypted cache
│   ├── TransactionFetchService.swift # Cache-first fetching
│   ├── TransactionAnalyzer.swift # Category mapping
│   ├── FinancialHealthCalculator.swift
│   ├── BudgetManager.swift
│   ├── AllocationScheduler.swift
│   ├── NotificationService.swift
│   └── AccountLinkingService.swift # Smart account detection
├── ViewModels/
│   ├── FinancialViewModel.swift # Central state coordinator
│   └── AllocationEditorViewModel.swift
├── Views/                     # 40+ SwiftUI views
│   ├── DashboardView.swift
│   ├── AllocationPlannerView.swift
│   ├── ScheduleTabView.swift
│   └── Components/            # Reusable UI
├── DesignSystem/              # Glassmorphic components
└── Utilities/
    ├── KeychainService.swift
    └── DataResetManager.swift

backend/
├── server.js                  # Express server (~1800 lines)
├── package.json
├── .env                       # Plaid + OpenAI keys
└── plaid_tokens.json          # Token storage (gitignored)
```

### Key Patterns

**Link Token Preloading:** PlaidService preloads tokens in background (refreshes every 15 min). Plaid Link opens instantly.

**ItemId → AccessToken Mapping:** Keychain stores access_token keyed by item_id. Critical: Set `account.itemId` after fetching accounts (Plaid API doesn't return it).

**Cache-First Loading:** Load cached accounts/transactions from encrypted cache on launch (<1s). First sync takes 10-20s, subsequent loads instant within 24h.

**AI Data Minimization:** Only send aggregated summaries to OpenAI (totals, averages, patterns). Never raw transaction data.

**Notification Deep Linking:** `NotificationNavigationCoordinator` routes notification taps to specific views via ViewModel state updates.

### Rebalancing Logic

When user adjusts one allocation bucket, others auto-rebalance using priority order:
1. Discretionary Spending (most flexible)
2. Investments
3. Debt Paydown (if present)
4. Emergency Fund (last resort)

## Code Style Standards

### Swift
- Strict type safety: no `Any`, no force unwraps (`!`), no `as!` casts
- Explicit return types on public functions
- MVVM pattern: Views are dumb, ViewModels coordinate logic

### General
- Minimal surgical changes
- Avoid over-engineering
- Failing tests acceptable if they expose genuine bugs

### Error Handling
```swift
// Always use do-catch for async operations
do {
    let result = try await apiCall()
    return result
} catch {
    logger.error("[ServiceName] Operation failed: \(error)")
    throw error
}
```

### Naming
- Files: PascalCase (TransactionAnalyzer.swift)
- Services: suffix with Service/Manager/Calculator
- Views: suffix with View/Sheet/Section

## Testing

### Plaid Sandbox Users

**Basic (minimal data):**
```
Username: user_good
Password: pass_good
MFA Code: 1234
```

**Stress Test (recommended):**
```
Username: user_custom
Password: [paste plaid_custom_user_config.json contents]
```
Provides 10 accounts, ~230 transactions, complex money flows.

**After connecting:** Wait 10-15 seconds for Plaid to assign transaction categories.

### Running Tests
```bash
# Backend
cd backend && npm test

# iOS (Xcode)
Cmd+U
```

### Test Coverage Goals
- Critical paths (allocation, health calculation): High coverage
- Services: Unit tests for business logic
- Views: Manual testing via simulator

## Development Workflow

### Local Development
```bash
# Backend (terminal 1)
cd backend && npm run dev

# iOS (Xcode)
Cmd+R to build and run
```

### iOS Simulator Config
- Use `http://localhost:3000` in PlaidService.swift
- For physical device: Use Mac IP (`ipconfig getifaddr en0`)

### Automated Testing Reset

**Setup (one-time):**
1. Xcode: Product → Scheme → Edit Scheme
2. Run → Arguments tab
3. Check `-ResetDataOnLaunch`

**Effect:** Clears Keychain, UserDefaults, backend tokens, notifications on every build+run.

**Console output:**
```
🔄 [Launch] Performing automatic data reset...
✅ [Reset] ===== DATA WIPE COMPLETE =====
```

**Disable:** Uncheck the argument in scheme settings.

### Standard Process
1. Implement following existing patterns
2. Write tests for new business logic
3. Run test suite
4. Manual testing in simulator
5. Commit with clear message

### Git Workflow
- Branch: `feature/description` or `fix/description`
- Commits: Conventional format (`feat:`, `fix:`)
- Current branch: `development`

## Quality Standards

### Performance
- Plaid Link opens instantly (preloaded tokens)
- Cache-first loading for instant UI
- Background refresh doesn't block UI

### Security
- Keychain for all access tokens
- Never log full tokens (first 10 chars + "...")
- Rate limiting on AI endpoints
- HTTPS in production

### UX
- Loading states for all async operations
- Encouraging colors (never judgmental)
- Toast notifications for auto-adjustments

## Autonomous Operation Guidelines

### Do without asking:
- Follow established patterns
- Add standard error handling/logging
- Write tests for new features
- Fix obvious bugs discovered during implementation
- Refactor within files you're working on

### Ask for guidance on:
- Major architectural changes
- New dependencies
- Breaking API changes
- Database schema changes
- Security-sensitive implementations

## Current Focus

**Recent work (from git):**
- Session cache implementation (encrypted local caching)
  - `SecureTransactionCache.swift` - AES-256-GCM encrypted file cache
  - `TransactionFetchService.swift` - Cache-first fetching with retry
  - Backend: `/api/plaid/sync-status` endpoint, `days_requested: 90`
  - 3-month history (reduced from 6 for faster sync)
  - 24h cache expiration with background refresh
- TASK 1-6: TransactionAnalyzer implementation plan COMPLETE
- Design system (glassmorphic components)
- Expense breakdown feature
- Swift 6 concurrency fixes

**Next priorities:**
- User authentication system
- Production database (replace JSON storage)
- CI/CD pipeline

## Known Constraints

- iOS 16.0+ minimum
- Backend: localhost:3000 (dev only)
- No CI/CD (manual Xcode builds)
- No user authentication (single-user dev mode)
- Plaid sandbox: 10 accounts max per custom user

## Common Issues & Solutions

### "Failed to create link token"
Backend not running or wrong URL. Check `baseURL` in PlaidService.swift.

### "Invalid credentials" from Plaid
Wrong secrets in .env. Must match environment (sandbox secret for sandbox env).

### Accounts show but transactions empty
Wait 10-15 seconds for Plaid sync. Pull-to-refresh.

### Notifications not appearing
Check permission granted. Ensure app is backgrounded.

### Account removal not working
Verify itemId matches between Keychain and backend. Use debug endpoint:
```bash
curl http://localhost:3000/api/debug/items
```

### Build fails after adding files
Ensure new .swift files registered in project.pbxproj. See [ADD_NEW_FILES_TO_XCODE.md](ADD_NEW_FILES_TO_XCODE.md).

## External Dependencies

### Required Services
- **Plaid API** - Bank account connection
- **OpenAI API** - AI-powered insights

### Environment Variables (backend/.env)
```bash
PLAID_CLIENT_ID=your_client_id
PLAID_SECRET=your_sandbox_secret
PLAID_ENV=sandbox
PORT=3000
OPENAI_API_KEY=sk-your-key
```

### iOS Configuration
- Info.plist: `NSAllowsLocalNetworking: YES` (dev only)

## Documentation Links

### Implementation Guides
- [Allocation Planner](ALLOCATION_PLANNER_IMPLEMENTATION_SUMMARY.md)
- [Allocation Schedule](ALLOCATION_SCHEDULE_IMPLEMENTATION.md)
- [Proactive Guidance](PROACTIVE_GUIDANCE_FEATURE.md)

### Testing Guides
- [Allocation Planner Testing](ALLOCATION_PLANNER_TESTING_GUIDE.md) - 10 test scenarios
- [Plaid Sandbox Testing](PLAID_SANDBOX_TESTING_GUIDE.md) - Custom user config
- [Financial Health Scenarios](PLAID_SANDBOX_TESTING_GUIDE.md#testing-financial-health-scenarios)

### Quick References
- [Adding Files to Xcode](ADD_NEW_FILES_TO_XCODE.md)
- [Data Reset Feature](CLEAR_DATA_FEATURE.md)

## Architecture Decisions

### 2025-01: State Management
**Decision:** MVVM with centralized FinancialViewModel
**Rationale:** SwiftUI native pattern, single source of truth for financial state
**Trade-offs:** Large ViewModel; could split if complexity grows

### 2025-01: Token Storage
**Decision:** Keychain (iOS) + JSON file (backend)
**Rationale:** Keychain is secure for mobile. JSON is MVP-simple for backend.
**Trade-offs:** JSON not production-ready; migrate to encrypted DB

### 2025-01: Health Score Privacy
**Decision:** Health score (0-100) never shown to users
**Rationale:** Prevents judgment; score only used by backend AI for personalization
**Trade-offs:** Less transparency; users see friendly metrics instead

### 2025-01: Allocation Rebalancing
**Decision:** Priority-based auto-rebalancing (discretionary first, emergency fund last)
**Rationale:** Protects critical allocations while maintaining flexibility
**Trade-offs:** May surprise users; mitigated with toast notifications

### 2024-10: AI Data Minimization
**Decision:** Only send aggregated data to OpenAI
**Rationale:** Privacy protection, cost reduction
**Trade-offs:** Less personalized insights; acceptable for MVP

## Production Checklist

- [ ] Switch PLAID_ENV=development
- [ ] Update baseURL to production API
- [ ] Implement user authentication (OAuth/JWT)
- [ ] Replace JSON with encrypted database
- [ ] Add rate limiting on all endpoints
- [ ] Set up HTTPS
- [ ] Configure App Store privacy policy
- [ ] Add error tracking (Sentry)
- [ ] Set OpenAI cost alerts

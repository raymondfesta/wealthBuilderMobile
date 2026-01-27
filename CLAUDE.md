# Wealth Builder Mobile

## Project Overview

Native iOS financial app (SwiftUI) with Node.js backend. Connects bank accounts via Plaid API and provides AI-powered financial guidance.

**Target Users:** Individuals wanting proactive help managing income allocation and building savings habits.

**Key Value Proposition:** Analyzes transactions and helps users allocate income across smart buckets (Essential, Emergency Fund, Discretionary, Investments, Debt Paydown) with AI-generated recommendations.

**Core Features:**
- My Plan view (4 bucket cards: Essential, Discretionary, Emergency Fund, Investments)
- Interactive Allocation Planner (Low/Rec/High presets, account linking)
- Allocation Schedule & Execution (paycheck detection, notifications, history)
- Proactive Guidance via GPT-4o-mini

## Tech Stack

### iOS (SwiftUI)
- Swift 5.9, SwiftUI
- MVVM architecture
- Plaid Link SDK 5.0+ (via SPM)
- iOS 16.0+ target
- Keychain for secure token storage (auth + Plaid tokens)
- Encrypted transaction cache (AES-256-GCM)
- Sign in with Apple + email/password auth

### Backend (Node.js)
- Express 4.18.2
- Plaid SDK 21.0.0
- OpenAI 6.2.0
- SQLite (better-sqlite3) for user/session storage
- JWT auth (jsonwebtoken) - 15min access, 30d refresh
- AES-256-GCM encryption for Plaid tokens
- bcrypt for password hashing
- Rate limiting (express-rate-limit)

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
├── Models/                    # 26 data models
│   ├── AuthState.swift        # Auth state enum (loading/unauthenticated/authenticated)
│   ├── AuthUser.swift         # User model + auth response structs
│   ├── Transaction.swift      # Plaid transaction + categoryConfidence
│   ├── BankAccount.swift      # Account with itemId, minimumPayment, apr
│   ├── FinancialPosition.swift # Balances + DebtAccount[], DebtType
│   ├── MonthlyFlow.swift      # Cash flow with expense breakdown
│   ├── AnalysisSnapshot.swift # Combined flow + position + metadata
│   ├── FinancialSnapshot.swift # Typealias for AnalysisSnapshot
│   ├── ExpenseBreakdown.swift # 8 categories incl. healthcare
│   ├── AllocationBucket.swift # 4-5 allocation buckets
│   ├── PaycheckSchedule.swift
│   └── UserJourneyState.swift # Onboarding state machine
├── Services/                  # 17 service files
│   ├── AuthService.swift      # Apple + email/password auth
│   ├── PlaidService.swift     # Plaid API + link token caching
│   ├── SecureTransactionCache.swift # AES-256-GCM encrypted cache
│   ├── TransactionFetchService.swift # Cache-first fetching
│   ├── TransactionAnalyzer.swift # Category mapping + essential/discretionary classification
│   ├── BudgetManager.swift
│   ├── AllocationScheduler.swift
│   ├── NotificationService.swift
│   └── AccountLinkingService.swift # Smart account detection
├── ViewModels/
│   ├── FinancialViewModel.swift # Central state coordinator
│   └── AllocationEditorViewModel.swift
├── Views/                     # 50+ SwiftUI views
│   ├── AuthRootView.swift     # Root auth router
│   ├── LoginView.swift        # Sign in with Apple + email/password
│   ├── ProfileView.swift      # User profile + logout
│   ├── DashboardView.swift    # Legacy (replaced by MyPlanView)
│   ├── ScheduleTabView.swift
│   ├── MyPlan/                # Main post-onboarding view
│   │   ├── MyPlanView.swift          # 4 bucket cards, cycle header
│   │   └── PlanAdherenceCard.swift   # Spending/savings card components
│   ├── Onboarding/            # Onboarding flow (separated from Dashboard)
│   │   ├── OnboardingFlowView.swift    # Journey state router
│   │   ├── WelcomeConnectView.swift    # Connect bank CTA
│   │   ├── AccountsConnectedView.swift # Analyze CTA
│   │   ├── AnalysisCompleteView.swift  # Analysis results + drill-downs
│   │   └── AllocationPlannerView.swift # Plan creation
│   └── Components/            # Reusable UI
│       ├── BucketCard.swift
│       ├── TransactionRow.swift
│       ├── BudgetStatusCard.swift
│       └── AllocationBucketSummaryCard.swift
├── DesignSystem/              # Glassmorphic components
└── Utilities/
    ├── KeychainService.swift
    ├── SecureTokenStorage.swift # Auth token keychain storage
    └── DataResetManager.swift

backend/
├── server.js                  # Express server (~1800 lines)
├── package.json
├── .env                       # Plaid, OpenAI, JWT, encryption keys
├── db/
│   ├── database.js            # SQLite connection + migrations
│   └── schema.sql             # Users, plaid_items, sessions tables
├── routes/
│   └── auth.js                # Auth endpoints (register, login, apple, refresh)
├── middleware/
│   └── auth.js                # requireAuth/optionalAuth middleware
├── services/
│   ├── encryption.js          # AES-256-GCM for Plaid tokens
│   └── token.js               # JWT generation/validation
└── data/
    └── wealth.db              # SQLite database (gitignored)
```

### Key Patterns

**Link Token Preloading:** PlaidService preloads tokens in background (refreshes every 15 min). Plaid Link opens instantly.

**ItemId-Based API:** iOS stores only itemIds in Keychain (not access tokens). Backend manages encrypted tokens in SQLite. All Plaid endpoints require auth and accept `item_id` instead of `access_token`.

**Cache-First Loading:** For logged-in users, `setCurrentUser()` syncs itemIds from backend first, then loads from encrypted cache (<1s). If cache empty but backend has items, auto-fetches from Plaid. First sync takes 10-20s, subsequent loads instant within 24h. Returning users see dashboard instantly; data refreshes silently via `performBackgroundRefresh()` (no loading UI).

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
- Critical paths (allocation): High coverage
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
- My Plan view COMPLETE
  - Replaced Dashboard tab with 4 allocation bucket cards
  - Essential/Discretionary spending from transactions (not Budget.currentSpent)
  - Emergency Fund/Investments from linked account balances
  - TransactionAnalyzer: `isEssentialSpending()`, `spentThisCycle()`, `projectedCycleSpend()`
  - Auto-link accounts on view load via AccountLinkingService suggestions
- Silent background recovery COMPLETE
  - Returning users see instant dashboard (no loading spinners)
  - `performBackgroundRefresh()` updates data without UI indicators
  - Cached summary preserved (no re-analysis on login)
  - Budget progress updated silently via `updateSpendingProgress()`
- Login persistence fix COMPLETE
  - Accounts now load correctly after logout/login
  - Fixed init order: cache deferred to `setCurrentUser()` when user logged in
  - Added recovery: fetch from Plaid if cache empty but backend has items
  - Fixed `fetchAccountsOnly()` state overwrite: added `preserveState` parameter for recovery paths
- User authentication system COMPLETE
  - Sign in with Apple + email/password
  - SQLite database (users, plaid_items, sessions tables)
  - JWT auth (15min access, 30d refresh tokens)
  - AES-256-GCM encrypted Plaid token storage
  - bcrypt password hashing
  - Multi-user data scoping
- Session cache implementation (encrypted local caching)
  - `SecureTransactionCache.swift` - AES-256-GCM encrypted file cache
  - 24h cache expiration with background refresh
- TASK 1-6: TransactionAnalyzer implementation plan COMPLETE
- Design system (glassmorphic components)

**Next priorities:**
- Sign in with Apple capability (requires Apple Developer portal setup)
- CI/CD pipeline
- Production deployment prep

## Known Constraints

- iOS 16.0+ minimum
- Backend: localhost:3000 (dev only)
- No CI/CD (manual Xcode builds)
- Sign in with Apple requires Apple Developer portal setup
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

### Onboarding shown after logout/login (accounts not loading)
Fixed in 2026-01-27. If this recurs, check:
1. `setCurrentUser()` is called in `ContentView.task`
2. `syncPlaidItemsFromBackend()` runs before `loadFromCache()`
3. Recovery fetch triggers when cache empty but backend has items
4. `fetchAccountsOnly(preserveState: true)` is used in recovery paths to prevent state overwrite

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
JWT_SECRET=<256-bit-secret>
ENCRYPTION_KEY=<32-byte-hex-key>
APPLE_BUNDLE_ID=com.yourcompany.FinancialAnalyzer
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

### Quick References
- [Adding Files to Xcode](ADD_NEW_FILES_TO_XCODE.md)
- [Data Reset Feature](CLEAR_DATA_FEATURE.md)

## Architecture Decisions

### 2026-01: My Plan View
**Decision:** Calculate spending from transactions, use linked account balances for savings
**Rationale:** Budget.currentSpent was stale; transactions are source of truth; Plaid balances reflect actual savings
**Trade-offs:** More computation per render; mitigated by cycle-based filtering

### 2025-01: State Management
**Decision:** MVVM with centralized FinancialViewModel
**Rationale:** SwiftUI native pattern, single source of truth for financial state
**Trade-offs:** Large ViewModel; could split if complexity grows

### 2025-01: Token Storage
**Decision:** Keychain (iOS) + SQLite with AES-256-GCM encryption (backend)
**Rationale:** Keychain for auth tokens. SQLite for user data. Plaid tokens encrypted at rest.
**Trade-offs:** SQLite not horizontally scalable; acceptable for MVP

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
- [x] Implement user authentication (JWT + Apple Sign In)
- [x] Replace JSON with encrypted database (SQLite + AES-256-GCM)
- [ ] Configure Sign in with Apple in Apple Developer portal
- [ ] Add rate limiting on all endpoints
- [ ] Set up HTTPS
- [ ] Configure App Store privacy policy
- [ ] Add error tracking (Sentry)
- [ ] Set OpenAI cost alerts

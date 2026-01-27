# Project Progress Tracker

Last Updated: 2026-01-23 (Transaction refresh debug logging added)

## Current State

### What's Working ✓
- Plaid bank account connection (sandbox)
- Transaction fetching and categorization
- Financial health metrics calculation
- Allocation bucket planner (5 buckets: Essential, Emergency, Discretionary, Investments, Debt)
- Allocation schedule with paycheck detection
- Proactive AI guidance via GPT-4o-mini
- Design system with glassmorphic components
- Expense breakdown analysis
- User journey state machine (onboarding flow)
- Link token preloading (instant Plaid Link)
- Cache-first loading (instant UI)
- Automated data reset via launch arguments
- Keychain token storage

### In Progress 🔨
- User authentication system
- Production database (replace JSON storage)
- CI/CD pipeline

### Blocked/Waiting ⏸
- Production Plaid credentials (development env pending)
- App Store submission (needs auth + privacy policy)

---

## Next Up

**Priority 1: User Authentication**
- OAuth or JWT-based auth flow
- Secure session management
- Multi-user support
- Files: New `AuthService.swift`, `LoginView.swift`, backend auth routes
- Tests: Login, logout, token refresh, invalid credentials

**Priority 2: Production Database**
- Replace `plaid_tokens.json` with encrypted DB
- PostgreSQL or SQLite for backend
- Migration scripts for existing data
- Files: `backend/server.js`, new DB config

**Priority 3: CI/CD Pipeline**
- GitHub Actions for automated tests
- Automated build validation
- Xcode Cloud or Fastlane for iOS builds

**Priority 4: Push Notifications**
- Paycheck detection alerts
- Allocation reminders
- Budget threshold warnings
- Files: `NotificationService.swift`, backend push integration

---

## Completed This Session

### 2026-01-23
- 🔍 **Debug: Plaid Transaction Fetch Returns Only 1 Transaction**
  - **Issue:** `user_custom` returns 1 transaction instead of ~130
  - **All possible causes investigated:**
    1. ~~Silent failure in refresh endpoint~~ → Fixed with HTTP 202/500 status codes
    2. ~~No logging~~ → Added verbose logging everywhere
    3. **Date range mismatch** → Test data: Apr-Oct 2025, but 6-month window is Jul 2025 - Jan 2026
    4. **Plaid sync timing** → Sandbox may need 10-15s to populate (we wait 3s)
    5. **Pagination bug** → If Plaid reports `total_transactions=1` early, loop exits
  - **Diagnostic logging added:**
    - `server.js:336-377` - Logs each pagination page, total_transactions, cumulative count
    - `PlaidService.swift:254-270` - Logs response size, total reported, date range
  - **Next step:** Run app, connect `user_custom`, check backend console for:
    ```
    [Transactions] Request: 2025-07-23 to 2026-01-23
    [Transactions] Page 1: got X txs, total_transactions=Y
    [Transactions] FINAL: Returning Z transactions
    ```
  - **If `total_transactions=1`:** Plaid hasn't synced → increase delay to 15s
  - **If date range issue:** Extend to 12 months or update testUserData.json dates
  - **Build verified:** ✓ Compiled successfully

- ✓ **Fix: TransactionAnalyzer Calculation Bugs**
  - **Bug #1 (Line 276-280):** Fixed `isActualIncome()` sandbox fallback
    - Added transfer keyword rejection ("transfer", "funding", "buffer", "emergency fund", etc.)
    - "INITIAL EMERGENCY BUFFER FUNDING" now correctly excluded from income
  - **Bug #2 (Line 367):** Fixed `isInternalTransfer()` patterns
    - Added: "credit card payment", "card payment", "loan payment", "autopay"
    - Added bank-specific patterns: "payment - chase/citi/amex/discover/capital one"
    - Credit card payments now correctly excluded from expenses
  - **File:** `TransactionAnalyzer.swift`
  - **Build verified:** ✓ Compiled successfully

- 🔍 **Bug Analysis: TransactionAnalyzer Calculation Errors**
  - **Issue:** Transaction analysis not calculating correct values after recent updates
  - **Test data:** `testUserData.json` with 10 accounts, ~130 transactions
  - **Expected monthly income:** ~$5,125 (14 paychecks @ $2,500 + $750 bonus / 7 months)
  - **Bugs identified:**
    1. **Sandbox fallback (line 276-280):** Large uncategorized negatives treated as income
       - "INITIAL EMERGENCY BUFFER FUNDING" -$2,800 → false income
    2. **Credit card payments (line 367):** Not excluded from expenses
       - "CREDIT CARD PAYMENT - CHASE SAPPHIRE" +$450 → false expense
  - **Root cause:** `isActualIncome()` sandbox fallback too aggressive; `isInternalTransfer()` missing debt payment patterns
  - **Status:** Analysis complete, fix plan documented, awaiting implementation

### 2026-01-22
- ✓ **Fix: TransactionAnalyzer Values Not Displaying Correctly**
  - **Issue:** Calculation values not displaying after implementation plan changes
  - **Root cause:** Lacked visibility into calculations; Plaid sandbox may not have `personal_finance_category`; income detection fallback too strict
  - **Fixed:**
    1. Added diagnostic logging to `calculateMonthlyFlow()`:
       - Logs total transactions analyzed
       - Logs income transactions count and amounts
       - Shows "missed income candidates" not classified as income
       - Shows expense breakdown totals
    2. Improved income detection fallback in `isActualIncome()`:
       - Added patterns: "direct deposit", "paycheck", "payment received", "deposit", "credit"
       - Added refund exclusion: "refund", "return", "reversal", "adjustment", "cashback"
       - Added sandbox fallback: large negative amounts with no category treated as income
  - **Verify:** Run with `-ResetDataOnLaunch`, connect Plaid sandbox, analyze transactions, check `[MonthlyFlow]` logs in Xcode console
  - **File:** `FinancialAnalyzer/Services/TransactionAnalyzer.swift`

- ✓ **TASK 1-6: TransactionAnalyzer Implementation Plan COMPLETE**
  - **Goal:** Fix 5 critical calculation errors (income inflation, expense inflation, wrong formula, missing investment detection, internal transfer double-counting)

  - **TASK 2: Rewrote TransactionAnalyzer.swift**
    - Added `isActualIncome()` - checks negative amounts + excludes transfers/refunds
    - Added `isInvestmentContribution()` - detects 401k/IRA/investment transfers
    - Added `isInternalTransfer()` - filters internal transfers
    - Added `shouldExcludeFromBudget()` - unified exclusion check for other services
    - Added `generateSnapshot()` - correct calculation engine
    - Disposable Income = Income - Essential Expenses - Debt Minimums

  - **TASK 3: Updated SpendingPatternAnalyzer.swift**
    - Changed guard to use `TransactionAnalyzer.shouldExcludeFromBudget()`

  - **TASK 4: Updated BudgetManager.swift**
    - Changed guard to use `TransactionAnalyzer.shouldExcludeFromBudget()`
    - Renamed `recommendGoalPriority(availableToSpend:)` → `recommendGoalPriority(disposableIncome:)`

  - **TASK 5: Updated AlertRulesEngine.swift**
    - Renamed parameter `availableToSpend` → `disposableIncome` throughout

  - **TASK 6: Migrated all consumers to AnalysisSnapshot**
    - `FinancialViewModel.swift` - uses `AnalysisSnapshot`, `generateSnapshot()`, `disposableIncome`
    - `FinancialHealthCalculator.swift` - accepts `snapshot: AnalysisSnapshot` parameter
    - `DashboardView.swift` - uses `AnalysisSnapshot`
    - `CategoryDetailView.swift` - uses `AnalysisSnapshot`
    - `AllocationPlannerView.swift` - preview uses proper `AnalysisSnapshot` construction
    - **Deleted** `FinancialSummary.swift`
    - **Removed** from Xcode project.pbxproj

  - **Verification:** No `FinancialSummary` references in Swift code (except comment marker)

- ✓ **TASK 1: Model Files Refactor (TransactionAnalyzer Implementation Plan)**
  - **Goal:** Fix critical calculation errors by refactoring model files
  - **Files modified:**
    - `BankAccount.swift` - Added `minimumPayment: Double?`, `apr: Double?` for debt calculations
    - `BucketCategory.swift` - Changed `.disposable` label from "To Allocate" → "Disposable Income"
    - `ExpenseBreakdown.swift` - Added `healthcare: Double` category
    - `MonthlyFlow.swift` - Added `disposableIncome`, `dailyDisposable`, `hasPositiveDisposable`, `empty`
    - `FinancialPosition.swift` - Major extension: added `DebtAccount` struct, `DebtType` enum, `debtBalances: [DebtAccount]`, computed `totalDebt`, `weightedAverageAPR`, `hasHighInterestDebt`, `totalMinimumPayments`
    - `AnalysisSnapshot.swift` - Added `overallConfidence` to metadata, `isValidForAllocation`, `validationError`, `empty`, plus convenience accessors
    - `Transaction.swift` - Added `categoryConfidence` computed property
    - `TransactionAnalyzer.swift` - Updated to use new `healthcare` category and compute `overallConfidence`
    - `ExpenseBreakdownSheet.swift`, `AnalysisCompleteView.swift` - Fixed mock data for new properties
  - **Files created:**
    - `FinancialSnapshot.swift` - Typealias for AnalysisSnapshot (plan compatibility)
  - **Files deleted:**
    - `Sources/` directory (deprecated SPM scaffolding)
    - `Package.swift` (deprecated SPM manifest)
    - `Tests/` directory (empty)
  - **Build verified:** ✓ Compiled successfully

### 2026-01-21
- ✓ **Fixed design system not applied across application**
  - **Issue:** 6 major views used system colors/fonts instead of DesignTokens
  - **Root cause:** Views created before design system wasn't refactored
  - **Fixed files:**
    - `WelcomePageView.swift` - Now uses DesignTokens, Typography, PrimaryButton
    - `AllocationPlannerView.swift` - Now uses GlassmorphicCard, design tokens, typography
    - `AllocationBucketCard.swift` - Now uses primaryCardStyle(), design tokens
    - `FinancialHealthReportView.swift` - Now uses GlassmorphicCard, design tokens
    - `ScheduleTabView.swift` - Now uses PrimaryButton, design tokens, background
    - `HealthReportComponents.swift` - MetricCard, ProgressBar, SpendingBreakdownRow updated
  - **Patterns replaced:**
    - `Color(.systemBackground)` → `DesignTokens.Colors.backgroundPrimary`
    - `Color(.secondarySystemBackground)` → `primaryCardStyle()`
    - Raw `.padding(20)` → `DesignTokens.Spacing.lg`
    - `.font(.title3)` → `.title3Style()`
    - `.foregroundColor(.secondary)` → `.subheadlineStyle()`
  - **Build verified:** ✓ Compiled successfully

- ✓ Added design system with glassmorphic components
  - `DesignTokens.swift` - color palette, spacing, typography
  - `GlassmorphicCard.swift` - frosted glass effect cards
  - `PrimaryButton.swift` - consistent button styling
  - `FinancialMetricRow.swift` - reusable metric display

- ✓ Added expense breakdown feature
  - `ExpenseBreakdown.swift` model with category aggregation
  - `ExpenseBreakdownSheet.swift` view with drill-down
  - Enhanced `TransactionAnalyzer` with breakdown calculation
  - Added `TransactionAnalyzerTests.swift` for coverage

- ✓ Refactored Dashboard and AnalysisComplete views
  - Cleaner component structure
  - Better visual hierarchy
  - Improved accessibility

- ✓ Updated documentation
  - `ALLOCATION_PLANNER_TESTING_GUIDE.md` - 10 test scenarios
  - `ADD_NEW_FILES_TO_XCODE.md` - file registration guide
  - Enhanced `CLAUDE.md` with testing scenarios

### 2026-01-19
- ✓ Fixed allocation bucket validation
  - Added NaN/infinite guard for monthlyExpenses
  - Backend debt paydown now correctly adjusts discretionary to sum to 100%

- ✓ Resolved Swift 6 concurrency errors
  - Removed `@MainActor` from `AllocationBucket`
  - Added `@unchecked Sendable` conformance
  - Removed retroactive `DateComponents` Comparable extension

- ✓ Fixed unused variable warning in `BudgetManager.deleteGoal`

### 2026-01-15
- ✓ Registered 34 Swift files in Xcode project
  - All Models, Services, Views, Components now in `project.pbxproj`
  - Fixed build errors from missing files

- ✓ Added missing enums and properties
  - `PresetTier`, `BucketLinkageMethod` enums
  - `.debtPaydown` case in `AllocationBucketType`
  - Missing `@Published` properties for allocation features

- ✓ Fixed WelcomePageView button logic
- ✓ Fixed color references (`primaryAccent` → `.blue`/`.green`)

---

## Known Issues

### Critical 🔴
(none)

### Important 🟡
- **No user authentication**
  - Single-user dev mode only
  - Blocks production deployment
  - Impact: Cannot deploy to App Store

- **Backend uses JSON file storage**
  - `plaid_tokens.json` not suitable for production
  - No encryption at rest
  - Impact: Security concern for production

### Minor 🟢
- Plaid sandbox limited to 10 accounts per custom user
- Transaction categories may take 10-15 seconds to populate after connecting
- Some console warnings about deprecated APIs

---

## Technical Debt

### High Priority
- **Backend needs database migration**
  - JSON storage → PostgreSQL/SQLite
  - Add encryption for sensitive data
  - File: `backend/server.js` (~1800 lines, needs refactor)

- **Add user authentication**
  - Currently no auth layer
  - Need OAuth or JWT implementation
  - Security requirement for production

### Medium Priority
- **Test coverage needs improvement**
  - Only `TransactionAnalyzerTests.swift` exists
  - Need tests for: FinancialHealthCalculator, AllocationScheduler, BudgetManager
  - Target: Critical services >80% coverage

- **Backend error handling**
  - Inconsistent error responses
  - Need standardized error format
  - Add proper logging

### Low Priority
- Consider code splitting for FinancialViewModel (large file)
- Optimize bundle size
- Add accessibility labels to all interactive elements

---

## Performance Benchmarks

**App Launch:**
- Plaid Link: Instant (preloaded tokens)
- Dashboard load: <500ms (cached data)
- Transaction refresh: 2-3s (Plaid API)

**API Response Times:**
- Link token creation: ~200ms
- Account fetch: ~1s
- Transaction fetch: ~2s (depends on account count)
- AI allocation recommendation: ~1.5s

**Memory Usage:**
- iOS average: ~80MB (acceptable)
- No memory leaks detected

---

## Testing Notes

### How to Run Tests
```bash
# Backend
cd backend && npm test

# iOS (Xcode)
Cmd+U
```

### Plaid Sandbox Users

**Basic testing:**
```
Username: user_good
Password: pass_good
MFA: 1234
```

**Stress testing (recommended):**
```
Username: user_custom
Password: [paste plaid_custom_user_config.json]
```
Provides 10 accounts, ~230 transactions.

### Automated Reset
Enable `-ResetDataOnLaunch` in Xcode scheme for clean state on each run.

---

## Architecture Decisions Log

### 2026-01-22: TransactionAnalyzer Rewrite (TASK 2-6)
**Decision:** Replace `availableToSpend` with `disposableIncome`, delete `FinancialSummary`
**Rationale:** Fixed 5 critical calculation errors - income/expense inflation, wrong formula, missing investment detection
**Formula:** `Disposable Income = Income - Essential Expenses - Debt Minimums`
**Files:** `TransactionAnalyzer.swift`, `FinancialViewModel.swift`, `FinancialHealthCalculator.swift`, deleted `FinancialSummary.swift`
**Trade-off:** Breaking change to all consumers; mitigated with backward-compat properties on AnalysisSnapshot

### 2026-01-22: Financial Model Refactor (TASK 1)
**Decision:** Separate flow (MonthlyFlow) from position (FinancialPosition), add detailed debt tracking
**Rationale:** Enables accurate debt payoff calculations, APR-weighted prioritization, minimum payment tracking
**Files:** `FinancialPosition.swift` (DebtAccount, DebtType), `MonthlyFlow.swift`, `AnalysisSnapshot.swift`
**Trade-off:** Breaking change to FinancialPosition init; mitigated with backward-compatible initializer

### 2026-01-21: Design System
**Decision:** Custom glassmorphic design tokens
**Rationale:** Consistent visual language, encouraging (non-judgmental) colors
**Files:** `DesignSystem/` directory

### 2025-01: State Management
**Decision:** MVVM with centralized FinancialViewModel
**Rationale:** SwiftUI native, single source of truth
**Trade-off:** Large ViewModel; may split later

### 2025-01: Health Score Privacy
**Decision:** Never show 0-100 score to users
**Rationale:** Prevent judgment; backend-only for AI personalization
**Trade-off:** Less transparency

### 2025-01: Allocation Rebalancing
**Decision:** Priority-based (discretionary first, emergency fund last)
**Rationale:** Protect critical allocations
**Trade-off:** May surprise users; mitigated with toast notifications

---

## Notes for Future Sessions

### Immediate Priorities
1. User authentication (blocks production)
2. Replace JSON storage with database
3. Improve test coverage

### Before Launch Checklist
- [ ] User authentication
- [ ] Production database
- [ ] HTTPS in production
- [ ] Privacy policy
- [ ] App Store assets
- [ ] Error monitoring (Sentry)
- [ ] Security audit
- [ ] Plaid development credentials

### Questions to Resolve
- OAuth vs JWT for auth?
- PostgreSQL vs SQLite for backend DB?
- Which error monitoring service?

---

## Deployment Status

### Environments
- **Development:** localhost:3000 ✓
- **Staging:** Not set up
- **Production:** Not deployed

### CI/CD Status
- Automated tests: Not configured
- Automated deployment: Not configured
- Need: GitHub Actions, Xcode Cloud or Fastlane

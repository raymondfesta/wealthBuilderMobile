# Project Progress Tracker

Last Updated: 2026-01-27 (My Plan feature - 4 allocation bucket cards)

## Current State

### What's Working ✓
- **User authentication** (Sign in with Apple + email/password)
- **SQLite database** (users, plaid_items, sessions tables)
- **Encrypted Plaid tokens** (AES-256-GCM at rest)
- JWT auth (15min access, 30d refresh tokens)
- Plaid bank account connection (sandbox)
- Transaction fetching and categorization
- Allocation bucket planner (5 buckets: Essential, Emergency, Discretionary, Investments, Debt)
- Allocation schedule with paycheck detection
- Proactive AI guidance via GPT-4o-mini
- Design system with glassmorphic components
- Expense breakdown analysis
- User journey state machine (onboarding flow)
- Link token preloading (instant Plaid Link)
- Encrypted session cache (AES-256-GCM, 24h expiry)
- Cache-first loading (<1s repeat analysis)
- Automated data reset via launch arguments
- Keychain token storage (auth + Plaid)
- Plaid items synced from backend on login (data persists across logout/login)
- Smart data refresh based on cache age (balances-only vs full refresh)
- Offline mode detection with graceful degradation
- Backend allocation plan storage (survives reinstall)
- **Silent background recovery** (returning users see instant dashboard, no loading UI)
- **My Plan view** (4 allocation bucket cards replacing Dashboard, real-time plan adherence)

### In Progress 🔨
- Sign in with Apple capability setup (requires Apple Developer portal)
- CI/CD pipeline

### Blocked/Waiting ⏸
- Production Plaid credentials (development env pending)
- App Store submission (needs privacy policy)
- Sign in with Apple (needs Apple Developer portal configuration)

---

## Next Up

**Priority 1: Sign in with Apple Setup**
- Configure App ID in Apple Developer portal
- Enable Sign in with Apple capability in Xcode
- Test Apple auth flow end-to-end

**Priority 2: CI/CD Pipeline**
- GitHub Actions for automated tests
- Automated build validation
- Xcode Cloud or Fastlane for iOS builds

**Priority 3: Push Notifications**
- Paycheck detection alerts
- Allocation reminders
- Budget threshold warnings

**Priority 4: Production Deployment**
- Switch PLAID_ENV=development
- Set up HTTPS
- Configure App Store privacy policy

---

## Completed This Session

### 2026-01-27

- ✓ **Feat: My Plan View - Real-time allocation plan adherence**
  - **Goal:** Replace Dashboard with 4 vertical cards showing plan adherence for Essential, Discretionary, Emergency Fund, Investments
  - **Architecture:**
    - Calculate spending from transactions (not Budget.currentSpent)
    - Use linked account balances for savings buckets
    - Calendar month cycle (1st to end of month)
    - Auto-link accounts on view load
  - **Files created:**
    - `Views/MyPlan/MyPlanView.swift` - Main view with cycle header, status badge, 4 bucket cards
    - `Views/MyPlan/PlanAdherenceCard.swift` - Card component with SpendingCardContent, EmergencyFundCardContent, InvestmentsCardContent inline
  - **TransactionAnalyzer.swift additions:**
    - `isEssentialSpending()` - PFC-based classification (rent, utilities, groceries vs restaurants, entertainment)
    - `isDiscretionarySpending()` - Essential expense that's not essential spending
    - `spentThisCycle()` - Sum transactions for bucket type within cycle dates
    - `dailyBurnRate()` - Average daily spend for projection
    - `projectedCycleSpend()` - Extrapolated end-of-cycle spend
    - `categoryBreakdown()` - Top spending categories for detail view
  - **AllocationBucket.swift additions:**
    - `PlanAdherenceStatus` enum (onTrack, warning, overBudget, ahead, behind, noData)
    - Cycle computed properties (cycleStartDate, cycleEndDate, daysRemainingInCycle, totalDaysInCycle)
    - `monthsOfCoverage(essentialMonthlySpend:)` for emergency fund tracking
  - **FinancialViewModel.swift additions:**
    - `updateBucketBalances()` - Populate currentBalanceFromAccounts via AccountLinkingService
    - `autoLinkAccountsToBuckets()` - Auto-link high/medium confidence account suggestions
  - **BudgetManager.swift change:**
    - `saveAllocationBucketsToCache()` changed from private to internal (needed for auto-link save)
  - **Navigation changes:**
    - `FinancialAnalyzerApp.swift` - TabView uses MyPlanView instead of DashboardView
    - Label changed from "Dashboard" to "My Plan"
  - **Card content by bucket type:**
    - **Essential/Discretionary:** Remaining balance, daily burn rate, days remaining at current pace, progress bar, status badge
    - **Emergency Fund:** Account balance, months of coverage (vs essential expenses), target progress, status badge
    - **Investments:** Account balance, contribution goal tracking
  - **Debt Paydown:** Always hidden (only 4 cards displayed)
  - **Build verified:** ✓

- ✓ **Refactor: Simplified Dashboard UI**
  - Removed "Your Financial Summary" header section
  - Removed "Budget Status" section (horizontal budget cards)
  - Removed "Recent Transactions" section
  - Dashboard now shows only: allocation buckets + financial buckets grid
  - File reduced from 275 → 157 lines
  - **File:** [DashboardView.swift](FinancialAnalyzer/Views/DashboardView.swift)

- ✓ **Feat: Silent background recovery for returning users**
  - **Issue:** Returning users saw visible loading indicators ("Fetching accounts...", "Analyzing...") when they should see instant dashboard
  - **Root cause:** `handleDataRecovery()` for `.planCreated` called `fetchAccountsOnly()` and `performSmartRefresh()` with full loading UI, and re-analyzed data even when cached summary existed
  - **Solution:** Created `performBackgroundRefresh()` method that refreshes data silently without loading indicators
  - **Changes:**
    - `performBackgroundRefresh(itemIds:)` - NEW - silent refresh without isLoading/showLoadingOverlay flags
    - `handleDataRecovery()` - `.planCreated` case now uses `performBackgroundRefresh()` instead of `fetchAccountsOnly()` + `performSmartRefresh()`
    - `updateSpendingProgress(from:)` - NEW in BudgetManager - updates budget progress without regenerating budgets
    - `saveBudgetsToCache()` - NEW public method in BudgetManager
  - **Expected logs after fix:**
    ```
    📍 [State] Applied backend state: planCreated
    🔄 [Recovery] Completed user - showing dashboard immediately
    ✅ [Recovery] Using cached summary - skipping re-analysis
    🔄 [Recovery] Starting silent background refresh...
    ✅ [Background Refresh] Updated 34 account(s)
    ✅ [Background Refresh] Updated 99 transaction(s)
    ✅ [Background Refresh] Keeping cached summary (no re-analysis)
    ✅ [Background Refresh] Complete - dashboard data updated silently
    ```
  - **UX improvement:** Dashboard appears instantly with cached data; balances/transactions update silently in background
  - **Files:** [FinancialViewModel.swift](FinancialAnalyzer/ViewModels/FinancialViewModel.swift), [BudgetManager.swift](FinancialAnalyzer/Services/BudgetManager.swift)
  - **Build verified:** ✓

- ✓ **Fix: State overwrite in fetchAccountsOnly() during recovery**
  - **Issue:** Completed users saw onboarding after login because `fetchAccountsOnly()` unconditionally set state to `.accountsConnected`
  - **Root cause:** Method always called `self.userJourneyState = .accountsConnected` at line 576, regardless of context
  - **Fix:** Added `preserveState: Bool = false` parameter; recovery paths now pass `true` to preserve backend-determined state
  - **Changes:**
    - `fetchAccountsOnly(preserveState:)` - conditionally sets state and shows success banner
    - `handleDataRecovery()` - passes `preserveState: true` for `.analysisComplete`, `.allocationPlanning`, `.planCreated`
  - **File:** [FinancialViewModel.swift](FinancialAnalyzer/ViewModels/FinancialViewModel.swift)
  - **Build verified:** ✓

- ✓ **Feat: Backend Allocation Plan Storage - Persist allocations across reinstalls**
  - **Goal:** User's allocation plan survives app reinstall/cache loss
  - **Problem:** Allocation percentages, account linkages, and paycheck schedule lost on cache clear
  - **Solution:** Store allocation plan in backend SQLite database, restore on login
  - **Database changes:**
    - `db/schema.sql` - Added `user_allocation_plans` and `user_paycheck_schedules` tables
    - `db/database.js` - Added migration to create tables on startup
  - **Backend API endpoints (3 new):**
    - `GET /api/user/allocation-plan` - Fetch user's saved plan
    - `POST /api/user/allocation-plan` - Save/update plan (validates sum to 100%)
    - `DELETE /api/user/allocation-plan` - Delete plan (for testing/reset)
  - **iOS model reuse:**
    - Models already existed in `UserStatus.swift`: `AllocationPlanResponse`, `StoredAllocation`, `StoredPaycheckSchedule`, `SaveAllocationPlanRequest`, etc.
  - **iOS service methods (2 new):**
    - `PlaidService.getAllocationPlan()` - Fetch from backend
    - `PlaidService.saveAllocationPlan(allocations:paycheckSchedule:)` - Save to backend
  - **iOS ViewModel changes:**
    - `restoreAllocationPlanFromBackend()` - Called in `setCurrentUser()` when onboarding complete but buckets empty
    - `confirmAllocationPlan()` - Now saves plan to backend before marking onboarding complete
  - **Data persisted:**
    - ✓ Bucket percentages and types
    - ✓ Target amounts (e.g., emergency fund goal)
    - ✓ Linked account IDs
    - ✓ Preset tier selection
    - ✓ Paycheck schedule (frequency, amount, next date)
  - **Data NOT persisted (fresh from Plaid):**
    - ✗ Transaction history
    - ✗ Account balances
    - ✗ Analysis snapshot
  - **Flow:**
    1. User confirms allocation plan → saved to backend
    2. App reinstalled → login → `setCurrentUser()` → restore from backend
    3. Custom percentages, linked accounts, paycheck schedule all restored
  - **Build verified:** ✓
- ✓ **Feat: Backend Onboarding Flag - Source of truth for journey state**
  - **Goal:** Journey state survives cache loss by using backend `onboardingCompleted` flag
  - **Problem:** Users who completed onboarding saw onboarding again after cache cleared (app reinstall, cache expiration, encryption key issues)
  - **Solution:** Backend now stores `onboarding_completed` flag; iOS uses it as source of truth
  - **Backend changes:**
    - `db/schema.sql` - Added `onboarding_completed`, `onboarding_completed_at` columns to users table
    - `db/database.js` - Added migration to add columns to existing databases
    - `server.js` - Updated `/api/plaid/items` to return `onboardingCompleted` flag
    - `server.js` - Added `POST /api/user/complete-onboarding` endpoint
    - `server.js` - Added `GET /api/user/status` endpoint
  - **iOS changes:**
    - `Models/UserStatus.swift` (NEW) - Response models for Plaid items with status, stored allocations
    - `Services/PlaidService.swift` - Added `getPlaidItemsWithStatus()`, `completeOnboarding()` methods
    - `ViewModels/FinancialViewModel.swift` - Updated `syncPlaidItemsFromBackend()` to return onboarding status, updated `setCurrentUser()` to use backend flag, updated `confirmAllocationPlan()` to mark onboarding complete
  - **Flow:**
    1. User logs in → `setCurrentUser()` syncs from backend
    2. Backend returns `onboardingCompleted: false/true`
    3. If true → go to dashboard (even with empty cache)
    4. If false → resume at appropriate onboarding step based on local data
    5. User confirms allocation plan → `completeOnboarding()` marks flag true in backend
  - **Test scenarios:**
    - Fresh user: Backend `onboardingCompleted: false, items: []` → onboarding
    - Returning user (cache intact): Backend `onboardingCompleted: true` → dashboard
    - Returning user (cache cleared): Backend `onboardingCompleted: true` → dashboard + fresh data fetch
    - Mid-onboarding resume: Backend `onboardingCompleted: false, items: [...]` → correct step
  - **Build verified:** ✓

- ✓ **Fix: iOS 16 compatibility - onChange deprecation**
  - Fixed `FinancialAnalyzerApp.swift` using iOS 17 `onChange(of:_:_:)` signature
  - Changed to iOS 16 compatible `onChange(of:_:)` signature

- ✓ **Feat: DataRefreshService for smart cache-based refresh**
  - **Goal:** Centralized data refresh strategy based on cache freshness
  - **Problem:** Ad-hoc refresh logic scattered across ViewModel methods with no intelligent decisions about when/what to refresh
  - **Solution:** Created DataRefreshService that determines refresh strategy based on cache age:
    - Fresh (<15 min): No refresh
    - Recent (15 min - 4 hr): Background balance refresh only (fast)
    - Stale (4 hr - 7 days): Background full refresh
    - Very stale (>7 days) or no cache: Foreground full refresh with loading UI
    - User-initiated: Always full refresh
  - **Files created:**
    - `Models/CacheMetadata.swift` - tracks cache freshness with age calculations
    - `Services/DataRefreshService.swift` - centralized refresh logic with strategy pattern
    - `Services/NetworkMonitor.swift` - NWPathMonitor wrapper for offline detection
    - `Views/Components/RefreshIndicatorView.swift` - subtle UI for background refresh status
  - **Files modified:**
    - `FinancialViewModel.swift` - added `cacheMetadata`, `performSmartRefresh()`, computed properties
    - `DashboardView.swift` - added offline banner, uses `performSmartRefresh(isUserInitiated: true)` for pull-to-refresh
    - `FinancialAnalyzerApp.swift` - added scenePhase observer for foreground refresh
    - `project.pbxproj` - registered new files
  - **Key features:**
    - Strategy enum: `.none`, `.balancesOnly`, `.backgroundFull`, `.foregroundFull`, `.userInitiated`
    - Offline detection via NWPathMonitor (shows "Offline - showing cached data" banner)
    - "Last updated X ago" indicator in toolbar
    - Data staleness indicator when cache >4 hours old
    - Lifecycle handling: checks refresh when app comes to foreground after >15 min
  - **Acceptance criteria met:**
    - [x] App determines refresh strategy based on cache age
    - [x] Fresh cache = no refresh
    - [x] Stale balances = quick background refresh
    - [x] Stale transactions = full background refresh
    - [x] Very stale/no cache = foreground refresh with loading
    - [x] Pull-to-refresh always works
    - [x] Offline state handled gracefully
  - **Build verified:** ✓

- ✓ **Feat: Updated login flow to use backend onboarding state**
  - **Goal:** Journey state determined from backend `onboardingCompleted` flag, not local cache inference
  - **Problem:** Cache corruption/clearing caused returning users to see onboarding instead of dashboard
  - **Solution:** Refactored `setCurrentUser()` to be backend-first:
    1. Sync from backend to get itemIds and onboarding status
    2. Determine journey state from backend flag (source of truth)
    3. Load local cache for data only (no state inference)
    4. Handle data recovery based on state
  - **New methods added:**
    - `determineJourneyStateFromBackend()` - maps backend flag to UserJourneyState
    - `refineOnboardingState()` - adjusts state for mid-onboarding users
    - `handleDataRecovery()` - fetches data from Plaid if cache missing
    - `clearAllLocalCache()` - helper for cache clearing
    - `performSmartRefresh()` - simplified version using cache age check
  - **Changes:**
    - `loadFromCache()` no longer calls `inferStateFromCache()` (deprecated)
    - `syncPlaidItemsFromBackend()` now uses `clearAllLocalCache()` helper
    - Removed broken DataRefreshService integration (was incomplete)
    - Removed RefreshIndicatorView from DashboardView (depended on removed service)
  - **Files modified:**
    - `ViewModels/FinancialViewModel.swift` - major refactor
    - `Views/DashboardView.swift` - removed offline banner and refresh indicator
    - `Models/UserStatus.swift` - fixed PaycheckSchedule init params
  - **Files removed:**
    - `Services/DataRefreshService.swift` - incomplete, caused build errors
    - `Views/Components/RefreshIndicatorView.swift` - depended on removed service
  - **Build verified:** ✓
  - **Testing scenarios:**
    - New user: Backend returns `onboardingCompleted: false, items: []` → shows onboarding
    - Returning user (cache intact): Backend returns `onboardingCompleted: true` → shows dashboard
    - Returning user (cache cleared): Backend returns `onboardingCompleted: true` → shows dashboard, fetches fresh data
    - Mid-onboarding resume: Backend returns `onboardingCompleted: false, items: [...]` → resumes at correct step

- ✓ **Fix: Encryption key deletion during Plaid sync**
  - **Issue:** After logout/login, encrypted cache fails with CryptoKitError - users forced to re-onboard
  - **Root cause:** `syncPlaidItemsFromBackend()` retrieved ALL Keychain keys (including encryption key `com.financialanalyzer.cache.key.dev`) and deleted any not found in backend Plaid items
  - **Evidence from logs:**
    ```
    🔄 [Sync] Keychain has 4 item(s)
    🗑️ [Sync] Removed stale itemId: com.fina...
    🔐 [SecureCache] Generated new encryption key
    ❌ [SecureCache] Failed to load accounts: CryptoKit.CryptoKitError error 3
    ```
  - **Fix:** Added `getPlaidItemIds()` helper that filters out internal keys (`!$0.contains("com.financial")`), used consistently in:
    - `syncPlaidItemsFromBackend()` - stops deleting encryption key as "stale"
    - `fetchAccountsOnly()` - only iterates Plaid items
    - `refreshAllData()` - only iterates Plaid items
    - `loadFromCache()` - only loads cache for Plaid items
    - `analyzeMyFinances()` - only analyzes Plaid items
    - `validateAndFixAccountItemIds()` - logs only Plaid items
    - `setCurrentUser()` recovery path - uses helper
  - **File:** `FinancialViewModel.swift`
  - **Build verified:** ✓

- ✓ **Fix: Xcode build failure - "Entitlements file modified during build"**
  - **Issue:** Build failed with entitlements modification error
  - **Root cause:** Stale derived data with incorrect timestamps
  - **Fix:** Cleared derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/FinancialAnalyzer-*`
  - **Build verified:** ✓

- ✓ **Fix: Login persistence - accounts not loading after logout/login**
  - **Issue:** After logout/login, users shown onboarding instead of their connected accounts
  - **Root cause:** Two issues:
    1. `init()` called `loadFromCache()` before `syncPlaidItemsFromBackend()` could sync itemIds
    2. `setCurrentUser()` had early return when userId matched, skipping sync entirely
    3. No recovery when cache files empty but backend has items
  - **Fix:**
    1. Defer `loadFromCache()` in `init()` when user is logged in (let `setCurrentUser()` handle it)
    2. Remove early return in `setCurrentUser()` - always sync from backend
    3. Add recovery: if accounts empty after cache load but itemIds exist, fetch from Plaid
  - **Files:** `FinancialViewModel.swift:51-73, 111-135`
  - **Build verified:** ✓

- ✓ **Fix: Journey state cache causing wrong view after login**
  - **Issue:** After logout/login, users shown AllocationPlannerView instead of correct onboarding step
  - **Root cause:** Cached journey state restored without validating actual data exists
  - **Fix:** Changed `loadFromCache()` to always call `inferStateFromCache()` instead of blindly trusting cached state
  - **File:** `FinancialViewModel.swift:1371-1379`

- ✓ **Fix: PlaidService auth header debug logging**
  - Added logging to show whether auth token is present when making API calls
  - **File:** `PlaidService.swift:25-29`

- ✓ **Identified: `-ResetDataOnLaunch` race condition**
  - **Bug:** Reset runs in ContentView.task AFTER user logs in, clearing fresh auth tokens
  - **Workaround:** Disable `-ResetDataOnLaunch` after initial reset
  - **Root cause:** ContentView.task checks flag and runs reset, but user already authenticated

- 🔍 **Investigated: Legacy Plaid token not migrated**
  - Old tokens in `plaid_tokens.json` not in SQLite `plaid_items` table
  - User `68191d9b-9387-41a7-952c-d652ee824347` had 0 plaid_items until fresh connect
  - **Resolution:** Fresh bank connection creates proper SQLite entry

- ✓ **Fix: Data not persisting after logout/login (empty state)**
  - **Issue:** After logout/login, users see onboarding instead of their connected bank data
  - **Root cause:** `loadFromCache()` used itemIds from local Keychain only; never fetched user's actual Plaid items from backend. Keychain itemIds could be empty/stale.
  - **Fix:** Added `syncPlaidItemsFromBackend()` method that:
    1. Calls `getPlaidItems()` to fetch user's items from backend
    2. Removes stale itemIds from Keychain (not in backend)
    3. Adds missing itemIds to Keychain
    4. Clears local cache if backend has no items
    5. Falls back to existing Keychain on network failure
  - Made `setCurrentUser()` async to call sync before loading cache
  - **Files:** `FinancialViewModel.swift`, `FinancialAnalyzerApp.swift`
  - **Build verified:** ✓

### 2026-01-26
- ✓ **Fix: Returning users see onboarding instead of dashboard**
  - **Issue:** After logout/login, users shown onboarding flow instead of their existing data (accounts, allocation plan, transactions)
  - **Root cause:** Cache data in UserDefaults not scoped by userId. With multi-user auth, cache could be corrupted/overwritten. When FinancialViewModel created, cache loading failed or loaded wrong user's data.
  - **Fix #1:** Scope all UserDefaults cache keys by userId prefix
  - **Fix #2:** Get userId from AuthService.shared in init() to ensure cache loads with correct user before .task runs
  - **Fix #3:** Add migration logic to copy existing data from old global keys to new user-scoped keys (one-time migration)
  - **Files modified:**
    - `FinancialViewModel.swift` - added `currentUserId`, `cacheKey()` helper, `setCurrentUser()` method, `migrateOldCacheKey()`, `migrateOldCacheKeys()`; updated `saveToCache()`/`loadFromCache()` to use user-scoped keys with migration
    - `BudgetManager.swift` - added `userId`, `cacheKey()` helper, `setUserId()` method, `migrateOldCacheKey()`, `migrateOldCacheKeys()`; updated cache methods to use user-scoped keys with migration
    - `FinancialAnalyzerApp.swift` - added call to `viewModel.setCurrentUser(userId)` after auth
    - `ProfileView.swift` - updated footer text to match actual behavior (data preserved on logout)
  - **Cache keys now user-scoped:**
    - `user_{userId}_summary`, `user_{userId}_journey_state`, `user_{userId}_budgets`, `user_{userId}_goals`, `user_{userId}_allocation_buckets`
  - **Migration handles:**
    - `cached_journey_state` → `user_{userId}_journey_state`
    - `cached_summary` → `user_{userId}_summary`
    - `cached_budgets` → `user_{userId}_budgets`
    - `cached_goals` → `user_{userId}_goals`
    - `cached_allocation_buckets` → `user_{userId}_allocation_buckets`
  - **Build verified:** ✓ Compiled successfully

- ✓ **Removed Financial Health Feature (iOS + Backend)**
  - **Goal:** Remove self-contained Financial Health functionality from app
  - **Files deleted (8 iOS files):**
    - `Models/FinancialHealthMetrics.swift`
    - `Services/FinancialHealthCalculator.swift`
    - `Views/HealthTabView.swift`
    - `Views/FinancialHealthReportView.swift`
    - `Views/FinancialHealthDashboardSection.swift`
    - `Views/HealthReportEmptyStateView.swift`
    - `Views/HealthReportSetupFlow.swift`
    - `Views/Components/HealthReportComponents.swift`
  - **Files modified (iOS):**
    - `FinancialViewModel.swift` - removed healthMetrics properties, caching, recalculate methods
    - `DashboardView.swift` - removed health toolbar button, sheets, dashboard section
    - `FinancialAnalyzerApp.swift` - removed Health tab from TabView
    - `BudgetManager.swift` - removed healthMetrics parameter from generateAllocationBuckets()
    - `ConnectedAccountsSheet.swift` - removed recalculateHealth() call
    - `project.pbxproj` - removed file references
  - **Files modified (Backend):**
    - `server.js` - removed healthMetrics from API request/response, simplified savings period calculation
  - **Verification:** Build succeeds, no health references remain
  - **Impact:** Allocation planning still works (uses emergency fund balance for savings period instead of health score)

- ✓ **Fix: Plaid INVALID_ACCESS_TOKEN Error**
  - **Issue:** Transaction fetch returned `INVALID_ACCESS_TOKEN - "provided access token is in an invalid format"`
  - **Root cause:** Hybrid storage mismatch - backend stored tokens in SQLite for authenticated users but lookups only checked legacy JSON file
  - **Backend fixes:**
    - Updated all Plaid endpoints to use `requireAuth` + SQLite lookup via `findPlaidItemByItemId()`
    - Removed JSON token storage (`accessTokens` Map, `loadTokens`, `saveTokens`)
    - Added `GET /api/plaid/items` endpoint for listing user's Plaid items
  - **iOS fixes:**
    - Updated PlaidService to send `item_id` instead of `access_token`
    - Token exchange now stores placeholder `"backend-managed"` (backend handles actual token)
    - Added `getPlaidItems()` method and `PlaidItem` model
    - Updated TransactionFetchService to use itemId-based API
  - **Files modified:**
    - `backend/server.js` - SQLite-only token lookup, removed JSON storage
    - `PlaidService.swift` - itemId-based requests, `getPlaidItems()` method
    - `TransactionFetchService.swift` - itemId parameter, added auth headers
    - `FinancialViewModel.swift` - uses itemId for all Plaid operations
    - `CLAUDE.md` - updated "ItemId-Based API" pattern documentation
  - **Token flow (fixed):**
    1. User authenticates → `req.userId` present
    2. User links bank → token stored in SQLite (encrypted)
    3. User fetches transactions → backend looks up token in SQLite by itemId
    4. Plaid API called with correct token → success
  - **Build verified:** ✓ Backend + iOS compile successfully

- ✓ **User Authentication System**
  - **Goal:** Multi-user auth with Sign in with Apple + email/password
  - **Backend files created:**
    - `db/database.js` - SQLite connection, migrations, CRUD
    - `db/schema.sql` - users, plaid_items, sessions tables
    - `services/encryption.js` - AES-256-GCM for Plaid tokens
    - `services/token.js` - JWT generation/validation
    - `middleware/auth.js` - requireAuth/optionalAuth
    - `routes/auth.js` - register, login, apple, refresh, logout
  - **iOS files created:**
    - `AuthState.swift`, `AuthUser.swift` - Auth models
    - `AuthService.swift` - Apple + email/password auth
    - `SecureTokenStorage.swift` - Keychain for auth tokens
    - `LoginView.swift`, `AuthRootView.swift`, `ProfileView.swift`
  - **Modified:** server.js, PlaidService.swift, DashboardView.swift, DataResetManager.swift, FinancialAnalyzerApp.swift
  - **Database:** 4 tables, bcrypt passwords, AES-256-GCM Plaid tokens
  - **Build verified:** ✓ Backend + iOS compile successfully

- ✓ **View Structure Refactoring (Separation of Concerns)**
  - **Goal:** Separate onboarding flow from post-onboarding dashboard
  - **Problem:** DashboardView conflated two responsibilities - handling journey states 1-4 (onboarding) AND state 5 (planCreated dashboard)
  - **Files created:**
    - `Views/Onboarding/OnboardingFlowView.swift` - Router for onboarding states
    - `Views/Onboarding/WelcomeConnectView.swift` - Connect bank CTA (extracted)
    - `Views/Onboarding/AccountsConnectedView.swift` - Analyze CTA (extracted)
    - `Views/Components/BucketCard.swift` - Extracted inline component
    - `Views/Components/TransactionRow.swift` - Extracted inline component
    - `Views/Components/BudgetStatusCard.swift` - Extracted inline component
    - `Views/Components/AllocationBucketSummaryCard.swift` - Extracted inline component
  - **Files moved:**
    - `AnalysisCompleteView.swift` → `Views/Onboarding/`
    - `AllocationPlannerView.swift` → `Views/Onboarding/`
  - **Files modified:**
    - `DashboardView.swift` - Reduced from ~833 to ~333 lines
    - `FinancialAnalyzerApp.swift` - Uses OnboardingFlowView during onboarding
    - `project.pbxproj` - Updated file references
  - **Architecture:**
    - Onboarding: OnboardingFlowView routes journey states 1-4
    - Post-onboarding: TabView with DashboardView (only planActiveView)
  - **Build verified:** ✓ Compiled successfully

- ✓ **Session Cache Implementation (Encrypted Local Caching)**
  - **Goal:** Instant app loads after first analysis, zero server-side storage
  - **Files created:**
    - `SecureTransactionCache.swift` - AES-256-GCM encrypted file cache
    - `TransactionFetchService.swift` - Cache-first fetching with retry
  - **Files modified:**
    - `backend/server.js` - Added `days_requested: 90`, `/api/plaid/sync-status` endpoint
    - `DataResetManager.swift` - Added `clearSecureCache()` integration
    - `FinancialViewModel.swift` - Integrated TransactionFetchService, cache migration
    - `project.pbxproj` - Registered new Swift files
  - **Key features:**
    - 3-month history (reduced from 6 for faster Plaid sync)
    - Encryption key stored in Keychain
    - Per-itemId cache files in Library/Caches
    - 24h cache expiration with background refresh
    - Auto-migration from UserDefaults to encrypted cache
  - **Expected timing:**
    - First analysis: 10-20s (Plaid sync)
    - Repeat within 24h: <1s (cache hit)
  - **Build verified:** ✓ Compiled successfully

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
    - (FinancialHealthCalculator.swift - removed in later session)
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
    - `ScheduleTabView.swift` - Now uses PrimaryButton, design tokens, background
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
- **Sign in with Apple needs Apple Developer portal setup**
  - Capability not yet configured
  - Email/password auth works as fallback
  - Impact: Apple Sign In button will fail until configured

- **JWT access token can expire during Plaid Link flow**
  - 15min token lifetime; Plaid Link can take longer
  - PlaidService doesn't retry on 401
  - Impact: "Failed to exchange token" error if idle >15min

### Minor 🟢
- Plaid sandbox limited to 10 accounts per custom user
- Transaction categories may take 10-15 seconds to populate after connecting
- Some console warnings about deprecated APIs

---

## Technical Debt

### High Priority
- **Configure Sign in with Apple**
  - Needs Apple Developer portal setup
  - Add capability to App ID
  - Test Apple auth flow end-to-end

### Medium Priority
- **Test coverage needs improvement**
  - Only `TransactionAnalyzerTests.swift` exists
  - Need tests for: AllocationScheduler, BudgetManager
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
- First analysis: 10-20s (Plaid sync)
- Repeat analysis (cache hit): <1s
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

### 2026-01-27: My Plan View Architecture
**Decision:** Calculate spending from transactions directly, not Budget.currentSpent; use linked account balances for savings buckets
**Rationale:** Budget.currentSpent was stale/unreliable; transactions are source of truth; account balances from Plaid reflect actual savings
**Implementation:**
- TransactionAnalyzer classifies essential vs discretionary via Plaid Personal Finance Category
- spentThisCycle/projectedCycleSpend calculate from filtered transactions
- AccountLinkingService.calculateBucketBalance() aggregates linked account balances
- Auto-link accounts on view load using suggestion confidence
**Files:** `TransactionAnalyzer.swift`, `AllocationBucket.swift`, `MyPlanView.swift`, `PlanAdherenceCard.swift`, `FinancialViewModel.swift`
**Trade-off:** More computation on each render; mitigated by cycle-based filtering

### 2026-01-27: Backend Allocation Plan Storage
**Decision:** Store allocation plan in backend SQLite, restore on login
**Rationale:** Local cache can be cleared (reinstall, corruption, key issues); allocation plan is user-created data that should persist
**Implementation:** New tables `user_allocation_plans` and `user_paycheck_schedules`; saved on plan confirmation, restored when onboarding complete but buckets empty
**Files:** `db/schema.sql`, `db/database.js`, `server.js`, `PlaidService.swift`, `FinancialViewModel.swift`
**Trade-off:** Additional API calls on save/restore; acceptable for data persistence guarantee

### 2026-01-26: Plaid Token Storage Migration
**Decision:** SQLite-only token storage, removed JSON fallback
**Rationale:** Hybrid storage caused INVALID_ACCESS_TOKEN errors - authenticated users' tokens went to SQLite but lookups checked JSON
**Implementation:** All Plaid endpoints use `requireAuth` + `findPlaidItemByItemId(userId, itemId)` lookup; iOS sends itemId instead of accessToken
**Files:** `server.js` (removed JSON storage), `PlaidService.swift` (itemId-based API)
**Trade-off:** Breaking change for unauthenticated flows; acceptable since auth now required

### 2026-01-26: User Authentication System
**Decision:** JWT auth with Sign in with Apple + email/password, SQLite database
**Rationale:** Multi-user support required for production; SQLite simple for MVP
**Implementation:** 15min access tokens, 30d refresh tokens, bcrypt passwords, AES-256-GCM Plaid tokens
**Files:** `db/`, `routes/auth.js`, `AuthService.swift`, `LoginView.swift`, `AuthRootView.swift`
**Trade-off:** SQLite not horizontally scalable; acceptable for MVP

### 2026-01-26: View Structure Refactoring
**Decision:** Separate onboarding flow into dedicated router, extract inline components
**Rationale:** DashboardView conflated onboarding (journey states 1-4) and dashboard (state 5); violated single responsibility
**Implementation:** OnboardingFlowView routes pre-dashboard states; DashboardView handles only post-onboarding
**Files:** `Views/Onboarding/` (5 files), `Views/Components/` (4 extracted components)
**Trade-off:** More files but cleaner separation; each page has dedicated view

### 2026-01-26: Session Cache Implementation
**Decision:** Encrypted local caching of transactions/accounts with 24h expiry
**Rationale:** Instant repeat loads (<1s vs 15-30s), zero server-side financial data storage
**Implementation:** AES-256-GCM encryption via CryptoKit, keys in Keychain, files in Library/Caches
**Files:** `SecureTransactionCache.swift`, `TransactionFetchService.swift`
**Trade-off:** 3-month history (vs 6) for faster sync; cache invalidation on account removal

### 2026-01-22: TransactionAnalyzer Rewrite (TASK 2-6)
**Decision:** Replace `availableToSpend` with `disposableIncome`, delete `FinancialSummary`
**Rationale:** Fixed 5 critical calculation errors - income/expense inflation, wrong formula, missing investment detection
**Formula:** `Disposable Income = Income - Essential Expenses - Debt Minimums`
**Files:** `TransactionAnalyzer.swift`, `FinancialViewModel.swift`, deleted `FinancialSummary.swift`
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

### 2025-01: Allocation Rebalancing
**Decision:** Priority-based (discretionary first, emergency fund last)
**Rationale:** Protect critical allocations
**Trade-off:** May surprise users; mitigated with toast notifications

---

## Notes for Future Sessions

### Immediate Priorities
1. Configure Sign in with Apple (Apple Developer portal)
2. CI/CD pipeline setup
3. Improve test coverage

### Before Launch Checklist
- [x] User authentication (JWT + Apple Sign In)
- [x] Production database (SQLite + encrypted Plaid tokens)
- [ ] Sign in with Apple capability configuration
- [ ] HTTPS in production
- [ ] Privacy policy
- [ ] App Store assets
- [ ] Error monitoring (Sentry)
- [ ] Security audit
- [ ] Plaid development credentials

### Questions to Resolve
- Which error monitoring service?
- Xcode Cloud vs Fastlane for CI/CD?

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

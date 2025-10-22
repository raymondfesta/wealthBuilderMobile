# Phase 1 Test Plan: State Management Foundation

## Quick Test Instructions

### Test 1: Fresh Install (No Cached Data)
**Objective**: Verify new user flow and state initialization

1. Delete app from simulator
2. Clean build folder (Cmd+Shift+K)
3. Build and run app
4. Check console logs

**Expected Logs**:
```
💾 [Cache Load] No cached accounts data found
💾 [Cache Load] No cached summary data found
🔍 [State] Inferring state from cached data...
   - Accounts: 0
   - Summary: nil
   - Budgets: 0
✅ [State] Inferred: .noAccountsConnected (no accounts)
```

**Expected State**: `.noAccountsConnected`

**Pass Criteria**:
- ✅ State is `.noAccountsConnected`
- ✅ No validation warnings in console
- ✅ App displays empty state UI

---

### Test 2: Connect Account → Verify State Transition
**Objective**: Verify state changes after connecting bank account

1. From Test 1, tap "Connect Bank Account"
2. Complete Plaid Link flow (user_good / pass_good)
3. Watch console logs during data refresh

**Expected Logs**:
```
🔗 [Connect] Starting bank account connection...
🔗 [Connect] Plaid Link completed successfully!
🔄 [Data Refresh] Starting data refresh...
🔄 [Data Refresh] Fetched X account(s)...
🔄 [Data Refresh] Fetched Y transaction(s)...
💾 [Cache Save] Saving account 'ACCOUNT_NAME' with itemId: XXX
💾 [Cache] Saved journey state: planCreated
```

**Current Behavior** (auto-flow not split yet):
- State will jump to `.planCreated` because current code auto-generates budgets

**Expected State**: `.planCreated` (until Phase 2 splits the flow)

**Pass Criteria**:
- ✅ State transitions are logged
- ✅ State is persisted to UserDefaults
- ✅ No validation warnings

---

### Test 3: App Restart → State Persistence
**Objective**: Verify state persists across app restarts

1. After Test 2, kill app (Cmd+Q in simulator)
2. Relaunch app
3. Check console logs

**Expected Logs**:
```
💾 [Cache Load] Found cached accounts data...
💾 [Cache Load] ✅ Decoded X account(s) from cache
📂 [Cache] Loaded journey state: planCreated
```

**Expected State**: `.planCreated` (same as before restart)

**Pass Criteria**:
- ✅ State loaded from cache (not inferred)
- ✅ Log shows "Loaded journey state" (not "Inferred")
- ✅ State matches pre-restart state

---

### Test 4: Migration - Simulate Existing User
**Objective**: Verify state inference for existing users (who don't have state saved yet)

1. Delete app from simulator
2. Build and run once to initialize
3. Kill app
4. Manually set up cached data without state:

```bash
# Run this in Terminal (modify with actual device ID)
xcrun simctl spawn booted defaults write com.yourapp.FinancialAnalyzer cached_accounts -data '...'
# Remove the state key to simulate old version
xcrun simctl spawn booted defaults delete com.yourapp.FinancialAnalyzer cached_journey_state
```

5. Relaunch app
6. Check console logs

**Expected Logs**:
```
💾 [Cache Load] ✅ Decoded X account(s) from cache
🔍 [State] Inferring state from cached data...
   - Accounts: X
   - Summary: exists
   - Budgets: Y
✅ [State] Inferred: .planCreated (budgets exist)
```

**Expected State**: Inferred based on cached data

**Pass Criteria**:
- ✅ Inference logic runs
- ✅ State correctly inferred from data
- ✅ State saved after inference

---

### Test 5: State Validation - Invalid State Detection
**Objective**: Verify validation catches inconsistent states

1. From Test 3 (with `.planCreated` state)
2. Manually clear budgets in code or debugger:
```swift
budgetManager.budgets.removeAll()
userJourneyState = .planCreated // Force invalid state
```

3. Check console logs

**Expected Logs**:
```
📍 [State] accountsConnected → planCreated
⚠️ [State] WARNING: State is .planCreated but budgets is empty
```

**Pass Criteria**:
- ✅ Validation warning appears in DEBUG builds
- ✅ No crash or error
- ✅ Warning is clear and actionable

---

## Manual Verification Checklist

### UserJourneyState Model
- [ ] File exists at `/FinancialAnalyzer/Models/UserJourneyState.swift`
- [ ] Enum has 4 cases: `noAccountsConnected`, `accountsConnected`, `analysisComplete`, `planCreated`
- [ ] Conforms to `String, Codable`
- [ ] Has `title`, `description`, `nextActionTitle` properties
- [ ] Has permission gates: `canConnectAccount`, `canAnalyze`, `canCreatePlan`

### FinancialViewModel Integration
- [ ] `@Published var userJourneyState` declared (line ~100)
- [ ] Default value is `.noAccountsConnected`
- [ ] `didSet` observer exists with logging
- [ ] `validateStateConsistency()` called on state change

### Persistence
- [ ] State saved in `saveToCache()` function (line ~681)
- [ ] State loaded in `loadFromCache()` function (line ~744)
- [ ] UserDefaults key is `cached_journey_state`
- [ ] Encoder/decoder used correctly

### Inference Logic
- [ ] `inferStateFromCache()` function exists (line ~758)
- [ ] Called when no cached state found (line ~751)
- [ ] Checks accounts count
- [ ] Checks summary existence
- [ ] Checks budgets count
- [ ] Assigns correct state based on data

### Validation Logic
- [ ] `validateStateConsistency()` function exists (line ~780)
- [ ] Wrapped in `#if DEBUG` directive
- [ ] Validates each state case
- [ ] Prints warnings for inconsistencies
- [ ] Does not crash or throw errors

---

## Expected Console Output Examples

### New User Flow
```
💾 [Cache Load] Starting cache load...
💾 [Cache Load] No cached accounts data found
💾 [Cache Load] No cached transactions data found
💾 [Cache Load] No cached summary data found
🔍 [State] Inferring state from cached data...
   - Accounts: 0
   - Summary: nil
   - Budgets: 0
✅ [State] Inferred: .noAccountsConnected (no accounts)
💾 [Cache Load] Cache load complete - Accounts: 0, Transactions: 0
```

### Connect Account (Current Auto-Flow)
```
🔗 [Connect] Starting bank account connection...
🔗 [Connect] Getting link token...
🔗 [Connect] Link token obtained, presenting Plaid Link...
✅ [Connect] Plaid Link completed successfully!
🔗 [Connect] Refreshing data after successful link...
🔄 [Data Refresh] Starting data refresh...
🔄 [Data Refresh] Found 1 stored itemId(s): [item_xxx]
🔄 [Data Refresh] Fetched 2 account(s) for itemId: item_xxx
🔄 [Data Refresh] Fetched 150 transaction(s) for itemId: item_xxx
💾 [Cache Save] Saving account 'Plaid Checking' with itemId: item_xxx
💾 [Cache] Saved journey state: planCreated
📍 [State] noAccountsConnected → planCreated
✅ [Data Refresh] Data refresh completed
```

### App Restart with Cached State
```
💾 [Cache Load] Starting cache load...
💾 [Cache Load] Found cached accounts data (1234 bytes)
💾 [Cache Load] ✅ Decoded 2 account(s) from cache
📂 [Cache] Loaded journey state: planCreated
💾 [Cache Load] Found cached transactions data (5678 bytes)
💾 [Cache Load] ✅ Decoded 150 transaction(s) from cache
💾 [Cache Load] Cache load complete - Accounts: 2, Transactions: 150
```

### Migration - Infer from Cached Data
```
💾 [Cache Load] Found cached accounts data (1234 bytes)
💾 [Cache Load] ✅ Decoded 2 account(s) from cache
🔍 [State] Inferring state from cached data...
   - Accounts: 2
   - Summary: exists
   - Budgets: 6
✅ [State] Inferred: .planCreated (budgets exist)
📍 [State] noAccountsConnected → planCreated
💾 [Cache Load] Cache load complete - Accounts: 2, Transactions: 150
```

---

## Known Limitations (To Be Addressed in Phase 2)

1. **Auto-Flow Still Active**: The current implementation still auto-generates budgets after connecting an account. Phase 2 will split this into separate user-triggered actions.

2. **State Transitions Not Enforced**: While the state machine exists, the actual data operations don't respect state yet. Phase 2 will add guards like:
   ```swift
   guard userJourneyState.canAnalyze else { return }
   ```

3. **No UI Integration**: The state exists but the UI doesn't render different views based on state yet. Phase 2 will add state-based UI.

---

## Success Criteria for Phase 1

Phase 1 is considered COMPLETE if:

- ✅ All 5 tests pass without errors
- ✅ All manual checklist items verified
- ✅ Console logs match expected patterns
- ✅ State persists across app restarts
- ✅ Inference logic works for existing users
- ✅ Validation catches inconsistent states

---

## Troubleshooting

### Issue: State not persisting
**Check**:
- UserDefaults key is correct: `cached_journey_state`
- `saveToCache()` is called after state changes
- App has permission to write to UserDefaults

### Issue: Inference always returns .noAccountsConnected
**Check**:
- Cached data is actually loaded before inference
- `accounts`, `summary`, `budgetManager.budgets` have expected values
- Check logs for "Accounts: X" line in inference output

### Issue: Validation warnings even when state is correct
**Check**:
- Validation logic matches your understanding of state requirements
- Data actually matches the state (e.g., budgets exist for `.planCreated`)
- Race condition: data loaded after state set?

---

**Test Plan Created**: 2025-10-21
**Estimated Test Time**: 30 minutes
**Required**: Xcode, iOS Simulator, Backend server running

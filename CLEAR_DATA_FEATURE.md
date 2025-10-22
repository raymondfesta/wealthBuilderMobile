# Clear All Data Feature - Implementation Summary

## Overview
Added a "Clear All Data & Restart" function to the iOS app's Demo tab for testing purposes. This allows developers to completely reset the app to first-run state without manually clearing Keychain data.

## Problem Solved
Previously, deleting the app from the simulator and doing a clean build didn't fully reset the app because:
- **Keychain data persists across app deletions** (iOS security feature)
- Old access tokens remained in Keychain
- App would load those tokens and fetch cached data from backend
- No easy way to test "fresh install" experience

## Implementation Details

### Location
**File:** `/Users/rfesta/Desktop/wealth-app/FinancialAnalyzer/Views/ProactiveGuidanceDemoView.swift`

**Section:** "Developer Tools" section (Section 7)

### UI Components Added

1. **Button:**
   - Text: "Clear All Data & Restart"
   - Icon: trash.fill
   - Style: Bordered prominent with red tint
   - Positioned after "Reset Onboarding Experience" button

2. **Warning Text:**
   - Red colored caption explaining what will be deleted
   - Lists all affected data types

3. **Confirmation Alert:**
   - Title: "Clear All Data?"
   - Two buttons: "Cancel" (safe) and "Clear & Restart" (destructive)
   - Detailed message listing all data that will be deleted

### Function: `clearAllDataAndRestart()`

The function performs a complete data wipe in 5 steps:

#### Step 1: Clear Keychain
```swift
// Get all stored itemIds
let allKeys = try KeychainService.shared.allKeys()

// Delete each token
for key in allKeys {
    try KeychainService.shared.delete(for: key)
}
```

**What's cleared:**
- All Plaid access tokens stored with item IDs as keys
- Uses the secure KeychainService API

#### Step 2: Clear UserDefaults
```swift
let keysToRemove = [
    "cached_accounts",
    "cached_transactions",
    "cached_summary",
    "cached_budgets",
    "cached_goals",
    "hasSeenWelcome",
    "hasCompletedOnboarding"
]

for key in keysToRemove {
    UserDefaults.standard.removeObject(forKey: key)
}
UserDefaults.standard.synchronize()
```

**What's cleared:**
- Cached bank accounts
- Cached transactions (6 months)
- Financial summary calculations
- Budget data
- Goal data
- Onboarding state flags

#### Step 3: Reset ViewModel State
```swift
viewModel.accounts.removeAll()
viewModel.transactions.removeAll()
viewModel.budgetManager.budgets.removeAll()
viewModel.budgetManager.goals.removeAll()
viewModel.summary = nil
viewModel.currentAlert = nil
viewModel.isShowingGuidance = false
viewModel.error = nil
```

**What's cleared:**
- All in-memory account data
- All in-memory transaction data
- All budgets and goals from BudgetManager
- Current financial summary
- Any active alerts/guidance
- Error state

#### Step 4: Cancel Notifications
```swift
NotificationService.shared.cancelAllNotifications()
```

**What's cleared:**
- All pending push notifications
- Scheduled purchase alerts
- Savings opportunity alerts
- Goal milestone notifications

#### Step 5: Exit App
```swift
Task {
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    exit(0)
}
```

**What happens:**
- 0.5 second delay to ensure console logs are printed
- Force app termination with `exit(0)`
- User must manually relaunch the app
- On relaunch, app shows welcome screen (fresh state)

### Logging

Comprehensive console logging with emoji prefixes for easy debugging:

```
🗑️ [Reset] ===== STARTING COMPLETE DATA WIPE =====
🗑️ [Reset] Found 2 Keychain item(s) to delete
🗑️ [Reset] ✅ Deleted Keychain item: item_12345
🗑️ [Reset] ✅ Deleted Keychain item: item_67890
🗑️ [Reset] Keychain cleared (2 items removed)
🗑️ [Reset] Clearing UserDefaults cache...
🗑️ [Reset] ✅ Removed UserDefaults key: cached_accounts
...
🗑️ [Reset] UserDefaults cleared (7 keys removed)
🗑️ [Reset] Resetting ViewModel state...
🗑️ [Reset] ViewModel state cleared
🗑️ [Reset] Canceling all pending notifications...
🗑️ [Reset] All notifications canceled
✅ [Reset] ===== DATA WIPE COMPLETE =====
✅ [Reset] App will now exit. Please relaunch manually to see fresh state.
```

## User Flow

1. **Open Demo Tab**
   - Navigate to ProactiveGuidanceView (Demo tab)
   - Scroll to "Developer Tools" section

2. **Tap Clear Button**
   - Tap "Clear All Data & Restart" button
   - Red prominent button with trash icon

3. **Confirm Action**
   - Alert appears with detailed list of what will be deleted
   - Tap "Clear & Restart" to confirm
   - Or tap "Cancel" to abort

4. **Data Wipe Executes**
   - Function clears Keychain, UserDefaults, ViewModel state
   - Cancels notifications
   - Console logs show detailed progress

5. **App Exits**
   - App terminates after 0.5 seconds
   - User sees home screen

6. **Relaunch App**
   - User manually taps app icon
   - App shows welcome screen
   - App is in fresh first-run state

## Error Handling

- **Keychain errors:** Each key deletion is wrapped in try-catch. If a key fails to delete, logs warning but continues with other keys
- **Missing keys:** If Keychain is already empty, `allKeys()` returns empty array (no error)
- **UserDefaults:** `removeObject(forKey:)` is safe to call even if key doesn't exist
- **Notifications:** `cancelAllNotifications()` is safe to call with no pending notifications

## Testing Checklist

### Before Clear
- [ ] Connect bank account (should show in Dashboard)
- [ ] Verify transactions loaded
- [ ] Generate budgets from transactions
- [ ] Create a financial goal
- [ ] Schedule test notification
- [ ] Complete onboarding flow

### After Clear
- [ ] App exits automatically
- [ ] Relaunch app manually
- [ ] Welcome screen appears (onboarding)
- [ ] No accounts shown on Dashboard
- [ ] No transactions in history
- [ ] No budgets exist
- [ ] No goals exist
- [ ] No pending notifications
- [ ] Keychain is empty (check Debug View if available)

### Console Logs
- [ ] Look for `🗑️ [Reset]` logs
- [ ] Verify itemId count matches accounts
- [ ] Confirm 7 UserDefaults keys removed
- [ ] Check "DATA WIPE COMPLETE" message
- [ ] No errors in console

## Security Considerations

- **Secure deletion:** Uses KeychainService API which properly handles Keychain item deletion
- **No data recovery:** Once executed, data cannot be recovered (intentional for testing)
- **Confirmation required:** Alert prevents accidental data loss
- **Destructive action:** Red color scheme and explicit warning text
- **Testing only:** This feature is in the Demo tab, not exposed to production users

## Backend Impact

**No backend changes required.** The function only clears iOS-side data:
- Keychain tokens are removed locally
- Backend still retains `plaid_tokens.json` with access tokens
- If backend tokens exist, user can re-link accounts without re-authenticating with Plaid
- To fully reset backend, manually delete `backend/plaid_tokens.json`

## Known Limitations

1. **Manual relaunch required:** iOS doesn't allow programmatic app restart. User must tap app icon to relaunch.

2. **Backend tokens persist:** Access tokens remain in `backend/plaid_tokens.json`. To test completely fresh state:
   ```bash
   rm backend/plaid_tokens.json
   ```

3. **Plaid dashboard:** Linked accounts still show in Plaid dashboard. To remove:
   - Visit https://dashboard.plaid.com/link
   - Manually revoke connections

4. **No undo:** Once confirmed, data deletion is permanent. Use with caution.

## Integration with Existing Code

### Dependencies
- `KeychainService.shared` - For Keychain operations
- `NotificationService.shared` - For notification management
- `FinancialViewModel` - For state management
- Standard iOS APIs: `UserDefaults`, `exit()`

### No Breaking Changes
- Function is additive (doesn't modify existing code)
- Uses existing service APIs
- Follows established logging conventions
- Matches existing UI patterns in Demo tab

## Future Enhancements

Potential improvements for the future:

1. **Backend integration:** Add API endpoint to also clear backend tokens
2. **Selective clearing:** Allow clearing specific data types (e.g., just budgets, not accounts)
3. **Export before clear:** Save data snapshot before wiping
4. **Automatic relaunch:** Research iOS private APIs for programmatic restart (risky for App Store)
5. **Production mode:** Gate this feature behind debug build flag

## Related Files

- **ProactiveGuidanceDemoView.swift** - Main implementation (lines 1-290)
- **KeychainService.swift** - Keychain deletion API
- **FinancialViewModel.swift** - State properties being cleared
- **NotificationService.swift** - Notification cancellation
- **CLAUDE.md** - Project documentation (should document this feature)

## Documentation Updates Needed

Add to CLAUDE.md under "Common Development Workflows":

```markdown
### Testing Fresh Install State
1. Open Demo tab in app
2. Scroll to "Developer Tools" section
3. Tap "Clear All Data & Restart" (red button)
4. Confirm in alert dialog
5. Wait for app to exit
6. Manually relaunch app
7. App shows welcome screen (fresh state)
8. Optional: Delete `backend/plaid_tokens.json` for complete reset
```

## Conclusion

This feature provides a critical testing tool for developers working on the financial app. It solves the problem of persistent Keychain data across app deletions and enables rapid iteration on onboarding flows, first-run experiences, and fresh install scenarios.

The implementation is:
- **Safe:** Requires confirmation, comprehensive logging
- **Thorough:** Clears all 5 data storage locations
- **Maintainable:** Uses existing service APIs, well-documented
- **Developer-friendly:** Clear UI, detailed console logs, comprehensive error handling

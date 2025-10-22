# Quick Start: Clear All Data Feature

## 🎯 Purpose
Reset your iOS app to **first-run state** for testing. Solves the problem where Keychain data persists across app deletions.

## 📍 How to Use

### Step 1: Open Demo Tab
```
Launch app → Navigate to "Demo" tab (bottom navigation)
```

### Step 2: Scroll to Developer Tools
```
Scroll to bottom → Find "Developer Tools" section
```

### Step 3: Tap Clear Button
```
Tap the red "Clear All Data & Restart" button
```

### Step 4: Confirm Action
```
Read the warning → Tap "Clear & Restart" (or Cancel to abort)
```

### Step 5: Relaunch App
```
App will exit → Manually tap app icon → Welcome screen appears
```

## 🗑️ What Gets Deleted

| Storage Location | Data Cleared |
|-----------------|--------------|
| **Keychain** | All Plaid access tokens |
| **UserDefaults** | Cached accounts, transactions, budgets, goals, **allocation buckets** |
| **ViewModel** | In-memory financial data, budgets, goals, **allocation buckets** |
| **Notifications** | All pending alerts |
| **Onboarding** | Welcome screen flags |

## ✅ Expected Results

**Before Clear:**
- Dashboard shows connected accounts
- Transactions visible
- Budgets active
- Goals exist

**After Clear + Relaunch:**
- Welcome/onboarding screen appears
- Dashboard is empty (no accounts)
- No transactions or budgets
- Clean slate for testing

## 📝 Console Output Example

```
🗑️ [Reset] ===== STARTING COMPLETE DATA WIPE =====
🗑️ [Reset] Found 2 Keychain item(s) to delete
🗑️ [Reset] ✅ Deleted Keychain item: item_sandbox_12345
🗑️ [Reset] ✅ Deleted Keychain item: item_sandbox_67890
🗑️ [Reset] Keychain cleared (2 items removed)
🗑️ [Reset] Clearing UserDefaults cache...
🗑️ [Reset] ✅ Removed UserDefaults key: cached_accounts
🗑️ [Reset] ✅ Removed UserDefaults key: cached_transactions
🗑️ [Reset] ✅ Removed UserDefaults key: cached_summary
🗑️ [Reset] ✅ Removed UserDefaults key: cached_budgets
🗑️ [Reset] ✅ Removed UserDefaults key: cached_goals
🗑️ [Reset] ✅ Removed UserDefaults key: cached_allocation_buckets
🗑️ [Reset] ✅ Removed UserDefaults key: hasSeenWelcome
🗑️ [Reset] ✅ Removed UserDefaults key: hasCompletedOnboarding
🗑️ [Reset] UserDefaults cleared (8 keys removed)
🗑️ [Reset] Resetting ViewModel state...
🗑️ [Reset] ViewModel state cleared
🗑️ [Reset] Canceling all pending notifications...
🗑️ [Reset] All notifications canceled
✅ [Reset] ===== DATA WIPE COMPLETE =====
✅ [Reset] App will now exit. Please relaunch manually to see fresh state.
```

## ⚠️ Important Notes

### iOS Limitation
- **App cannot restart itself** (iOS security)
- You must manually tap the app icon to relaunch
- Wait 1-2 seconds after exit before relaunching

### Backend Tokens
- Backend `plaid_tokens.json` still contains access tokens
- For complete reset, also delete backend file:
  ```bash
  rm backend/plaid_tokens.json
  ```

### No Undo
- Data deletion is **permanent**
- Always confirm you want to clear before proceeding
- Use only for testing purposes

## 🔧 Troubleshooting

### Problem: App doesn't exit
**Solution:** Check console for errors. Manually force quit if needed.

### Problem: Data still appears after relaunch
**Possible causes:**
1. Backend tokens still exist → Delete `plaid_tokens.json`
2. Cache loaded before deletion → Try again
3. Different simulator/device → Each device has separate Keychain

### Problem: Console shows Keychain errors
**Common cause:** Keychain already empty (safe to ignore)

### Problem: Welcome screen doesn't appear
**Check:** Verify these UserDefaults keys were removed:
- `hasSeenWelcome` should be false/nil
- `hasCompletedOnboarding` should be false/nil

## 🚀 Common Testing Workflows

### Test Fresh Install
```
1. Clear All Data & Restart
2. Relaunch app
3. Verify welcome screen appears
4. Test onboarding flow
```

### Test Account Linking
```
1. Clear All Data & Restart
2. Relaunch app
3. Complete onboarding
4. Link bank account (Plaid)
5. Verify data loads correctly
```

### Test Budget Generation
```
1. Clear All Data & Restart
2. Relaunch app → Link account → Wait for transactions
3. Demo tab → Generate Budgets
4. Verify budgets calculated correctly
```

### Test Notifications
```
1. Clear All Data & Restart
2. Relaunch app → Enable notifications
3. Link account → Test notification scheduling
4. Verify no old notifications appear
```

## 📂 Related Files

- **Implementation:** `FinancialAnalyzer/Views/ProactiveGuidanceDemoView.swift`
- **Keychain Service:** `FinancialAnalyzer/Utilities/KeychainService.swift`
- **ViewModel:** `FinancialAnalyzer/ViewModels/FinancialViewModel.swift`
- **Documentation:** `CLEAR_DATA_FEATURE.md` (comprehensive details)

## 💡 Pro Tips

1. **Check logs before relaunch** to verify all data was cleared
2. **Wait a second** after app exits before relaunching
3. **Use simulator menu** (Device → Erase All Content) for even deeper reset
4. **Keep backend running** so app can connect after fresh start
5. **Screenshot console output** if you encounter issues

## ❓ Questions?

- Why does app exit instead of restart? → iOS doesn't allow programmatic restart
- Is backend data deleted? → No, only iOS-side data
- Can I undo this? → No, deletion is permanent
- Is this safe for production? → No, testing only (in Demo tab)
- What if I only want to clear budgets? → Use individual reset buttons in Quick Actions section

---

**Last Updated:** October 21, 2025 (Fixed: Now clears allocation buckets)
**iOS Version:** 17.0+
**Feature Location:** Demo Tab → Developer Tools

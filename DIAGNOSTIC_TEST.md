# Diagnostic Test - Find the Exact Issue

## What I've Added

1. ✅ Better error handling (won't delete tokens on transaction fetch failures)
2. ✅ Detailed cache save logging (shows itemId status for each account)
3. ✅ Detailed cache load logging (shows decode success/failure)
4. ✅ Transaction fetch logging

## Critical Test to Run

### Step 1: Delete App & Start Fresh
1. Delete the app from simulator/device
2. In Xcode, click Product → Clean Build Folder (Shift+Cmd+K)
3. Build and run (Cmd+R)

### Step 2: Link Account & Watch Console
1. Link a bank account (user_good / pass_good)
2. **Copy the ENTIRE console output** and send it to me

**Look for these specific patterns:**

```
// Initial data fetch
🔄 [Data Refresh] Fetching accounts for itemId: item-xyz...
🔄 [Data Refresh] Fetched X account(s) for itemId: item-xyz
✅ [Data Refresh] Account 'Plaid Checking' correctly has itemId: 'item-xyz'

// Transaction fetch
🔄 [Data Refresh] Fetching transactions for itemId: item-xyz...
🔄 [Data Refresh] Fetched X transaction(s) for itemId: item-xyz

// Cache save
💾 [Cache Save] Starting cache save...
💾 [Cache Save] Accounts to save: 3
💾 [Cache Save] Transactions to save: 150
💾 [Cache Save] ✅ Saving account 'Plaid Checking' with itemId: item-xyz
```

### Step 3: Force Quit & Restart
1. **Force quit the app** (swipe up in app switcher)
2. **Relaunch the app**
3. **Copy the console output** starting from app launch

**Look for:**
```
// Cache load
💾 [Cache Load] Starting cache load...
💾 [Cache Load] Found cached accounts data (X bytes)
💾 [Cache Load] ✅ Decoded 3 account(s) from cache
💾 [Cache Load] Found cached transactions data (X bytes)
💾 [Cache Load] ✅ Decoded 150 transaction(s) from cache

// ItemId validation
🔍 [ItemId Validation] Checking 3 cached accounts against 1 stored itemIds
✅ [ItemId Validation] Account 'Plaid Checking' has itemId: item-xyz
```

### Step 4: What Does "Refresh" Mean?

**Please clarify**: When you say "when the app refreshes all data is lost", do you mean:

A. **Pull-to-refresh** gesture in the app UI?
B. **Force quit and relaunch** the app?
C. **The data automatically disappears** after a few seconds?
D. Something else?

## Key Things I Need to See

From the console output, I need to know:

1. **Are transactions being fetched?**
   - Look for: `🔄 [Data Refresh] Fetched X transaction(s)`
   - If you see 0 transactions, that's the issue
   - If you see an error instead, that's important

2. **Are transactions being saved to cache?**
   - Look for: `💾 [Cache Save] Transactions to save: X`
   - Should be > 0 if transactions were fetched

3. **Are itemIds being saved correctly?**
   - Look for: `💾 [Cache Save] ✅ Saving account 'Name' with itemId: item-xyz`
   - Should NOT see: `⚠️ Saving account 'Name' with EMPTY itemId!`

4. **Does cache load work?**
   - Look for: `💾 [Cache Load] ✅ Decoded X account(s) from cache`
   - Should see accounts AND transactions loaded

5. **Are itemIds preserved in cache?**
   - Look for: `✅ [ItemId Validation] Account 'Name' has itemId: item-xyz`
   - Should NOT see: `❌ Account 'Name' has EMPTY itemId`

## Possible Issues

Based on what you described, here are the likely culprits:

### Issue 1: Transactions Not Fetching
**Symptom**: Accounts show, dashboard shows, but Transactions tab is empty

**Cause**: Plaid sandbox might not return transactions for some test accounts

**Check console for**:
```
❌ [Data Refresh] Failed to fetch data for itemId...
```

**Fix**: Try a different test bank or check if transactions endpoint returns empty array

### Issue 2: Transactions Not Being Saved
**Symptom**: Transactions fetch but disappear after restart

**Check console for**:
```
💾 [Cache Save] Transactions to save: 0  // ❌ Should be > 0
```

### Issue 3: ItemId Lost in Cache
**Symptom**: Everything works initially but disappears on restart

**Check console for**:
```
💾 [Cache Save] ⚠️ Saving account 'Name' with EMPTY itemId!  // ❌ Bad
```

or after restart:
```
❌ [ItemId Validation] Account 'Name' has EMPTY itemId  // ❌ Bad
```

### Issue 4: Aggressive Error Handling
**Symptom**: Data disappears immediately after initial load

**Check console for**:
```
⚠️ [Data Refresh] Cleaning up orphaned itemId: item-xyz  // ❌ Shouldn't happen on fresh link
```

This would mean an error occurred and the old code deleted the token.

---

## What to Send Me

Please run the diagnostic test above and send me:

1. **Console output from Step 2** (linking account) - full output
2. **Console output from Step 3** (restart app) - full output
3. **Answer to Step 4** - what does "refresh" mean exactly?
4. **Screenshots** if helpful:
   - Dashboard showing account data
   - Transactions tab (empty or showing data?)
   - After "refresh" (showing empty state?)

With this information, I can pinpoint the exact issue.

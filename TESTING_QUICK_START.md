# Testing Quick Start — Wealth App

**Date:** 2026-02-13
**Status:** ✅ Feature Complete, Ready for Testing
**Backend:** Running on localhost:3000 (PID: 74065)

---

## 🚀 Start Testing Now (5 Minutes)

### 1. Verify Backend
```bash
curl http://localhost:3000/health
```
**Expected:** `{"status":"ok","timestamp":"..."}`

### 2. Open in Xcode
```bash
open FinancialAnalyzer.xcodeproj
```

### 3. Build & Run
- Select any iOS Simulator (iPhone 15 recommended)
- Press **Cmd+R**
- App should launch to login screen

### 4. Test Onboarding Flow

**Register Account:**
- Email: `test@example.com`
- Password: `test1234`
- Display Name: `Test User`

**Connect Bank:**
- Click "Connect Your First Account"
- Plaid Link opens (instant <1s)
- Username: `user_good`
- Password: `pass_good`
- MFA Code: `1234`
- Wait 10-15 seconds for categories

**Analyze Transactions:**
- Click "Analyze My Finances"
- Review snapshot (income, expenses, balances)
- Click "Create My Plan"

**Build Allocation Plan:**
- Select preset (Recommended suggested)
- Adjust percentages if desired
- Link accounts to buckets
- Save plan

**View My Plan:**
- See 4 bucket cards (Essential, Discretionary, Emergency, Investments)
- Real spending from transactions
- Balances from linked accounts
- Cycle progress header

---

## 📋 Full Testing Checklist

### Authentication
- [ ] Register new account (email/password)
- [ ] Logout
- [ ] Login with same credentials
- [ ] Profile view loads correctly
- [ ] Data persists after logout/login

### Bank Connection
- [ ] Connect first account via Plaid
- [ ] Add second account (+ button)
- [ ] View accounts list
- [ ] Remove account
- [ ] Re-add account

### Transaction Management
- [ ] Transactions sync from Plaid
- [ ] Categories assigned correctly
- [ ] Pull-to-refresh updates data
- [ ] Transaction detail view
- [ ] Search/filter transactions

### Financial Analysis
- [ ] Monthly flow calculated correctly
- [ ] Expense breakdown shows 8 categories
- [ ] Essential vs discretionary split accurate
- [ ] Debt accounts detected (if present)
- [ ] Emergency fund coverage calculated

### Allocation System
- [ ] Low/Recommended/High presets work
- [ ] Custom allocation editing
- [ ] Auto-rebalancing on slider change
- [ ] Toast notifications appear
- [ ] Account linking suggestions
- [ ] Plan saves successfully

### My Plan View
- [ ] 4 bucket cards display correctly
- [ ] Essential spending from real transactions
- [ ] Discretionary spending from real transactions
- [ ] Emergency Fund balance from linked account
- [ ] Investments balance from linked account
- [ ] Cycle progress header accurate
- [ ] Health indicator (on track / needs attention)
- [ ] Detail sheets open on tap

### Schedule Tab
- [ ] Paycheck schedule setup
- [ ] Allocation reminders configured
- [ ] Upcoming allocations list
- [ ] History view (after execution)
- [ ] Empty state shows correctly

### Error Handling
- [ ] Offline banner appears when backend stopped
- [ ] Error alerts user-friendly
- [ ] Graceful fallbacks for failed operations
- [ ] Pull-to-refresh recovers from errors

### Loading States
- [ ] Cache-first instant loading (returning users)
- [ ] Silent background refresh
- [ ] Loading overlay shows step indicators
- [ ] No UI blocking on data updates

### Data Reset (Testing)
- [ ] Xcode scheme has `-ResetDataOnLaunch` enabled
- [ ] Data clears on every build+run
- [ ] Keychain, UserDefaults, notifications cleared
- [ ] Backend tokens removed

---

## 🐛 Known Issues (Non-Blocking)

### Warnings Only (No Errors)
- AccentColor asset catalog warning (cosmetic)
- Sendable warnings in PlaidService (external SDK)
- Unreachable catch blocks (defensive code)
- Unused variable in AccountLinkingService

### External Dependencies
- **Backend must be running** - If app shows "Could not connect", start backend:
  ```bash
  cd backend && npm start
  ```

---

## 📊 Test Data

### Plaid Sandbox Users

**Basic Test:**
- Username: `user_good`
- Password: `pass_good`
- MFA Code: `1234`
- Accounts: 3 (checking, savings, credit card)
- Transactions: ~50

**Stress Test:**
- Username: `user_custom`
- Password: `[paste plaid_custom_user_config.json]`
- MFA Code: `1234`
- Accounts: 10 (diverse types)
- Transactions: ~230

**Config File:** `backend/plaid_custom_user_config.json`

---

## 🔍 What to Look For

### Good Signs ✅
- Instant loading for returning users (<1s)
- Smooth animations and transitions
- Real transaction data in My Plan cards
- Account balances match Plaid sandbox data
- Error messages user-friendly
- Offline mode graceful

### Red Flags 🔴
- Loading spinner stuck forever
- Crash on any user action
- Data not persisting after logout/login
- Transaction categories all "uncategorized"
- Account balances zero when they shouldn't be
- Error messages technical jargon

---

## 🚨 Troubleshooting

### "Could not connect to server"
**Fix:**
```bash
cd backend
npm start
# Wait for "Server ready to accept requests"
```

### "Invalid credentials" from Plaid
**Fix:** Backend environment variables wrong
```bash
cd backend
cat .env | grep PLAID
# Verify PLAID_ENV=sandbox
# Verify PLAID_SECRET matches sandbox
```

### Accounts show but no transactions
**Wait:** 10-15 seconds after connection for Plaid sync
**Then:** Pull-to-refresh

### Build fails
**Check:** Backend URL in AppConfig.swift
```swift
// Should be:
private static let environment: Environment = .localhost
```

---

## 📈 Success Criteria

### Must Pass
- [ ] Complete onboarding flow without crashes
- [ ] Transactions load and categorize correctly
- [ ] Allocation plan saves and persists
- [ ] My Plan cards show real data
- [ ] Logout/login preserves data
- [ ] Error handling works

### Nice to Have
- [ ] Loading feels instant (<1s)
- [ ] Animations smooth
- [ ] UI polished and consistent
- [ ] Empty states helpful
- [ ] Offline mode graceful

---

## 📚 Documentation

**Full Analysis:** `STATUS_EVALUATION.md` (500+ lines)
**Session Log:** `BUILD-LOG.md` (Session 4)
**Deployment:** `RAILWAY_DEPLOYMENT.md`
**Troubleshooting:** `CONNECTION_FIX.md`

---

## 🎯 Next Steps After Testing

### If Tests Pass
1. **Deploy to Railway** (`RAILWAY_DEPLOYMENT.md`)
2. **Test on iPhone** (physical device via USB)
3. **Configure Sign in with Apple** (Apple Developer portal)

### If Issues Found
1. Document specific bugs in new BUGS.md
2. Include steps to reproduce
3. Builder will fix in next session

---

**Questions?** Check `STATUS_EVALUATION.md` or `BUILD-LOG.md`

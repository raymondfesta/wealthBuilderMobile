# 🚀 Local Testing Ready

**Status:** Backend server running, iOS app configured, ready to test in simulator

---

## Quick Start

### 1. Verify Setup (Optional)
```bash
./verify-local-setup.sh
```

### 2. Launch in Xcode
```bash
# Or just: Cmd+R in Xcode
open FinancialAnalyzer.xcodeproj
```

### 3. Test Flow
1. Register new user (or login)
2. Connect bank with Plaid:
   - Username: `user_good`
   - Password: `pass_good`
   - MFA Code: `1234`
3. Test all features

---

## System Status

### ✅ Backend Server
- **Running:** http://localhost:3000
- **Environment:** sandbox (Plaid)
- **Database:** SQLite initialized
- **Process:** Running in background (npm start)

**Verified Endpoints:**
- Health: `/health` ✅
- Plaid Link Token: `/api/plaid/create_link_token` ✅
- Auth Registration: `/auth/register` ✅
- Auth Login: `/auth/login` ✅

### ✅ iOS App
- **Configuration:** AppConfig.swift set to `.localhost`
- **Build Status:** Clean build, zero errors
- **Target:** iOS Simulator
- **Connected to:** http://localhost:3000

---

## Server Management

### Check Server Status
```bash
# Check if running
lsof -ti:3000

# View health
curl http://localhost:3000/health
```

### Stop Server
```bash
# Find process
lsof -ti:3000

# Kill process
kill $(lsof -ti:3000)
```

### Restart Server
```bash
cd backend
npm start
```

### View Server Logs
Server logs appear in the terminal where you ran `npm start`

---

## Testing Guide

### Recommended Test Flow

1. **Initial Setup**
   - Launch app in simulator
   - Register new user or login
   - Verify login persistence

2. **Bank Connection**
   - Tap "Connect Bank"
   - Use Plaid sandbox credentials (above)
   - Complete MFA challenge
   - Verify accounts appear

3. **Transaction Analysis**
   - Wait for initial sync (~10-15 seconds)
   - Pull to refresh
   - Verify transactions appear
   - Check categorization (Essential vs Discretionary)

4. **My Plan View**
   - Verify 4 bucket cards display
   - Check spending calculations
   - Verify savings balances
   - Test cycle progress

5. **Allocation Planner**
   - Create new allocation plan
   - Test Low/Rec/High presets
   - Verify rebalancing logic
   - Check account linking

6. **Schedule & Execution**
   - Review allocation schedule
   - Test paycheck detection
   - Verify notification triggers
   - Check execution history

7. **AI Guidance**
   - Trigger AI insights
   - Verify recommendations
   - Test different scenarios

### Plaid Sandbox Options

**Basic Testing (recommended):**
- Username: `user_good`
- Password: `pass_good`
- MFA: `1234`
- Provides: Standard accounts and transactions

**Stress Testing (optional):**
- Username: `user_custom`
- Password: [paste plaid_custom_user_config.json contents]
- Provides: 10 accounts, ~230 transactions

---

## Troubleshooting

### Server Not Responding

**Symptom:** App shows connection errors

**Solution:**
```bash
# Check if server running
lsof -ti:3000

# If not running, start it
cd backend && npm start
```

### Plaid Connection Fails

**Symptom:** "Failed to create link token" error

**Possible Causes:**
1. Backend not running → Check health endpoint
2. Wrong credentials → Verify .env has correct PLAID_SECRET
3. Network issue → Check localhost connectivity

**Debug:**
```bash
# Test link token creation
curl -X POST http://localhost:3000/api/plaid/create_link_token
```

### Transactions Not Loading

**Symptom:** Accounts connected but no transactions

**Solution:**
1. Wait 10-15 seconds for Plaid sync
2. Pull to refresh
3. Check server logs for errors

### Build Errors

**Symptom:** Xcode build fails

**Solution:**
```bash
# Clean build folder
Cmd+Shift+K

# Rebuild
Cmd+B
```

### App Configuration Issues

**Symptom:** 404 errors or wrong server

**Solution:**
Verify AppConfig.swift:
```swift
private static let environment: Environment = .localhost
```

---

## Configuration Files

### Backend (.env)
Location: `backend/.env`

Critical variables:
- `PLAID_CLIENT_ID`: Your Plaid client ID
- `PLAID_SECRET`: Sandbox secret
- `PLAID_ENV`: sandbox
- `OPENAI_API_KEY`: For AI features
- `JWT_SECRET`: Auth token encryption

### iOS (AppConfig.swift)
Location: `FinancialAnalyzer/Utilities/AppConfig.swift`

Current setting:
```swift
private static let environment: Environment = .localhost
```

Available environments:
- `.localhost` - Simulator (http://localhost:3000)
- `.local` - Physical device on same wifi
- `.development` - Railway deployment

---

## Next Steps

### For Immediate Testing
1. Run `./verify-local-setup.sh` to confirm all systems ready
2. Launch app in Xcode (Cmd+R)
3. Test full user flow
4. Report any issues or bugs

### For Device Testing (Later)
1. Get your Mac's IP: `ipconfig getifaddr en0`
2. Update AppConfig.swift environment to `.local`
3. Update local IP in AppConfig.swift
4. Build to physical device

### For Production Deploy (Later)
1. Follow `RAILWAY_DEPLOYMENT.md`
2. Deploy backend to Railway
3. Update AppConfig.swift to `.development`
4. Update Railway URL in AppConfig.swift

---

## Support Files

- `verify-local-setup.sh` - Automated verification
- `BUILD-LOG.md` - Session details and status
- `DIRECTION.md` - Current priorities
- `RAILWAY_DEPLOYMENT.md` - Production deploy guide
- `CLAUDE.md` - Project documentation

---

**Last Updated:** 2026-02-07 by Builder Agent
**Server PID:** Check with `lsof -ti:3000`
**Commits:** 3 commits pushed to master

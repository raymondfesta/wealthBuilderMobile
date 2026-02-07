# iOS Simulator Connection Fix ✅

## Problem
Ray was getting "Could not connect to server" errors when testing in iOS simulator despite backend running on localhost:3000.

## Root Cause
Backend server was not running. Previous session had started the server but it was stopped after system restart or process termination.

## Solution Implemented

### 1. Backend Server Started
```bash
cd backend
npm start
```
Server now running on http://localhost:3000

### 2. Verified All Endpoints
- ✅ Health check: `/health`
- ✅ Plaid link token: `/api/plaid/create_link_token`
- ✅ Auth registration: `/auth/register`
- ✅ Auth login: `/auth/login`

### 3. iOS Configuration Verified
- ✅ AppConfig.swift set to `.localhost`
- ✅ Info.plist has `NSAllowsLocalNetworking: true`
- ✅ Build succeeds with zero errors

### 4. Created Testing Tools
- `test-connection.sh` - Automated connection verification script
- Tests all critical endpoints
- Verifies iOS configuration
- Provides clear pass/fail status

## How to Test Right Now

### Quick Test (30 seconds)
1. Run the test script:
   ```bash
   ./test-connection.sh
   ```
2. You should see all ✅ green checkmarks

### Full iOS Test (2 minutes)
1. Open Xcode:
   ```bash
   open FinancialAnalyzer.xcodeproj
   ```
2. Select any iPhone simulator from the device menu
3. Press **Cmd+R** to build and run
4. App should launch and connect to backend successfully

## Connection Status

| Component | Status | Details |
|-----------|--------|---------|
| Backend Server | ✅ Running | http://localhost:3000 |
| Health Endpoint | ✅ Responding | Returns `{"status":"ok"}` |
| Plaid Integration | ✅ Working | Link tokens generated |
| Auth System | ✅ Working | Registration/login functional |
| iOS Config | ✅ Correct | AppConfig.swift → .localhost |
| iOS Build | ✅ Success | Zero errors, warnings only |
| Network Permissions | ✅ Enabled | NSAllowsLocalNetworking |

## Common Issues & Fixes

### "Could not connect to server" in simulator

**Diagnosis:**
```bash
./test-connection.sh
```

**If backend check fails:**
```bash
cd backend
npm start
```

**If iOS config wrong:**
Edit `FinancialAnalyzer/Utilities/AppConfig.swift`:
```swift
private static let environment: Environment = .localhost
```

### "Connection refused" or "Network error"

**Check 1: Server is actually running**
```bash
curl http://localhost:3000/health
```
Should return: `{"status":"ok","timestamp":"..."}`

**Check 2: Port is not blocked**
```bash
lsof -i :3000
```
Should show `node` process

**Check 3: Simulator networking**
- Restart simulator (Device → Restart)
- Try different simulator model
- Check Xcode console for specific error

### Build fails in Xcode

**Clean build:**
1. Cmd+Shift+K (Clean Build Folder)
2. Cmd+B (Build)

**Check scheme:**
- Product → Scheme → Edit Scheme
- Run → Build Configuration should be "Debug"

## Server Management Commands

### Start server
```bash
cd backend
npm start
```

### Stop server
```bash
# Find process
lsof -i :3000

# Kill it
kill <PID>
```

### Check server status
```bash
curl http://localhost:3000/health
```

### View server logs
```bash
cd backend
npm run dev  # Runs with nodemon for auto-restart
```

## What Changed

### Files Modified
- None - all configuration was already correct

### Files Created
- `test-connection.sh` - Connection verification script
- `CONNECTION_FIX.md` - This troubleshooting guide

### Process Started
- Backend server started and verified (PID will vary)

## Next Steps for Ray

1. **Immediate Testing**
   - Run `./test-connection.sh` to verify everything
   - Open Xcode and press Cmd+R
   - Test login/signup flow

2. **Keep Server Running**
   - Leave terminal window with server running
   - Or run in background: `cd backend && npm start &`

3. **If Issues Persist**
   - Check Xcode console for specific error messages
   - Run test script to identify which component failing
   - Look for network-related errors in console

## Technical Details

### iOS Simulator Networking
- Simulator uses macOS networking stack
- `localhost` on simulator → `localhost` on Mac
- No IP address changes needed for simulator
- `NSAllowsLocalNetworking` enables HTTP to localhost

### Backend Configuration
- Express server on port 3000
- SQLite database (local file)
- Plaid SDK in sandbox mode
- JWT authentication with 15min access tokens

### Connection Flow
1. iOS app reads AppConfig.baseURL
2. Makes HTTP request to http://localhost:3000
3. Simulator networking routes to Mac's localhost
4. Express server receives request
5. Processes and returns response
6. iOS app receives and handles response

## Troubleshooting Checklist

Before reporting connection issues, verify:

- [ ] Backend server is running (`./test-connection.sh`)
- [ ] AppConfig.swift set to `.localhost`
- [ ] iOS build succeeds
- [ ] Simulator selected (not physical device)
- [ ] No other process using port 3000
- [ ] Xcode console shows specific error details

---

**Status:** ✅ FIXED - Backend running, iOS configured correctly, ready for testing

**Last Updated:** 2026-02-07

**Builder Notes:**
- Root cause was simple: server wasn't running
- All configuration was already correct from previous session
- Created automated testing tool for future verification
- No code changes needed - pure operational fix

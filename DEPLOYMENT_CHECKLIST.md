# Deployment Checklist - Railway + iOS Device Testing

## Pre-Deployment

### Backend Preparation
- [x] Health endpoint exists (`/health`)
- [x] Railway configuration created (`railway.json`)
- [x] Environment variables documented (`.env.example`)
- [x] Database migrations run on startup (automatic)
- [x] CORS configured for cross-origin requests
- [ ] Generate production JWT_SECRET and ENCRYPTION_KEY

### iOS App Preparation
- [x] AppConfig.swift supports environment switching
- [x] HTTPS support configured
- [ ] Update Railway URL in AppConfig after deployment
- [ ] Test build on physical device

## Railway Deployment Steps

### 1. Push Code to GitHub
```bash
cd /Users/rfesta/Desktop/wealth-app
git add .
git commit -m "feat: Railway deployment configuration"
git push origin master
```

### 2. Create Railway Project
1. Go to https://railway.app/new
2. Select "Deploy from GitHub repo"
3. Authorize Railway
4. Select `wealth-app` repository
5. **Important**: Set Root Directory to `backend` in Settings

### 3. Configure Environment Variables

Go to Railway project → Variables tab and add:

```bash
PLAID_CLIENT_ID=<copy from current .env>
PLAID_SECRET_SANDBOX=<copy from current .env>
PLAID_SECRET_PRODUCTION=<copy from current .env>
PLAID_SECRET=<copy from current .env>
PLAID_ENV=sandbox
OPENAI_API_KEY=<copy from current .env>
PORT=3000
NODE_ENV=production
APPLE_BUNDLE_ID=com.financialanalyzer.app
JWT_ACCESS_EXPIRY=15m
```

**Generate NEW production secrets** (don't reuse dev secrets):
```bash
# JWT Secret (64 bytes)
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"

# Encryption Key (32 bytes)
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Add the generated values:
```
JWT_SECRET=<generated_64_byte_hex>
ENCRYPTION_KEY=<generated_32_byte_hex>
```

### 4. Deploy

Railway auto-deploys from GitHub. Monitor deployment:
1. Check Logs tab for build progress
2. Wait for "Deployment successful" message
3. Note any errors and fix before proceeding

### 5. Generate Domain

1. Settings → Generate Domain
2. Railway provides: `your-app-name.up.railway.app`
3. **Copy this URL** - you'll need it for iOS configuration

### 6. Verify Deployment

```bash
# Test health endpoint
curl https://your-app-name.up.railway.app/health

# Expected: {"status":"ok","timestamp":"..."}

# Test Plaid link token creation (no auth required)
curl -X POST https://your-app-name.up.railway.app/api/plaid/create_link_token \
  -H "Content-Type: application/json"

# Expected: {"link_token":"link-sandbox-...","expiration":"..."}
```

## iOS Configuration

### 1. Update AppConfig.swift

Edit `FinancialAnalyzer/Utilities/AppConfig.swift`:

```swift
private static let environment: Environment = .development

// ...

case .development:
    // Replace with your Railway URL
    return "https://your-app-name.up.railway.app"
```

### 2. Update Info.plist (Production Security)

For device testing, you can keep NSAllowsArbitraryLoads temporarily.
For TestFlight/App Store, you MUST remove it:

**Production-ready Info.plist:**
- Remove `NSAllowsArbitraryLoads` key entirely
- Remove `NSAllowsLocalNetworking` key
- Railway uses HTTPS by default (no exceptions needed)

### 3. Build for Physical Device

1. Connect iPhone via USB
2. Open `FinancialAnalyzer.xcodeproj` in Xcode
3. Select your device in toolbar
4. Trust developer cert on device (Settings → General → VPN & Device Management)
5. Cmd+R to build and run

## Testing on Device

### Complete User Flow Test

1. **Launch app on device**
   - Should not show network errors
   - Login screen loads

2. **Register new account**
   - Use test email: `test@example.com`
   - Password: `Test123!`
   - Should receive JWT tokens

3. **Connect bank account**
   - Tap "Connect Your First Account"
   - Plaid Link should open
   - Use sandbox credentials:
     ```
     Username: user_good
     Password: pass_good
     ```
   - Select "Plaid Checking" + "Plaid Savings"

4. **Complete onboarding**
   - Tap "Analyze Finances"
   - Wait 10-15 seconds for Plaid sync
   - Review financial snapshot
   - Verify transactions loaded
   - Create allocation plan

5. **Navigate My Plan view**
   - Verify 4 bucket cards display
   - Check spending calculations
   - Pull-to-refresh works

6. **Test Schedule tab**
   - Set up paycheck schedule
   - Verify upcoming allocations

7. **Logout and login**
   - Verify data persists
   - Accounts reload correctly

### Verification Checklist

- [ ] App connects to Railway backend
- [ ] User registration works
- [ ] Plaid connection succeeds
- [ ] Transactions sync and display
- [ ] Allocation plan creates successfully
- [ ] My Plan cards show correct data
- [ ] Logout/login preserves state
- [ ] No network timeouts
- [ ] No SSL/certificate errors

## Rollback Plan

If deployment fails or iOS app can't connect:

### Option A: Keep Local Development
1. In AppConfig.swift, set `environment = .local`
2. Ensure Mac and iPhone on same wifi
3. Update IP address in AppConfig if needed
4. Rebuild and run

### Option B: Fix Railway Deployment
1. Check Railway logs for errors
2. Verify environment variables set correctly
3. Verify Root Directory = `backend`
4. Redeploy from Railway dashboard

## Post-Deployment

### Monitor Railway

1. **Check Metrics**
   - CPU usage (should be <50% idle)
   - Memory usage (should be <200MB)
   - Response times (<500ms)

2. **Review Logs**
   - Watch for errors
   - Check Plaid API calls
   - Monitor database operations

3. **Set Up Alerts**
   - Railway → Settings → Notifications
   - Enable deployment failure alerts
   - Enable crash alerts

### Document Deployment

Update BUILD-LOG.md with:
- Railway deployment URL
- Deployment date/time
- Any issues encountered
- iOS device test results

### Next Steps

After successful device testing:
1. Switch PLAID_ENV to `development` for real bank testing
2. Test with real bank accounts (not sandbox)
3. Prepare for TestFlight beta distribution
4. Plan App Store submission

## Troubleshooting

### "Could not connect to server"
- Verify Railway deployment is running (green status)
- Check Railway logs for crashes
- Test health endpoint directly with curl
- Verify AppConfig URL matches Railway domain

### "SSL certificate error"
- Railway provides valid SSL by default
- Check device date/time is correct
- Update iOS to latest version

### "Invalid credentials" from Plaid
- Verify PLAID_SECRET matches PLAID_ENV
- Sandbox requires PLAID_SECRET_SANDBOX
- Check Plaid dashboard for API status

### Database errors in logs
- Railway auto-creates persistent volume
- Check write permissions
- Verify database migrations ran (startup logs)

### Out of Railway credits
- Free tier: $5/month
- Upgrade to Pro if needed
- Monitor usage in Railway dashboard

## Success Criteria

✅ Railway backend deployed and accessible
✅ iOS app connects successfully
✅ Complete user flow works on device
✅ No critical errors in Railway logs
✅ Database persists across deployments
✅ Ready for Ray's testing

---

**Current Status:** Ready for deployment. All code prepared.

**Estimated Time:** 30-45 minutes for full deployment and testing.

**Next Action:** Push code to GitHub and create Railway project.

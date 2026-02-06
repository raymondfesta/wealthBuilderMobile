# Deploy Backend to Railway - Quick Start

**Time Required:** 30 minutes
**Cost:** Free (Railway $5/month credit)

## Step 1: Create Railway Project (5 min)

1. Go to https://railway.app/new
2. Click "Deploy from GitHub repo"
3. Sign in with GitHub (authorize Railway)
4. Select `wealthBuilderMobile` repository
5. Wait for project creation

## Step 2: Configure Project (2 min)

1. In Railway dashboard → **Settings**
2. Set **Root Directory** = `backend`
3. Click **Generate Domain** (save this URL, you'll need it)
4. Copy your Railway URL: `https://your-app-name.up.railway.app`

## Step 3: Set Environment Variables (10 min)

Railway dashboard → **Variables** tab

### Copy from your local `.env` file:

```bash
# Open terminal, run:
cd /Users/rfesta/Desktop/wealth-app/backend
cat .env
```

Copy these values to Railway (paste exactly as they are):

```
PLAID_CLIENT_ID=<copy from .env>
PLAID_SECRET_SANDBOX=<copy from .env>
PLAID_SECRET_PRODUCTION=<copy from .env>
PLAID_SECRET=<copy from .env>
PLAID_ENV=sandbox
OPENAI_API_KEY=<copy from .env>
APPLE_BUNDLE_ID=com.financialanalyzer.app
```

### Generate NEW production secrets:

```bash
# Run these commands in terminal:
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Add to Railway:
```
JWT_SECRET=<paste first generated value>
ENCRYPTION_KEY=<paste second generated value>
```

Add these static values:
```
PORT=3000
NODE_ENV=production
JWT_ACCESS_EXPIRY=15m
```

## Step 4: Deploy (3 min)

1. Railway auto-deploys from GitHub
2. Watch **Logs** tab for "Running on http://localhost:3000"
3. Wait for "Deployment successful" message

## Step 5: Test Backend (2 min)

```bash
# Replace with YOUR Railway URL:
curl https://your-app-name.up.railway.app/health
```

**Expected response:**
```json
{"status":"ok","timestamp":"2026-02-06T..."}
```

✅ If you see this, backend is working!

## Step 6: Update iOS App (3 min)

1. Open Xcode
2. Edit `FinancialAnalyzer/Utilities/AppConfig.swift`
3. Change line 8:
   ```swift
   private static let environment: Environment = .development
   ```
4. Change line 30 (replace with YOUR Railway URL):
   ```swift
   return "https://your-app-name.up.railway.app"
   ```
5. Save file

## Step 7: Test on iPhone (15 min)

1. Connect iPhone via USB
2. Select device in Xcode toolbar
3. Cmd+R (build and run)
4. On iPhone:
   - Register account: `test@example.com` / `Test123!`
   - Connect bank (Plaid sandbox):
     - Username: `user_good`
     - Password: `pass_good`
   - Complete onboarding
   - Verify My Plan loads

✅ **Success!** App is running on Railway backend.

## Troubleshooting

### "Could not connect to server"
1. Verify Railway deployment is green (running)
2. Check Railway Logs tab for errors
3. Test health endpoint again with curl

### "Invalid credentials" from Plaid
1. In Railway Variables, check `PLAID_SECRET` matches `PLAID_ENV`
2. For `sandbox`, use `PLAID_SECRET_SANDBOX` value

### Build errors in Xcode
1. Verify AppConfig.swift URL is https:// (not http://)
2. Clean build: Cmd+Shift+K, then Cmd+B

## Next Steps

After successful testing:
1. Update BUILD-LOG.md with your Railway URL
2. Test logout/login to verify persistence
3. Monitor Railway dashboard for metrics
4. Ready for extended testing

## Questions?

See detailed guides:
- `RAILWAY_DEPLOYMENT.md` - Full deployment guide
- `DEPLOYMENT_CHECKLIST.md` - Complete checklist

---

**Railway Free Tier:** $5 credit/month (plenty for testing)
**Upgrade if needed:** $20/month Pro plan

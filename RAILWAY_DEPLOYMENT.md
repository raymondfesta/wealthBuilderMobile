# Railway Deployment Guide

## Prerequisites

1. Railway account: https://railway.app/
2. Railway CLI (optional): `npm install -g @railway/cli`
3. GitHub repository connected (or manual deployment)

## Deployment Steps

### Option A: GitHub Integration (Recommended)

1. **Push code to GitHub**
   ```bash
   git add .
   git commit -m "feat: Railway deployment configuration"
   git push origin master
   ```

2. **Create Railway Project**
   - Go to https://railway.app/new
   - Select "Deploy from GitHub repo"
   - Authorize Railway to access your repository
   - Select `wealth-app` repository
   - Railway will auto-detect Node.js project

3. **Configure Root Directory**
   - In Railway dashboard → Settings
   - Set "Root Directory" to `backend`
   - This tells Railway where to find package.json

4. **Set Environment Variables**
   - Go to project → Variables tab
   - Add all variables from backend/.env:

   ```
   PLAID_CLIENT_ID=<your_plaid_client_id>
   PLAID_SECRET_SANDBOX=<your_sandbox_secret>
   PLAID_SECRET_PRODUCTION=<your_production_secret>
   PLAID_SECRET=<your_sandbox_secret>
   PLAID_ENV=sandbox
   OPENAI_API_KEY=<your_openai_key>
   PORT=3000
   NODE_ENV=production
   JWT_SECRET=<generate_new_64_byte_hex>
   JWT_ACCESS_EXPIRY=15m
   ENCRYPTION_KEY=<generate_new_32_byte_hex>
   APPLE_BUNDLE_ID=com.financialanalyzer.app
   ```

   **Generate production secrets:**
   ```bash
   # JWT Secret (64 bytes)
   node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"

   # Encryption Key (32 bytes)
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   ```

5. **Deploy**
   - Railway auto-deploys on push
   - First deploy: Manual trigger via dashboard → Deploy button
   - Monitor logs in Railway dashboard

6. **Get Deployment URL**
   - Settings → Generate Domain
   - Railway provides: `your-app-name.up.railway.app`
   - Copy this URL for iOS app configuration

### Option B: Railway CLI

```bash
# Install CLI
npm install -g @railway/cli

# Login
railway login

# Link project (or create new)
railway link

# Set root directory
railway up --rootdir backend

# Add environment variables
railway variables set PLAID_CLIENT_ID=xxx
railway variables set PLAID_SECRET=xxx
# ... (repeat for all variables)

# Deploy
railway up
```

## Post-Deployment

### 1. Verify Backend is Running

```bash
curl https://your-app.up.railway.app/api/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2026-02-06T..."
}
```

### 2. Test Plaid Integration

```bash
curl -X POST https://your-app.up.railway.app/api/plaid/create-link-token \
  -H "Content-Type: application/json"
```

Should return link token (without auth required for this endpoint).

### 3. Update iOS App

Edit `FinancialAnalyzer/Utilities/AppConfig.swift`:

```swift
struct AppConfig {
    // Production URL from Railway
    static let baseURL = "https://your-app.up.railway.app"

    // Old: static let baseURL = "http://localhost:3000"
}
```

### 4. Build and Test on iOS Device

1. Connect iPhone to Mac
2. Select device in Xcode
3. Update baseURL in AppConfig.swift
4. Build and run (Cmd+R)
5. Test complete onboarding flow

## Database Management

Railway provides persistent storage for SQLite:
- Database: `/app/backend/db/app.db`
- Automatic volume attached
- Survives deployments

**Backup database:**
```bash
railway run -- sqlite3 db/app.db ".backup backup.db"
railway download backup.db
```

## Monitoring

Railway dashboard provides:
- Real-time logs
- CPU/Memory metrics
- Deployment history
- Crash reports

## Troubleshooting

### Build Fails

**Check root directory:**
- Settings → Root Directory = `backend`

**Check start command:**
- Settings → Start Command = `node server.js`

### Runtime Errors

**Check logs:**
- Railway dashboard → Logs tab
- Filter by error level

**Database initialization:**
- SQLite auto-creates on first run
- Check write permissions in Railway volume

**Environment variables:**
- Verify all variables set
- Check for typos in variable names
- Regenerate JWT_SECRET and ENCRYPTION_KEY for production

### Connection Issues from iOS

**CORS errors:**
- Backend already configured for CORS
- Verify AppConfig.baseURL uses https:// (not http://)

**SSL errors:**
- Railway provides SSL by default
- Update Info.plist: Remove NSAllowsArbitraryLoads for production

**Network timeout:**
- Check Railway deployment status (green = running)
- Test backend directly with curl first

## Cost Estimation

Railway pricing (as of 2026):
- **Free tier**: $5 credit/month
- **Pro plan**: $20/month + usage
- Estimated backend cost: ~$5-10/month for MVP traffic

## Next Steps

After successful deployment:

1. ✅ Update iOS app with production URL
2. ✅ Test complete user flow on physical device
3. ✅ Monitor Railway logs for errors
4. Switch PLAID_ENV to `development` when ready for real bank testing
5. Set up monitoring alerts in Railway dashboard
6. Document deployment URL in BUILD-LOG.md

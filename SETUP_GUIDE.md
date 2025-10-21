# Quick Setup Guide

Follow these steps to get the Financial Analyzer app running on your iPhone.

## Step 1: Backend Setup (5 minutes)

### Install Node.js Dependencies

```bash
cd backend
npm install
```

### Get Plaid Credentials

1. Go to [https://dashboard.plaid.com/signup](https://dashboard.plaid.com/signup)
2. Create a free account
3. Go to **Team Settings** → **Keys**
4. Copy your `client_id` and `sandbox` secret

### Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and paste your credentials:

```env
PLAID_CLIENT_ID=your_client_id_here
PLAID_SECRET=your_sandbox_secret_here
PLAID_ENV=sandbox
PORT=3000
```

### Start the Server

```bash
npm run dev
```

You should see:
```
🚀 Financial Analyzer Backend Server
📡 Running on http://localhost:3000
🌍 Environment: sandbox
```

✅ **Backend is ready!** Leave this terminal running.

## Step 2: iOS App Setup (10 minutes)

### Option A: Using Xcode Project (Recommended)

1. **Create a new iOS App project in Xcode:**
   - File → New → Project
   - Choose "App" template
   - Product Name: "FinancialAnalyzer"
   - Interface: SwiftUI
   - Language: Swift

2. **Add Swift Package Dependencies:**
   - File → Add Package Dependencies
   - Enter: `https://github.com/plaid/plaid-link-ios`
   - Select latest version (5.0.0+)

3. **Copy source files:**
   ```bash
   # In Finder, drag the entire Sources/FinancialAnalyzer folder
   # into your Xcode project's root
   ```

4. **Configure Info.plist:**
   - Select your project in the navigator
   - Select the target → Info tab
   - Add a new row:
     - Key: `App Transport Security Settings` (dictionary)
     - Add child: `Allow Local Networking` = YES

### Option B: Using Swift Package Manager

```bash
# From the demo-app directory
open Package.swift
```

This will open the package in Xcode. You can build and run from there.

### Update Backend URL (if using physical device)

1. Find your computer's IP address:
   ```bash
   ipconfig getifaddr en0  # macOS
   ```

2. In `Sources/FinancialAnalyzer/Services/PlaidService.swift`, update:
   ```swift
   init(baseURL: String = "http://YOUR_IP_ADDRESS:3000") {
       self.baseURL = baseURL
   }
   ```

### Build and Run

1. Select a simulator or device in Xcode
2. Press **Cmd+R** to build and run
3. Wait for the app to launch

✅ **iOS app is ready!**

## Step 3: Test with Sandbox Data

### Connect Your First "Bank Account"

1. Tap **Get Started** in the onboarding flow
2. Tap the **+** button in the top right
3. In Plaid Link, search for **"Platypus"** (test bank)
4. Use these credentials:
   - Username: `user_good`
   - Password: `pass_good`
   - MFA Code: `1234` (if prompted)

5. Select accounts to link
6. Tap **Continue**

### View Your Financial Data

After a few seconds, you should see:
- ✅ 6 financial buckets populated with test data
- ✅ Recent transactions list
- ✅ Account balances

### Explore the App

**Dashboard Tab:**
- View all 6 financial buckets
- Pull down to refresh
- Tap buckets to see details

**Transactions Tab:**
- Browse transaction history
- Search by merchant
- Filter by category

**Accounts Tab:**
- View connected accounts
- See balances by type

## Troubleshooting

### "Failed to create link token"

**Problem:** Backend not reachable
**Solution:**
1. Ensure backend is running (`npm run dev` in backend folder)
2. Check console for errors
3. Verify baseURL in PlaidService.swift

### "Invalid credentials"

**Problem:** Plaid credentials incorrect
**Solution:**
1. Double-check client_id and secret in `.env`
2. Make sure you're using the `sandbox` secret (not development/production)
3. Restart backend server after changing `.env`

### Physical Device Connection Issues

**Problem:** Cannot connect from iPhone to backend
**Solution:**
1. Make sure iPhone and computer are on same WiFi network
2. Update baseURL to use computer's IP address (not localhost)
3. Disable firewall temporarily to test
4. Check that port 3000 is not blocked

### No Transactions Showing

**Problem:** Linked account but no data
**Solution:**
1. Wait 10-15 seconds for data to sync
2. Pull down to refresh
3. Check backend console for errors
4. Try relinking the account

### Build Errors in Xcode

**Problem:** Swift compilation errors
**Solution:**
1. Clean build folder: Shift+Cmd+K
2. File → Packages → Reset Package Caches
3. Restart Xcode
4. Ensure iOS 16.0+ deployment target

## Next Steps

Once everything is working:

1. **Explore sandbox banks:**
   - Try "First Platypus Bank" for checking/savings
   - Try "Tartan Bank" for credit cards
   - Try "Houndstooth Bank" for investments

2. **Test error scenarios:**
   - Use `user_bad` / `pass_bad` to test error handling
   - Try disconnecting accounts

3. **Customize the app:**
   - Add your own color schemes
   - Modify bucket categories
   - Add custom analytics

4. **Move to Development/Production:**
   - Get production credentials from Plaid
   - Implement real user authentication
   - Set up proper database for token storage
   - Deploy backend to a server

## Additional Resources

- **Plaid Sandbox Guide:** https://plaid.com/docs/sandbox/test-credentials/
- **Swift Package Manager:** https://www.swift.org/package-manager/
- **SwiftUI Tutorials:** https://developer.apple.com/tutorials/swiftui

## Support

If you run into issues:
1. Check the main [README.md](README.md) for detailed docs
2. Review backend logs in the terminal
3. Check Xcode console for iOS errors
4. Verify all steps above were completed

---

**Success!** 🎉 You should now have a fully functional financial analysis app running on your iPhone!

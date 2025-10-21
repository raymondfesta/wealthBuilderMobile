# 🚀 Quick Start - You're Almost There!

## ✅ What's Already Done

1. **Backend Server** - Running on http://localhost:3000
   - ✅ Dependencies installed
   - ✅ Plaid credentials configured
   - ✅ Server is live and healthy

2. **iOS Xcode Project** - Ready to build
   - ✅ Project structure created
   - ✅ All Swift files in place
   - ✅ Plaid Link SDK configured
   - ✅ Info.plist set up for local networking

## 📱 Next Steps (2 minutes)

### Step 1: Build the iOS App

The Xcode project should now be open. If not:
```bash
open /Users/rfesta/Desktop/demo-app/FinancialAnalyzer.xcodeproj
```

In Xcode:
1. Wait for package dependencies to resolve (top of window)
2. Select a simulator (iPhone 15 Pro recommended)
3. Press **Cmd+R** to build and run

### Step 2: Test with Sandbox Account

Once the app launches:

1. **Tap "Get Started"** - Skip the onboarding
2. **Tap the "+" button** - Top right corner
3. **Search for "Platypus"** - In the bank search
4. **Login with test credentials:**
   - Username: `user_good`
   - Password: `pass_good`
   - MFA Code: `1234` (if prompted)
5. **Select accounts** - Choose any accounts shown
6. **Tap Continue** - Complete the flow

### Step 3: View Your Financial Data

After 3-5 seconds, you'll see:
- ✅ **6 Financial Buckets** populated with data
- ✅ **Recent Transactions** list
- ✅ **Connected Accounts** tab

## 🎯 Your 6 Financial Buckets

1. **💰 Available to Spend** - Disposable income after bills & debt
2. **📈 Avg Monthly Income** - Money coming in
3. **📉 Avg Monthly Expenses** - Money going out
4. **💳 Total Debt** - Credit cards & loans
5. **📊 Total Invested** - Stocks & retirement
6. **🏦 Total Cash Available** - Checking & savings

## 🔧 Backend Server Status

Your backend is running at: **http://localhost:3000**

To check status:
```bash
curl http://localhost:3000/health
```

To restart if needed:
```bash
cd /Users/rfesta/Desktop/demo-app/backend
npm start
```

## 📱 Using on Physical iPhone

If you want to test on your actual iPhone:

1. **Find your Mac's IP address:**
   ```bash
   ipconfig getifaddr en0
   ```

2. **Update PlaidService.swift:**
   ```swift
   // Change line ~19 from:
   init(baseURL: String = "http://localhost:3000") {

   // To your IP:
   init(baseURL: String = "http://192.168.X.X:3000") {
   ```

3. Make sure iPhone and Mac are on same WiFi

## 🧪 Sandbox Test Banks

Try these banks in Plaid sandbox:

| Bank Name | Type | What to Test |
|-----------|------|--------------|
| **Platypus** | Checking/Savings | Basic transactions |
| **Tartan Bank** | Credit Cards | Debt tracking |
| **Houndstooth** | Investments | Portfolio analysis |
| **First Platypus Bank** | Multiple accounts | Full experience |

## 🐛 Troubleshooting

### "Failed to create link token"
→ Backend isn't running. Check terminal or restart with `npm start`

### "No transactions showing"
→ Wait 10 seconds, then pull down to refresh

### Build errors in Xcode
→ Clean build folder (Shift+Cmd+K) and rebuild

### Can't connect from physical device
→ Update baseURL to your Mac's IP address

## 📚 Documentation

- [Full README](README.md) - Complete documentation
- [Setup Guide](SETUP_GUIDE.md) - Detailed setup steps
- [Backend README](backend/README.md) - API documentation

## 🎉 What You've Built

A complete financial analysis app that:
- ✅ Connects to real bank accounts (via Plaid)
- ✅ Analyzes 6 months of transactions
- ✅ Categorizes spending automatically
- ✅ Shows 6 high-level financial metrics
- ✅ Displays transaction history
- ✅ Supports multiple accounts
- ✅ Uses SwiftUI + SwiftData
- ✅ Secure keychain storage

**Now go build and test it!** 🚀

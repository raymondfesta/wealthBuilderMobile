# Financial Analyzer iOS App

A native iPhone application that connects to bank accounts via Plaid API, analyzes 6 months of transactions, and categorizes them into high-level financial buckets.

## Features

### 🏦 Bank Account Integration
- Secure bank account connection using Plaid Link SDK
- Support for multiple accounts (checking, savings, credit cards, loans, investments)
- Real-time balance updates

### 📊 Transaction Analysis
- Automatic analysis of 6 months of transaction history
- Smart categorization using Plaid's taxonomy
- Real-time transaction updates

### 💰 Six High-Level Financial Buckets

1. **Available to Spend (Disposable Income)**
   - Calculated as: Income - Expenses - Debt Payments
   - Shows your true spending power

2. **Avg Monthly Income (Money In)**
   - Salary, freelance, investment income, etc.
   - Averaged over analyzed period

3. **Avg Monthly Expenses (Money Out)**
   - Bills, shopping, entertainment, subscriptions
   - Averaged over analyzed period

4. **Total Debt (Money Owed)**
   - Credit card balances
   - Loan balances (auto, personal, mortgage)

5. **Total Invested (Assets)**
   - Stocks, bonds, ETFs
   - Retirement accounts (401k, IRA)
   - Brokerage accounts

6. **Total Cash Available**
   - Checking account balances
   - Savings account balances

## Tech Stack

### iOS App
- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Data persistence
- **Plaid Link iOS SDK** - Bank account connection
- **MVVM Architecture** - Clean separation of concerns
- **Keychain** - Secure token storage

### Backend Server
- **Node.js** - Runtime environment
- **Express** - Web framework
- **Plaid Node SDK** - Plaid API integration
- **dotenv** - Environment configuration

## Project Structure

```
demo-app/
├── Sources/
│   └── FinancialAnalyzer/
│       ├── Models/              # Data models
│       │   ├── Transaction.swift
│       │   ├── BankAccount.swift
│       │   ├── BucketCategory.swift
│       │   └── FinancialSummary.swift
│       ├── Services/            # Business logic
│       │   ├── PlaidService.swift
│       │   └── TransactionAnalyzer.swift
│       ├── ViewModels/          # View state management
│       │   └── FinancialViewModel.swift
│       ├── Views/               # UI components
│       │   ├── DashboardView.swift
│       │   ├── TransactionsListView.swift
│       │   ├── AccountsView.swift
│       │   └── OnboardingView.swift
│       ├── Utilities/           # Helper functions
│       │   └── KeychainService.swift
│       └── FinancialAnalyzerApp.swift
├── backend/                     # Node.js backend
│   ├── server.js
│   ├── package.json
│   └── .env.example
└── Package.swift                # SPM dependencies
```

## Setup Instructions

### Prerequisites
- **Xcode 15.0+** with iOS 16.0+ SDK
- **Node.js 18+** and npm
- **Plaid Account** (free sandbox available)

### Backend Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure Plaid credentials:**
   ```bash
   cp .env.example .env
   ```

   Edit `.env` and add your Plaid credentials:
   - Sign up at [https://dashboard.plaid.com/signup](https://dashboard.plaid.com/signup)
   - Get your `client_id` and `sandbox` secret from Team Settings > Keys
   - Add them to `.env`

4. **Start the server:**
   ```bash
   npm run dev
   ```

   Server runs on `http://localhost:3000`

### iOS App Setup

1. **Open the project in Xcode:**
   ```bash
   open Package.swift
   ```

   Or create a new iOS App project and copy the `Sources` folder.

2. **Add Swift Package Dependencies:**
   - Plaid Link iOS SDK is already configured in `Package.swift`
   - Xcode will automatically resolve dependencies

3. **Configure Info.plist:**
   Add the following to allow local network connections (for development):
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
       <key>NSAllowsLocalNetworking</key>
       <true/>
   </dict>
   ```

4. **Update backend URL (if needed):**
   In `PlaidService.swift`, update the baseURL:
   ```swift
   // For simulator
   init(baseURL: String = "http://localhost:3000")

   // For physical device, use your computer's IP
   init(baseURL: String = "http://192.168.1.X:3000")
   ```

5. **Build and run:**
   - Select a simulator or device
   - Press Cmd+R to build and run

## Usage

### First Time Setup

1. **Launch the app** - You'll see an onboarding flow explaining the features
2. **Connect bank account** - Tap the "+" button or "Connect Bank Account"
3. **Select your bank** - Use Plaid Link to search and select your bank
4. **Login** - Use your bank credentials (or test credentials in sandbox)
5. **Wait for analysis** - The app will fetch and analyze your transactions
6. **View insights** - See your financial buckets on the dashboard

### Sandbox Test Credentials

For testing in Plaid's sandbox environment:

- **Bank**: Search for "Platypus" or any bank
- **Username**: `user_good`
- **Password**: `pass_good`
- **MFA**: `1234` (if prompted)

### Main Features

#### Dashboard
- View all 6 financial buckets at a glance
- Tap on any bucket to see details
- Pull to refresh data
- Tap "+" to add more accounts

#### Transactions
- Browse all transactions
- Search by merchant or description
- Filter by category
- View transactions grouped by month

#### Accounts
- See all connected accounts
- View balances by account type
- Monitor account health

## How Transaction Categorization Works

### Category Mapping Logic

The app uses Plaid's detailed categories and maps them to high-level buckets:

1. **Income Detection**
   - Plaid returns negative amounts for deposits
   - Categories like "Payroll", "Transfer In", "Interest"
   - Mapped to: **Avg Monthly Income**

2. **Expense Detection**
   - Positive amounts for purchases/payments
   - Categories like "Food", "Transportation", "Shopping"
   - Mapped to: **Avg Monthly Expenses**

3. **Debt Detection**
   - Credit card payments
   - Loan payments
   - Mortgage payments
   - Mapped to: **Total Debt** (for balances) or deducted from disposable income

4. **Investment Detection**
   - Transfers to investment accounts
   - Brokerage transactions
   - Retirement contributions
   - Mapped to: **Total Invested**

5. **Cash Calculation**
   - Account balances from checking/savings
   - Mapped to: **Total Cash Available**

6. **Disposable Income Calculation**
   - Formula: Income - Expenses - Debt Payments
   - Shows true spending power
   - Mapped to: **Available to Spend**

## Security Considerations

### Current Implementation (Development)
- ✅ Keychain storage for access tokens
- ✅ HTTPS for Plaid API calls
- ✅ Secure token exchange flow
- ⚠️ In-memory token storage on backend (temporary)
- ⚠️ No user authentication

### Production Requirements
- 🔒 Implement user authentication (OAuth, JWT)
- 🔒 Database for encrypted token storage
- 🔒 Add rate limiting
- 🔒 Input validation and sanitization
- 🔒 HTTPS only for all connections
- 🔒 Regular security audits
- 🔒 Compliance with financial data regulations

## Troubleshooting

### Backend Issues

**Error: "PLAID_CLIENT_ID and PLAID_SECRET must be set"**
- Make sure `.env` file exists in `backend/` directory
- Verify credentials are correct
- Restart the server

**Error: Connection refused**
- Ensure backend is running (`npm run dev`)
- Check port 3000 is not in use
- For physical devices, use computer's IP address

### iOS App Issues

**Error: "Failed to create link token"**
- Verify backend server is running
- Check network connectivity
- Ensure baseURL is correct in PlaidService.swift

**Error: "No transactions found"**
- Make sure you completed the Plaid Link flow
- Wait a few seconds for data to sync
- Try pulling to refresh

**Build errors**
- Clean build folder (Shift+Cmd+K)
- Reset package caches
- Ensure iOS 16.0+ deployment target

## ✨ NEW: Proactive Decision-Point Guidance with AI

**The first finance app that helps you decide what to do with your money BEFORE you spend it.**

### Features Implemented:
- ✅ **AI-Powered Purchase Insights** - GPT-4 analyzes your spending patterns and provides personalized guidance
- ✅ **Smart Budget Alerts** - Get notified before you overspend, with options to reallocate or defer
- ✅ **Automatic Budget Generation** - Creates budgets from your transaction history using pattern analysis
- ✅ **Goal-Based Savings** - Track emergency funds, vacations, debt payoff with milestone notifications
- ✅ **Cash Flow Predictions** - Predicts upcoming bills 7-30 days ahead to prevent overdrafts
- ✅ **Savings Opportunities** - Detects when you're under budget and recommends goal contributions
- ✅ **Interactive Notifications** - Swipe to confirm, defer, or reallocate from the notification itself

**📚 [Read the Full Feature Documentation →](PROACTIVE_GUIDANCE_FEATURE.md)**

**📊 [View Implementation Summary →](IMPLEMENTATION_SUMMARY.md)**

### Quick Start
```bash
# Backend: Add OpenAI API key to .env
cd backend
echo "OPENAI_API_KEY=sk-your-key-here" >> .env
npm install openai
npm run dev

# iOS: See PROACTIVE_GUIDANCE_FEATURE.md for integration steps
```

---

## Future Enhancements

- [x] Budget tracking and alerts ✅ **DONE**
- [x] Financial goals and savings targets ✅ **DONE**
- [ ] Spending trend graphs
- [ ] Bill payment reminders
- [ ] Export reports (PDF, CSV)
- [ ] Custom category rules
- [ ] Multi-currency support
- [ ] Investment performance tracking
- [ ] Net worth over time
- [ ] Subscription detection and management

## License

MIT License - feel free to use this project as a template for your own financial apps.

## Resources

- [Plaid Documentation](https://plaid.com/docs/)
- [Plaid Link iOS SDK](https://github.com/plaid/plaid-link-ios)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Plaid's sandbox testing guide
3. Check the backend logs for errors

---

**Note**: This is a development/educational project. For production use, implement proper security measures, user authentication, and comply with financial data regulations in your jurisdiction.

# Plaid Custom User Configuration - Quick Start Guide

## What Is This?

A comprehensive Plaid sandbox test user that mimics a real-world personal finance setup with **14 accounts** and **~350 transactions** over 6 months. This stress-tests your wealth management app with realistic complexity.

## How to Use

### Option 1: Via Plaid Link (Recommended)

1. **Start your backend server:**
   ```bash
   cd backend
   npm run dev
   ```

2. **Launch the iOS app** in Xcode (Cmd+R)

3. **Tap the "+" button** to connect a bank account

4. **When Plaid Link opens, enter:**
   - **Username:** `user_custom`
   - **Password:** Copy and paste the **entire contents** of `plaid_custom_user_config.json`
     - Yes, paste the whole JSON object!
     - Plaid will parse it and create all accounts

5. **Complete the authentication flow** - Plaid will create 14 accounts with full transaction history

### Option 2: Via Plaid Dashboard (Alternative)

1. Log into [Plaid Dashboard](https://dashboard.plaid.com)
2. Go to **Developers → Sandbox → Sandbox Users**
3. Create a new custom user
4. Paste the contents of `plaid_custom_user_config.json` into the configuration field
5. Save and use the credentials in your app

## What You Get

### Account Structure (10 Accounts)

**Checking & Cash Management (4):**
- Primary Checking - $3,200 balance
- Bills Checking - $1,850 balance
- Discretionary Cash Management - $450 balance
- Emergency Buffer - $2,800 balance

**Savings (2):**
- Emergency Fund HYSA - $11,500 balance (growing at $500/month + interest)
- Short-Term Goals - $3,000 balance

**Investments (3):**
- 401k Retirement - $45,800 balance
- Roth IRA - $21,250 balance
- Taxable Brokerage - $14,200 balance

**Credit (1):**
- Chase Sapphire Reserve - $1,850 balance

**Total Net Worth:** ~$99,700

### Transaction Types (~230 total)

**Income:**
- Semi-monthly salary: $2,500 (1st and 15th)
- Q2 bonus: $750
- Interest income: ~$40/month (HYSA)
- Dividend income: ~$27/month (Brokerage)
- Employer 401k match: $250 per paycheck (14 paychecks)

**Essential Expenses:**
- Rent: $1,800/month
- Utilities: $220/month (gas, electric, internet, water)
- Groceries: $400/month (Whole Foods, Costco, Trader Joes, Safeway, etc.)
- Gas: $50-55/month
- Auto insurance: $85/month
- Subscriptions: $37/month (Netflix, Spotify, iCloud)

**Discretionary:**
- Dining: $400/month
- Entertainment: $100/month
- Shopping: $300/month
- Travel: Occasional

**Money Movement:**
- Inter-account transfers (Primary → Bills, Discretionary, Savings)
- Credit card payment ($450/month to Chase Sapphire)
- Investment contributions ($500 401k + $500 Roth + $300 brokerage monthly)
- Emergency fund deposits ($500/month)
- Short-term goals savings ($300/month - vacation fund)

## Expected Financial Metrics

After connecting this user, your app should calculate:

- **Monthly Income:** ~$5,820 (salary + bonus + interest + dividends + match)
- **Monthly Expenses:** ~$3,350 (essential + discretionary)
- **Savings Rate:** ~42%
- **Emergency Fund Coverage:** 4.6 months (based on essential expenses ~$2,500/month)
- **Credit Utilization:** ~$1,850 balance (no limit data in sandbox)
- **Income Stability:** Stable (W-2)
- **Health Score:** ~78 (good)

## What This Tests

### 1. Multi-Account Complexity
- How does your UI handle 10 accounts?
- Account grouping/tagging functionality
- Navigation and information hierarchy
- **Note:** Reduced to 10 accounts to comply with Plaid sandbox limits

### 2. Inter-Account Transfers
- Transfers shouldn't inflate income/expenses
- Duplicate transaction detection
- Net cash flow accuracy

### 3. Investment Aggregation
- Total invested across 3 accounts
- Retirement (401k + Roth IRA) vs. taxable brokerage distinction
- Employer match tracking

### 4. Category Mapping
- Essential vs. discretionary classification
- Plaid Personal Finance Categories (PFC) - **Auto-assigned by Plaid after account creation**
- Allocation bucket accuracy
- **Note:** Custom configs don't support PFC field; Plaid categorizes automatically

### 5. Edge Cases
- Refunds (negative expenses)
- Dividends and interest income
- Recurring vs. one-time expenses
- Annual expense handling

### 6. Performance
- Rendering ~230 transactions
- Date range filtering (7 months of data: April - October 2025)
- Category breakdown calculations
- Search and filter speed

## Troubleshooting

### "Invalid credentials" error
- Make sure you're using `user_custom` as the username
- Verify you copied the **entire JSON** from `plaid_custom_user_config.json`
- Check that JSON is valid (no trailing commas, proper quotes)

### Transactions not showing
- Wait 10-15 seconds after connection for Plaid to sync
- Pull to refresh in the app
- Check backend logs for errors

### Account balances don't match
- Plaid calculates current balance based on starting_balance + transactions
- Some variation is expected due to how Plaid processes the config

### Only some accounts appear
- Plaid has a **strict limit of 10 accounts** per custom user
- Current config is optimized at exactly 10 accounts
- Check backend logs for which accounts were created

### Transactions missing categories
- **This is normal!** Custom user configs don't support `personal_finance_category` field
- Plaid automatically assigns categories **after** account creation
- Wait 10-15 seconds after connection, then pull to refresh
- Categories will appear with confidence levels (VERY_HIGH, HIGH, MEDIUM, etc.)

## Customizing the Configuration

### Adding More Transactions
Edit `plaid_custom_user_config.json` and add to the `transactions` array:
```json
{
  "date_posted": "2025-10-25",
  "date_transacted": "2025-10-25",
  "amount": 45.99,
  "description": "YOUR MERCHANT NAME",
  "currency": "USD"
}
```

**Important Notes:**
- **DO NOT include `personal_finance_category`** - not supported in custom configs
- Plaid will auto-assign categories after account creation
- Positive amount = money OUT (expenses, transfers out)
- Negative amount = money IN (income, deposits, refunds)

**Limits:**
- Max ~250 transactions per account
- Max ~55kb total config size
- Max 10 accounts (hard limit)

### Changing Balances
Update the `starting_balance` field for any account:
```json
{
  "type": "depository",
  "subtype": "checking",
  "starting_balance": 5000,  // Change this
  "meta": {
    "name": "Primary Checking",
    ...
  }
}
```

### Adding Pending Transactions
Set `date_posted` to a future date:
```json
{
  "date_posted": "2025-12-31",
  "date_transacted": "2025-10-20",
  "amount": 100,
  "description": "PENDING CHARGE",
  "currency": "USD"
}
```
**Note:** Future `date_posted` = pending transaction

## Alternative Test Users

If 10 accounts is too complex, try these built-in Plaid users:

**Medium Complexity:**
- `user_yuppie` - Young professional (password: any)
- `user_small_business` - Business account (password: any)
- `user_credit_profile_excellent` - High earner (password: any)

**Minimal (Quick Tests):**
- `user_good` - Basic account (password: `pass_good`)

## Resources

- [Plaid Sandbox Docs](https://plaid.com/docs/sandbox/)
- [Custom User Guide](https://plaid.com/docs/sandbox/user-custom/)
- [Personal Finance Categories](https://plaid.com/docs/api/products/transactions/#personal-finance-category)
- [GitHub: plaid/sandbox-custom-users](https://github.com/plaid/sandbox-custom-users)

## Questions?

See `CLAUDE.md` section "Custom User Testing Scenarios" for detailed breakdown of what each scenario tests.

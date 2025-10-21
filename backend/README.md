# Financial Analyzer Backend

This is the backend server for the Financial Analyzer iOS app. It handles Plaid API integration and token management.

## Setup

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Configure Environment Variables

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Sign up for a Plaid account at [https://dashboard.plaid.com/signup](https://dashboard.plaid.com/signup)

3. Get your credentials:
   - Go to Team Settings > Keys
   - Copy your `client_id` and `sandbox` secret

4. Update `.env` with your credentials:
```
PLAID_CLIENT_ID=your_client_id_here
PLAID_SECRET=your_sandbox_secret_here
PLAID_ENV=sandbox
PORT=3000
```

### 3. Run the Server

Development mode (with auto-reload):
```bash
npm run dev
```

Production mode:
```bash
npm start
```

The server will start on `http://localhost:3000`

## API Endpoints

### Health Check
- **GET** `/health`
- Returns server status

### Create Link Token
- **POST** `/api/plaid/create_link_token`
- Creates a link token for Plaid Link initialization

### Exchange Public Token
- **POST** `/api/plaid/exchange_public_token`
- Body: `{ "public_token": "..." }`
- Exchanges public token for access token

### Get Accounts
- **POST** `/api/plaid/accounts`
- Body: `{ "access_token": "..." }`
- Returns list of connected accounts

### Get Transactions
- **POST** `/api/plaid/transactions`
- Body: `{ "access_token": "...", "start_date": "2024-01-01", "end_date": "2024-06-01" }`
- Returns transactions for the specified date range

### Get Balance
- **POST** `/api/plaid/balance`
- Body: `{ "access_token": "..." }`
- Returns current account balances

### Remove Item
- **POST** `/api/plaid/item/remove`
- Body: `{ "access_token": "..." }`
- Disconnects a bank account
- Returns: `{ "removed": true, "item_id": "..." }`
- This triggers cleanup of all associated data in the iOS app

## Account Removal & Data Cleanup

When a user removes a linked bank account, the following cleanup occurs automatically:

### Backend (server.js)
1. Calls Plaid's `itemRemove` API to disconnect the account
2. Removes the access token from in-memory storage
3. Returns the `item_id` to the client

### iOS App (FinancialViewModel)
1. Calls backend removal endpoint
2. Deletes access token from iOS Keychain
3. Removes all accounts with matching `itemId`
4. Filters out all transactions from removed accounts
5. Recalculates financial summary with remaining data
6. Regenerates budgets from remaining transactions
7. Updates UserDefaults cache
8. Clears any active alerts/guidance that may reference removed data

### What Gets Updated
- ✅ **Accounts list** - Removed accounts no longer appear
- ✅ **Transactions** - Transactions from removed accounts are deleted
- ✅ **Financial summary** - Income, expenses, and all bucket values recalculated
- ✅ **Budgets** - Regenerated based on remaining transaction history
- ✅ **Cache** - All UserDefaults caches updated to persist changes
- ✅ **Alerts** - Active guidance cleared to prevent stale data references

### User Experience
- Swipe-to-delete or context menu on account rows
- Confirmation alert before removal
- Loading indicator during removal process
- All dependent data automatically updates

## Plaid Environments

- **sandbox**: For testing (default)
- **development**: For development with real credentials
- **production**: For live applications

## Security Notes

⚠️ **Important for Production:**

1. **Never commit `.env` file** - It contains sensitive credentials
2. **Use a proper database** - Currently uses in-memory storage for access tokens
3. **Encrypt access tokens** - Store encrypted in production
4. **Add authentication** - Implement user authentication before deploying
5. **Use HTTPS** - Always use HTTPS in production
6. **Rate limiting** - Add rate limiting to prevent abuse
7. **Input validation** - Validate all inputs thoroughly

## Testing with iOS App

Make sure your iOS app's `PlaidService.swift` points to:
```swift
init(baseURL: String = "http://localhost:3000") {
    self.baseURL = baseURL
}
```

For testing on a physical device, use your computer's IP address:
```swift
init(baseURL: String = "http://192.168.1.X:3000") {
    self.baseURL = baseURL
}
```

## Troubleshooting

### "PLAID_CLIENT_ID and PLAID_SECRET must be set"
- Make sure `.env` file exists and contains valid credentials
- Restart the server after updating `.env`

### Connection refused from iOS app
- Make sure the backend server is running
- Check the IP address/port in iOS app matches the server
- For physical devices, use your computer's local IP address

### Invalid credentials error
- Verify your Plaid credentials in the dashboard
- Make sure you're using the correct environment (sandbox/development/production)
- Check that the secret matches the environment

## Resources

- [Plaid API Documentation](https://plaid.com/docs/)
- [Plaid Dashboard](https://dashboard.plaid.com/)
- [Plaid Sandbox Testing Guide](https://plaid.com/docs/sandbox/test-credentials/)

# Plaid Sandbox Testing - Quick Reference

## Test User Credentials

```
Username: user_transactions_dynamic
Password: pass_good
MFA Code: 1234
```

## Quick Test Commands

### 1. Check Server Health

```bash
curl http://localhost:3000/health
```

### 2. List Stored Items

```bash
curl http://localhost:3000/api/debug/items
```

### 3. Create Test Transaction (Over-Budget)

```bash
curl -X POST http://localhost:3000/api/plaid/sandbox/create-transaction \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "YOUR_ACCESS_TOKEN_HERE",
    "amount": 150.00,
    "merchant_name": "Target"
  }'
```

### 4. Create Test Transaction (Income/Savings Opportunity)

```bash
curl -X POST http://localhost:3000/api/plaid/sandbox/create-transaction \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "YOUR_ACCESS_TOKEN_HERE",
    "amount": -2500.00,
    "merchant_name": "Employer Payroll"
  }'
```

### 5. Manually Fire DEFAULT_UPDATE Webhook

```bash
curl -X POST http://localhost:3000/api/plaid/sandbox/fire-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "YOUR_ACCESS_TOKEN_HERE",
    "webhook_code": "DEFAULT_UPDATE"
  }'
```

### 6. Test Error Recovery (Force Re-Auth)

```bash
curl -X POST http://localhost:3000/api/plaid/sandbox/reset-login \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "YOUR_ACCESS_TOKEN_HERE"
  }'
```

### 7. Test Other Webhook Types

**Item Login Required:**
```bash
curl -X POST http://localhost:3000/api/plaid/sandbox/fire-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "YOUR_ACCESS_TOKEN_HERE",
    "webhook_code": "ITEM_LOGIN_REQUIRED"
  }'
```

**New Accounts Available:**
```bash
curl -X POST http://localhost:3000/api/plaid/sandbox/fire-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "YOUR_ACCESS_TOKEN_HERE",
    "webhook_code": "NEW_ACCOUNTS_AVAILABLE"
  }'
```

**User Permission Revoked:**
```bash
curl -X POST http://localhost:3000/api/plaid/sandbox/fire-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "YOUR_ACCESS_TOKEN_HERE",
    "webhook_code": "USER_PERMISSION_REVOKED"
  }'
```

## Testing Workflow

### Quick Test Loop

1. **Connect account** with `user_transactions_dynamic`
2. **Copy access token** from iOS logs or debug endpoint
3. **Create transaction** using curl command above
4. **Wait 2-3 seconds** for processing
5. **Pull-to-refresh** in iOS app
6. **Verify** transaction appears and guidance triggers

### Rapid Testing Script

Create multiple transactions for stress testing:

```bash
# Set your access token
ACCESS_TOKEN="YOUR_ACCESS_TOKEN_HERE"

# Create 5 random transactions
for i in {1..5}; do
  AMOUNT=$((RANDOM % 100 + 10))
  curl -X POST http://localhost:3000/api/plaid/sandbox/create-transaction \
    -H "Content-Type: application/json" \
    -d "{
      \"access_token\": \"$ACCESS_TOKEN\",
      \"amount\": $AMOUNT.00,
      \"merchant_name\": \"Test Merchant $i\"
    }"
  echo ""
  echo "Created transaction $i for \$$AMOUNT.00"
  sleep 2
done
```

## ngrok Setup (Optional - for real webhooks)

```bash
# 1. Install ngrok
brew install ngrok

# 2. Start your backend
cd backend
npm run dev

# 3. In another terminal, expose to internet
ngrok http 3000

# 4. Copy the HTTPS URL (e.g., https://abc123.ngrok.io)

# 5. Configure in Plaid Dashboard:
#    - Go to https://dashboard.plaid.com
#    - Developers → Webhooks
#    - Set: https://abc123.ngrok.io/api/plaid/webhook
```

## Expected Responses

### Success Response (Transaction Created)

```json
{
  "success": true,
  "message": "Transaction created. DEFAULT_UPDATE webhook will fire automatically.",
  "note": "Only works with user_transactions_dynamic test user"
}
```

### Success Response (Webhook Fired)

```json
{
  "success": true,
  "message": "Webhook DEFAULT_UPDATE triggered",
  "webhook_code": "DEFAULT_UPDATE"
}
```

### Success Response (Item Reset)

```json
{
  "success": true,
  "message": "Item set to ITEM_LOGIN_REQUIRED state. Test re-authentication flow.",
  "note": "Use Plaid Link in update mode to reconnect the account"
}
```

### Error Response (Missing Parameters)

```json
{
  "error": "access_token, amount, and merchant_name are required"
}
```

### Error Response (Sandbox Only)

```json
{
  "error": "This endpoint only works in sandbox environment",
  "details": { ... }
}
```

## Backend Logs to Watch For

### Successful Webhook

```
📨 [Webhook] Received webhook request
🔑 [Webhook] Fetching verification key from Plaid...
✅ [Webhook] Signature validation passed
📨 [Webhook] Type: TRANSACTIONS, Code: DEFAULT_UPDATE, Item: item-xxx
📊 [Webhook] New transactions available for item item-xxx
```

### Successful Transaction Creation

```
🧪 [Sandbox] Creating test transaction: $150.0 at Target
✅ [Sandbox] Test transaction created successfully
✅ [Sandbox] DEFAULT_UPDATE webhook will fire automatically
```

### Successful Item Reset

```
🧪 [Sandbox] Resetting item to ITEM_LOGIN_REQUIRED state
✅ [Sandbox] Item reset successfully
✅ [Sandbox] ITEM_LOGIN_REQUIRED webhook will fire (if webhook configured)
```

## Tips

1. **Get Access Token**: Check iOS console logs or call `/api/debug/items`
2. **Check Logs**: Always monitor backend logs when testing
3. **Wait for Sync**: Give Plaid 2-3 seconds to process after creating transactions
4. **Refresh App**: Pull-to-refresh in iOS to fetch new data
5. **Use ngrok**: For testing real webhook delivery (optional but recommended)

## Common Issues

**"Invalid credentials"**
- Make sure you're using `user_transactions_dynamic` not `user_good`

**"Transaction not appearing"**
- Wait 2-3 seconds and pull-to-refresh
- Check backend logs for errors

**"Webhook not firing"**
- Server must be running
- Access token must be valid
- Webhook code must be spelled correctly (case-sensitive)

**"SANDBOX_ONLY error"**
- Check `.env` has `PLAID_ENV=sandbox`
- Restart server after changing .env

## Next Steps

1. Connect account with `user_transactions_dynamic`
2. Create your first test transaction
3. Verify it appears in iOS app
4. Test proactive guidance triggers
5. Try different webhook types
6. Set up ngrok for webhook testing (optional)

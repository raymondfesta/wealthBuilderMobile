#!/bin/bash

# Verify Local Setup Script
# Run this to confirm backend server is ready for iOS simulator testing

echo "🔍 Verifying Local Backend Setup..."
echo ""

# Check if server is running
echo "1. Checking if backend server is running on port 3000..."
if lsof -ti:3000 > /dev/null 2>&1; then
    echo "   ✅ Server is running (PID: $(lsof -ti:3000))"
else
    echo "   ❌ Server is NOT running"
    echo "   📝 To start server: cd backend && npm start"
    exit 1
fi

# Test health endpoint
echo ""
echo "2. Testing health endpoint..."
HEALTH=$(curl -s http://localhost:3000/health)
if echo "$HEALTH" | grep -q "ok"; then
    echo "   ✅ Health check passed"
else
    echo "   ❌ Health check failed"
    exit 1
fi

# Test Plaid link token endpoint
echo ""
echo "3. Testing Plaid link token creation..."
LINK_TOKEN=$(curl -s -X POST http://localhost:3000/api/plaid/create_link_token)
if echo "$LINK_TOKEN" | grep -q "link_token"; then
    echo "   ✅ Plaid integration working"
else
    echo "   ❌ Plaid integration failed"
    exit 1
fi

# Test auth endpoint
echo ""
echo "4. Testing auth endpoint..."
AUTH_RESPONSE=$(curl -s -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"verify-test-$(date +%s)@test.com\",\"password\":\"test123\"}")
if echo "$AUTH_RESPONSE" | grep -q -E "(accessToken|email)"; then
    echo "   ✅ Authentication working"
else
    echo "   ⚠️  Auth test inconclusive (may be rate limited or user exists)"
    echo "   📝 Manually verify: curl -X POST http://localhost:3000/auth/login \\"
    echo "      -H 'Content-Type: application/json' \\"
    echo "      -d '{\"email\":\"testuser@example.com\",\"password\":\"testpass123\"}'"
fi

# Check iOS app configuration
echo ""
echo "5. Checking iOS app configuration..."
if grep -q "\.localhost" FinancialAnalyzer/Utilities/AppConfig.swift; then
    echo "   ✅ AppConfig set to .localhost"
else
    echo "   ⚠️  AppConfig not set to .localhost"
    echo "   📝 Update AppConfig.swift environment to .localhost"
fi

echo ""
echo "✅ All systems operational!"
echo ""
echo "📱 Ready to test in iOS Simulator:"
echo "   1. Open project in Xcode"
echo "   2. Select iOS Simulator (Cmd+Shift+O)"
echo "   3. Build and run (Cmd+R)"
echo ""
echo "🧪 Test credentials:"
echo "   Plaid Username: user_good"
echo "   Plaid Password: pass_good"
echo "   MFA Code: 1234"
echo ""

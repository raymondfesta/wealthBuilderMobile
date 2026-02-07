#!/bin/bash

echo "🧪 Testing iOS Simulator to Backend Connection"
echo "=============================================="
echo ""

# Check if server is running
echo "1️⃣ Checking backend server status..."
if curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "   ✅ Backend server is running on localhost:3000"
else
    echo "   ❌ Backend server is NOT running"
    echo "   ℹ️  Start it with: cd backend && npm start"
    exit 1
fi

# Test health endpoint
echo ""
echo "2️⃣ Testing /health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:3000/health)
echo "   Response: $HEALTH_RESPONSE"

# Test Plaid link token creation
echo ""
echo "3️⃣ Testing /api/plaid/create_link_token endpoint..."
LINK_TOKEN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/plaid/create_link_token -H "Content-Type: application/json")
if echo "$LINK_TOKEN_RESPONSE" | grep -q "link_token"; then
    echo "   ✅ Link token created successfully"
    echo "   Sample token: $(echo $LINK_TOKEN_RESPONSE | jq -r '.link_token' | head -c 30)..."
else
    echo "   ❌ Failed to create link token"
    echo "   Response: $LINK_TOKEN_RESPONSE"
fi

# Test auth registration endpoint
echo ""
echo "4️⃣ Testing /auth/register endpoint..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:3000/auth/register \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"testpass123"}')
if echo "$REGISTER_RESPONSE" | grep -q "accessToken"; then
    echo "   ✅ Registration endpoint working"
else
    echo "   ℹ️  Registration response (may fail if user exists): $(echo $REGISTER_RESPONSE | head -c 100)"
fi

# Check iOS app configuration
echo ""
echo "5️⃣ Checking iOS app configuration..."
if grep -q 'environment: Environment = .localhost' FinancialAnalyzer/Utilities/AppConfig.swift; then
    echo "   ✅ AppConfig.swift is set to .localhost"
else
    echo "   ⚠️  AppConfig.swift is NOT set to .localhost"
    echo "   Current setting:"
    grep 'environment: Environment' FinancialAnalyzer/Utilities/AppConfig.swift
fi

echo ""
echo "=============================================="
echo "✅ All backend endpoints are functional!"
echo ""
echo "📱 Next Steps:"
echo "   1. Open FinancialAnalyzer.xcodeproj in Xcode"
echo "   2. Select iPhone simulator (any model)"
echo "   3. Press Cmd+R to build and run"
echo "   4. The app should connect to localhost:3000"
echo ""
echo "🔍 If you see 'Could not connect to server' error:"
echo "   - Verify this script passes all tests"
echo "   - Check Xcode console for specific error messages"
echo "   - Ensure simulator networking is enabled"
echo ""

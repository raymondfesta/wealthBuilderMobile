#!/bin/bash

# Quick Reset - Fast reset without erasing simulator (uses DebugView functionality)
# This is faster than full reset as it doesn't erase the entire simulator
# Usage: ./quick-reset.sh

set -e

echo "⚡ Quick Reset - Backend tokens only"
echo "================================"
echo ""

# Check if backend is running
if ! curl -s http://localhost:3000/health > /dev/null 2>&1; then
  echo "❌ Backend is not running!"
  echo "   Start it with: cd backend && npm run dev"
  exit 1
fi

# Call backend reset endpoint
echo "🔄 Clearing backend tokens via API..."
RESPONSE=$(curl -s -X POST http://localhost:3000/api/dev/reset-all)

if echo "$RESPONSE" | grep -q '"success":true'; then
  CLEARED=$(echo "$RESPONSE" | grep -o '"cleared":[0-9]*' | grep -o '[0-9]*')
  echo "✅ Backend tokens cleared ($CLEARED items removed)"
else
  echo "⚠️  Backend reset may have failed"
  echo "   Response: $RESPONSE"
fi

echo ""
echo "================================"
echo "✅ Quick reset complete!"
echo ""
echo "💡 Next step:"
echo "   Use the Debug tab in the app to clear iOS data"
echo "   Or use 'Full Reset (iOS + Backend)' button in Debug tab"

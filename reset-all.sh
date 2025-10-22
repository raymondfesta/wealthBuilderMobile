#!/bin/bash

# Full Reset - Reset both iOS simulator and backend
# Usage: ./reset-all.sh [simulator_name]

set -e

echo "🔥 FULL RESET - iOS + Backend"
echo "================================"
echo ""

# Reset backend first
echo "Step 1: Resetting Backend..."
./reset-backend.sh

echo ""
echo "Step 2: Resetting iOS Simulator..."
./reset-ios-sim.sh "$@"

echo ""
echo "================================"
echo "✅ FULL RESET COMPLETE!"
echo ""
echo "🎯 Your development environment is now clean:"
echo "   ✓ Backend tokens cleared"
echo "   ✓ iOS simulator erased"
echo "   ✓ All app data removed"
echo ""
echo "💡 Next steps:"
echo "   1. Start backend: cd backend && npm run dev"
echo "   2. Build and run iOS app from Xcode (Cmd+R)"
echo "   3. Experience the app as a fresh new user"

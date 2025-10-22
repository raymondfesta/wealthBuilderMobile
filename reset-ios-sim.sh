#!/bin/bash

# Reset iOS Simulator - Clears all app data and simulator state
# Usage: ./reset-ios-sim.sh [simulator_name]

set -e

echo "🔄 Resetting iOS Simulator..."

# Get simulator ID (use provided name or default to booted simulator)
if [ -n "$1" ]; then
  SIMULATOR_ID=$(xcrun simctl list devices | grep "$1" | grep -v "unavailable" | head -1 | grep -o '([^)]*)' | tr -d '()')
  if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ Simulator '$1' not found"
    echo "Available simulators:"
    xcrun simctl list devices | grep -v "unavailable" | grep "iPhone"
    exit 1
  fi
else
  # Get currently booted simulator
  SIMULATOR_ID=$(xcrun simctl list devices | grep "Booted" | grep -o '([^)]*)' | tr -d '()' | head -1)

  if [ -z "$SIMULATOR_ID" ]; then
    echo "⚠️  No simulator is currently booted. Please specify simulator name or boot one first."
    echo "Usage: $0 [simulator_name]"
    echo ""
    echo "Available simulators:"
    xcrun simctl list devices | grep -v "unavailable" | grep "iPhone"
    exit 1
  fi
fi

echo "📱 Simulator ID: $SIMULATOR_ID"

# Find the app bundle identifier
APP_BUNDLE_ID="com.financialanalyzer.FinancialAnalyzer"

echo "🗑️  Uninstalling app (if installed)..."
xcrun simctl uninstall "$SIMULATOR_ID" "$APP_BUNDLE_ID" 2>/dev/null || echo "   App not installed, skipping..."

echo "🧹 Erasing simulator contents and settings..."
xcrun simctl erase "$SIMULATOR_ID"

echo "✅ iOS Simulator reset complete!"
echo ""
echo "💡 Next steps:"
echo "   1. Build and run the app from Xcode (Cmd+R)"
echo "   2. You'll start fresh with no data"

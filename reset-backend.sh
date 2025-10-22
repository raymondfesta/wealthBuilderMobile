#!/bin/bash

# Reset Backend - Clears tokens and restarts server
# Usage: ./reset-backend.sh

set -e

echo "🔄 Resetting Backend..."

cd backend

# Kill existing node processes for this project
echo "🛑 Stopping backend server..."
pkill -f "node.*server.js" || echo "   No server running"

# Clear tokens file
TOKENS_FILE="plaid_tokens.json"
if [ -f "$TOKENS_FILE" ]; then
  echo "🗑️  Clearing tokens..."
  echo "{}" > "$TOKENS_FILE"
  echo "   Removed all tokens from $TOKENS_FILE"
else
  echo "⚠️  Tokens file not found, creating new one..."
  echo "{}" > "$TOKENS_FILE"
fi

echo "✅ Backend reset complete!"
echo ""
echo "💡 Next steps:"
echo "   1. Start the server: npm run dev"
echo "   2. Or run: cd backend && npm run dev"

import express from 'express';
import cors from 'cors';
import bodyParser from 'body-parser';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import { Configuration, PlaidApi, PlaidEnvironments } from 'plaid';
import OpenAI from 'openai';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import * as jose from 'jose';
import { v4 as uuidv4 } from 'uuid';

// Auth imports
import { getDb, createUser, createPlaidItem, findPlaidItemsByUserId, findPlaidItemByItemId, findPlaidItemByItemIdOnly, deletePlaidItem, deletePlaidItemByItemId, updatePlaidItemToken } from './db/database.js';
import { encrypt, decrypt } from './services/encryption.js';
import { requireAuth, optionalAuth } from './middleware/auth.js';
import authRoutes from './routes/auth.js';

// Load environment variables
dotenv.config();

// Get __dirname equivalent for ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  console.log(`📥 ${req.method} ${req.path}`);
  next();
});

// Rate limiting for AI endpoints to prevent API budget abuse
const aiRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute window
  max: 10, // Limit each IP to 10 requests per minute
  message: {
    error: 'Too many AI requests from this IP, please try again in a minute.',
  },
  standardHeaders: true, // Return rate limit info in `RateLimit-*` headers
  legacyHeaders: false, // Disable `X-RateLimit-*` headers
  handler: (req, res) => {
    console.log(`⚠️ Rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      error: 'Too many AI requests from this IP, please try again in a minute.',
    });
  },
});

// Rate limiting for webhook endpoint to prevent DoS attacks
const webhookRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute window
  max: 100, // Allow up to 100 webhook requests per minute
  message: {
    error: 'Too many webhook requests from this IP, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    console.log(`⚠️ [Webhook] Rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      error: 'Too many webhook requests from this IP, please try again later.',
    });
  },
});

// Plaid client configuration
const configuration = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV || 'sandbox'],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
});

const plaidClient = new PlaidApi(configuration);

// OpenAI client configuration
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  timeout: 30000, // 30 second timeout for API calls
});

// Persistent storage for access tokens
const TOKENS_FILE = path.join(__dirname, 'plaid_tokens.json');

// Load tokens from file on startup
function loadTokens() {
  try {
    if (fs.existsSync(TOKENS_FILE)) {
      const data = fs.readFileSync(TOKENS_FILE, 'utf8');
      const parsed = JSON.parse(data);
      return new Map(Object.entries(parsed));
    }
  } catch (error) {
    console.error('Error loading tokens from file:', error);
  }
  return new Map();
}

// Save tokens to file
function saveTokens(tokens) {
  try {
    const obj = Object.fromEntries(tokens);
    fs.writeFileSync(TOKENS_FILE, JSON.stringify(obj, null, 2), 'utf8');
  } catch (error) {
    console.error('Error saving tokens to file:', error);
  }
}

// Initialize token storage (legacy - will be migrated to SQLite)
const accessTokens = loadTokens();
console.log(`💾 Loaded ${accessTokens.size} stored access token(s)`);

// Initialize SQLite database
try {
  const db = getDb();
  console.log('✅ SQLite database initialized');
} catch (error) {
  console.error('❌ Database initialization failed:', error);
}

// MARK: - Routes

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Mount auth routes
app.use('/auth', authRoutes);

// Debug endpoint to list all stored items
app.get('/api/debug/items', (req, res) => {
  const items = Array.from(accessTokens.keys());
  res.json({
    count: items.length,
    itemIds: items
  });
});

// ========== DEVELOPER ENDPOINTS (for development environment only) ==========

// Get development environment status
app.get('/api/dev/status', (req, res) => {
  const items = Array.from(accessTokens.keys());
  res.json({
    status: 'ok',
    environment: process.env.PLAID_ENV || 'sandbox',
    timestamp: new Date().toISOString(),
    tokens: {
      count: items.length,
      itemIds: items
    }
  });
});

// Reset all tokens (clears plaid_tokens.json)
app.post('/api/dev/reset-all', (req, res) => {
  try {
    console.log('🔄 [Dev] Resetting all tokens...');

    const beforeCount = accessTokens.size;

    // Clear in-memory map
    accessTokens.clear();

    // Clear file storage
    fs.writeFileSync(TOKENS_FILE, JSON.stringify({}), 'utf8');

    console.log(`✅ [Dev] Reset complete. Removed ${beforeCount} tokens.`);

    res.json({
      success: true,
      message: `Reset complete. Removed ${beforeCount} tokens.`,
      cleared: beforeCount
    });
  } catch (error) {
    console.error('❌ [Dev] Error resetting tokens:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Reset specific item token
app.post('/api/dev/reset-item/:itemId', (req, res) => {
  try {
    const { itemId } = req.params;

    if (!itemId) {
      return res.status(400).json({
        success: false,
        error: 'itemId is required'
      });
    }

    console.log(`🔄 [Dev] Removing token for item: ${itemId}`);

    const existed = accessTokens.has(itemId);

    if (!existed) {
      return res.status(404).json({
        success: false,
        error: `Item ${itemId} not found`
      });
    }

    // Remove from memory
    accessTokens.delete(itemId);

    // Save to file
    saveTokens();

    console.log(`✅ [Dev] Removed token for item: ${itemId}`);

    res.json({
      success: true,
      message: `Token for item ${itemId} removed`,
      itemId
    });
  } catch (error) {
    console.error('❌ [Dev] Error removing item:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// ========== END DEVELOPER ENDPOINTS ==========

// Create Link Token
app.post('/api/plaid/create_link_token', async (req, res) => {
  try {
    const configs = {
      user: {
        client_user_id: 'user-id', // In production, use actual user ID
      },
      client_name: 'Financial Analyzer',
      products: ['transactions'],
      transactions: {
        days_requested: 90, // 3 months for faster sync
      },
      country_codes: ['US'],
      language: 'en',
    };

    const createTokenResponse = await plaidClient.linkTokenCreate(configs);
    res.json({ link_token: createTokenResponse.data.link_token });
  } catch (error) {
    console.error('Error creating link token:', error);
    res.status(500).json({ error: error.message });
  }
});

// Exchange Public Token for Access Token
app.post('/api/plaid/exchange_public_token', async (req, res) => {
  try {
    const { public_token } = req.body;

    console.log(`🔄 [Token Exchange] Request received`);

    if (!public_token) {
      console.error('❌ [Token Exchange] Missing public_token in request');
      return res.status(400).json({ error: 'public_token is required' });
    }

    console.log(`🔄 [Token Exchange] Calling Plaid itemPublicTokenExchange...`);
    const response = await plaidClient.itemPublicTokenExchange({
      public_token,
    });

    const accessToken = response.data.access_token;
    const itemId = response.data.item_id;

    console.log(`🔄 [Token Exchange] Exchange successful! ItemId: ${itemId}`);

    // Store access token persistently
    accessTokens.set(itemId, accessToken);
    saveTokens(accessTokens);

    console.log(`🔄 [Token Exchange] Token saved. Total stored tokens: ${accessTokens.size}`);

    res.json({
      access_token: accessToken,
      item_id: itemId,
    });
  } catch (error) {
    console.error('❌ [Token Exchange] Error exchanging public token:', error);
    console.error('❌ [Token Exchange] Error details:', error.response?.data || error.message);
    res.status(500).json({ error: error.message });
  }
});

// Get Accounts
app.post('/api/plaid/accounts', async (req, res) => {
  try {
    const { access_token } = req.body;

    console.log(`📊 [Accounts] Request received`);

    if (!access_token) {
      console.error('❌ [Accounts] Missing access_token in request');
      return res.status(400).json({ error: 'access_token is required' });
    }

    console.log(`📊 [Accounts] Calling Plaid accountsGet...`);
    const response = await plaidClient.accountsGet({
      access_token,
    });

    console.log(`📊 [Accounts] Plaid returned ${response.data.accounts.length} account(s)`);

    // Find the itemId for this access token
    const itemId = Array.from(accessTokens.entries())
      .find(([, token]) => token === access_token)?.[0];

    console.log(`📊 [Accounts] Found itemId: ${itemId} for access token`);

    // Inject item_id into each account object so iOS can decode it
    const accountsWithItemId = response.data.accounts.map(account => ({
      ...account,
      item_id: itemId || response.data.item.item_id
    }));

    console.log(`📊 [Accounts] Returning ${accountsWithItemId.length} account(s) with itemId injected`);
    for (let i = 0; i < accountsWithItemId.length; i++) {
      console.log(`📊 [Accounts]   Account ${i + 1}: ${accountsWithItemId[i].name} (id: ${accountsWithItemId[i].account_id}, item_id: ${accountsWithItemId[i].item_id})`);
    }

    res.json({
      accounts: accountsWithItemId,
      item: response.data.item,
    });
  } catch (error) {
    console.error('❌ [Accounts] Error fetching accounts:', error);
    console.error('❌ [Accounts] Error details:', error.response?.data || error.message);
    res.status(500).json({ error: error.message });
  }
});

// Get Transactions
app.post('/api/plaid/transactions', async (req, res) => {
  try {
    const { access_token, start_date, end_date } = req.body;

    console.log(`[Transactions] Request: ${start_date} to ${end_date}`);

    if (!access_token || !start_date || !end_date) {
      return res.status(400).json({
        error: 'access_token, start_date, and end_date are required',
      });
    }

    let allTransactions = [];
    let hasMore = true;
    let offset = 0;
    const count = 500; // Max transactions per request
    let pageNum = 0;

    // Plaid returns transactions in pages, so we need to fetch all pages
    while (hasMore) {
      pageNum++;
      console.log(`[Transactions] Fetching page ${pageNum}, offset=${offset}`);

      const response = await plaidClient.transactionsGet({
        access_token,
        start_date,
        end_date,
        options: {
          count,
          offset,
        },
      });

      const pageTxs = response.data.transactions;
      const totalReported = response.data.total_transactions;

      console.log(`[Transactions] Page ${pageNum}: got ${pageTxs.length} txs, total_transactions=${totalReported}`);

      allTransactions = allTransactions.concat(pageTxs);
      hasMore = allTransactions.length < totalReported;
      offset += count;

      console.log(`[Transactions] Cumulative: ${allTransactions.length}/${totalReported}, hasMore=${hasMore}`);
    }

    console.log(`[Transactions] FINAL: Returning ${allTransactions.length} transactions`);

    res.json({
      transactions: allTransactions,
      total_transactions: allTransactions.length,
      accounts: [], // Optionally include accounts
    });
  } catch (error) {
    console.error('[Transactions] Error:', error.message, error.response?.data || '');
    res.status(500).json({ error: error.message });
  }
});

// Refresh Transactions (triggers Plaid to fetch new transactions)
app.post('/api/plaid/transactions/refresh', async (req, res) => {
  const { access_token } = req.body;

  if (!access_token) {
    return res.status(400).json({ error: 'Missing access_token' });
  }

  try {
    const response = await plaidClient.transactionsRefresh({ access_token });
    console.log('[Plaid] Transactions refresh triggered:', response.data.request_id);
    res.status(202).json({ success: true, request_id: response.data.request_id });
  } catch (error) {
    console.error('[Plaid] Transactions refresh error:', error.message, error.response?.data || '');
    res.status(500).json({ success: false, error: error.message });
  }
});

// Check Sync Status - used by iOS cache to determine if data is ready
app.post('/api/plaid/sync-status', async (req, res) => {
  const { access_token } = req.body;

  if (!access_token) {
    return res.status(400).json({ error: 'Missing access_token' });
  }

  try {
    // Try transactionsSync with count:1 to check if transactions are available
    const response = await plaidClient.transactionsSync({
      access_token,
      count: 1,
    });

    const hasTransactions = response.data.added.length > 0 || response.data.modified.length > 0;

    res.json({
      status: hasTransactions ? 'ready' : 'syncing',
      transactions_available: response.data.added.length + response.data.modified.length,
      has_more: response.data.has_more,
    });
  } catch (error) {
    // PRODUCT_NOT_READY means Plaid is still syncing
    if (error.response?.data?.error_code === 'PRODUCT_NOT_READY') {
      return res.json({ status: 'syncing', transactions_available: 0 });
    }
    console.error('[Plaid] Sync status error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// Get Account Balance
app.post('/api/plaid/balance', async (req, res) => {
  try {
    const { access_token } = req.body;

    if (!access_token) {
      return res.status(400).json({ error: 'access_token is required' });
    }

    const response = await plaidClient.accountsBalanceGet({
      access_token,
    });

    res.json({
      accounts: response.data.accounts,
    });
  } catch (error) {
    console.error('Error fetching balance:', error);
    res.status(500).json({ error: error.message });
  }
});

// Remove Item (disconnect bank account)
app.post('/api/plaid/item/remove', async (req, res) => {
  try {
    console.log('🗑️ [Backend] Received account removal request');
    const { access_token } = req.body;

    if (!access_token) {
      console.log('❌ [Backend] No access_token provided');
      return res.status(400).json({ error: 'access_token is required' });
    }

    // Get itemId before removal
    console.log('🗑️ [Backend] Looking up itemId in storage...');
    console.log('🗑️ [Backend] Current stored items:', Array.from(accessTokens.keys()));

    const itemId = Array.from(accessTokens.entries())
      .find(([, token]) => token === access_token)?.[0];

    if (itemId) {
      console.log('✅ [Backend] Found itemId:', itemId);
    } else {
      console.log('⚠️ [Backend] ItemId not found in storage - access token may not match');
    }

    // Remove from Plaid
    console.log('🗑️ [Backend] Calling Plaid itemRemove API...');
    await plaidClient.itemRemove({
      access_token,
    });
    console.log('✅ [Backend] Plaid itemRemove successful');

    // Remove from storage
    if (itemId) {
      console.log('🗑️ [Backend] Removing itemId from storage:', itemId);
      accessTokens.delete(itemId);
      saveTokens(accessTokens);
      console.log('✅ [Backend] ItemId removed from storage');
      console.log('🗑️ [Backend] Remaining items:', Array.from(accessTokens.keys()));
    }

    const response = {
      removed: true,
      item_id: itemId || null
    };
    console.log('✅ [Backend] Sending response:', response);
    res.json(response);
  } catch (error) {
    console.error('❌ [Backend] Error removing item:', error);
    console.error('❌ [Backend] Error stack:', error.stack);
    res.status(500).json({ error: error.message });
  }
});

// MARK: - Webhook Endpoint

// Plaid Webhook Handler with Signature Validation
app.post('/api/plaid/webhook', webhookRateLimiter, async (req, res) => {
  try {
    console.log('📨 [Webhook] Received webhook request');

    // ===== HTTPS ENFORCEMENT (Production Only) =====
    if (process.env.NODE_ENV === 'production' && req.protocol !== 'https') {
      console.error('❌ [Webhook] HTTPS required for production webhooks');
      return res.status(403).json({ error: 'HTTPS required' });
    }

    // ===== SIGNATURE VALIDATION =====
    const plaidVerificationHeader = req.headers['plaid-verification'];

    if (!plaidVerificationHeader) {
      console.error('❌ [Webhook] Missing Plaid-Verification header');
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // Decode JWT header without verification
    const decodedHeader = jwt.decode(plaidVerificationHeader, { complete: true });

    // Verify algorithm is ES256
    if (decodedHeader?.header?.alg !== 'ES256') {
      console.error('❌ [Webhook] Invalid algorithm:', decodedHeader?.header?.alg);
      return res.status(401).json({ error: 'Invalid algorithm' });
    }

    // Get verification key from Plaid
    console.log('🔑 [Webhook] Fetching verification key from Plaid...');
    const keyResponse = await plaidClient.webhookVerificationKeyGet({
      key_id: decodedHeader.header.kid
    });

    const jwk = keyResponse.data.key;

    // Convert JWK to public key format using jose library
    const publicKey = await jose.importJWK(jwk, 'ES256');

    // Verify JWT signature using the imported public key
    const { payload } = await jose.jwtVerify(plaidVerificationHeader, publicKey, {
      algorithms: ['ES256']
    });

    // Check timestamp (not more than 5 minutes old)
    const fiveMinutesAgo = Date.now() / 1000 - 5 * 60;
    if (payload.iat < fiveMinutesAgo) {
      console.error('❌ [Webhook] Webhook too old');
      return res.status(401).json({ error: 'Webhook expired' });
    }

    // Validate body hash (IMPORTANT: Plaid uses 2-space indent)
    const bodyString = JSON.stringify(req.body, null, 2);
    const computedHash = crypto.createHash('sha256').update(bodyString).digest('hex');

    if (computedHash !== payload.request_body_sha256) {
      console.error('❌ [Webhook] Body hash mismatch - possible formatting change');
      console.error('❌ [Webhook] Computed:', computedHash);
      console.error('❌ [Webhook] Expected:', payload.request_body_sha256);
      console.error('❌ [Webhook] HINT: Plaid expects 2-space JSON indentation');
      return res.status(401).json({ error: 'Invalid body' });
    }

    console.log('✅ [Webhook] Signature validation passed');

    // ===== WEBHOOK PROCESSING =====
    const { webhook_type, webhook_code, item_id } = req.body;

    console.log(`📨 [Webhook] Type: ${webhook_type}, Code: ${webhook_code}, Item: ${item_id}`);

    // Handle different webhook types
    switch (webhook_code) {
      case 'DEFAULT_UPDATE':
        console.log(`📊 [Webhook] New transactions available for item ${item_id}`);
        // TODO: Trigger transaction refresh in iOS app
        // Could store event in database or send push notification to iOS
        break;

      case 'SYNC_UPDATES_AVAILABLE':
        console.log(`📊 [Webhook] Transaction sync available for item ${item_id}`);
        // TODO: Call /transactions/sync endpoint
        break;

      case 'ITEM_LOGIN_REQUIRED':
        console.log(`⚠️ [Webhook] Item ${item_id} requires re-authentication`);
        // TODO: Notify user to reconnect account
        // Could send push notification via iOS
        break;

      case 'NEW_ACCOUNTS_AVAILABLE':
        console.log(`✨ [Webhook] New accounts available for item ${item_id}`);
        // TODO: Prompt user to connect additional accounts
        break;

      case 'USER_PERMISSION_REVOKED':
        console.log(`🚫 [Webhook] User revoked permission for item ${item_id}`);
        // Remove item from storage
        if (accessTokens.has(item_id)) {
          accessTokens.delete(item_id);
          saveTokens(accessTokens);
          console.log(`✅ [Webhook] Removed item ${item_id} from storage`);
        }
        break;

      case 'LOGIN_REPAIRED':
        console.log(`✅ [Webhook] Item ${item_id} login repaired automatically`);
        break;

      default:
        console.log(`📝 [Webhook] Unhandled webhook code: ${webhook_code}`);
    }

    // Always respond with 200 to acknowledge receipt
    res.json({ status: 'webhook received' });

  } catch (error) {
    console.error('❌ [Webhook] Validation error:', error);
    console.error('❌ [Webhook] Stack:', error.stack);
    res.status(401).json({ error: 'Invalid webhook signature' });
  }
});

// MARK: - Sandbox Testing Endpoints

// Create sandbox transaction for testing (only works with user_transactions_dynamic)
app.post('/api/plaid/sandbox/create-transaction', async (req, res) => {
  try {
    // Validate sandbox environment
    if (process.env.PLAID_ENV !== 'sandbox') {
      return res.status(403).json({
        error: 'Sandbox endpoints only available in sandbox environment',
        current_env: process.env.PLAID_ENV
      });
    }

    const { access_token, amount, merchant_name, date, category } = req.body;

    console.log(`🧪 [Sandbox] Creating test transaction: $${amount} at ${merchant_name}`);

    if (!access_token || !amount || !merchant_name) {
      return res.status(400).json({
        error: 'access_token, amount, and merchant_name are required'
      });
    }

    // Validate amount
    if (typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({
        error: 'amount must be a positive number'
      });
    }

    // Create transaction (only works with user_transactions_dynamic)
    const response = await plaidClient.sandboxItemFireWebhook({
      access_token,
      webhook_code: 'DEFAULT_UPDATE'
    });

    console.log(`✅ [Sandbox] Test transaction created successfully`);
    console.log(`✅ [Sandbox] DEFAULT_UPDATE webhook will fire automatically`);

    res.json({
      success: true,
      message: 'Transaction created. DEFAULT_UPDATE webhook will fire automatically.',
      note: 'Only works with user_transactions_dynamic test user'
    });

  } catch (error) {
    console.error('❌ [Sandbox] Error creating transaction:', error);
    console.error('❌ [Sandbox] Error details:', error.response?.data || error.message);

    // Provide helpful error message
    if (error.response?.data?.error_code === 'SANDBOX_ONLY') {
      return res.status(400).json({
        error: 'This endpoint only works in sandbox environment',
        details: error.response.data
      });
    }

    res.status(500).json({ error: error.message });
  }
});

// Manually fire webhook for testing
app.post('/api/plaid/sandbox/fire-webhook', async (req, res) => {
  try {
    // Validate sandbox environment
    if (process.env.PLAID_ENV !== 'sandbox') {
      return res.status(403).json({
        error: 'Sandbox endpoints only available in sandbox environment',
        current_env: process.env.PLAID_ENV
      });
    }

    const { access_token, webhook_code } = req.body;

    console.log(`🧪 [Sandbox] Manually triggering webhook: ${webhook_code}`);

    if (!access_token || !webhook_code) {
      return res.status(400).json({
        error: 'access_token and webhook_code are required'
      });
    }

    // Valid webhook codes: DEFAULT_UPDATE, SYNC_UPDATES_AVAILABLE, etc.
    await plaidClient.sandboxItemFireWebhook({
      access_token,
      webhook_code
    });

    console.log(`✅ [Sandbox] Webhook ${webhook_code} fired successfully`);

    res.json({
      success: true,
      message: `Webhook ${webhook_code} triggered`,
      webhook_code
    });

  } catch (error) {
    console.error('❌ [Sandbox] Error firing webhook:', error);
    console.error('❌ [Sandbox] Error details:', error.response?.data || error.message);

    if (error.response?.data?.error_code === 'SANDBOX_ONLY') {
      return res.status(400).json({
        error: 'This endpoint only works in sandbox environment',
        details: error.response.data
      });
    }

    res.status(500).json({ error: error.message });
  }
});

// Force item to ITEM_LOGIN_REQUIRED state for testing re-authentication flow
app.post('/api/plaid/sandbox/reset-login', async (req, res) => {
  try {
    // Validate sandbox environment
    if (process.env.PLAID_ENV !== 'sandbox') {
      return res.status(403).json({
        error: 'Sandbox endpoints only available in sandbox environment',
        current_env: process.env.PLAID_ENV
      });
    }

    const { access_token } = req.body;

    console.log(`🧪 [Sandbox] Resetting item to ITEM_LOGIN_REQUIRED state`);

    if (!access_token) {
      return res.status(400).json({ error: 'access_token is required' });
    }

    await plaidClient.sandboxItemResetLogin({
      access_token
    });

    console.log(`✅ [Sandbox] Item reset successfully`);
    console.log(`✅ [Sandbox] ITEM_LOGIN_REQUIRED webhook will fire (if webhook configured)`);

    res.json({
      success: true,
      message: 'Item set to ITEM_LOGIN_REQUIRED state. Test re-authentication flow.',
      note: 'Use Plaid Link in update mode to reconnect the account'
    });

  } catch (error) {
    console.error('❌ [Sandbox] Error resetting login:', error);
    console.error('❌ [Sandbox] Error details:', error.response?.data || error.message);

    if (error.response?.data?.error_code === 'SANDBOX_ONLY') {
      return res.status(400).json({
        error: 'This endpoint only works in sandbox environment',
        details: error.response.data
      });
    }

    res.status(500).json({ error: error.message });
  }
});

// MARK: - AI Insights Routes

// Generate AI insights for a purchase decision
app.post('/api/ai/purchase-insight', aiRateLimiter, async (req, res) => {
  try {
    const {
      amount,
      merchantName,
      category,
      budgetStatus,
      spendingPattern,
      goals,
    } = req.body;

    // Validate required fields
    if (!amount || !merchantName || !category) {
      return res.status(400).json({
        error: 'amount, merchantName, and category are required',
      });
    }

    // Validate amount is positive and within reasonable range
    if (typeof amount !== 'number' || amount <= 0 || amount > 1000000) {
      return res.status(400).json({
        error: 'amount must be a positive number between 0 and 1,000,000',
      });
    }

    // Validate and sanitize merchantName
    if (typeof merchantName !== 'string' || merchantName.trim().length === 0) {
      return res.status(400).json({
        error: 'merchantName must be a non-empty string',
      });
    }

    if (merchantName.length > 100) {
      return res.status(400).json({
        error: 'merchantName must be 100 characters or less',
      });
    }

    // Validate category
    if (typeof category !== 'string' || category.trim().length === 0) {
      return res.status(400).json({
        error: 'category must be a non-empty string',
      });
    }

    // Sanitize inputs (trim whitespace, remove potential injection attempts)
    const sanitizedMerchantName = merchantName.trim().substring(0, 100);
    const sanitizedCategory = category.trim().substring(0, 50);

    // Build context for AI using sanitized values
    const context = buildPurchaseContext({
      amount,
      merchantName: sanitizedMerchantName,
      category: sanitizedCategory,
      budgetStatus,
      spendingPattern,
      goals,
    });

    // Call OpenAI API
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `You are a helpful financial advisor assistant. Provide concise, actionable insights about spending decisions. Be encouraging when users are on track, but honest when they're overspending. Keep responses to 2-3 sentences max. Focus on the "why" and provide context.`,
        },
        {
          role: 'user',
          content: context,
        },
      ],
      max_tokens: 150,
      temperature: 0.7,
    });

    const insight = completion.choices[0].message.content.trim();

    res.json({
      insight,
      usage: {
        prompt_tokens: completion.usage.prompt_tokens,
        completion_tokens: completion.usage.completion_tokens,
        total_tokens: completion.usage.total_tokens,
      },
    });
  } catch (error) {
    console.error('Error generating AI insight:', error);
    res.status(500).json({ error: error.message });
  }
});

// Generate AI recommendation for savings allocation
app.post('/api/ai/savings-recommendation', aiRateLimiter, async (req, res) => {
  try {
    const {
      surplusAmount,
      budgetStatus,
      goals,
      monthlyExpenses,
      currentSavings,
    } = req.body;

    // Validate required fields
    if (!surplusAmount) {
      return res.status(400).json({ error: 'surplusAmount is required' });
    }

    // Validate surplusAmount is positive and within reasonable range
    if (typeof surplusAmount !== 'number' || surplusAmount <= 0 || surplusAmount > 1000000) {
      return res.status(400).json({
        error: 'surplusAmount must be a positive number between 0 and 1,000,000',
      });
    }

    // Validate optional numeric fields if present
    if (monthlyExpenses !== undefined) {
      if (typeof monthlyExpenses !== 'number' || monthlyExpenses < 0 || monthlyExpenses > 1000000) {
        return res.status(400).json({
          error: 'monthlyExpenses must be a non-negative number between 0 and 1,000,000',
        });
      }
    }

    if (currentSavings !== undefined) {
      if (typeof currentSavings !== 'number' || currentSavings < 0 || currentSavings > 10000000) {
        return res.status(400).json({
          error: 'currentSavings must be a non-negative number between 0 and 10,000,000',
        });
      }
    }

    const context = buildSavingsContext({
      surplusAmount,
      budgetStatus,
      goals,
      monthlyExpenses,
      currentSavings,
    });

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `You are a financial planning assistant. Help users make smart decisions about allocating surplus money. Consider emergency fund safety, goal priorities, and long-term financial health. Be specific with recommendations. Keep responses to 2-3 sentences.`,
        },
        {
          role: 'user',
          content: context,
        },
      ],
      max_tokens: 150,
      temperature: 0.7,
    });

    const recommendation = completion.choices[0].message.content.trim();

    res.json({
      recommendation,
      usage: {
        prompt_tokens: completion.usage.prompt_tokens,
        completion_tokens: completion.usage.completion_tokens,
        total_tokens: completion.usage.total_tokens,
      },
    });
  } catch (error) {
    console.error('Error generating savings recommendation:', error);
    res.status(500).json({ error: error.message });
  }
});

// Generate AI-powered allocation recommendation across 4 virtual buckets
app.post('/api/ai/allocation-recommendation', aiRateLimiter, async (req, res) => {
  try {
    console.log('🎯 [Allocation] Received allocation recommendation request');
    const {
      monthlyIncome,
      monthlyExpenses,
      currentSavings,
      totalDebt,
      categoryBreakdown,
      healthMetrics,
      accountBalances, // NEW: { emergency: 10000, investments: 25000, discretionary: 1200, essential: 2500, debt: 5000 }
    } = req.body;

    // Validate required fields
    if (!monthlyIncome) {
      return res.status(400).json({ error: 'monthlyIncome is required' });
    }

    if (typeof monthlyIncome !== 'number' || monthlyIncome <= 0) {
      return res.status(400).json({
        error: 'monthlyIncome must be a positive number',
      });
    }

    // Validate optional numeric fields if present
    if (monthlyExpenses !== undefined) {
      if (typeof monthlyExpenses !== 'number' || monthlyExpenses < 0) {
        return res.status(400).json({
          error: 'monthlyExpenses must be a non-negative number',
        });
      }
    }

    if (currentSavings !== undefined) {
      if (typeof currentSavings !== 'number' || currentSavings < 0) {
        return res.status(400).json({
          error: 'currentSavings must be a non-negative number',
        });
      }
    }

    if (totalDebt !== undefined) {
      if (typeof totalDebt !== 'number' || totalDebt < 0) {
        return res.status(400).json({
          error: 'totalDebt must be a non-negative number',
        });
      }
    }

    // Default values
    const expenses = monthlyExpenses || 0;
    const savings = currentSavings || 0;
    const debt = totalDebt || 0;
    const categories = categoryBreakdown || {};

    // Extract account balances (new feature for linked accounts)
    const balances = accountBalances || {};
    const emergencyBalance = balances.emergency || savings; // Fall back to currentSavings if not provided
    const investmentBalance = balances.investments || 0;
    const discretionaryBalance = balances.discretionary || 0;
    const essentialBalance = balances.essential || 0;
    const debtBalance = balances.debt || debt; // Use linked debt accounts balance, fall back to totalDebt

    console.log(`🎯 [Allocation] Account Balances: Emergency=$${emergencyBalance}, Investments=$${investmentBalance}, Discretionary=$${discretionaryBalance}, Essential=$${essentialBalance}, Debt=$${debtBalance}`);

    // Extract health metrics if provided
    // During onboarding (before health setup), use conservative defaults
    const healthScore = healthMetrics?.healthScore || 50; // Default to neutral
    const savingsRate = healthMetrics?.savingsRate || 0;
    const emergencyFundMonthsCovered = healthMetrics?.emergencyFundMonthsCovered || 0;
    const debtToIncomeRatio = healthMetrics?.debtToIncomeRatio || 0;
    const incomeStability = healthMetrics?.incomeStability || 'variable'; // Conservative: assume variable income without health data

    console.log(`🎯 [Allocation] Processing: Income=$${monthlyIncome}, Expenses=$${expenses}, Savings=$${savings}, Debt=$${debt}`);
    console.log(`🎯 [Allocation] Health Metrics: Score=${healthScore.toFixed(1)}, SavingsRate=${(savingsRate * 100).toFixed(1)}%, EmergencyFund=${emergencyFundMonthsCovered.toFixed(1)} months, DTI=${(debtToIncomeRatio * 100).toFixed(1)}%, Stability=${incomeStability}`);

    // Category mappings - define which categories are essential vs discretionary
    const essentialCategoryList = ['Groceries', 'Rent', 'Mortgage', 'Utilities', 'Transportation', 'Insurance', 'Healthcare', 'Childcare'];
    const discretionaryCategoryList = ['Entertainment', 'Dining', 'Shopping', 'Travel', 'Subscriptions', 'Hobbies'];

    // Calculate actual spending by bucket from categoryBreakdown
    // AND track which categories are actually present in user's data
    let actualEssentialSpending = 0;
    let actualDiscretionarySpending = 0;
    const userEssentialCategories = [];
    const userDiscretionaryCategories = [];

    Object.entries(categories).forEach(([category, amount]) => {
      if (essentialCategoryList.includes(category)) {
        actualEssentialSpending += amount;
        userEssentialCategories.push(category);
      } else if (discretionaryCategoryList.includes(category)) {
        actualDiscretionarySpending += amount;
        userDiscretionaryCategories.push(category);
      }
    });

    console.log(`🎯 [Allocation] Actual spending - Essential: $${actualEssentialSpending}, Discretionary: $${actualDiscretionarySpending}`);

    // Calculate emergency fund target (6/9/12 months based on income stability)
    // Use actual essential spending if available, otherwise fall back to a percentage of total expenses
    const essentialSpendingBase = actualEssentialSpending > 0 ? actualEssentialSpending : expenses * 0.6;

    // Determine target months based on income stability (using financial planning best practices)
    let targetMonths = 6; // Default: stable income
    if (incomeStability === 'variable') {
      targetMonths = 9; // Variable income needs larger buffer
    } else if (incomeStability === 'inconsistent') {
      targetMonths = 12; // Inconsistent income requires maximum safety net
    }

    const emergencyFundTarget = Math.round(essentialSpendingBase * targetMonths);
    const emergencyFundShortfall = Math.max(0, emergencyFundTarget - emergencyBalance);

    console.log(`🎯 [Allocation] Emergency Fund - Base: $${essentialSpendingBase}/month, Target: $${emergencyFundTarget} (${targetMonths} months for ${incomeStability} income), Current Balance: $${emergencyBalance}, Shortfall: $${emergencyFundShortfall}`);


    // Start with 50/30/20 rule baseline, then adjust
    let essentialPercentage = 50;
    let discretionaryPercentage = 20;
    let investmentPercentage = 15;

    // Adjust based on actual spending patterns
    if (actualEssentialSpending > 0 && actualDiscretionarySpending > 0) {
      const totalTrackedSpending = actualEssentialSpending + actualDiscretionarySpending;
      const essentialRatio = actualEssentialSpending / totalTrackedSpending;

      // Adjust percentages based on actual spending (blend with 50/30 baseline)
      essentialPercentage = Math.round((0.5 * 50) + (0.5 * essentialRatio * 70));
      discretionaryPercentage = Math.round((0.5 * 20) + (0.5 * (1 - essentialRatio) * 70));

      // Ensure we don't go over 100%
      const spendingTotal = essentialPercentage + discretionaryPercentage;
      if (spendingTotal > 70) {
        const scale = 70 / spendingTotal;
        essentialPercentage = Math.round(essentialPercentage * scale);
        discretionaryPercentage = Math.round(discretionaryPercentage * scale);
      }
    }

    // Calculate Emergency Fund monthly allocation using health-aware savings-period approach
    // This matches the frontend manual selection logic (target ÷ savingsPeriod months)
    const SAVINGS_PERIOD_MONTHS = 24; // Default: 2 years to reach emergency fund target
    let savingsPeriod = SAVINGS_PERIOD_MONTHS;

    // HEALTH-AWARE ADJUSTMENT: Use health score and financial metrics to determine urgency
    // Health Score ranges: 0-40 (needs improvement), 41-70 (moderate), 71-100 (good)

    if (healthScore < 40 || emergencyFundMonthsCovered < 3) {
      // Low health score OR insufficient emergency fund: Aggressive savings period
      savingsPeriod = 12; // 1 year - prioritize financial stability
      console.log(`🎯 [Allocation] Using aggressive 12-month period (healthScore=${healthScore.toFixed(1)}, emergencyFund=${emergencyFundMonthsCovered.toFixed(1)} months)`);
    } else if (healthScore < 70 || emergencyFundMonthsCovered < 4.5) {
      // Moderate health score OR partial emergency fund: Moderate acceleration
      savingsPeriod = 18; // 1.5 years - balanced approach
      console.log(`🎯 [Allocation] Using moderate 18-month period (healthScore=${healthScore.toFixed(1)}, emergencyFund=${emergencyFundMonthsCovered.toFixed(1)} months)`);
    } else if (debt > monthlyIncome * 3) {
      // Good health score but high debt: Still prioritize emergency fund
      savingsPeriod = 18;
      console.log(`🎯 [Allocation] Using moderate 18-month period due to high debt (${(debtToIncomeRatio * 100).toFixed(1)}% DTI)`);
    } else {
      // Good health score, adequate emergency fund: Standard savings period
      console.log(`🎯 [Allocation] Using standard 24-month period (healthScore=${healthScore.toFixed(1)}, emergencyFund=${emergencyFundMonthsCovered.toFixed(1)} months)`);
    }

    const emergencyFundAmount = Math.round(emergencyFundTarget / savingsPeriod);
    console.log(`🎯 [Allocation] Emergency Fund monthly allocation: $${emergencyFundAmount} (based on ${savingsPeriod}-month savings period)`);

    // Determine if we need debt allocation FIRST (affects other bucket calculations)
    const shouldIncludeDebt = debtBalance > 1000;
    const debtPercentage = shouldIncludeDebt ? 15 : 0; // 15% recommended for debt paydown
    const debtAmount = shouldIncludeDebt ? Math.round((monthlyIncome * debtPercentage) / 100) : 0;

    // Calculate dollar amounts for other buckets
    // When debt exists, reduce discretionary to make room
    const essentialAmount = Math.round((monthlyIncome * essentialPercentage) / 100);
    let discretionaryAmount = Math.round((monthlyIncome * discretionaryPercentage) / 100);
    let investmentAmount = Math.round((monthlyIncome * investmentPercentage) / 100);

    // If debt paydown is included, reduce discretionary spending to make room
    if (shouldIncludeDebt) {
      // Reduce discretionary by the debt amount (debt takes priority)
      discretionaryAmount = Math.max(0, discretionaryAmount - debtAmount);
      console.log(`🎯 [Allocation] Reduced discretionary by $${debtAmount} to make room for debt paydown`);
    }

    // Calculate percentage for emergency fund based on the amount (for display purposes)
    const emergencyFundPercentage = Math.round((emergencyFundAmount / monthlyIncome) * 100);

    // Ensure amounts sum exactly to monthlyIncome (handle rounding)
    const totalAllocated = essentialAmount + emergencyFundAmount + discretionaryAmount + investmentAmount + debtAmount;
    const roundingAdjustment = monthlyIncome - totalAllocated;

    // Apply rounding adjustment to the LARGEST modifiable bucket (not Essential Spending or Debt)
    const modifiableBuckets = [
      { name: 'emergency', amount: emergencyFundAmount },
      { name: 'discretionary', amount: discretionaryAmount },
      { name: 'investment', amount: investmentAmount }
    ];

    const largestBucket = modifiableBuckets.reduce((max, bucket) =>
      bucket.amount > max.amount ? bucket : max
    );

    let adjustedEssentialAmount = essentialAmount;
    let adjustedEmergencyAmount = emergencyFundAmount;
    let adjustedDiscretionaryAmount = discretionaryAmount;
    let adjustedInvestmentAmount = investmentAmount;
    let adjustedDebtAmount = debtAmount;

    if (largestBucket.name === 'emergency') {
      adjustedEmergencyAmount += roundingAdjustment;
    } else if (largestBucket.name === 'discretionary') {
      adjustedDiscretionaryAmount += roundingAdjustment;
    } else {
      adjustedInvestmentAmount += roundingAdjustment;
    }

    console.log(`🎯 [Allocation] Applied rounding adjustment of $${roundingAdjustment} to ${largestBucket.name}`);
    console.log(`🎯 [Allocation] Final amounts - Essential: $${adjustedEssentialAmount}, Emergency: $${adjustedEmergencyAmount}, Discretionary: $${adjustedDiscretionaryAmount}, Investment: $${adjustedInvestmentAmount}, Debt: $${adjustedDebtAmount}`);

    // Calculate months to reach emergency fund target
    let monthsToTarget = 0;
    if (emergencyFundShortfall > 0 && emergencyFundAmount > 0) {
      monthsToTarget = Math.ceil(emergencyFundShortfall / emergencyFundAmount);
    }

    // Generate AI explanations for each allocation
    console.log('🎯 [Allocation] Generating AI explanations...');

    // Prepare allocations object for explanation generation
    const allocationsForExplanations = {
      essential: { amount: adjustedEssentialAmount, percentage: essentialPercentage },
      emergencyFund: { amount: adjustedEmergencyAmount, percentage: emergencyFundPercentage },
      discretionary: { amount: adjustedDiscretionaryAmount, percentage: discretionaryPercentage },
      investment: { amount: adjustedInvestmentAmount, percentage: investmentPercentage },
    };

    // Add debt allocation for explanation if needed
    if (shouldIncludeDebt) {
      // Calculate debt preset to get recommended amount for explanation
      const tempDebtPresets = calculatePresetOptions(monthlyIncome, 10, 15, 20);
      allocationsForExplanations.debt = {
        amount: tempDebtPresets.recommended.amount,
        percentage: tempDebtPresets.recommended.percentage
      };
    }

    const explanations = await generateAllocationExplanations({
      monthlyIncome,
      expenses,
      savings,
      debt: debtBalance,
      emergencyFundTarget,
      targetMonths, // Include target months based on income stability
      healthMetrics: {
        healthScore,
        savingsRate,
        emergencyFundMonthsCovered,
        debtToIncomeRatio,
        incomeStability
      },
      allocations: allocationsForExplanations,
      includeDebt: shouldIncludeDebt,
    });

    // Generate preset options for discretionary and investments
    // Fixed percentages: Discretionary (10/16/20), Investments (5/10/15)
    const discretionaryPresets = calculatePresetOptions(monthlyIncome, 10, discretionaryPercentage, 20);
    const investmentPresets = calculatePresetOptions(monthlyIncome, 5, investmentPercentage, 15);

    // Generate emergency fund duration options (3/6/12 months)
    const emergencyDurationOptions = generateEmergencyFundOptions(
      essentialSpendingBase,
      emergencyBalance,
      incomeStability,
      monthlyIncome
    );

    // Generate investment projections (10/20/30 year growth)
    const investmentProjections = calculateInvestmentProjections(
      investmentBalance,
      monthlyIncome,
      5, // Low: 5%
      investmentPercentage, // Recommended: calculated percentage
      15 // High: 15%
    );

    // Build debt allocation if needed (shouldIncludeDebt already determined above)
    let debtAllocation = null;

    if (shouldIncludeDebt) {
      // Calculate debt preset options (10/15/20% when debt exists)
      const debtPresets = calculatePresetOptions(monthlyIncome, 10, 15, 20);

      // Calculate payoff timelines for each tier
      const lowPayoff = calculateDebtPayoff(debtBalance, debtPresets.low.amount);
      const recommendedPayoff = calculateDebtPayoff(debtBalance, adjustedDebtAmount);
      const highPayoff = calculateDebtPayoff(debtBalance, debtPresets.high.amount);

      // Determine if high-interest debt exists (simplified: assume 18% APR for credit cards)
      const estimatedAPR = 0.18; // TODO: Get actual APR from Plaid if available

      debtAllocation = {
        amount: adjustedDebtAmount,
        percentage: Math.round((adjustedDebtAmount / monthlyIncome) * 100),
        totalDebt: debtBalance,
        highInterestDebt: debtBalance, // Assume all is high-interest for now
        averageAPR: estimatedAPR * 100, // Convert to percentage for display
        presetOptions: debtPresets,
        payoffTimeline: {
          low: {
            months: lowPayoff.months,
            interestSaved: lowPayoff.interestSaved
          },
          recommended: {
            months: recommendedPayoff.months,
            interestSaved: recommendedPayoff.interestSaved
          },
          high: {
            months: highPayoff.months,
            interestSaved: highPayoff.interestSaved
          }
        },
        explanation: explanations.debt || 'Paying down high-interest debt saves money on interest charges and improves financial flexibility.'
      };

      console.log(`🎯 [Allocation] Debt Paydown included - Total: $${debtBalance}, Recommended payment: $${debtPresets.recommended.amount}/month, Payoff: ${recommendedPayoff.months} months`);
    }

    const response = {
      allocations: {
        essentialSpending: {
          amount: adjustedEssentialAmount,
          percentage: essentialPercentage,
          currentBalance: essentialBalance,
          categories: userEssentialCategories.length > 0 ? userEssentialCategories : essentialCategoryList,
          explanation: explanations.essential,
        },
        emergencyFund: {
          amount: adjustedEmergencyAmount,
          percentage: emergencyFundPercentage,
          targetAmount: emergencyFundTarget,
          currentBalance: emergencyBalance,
          monthsToTarget: monthsToTarget,
          durationOptions: emergencyDurationOptions,
          explanation: explanations.emergencyFund,
        },
        discretionarySpending: {
          amount: adjustedDiscretionaryAmount,
          percentage: Math.round((adjustedDiscretionaryAmount / monthlyIncome) * 100),
          currentBalance: discretionaryBalance,
          presetOptions: discretionaryPresets,
          categories: userDiscretionaryCategories.length > 0 ? userDiscretionaryCategories : discretionaryCategoryList,
          explanation: explanations.discretionary,
        },
        investments: {
          amount: adjustedInvestmentAmount,
          percentage: investmentPercentage,
          currentBalance: investmentBalance,
          presetOptions: investmentPresets,
          projection: investmentProjections,
          explanation: explanations.investment,
        },
      },
      summary: {
        totalAllocated: monthlyIncome,
        basedOn: emergencyFundShortfall > 0
          ? '50/30/20 rule adjusted for emergency fund priority'
          : '50/30/20 rule adjusted for your spending patterns',
        includesDebtPaydown: shouldIncludeDebt,
      },
    };

    // Add debt paydown bucket if debt > $1000
    if (shouldIncludeDebt) {
      response.allocations.debtPaydown = debtAllocation;
    }

    console.log('🎯 [Allocation] Successfully generated allocation recommendation');
    res.json(response);
  } catch (error) {
    console.error('🎯 [Allocation] Error generating allocation recommendation:', error);
    res.status(500).json({ error: error.message });
  }
});

// Generate AI explanation for allocation change in real-time
app.post('/api/ai/explain-allocation-change', aiRateLimiter, async (req, res) => {
  try {
    console.log('🔄 [AllocationChange] Received explanation request');
    const {
      bucketType,
      oldAmount,
      newAmount,
      monthlyIncome,
      impactedBuckets
    } = req.body;

    // Validate required fields
    if (!bucketType || oldAmount === undefined || newAmount === undefined || !monthlyIncome) {
      return res.status(400).json({ error: 'bucketType, oldAmount, newAmount, and monthlyIncome are required' });
    }

    if (typeof oldAmount !== 'number' || typeof newAmount !== 'number' || typeof monthlyIncome !== 'number') {
      return res.status(400).json({ error: 'Amounts must be numbers' });
    }

    const delta = newAmount - oldAmount;
    const oldPercentage = (oldAmount / monthlyIncome) * 100;
    const newPercentage = (newAmount / monthlyIncome) * 100;

    console.log(`🔄 [AllocationChange] ${bucketType}: $${oldAmount} → $${newAmount} (${delta >= 0 ? '+' : ''}$${delta})`);

    // Build context about what changed
    let impactDescription = '';
    if (impactedBuckets && Array.isArray(impactedBuckets)) {
      const impacts = impactedBuckets
        .filter(b => Math.abs(b.change) > 0.01)
        .map(b => `${b.name}: ${b.change > 0 ? '+' : ''}$${Math.round(b.change)}`)
        .join(', ');
      if (impacts) {
        impactDescription = ` This change automatically adjusted: ${impacts}.`;
      }
    }

    // Generate AI explanation for the change
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'You are a financial advisor. Explain budget allocation changes in 1-2 concise sentences. Be encouraging and focus on the financial impact. Keep it under 40 words.'
        },
        {
          role: 'user',
          content: `User changed their ${bucketType} allocation from $${oldAmount} (${oldPercentage.toFixed(1)}%) to $${newAmount} (${newPercentage.toFixed(1)}%) of their $${monthlyIncome} monthly income.${impactDescription} Explain the impact of this change.`
        }
      ],
      max_tokens: 80,
      temperature: 0.7
    });

    const explanation = completion.choices[0].message.content.trim();

    console.log(`🔄 [AllocationChange] Generated explanation: "${explanation}"`);

    res.json({
      explanation,
      usage: {
        prompt_tokens: completion.usage.prompt_tokens,
        completion_tokens: completion.usage.completion_tokens,
        total_tokens: completion.usage.total_tokens
      }
    });
  } catch (error) {
    console.error('🔄 [AllocationChange] Error generating explanation:', error);
    res.status(500).json({ error: error.message });
  }
});

// MARK: - Helper Functions

/**
 * Wraps a promise with a timeout. If the promise doesn't resolve within timeoutMs,
 * returns the fallbackValue instead.
 * @param {Promise} promise - The promise to wrap
 * @param {number} timeoutMs - Timeout in milliseconds
 * @param {any} fallbackValue - Value to return if timeout occurs
 * @returns {Promise} The original promise result or fallback value
 */
function withTimeout(promise, timeoutMs, fallbackValue) {
  return Promise.race([
    promise.catch(error => {
      console.warn(`⚠️ [Fallback] Promise failed: ${error.message}`);
      return fallbackValue;
    }),
    new Promise((resolve) =>
      setTimeout(() => {
        console.warn(`⏱️ [Timeout] Promise exceeded ${timeoutMs}ms, using fallback`);
        resolve(fallbackValue);
      }, timeoutMs)
    ),
  ]);
}

// Generate AI-powered explanations for each allocation bucket
async function generateAllocationExplanations({
  monthlyIncome,
  expenses,
  savings,
  debt,
  emergencyFundTarget,
  targetMonths,
  healthMetrics,
  allocations,
  includeDebt = false, // NEW: whether to generate debt explanation
}) {
  try {
    // Prepare fallback explanations in OpenAI response format
    const essentialMonthlyTarget = Math.round(emergencyFundTarget / (targetMonths || 6));
    const fallbackEssential = {
      choices: [{ message: { content: `Allocating $${allocations.essential.amount} covers your necessary monthly expenses while leaving room for savings.` } }]
    };
    const fallbackEmergency = {
      choices: [{ message: { content: `Build a ${targetMonths || 6}-month emergency fund covering your essential expenses of $${essentialMonthlyTarget}/month. At $${allocations.emergencyFund.amount}/month, you'll reach your $${emergencyFundTarget} target in ${Math.ceil((emergencyFundTarget - savings) / allocations.emergencyFund.amount)} months.` } }]
    };
    const fallbackDiscretionary = {
      choices: [{ message: { content: `Setting aside $${allocations.discretionary.amount} for discretionary spending allows you to enjoy life while staying financially responsible.` } }]
    };
    const fallbackInvestment = {
      choices: [{ message: { content: `Investing $${allocations.investment.amount} monthly helps build long-term wealth and prepares for retirement.` } }]
    };
    const fallbackDebt = {
      choices: [{ message: { content: `Paying down debt saves money on interest charges and improves financial flexibility.` } }]
    };

    // Build promises array based on whether debt is included
    const promises = [
      // Essential Spending explanation
      withTimeout(
        openai.chat.completions.create({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: 'You are a financial advisor. Explain budget allocations in 1-2 sentences. Be encouraging and specific.',
            },
            {
              role: 'user',
              content: `Explain why allocating $${allocations.essential.amount} (${allocations.essential.percentage}% of $${monthlyIncome} monthly income) to essential spending makes sense. Current monthly expenses: $${expenses}.`,
            },
          ],
          max_tokens: 100,
          temperature: 0.7,
        }),
        20000,
        fallbackEssential
      ),
      // Emergency Fund explanation
      withTimeout(
        openai.chat.completions.create({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: 'You are a financial advisor. Explain budget allocations in 1-2 sentences. Be encouraging and specific. Focus on opportunity and progress, never discouragement.',
            },
            {
              role: 'user',
              content: `Explain why allocating $${allocations.emergencyFund.amount} (${allocations.emergencyFund.percentage}% of $${monthlyIncome} monthly income) to emergency fund makes sense. Current savings: $${savings}, Target: $${emergencyFundTarget} (${targetMonths || 6} months of essential expenses, recommended for ${healthMetrics?.incomeStability || 'stable'} income). Essential spending base: $${Math.round(emergencyFundTarget / (targetMonths || 6))}/month. ${debt > 0 ? `Current debt: $${debt}.` : ''} Current emergency fund covers ${healthMetrics?.emergencyFundMonthsCovered?.toFixed(1) || 0} months.`,
            },
          ],
          max_tokens: 120,
          temperature: 0.7,
        }),
        20000,
        fallbackEmergency
      ),
      // Discretionary Spending explanation
      withTimeout(
        openai.chat.completions.create({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: 'You are a financial advisor. Explain budget allocations in 1-2 sentences. Be encouraging and specific.',
            },
            {
              role: 'user',
              content: `Explain why allocating $${allocations.discretionary.amount} (${allocations.discretionary.percentage}% of $${monthlyIncome} monthly income) to discretionary spending (entertainment, dining, shopping) makes sense for work-life balance.`,
            },
          ],
          max_tokens: 100,
          temperature: 0.7,
        }),
        20000,
        fallbackDiscretionary
      ),
      // Investment explanation
      withTimeout(
        openai.chat.completions.create({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: 'You are a financial advisor. Explain budget allocations in 1-2 sentences. Be encouraging and specific.',
            },
            {
              role: 'user',
              content: `Explain why allocating $${allocations.investment.amount} (${allocations.investment.percentage}% of $${monthlyIncome} monthly income) to investments and retirement savings is important for long-term wealth building. ${savings >= emergencyFundTarget ? 'Emergency fund is fully funded.' : 'Building emergency fund alongside investments.'}`,
            },
          ],
          max_tokens: 100,
          temperature: 0.7,
        }),
        20000,
        fallbackInvestment
      ),
    ];

    // Add debt explanation if needed
    if (includeDebt && allocations.debt) {
      promises.push(
        withTimeout(
          openai.chat.completions.create({
            model: 'gpt-4o-mini',
            messages: [
              {
                role: 'system',
                content: 'You are a financial advisor. Explain budget allocations in 1-2 sentences. Be encouraging and specific.',
              },
              {
                role: 'user',
                content: `Explain why allocating $${allocations.debt.amount} (${allocations.debt.percentage}% of $${monthlyIncome} monthly income) to debt paydown is important. Total debt: $${debt}. This payment will help pay off the debt faster and save on interest charges.`,
              },
            ],
            max_tokens: 100,
            temperature: 0.7,
          }),
          20000,
          fallbackDebt
        )
      );
    }

    const explanations = await Promise.all(promises);

    const result = {
      essential: explanations[0].choices[0].message.content.trim(),
      emergencyFund: explanations[1].choices[0].message.content.trim(),
      discretionary: explanations[2].choices[0].message.content.trim(),
      investment: explanations[3].choices[0].message.content.trim(),
    };

    if (includeDebt && explanations[4]) {
      result.debt = explanations[4].choices[0].message.content.trim();
    }

    return result;
  } catch (error) {
    console.error('🎯 [Allocation] Error generating AI explanations:', error);
    // Return fallback explanations if AI fails
    const essentialMonthlyTarget = Math.round(emergencyFundTarget / (targetMonths || 6));
    const result = {
      essential: `Allocating $${allocations.essential.amount} covers your necessary monthly expenses while leaving room for savings.`,
      emergencyFund: `Build a ${targetMonths || 6}-month emergency fund covering your essential expenses of $${essentialMonthlyTarget}/month. At $${allocations.emergencyFund.amount}/month, you'll reach your $${emergencyFundTarget} target in ${Math.ceil((emergencyFundTarget - savings) / allocations.emergencyFund.amount)} months.`,
      discretionary: `Setting aside $${allocations.discretionary.amount} for discretionary spending allows you to enjoy life while staying financially responsible.`,
      investment: `Investing $${allocations.investment.amount} monthly helps build long-term wealth and prepares for retirement.`,
    };

    if (includeDebt && allocations.debt) {
      result.debt = `Paying down $${debt} in debt with $${allocations.debt.amount}/month saves on interest charges and improves financial flexibility.`;
    }

    return result;
  }
}

function buildPurchaseContext({
  amount,
  merchantName,
  category,
  budgetStatus,
  spendingPattern,
  goals,
}) {
  let context = `I'm about to spend $${amount} at ${merchantName} (${category} category).\n\n`;

  if (budgetStatus) {
    context += `Budget status:\n`;
    context += `- Current ${category} spending: $${budgetStatus.currentSpent}/${budgetStatus.limit}\n`;
    context += `- After this purchase: $${budgetStatus.remaining - amount} remaining\n`;
    context += `- Days left in month: ${budgetStatus.daysRemaining}\n\n`;
  }

  if (spendingPattern) {
    context += `Spending pattern:\n`;
    context += `- Typical ${merchantName} purchase: $${spendingPattern.averageAmount}\n`;
    context += `- This purchase is ${Math.round((amount / spendingPattern.averageAmount) * 100)}% of usual\n`;
    context += `- Visit frequency: ${spendingPattern.frequency} times/month\n\n`;
  }

  if (goals && goals.length > 0) {
    context += `Active financial goals:\n`;
    goals.forEach((goal) => {
      context += `- ${goal.name}: $${goal.current}/$${goal.target} (${goal.priority} priority)\n`;
    });
  }

  context += `\nProvide a brief insight about this purchase decision.`;

  return context;
}

function buildSavingsContext({
  surplusAmount,
  budgetStatus,
  goals,
  monthlyExpenses,
  currentSavings,
}) {
  let context = `I have $${surplusAmount} surplus this month that I could save.\n\n`;

  if (budgetStatus) {
    context += `Budget summary:\n`;
    context += `- ${budgetStatus.underBudgetCategories} categories under budget\n`;
    context += `- Days left in month: ${budgetStatus.daysRemaining}\n\n`;
  }

  if (monthlyExpenses) {
    context += `Financial context:\n`;
    context += `- Monthly expenses: $${monthlyExpenses}\n`;
    context += `- Current emergency fund: $${currentSavings}\n`;
    context += `- Recommended emergency fund: $${monthlyExpenses * 6}\n\n`;
  }

  if (goals && goals.length > 0) {
    context += `Active goals:\n`;
    goals.forEach((goal) => {
      context += `- ${goal.name}: $${goal.current}/$${goal.target} (${goal.priority} priority)\n`;
    });
  }

  context += `\nRecommend how to allocate this $${surplusAmount} surplus.`;

  return context;
}

// MARK: - Allocation Helper Functions

/**
 * Calculate preset values (Low/Rec/High) for a bucket based on fixed percentages
 * @param {number} monthlyIncome - Monthly income
 * @param {number} recommendedPercentage - Recommended percentage (e.g., 10 for 10%)
 * @param {number} lowPercentage - Low tier percentage
 * @param {number} highPercentage - High tier percentage
 * @returns {object} Preset options with low, recommended, and high values
 */
function calculatePresetOptions(monthlyIncome, lowPercentage, recommendedPercentage, highPercentage) {
  return {
    low: {
      amount: Math.round((monthlyIncome * lowPercentage) / 100),
      percentage: lowPercentage
    },
    recommended: {
      amount: Math.round((monthlyIncome * recommendedPercentage) / 100),
      percentage: recommendedPercentage
    },
    high: {
      amount: Math.round((monthlyIncome * highPercentage) / 100),
      percentage: highPercentage
    }
  };
}

/**
 * Generate emergency fund duration options (3/6/12 months)
 * @param {number} essentialSpending - Monthly essential spending
 * @param {number} currentBalance - Current emergency fund balance from linked accounts
 * @param {string} incomeStability - 'stable', 'variable', or 'inconsistent'
 * @param {number} monthlyIncome - Monthly income for percentage calculations
 * @returns {Array} Array of duration options with monthly contribution presets
 */
function generateEmergencyFundOptions(essentialSpending, currentBalance, incomeStability, monthlyIncome) {
  // Determine recommended duration based on income stability
  let recommendedMonths = 6;
  if (incomeStability === 'variable') {
    recommendedMonths = 9;
  } else if (incomeStability === 'inconsistent') {
    recommendedMonths = 12;
  }

  const options = [3, 6, 12].map(months => {
    const targetAmount = Math.round(essentialSpending * months);
    const shortfall = Math.max(0, targetAmount - currentBalance);

    // Calculate monthly contribution options for different savings periods
    // Low: 24 months, Recommended: 18 months (moderate) or 12 months (aggressive), High: 8 months
    const lowMonthly = shortfall > 0 ? Math.round(shortfall / 24) : 0;
    const recommendedMonthly = shortfall > 0 ? Math.round(shortfall / (shortfall > targetAmount * 0.5 ? 12 : 18)) : 0;
    const highMonthly = shortfall > 0 ? Math.round(shortfall / 8) : 0;

    return {
      months,
      targetAmount,
      shortfall,
      monthlyContribution: {
        low: {
          amount: lowMonthly,
          percentage: monthlyIncome > 0 ? Math.round((lowMonthly / monthlyIncome) * 100) : 0
        },
        recommended: {
          amount: recommendedMonthly,
          percentage: monthlyIncome > 0 ? Math.round((recommendedMonthly / monthlyIncome) * 100) : 0
        },
        high: {
          amount: highMonthly,
          percentage: monthlyIncome > 0 ? Math.round((highMonthly / monthlyIncome) * 100) : 0
        }
      },
      isRecommended: months === recommendedMonths
    };
  });

  return options;
}

/**
 * Calculate investment growth projections using compound interest
 * Assumes 7% annual return (conservative market average)
 * @param {number} currentBalance - Current investment balance
 * @param {number} monthlyIncome - Monthly income for percentage calculations
 * @param {number} lowPercentage - Low tier percentage
 * @param {number} recommendedPercentage - Recommended percentage
 * @param {number} highPercentage - High tier percentage
 * @returns {object} Investment projections for low/rec/high tiers
 */
function calculateInvestmentProjections(currentBalance, monthlyIncome, lowPercentage, recommendedPercentage, highPercentage) {
  const ANNUAL_RETURN_RATE = 0.07; // 7% annual return
  const MONTHLY_RATE = ANNUAL_RETURN_RATE / 12;

  function projectGrowth(monthlyContribution, years) {
    const months = years * 12;
    let balance = currentBalance;

    // Compound interest formula with monthly contributions
    // Future Value = P(1+r)^n + PMT × [((1+r)^n - 1) / r]
    const principalGrowth = currentBalance * Math.pow(1 + MONTHLY_RATE, months);
    const contributionGrowth = monthlyContribution * ((Math.pow(1 + MONTHLY_RATE, months) - 1) / MONTHLY_RATE);

    return Math.round(principalGrowth + contributionGrowth);
  }

  const lowContribution = Math.round((monthlyIncome * lowPercentage) / 100);
  const recommendedContribution = Math.round((monthlyIncome * recommendedPercentage) / 100);
  const highContribution = Math.round((monthlyIncome * highPercentage) / 100);

  return {
    currentBalance,
    lowProjection: {
      monthlyContribution: lowContribution,
      year10: projectGrowth(lowContribution, 10),
      year20: projectGrowth(lowContribution, 20),
      year30: projectGrowth(lowContribution, 30)
    },
    recommendedProjection: {
      monthlyContribution: recommendedContribution,
      year10: projectGrowth(recommendedContribution, 10),
      year20: projectGrowth(recommendedContribution, 20),
      year30: projectGrowth(recommendedContribution, 30)
    },
    highProjection: {
      monthlyContribution: highContribution,
      year10: projectGrowth(highContribution, 10),
      year20: projectGrowth(highContribution, 20),
      year30: projectGrowth(highContribution, 30)
    }
  };
}

/**
 * Calculate debt paydown timeline and interest saved
 * Simplified calculation - assumes average APR across all debts
 * @param {number} totalDebt - Total debt balance
 * @param {number} monthlyPayment - Monthly payment amount
 * @param {number} averageAPR - Average APR (e.g., 0.18 for 18%)
 * @returns {object} Timeline with months to payoff and interest saved
 */
function calculateDebtPayoff(totalDebt, monthlyPayment, averageAPR = 0.18) {
  if (totalDebt === 0 || monthlyPayment === 0) {
    return { months: 0, totalPaid: 0, interestPaid: 0, interestSaved: 0 };
  }

  const monthlyRate = averageAPR / 12;
  let balance = totalDebt;
  let months = 0;
  let totalInterest = 0;

  // Calculate payoff with given payment
  while (balance > 0 && months < 600) { // Cap at 50 years to prevent infinite loops
    const interestCharge = balance * monthlyRate;
    const principalPayment = monthlyPayment - interestCharge;

    if (principalPayment <= 0) {
      // Payment doesn't cover interest - would never pay off
      return { months: 600, totalPaid: monthlyPayment * 600, interestPaid: monthlyPayment * 600 - totalDebt, interestSaved: 0 };
    }

    totalInterest += interestCharge;
    balance -= principalPayment;
    months++;
  }

  // Calculate minimum payment (3% of balance or $25, whichever is greater)
  const minimumPayment = Math.max(totalDebt * 0.03, 25);
  let minBalance = totalDebt;
  let minMonths = 0;
  let minInterest = 0;

  while (minBalance > 0 && minMonths < 600) {
    const interestCharge = minBalance * monthlyRate;
    const principalPayment = minimumPayment - interestCharge;

    if (principalPayment <= 0) break;

    minInterest += interestCharge;
    minBalance -= principalPayment;
    minMonths++;
  }

  const interestSaved = Math.max(0, minInterest - totalInterest);

  return {
    months: Math.round(months),
    totalPaid: Math.round(totalDebt + totalInterest),
    interestPaid: Math.round(totalInterest),
    interestSaved: Math.round(interestSaved)
  };
}

// Start server
app.listen(PORT, () => {
  console.log(`\n🚀 Financial Analyzer Backend Server`);
  console.log(`📡 Running on http://localhost:${PORT}`);
  console.log(`🌍 Environment: ${process.env.PLAID_ENV || 'sandbox'}\n`);

  // Validate required environment variables
  const missingVars = [];

  if (!process.env.PLAID_CLIENT_ID || !process.env.PLAID_SECRET) {
    console.error('❌ ERROR: PLAID_CLIENT_ID and PLAID_SECRET must be set in .env file');
    console.error('📝 Copy .env.example to .env and add your Plaid credentials\n');
    missingVars.push('PLAID_CLIENT_ID', 'PLAID_SECRET');
  }

  if (!process.env.OPENAI_API_KEY) {
    console.error('❌ ERROR: OPENAI_API_KEY must be set in .env file');
    console.error('📝 AI-powered insights will not work without a valid OpenAI API key');
    console.error('📝 Get your API key from https://platform.openai.com/api-keys\n');
    missingVars.push('OPENAI_API_KEY');
  }

  // Fail fast if critical environment variables are missing
  if (missingVars.length > 0) {
    console.error(`❌ FATAL: Missing required environment variables: ${missingVars.join(', ')}`);
    console.error('❌ Server cannot function properly. Please add these to your .env file.\n');
    process.exit(1);
  }

  console.log('✅ All required environment variables validated');
  console.log('✅ Server ready to accept requests\n');
});

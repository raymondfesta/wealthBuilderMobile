import express from 'express';
import cors from 'cors';
import bodyParser from 'body-parser';
import dotenv from 'dotenv';
import { Configuration, PlaidApi, PlaidEnvironments } from 'plaid';
import OpenAI from 'openai';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

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
});

// In-memory storage for access tokens (use a database in production)
const accessTokens = new Map();

// MARK: - Routes

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Create Link Token
app.post('/api/plaid/create_link_token', async (req, res) => {
  try {
    const configs = {
      user: {
        client_user_id: 'user-id', // In production, use actual user ID
      },
      client_name: 'Financial Analyzer',
      products: ['transactions'],
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

    if (!public_token) {
      return res.status(400).json({ error: 'public_token is required' });
    }

    const response = await plaidClient.itemPublicTokenExchange({
      public_token,
    });

    const accessToken = response.data.access_token;
    const itemId = response.data.item_id;

    // Store access token (in production, encrypt and store in database)
    accessTokens.set(itemId, accessToken);

    res.json({
      access_token: accessToken,
      item_id: itemId,
    });
  } catch (error) {
    console.error('Error exchanging public token:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get Accounts
app.post('/api/plaid/accounts', async (req, res) => {
  try {
    const { access_token } = req.body;

    if (!access_token) {
      return res.status(400).json({ error: 'access_token is required' });
    }

    const response = await plaidClient.accountsGet({
      access_token,
    });

    res.json({
      accounts: response.data.accounts,
      item: response.data.item,
    });
  } catch (error) {
    console.error('Error fetching accounts:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get Transactions
app.post('/api/plaid/transactions', async (req, res) => {
  try {
    const { access_token, start_date, end_date } = req.body;

    if (!access_token || !start_date || !end_date) {
      return res.status(400).json({
        error: 'access_token, start_date, and end_date are required',
      });
    }

    let allTransactions = [];
    let hasMore = true;
    let offset = 0;
    const count = 500; // Max transactions per request

    // Plaid returns transactions in pages, so we need to fetch all pages
    while (hasMore) {
      const response = await plaidClient.transactionsGet({
        access_token,
        start_date,
        end_date,
        options: {
          count,
          offset,
        },
      });

      allTransactions = allTransactions.concat(response.data.transactions);
      hasMore = allTransactions.length < response.data.total_transactions;
      offset += count;
    }

    res.json({
      transactions: allTransactions,
      total_transactions: allTransactions.length,
      accounts: [], // Optionally include accounts
    });
  } catch (error) {
    console.error('Error fetching transactions:', error);
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

    console.log('🗑️ [Backend] Access token received (first 10 chars):', access_token.substring(0, 10) + '...');

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

// MARK: - AI Insights Routes

// Generate AI insights for a purchase decision
app.post('/api/ai/purchase-insight', async (req, res) => {
  try {
    const {
      amount,
      merchantName,
      category,
      budgetStatus,
      spendingPattern,
      goals,
    } = req.body;

    if (!amount || !merchantName || !category) {
      return res.status(400).json({
        error: 'amount, merchantName, and category are required',
      });
    }

    // Build context for AI
    const context = buildPurchaseContext({
      amount,
      merchantName,
      category,
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
app.post('/api/ai/savings-recommendation', async (req, res) => {
  try {
    const {
      surplusAmount,
      budgetStatus,
      goals,
      monthlyExpenses,
      currentSavings,
    } = req.body;

    if (!surplusAmount) {
      return res.status(400).json({ error: 'surplusAmount is required' });
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

// MARK: - Helper Functions

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

// Start server
app.listen(PORT, () => {
  console.log(`\n🚀 Financial Analyzer Backend Server`);
  console.log(`📡 Running on http://localhost:${PORT}`);
  console.log(`🌍 Environment: ${process.env.PLAID_ENV || 'sandbox'}\n`);

  // Validate required environment variables
  if (!process.env.PLAID_CLIENT_ID || !process.env.PLAID_SECRET) {
    console.error('❌ ERROR: PLAID_CLIENT_ID and PLAID_SECRET must be set in .env file');
    console.error('📝 Copy .env.example to .env and add your Plaid credentials\n');
  }
});

import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DB_PATH = path.join(__dirname, 'app.db');

let db = null;

export function getDb() {
  if (!db) {
    db = new Database(DB_PATH);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    runMigrations(db);
  }
  return db;
}

function runMigrations(database) {
  const schemaPath = path.join(__dirname, 'schema.sql');
  const schema = fs.readFileSync(schemaPath, 'utf8');
  database.exec(schema);

  // Migration: Add onboarding_completed columns if they don't exist
  try {
    const columns = database.pragma('table_info(users)');
    const hasOnboardingCompleted = columns.some(c => c.name === 'onboarding_completed');
    if (!hasOnboardingCompleted) {
      console.log('🔄 Adding onboarding_completed columns to users table...');
      database.exec(`ALTER TABLE users ADD COLUMN onboarding_completed INTEGER DEFAULT 0`);
      database.exec(`ALTER TABLE users ADD COLUMN onboarding_completed_at TEXT`);
      console.log('✅ Added onboarding columns');
    }
  } catch (err) {
    // Ignore if columns already exist
    if (!err.message.includes('duplicate column')) {
      console.error('⚠️ Migration warning:', err.message);
    }
  }

  // Migration: Add allocation plan tables if they don't exist
  try {
    const tables = database.prepare(`
      SELECT name FROM sqlite_master WHERE type='table' AND name='user_allocation_plans'
    `).get();
    if (!tables) {
      console.log('🔄 Creating user_allocation_plans and user_paycheck_schedules tables...');
      database.exec(`
        CREATE TABLE IF NOT EXISTS user_allocation_plans (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          bucket_type TEXT NOT NULL,
          percentage REAL NOT NULL,
          target_amount REAL,
          linked_account_id TEXT,
          linked_account_name TEXT,
          is_customized INTEGER DEFAULT 0,
          preset_tier TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(user_id, bucket_type),
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS user_paycheck_schedules (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          frequency TEXT NOT NULL,
          estimated_amount REAL,
          next_paycheck_date TEXT,
          is_confirmed INTEGER DEFAULT 0,
          detected_employer TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(user_id),
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_allocation_plans_user ON user_allocation_plans(user_id);
        CREATE INDEX IF NOT EXISTS idx_paycheck_schedules_user ON user_paycheck_schedules(user_id);
      `);
      console.log('✅ Created allocation plan tables');
    }
  } catch (err) {
    console.error('⚠️ Allocation plan migration warning:', err.message);
  }

  console.log('✅ Database migrations complete');
}

export function closeDb() {
  if (db) {
    db.close();
    db = null;
  }
}

// User operations
export function createUser({ id, email, passwordHash, appleUserId, displayName }) {
  const db = getDb();
  const stmt = db.prepare(`
    INSERT INTO users (id, email, password_hash, apple_user_id, display_name, email_verified)
    VALUES (?, ?, ?, ?, ?, ?)
  `);
  stmt.run(id, email, passwordHash, appleUserId, displayName, appleUserId ? 1 : 0);
  return findUserById(id);
}

export function findUserById(id) {
  const db = getDb();
  return db.prepare('SELECT * FROM users WHERE id = ?').get(id);
}

export function findUserByEmail(email) {
  const db = getDb();
  return db.prepare('SELECT * FROM users WHERE email = ?').get(email);
}

export function findUserByAppleId(appleUserId) {
  const db = getDb();
  return db.prepare('SELECT * FROM users WHERE apple_user_id = ?').get(appleUserId);
}

export function updateUser(id, updates) {
  const db = getDb();
  const fields = [];
  const values = [];

  if (updates.email !== undefined) {
    fields.push('email = ?');
    values.push(updates.email);
  }
  if (updates.displayName !== undefined) {
    fields.push('display_name = ?');
    values.push(updates.displayName);
  }
  if (updates.emailVerified !== undefined) {
    fields.push('email_verified = ?');
    values.push(updates.emailVerified ? 1 : 0);
  }

  if (fields.length === 0) return findUserById(id);

  fields.push('updated_at = CURRENT_TIMESTAMP');
  values.push(id);

  db.prepare(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`).run(...values);
  return findUserById(id);
}

// Session operations
export function createSession({ id, userId, refreshTokenHash, deviceInfo, expiresAt }) {
  const db = getDb();
  db.prepare(`
    INSERT INTO sessions (id, user_id, refresh_token_hash, device_info, expires_at)
    VALUES (?, ?, ?, ?, ?)
  `).run(id, userId, refreshTokenHash, deviceInfo, expiresAt);
}

export function findSessionByTokenHash(tokenHash) {
  const db = getDb();
  return db.prepare(`
    SELECT * FROM sessions
    WHERE refresh_token_hash = ? AND revoked_at IS NULL AND expires_at > datetime('now')
  `).get(tokenHash);
}

export function revokeSession(id) {
  const db = getDb();
  db.prepare(`UPDATE sessions SET revoked_at = CURRENT_TIMESTAMP WHERE id = ?`).run(id);
}

export function revokeAllUserSessions(userId) {
  const db = getDb();
  db.prepare(`UPDATE sessions SET revoked_at = CURRENT_TIMESTAMP WHERE user_id = ?`).run(userId);
}

// Plaid item operations
export function createPlaidItem({ id, userId, itemId, accessTokenEncrypted, institutionName }) {
  const db = getDb();
  db.prepare(`
    INSERT INTO plaid_items (id, user_id, item_id, access_token_encrypted, institution_name)
    VALUES (?, ?, ?, ?, ?)
  `).run(id, userId, itemId, accessTokenEncrypted, institutionName);
}

export function findPlaidItemsByUserId(userId) {
  const db = getDb();
  return db.prepare('SELECT * FROM plaid_items WHERE user_id = ?').all(userId);
}

export function findPlaidItemByItemId(userId, itemId) {
  const db = getDb();
  return db.prepare('SELECT * FROM plaid_items WHERE user_id = ? AND item_id = ?').get(userId, itemId);
}

export function findPlaidItemByItemIdOnly(itemId) {
  const db = getDb();
  return db.prepare('SELECT * FROM plaid_items WHERE item_id = ?').get(itemId);
}

export function deletePlaidItem(userId, itemId) {
  const db = getDb();
  db.prepare('DELETE FROM plaid_items WHERE user_id = ? AND item_id = ?').run(userId, itemId);
}

export function deletePlaidItemByItemId(itemId) {
  const db = getDb();
  db.prepare('DELETE FROM plaid_items WHERE item_id = ?').run(itemId);
}

export function updatePlaidItemToken(userId, itemId, accessTokenEncrypted) {
  const db = getDb();
  db.prepare(`
    UPDATE plaid_items
    SET access_token_encrypted = ?, updated_at = CURRENT_TIMESTAMP
    WHERE user_id = ? AND item_id = ?
  `).run(accessTokenEncrypted, userId, itemId);
}

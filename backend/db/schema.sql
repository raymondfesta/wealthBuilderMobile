-- Users table
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE,
    password_hash TEXT,
    apple_user_id TEXT UNIQUE,
    display_name TEXT,
    email_verified INTEGER DEFAULT 0,
    onboarding_completed INTEGER DEFAULT 0,
    onboarding_completed_at TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Plaid items (bank connections)
CREATE TABLE IF NOT EXISTS plaid_items (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    access_token_encrypted TEXT NOT NULL,
    institution_name TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, item_id)
);

-- Sessions (refresh tokens)
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    refresh_token_hash TEXT NOT NULL,
    device_info TEXT,
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Password reset tokens
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    used_at TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- User allocation plans (bucket configuration)
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

-- User paycheck schedules
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_plaid_items_user_id ON plaid_items(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_refresh_token ON sessions(refresh_token_hash);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_apple_id ON users(apple_user_id);
CREATE INDEX IF NOT EXISTS idx_allocation_plans_user ON user_allocation_plans(user_id);
CREATE INDEX IF NOT EXISTS idx_paycheck_schedules_user ON user_paycheck_schedules(user_id);

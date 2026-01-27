import express from 'express';
import bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import * as jose from 'jose';
import {
  createUser,
  findUserByEmail,
  findUserByAppleId,
  findUserById,
  createSession,
  findSessionByTokenHash,
  revokeSession,
  revokeAllUserSessions,
} from '../db/database.js';
import {
  generateAccessToken,
  generateRefreshToken,
  hashRefreshToken,
  getRefreshTokenExpiry,
} from '../services/token.js';
import { requireAuth } from '../middleware/auth.js';

const router = express.Router();
const BCRYPT_ROUNDS = 12;

// Apple's public keys cache
let applePublicKeys = null;
let appleKeysLastFetched = 0;
const APPLE_KEYS_TTL = 24 * 60 * 60 * 1000; // 24 hours

async function getApplePublicKeys() {
  const now = Date.now();
  if (applePublicKeys && now - appleKeysLastFetched < APPLE_KEYS_TTL) {
    return applePublicKeys;
  }

  const response = await fetch('https://appleid.apple.com/auth/keys');
  const data = await response.json();
  applePublicKeys = data.keys;
  appleKeysLastFetched = now;
  return applePublicKeys;
}

function formatUserResponse(user) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.display_name,
    emailVerified: Boolean(user.email_verified),
  };
}

// POST /auth/register - Email/password signup
router.post('/register', async (req, res) => {
  try {
    const { email, password, displayName } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    const emailLower = email.toLowerCase().trim();
    const existingUser = findUserByEmail(emailLower);
    if (existingUser) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const userId = uuidv4();
    const user = createUser({
      id: userId,
      email: emailLower,
      passwordHash,
      appleUserId: null,
      displayName: displayName || emailLower.split('@')[0],
    });

    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken();
    const sessionId = uuidv4();

    createSession({
      id: sessionId,
      userId: user.id,
      refreshTokenHash: hashRefreshToken(refreshToken),
      deviceInfo: req.headers['user-agent'],
      expiresAt: getRefreshTokenExpiry(),
    });

    console.log(`✅ [Auth] User registered: ${emailLower}`);

    res.json({
      accessToken,
      refreshToken,
      user: formatUserResponse(user),
      isNewUser: true,
    });
  } catch (error) {
    console.error('❌ [Auth] Registration error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// POST /auth/login - Email/password login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    const emailLower = email.toLowerCase().trim();
    const user = findUserByEmail(emailLower);

    if (!user || !user.password_hash) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken();
    const sessionId = uuidv4();

    createSession({
      id: sessionId,
      userId: user.id,
      refreshTokenHash: hashRefreshToken(refreshToken),
      deviceInfo: req.headers['user-agent'],
      expiresAt: getRefreshTokenExpiry(),
    });

    console.log(`✅ [Auth] User logged in: ${emailLower}`);

    res.json({
      accessToken,
      refreshToken,
      user: formatUserResponse(user),
      isNewUser: false,
    });
  } catch (error) {
    console.error('❌ [Auth] Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

// POST /auth/apple - Sign in with Apple
router.post('/apple', async (req, res) => {
  try {
    const { identityToken, authorizationCode, fullName, email } = req.body;

    if (!identityToken) {
      return res.status(400).json({ error: 'Identity token required' });
    }

    // Verify Apple identity token
    const keys = await getApplePublicKeys();
    const decodedHeader = jose.decodeProtectedHeader(identityToken);
    const key = keys.find((k) => k.kid === decodedHeader.kid);

    if (!key) {
      return res.status(401).json({ error: 'Invalid identity token' });
    }

    const publicKey = await jose.importJWK(key, 'RS256');
    const { payload } = await jose.jwtVerify(identityToken, publicKey, {
      issuer: 'https://appleid.apple.com',
      audience: process.env.APPLE_BUNDLE_ID || 'com.financialanalyzer',
    });

    const appleUserId = payload.sub;
    let user = findUserByAppleId(appleUserId);
    let isNewUser = false;

    if (!user) {
      // New user - create account
      isNewUser = true;
      const userId = uuidv4();
      const userEmail = email || payload.email;
      const name =
        fullName?.givenName && fullName?.familyName
          ? `${fullName.givenName} ${fullName.familyName}`
          : userEmail?.split('@')[0] || 'User';

      user = createUser({
        id: userId,
        email: userEmail,
        passwordHash: null,
        appleUserId,
        displayName: name,
      });

      console.log(`✅ [Auth] Apple user created: ${user.id}`);
    } else {
      console.log(`✅ [Auth] Apple user logged in: ${user.id}`);
    }

    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken();
    const sessionId = uuidv4();

    createSession({
      id: sessionId,
      userId: user.id,
      refreshTokenHash: hashRefreshToken(refreshToken),
      deviceInfo: req.headers['user-agent'],
      expiresAt: getRefreshTokenExpiry(),
    });

    res.json({
      accessToken,
      refreshToken,
      user: formatUserResponse(user),
      isNewUser,
    });
  } catch (error) {
    console.error('❌ [Auth] Apple auth error:', error);
    if (error.code === 'ERR_JWT_EXPIRED') {
      return res.status(401).json({ error: 'Apple token expired' });
    }
    res.status(500).json({ error: 'Apple authentication failed' });
  }
});

// POST /auth/refresh - Refresh access token
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token required' });
    }

    const tokenHash = hashRefreshToken(refreshToken);
    const session = findSessionByTokenHash(tokenHash);

    if (!session) {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    const user = findUserById(session.user_id);
    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    // Rotate refresh token
    revokeSession(session.id);

    const newAccessToken = generateAccessToken(user);
    const newRefreshToken = generateRefreshToken();
    const newSessionId = uuidv4();

    createSession({
      id: newSessionId,
      userId: user.id,
      refreshTokenHash: hashRefreshToken(newRefreshToken),
      deviceInfo: req.headers['user-agent'],
      expiresAt: getRefreshTokenExpiry(),
    });

    res.json({
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    });
  } catch (error) {
    console.error('❌ [Auth] Token refresh error:', error);
    res.status(500).json({ error: 'Token refresh failed' });
  }
});

// POST /auth/logout - Revoke session
router.post('/logout', requireAuth, async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      const tokenHash = hashRefreshToken(refreshToken);
      const session = findSessionByTokenHash(tokenHash);
      if (session) {
        revokeSession(session.id);
      }
    }

    console.log(`✅ [Auth] User logged out: ${req.userId}`);

    res.json({ success: true });
  } catch (error) {
    console.error('❌ [Auth] Logout error:', error);
    res.status(500).json({ error: 'Logout failed' });
  }
});

// POST /auth/logout-all - Revoke all sessions
router.post('/logout-all', requireAuth, async (req, res) => {
  try {
    revokeAllUserSessions(req.userId);
    console.log(`✅ [Auth] All sessions revoked for user: ${req.userId}`);
    res.json({ success: true });
  } catch (error) {
    console.error('❌ [Auth] Logout-all error:', error);
    res.status(500).json({ error: 'Logout failed' });
  }
});

// GET /auth/me - Get current user
router.get('/me', requireAuth, async (req, res) => {
  try {
    const user = findUserById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ user: formatUserResponse(user) });
  } catch (error) {
    console.error('❌ [Auth] Get user error:', error);
    res.status(500).json({ error: 'Failed to get user' });
  }
});

export default router;

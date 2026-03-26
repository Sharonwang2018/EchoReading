import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { query } from '../db.js';
import { Router } from 'express';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

const USERNAME_RE = /^[a-zA-Z0-9][a-zA-Z0-9_.:+@-]*$/;

function signToken(user) {
  return jwt.sign(
    { userId: user.id, username: user.username, isGuest: !!user.isGuest },
    JWT_SECRET,
    { expiresIn: '7d' }
  );
}

const router = Router();

router.post('/register', async (req, res, next) => {
  try {
    const { username, password } = req.body || {};
    const u = String(username || '').trim();
    const p = String(password || '');

    if (u.length < 2 || u.length > 48) {
      return res.status(400).json({ error: 'invalid_username', message: '用户名 2-48 位' });
    }
    if (!USERNAME_RE.test(u)) {
      return res.status(400).json({ error: 'invalid_username', message: '用户名仅支持字母、数字、-_.:+@，且以字母或数字开头' });
    }
    if (p.length < 6 || p.length > 32) {
      return res.status(400).json({ error: 'invalid_password', message: '密码 6-32 位' });
    }

    const existing = await query('SELECT id FROM users WHERE username = $1 AND is_guest = false', [u]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'username_taken', message: '用户名已被使用' });
    }

    const hash = await bcrypt.hash(p, 10);
    const id = uuidv4();
    await query(
      'INSERT INTO users (id, username, password_hash, is_guest) VALUES ($1, $2, $3, false)',
      [id, u, hash]
    );

    const token = signToken({ id, username: u, isGuest: false });
    res.json({ ticket: token, userId: id });
  } catch (e) {
    next(e);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const { username, password } = req.body || {};
    const u = String(username || '').trim();
    const p = String(password || '');

    if (!u || !p) {
      return res.status(400).json({ error: 'auth_failed', message: '用户名或密码错误' });
    }

    const result = await query('SELECT id, username, password_hash FROM users WHERE username = $1 AND is_guest = false', [u]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'auth_failed', message: '用户名或密码错误' });
    }

    const user = result.rows[0];
    const ok = await bcrypt.compare(p, user.password_hash || '');
    if (!ok) {
      return res.status(401).json({ error: 'auth_failed', message: '用户名或密码错误' });
    }

    const token = signToken({ id: user.id, username: user.username, isGuest: false });
    res.json({ ticket: token, userId: user.id });
  } catch (e) {
    next(e);
  }
});

router.post('/guest', async (req, res, next) => {
  try {
    const id = uuidv4();
    const username = `guest_${id.replace(/-/g, '').slice(0, 12)}`;
    await query(
      'INSERT INTO users (id, username, is_guest) VALUES ($1, $2, true)',
      [id, username]
    );

    const token = signToken({ id, username, isGuest: true });
    res.json({ ticket: token, userId: id });
  } catch (e) {
    next(e);
  }
});

export default router;

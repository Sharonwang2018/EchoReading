/**
 * 用户名密码注册/登录
 * action: 'register' | 'login'
 * register: { username, password } -> 创建用户，返回 ticket
 * login: { username, password } -> 验证密码，返回 ticket
 */
const cloudbase = require('@cloudbase/node-sdk');
const crypto = require('crypto');

const app = cloudbase.init({
  env: process.env.TCB_ENV || process.env.SCF_NAMESPACE,
  credentials: require('./tcb_custom_login.json'),
});

const USERS_COLL = 'users';
const USERNAME_FIELD = 'username';

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

function verifyPassword(password, hash) {
  return hashPassword(password) === hash;
}

exports.main = async (event, context) => {
  const { action, username, password } = event;

  if (!action || !username || !password) {
    return { error: 'invalid_params', message: '缺少 action、username 或 password' };
  }

  const u = String(username).trim();
  if (u.length < 2 || u.length > 48) {
    return { error: 'invalid_username', message: '用户名 2-48 位' };
  }
  if (!/^[a-zA-Z0-9][a-zA-Z0-9_.:+@-]*$/.test(u)) {
    return { error: 'invalid_username', message: '用户名仅支持字母、数字、-_.:+@，且以字母或数字开头' };
  }

  const p = String(password);
  if (p.length < 6 || p.length > 32) {
    return { error: 'invalid_password', message: '密码 6-32 位' };
  }

  const db = app.database();

  if (action === 'register') {
    const existing = await db.collection(USERS_COLL).where({ [USERNAME_FIELD]: u }).get();
    if (existing.data && existing.data.length > 0) {
      return { error: 'username_taken', message: '用户名已被使用' };
    }

    const res = await db.collection(USERS_COLL).add({
      [USERNAME_FIELD]: u,
      password_hash: hashPassword(p),
      created_at: new Date().toISOString(),
    });

    const docId = res.id;
    if (!docId) {
      return { error: 'register_failed', message: '注册失败' };
    }

    const ticket = app.auth().createTicket(docId, { refresh: 10 * 60 * 1000 });
    return { ticket };
  }

  if (action === 'login') {
    const res = await db.collection(USERS_COLL).where({ [USERNAME_FIELD]: u }).get();
    if (!res.data || res.data.length === 0) {
      return { error: 'auth_failed', message: '用户名或密码错误' };
    }

    const user = res.data[0];
    const docId = user._id;
    const hash = user.password_hash;

    if (!hash || !verifyPassword(p, hash)) {
      return { error: 'auth_failed', message: '用户名或密码错误' };
    }

    const ticket = app.auth().createTicket(docId, { refresh: 10 * 60 * 1000 });
    return { ticket };
  }

  return { error: 'invalid_action', message: 'action 需为 register 或 login' };
};

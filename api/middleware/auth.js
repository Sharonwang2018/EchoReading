import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

export function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'unauthorized', message: '缺少 token' });
  }
  const token = auth.slice(7);
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.userId = payload.userId;
    req.username = payload.username;
    req.isGuest = inferGuest(payload);
    next();
  } catch (err) {
    return res.status(401).json({ error: 'unauthorized', message: 'token 无效' });
  }
}

/** JWT 含 isGuest，或旧 token 根据 guest_ 用户名推断 */
function inferGuest(payload) {
  if (payload.isGuest === true) return true;
  if (payload.isGuest === false) return false;
  return /^guest_/i.test(String(payload.username || ''));
}

export function optionalAuth(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    req.userId = null;
    req.isGuest = false;
    return next();
  }
  const token = auth.slice(7);
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.userId = payload.userId;
    req.username = payload.username;
    req.isGuest = inferGuest(payload);
  } catch (_) {
    req.userId = null;
    req.isGuest = false;
  }
  next();
}

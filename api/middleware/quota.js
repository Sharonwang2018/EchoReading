import { optionalAuth } from './auth.js';
import { checkQuota, consumeQuota } from '../lib/usage_quota.js';

const kindLabels = {
  vision: '拍照读页（视觉识别）',
  transcribe: '语音转写',
  tts: 'AI 朗读',
  chat: 'AI 对话/点评',
};

/**
 * 先做 optionalAuth，再检查当日额度；响应结束后按状态码决定是否计次。
 * @param {'vision'|'transcribe'|'tts'|'chat'} kind
 */
export function quotaPreCheck(kind) {
  return (req, res, next) => {
    optionalAuth(req, res, () => {
      const q = checkQuota(req, kind);
      if (!q.ok) {
        return res.status(429).json({
          error: 'quota_exceeded',
          message: q.message || `今日${kindLabels[kind] || kind}次数已用完`,
          kind,
          limit: q.limit,
          used: q.used,
        });
      }
      res.once('finish', () => {
        consumeQuota(req, kind, res.statusCode);
      });
      next();
    });
  };
}

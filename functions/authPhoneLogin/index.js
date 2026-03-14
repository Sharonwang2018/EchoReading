/**
 * 手机验证码登录云函数
 * 1. 验证验证码获取 verification_token
 * 2. 调用 signin 获取用户信息
 * 3. 使用 createTicket 创建登录凭证返回客户端
 *
 * 部署：在 CloudBase 控制台创建云函数 authPhoneLogin，复制此代码
 * 需配置：自定义登录私钥（控制台-登录设置-生成私钥）
 */
const cloudbase = require('@cloudbase/node-sdk');
const fetch = require('node-fetch');

const app = cloudbase.init({
  env: process.env.TCB_ENV || process.env.SCF_NAMESPACE,
  credentials: require('./tcb_custom_login.json'), // 从控制台下载私钥，重命名放置于此
});

exports.main = async (event, context) => {
  const { verificationId, verificationCode } = event;

  if (!verificationId || !verificationCode) {
    return { error: 'invalid_params', message: '缺少 verificationId 或 verificationCode' };
  }

  const envId = process.env.TCB_ENV || process.env.SCF_NAMESPACE;
  const baseUrl = `https://${envId}.api.tcloudbasegateway.com`;

  try {
    const publishableKey = process.env.CLOUDBASE_PUBLISHABLE_KEY;
    if (!publishableKey) {
      return { error: 'config_error', message: '未配置 CLOUDBASE_PUBLISHABLE_KEY' };
    }

    const authHeader = { 'Authorization': `Bearer ${publishableKey}` };

    // 1. 验证验证码
    const verifyRes = await fetch(`${baseUrl}/auth/v1/verification/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeader },
      body: JSON.stringify({
        verification_id: verificationId,
        verification_code: verificationCode,
      }),
    });

    const verifyData = await verifyRes.json();
    const verificationToken = verifyData.verification_token;

    if (!verificationToken) {
      const err = verifyData.error_description || verifyData.error || '验证码错误';
      return { error: 'verify_failed', message: err };
    }

    // 2. 使用 verification_token 登录
    const signinRes = await fetch(`${baseUrl}/auth/v1/signin`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeader },
      body: JSON.stringify({ verification_token: verificationToken }),
    });

    const signinData = await signinRes.json();
    const sub = signinData.sub;

    if (!sub) {
      const err = signinData.error_description || signinData.error || '登录失败';
      return { error: 'signin_failed', message: err };
    }

    // 3. 创建自定义登录 ticket（customUserId 使用 Auth 返回的 sub）
    const ticket = app.auth().createTicket(sub, { refresh: 10 * 60 * 1000 });

    return { ticket };
  } catch (e) {
    console.error('authPhoneLogin error:', e);
    return { error: 'server_error', message: e.message || '服务器错误' };
  }
};

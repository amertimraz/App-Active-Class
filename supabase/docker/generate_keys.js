// supabase/docker/generate_keys.js
//
// يولّد ANON_KEY و SERVICE_ROLE_KEY (توكينات JWT موقّعة بـ JWT_SECRET
// بتاعك) اللازمين في .env — بدون أي مكتبات خارجية (Node built-in
// فقط)، عشان ميحتاجش npm install على السيرفر.
//
// الاستخدام:
//   node generate_keys.js YOUR_JWT_SECRET
//
// انسخ القيمتين الناتجتين لـ ANON_KEY و SERVICE_ROLE_KEY في .env.

const crypto = require('crypto');

const secret = process.argv[2];
if (!secret) {
  console.error('الاستخدام: node generate_keys.js YOUR_JWT_SECRET');
  process.exit(1);
}

function base64url(input) {
  return Buffer.from(JSON.stringify(input))
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function signJwt(role) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    role,
    iss: 'supabase',
    iat: now,
    // صالح لمدة 10 سنوات — ده مفتاح client-side ثابت (زي أي anon key
    // في Supabase)، مش توكن جلسة مستخدم.
    exp: now + 10 * 365 * 24 * 60 * 60,
  };
  const data = `${base64url(header)}.${base64url(payload)}`;
  const signature = crypto
    .createHmac('sha256', secret)
    .update(data)
    .digest('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
  return `${data}.${signature}`;
}

console.log('ANON_KEY=' + signJwt('anon'));
console.log('SERVICE_ROLE_KEY=' + signJwt('service_role'));

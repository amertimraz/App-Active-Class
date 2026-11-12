// التحقق من توكن Supabase (HS256) وإرجاع owner_id (spec 057).
import { createHmac, timingSafeEqual } from 'node:crypto';

const b64url = (s) => Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64');

// بيرجّع { ok:true, sub } أو { ok:false }
export function verifyJwt(token, secret, nowSec = Math.floor(Date.now() / 1000)) {
  try {
    if (!token || !secret) return { ok: false };
    const parts = token.split('.');
    if (parts.length !== 3) return { ok: false };
    const [h, p, sig] = parts;
    const header = JSON.parse(b64url(h).toString('utf8'));
    if (header.alg !== 'HS256') return { ok: false }; // نرفض none وأي خوارزمية تانية
    const expected = createHmac('sha256', secret).update(`${h}.${p}`).digest();
    const given = b64url(sig);
    if (expected.length !== given.length || !timingSafeEqual(expected, given)) return { ok: false };
    const payload = JSON.parse(b64url(p).toString('utf8'));
    if (typeof payload.exp === 'number' && payload.exp < nowSec) return { ok: false };
    if (payload.role !== 'authenticated') return { ok: false };
    if (!payload.sub || !/^[0-9a-f-]{36}$/i.test(payload.sub)) return { ok: false };
    return { ok: true, sub: payload.sub };
  } catch {
    return { ok: false };
  }
}

export function bearer(req) {
  const h = req.headers['authorization'] ?? '';
  return h.startsWith('Bearer ') ? h.slice(7).trim() : null;
}

// Meta WhatsApp Cloud API (spec 056). بدون وسيط. معزول هنا عشان أي تغيير مزوّد يكلف ملف واحد.
import { createHmac, timingSafeEqual } from 'node:crypto';
import { buildTemplatePayload } from './templates.js';

const GRAPH = 'https://graph.facebook.com/v21.0';

// تصنيف أخطاء Meta → temp (نعيد المحاولة) / permanent (نفشل) / auth (نوقف الكل)
const TEMP = new Set([130429, 131056, 131000, 1, 2, 4, 17, 80007]);
const AUTH = new Set([190, 10, 200, 133010, 133005, 100001]);
const NOT_ON_WA = new Set([131026]);
const NOT_ALLOWED = new Set([131030]); // رقم تجريبي: مستلم غير مضاف

export function classifyError(httpStatus, err) {
  const code = err?.code;
  if (AUTH.has(code)) return { kind: 'auth', reason: 'provider_auth' };
  if (NOT_ON_WA.has(code)) return { kind: 'permanent', reason: 'not_on_whatsapp' };
  if (NOT_ALLOWED.has(code)) return { kind: 'permanent', reason: 'recipient_not_allowed' };
  if (code === 132000 || code === 132001 || code === 132005 || code === 132012) {
    return { kind: 'permanent', reason: 'template_error' };
  }
  if (TEMP.has(code) || httpStatus >= 500 || httpStatus === 429) {
    return { kind: 'temp', reason: 'provider_error' };
  }
  if (code === 131021 || code === 131009) return { kind: 'permanent', reason: 'invalid_number' };
  return { kind: 'permanent', reason: 'provider_error' };
}

export function createMeta({ token, phoneNumberId, fetchFn = fetch }) {
  return {
    // بيرجع { ok:true, id } أو { ok:false, kind, reason, detail }
    async send(kind, to, vars) {
      let payload;
      try {
        payload = buildTemplatePayload(kind, to, vars);
      } catch (e) {
        return { ok: false, kind: 'permanent', reason: 'template_vars', detail: e.message };
      }
      let res, body;
      try {
        res = await fetchFn(`${GRAPH}/${phoneNumberId}/messages`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
        body = await res.json().catch(() => ({}));
      } catch (e) {
        return { ok: false, kind: 'temp', reason: 'network', detail: e.message };
      }
      const id = body?.messages?.[0]?.id;
      if (res.ok && id) return { ok: true, id };
      const c = classifyError(res.status, body?.error);
      return { ok: false, ...c, detail: body?.error?.message ?? `HTTP ${res.status}` };
    },
  };
}

// تحقق توقيع الـ webhook: header = "sha256=<hex>" على الـ raw body بسر التطبيق.
export function verifySignature(rawBody, header, appSecret) {
  if (!header || !appSecret) return false;
  const expected = 'sha256=' + createHmac('sha256', appSecret).update(rawBody).digest('hex');
  const a = Buffer.from(expected);
  const b = Buffer.from(header);
  return a.length === b.length && timingSafeEqual(a, b);
}

// بيطلّع من payload الـ webhook: statuses (حالات) وstops (ردود إيقاف).
const STOP_WORDS = new Set(['إيقاف', 'ايقاف', 'إيقاف.', 'stop', 'unsubscribe', 'الغاء', 'إلغاء']);

export function normalizeText(s) {
  return String(s ?? '')
    .normalize('NFKC')
    .replace(/[ً-ٟـ]/g, '') // تشكيل وتطويل
    .trim()
    .toLowerCase();
}

export function isStopWord(text) {
  const n = normalizeText(text);
  return STOP_WORDS.has(n) || STOP_WORDS.has(n.replace(/[.!؟?]+$/, ''));
}

const RANK = { sent: 1, delivered: 2, read: 3 };
export function statusRank(s) {
  return RANK[s] ?? 0;
}

export function parseWebhook(payload) {
  const statuses = [];
  const stops = [];
  for (const entry of payload?.entry ?? []) {
    for (const ch of entry?.changes ?? []) {
      const v = ch?.value ?? {};
      for (const s of v.statuses ?? []) {
        statuses.push({
          id: s.id,
          status: s.status, // sent | delivered | read | failed
          at: s.timestamp ? new Date(Number(s.timestamp) * 1000) : new Date(),
          error: s.errors?.[0] ?? null,
        });
      }
      for (const m of v.messages ?? []) {
        if (m.type === 'text' && isStopWord(m.text?.body)) stops.push({ from: m.from });
      }
    }
  }
  return { statuses, stops };
}

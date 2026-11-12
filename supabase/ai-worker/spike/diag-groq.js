// تشخيص مؤقت: بيقرا مفتاح Groq من app_secrets (أو البيئة) وبيجرّب النموذج المضبوط.
// بيطبع الحالة ورسالة الخطأ فقط — ولا بيطبع المفتاح. شغّله جوه حاوية ai-worker:
//   docker cp spike/diag-groq.js ai-worker:/app/diag.js && docker exec ai-worker node diag.js
import pg from 'pg';

const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select key, value from app_secrets where key = 'GROQ_API_KEY'`);
const cfg = await db.query(`select value from ai_config where key = 'groq_model'`);
const key = rows[0]?.value ?? process.env.GROQ_API_KEY;
const model = cfg.rows[0]?.value ?? 'meta-llama/llama-4-maverick-17b-128e-instruct';
await db.end();
if (!key) { console.log('مفيش مفتاح Groq'); process.exit(0); }
console.log('model مضبوط =', model, '| طول المفتاح =', key.length, '| يبدأ بـ', key.slice(0, 4));

const H = { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };

let r = await fetch('https://api.groq.com/openai/v1/models', { headers: H });
const body = await r.json().catch(() => ({}));
console.log('GET /models ->', r.status, body?.error?.message ?? '');
const ids = (body?.data ?? []).map((m) => m.id);
console.log('كل النماذج المتاحة:', ids.join(', '));
console.log('النموذج المضبوط متاح؟', ids.includes(model));

r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
  method: 'POST', headers: H,
  body: JSON.stringify({ model, messages: [{ role: 'user', content: 'قل: تمام' }], max_tokens: 10 }),
});
const b2 = await r.json().catch(() => ({}));
console.log('chat نص بس ->', r.status, b2?.error?.message ?? b2?.choices?.[0]?.message?.content ?? '');

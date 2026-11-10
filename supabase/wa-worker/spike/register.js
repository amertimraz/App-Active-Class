// spike مؤقت (spec 056 / T002): يسجّل رقم الإرسال على Cloud API بـ PIN من 6 أرقام.
// الاستخدام: node spike/register.js 123456   (الـ PIN تختاره إنت وتحتفظ به)
// بعدها يعيد قراءة حالة الرقم.
import { readFileSync } from 'node:fs';

const env = {};
for (const line of readFileSync(new URL('../.env', import.meta.url), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*?)\s*$/);
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
}
const pin = process.argv[2];
if (!/^\d{6}$/.test(pin ?? '')) { console.error('اكتب PIN من 6 أرقام: node spike/register.js 123456'); process.exit(1); }

const base = 'https://graph.facebook.com/v21.0';
const headers = { Authorization: `Bearer ${env.WA_TOKEN}`, 'Content-Type': 'application/json' };

let r = await fetch(`${base}/${env.WA_PHONE_NUMBER_ID}/register`, {
  method: 'POST', headers, body: JSON.stringify({ messaging_product: 'whatsapp', pin }),
});
console.log('\n== register → HTTP', r.status, '\n' + await r.text());

r = await fetch(`${base}/${env.WA_PHONE_NUMBER_ID}?fields=display_phone_number,status,quality_rating,code_verification_status`, { headers });
console.log('\n== status → HTTP', r.status, '\n' + await r.text());

// spike مؤقت (spec 056 / T002): يبعت قالب hello_world عبر Meta Cloud API ويطبع الرد الخام.
// الاستخدام: node spike/send.js   (يقرأ ../.env — ممنوع commit)
// بيطبع الرد بدون التوكن.
import { readFileSync } from 'node:fs';

const env = {};
try {
  for (const line of readFileSync(new URL('../.env', import.meta.url), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*?)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
} catch {
  console.error('مفيش ملف supabase/wa-worker/.env'); process.exit(1);
}

const { WA_TOKEN, WA_PHONE_NUMBER_ID, TEST_TO } = env;
if (!WA_TOKEN || !WA_PHONE_NUMBER_ID || !TEST_TO) {
  console.error('ناقص واحد من: WA_TOKEN, WA_PHONE_NUMBER_ID, TEST_TO'); process.exit(1);
}

const base = `https://graph.facebook.com/v21.0`;
const headers = { Authorization: `Bearer ${WA_TOKEN}`, 'Content-Type': 'application/json' };

async function call(label, url, init) {
  const r = await fetch(url, { ...init, headers });
  const text = await r.text();
  console.log(`\n== ${label} → HTTP ${r.status}`);
  console.log(text);
}

// 0) تشخيص: التوكن لمين؟ وإيه حسابات واتساب والأرقام اللي شايفها؟
await call('من أنا (التوكن)', `${base}/me?fields=id,name`);
if (env.WA_WABA_ID) {
  await call('الأرقام تحت حساب واتساب', `${base}/${env.WA_WABA_ID}/phone_numbers?fields=id,display_phone_number,verified_name,status`);
}
await call('حسابات واتساب المرئية', `${base}/me/businesses?fields=id,name,owned_whatsapp_business_accounts{id,name}`);

// 1) هل الـ ID موجود وعندنا صلاحية عليه؟
await call('قراءة الرقم', `${base}/${WA_PHONE_NUMBER_ID}?fields=display_phone_number,verified_name,quality_rating,status`);

// 2) إرسال القالب الجاهز
await call('إرسال hello_world', `${base}/${WA_PHONE_NUMBER_ID}/messages`, {
  method: 'POST',
  body: JSON.stringify({
    messaging_product: 'whatsapp',
    to: TEST_TO,
    type: 'template',
    template: { name: 'hello_world', language: { code: 'en_US' } },
  }),
});

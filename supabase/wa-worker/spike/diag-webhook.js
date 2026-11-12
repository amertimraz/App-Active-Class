// تشخيص مؤقت: يجرّب تحقق الـwebhook محليًا بنفس رمز التحقق المخزّن (بدون طباعته).
import pg from 'pg';

const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select key, value from app_secrets where key in ('WA_VERIFY_TOKEN','WA_APP_SECRET','WA_PHONE_NUMBER_ID')`);
await db.end();
const m = Object.fromEntries(rows.map((r) => [r.key, r.value]));
console.log('مضبوط في اللوحة:', ['WA_VERIFY_TOKEN', 'WA_APP_SECRET', 'WA_PHONE_NUMBER_ID'].map((k) => `${k}=${m[k] ? 'نعم' : 'لأ'}`).join(' | '));
if (m.WA_VERIFY_TOKEN) {
  const base = 'http://127.0.0.1:8787/wa/webhook';
  let r = await fetch(`${base}?hub.mode=subscribe&hub.verify_token=${encodeURIComponent(m.WA_VERIFY_TOKEN)}&hub.challenge=777`);
  console.log('تحقق بالرمز الصحيح ->', r.status, await r.text());
  r = await fetch(`${base}?hub.mode=subscribe&hub.verify_token=wrong&hub.challenge=777`);
  console.log('تحقق بالرمز الغلط ->', r.status);
}

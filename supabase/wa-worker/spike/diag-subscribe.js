// تشخيص مؤقت: يشترك تطبيق الـwebhook في حسابات واتساب للأعمال ويطبع المشتركين بعدها. بدون طباعة التوكن.
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-subscribe.js <waba_id> [<waba_id> ...]
import pg from 'pg';

const wabas = process.argv.slice(2);
if (!wabas.length) { console.log('اكتب WABA ID'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const H = { Authorization: `Bearer ${token}` };
const show = (r, b) => `${r.status} ${b?.error ? `${b.error.code}: ${b.error.message}` : JSON.stringify(b)}`;
for (const w of wabas) {
  let r = await fetch(`https://graph.facebook.com/v21.0/${w}/subscribed_apps`, { method: 'POST', headers: H });
  console.log(`اشتراك ${w} ->`, show(r, await r.json().catch(() => ({}))));
  r = await fetch(`https://graph.facebook.com/v21.0/${w}/subscribed_apps`, { headers: H });
  const b = await r.json().catch(() => ({}));
  console.log(`المشتركين في ${w} ->`, b?.error ? show(r, b) : (b.data ?? []).map((a) => a.whatsapp_business_api_data?.name ?? a.id).join(' | ') || '(لا أحد)');
}

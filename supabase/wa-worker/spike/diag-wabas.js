// تشخيص مؤقت: كل حسابات واتساب للأعمال (WABA) تحت حافظة الأعمال وأرقامها وأسماؤها. بدون طباعة التوكن.
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-wabas.js <business_id> [waba_id ...]
import pg from 'pg';

const [biz, ...extra] = process.argv.slice(2);
if (!biz) { console.log('اكتب Business ID'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const get = async (path) => {
  const r = await fetch(`https://graph.facebook.com/v21.0/${path}`, { headers: { Authorization: `Bearer ${token}` } });
  const b = await r.json().catch(() => ({}));
  return b?.error ? { error: `HTTP ${r.status} ${b.error.code}: ${b.error.message}` } : b;
};
const ids = new Set(extra);
for (const edge of ['owned_whatsapp_business_accounts', 'client_whatsapp_business_accounts']) {
  const b = await get(`${biz}/${edge}?fields=id,name&limit=50`);
  const list = (b.data ?? []).map((w) => `${w.id}=${w.name}`).join(' | ');
  console.log(edge, b.error ? b.error : (list || '(فاضي)'));
  for (const w of b.data ?? []) ids.add(w.id);
}
for (const id of ids) {
  const w = await get(`${id}?fields=name,account_review_status`);
  const p = await get(`${id}/phone_numbers?fields=id,display_phone_number,verified_name,new_display_name`);
  console.log(`WABA ${id}:`, w.error ?? `${w.name} (${w.account_review_status})`,
    '| أرقام:', p.error ?? ((p.data ?? []).map((x) => `${x.id} ${x.display_phone_number} «${x.verified_name}»${x.new_display_name ? ' جديد=«' + x.new_display_name + '»' : ''}`).join(' ; ') || 'لا يوجد'));
}

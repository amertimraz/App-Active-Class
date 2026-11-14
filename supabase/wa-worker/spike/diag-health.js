// تشخيص مؤقت: صحة حساب واتساب للأعمال (can_send_message + أسباب الحجب) وتطبيقات الـwebhook المشتركة. بدون طباعة التوكن.
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-health.js <waba_id> <phone_number_id>
import pg from 'pg';

const [waba, pid] = process.argv.slice(2);
if (!waba || !pid) { console.log('اكتب WABA ID و Phone Number ID'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const get = async (path) => {
  const r = await fetch(`https://graph.facebook.com/v21.0/${path}`, { headers: { Authorization: `Bearer ${token}` } });
  const b = await r.json().catch(() => ({}));
  return b?.error ? `HTTP ${r.status} ${b.error.code}: ${b.error.message}` : JSON.stringify(b);
};
console.log('WABA:', await get(`${waba}?fields=name,currency,account_review_status,business_verification_status,health_status`));
console.log('الرقم:', await get(`${pid}?fields=health_status,messaging_limit_tier,throughput`));
console.log('subscribed_apps:', await get(`${waba}/subscribed_apps`));

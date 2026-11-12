// تشخيص مؤقت: حالة طلب تغيير اسم العرض لرقم واتساب (بدون طباعة التوكن)
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-name.js <phone_number_id>
import pg from 'pg';

const [pid] = process.argv.slice(2);
if (!pid) { console.log('اكتب Phone Number ID'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const r = await fetch(
  `https://graph.facebook.com/v21.0/${pid}?fields=verified_name,name_status,new_display_name,new_name_status,quality_rating,status,account_mode`,
  { headers: { Authorization: `Bearer ${token}` } });
const b = await r.json().catch(() => ({}));
console.log(r.status, b?.error ? `${b.error.code}: ${b.error.message}` : JSON.stringify(b));

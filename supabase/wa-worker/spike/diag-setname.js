// تشخيص مؤقت: يعيد تقديم طلب اسم العرض لرقم واتساب عبر الـAPI ويطبع النتيجة وحالة الاسم بعدها. بدون طباعة التوكن.
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-setname.js <phone_number_id> "<الاسم الجديد>"
import pg from 'pg';

const [pid, name] = process.argv.slice(2);
if (!pid || !name) { console.log('اكتب Phone Number ID والاسم'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const H = { Authorization: `Bearer ${token}` };
const show = (r, b) => `${r.status} ${b?.error ? `${b.error.code}/${b.error.error_subcode ?? '-'}: ${b.error.message}${b.error.error_user_msg ? ' | ' + b.error.error_user_msg : ''}` : JSON.stringify(b)}`;

let r = await fetch(`https://graph.facebook.com/v21.0/${pid}`, {
  method: 'POST',
  headers: { ...H, 'Content-Type': 'application/json' },
  body: JSON.stringify({ new_display_name: name }),
});
console.log('طلب الاسم ->', show(r, await r.json().catch(() => ({}))));

r = await fetch(`https://graph.facebook.com/v21.0/${pid}?fields=verified_name,name_status,new_display_name,new_name_status`, { headers: H });
console.log('الحالة بعدها ->', show(r, await r.json().catch(() => ({}))));

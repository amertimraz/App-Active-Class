// تشخيص مؤقت: هل توكن wa-worker شايف رقم واتساب معيّن وحالته؟ (بدون طباعة التوكن)
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-number.js <phone_number_id> [waba_id ...]
import pg from 'pg';

const [pid, ...wabas] = process.argv.slice(2);
if (!pid) { console.log('اكتب Phone Number ID'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const H = { Authorization: `Bearer ${token}` };
const g = async (label, path) => {
  const r = await fetch(`https://graph.facebook.com/v21.0/${path}`, { headers: H });
  const b = await r.json().catch(() => ({}));
  const err = b?.error ? `${b.error.code}/${b.error.error_subcode ?? '-'}: ${b.error.message}` : '';
  console.log(label, '->', r.status, err || JSON.stringify(b));
};
await g('me', 'me?fields=id,name');
await g('phone', `${pid}?fields=display_phone_number,verified_name,status,quality_rating,code_verification_status`);
for (const w of wabas) await g(`waba ${w}`, `${w}?fields=id,name&access_token=${token}`.replace(`&access_token=${token}`, ''));
for (const w of wabas) await g(`waba ${w} numbers`, `${w}/phone_numbers?fields=id,display_phone_number,status`);

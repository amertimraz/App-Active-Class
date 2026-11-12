// تشخيص مؤقت: يبعت قالب hello_world لرقم واحد حدّده المالك (بدون طباعة التوكن).
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-send.js <phone_number_id> <to_digits>
import pg from 'pg';

const [pid, to] = process.argv.slice(2);
if (!pid || !/^\d{8,15}$/.test(to ?? '')) { console.log('اكتب: <phone_number_id> <رقم المستلم بالأرقام الدولية>'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const r = await fetch(`https://graph.facebook.com/v21.0/${pid}/messages`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    messaging_product: 'whatsapp',
    to,
    type: 'template',
    template: { name: 'hello_world', language: { code: 'en_US' } },
  }),
});
const b = await r.json().catch(() => ({}));
const err = b?.error ? `${b.error.code}/${b.error.error_subcode ?? '-'}: ${b.error.message}` : '';
console.log('HTTP', r.status, err || JSON.stringify(b));

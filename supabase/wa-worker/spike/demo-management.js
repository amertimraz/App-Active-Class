// عرض لمراجعة Meta (whatsapp_business_management): استدعاءات API حقيقية على الحساب ثم إنشاء قالب رسالة.
// بدون طباعة التوكن. الاستخدام جوه الحاوية: docker exec wa-worker node demo-management.js <waba_id>
import pg from 'pg';

const waba = process.argv[2];
if (!waba) { console.log('اكتب WABA ID'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const H = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
const G = 'https://graph.facebook.com/v21.0';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const show = (title, status, obj) => {
  console.log(`\n=== ${title} ===`);
  console.log(`HTTP ${status}`);
  console.log(JSON.stringify(obj, null, 2));
};

// 1) بيانات حساب واتساب للأعمال
let r = await fetch(`${G}/${waba}?fields=name,currency,timezone_id,account_review_status`, { headers: H });
show('GET /{waba-id}  (بيانات الحساب)', r.status, await r.json());
await sleep(1500);

// 2) أرقام الهاتف
r = await fetch(`${G}/${waba}/phone_numbers?fields=display_phone_number,verified_name,quality_rating,messaging_limit_tier`, { headers: H });
show('GET /{waba-id}/phone_numbers  (الأرقام)', r.status, await r.json());
await sleep(1500);

// 3) القوالب الحالية (أسماء وحالات فقط)
r = await fetch(`${G}/${waba}/message_templates?fields=name,status,category,language&limit=5`, { headers: H });
show('GET /{waba-id}/message_templates  (قبل الإنشاء)', r.status, await r.json());
await sleep(1500);

// 4) إنشاء قالب رسالة جديد
const name = `absence_notice_demo_${Date.now().toString().slice(-6)}`;
const body = {
  name,
  language: 'ar',
  category: 'UTILITY',
  components: [{
    type: 'BODY',
    text: 'تنبيه من {{1}}: الطالب {{2}} غاب عن حصة {{3}} اليوم.',
    example: { body_text: [['أ/ أحمد', 'محمد', 'الرياضيات']] },
  }],
};
console.log('\n=== POST /{waba-id}/message_templates  (إنشاء قالب) ===');
console.log(JSON.stringify(body, null, 2));
r = await fetch(`${G}/${waba}/message_templates`, { method: 'POST', headers: H, body: JSON.stringify(body) });
show('الرد', r.status, await r.json());
await sleep(2000);

// 5) القالب الجديد في القائمة
r = await fetch(`${G}/${waba}/message_templates?name=${name}&fields=name,status,category,language`, { headers: H });
show('GET /{waba-id}/message_templates?name=...  (بعد الإنشاء)', r.status, await r.json());

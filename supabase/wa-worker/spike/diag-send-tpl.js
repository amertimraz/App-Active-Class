// تشخيص مؤقت: يبعت قالب الغياب لرقم الاختبار ويطبع خطأ Meta الحقيقي (بدون طباعة التوكن).
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-send-tpl.js <to> [ar_EG|ar]
import pg from 'pg';
import { buildTemplatePayload } from './src/templates.js';

const [to, lang] = process.argv.slice(2);
if (!to) { console.log('اكتب الرقم'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select key, value from app_secrets where key in ('WA_TOKEN','WA_PHONE_NUMBER_ID')`);
await db.end();
const s = Object.fromEntries(rows.map((r) => [r.key, r.value]));
const payload = buildTemplatePayload('absence', to, {
  student: 'تجريبي', group: 'مجموعة تجريبية', date: '2026-11-12',
  teacher: 'عامر تمراز', teacher_phone: '+201096066818',
});
if (lang) payload.template.language.code = lang;
const r = await fetch(`https://graph.facebook.com/v21.0/${s.WA_PHONE_NUMBER_ID}/messages`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${s.WA_TOKEN}`, 'Content-Type': 'application/json' },
  body: JSON.stringify(payload),
});
const b = await r.json().catch(() => ({}));
console.log(r.status, JSON.stringify(b?.error ?? b));

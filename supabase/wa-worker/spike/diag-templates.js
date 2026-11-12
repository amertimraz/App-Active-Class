// تشخيص مؤقت: حالة قوالب واتساب (الاسم/الحالة/الفئة/اللغة/سبب الرفض) — بدون طباعة التوكن.
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-templates.js <waba_id>
import pg from 'pg';

const waba = process.argv[2];
if (!waba) { console.log('اكتب WABA ID'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const r = await fetch(
  `https://graph.facebook.com/v21.0/${waba}/message_templates?fields=name,status,category,language,rejected_reason,components&limit=50`,
  { headers: { Authorization: `Bearer ${token}` } });
const b = await r.json().catch(() => ({}));
if (b?.error) { console.log('HTTP', r.status, `${b.error.code}: ${b.error.message}`); process.exit(0); }
for (const t of b.data ?? []) {
  const body = (t.components ?? []).find((c) => c.type === 'BODY')?.text ?? '';
  const vars = (body.match(/\{\{\d+\}\}/g) ?? []).length;
  const btns = (t.components ?? []).filter((c) => c.type === 'BUTTONS').length;
  console.log(`${t.name} | ${t.language} | ${t.category} | ${t.status}${t.rejected_reason && t.rejected_reason !== 'NONE' ? ' | سبب: ' + t.rejected_reason : ''} | متغيرات=${vars} | أزرار=${btns}`);
}
if (!(b.data ?? []).length) console.log('مفيش قوالب');

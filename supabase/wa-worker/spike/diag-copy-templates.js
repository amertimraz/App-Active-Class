// مؤقت: ينسخ قوالب ac_* المعتمدة من حساب واتساب (src) لحساب الرقم الفعلي (dst).
// الاستخدام جوه الحاوية: docker exec wa-worker node diag-copy-templates.js <src_waba> <dst_waba>
import pg from 'pg';

const [src, dst] = process.argv.slice(2);
if (!src || !dst) { console.log('اكتب src dst'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const H = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
const G = 'https://graph.facebook.com/v21.0';

const r = await fetch(`${G}/${src}/message_templates?fields=name,status,category,language,components&limit=50`, { headers: H });
const list = (await r.json()).data ?? [];
for (const t of list.filter((x) => x.name.startsWith('ac_') && x.status === 'APPROVED')) {
  const body = { name: t.name, language: t.language, category: t.category, components: t.components };
  const p = await fetch(`${G}/${dst}/message_templates`, { method: 'POST', headers: H, body: JSON.stringify(body) });
  const b = await p.json().catch(() => ({}));
  console.log(t.name, t.language, t.category, '->', p.status, JSON.stringify(b?.error ? { code: b.error.code, msg: b.error.message, user: b.error.error_user_msg } : b));
}

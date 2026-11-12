// تشخيص مؤقت: صلاحيات التوكن المخزّن (scopes) والتطبيق اللي طالع منه — بدون طباعة التوكن.
import pg from 'pg';

const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'WA_TOKEN'`);
await db.end();
const token = rows[0]?.value ?? process.env.WA_TOKEN;
const r = await fetch(`https://graph.facebook.com/v21.0/debug_token?input_token=${token}&access_token=${token}`);
const b = await r.json().catch(() => ({}));
const d = b?.data ?? {};
console.log('HTTP', r.status, b?.error?.message ?? '');
console.log('app =', d.application, '| type =', d.type, '| valid =', d.is_valid, '| expires =', d.expires_at);
console.log('scopes =', (d.scopes ?? []).join(', '));
console.log('granular =', JSON.stringify(d.granular_scopes ?? []).slice(0, 400));

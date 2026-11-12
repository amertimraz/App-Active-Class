// نقطة تشغيل wa-worker (spec 056).
// متغيرات البيئة: DB_URL, WA_TOKEN, WA_PHONE_NUMBER_ID, WA_APP_SECRET, WA_VERIFY_TOKEN, PORT
import http from 'node:http';
import pg from 'pg';
import { createMeta } from './meta.js';
import { createSecrets } from './secrets.js';
import { createSender } from './sender.js';
import { createWebhookHandler } from './webhook.js';

// المفاتيح بتيجي من لوحة الأدمن (app_secrets) أو البيئة — الإلزامي DB_URL بس.
const need = ['DB_URL'];
const missing = need.filter((k) => !process.env[k]);
if (missing.length) {
  console.error('[wa] متغيرات ناقصة:', missing.join(', '));
  process.exit(1);
}

const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 4 });
const secrets = createSecrets({ db });
const meta = createMeta({
  token: () => secrets.get('WA_TOKEN'),
  phoneNumberId: () => secrets.get('WA_PHONE_NUMBER_ID'),
});
const sender = createSender({ db, meta });
const webhook = createWebhookHandler({
  db,
  appSecret: () => secrets.get('WA_APP_SECRET'),
  verifyToken: () => secrets.get('WA_VERIFY_TOKEN'),
});

const server = http.createServer((req, res) => {
  if (req.url === '/wa/health') { res.writeHead(200); return res.end('ok'); }
  if (!req.url.startsWith('/wa/webhook')) { res.writeHead(404); return res.end(); }
  const chunks = [];
  let size = 0;
  req.on('data', (c) => { size += c.length; if (size > 1_000_000) req.destroy(); else chunks.push(c); });
  req.on('end', () => webhook(req, res, Buffer.concat(chunks)).catch((e) => {
    console.error('[wa] http', e.message); res.writeHead(500); res.end();
  }));
});
server.listen(Number(process.env.PORT ?? 8787), () => console.log('[wa] جاهز'));

let busy = false;
setInterval(async () => {
  if (busy) return;
  busy = true;
  try {
    // لسه المفاتيح مش متضبوطة (من اللوحة أو البيئة) → ما نبعتش ولا نفشّل الطلبات.
    if (!(await secrets.get('WA_TOKEN')) || !(await secrets.get('WA_PHONE_NUMBER_ID'))) return;
    await sender.tick();
  } catch (e) { console.error('[wa] tick', e.message); } finally { busy = false; }
}, 2000);

// تنظيف يومي للسجل القديم
setInterval(() => db.query('select wa_purge_old()').catch((e) => console.error('[wa] purge', e.message)), 24 * 3600_000);

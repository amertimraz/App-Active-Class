// تشخيص مؤقت: هل نموذج Groq المحدد بيقبل صور؟ (صورة صغيرة 8x8 مولّدة هنا).
// الاستخدام جوه الحاوية: docker exec ai-worker node diag-vision.js <model>
import pg from 'pg';
import { createRequire } from 'node:module';

const model = process.argv[2];
if (!model) { console.log('اكتب اسم النموذج'); process.exit(0); }
const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });
const { rows } = await db.query(`select value from app_secrets where key = 'GROQ_API_KEY'`);
await db.end();
const key = rows[0]?.value ?? process.env.GROQ_API_KEY;

// PNG أحمر 64x64 مولّد هنا (الحد الأدنى للنموذج 32 بكسل)
const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = (b) => { let c = 0xffffffff; for (const x of b) c = crcTable[(c ^ x) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (t, d) => { const len = Buffer.alloc(4); len.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
const W = 64;
const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(W, 4); ihdr[8] = 8; ihdr[9] = 2;
const raw = Buffer.alloc((W * 3 + 1) * W); for (let y = 0; y < W; y++) for (let x = 0; x < W; x++) raw[y * (W * 3 + 1) + 1 + x * 3] = 255;
const zlib = createRequire(import.meta.url)('node:zlib');
const png = Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]).toString('base64');
const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
  method: 'POST',
  headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    model,
    max_tokens: 20,
    messages: [{ role: 'user', content: [
      { type: 'text', text: 'ما لون هذه الصورة؟ جاوب بكلمة.' },
      { type: 'image_url', image_url: { url: `data:image/png;base64,${png}` } },
    ] }],
  }),
});
const b = await r.json().catch(() => ({}));
console.log(model, '->', r.status, b?.error?.message ?? b?.choices?.[0]?.message?.content ?? '');

// نقطة تشغيل ai-worker (spec 057).
// متغيرات البيئة: DB_URL, JWT_SECRET, PORT (والمفاتيح GROQ_API_KEY/ANTHROPIC_API_KEY من لوحة الأدمن أو البيئة)
import http from 'node:http';
import pg from 'pg';

import { verifyJwt, bearer } from './auth.js';
import { createSecrets } from './secrets.js';
import { createGroq } from './providers/groq.js';
import { createClaude } from './providers/claude.js';
import { extract } from './providers/index.js';
import {
  createConfigLoader, createJob, getJob, publicJob, quotaFor, createQueue, runJob, failOrphans,
} from './jobs.js';

const need = ['DB_URL', 'JWT_SECRET'];
const missing = need.filter((k) => !process.env[k]);
if (missing.length) { console.error('[ai] متغيرات ناقصة:', missing.join(', ')); process.exit(1); }

const db = new pg.Pool({ connectionString: process.env.DB_URL, max: 6 });
const secrets = createSecrets({ db });
const loadCfg = createConfigLoader(db);

// المزوّدين: المفتاح والنموذج بيتقروا وقت الطلب (تغيير من اللوحة يسري خلال دقيقة)
const providers = {
  groq: createGroq({ apiKey: () => secrets.get('GROQ_API_KEY'), model: async () => (await loadCfg()).groqModel }),
  claude: createClaude({ apiKey: () => secrets.get('ANTHROPIC_API_KEY'), model: async () => (await loadCfg()).claudeModel }),
};

let concurrency = 3;
const queue = createQueue({
  getConcurrency: () => concurrency,
  run: async ({ job, payload }) => {
    const cfg = await loadCfg();
    await runJob(db, { extract, providers, cfg, job, payload });
  },
});

const json = (res, code, obj) => {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(obj));
};

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) { reject(Object.assign(new Error('too_large'), { code: 'too_large' })); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const server = http.createServer(async (req, res) => {
  try {
    const path = new URL(req.url, 'http://x').pathname;
    if (path === '/ai/health') return json(res, 200, { ok: true });
    if (!path.startsWith('/ai/exam/')) return json(res, 404, { error: 'not_found' });

    const auth = verifyJwt(bearer(req), process.env.JWT_SECRET);
    if (!auth.ok) return json(res, 401, { error: 'unauthorized' });
    const owner = auth.sub;
    const cfg = await loadCfg();
    concurrency = cfg.concurrency;

    if (req.method === 'GET' && path === '/ai/exam/quota') {
      return json(res, 200, await quotaFor(db, owner));
    }

    const m = path.match(/^\/ai\/exam\/jobs\/([^/]+)$/);
    if (req.method === 'GET' && m) {
      if (!UUID.test(m[1])) return json(res, 404, { error: 'not_found' });
      const job = await getJob(db, owner, m[1]);
      return job ? json(res, 200, publicJob(job)) : json(res, 404, { error: 'not_found' });
    }

    if (req.method === 'POST' && path === '/ai/exam/jobs') {
      if (cfg.killSwitch) return json(res, 403, { error: 'paused' });
      let body;
      try {
        const raw = await readBody(req, Math.ceil(cfg.maxBytes * 1.4) + 4096);
        body = JSON.parse(raw.toString('utf8'));
      } catch (e) {
        return json(res, e.code === 'too_large' ? 413 : 422, { error: e.code === 'too_large' ? 'too_large' : 'invalid_request' });
      }

      const { job_id: id, mode, images = [], text = '', count = 10, mcq_count: mcqIn, tf_count: tfIn, difficulty = 'medium', language = 'ar' } = body ?? {};
      if (!UUID.test(id ?? '') || !['convert', 'generate'].includes(mode)) return json(res, 422, { error: 'invalid_request' });
      if (!Array.isArray(images) || images.some((x) => typeof x !== 'string')) return json(res, 422, { error: 'invalid_request' });
      if (images.length > cfg.maxImages) return json(res, 413, { error: 'too_large' });
      const bytes = images.reduce((s, x) => s + x.length * 0.75, 0);
      if (bytes > cfg.maxBytes) return json(res, 413, { error: 'too_large' });
      if (mode === 'convert' && images.length === 0) return json(res, 422, { error: 'invalid_request' });
      if (mode === 'generate' && images.length === 0 && String(text).trim().length < 40) return json(res, 422, { error: 'invalid_request' });
      // عدد كل نوع (وضع التوليد): mcq_count + tf_count، وبدونهم count كله اختيار من متعدد.
      let mcq = Number.isInteger(mcqIn) ? Math.max(mcqIn, 0) : null;
      let tf = Number.isInteger(tfIn) ? Math.max(tfIn, 0) : 0;
      if (mcq === null) mcq = Math.max((parseInt(count, 10) || 10) - tf, 0);
      if (mcq + tf > cfg.maxQuestions) return json(res, 422, { error: 'invalid_request' });
      if (mode === 'generate' && mcq + tf < 1) return json(res, 422, { error: 'invalid_request' });
      const n = Math.max(mcq + tf, 1);
      const diff = ['easy', 'medium', 'hard'].includes(difficulty) ? difficulty : 'medium';

      const created = await createJob(db, {
        id, owner, mode, params: { count: n, mcq, tf, difficulty: diff, language, pages: images.length },
      });
      if (created.kind === 'paused') return json(res, 403, { error: 'paused' });
      if (created.kind === 'quota') return json(res, 402, { error: 'quota' });
      if (created.kind === 'existing') {
        return created.job ? json(res, 200, publicJob(created.job)) : json(res, 409, { error: 'conflict' });
      }
      const ok = queue.push({
        job: created.job,
        payload: { images, text: String(text).slice(0, 60000), count: n, mcq, tf, difficulty: diff, language },
      });
      if (!ok) {
        // الطابور ممتلئ: نفشّل الطلب ونرد الحجز
        await db.query('select ai_release($1, $2)', [owner, created.job.charged]);
        await db.query(`update ai_jobs set status = 'failed', fail_reason = 'busy', charged = null, finished_at = now() where id = $1`, [id]);
        return json(res, 503, { error: 'busy' });
      }
      return json(res, 202, { job_id: id, status: 'queued' });
    }

    return json(res, 404, { error: 'not_found' });
  } catch (e) {
    console.error('[ai] http', e.message);
    json(res, 500, { error: 'server_error' });
  }
});

const orphans = await failOrphans(db).catch(() => 0);
if (orphans) console.log(`[ai] ${orphans} طلب قديم اتقفل بعد إعادة التشغيل`);
server.listen(Number(process.env.PORT ?? 8788), () => console.log('[ai] جاهز'));

setInterval(() => db.query('select ai_purge_old()').catch((e) => console.error('[ai] purge', e.message)), 6 * 3600_000);

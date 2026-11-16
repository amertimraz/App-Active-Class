// حالة الطلبات والحصة وقائمة الانتظار (spec 057). الصور في الذاكرة فقط.

const DEFAULT_CFG = {
  defaultProvider: 'groq',
  fallbackProvider: 'claude',
  groqModel: 'qwen/qwen3.8-27b',
  claudeModel: 'claude-sonnet-5-5',
  maxImages: 10,
  maxBytes: 15 * 1024 * 1024,
  maxQuestions: 30,
  concurrency: 3,
  killSwitch: false,
};

const jv = (v) => (typeof v === 'string' ? (() => { try { return JSON.parse(v); } catch { return v; } })() : v);

export function createConfigLoader(db, { ttlMs = 30_000, now = () => Date.now() } = {}) {
  let cache = null;
  let at = 0;
  return async function load() {
    if (cache && now() - at < ttlMs) return cache;
    let m = {};
    try {
      const { rows } = await db.query('select key, value from ai_config');
      m = Object.fromEntries(rows.map((r) => [r.key, jv(r.value)]));
    } catch { /* الجدول لسه مش موجود → الافتراضي */ }
    cache = {
      defaultProvider: m.default_provider ?? DEFAULT_CFG.defaultProvider,
      fallbackProvider: m.fallback_provider ?? DEFAULT_CFG.fallbackProvider,
      groqModel: m.groq_model ?? DEFAULT_CFG.groqModel,
      claudeModel: m.claude_model ?? DEFAULT_CFG.claudeModel,
      maxImages: Number(m.max_images ?? DEFAULT_CFG.maxImages),
      maxBytes: Number(m.max_bytes ?? DEFAULT_CFG.maxBytes),
      maxQuestions: Number(m.max_questions ?? DEFAULT_CFG.maxQuestions),
      concurrency: Number(m.concurrency ?? DEFAULT_CFG.concurrency),
      killSwitch: m.kill_switch === true || m.kill_switch === 'true',
    };
    at = now();
    return cache;
  };
}

// بيحدد لو الطلب جديد، وبيحجز الحصة في نفس الـ transaction.
// بيرجّع { kind:'created'|'existing'|'quota'|'paused', job }
export async function createJob(db, { id, owner, mode, params }) {
  const c = await db.connect();
  try {
    await c.query('begin');
    const paused = await c.query('select paused_by_admin from ai_teacher_settings where owner_id = $1', [owner]);
    if (paused.rows[0]?.paused_by_admin) { await c.query('rollback'); return { kind: 'paused' }; }

    const ins = await c.query(
      `insert into ai_jobs (id, owner_id, mode, params) values ($1, $2, $3, $4)
       on conflict (id) do nothing returning *`,
      [id, owner, mode, JSON.stringify(params)],
    );
    if (!ins.rows.length) {
      const ex = await c.query('select * from ai_jobs where id = $1 and owner_id = $2', [id, owner]);
      await c.query('commit');
      return ex.rows.length ? { kind: 'existing', job: ex.rows[0] } : { kind: 'existing', job: null };
    }
    const { rows: [{ q }] } = await c.query('select ai_reserve($1) as q', [owner]);
    if (!q) { await c.query('rollback'); return { kind: 'quota' }; }
    const up = await c.query('update ai_jobs set charged = $2 where id = $1 returning *', [id, q]);
    await c.query('commit');
    return { kind: 'created', job: up.rows[0] };
  } catch (e) {
    await c.query('rollback').catch(() => {});
    throw e;
  } finally {
    c.release();
  }
}

export async function getJob(db, owner, id) {
  const { rows } = await db.query('select * from ai_jobs where id = $1 and owner_id = $2', [id, owner]);
  return rows[0] ?? null;
}

export function publicJob(j) {
  return {
    job_id: j.id,
    status: j.status,
    fail_reason: j.fail_reason ?? null,
    progress: j.progress ?? null,
    result: j.status === 'done' ? j.result : undefined,
  };
}

export async function quotaFor(db, owner) {
  const month = new Date().toLocaleDateString('en-CA', { timeZone: 'Africa/Cairo' }).slice(0, 7) + '-01';
  const { rows: [row] } = await db.query('select free_limit, used, extra_balance from ai_quota where owner_id = $1 and month = $2', [owner, month]);
  if (row) return { remaining: Math.max(row.free_limit - row.used, 0) + row.extra_balance, limit: row.free_limit };
  const { rows: [cfg] } = await db.query(`select value from ai_config where key = 'default_free_limit'`);
  const { rows: [ov] } = await db.query('select free_limit_override from ai_teacher_settings where owner_id = $1', [owner]);
  const limit = ov?.free_limit_override ?? Number(jv(cfg?.value) ?? 10);
  return { remaining: limit, limit };
}

// قائمة انتظار بتزامن محدود. الـ payload (الصور) في الذاكرة بس.
export function createQueue({ run, getConcurrency = () => 3, maxWaiting = 20 }) {
  const waiting = [];
  let running = 0;

  function pump() {
    while (running < getConcurrency() && waiting.length) {
      const item = waiting.shift();
      running++;
      Promise.resolve(run(item)).catch(() => {}).finally(() => { running--; pump(); });
    }
  }
  return {
    // false = الطابور ممتلئ
    push(item) {
      if (waiting.length >= maxWaiting) return false;
      waiting.push(item);
      pump();
      return true;
    },
    get size() { return waiting.length + running; },
  };
}

// تنفيذ طلب: extract ← حفظ النتيجة أو الفشل مع رد الحجز.
export async function runJob(db, { extract, providers, cfg, job, payload, log = console }) {
  const id = job.id;
  await db.query(`update ai_jobs set status = 'running', started_at = now(), progress = $2 where id = $1`,
    [id, JSON.stringify({ done: 0, total: payload.images.length || 1 })]);
  // مهلة تتناسب مع عدد الدفعات (3 صور لكل دفعة عند Groq) مع حد أدنى 120ث.
  const timeoutMs = Math.max(120_000, Math.ceil((payload.images.length || 1) / 3) * 90_000);
  let r;
  let timer;
  try {
    r = await Promise.race([
      extract(providers, { primary: cfg.defaultProvider, fallback: cfg.fallbackProvider }, {
        mode: job.mode, images: payload.images, text: payload.text, count: payload.count,
        mcq: payload.mcq, tf: payload.tf,
        difficulty: payload.difficulty, language: payload.language, maxQuestions: cfg.maxQuestions,
      }),
      new Promise((resolve) => { timer = setTimeout(() => resolve({ ok: false, kind: 'temp', reason: 'timeout' }), timeoutMs); }),
    ]);
  } catch (e) {
    log.error('[ai] extract', e.message);
    r = { ok: false, kind: 'temp', reason: 'provider_error' };
  } finally {
    clearTimeout(timer);
  }

  if (r.ok) {
    const result = { questions: r.questions, skipped: r.skipped ?? 0, notes: r.notes ?? [] };
    await db.query(
      `update ai_jobs set status = 'done', result = $2, provider = $3, progress = null, finished_at = now() where id = $1`,
      [id, JSON.stringify(result), r.provider ?? null]);
    return;
  }
  // فشل/رفض: رد الحجز بدون خصم صافي (التفاصيل في اللوج للتشخيص — بدون محتوى ولا مفاتيح)
  log.error('[ai] فشل طلب', id, r.provider ?? '-', r.reason ?? '-', r.detail ?? '');
  await db.query('select ai_release($1, $2)', [job.owner_id, job.charged]);
  const status = r.reason === 'not_educational' ? 'rejected' : 'failed';
  await db.query(
    `update ai_jobs set status = $2, fail_reason = $3, provider = $4, charged = null, progress = null, finished_at = now() where id = $1`,
    [id, status, r.reason ?? 'provider_error', r.provider ?? null]);
}

// عند إعادة التشغيل: أي طلب كان شغال فقدنا صوره → فشل + رد الحجز.
export async function failOrphans(db) {
  const { rows } = await db.query(
    `update ai_jobs set status = 'failed', fail_reason = 'timeout', finished_at = now(), progress = null
      where status in ('queued', 'running') returning owner_id, charged`);
  for (const r of rows) if (r.charged) await db.query('select ai_release($1, $2)', [r.owner_id, r.charged]);
  return rows.length;
}

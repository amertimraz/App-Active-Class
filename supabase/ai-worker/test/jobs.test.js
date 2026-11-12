import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';

import { verifyJwt } from '../src/auth.js';
import { createQueue, runJob, createJob, createConfigLoader, failOrphans } from '../src/jobs.js';

// ───────── auth ─────────
const b64u = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
const jwt = (payload, secret = 's3', header = { alg: 'HS256', typ: 'JWT' }) => {
  const h = b64u(header);
  const p = b64u(payload);
  return `${h}.${p}.${createHmac('sha256', secret).update(`${h}.${p}`).digest('base64url')}`;
};
const SUB = '123e4567-e89b-12d3-a456-426614174000';

test('verifyJwt: صالح، منتهي، توقيع غلط، alg none، role غلط', () => {
  const now = 1_700_000_000;
  assert.deepEqual(verifyJwt(jwt({ sub: SUB, role: 'authenticated', exp: now + 60 }), 's3', now), { ok: true, sub: SUB });
  assert.equal(verifyJwt(jwt({ sub: SUB, role: 'authenticated', exp: now - 1 }), 's3', now).ok, false);
  assert.equal(verifyJwt(jwt({ sub: SUB, role: 'authenticated', exp: now + 60 }, 'other'), 's3', now).ok, false);
  assert.equal(verifyJwt(jwt({ sub: SUB, role: 'authenticated' }, 's3', { alg: 'none' }), 's3', now).ok, false);
  assert.equal(verifyJwt(jwt({ sub: SUB, role: 'anon', exp: now + 60 }), 's3', now).ok, false);
  assert.equal(verifyJwt(jwt({ sub: 'x', role: 'authenticated', exp: now + 60 }), 's3', now).ok, false);
  assert.equal(verifyJwt('garbage', 's3', now).ok, false);
  assert.equal(verifyJwt(null, 's3', now).ok, false);
});

// ───────── queue ─────────
test('queue: تزامن محدود وبيرفض لما يمتلئ', async () => {
  let running = 0;
  let peak = 0;
  const q = createQueue({
    getConcurrency: () => 2,
    maxWaiting: 3,
    run: async () => {
      running++;
      peak = Math.max(peak, running);
      await new Promise((r) => setTimeout(r, 20));
      running--;
    },
  });
  for (let i = 0; i < 5; i++) q.push({ i });
  assert.equal(q.push({ i: 99 }), false);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(peak, 2);
  assert.equal(q.size, 0);
});

// ───────── runJob ─────────
const fakeDb = () => {
  const log = [];
  return { log, query: async (sql, params) => { log.push({ sql, params }); return { rows: [] }; } };
};
const job = { id: SUB, owner_id: 'o1', mode: 'convert', charged: 'free' };
const cfg = { defaultProvider: 'groq', fallbackProvider: 'claude', maxQuestions: 30 };
const failedRow = (log) => log.find((l) => l.sql.includes('fail_reason'));

test('runJob: نجاح يحفظ النتيجة ومفيش رد حجز', async () => {
  const db = fakeDb();
  const extractOk = async () => ({ ok: true, provider: 'groq', questions: [{ text: 'س' }], skipped: 1, notes: [] });
  await runJob(db, { extract: extractOk, providers: {}, cfg, job, payload: { images: ['a'], count: 5 } });
  assert.ok(db.log.some((l) => l.sql.includes("status = 'done'")));
  assert.ok(!db.log.some((l) => l.sql.includes('ai_release')));
});

test('runJob: فشل يرد الحجز ويسجل السبب، والرفض status=rejected', async () => {
  const db = fakeDb();
  await runJob(db, { extract: async () => ({ ok: false, kind: 'permanent', reason: 'unreadable' }), providers: {}, cfg, job, payload: { images: ['a'] } });
  assert.ok(db.log.some((l) => l.sql.includes('ai_release') && l.params[1] === 'free'));
  assert.equal(failedRow(db.log).params[1], 'failed');
  assert.equal(failedRow(db.log).params[2], 'unreadable');

  const db2 = fakeDb();
  await runJob(db2, { extract: async () => ({ ok: false, kind: 'permanent', reason: 'not_educational' }), providers: {}, cfg, job, payload: { images: ['a'] } });
  assert.equal(failedRow(db2.log).params[1], 'rejected');
});

test('runJob: استثناء من extract = فشل مؤقت مع رد الحجز', async () => {
  const db = fakeDb();
  await runJob(db, { extract: async () => { throw new Error('boom'); }, providers: {}, cfg, job, payload: { images: [] }, log: { error() {} } });
  assert.ok(db.log.some((l) => l.sql.includes('ai_release')));
  assert.equal(failedRow(db.log).params[2], 'provider_error');
});

// ───────── createJob (transaction) ─────────
const fakePool = (script) => {
  const calls = [];
  const client = {
    query: async (sql, params) => { calls.push(sql.trim().slice(0, 40)); return script(sql, params); },
    release() {},
  };
  return { calls, connect: async () => client };
};

test('createJob: جديد ← حجز ← commit', async () => {
  const pool = fakePool((sql) => {
    if (sql.includes('paused_by_admin')) return { rows: [] };
    if (sql.includes('insert into ai_jobs')) return { rows: [{ id: SUB }] };
    if (sql.includes('ai_reserve')) return { rows: [{ q: 'free' }] };
    if (sql.includes('set charged')) return { rows: [{ id: SUB, charged: 'free' }] };
    return { rows: [] };
  });
  const r = await createJob(pool, { id: SUB, owner: 'o1', mode: 'convert', params: {} });
  assert.equal(r.kind, 'created');
  assert.equal(r.job.charged, 'free');
  assert.ok(pool.calls.includes('commit'));
});

test('createJob: الحصة خلصت ← rollback', async () => {
  const pool = fakePool((sql) => {
    if (sql.includes('insert into ai_jobs')) return { rows: [{ id: SUB }] };
    if (sql.includes('ai_reserve')) return { rows: [{ q: null }] };
    return { rows: [] };
  });
  const r = await createJob(pool, { id: SUB, owner: 'o1', mode: 'convert', params: {} });
  assert.equal(r.kind, 'quota');
  assert.ok(pool.calls.includes('rollback'));
});

test('createJob: نفس job_id ← existing بدون حجز جديد، والموقوف مرفوض', async () => {
  let reserved = false;
  const pool = fakePool((sql) => {
    if (sql.includes('paused_by_admin')) return { rows: [] };
    if (sql.includes('insert into ai_jobs')) return { rows: [] };
    if (sql.includes('ai_reserve')) { reserved = true; return { rows: [{ q: 'free' }] }; }
    if (sql.includes('select * from ai_jobs')) return { rows: [{ id: SUB, status: 'done' }] };
    return { rows: [] };
  });
  const r = await createJob(pool, { id: SUB, owner: 'o1', mode: 'convert', params: {} });
  assert.equal(r.kind, 'existing');
  assert.equal(reserved, false);
  const paused = fakePool((sql) => (sql.includes('paused_by_admin') ? { rows: [{ paused_by_admin: true }] } : { rows: [] }));
  assert.equal((await createJob(paused, { id: SUB, owner: 'o1', mode: 'convert', params: {} })).kind, 'paused');
});

test('config: افتراضي عند غياب الجدول، وقراءة القيم', async () => {
  const none = createConfigLoader({ query: async () => { throw new Error('no table'); } });
  assert.equal((await none()).defaultProvider, 'groq');
  const some = createConfigLoader({
    query: async () => ({ rows: [{ key: 'default_provider', value: 'claude' }, { key: 'kill_switch', value: true }, { key: 'max_images', value: 4 }] }),
  });
  const c = await some();
  assert.equal(c.defaultProvider, 'claude');
  assert.equal(c.killSwitch, true);
  assert.equal(c.maxImages, 4);
});

test('failOrphans: يقفل المعلّق ويرد حجزه', async () => {
  const calls = [];
  const db = {
    query: async (sql, params) => {
      calls.push({ sql, params });
      return sql.includes('update ai_jobs') ? { rows: [{ owner_id: 'o1', charged: 'extra' }, { owner_id: 'o2', charged: null }] } : { rows: [] };
    },
  };
  assert.equal(await failOrphans(db), 2);
  assert.equal(calls.filter((c) => c.sql.includes('ai_release')).length, 1);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';

import { buildTemplatePayload } from '../src/templates.js';
import { classifyError, verifySignature, parseWebhook, isStopWord, createMeta } from '../src/meta.js';
import { inSendWindow, nextWindowStart, retryDelayMs, createBucket } from '../src/rules.js';
import { decide, afterFailure } from '../src/sender.js';
import { createWebhookHandler } from '../src/webhook.js';
import { createSecrets } from '../src/secrets.js';

const cfg = { killSwitch: false, fromHour: 8, toHour: 22 };
// 12:00 ظهرًا بتوقيت القاهرة (UTC+2 شتاءً أو +3 صيفًا): نستخدم 10:00 UTC = 12/13 قاهرة
const noon = new Date('2026-11-09T10:00:00Z');
const night = new Date('2026-11-09T21:30:00Z'); // 23:30 قاهرة
const row = (o = {}) => ({ kind: 'absence', attempts: 0, ...o });
const base = { cfg, settings: { enabled: true, kinds: {}, pausedByAdmin: false, adminActivated: true }, consent: 'granted', globalStopped: false, now: noon };

test('قالب الغياب: متغيرات بالترتيب وتنضيف السطور', () => {
  const p = buildTemplatePayload('absence', '2010', { student: 'أحمد\nعلي', group: 'ج1', date: '2026-11-09', teacher: 'أ/ سعد', teacher_phone: '+201012345678' });
  assert.equal(p.template.name, 'ac_absence_ar');
  assert.deepEqual(p.template.components[0].parameters.map((x) => x.text), ['أحمد علي', 'ج1', '2026-11-09', 'أ/ سعد', '+201012345678']);
});

test('متغير ناقص يرمي خطأ', () => {
  assert.throws(() => buildTemplatePayload('receipt', '2010', { student: 'a' }), /متغير ناقص/);
});

test('تصنيف أخطاء Meta', () => {
  assert.equal(classifyError(400, { code: 131026 }).reason, 'not_on_whatsapp');
  assert.equal(classifyError(400, { code: 130429 }).kind, 'temp');
  assert.equal(classifyError(500, {}).kind, 'temp');
  assert.equal(classifyError(400, { code: 190 }).kind, 'auth');
  assert.equal(classifyError(400, { code: 133010 }).kind, 'auth');
  assert.equal(classifyError(400, { code: 132001 }).reason, 'template_error');
});

test('توقيع الـ webhook', () => {
  const body = Buffer.from('{"a":1}');
  const sig = 'sha256=' + createHmac('sha256', 'sec').update(body).digest('hex');
  assert.equal(verifySignature(body, sig, 'sec'), true);
  assert.equal(verifySignature(body, sig, 'other'), false);
  assert.equal(verifySignature(body, undefined, 'sec'), false);
});

test('كلمات الإيقاف عربي وإنجليزي', () => {
  for (const w of ['إيقاف', 'ايقاف', 'STOP', ' stop ', 'إيقاف.', 'إلغاء']) assert.equal(isStopWord(w), true, w);
  assert.equal(isStopWord('شكرا'), false);
});

test('parseWebhook يطلّع الحالات والإيقاف', () => {
  const r = parseWebhook({ entry: [{ changes: [{ value: {
    statuses: [{ id: 'w1', status: 'delivered', timestamp: '1700000000' }],
    messages: [{ from: '201000', type: 'text', text: { body: 'ايقاف' } }, { from: '2', type: 'text', text: { body: 'شكرا' } }],
  } }] }] });
  assert.equal(r.statuses[0].status, 'delivered');
  assert.deepEqual(r.stops, [{ from: '201000' }]);
});

test('نافذة الإرسال والتأجيل للصباح', () => {
  assert.equal(inSendWindow(noon, 8, 22), true);
  assert.equal(inSendWindow(night, 8, 22), false);
  const next = nextWindowStart(night, 8, 22);
  assert.equal(inSendWindow(next, 8, 22), true);
  assert.ok(next > night);
});

test('فواصل إعادة المحاولة', () => {
  assert.equal(retryDelayMs(1), 30_000);
  assert.equal(retryDelayMs(2), 120_000);
  assert.equal(retryDelayMs(3), 600_000);
});

test('token bucket يحدّ المعدل ويتجدد', () => {
  let t = 0;
  const b = createBucket(2, () => t);
  assert.equal(b.take(), true);
  assert.equal(b.take(), true);
  assert.equal(b.take(), false);
  t += 30_000; // نص دقيقة = توكن واحد
  assert.equal(b.take(), true);
});

test('decide: الأساسي يُرسل', () => assert.equal(decide(row(), base).action, 'send'));

test('decide: بلا موافقة / موقوف / ميزة مقفولة', () => {
  assert.deepEqual(decide(row(), { ...base, consent: null }), { action: 'block', reason: 'no_consent' });
  assert.deepEqual(decide(row(), { ...base, consent: 'stopped' }), { action: 'block', reason: 'stopped' });
  assert.deepEqual(decide(row(), { ...base, globalStopped: true }), { action: 'block', reason: 'stopped' });
  assert.equal(decide(row(), { ...base, settings: { ...base.settings, enabled: false } }).reason, 'disabled');
  assert.equal(decide(row(), { ...base, settings: { ...base.settings, kinds: { absence: false } } }).reason, 'disabled');
  assert.equal(decide(row(), { ...base, settings: { ...base.settings, pausedByAdmin: true } }).reason, 'disabled');
});

test('decide: خارج الساعات يتأجل، والاختبار لا', () => {
  const d = decide(row(), { ...base, now: night });
  assert.equal(d.action, 'defer');
  assert.ok(d.until > night);
  assert.equal(decide(row({ kind: 'test' }), { ...base, now: night, consent: null }).action, 'send');
});

test('decide: kill switch يؤجل بصمت', () => {
  const d = decide(row(), { ...base, cfg: { ...cfg, killSwitch: true } });
  assert.equal(d.action, 'defer');
  assert.equal(d.quiet, true);
});

test('afterFailure: مؤقت يعيد حتى 3 ثم يفشل، الدائم يفشل فورًا', () => {
  const t = { kind: 'temp', reason: 'provider_error' };
  assert.equal(afterFailure(row({ attempts: 0 }), t).status, 'pending');
  assert.equal(afterFailure(row({ attempts: 1 }), t).status, 'pending');
  assert.equal(afterFailure(row({ attempts: 2 }), t).status, 'failed');
  assert.equal(afterFailure(row(), { kind: 'permanent', reason: 'not_on_whatsapp' }).status, 'failed');
});

test('meta.send: نجاح وفشل بدون شبكة حقيقية', async () => {
  const ok = createMeta({ token: 't', phoneNumberId: '1', fetchFn: async () => ({ ok: true, status: 200, json: async () => ({ messages: [{ id: 'wamid.X' }] }) }) });
  assert.deepEqual(await ok.send('absence', '2010', { student: 'a', group: 'b', date: 'c', teacher: 'd', teacher_phone: '+20' }), { ok: true, id: 'wamid.X' });
  const bad = createMeta({ token: 't', phoneNumberId: '1', fetchFn: async () => ({ ok: false, status: 400, json: async () => ({ error: { code: 131026, message: 'x' } }) }) });
  const r = await bad.send('absence', '2010', { student: 'a', group: 'b', date: 'c', teacher: 'd', teacher_phone: '+20' });
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'not_on_whatsapp');
  const net = createMeta({ token: 't', phoneNumberId: '1', fetchFn: async () => { throw new Error('down'); } });
  assert.equal((await net.send('absence', '2010', { student: 'a', group: 'b', date: 'c', teacher: 'd', teacher_phone: '+20' })).kind, 'temp');
  const noVars = createMeta({ token: 't', phoneNumberId: '1', fetchFn: async () => { throw new Error('should not call'); } });
  assert.equal((await noVars.send('absence', '2010', {})).reason, 'template_vars');
});

test('webhook handler: GET تحقق، POST توقيع غلط = 401', async () => {
  const h = createWebhookHandler({ db: { query: async () => ({ rows: [] }) }, appSecret: 'sec', verifyToken: 'vt', log: { error() {}, info() {} } });
  const res = () => { const r = { code: 0, body: '', writeHead(c) { r.code = c; }, end(b = '') { r.body = b; } }; return r; };

  let r = res();
  await h({ method: 'GET', url: '/wa/webhook?hub.mode=subscribe&hub.verify_token=vt&hub.challenge=42', headers: {} }, r, Buffer.alloc(0));
  assert.equal(r.code, 200); assert.equal(r.body, '42');

  r = res();
  await h({ method: 'GET', url: '/wa/webhook?hub.mode=subscribe&hub.verify_token=bad&hub.challenge=42', headers: {} }, r, Buffer.alloc(0));
  assert.equal(r.code, 403);

  r = res();
  await h({ method: 'POST', url: '/wa/webhook', headers: { 'x-hub-signature-256': 'sha256=00' } }, r, Buffer.from('{}'));
  assert.equal(r.code, 401);

  const body = Buffer.from('{}');
  const sig = 'sha256=' + createHmac('sha256', 'sec').update(body).digest('hex');
  r = res();
  await h({ method: 'POST', url: '/wa/webhook', headers: { 'x-hub-signature-256': sig } }, r, body);
  assert.equal(r.code, 200);
});

test('secrets: الجدول يغلب البيئة، PENDING يتجاهل، والكاش يتجدد', async () => {
  let rows = [{ key: 'WA_TOKEN', value: 'db-token' }, { key: 'WA_APP_SECRET', value: 'PENDING_SET_ME' }];
  let t = 0;
  const db = { query: async () => ({ rows }) };
  const s = createSecrets({ db, env: { WA_TOKEN: 'env-token', WA_APP_SECRET: 'env-secret', WA_VERIFY_TOKEN: 'v' }, ttlMs: 1000, now: () => t });
  assert.equal(await s.get('WA_TOKEN'), 'db-token');
  assert.equal(await s.get('WA_APP_SECRET'), 'env-secret');
  assert.equal(await s.get('WA_VERIFY_TOKEN'), 'v');
  assert.equal(await s.get('GROQ_API_KEY'), null);
  rows = [{ key: 'WA_TOKEN', value: 'new' }];
  assert.equal(await s.get('WA_TOKEN'), 'db-token'); // لسه في الكاش
  t += 1500;
  assert.equal(await s.get('WA_TOKEN'), 'new');
});

test('secrets: الجدول غير موجود → البيئة فقط', async () => {
  const s = createSecrets({ db: { query: async () => { throw new Error('no table'); } }, env: { WA_TOKEN: 'e' } });
  assert.equal(await s.get('WA_TOKEN'), 'e');
});

test('meta.send: المفتاح من getter، وناقص = temp بدون استدعاء شبكة', async () => {
  let calls = 0;
  const f = async () => { calls++; return { ok: true, status: 200, json: async () => ({ messages: [{ id: 'x' }] }) }; };
  const none = createMeta({ token: async () => null, phoneNumberId: async () => '1', fetchFn: f });
  const r1 = await none.send('absence', '2010', { student: 'a', group: 'b', date: 'c', teacher: 'd', teacher_phone: '+20' });
  assert.equal(r1.kind, 'temp');
  assert.equal(calls, 0);
  const ok = createMeta({ token: async () => 't', phoneNumberId: async () => '1', fetchFn: f });
  assert.equal((await ok.send('absence', '2010', { student: 'a', group: 'b', date: 'c', teacher: 'd', teacher_phone: '+20' })).ok, true);
});

test('قفل افتراضي: من غير تفعيل الأدمن بيتحجب حتى الاختبار', () => {
  const notOn = { ...base, settings: { ...base.settings, adminActivated: false } };
  assert.deepEqual(decide(row(), notOn), { action: 'block', reason: 'not_activated' });
  assert.deepEqual(decide(row({ kind: 'test' }), notOn), { action: 'block', reason: 'not_activated' });
  assert.deepEqual(decide(row(), { ...notOn, settings: { ...notOn.settings, adminActivated: undefined } }), { action: 'block', reason: 'not_activated' });
});

test('مفتوح من الأدمن + مفعّل من المدرس → بيتبعت، والإيقاف من الأدمن يغلب', () => {
  assert.deepEqual(decide(row(), base), { action: 'send' });
  const paused = { ...base, settings: { ...base.settings, pausedByAdmin: true } };
  assert.deepEqual(decide(row(), paused), { action: 'block', reason: 'disabled' });
});

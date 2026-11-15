import test from 'node:test';
import assert from 'node:assert/strict';

import { validate, extractJson, normalizeAr, similarity } from '../src/validate.js';
import { systemPrompt } from '../src/prompts.js';
import { extract } from '../src/providers/index.js';
import { createGroq, classify as classifyGroq } from '../src/providers/groq.js';
import { createClaude } from '../src/providers/claude.js';

const q = (o = {}) => ({
  text: 'ما عاصمة مصر؟',
  options: ['القاهرة', 'الإسكندرية', 'أسوان', 'الأقصر'],
  correct_index: 0,
  answer_marked: true,
  explanation: 'القاهرة هي العاصمة.',
  ...o,
});

test('extractJson يتحمّل markdown ونص حواليه', () => {
  assert.deepEqual(extractJson('```json\n{"a":1}\n```'), { a: 1 });
  assert.deepEqual(extractJson('تفضل: {"a":2} شكرا'), { a: 2 });
  assert.equal(extractJson('مفيش'), null);
});

test('تطبيع عربي وتشابه', () => {
  assert.equal(normalizeAr('أَحْمَد'), normalizeAr('احمد'));
  assert.ok(similarity('ما عاصمة مصر؟', 'ما هي عاصمه مصر') > 0.5);
  assert.equal(similarity('', 'x'), 0);
});

test('validate: سؤال سليم، وشرح يتشال في التحويل', () => {
  const r = validate({ status: 'ok', questions: [q()] }, { mode: 'generate' });
  assert.equal(r.ok, true);
  assert.equal(r.questions[0].needs_review, false);
  assert.equal(r.questions[0].explanation, 'القاهرة هي العاصمة.');
  const c = validate({ status: 'ok', questions: [q()] }, { mode: 'convert' });
  assert.equal(c.questions[0].explanation, '');
});

test('validate convert: الإجابة تتمسح لو مش معلّمة في الورقة', () => {
  const r = validate({ questions: [q({ answer_marked: false })] }, { mode: 'convert' });
  assert.equal(r.questions[0].correct_index, null);
  assert.equal(r.questions[0].needs_review, true);
  const ok = validate({ questions: [q({ answer_marked: true })] }, { mode: 'convert' });
  assert.equal(ok.questions[0].correct_index, 0);
});

test('validate: اختيارات قليلة/كتير، فهرس خارج المدى، تكرار', () => {
  const r = validate({
    questions: [
      q({ options: ['واحد'] }),
      q({ options: ['1', '2', '3', '4', '5', '6', '7', '8'], text: 'سؤال مختلف تماما هنا' }),
      q({ correct_index: 9, text: 'سؤال تاني مختلف عن الباقي' }),
      q({ text: 'ما عاصمة مصر؟' }),
    ],
  }, { mode: 'generate' });
  assert.equal(r.skipped, 1);
  assert.equal(r.questions[0].options.length, 6);
  assert.equal(r.questions[1].correct_index, null);
  assert.equal(r.questions[1].needs_review, true);
  assert.equal(r.questions[2].duplicate, false);
});

test('validate: تكرار فعلي بين سؤالين متشابهين', () => {
  const r = validate({ questions: [q(), q({ text: 'ما هي عاصمة مصر؟' })] }, { mode: 'generate' });
  assert.equal(r.questions[1].duplicate, true);
});

test('validate: اختيارات مكررة تعلّم محتاج مراجعة، وHTML يتنضّف', () => {
  const r = validate({ questions: [q({ options: ['أ', 'أ', 'ب'], text: '<b>سؤال</b> **غامق** هنا' })] }, { mode: 'generate' });
  assert.equal(r.questions[0].needs_review, true);
  assert.equal(r.questions[0].text, 'سؤال غامق هنا');
});

test('validate: unreadable / rejected / بلا أسئلة', () => {
  assert.equal(validate({ status: 'unreadable' }, { mode: 'convert' }).status, 'unreadable');
  assert.equal(validate({ status: 'rejected' }, { mode: 'generate' }).status, 'rejected');
  assert.equal(validate({ questions: [] }, { mode: 'convert' }).ok, false);
  assert.equal(validate(null, { mode: 'convert' }).status, 'bad_output');
});

test('prompts: الوضعين مختلفين ويذكروا العدد', () => {
  assert.match(systemPrompt('convert'), /لا تخمّن/);
  assert.match(systemPrompt('generate', { count: 7, difficulty: 'hard' }), /7 سؤال/);
});

test('تصنيف أخطاء Groq', () => {
  assert.equal(classifyGroq(401).kind, 'auth');
  assert.equal(classifyGroq(429).kind, 'temp');
  assert.equal(classifyGroq(503).kind, 'temp');
  assert.equal(classifyGroq(400).kind, 'permanent');
});

const okJson = (questions) => JSON.stringify({ status: 'ok', questions });
const fake = (name, replies, maxImages = 5) => {
  let i = 0;
  const calls = [];
  return {
    name, maxImages, calls,
    complete: async (a) => { calls.push(a); return replies[Math.min(i++, replies.length - 1)]; },
  };
};

test('extract: دفعات الصور تتجمّع بالترتيب مع offset للصفحات', async () => {
  const p = fake('groq', [
    { ok: true, text: okJson([q({ source_page: 1, text: 'سؤال الدفعة الأولى هنا' })]) },
    { ok: true, text: okJson([q({ source_page: 1, text: 'سؤال الدفعة التانية هنا مختلف' })]) },
  ], 2);
  const r = await extract({ groq: p }, { primary: 'groq' }, { mode: 'convert', images: ['a', 'b', 'c'], count: 10 });
  assert.equal(r.ok, true);
  assert.equal(p.calls.length, 2);
  assert.deepEqual(r.questions.map((x) => x.source_page), [1, 3]);
});

test('extract: JSON غلط ← إعادة محاولة واحدة', async () => {
  const p = fake('groq', [{ ok: true, text: 'مش json' }, { ok: true, text: okJson([q()]) }]);
  const r = await extract({ groq: p }, { primary: 'groq' }, { mode: 'generate', images: ['a'], count: 3 });
  assert.equal(r.ok, true);
  assert.equal(p.calls.length, 2);
  assert.ok(p.calls[1].extraUser);
});

test('extract: فشل مؤقت في الأساسي ← الاحتياطي ينجح', async () => {
  const a = fake('groq', [{ ok: false, kind: 'temp', reason: 'provider_error' }]);
  const b = fake('claude', [{ ok: true, text: okJson([q()]) }]);
  const r = await extract({ groq: a, claude: b }, { primary: 'groq', fallback: 'claude' }, { mode: 'generate', images: ['a'], count: 1 });
  assert.equal(r.ok, true);
  assert.equal(r.provider, 'claude');
});

test('extract: فشل دائم لا يجرّب الاحتياطي، والمرفوض نهائي', async () => {
  const a = fake('groq', [{ ok: false, kind: 'permanent', reason: 'provider_error' }]);
  const b = fake('claude', [{ ok: true, text: okJson([q()]) }]);
  const r = await extract({ groq: a, claude: b }, { primary: 'groq', fallback: 'claude' }, { mode: 'generate', images: ['a'], count: 1 });
  assert.equal(r.ok, false);
  assert.equal(b.calls.length, 0);
  const rej = fake('groq', [{ ok: true, text: JSON.stringify({ status: 'rejected' }) }]);
  const r2 = await extract({ groq: rej, claude: b }, { primary: 'groq', fallback: 'claude' }, { mode: 'generate', images: ['a'], count: 1 });
  assert.equal(r2.reason, 'not_educational');
  assert.equal(b.calls.length, 0);
});

test('extract: غير مقروء في الأساسي ← الاحتياطي يقرا', async () => {
  const a = fake('groq', [{ ok: true, text: JSON.stringify({ status: 'unreadable' }) }]);
  const b = fake('claude', [{ ok: true, text: okJson([q()]) }]);
  const r = await extract({ groq: a, claude: b }, { primary: 'groq', fallback: 'claude' }, { mode: 'convert', images: ['a'], count: 1 });
  assert.equal(r.ok, true);
  assert.equal(r.provider, 'claude');
});

test('groq/claude: شكل الطلب والمفتاح الناقص', async () => {
  let sent;
  const g = createGroq({
    apiKey: 'k', model: 'm',
    fetchFn: async (u, o) => { sent = { u, o }; return { ok: true, status: 200, json: async () => ({ choices: [{ message: { content: '{}' } }] }) }; },
  });
  await g.complete({ system: 's', user: 'u', images: ['AAA'] });
  assert.match(sent.u, /groq/);
  assert.equal(JSON.parse(sent.o.body).messages[1].content[1].image_url.url, 'data:image/jpeg;base64,AAA');
  const c = createClaude({
    apiKey: 'k', model: 'm',
    fetchFn: async (u, o) => { sent = { u, o }; return { ok: true, status: 200, json: async () => ({ content: [{ type: 'text', text: '{}' }] }) }; },
  });
  await c.complete({ system: 's', user: 'u', images: ['BBB'] });
  assert.equal(JSON.parse(sent.o.body).messages[0].content[0].source.data, 'BBB');
  const none = createGroq({ apiKey: async () => null, model: 'm', fetchFn: async () => { throw new Error('no'); } });
  assert.equal((await none.complete({ system: 's', user: 'u' })).kind, 'auth');
});

test('groq: الحد 3 صور في الطلب (الحد الحقيقي للنموذج)', () => {
  const g = createGroq({ apiKey: async () => 'k', model: 'm' });
  assert.equal(g.maxImages, 3);
});

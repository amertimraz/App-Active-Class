import test from 'node:test';
import assert from 'node:assert/strict';

import { systemPrompt } from '../src/prompts.js';
import { validate } from '../src/validate.js';
import { extract } from '../src/providers/index.js';

test('prompt التوليد: عدد كل نوع بيظهر بالظبط', () => {
  const p = systemPrompt('generate', { mcq: 6, tf: 4 });
  assert.match(p, /6 سؤال اختيار من متعدد/);
  assert.match(p, /4 سؤال صح\/خطأ/);
  assert.match(p, /"true_false"/);
});

test('prompt التوليد: صح/خطأ بس أو اختيار بس', () => {
  const tfOnly = systemPrompt('generate', { mcq: 0, tf: 5 });
  assert.match(tfOnly, /5 سؤال صح\/خطأ/);
  assert.doesNotMatch(tfOnly, /سؤال اختيار من متعدد\n/);
  const old = systemPrompt('generate', { count: 7 }); // بدون mcq/tf = كله اختيار
  assert.match(old, /7 سؤال اختيار من متعدد/);
});

test('validate: صح/خطأ بيتثبّت على [صح, خطأ] حتى لو النموذج كتب غيرهم', () => {
  const r = validate({
    questions: [
      { text: 'الشمس تشرق من الشرق.', options: ['True', 'False'], correct_index: 0, type: 'true_false', explanation: 'صحيح.' },
      { text: 'ما عاصمة مصر؟', options: ['القاهرة', 'أسوان', 'الأقصر', 'طنطا'], correct_index: 0, type: 'mcq' },
    ],
  }, { mode: 'generate' });
  assert.deepEqual(r.questions[0].options, ['صح', 'خطأ']);
  assert.equal(r.questions[0].type, 'true_false');
  assert.equal(r.questions[0].correct_index, 0);
  assert.equal(r.questions[1].type, 'mcq');
});

test('extract: الأعداد بتتقسم على الدفعات وبتوصل للـ prompt', async () => {
  const seen = [];
  const p = {
    name: 'groq', maxImages: 2,
    complete: async (a) => { seen.push(a.system); return { ok: true, text: JSON.stringify({ status: 'ok', questions: [{ text: 'سؤال كامل هنا', options: ['أ', 'ب'], correct_index: 0, type: 'mcq' }] }) }; },
  };
  await extract({ groq: p }, { primary: 'groq' }, { mode: 'generate', images: ['a', 'b', 'c', 'd'], count: 10, mcq: 8, tf: 2 });
  assert.equal(seen.length, 2); // دفعتين
  assert.match(seen[0], /4 سؤال اختيار من متعدد/); // 8 / 2
  assert.match(seen[0], /1 سؤال صح\/خطأ/); // 2 / 2
});

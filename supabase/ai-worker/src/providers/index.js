// تنسيق المزوّدين (spec 057): دفعات الصور، إعادة محاولة JSON، fallback، وتحقق.
import { systemPrompt, userPrompt, RETRY_JSON_PROMPT } from '../prompts.js';
import { extractJson, validate } from '../validate.js';

function chunk(arr, n) {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out.length ? out : [[]];
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// طلب واحد للمزوّد مع إعادة محاولة بتأخير متزايد للأخطاء المؤقتة (زحمة 429/5xx، شبكة)
// بدل ما دفعة واحدة تفشّل الطلب كله. delays قابلة للحقن عشان الاختبارات.
export async function completeWithRetry(provider, args, { delays = [2000, 5000] } = {}) {
  let r = await provider.complete(args);
  for (const d of delays) {
    if (r.ok || r.kind !== 'temp' || r.reason === 'bad_output') return r;
    await sleep(d);
    r = await provider.complete(args);
  }
  return r;
}

// بيشغّل مزوّد واحد على كل الدفعات. بيرجّع { ok, parsed } أو { ok:false, kind, reason }
async function runProvider(provider, { mode, images, text, count, mcq, tf, difficulty, language }) {
  const batches = chunk(images, provider.maxImages);
  // عدد كل نوع بيتقسم على الدفعات (لو الصور أكتر من حد المزوّد)
  const nMcq = mcq ?? Math.max((count ?? 10) - (tf ?? 0), 0);
  const nTf = tf ?? 0;
  const per = (n) => (n > 0 ? Math.max(1, Math.ceil(n / batches.length)) : 0);
  const system = systemPrompt(mode, { count: per(nMcq) + per(nTf), mcq: per(nMcq), tf: per(nTf), difficulty, language });
  const merged = { status: 'ok', questions: [], skipped: 0, notes: [] };
  let usage = null;

  for (let b = 0; b < batches.length; b++) {
    const user = userPrompt(mode, { text, pages: batches[b].length });
    let r = await completeWithRetry(provider, { system, user, images: batches[b] });
    if (!r.ok) return r;
    let parsed = extractJson(r.text);
    if (!parsed) { // محاولة واحدة لإصلاح الشكل
      r = await completeWithRetry(provider, { system, user, images: batches[b], extraUser: RETRY_JSON_PROMPT });
      if (!r.ok) return r;
      parsed = extractJson(r.text);
    }
    if (!parsed) return { ok: false, kind: 'temp', reason: 'bad_output', detail: 'invalid json' };
    usage = r.usage ?? usage;
    if (parsed.status && parsed.status !== 'ok') {
      if (batches.length === 1) return { ok: true, parsed, usage };
      continue; // دفعة مش مقروءة من عدة دفعات: نكمل بالباقي
    }
    const offset = b * provider.maxImages;
    for (const q of parsed.questions ?? []) {
      if (Number.isInteger(q.source_page)) q.source_page += offset;
      merged.questions.push(q);
    }
    merged.skipped += Number.isFinite(parsed.skipped) ? parsed.skipped : 0;
    merged.notes.push(...(Array.isArray(parsed.notes) ? parsed.notes : []));
  }
  if (!merged.questions.length) merged.status = 'unreadable';
  return { ok: true, parsed: merged, usage };
}

// providers: { groq, claude }. cfg: { primary, fallback }. بيرجّع نتيجة نهائية موحّدة.
export async function extract(providers, cfg, req) {
  const order = [cfg.primary, cfg.fallback].filter((n, i, a) => n && providers[n] && a.indexOf(n) === i);
  let last = { ok: false, kind: 'permanent', reason: 'provider_error', detail: 'no provider' };
  for (const name of order) {
    const r = await runProvider(providers[name], req);
    if (r.ok) {
      const v = validate(r.parsed, { mode: req.mode, maxQuestions: req.maxQuestions ?? 30 });
      if (v.ok) return { ok: true, provider: name, usage: r.usage, ...v };
      if (v.status === 'rejected') {
        return { ok: false, kind: 'permanent', reason: 'not_educational', provider: name };
      }
      // غير مقروء أو شكل غلط: نجرّب الاحتياطي (نموذج أقوى ممكن يقرا)
      last = v.status === 'unreadable'
        ? { ok: false, kind: 'permanent', reason: 'unreadable', provider: name }
        : { ok: false, kind: 'temp', reason: 'bad_output', provider: name };
      continue;
    }
    // مزوّد احتياطي مش متضبوط (مفيش مفتاح) ما يغطّيش على سبب فشل الأساسي.
    const notConfigured = r.reason === 'provider_auth' && r.detail === 'not configured';
    console.error('[ai] مزوّد فشل:', name, r.reason, r.detail ?? '');
    if (!(notConfigured && last.provider)) last = { ...r, provider: name };
    if (r.kind === 'permanent') break;
  }
  return last;
}

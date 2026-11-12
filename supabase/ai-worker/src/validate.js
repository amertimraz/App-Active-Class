// تنضيف ردود النموذج (spec 057): JSON صالح، أسئلة سليمة، علامات المراجعة والتكرار.

const TASHKEEL = /[ً-ٰٟـ]/g;

// تطبيع عربي للمقارنة: تشكيل، همزات، ياء/ألف مقصورة، تاء مربوطة، علامات ترقيم
export function normalizeAr(s) {
  return String(s ?? '')
    .normalize('NFKC')
    .replace(TASHKEEL, '')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

function tokens(s) { return new Set(normalizeAr(s).split(' ').filter((w) => w.length > 1)); }

export function similarity(a, b) {
  const A = tokens(a), B = tokens(b);
  if (!A.size || !B.size) return 0;
  let inter = 0;
  for (const t of A) if (B.has(t)) inter++;
  return inter / (A.size + B.size - inter);
}

// يحاول يطلّع JSON من نص النموذج (يتحمّل ``` أو نص قبل/بعد)
export function extractJson(raw) {
  if (raw && typeof raw === 'object') return raw;
  const text = String(raw ?? '').trim();
  if (!text) return null;
  try { return JSON.parse(text); } catch { /* نكمل */ }
  const stripped = text.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  try { return JSON.parse(stripped); } catch { /* نكمل */ }
  const a = text.indexOf('{');
  const b = text.lastIndexOf('}');
  if (a >= 0 && b > a) {
    try { return JSON.parse(text.slice(a, b + 1)); } catch { /* فشل */ }
  }
  return null;
}

const clean = (s, max = 2000) =>
  String(s ?? '').replace(/<[^>]*>/g, ' ').replace(/[*_`#]+/g, '').replace(/\s+/g, ' ').trim().slice(0, max);

export const MAX_OPTIONS = 6;
// تلميح «مكرر؟» بس (مش حذف): 0.7 يلقط صياغتين لنفس السؤال.
const DUP_THRESHOLD = 0.7;

// parsed = JSON النموذج. بيرجّع { ok, status, questions, skipped, notes }
export function validate(parsed, { mode, maxQuestions = 30 } = {}) {
  if (!parsed || typeof parsed !== 'object') return { ok: false, status: 'bad_output' };
  const status = parsed.status ?? 'ok';
  if (status === 'unreadable') return { ok: false, status: 'unreadable' };
  if (status === 'rejected') return { ok: false, status: 'rejected' };

  let skipped = Number.isFinite(parsed.skipped) ? Math.max(0, parsed.skipped | 0) : 0;
  const notes = Array.isArray(parsed.notes) ? parsed.notes.map((n) => clean(n, 300)).filter(Boolean) : [];
  const out = [];

  for (const q of Array.isArray(parsed.questions) ? parsed.questions : []) {
    const text = clean(q?.text, 1500);
    let options = (Array.isArray(q?.options) ? q.options : []).map((o) => clean(o, 500)).filter(Boolean);
    const isTf = q?.type === 'true_false';
    if (isTf) options = ['صح', 'خطأ']; // صح/خطأ: اختيارين ثابتين بالترتيب ده
    if (!text || options.length < 2) { skipped++; continue; }
    if (options.length > MAX_OPTIONS) options = options.slice(0, MAX_OPTIONS);

    let correct = Number.isInteger(q.correct_index) ? q.correct_index : null;
    if (correct !== null && (correct < 0 || correct >= options.length)) correct = null;
    // في التحويل: ممنوع نصدّق إجابة النموذج لو ما كانتش معلّمة في الورقة
    if (mode === 'convert' && q.answer_marked !== true) correct = null;

    const normOpts = options.map(normalizeAr);
    const dupOptions = new Set(normOpts).size !== normOpts.length;

    out.push({
      text,
      options,
      correct_index: correct,
      explanation: mode === 'convert' ? '' : clean(q.explanation, 300),
      type: isTf ? 'true_false' : 'mcq',
      has_figure: q.has_figure === true,
      uncertain: q.uncertain === true,
      source_page: Number.isInteger(q.source_page) ? q.source_page : null,
      _dupOptions: dupOptions,
    });
    if (out.length >= maxQuestions) break;
  }

  // علامات المراجعة والتكرار
  const questions = out.map((q, i) => {
    const duplicate = out.some((o, j) => j < i && similarity(o.text, q.text) >= DUP_THRESHOLD);
    const needs_review = q.uncertain || q.correct_index === null || q._dupOptions || q.text.length < 4;
    const { uncertain, _dupOptions, ...rest } = q; // eslint-disable-line no-unused-vars
    return { ...rest, needs_review, duplicate };
  });

  if (!questions.length) return { ok: false, status: 'unreadable' };
  return { ok: true, status: 'ok', questions, skipped, notes };
}

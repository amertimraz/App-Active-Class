// تعليمات الذكاء الاصطناعي (spec 057). المخرج لازم يطابق المخطط في
// specs/057-exam-from-file/contracts/provider-and-prompts.md.

export const SCHEMA_HINT = `أرجع JSON فقط (بدون أي نص خارجه ولا markdown) بالشكل:
{
  "status": "ok" | "unreadable" | "rejected",
  "questions": [{
    "text": "نص السؤال",
    "options": ["اختيار 1", "اختيار 2", "..."],
    "correct_index": 0,
    "answer_marked": false,
    "explanation": "شرح قصير",
    "type": "mcq" | "true_false",
    "has_figure": false,
    "uncertain": false,
    "source_page": 1
  }],
  "skipped": 0,
  "notes": ["ملاحظة"]
}
"correct_index" رقم يبدأ من 0 أو null لو الإجابة غير محددة. "status" = "unreadable" لو الصور مش مقروءة، و"rejected" لو المحتوى مش تعليمي.`;

// mcq/tf: عدد أسئلة كل نوع في وضع التوليد (الافتراضي: count كله اختيار من متعدد).
export function systemPrompt(mode, { count = 10, mcq, tf = 0, difficulty = 'medium', language = 'ar' } = {}) {
  const nMcq = mcq ?? Math.max(count - tf, 0);
  const lang = language === 'ar' ? 'العربية' : language;
  if (mode === 'convert') {
    return `أنت مساعد يحوّل ورقة امتحان مصوّرة إلى أسئلة إلكترونية.
- استخرج أسئلة الامتحان الموجودة في الصور كما هي، بنفس الترتيب ونفس اللغة. لا تؤلّف أسئلة ولا تعدّل صياغتها.
- لا تخمّن الإجابة الصحيحة. لو الإجابة معلّمة بوضوح في الورقة (دائرة أو علامة صح أو تظليل) ضع "answer_marked": true و"correct_index" صحيحًا؛ غير ذلك ضع "answer_marked": false و"correct_index": null.
- ادعم فقط الاختيار من متعدد (2–6 اختيارات) وصح/غلط. أي سؤال مقالي أو إكمال أو توصيل لا تضعه في "questions" بل زوّد "skipped" بواحد.
- لو السؤال فيه رسم أو شكل أو جدول ضع "has_figure": true.
- لو غير متأكد من قراءة جزء (خط غير واضح أو نص مقطوع) ضع "uncertain": true.
- ضع رقم صفحة الصورة في "source_page" (تبدأ من 1).
- "explanation" اتركها فارغة في هذا الوضع.
${SCHEMA_HINT}`;
  }
  return `أنت مدرس خبير يكتب أسئلة امتحان من شرح درس.
- من المحتوى التعليمي في الصور أو النص، ولّد بمستوى ${difficulty === 'easy' ? 'سهل' : difficulty === 'hard' ? 'صعب (فهم وتطبيق مش حفظ مباشر)' : 'متوسط'}، باللغة ${lang} وبنفس مصطلحات المحتوى، الأسئلة التالية بالظبط:
${typesLine(nMcq, tf)}
- أسئلة الاختيار من متعدد: "type": "mcq" بأربع اختيارات وإجابة واحدة صحيحة بالظبط.
- أسئلة صح/خطأ: "type": "true_false" وعبارة خبرية يُحكم عليها، و"options" بالظبط ["صح", "خطأ"].
- لكل سؤال "correct_index" وشرح من جملة أو جملتين في "explanation". لا تكرر سؤالًا.
- الأسئلة لازم تعتمد على المحتوى المرفق فقط، ولا تضف معلومات من خارجه.
- لو المحتوى لا يكفي للعدد المطلوب، ولّد الأقصى الممكن بدون تكرار وأضف ملاحظة في "notes".
- لو المحتوى مش تعليمي (صور شخصية، إعلانات…) أرجع "status": "rejected" بدون أسئلة.
- "answer_marked" دايمًا true في هذا الوضع.
${SCHEMA_HINT}`;
}

export function userPrompt(mode, { text, pages } = {}) {
  const parts = [];
  if (mode === 'convert') parts.push(`حوّل ${pages ? `الـ${pages} صفحة المرفقة` : 'الصور المرفقة'} إلى أسئلة.`);
  else parts.push('هذا هو المحتوى التعليمي:');
  if (text) parts.push(`\n${text}`);
  return parts.join('\n');
}

function typesLine(mcq, tf) {
  const parts = [];
  if (mcq > 0) parts.push(`- ${mcq} سؤال اختيار من متعدد`);
  if (tf > 0) parts.push(`- ${tf} سؤال صح/خطأ`);
  return parts.join('\n');
}

export const RETRY_JSON_PROMPT = 'ردك السابق لم يكن JSON صالحًا. أعد الرد بـ JSON فقط بالمخطط المطلوب، بدون أي نص آخر.';

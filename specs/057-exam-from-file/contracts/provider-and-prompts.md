# عقد: المزوّدين والتعليمات

## واجهة المزوّد
```js
provider.extract({ mode, images, text, count, difficulty, language })
// → { ok:true, questions:[...raw], notes:[...] }
// → { ok:false, kind:'temp'|'permanent'|'auth', reason, detail }
```
التنفيذات: `providers/groq.js` و`providers/claude.js`. الاختيار من `ai_config.default_provider`، وعند `temp` أو `bad_output` بعد محاولة إعادة واحدة يُجرَّب `fallback_provider` مرة واحدة (والحصة تتحسب مرة واحدة فقط).

### Groq
`POST https://api.groq.com/openai/v1/chat/completions` — `Authorization: Bearer $GROQ_API_KEY`، النموذج من `ai_config.groq_model`. الصور كـ `{"type":"image_url","image_url":{"url":"data:image/jpeg;base64,…"}}`. حد 5 صور/طلب → تقسيم لدفعات وتجميع. `response_format` JSON لو متاح.

### Claude
`POST https://api.anthropic.com/v1/messages` — `x-api-key: $ANTHROPIC_API_KEY`، النموذج من `ai_config.claude_model`. الصور كـ `{"type":"image","source":{"type":"base64","media_type":"image/jpeg","data":"…"}}`.

> أسماء النماذج وحدود الاستخدام تتأكد في الـ spike وتتخزن في `ai_config` (مش hard-coded).

## التعليمات (system prompts، `src/prompts.js`)

**وضع convert** — «استخرج أسئلة الامتحان الموجودة في الصور كما هي. لا تؤلف أسئلة ولا تخمّن إجابة. لو الإجابة الصحيحة معلّمة بوضوح (دائرة/علامة/تظليل) ضع `answer_marked=true` و`correct_index`؛ غير ذلك `correct_index=null`. حافظ على لغة الأصل وترتيب الأسئلة. أسئلة اختيار من متعدد وصح/غلط فقط؛ لو سؤال مقالي أو إكمال ضعه في `skipped`. لو السؤال فيه رسم/شكل ضع `has_figure=true`. لو غير متأكد من قراءة جزء ضع `uncertain=true`. أرجع JSON فقط بالمخطط.»

**وضع generate** — «من المحتوى التعليمي في الصور/النص، ولّد {count} سؤال اختيار من متعدد بمستوى {difficulty}، بالعربية وبنفس مصطلحات المحتوى، كل سؤال بأربع اختيارات إجابة واحدة صحيحة وشرح من جملة أو اثنتين. الأسئلة لازم تعتمد على المحتوى فقط. لو المحتوى لا يكفي لـ{count} ولّد الأقصى بدون تكرار وضع ذلك في `notes`. لو المحتوى مش تعليمي أرجع `rejected`.»

## مخطط الرد المطلوب
```json
{
  "status": "ok | unreadable | rejected",
  "questions": [{
    "text": "string", "options": ["string"], "correct_index": 0,
    "answer_marked": false, "explanation": "string",
    "has_figure": false, "uncertain": false, "source_page": 1
  }],
  "skipped": 0,
  "notes": ["string"]
}
```

## التحقق على السيرفر (`validate.js`)
1. JSON صالح (محاولة إصلاح بسيطة: قص النص حول أول `{` وآخر `}`).
2. حذف السؤال لو النص فاضي أو اختيارات <2 (يُعدّ في `skipped`)، وقص الاختيارات الزيادة لـ6.
3. `correct_index` خارج المدى → null.
4. في `convert`: لو `answer_marked=false` → `correct_index=null` حتى لو النموذج ملاه.
5. `needs_review = uncertain || correct_index==null || options مكررة || text قصير جدًا`.
6. `duplicate`: تشابه عالي بين نصين (نفس الطلب) بعد تطبيع عربي (تشكيل/همزات).
7. قص `explanation` لـ300 حرف، وإزالة أي markdown أو HTML.
8. `status != ok` أو 0 أسئلة صالحة → فشل بدون خصم (`unreadable`/`not_educational`).

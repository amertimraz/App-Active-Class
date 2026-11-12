# ai-worker (spec 057)

قراءة صور الامتحانات وتوليد أسئلة من شرح درس. التفاصيل: `specs/057-exam-from-file/`.

- `src/` — الخدمة (prompts, validate, providers, auth, jobs, http).
- `spike/compare.js` — مقارنة Groq وClaude على صور حقيقية (ضع الصور في `spike/samples/`، ممنوعة من git).
- المفاتيح: من `app_secrets` (لوحة الأدمن) أو متغيرات البيئة. **ممنوع في git**.

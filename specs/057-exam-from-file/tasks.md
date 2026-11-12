# Tasks: إنشاء امتحان إلكتروني من ملف أو صورة

**Input**: [spec.md](spec.md)، [plan.md](plan.md)، [data-model.md](data-model.md)، [contracts/](contracts/)، [research.md](research.md)

**Tests**: مطلوبة لمنطق التحضير والتحويل والتحقق (الخطة فيها ملفات اختبار)؛ بدون TDD صارم.

**Format**: `- [ ] T### [P?] [US?] وصف + مسار الملف`. [P] = ممكن بالتوازي.

**قواعد المشروع**: كل شاشة/موضوع جديد = تحديث `lib/help/help_content.dart` و`lib/help/help_coverage.dart` في نفس التغيير. أي migration أو نشر على السيرفر يحتاج موافقة المالك. المفاتيح (Groq/Claude) على السيرفر فقط، لا في git ولا في الشات.

---

## Phase 1: Setup + Spike (قبل أي بناء)

- [ ] T001 تجهيز الخارجيات (يدوي من المالك): مفتاح Groq من console.groq.com (ومفتاح Claude اختياري)، و3 صور اختبار حقيقية (امتحان مطبوع، صفحة كتاب، خط يد) في مجلد `supabase/ai-worker/spike/samples/` (مجلد ممنوع من git)
- [ ] T002 [P] إنشاء هيكل `supabase/ai-worker/` (package.json، Dockerfile، README، `.gitignore` يحجب `.env` و`spike/samples/`، مجلدات `src/providers`، `test`، `spike`)
- [ ] T003 Spike: سكربت `supabase/ai-worker/spike/compare.js` يبعت الصور لـ Groq وClaude بالتعليمات الفعلية (من `contracts/provider-and-prompts.md`) ويطبع: عدد الأسئلة، الدقة اليدوية، الزمن، التكلفة التقريبية
- [ ] T004 تحديث `specs/057-exam-from-file/research.md` (R2) و`ai_config` الافتراضية بنتيجة الـ spike: المزوّد الافتراضي، النماذج، الحصة المجانية الواقعية، لو الجودة غير كافية نرجع لقرار المزوّد

**Checkpoint**: عندنا مزوّد وجودة مقبولة على صور حقيقية بالعربي؛ لو لأ ما نكملش.

---

## Phase 2: Foundational (يعطّل كل القصص)

- [ ] T005 كتابة `supabase/migration_ai_exam.sql`: `ai_jobs` و`ai_quota` و`ai_config` و`ai_teacher_settings` + `ai_reserve`/`ai_release` (service-only) + RLS + تنظيف `result` بعد 24 ساعة (idempotent)
- [ ] T006 [P] `supabase/ai-worker/src/prompts.js`: تعليمات convert/generate ومخطط JSON (من العقد)
- [ ] T007 [P] `supabase/ai-worker/src/validate.js`: تنضيف الأسئلة (JSON، اختيارات 2–6، correct_index، قواعد needs_review والتكرار بتطبيع عربي، قص الشرح)
- [ ] T008 [P] `supabase/ai-worker/src/providers/groq.js` و`claude.js` و`index.js`: واجهة `extract()` موحّدة، تقسيم دفعات ≤5 صور، تصنيف الأخطاء temp/permanent/auth، fallback مرة واحدة
- [ ] T009 `supabase/ai-worker/src/auth.js`: التحقق من JWT (HS256 بـ `JWT_SECRET`، `exp`، `sub`) (بعد T005)
- [ ] T010 `supabase/ai-worker/src/jobs.js`: إنشاء الطلب بـ idempotency على `job_id`، الحجز/الرد من الحصة، حالات `queued→running→done|failed|rejected`، مهلة 120ث (بعد T005, T008)
- [ ] T011 `supabase/ai-worker/src/index.js`: `POST /ai/exam/jobs` و`GET /ai/exam/jobs/:id` و`GET /ai/exam/quota` و`/ai/health`، حدود الحجم/العدد، قائمة انتظار بتزامن قابل للضبط، الصور في الذاكرة فقط بدون لوج (بعد T009, T010)
- [ ] T012 [P] اختبارات الخدمة `supabase/ai-worker/test/ai.test.js` بمزوّد وهمي (validate، تصنيف الأخطاء، fallback، idempotency، الحصة تحت التزامن، رفض توكن غلط)
- [ ] T013 إعداد النشر: خدمة `ai-worker` في docker على الـ VPS (متغيرات `DB_URL`, `JWT_SECRET`, `GROQ_API_KEY`, `ANTHROPIC_API_KEY`) + مسار `/ai/*` في Caddy — **بعد موافقة المالك**، والمفاتيح يحطها المالك بنفسه
- [ ] T014 تطبيق الـ migration على السيرفر عبر SSH (`supabase_admin`) والتحقق من الجداول والـ RLS — **بعد موافقة المالك**
- [ ] T015 [P] التطبيق: عمود `review_flags` على `exam_questions` (DB v44 في `database_service.dart` وثابت في `constants.dart`) + حقل في `lib/models/exam_question_model.dart` (غير مزامَن ولا داخل `toCloudMap`، يتصفّر عند تعديل المدرس)
- [ ] T016 [P] `lib/utils/ai_exam_prepare.dart`: تحضير الصور (أقصى ضلع 1600px، JPEG ~80)، تحويل صفحات PDF لصور بـ `Printing.raster`، فرض الحدود (10 صور/15 ميجا) مع رسالة قبل الرفع
- [ ] T017 [P] `lib/models/ai_draft_question.dart` + `lib/utils/ai_exam_mapper.dart`: JSON ← `ExamQuestion` مسودة بعلامات المراجعة
- [ ] T018 اختبارات `test/ai_exam_prepare_test.dart` و`test/ai_exam_mapper_test.dart` (بعد T016, T017)
- [ ] T019 `lib/services/ai_exam_service.dart`: إنشاء الطلب بـ `job_id` UUID، polling كل 2–3 ثواني، قراءة الحصة، التعامل مع 401/402/403/413/503، التوكن من جلسة Supabase (بعد T015, T016, T017)

**Checkpoint**: طلب تجريبي من التطبيق ← السيرفر ← المزوّد ← أسئلة JSON راجعة للتطبيق.

---

## Phase 3: US1 — تحويل صورة/ملف امتحان موجود (P1) 🎯 MVP

**Goal**: ورقة امتحان مصوّرة ← مسودة أسئلة في المحرر.
**Independent Test**: صورة 10 أسئلة اختيار من متعدد ← 10 أسئلة بنصوص واختيارات صحيحة، والإجابة المعلّمة متحددة.

- [ ] T020 [US1] `lib/views/exams/ai_exam_source_sheet.dart`: اختيار الوضع «تحويل امتحان موجود» + مصدر (كاميرا/معرض/PDF) + معاينة الصفحات وحذف صفحة + عرض الحدود والحصة (بتصميم `AppPanel`)
- [ ] T021 [US1] `lib/views/exams/ai_exam_progress_page.dart`: حالة التقدّم، إمكانية الرجوع للتطبيق ومتابعة الطلب، رسائل الفشل بالعربي بدون خصم (مش قادر أقرا، غير تعليمي، لا إنترنت)
- [ ] T022 [US1] دمج النتيجة في `lib/views/exams/online_exam_editor_page.dart`: زر «من ملف أو صورة» جنب «أضف من البنك»، إضافة الأسئلة كمسودة بترتيبها، عرض شارة «محتاج مراجعة» و«الإجابة ناقصة»
- [ ] T023 [US1] أنواع غير مدعومة: تخطي المقالي/إكمل مع رسالة «اتخطّى N سؤال» في شاشة النتيجة
- [ ] T024 [US1] رسالة أول مرة عن الذكاء الاصطناعي ومسؤولية المراجعة (FR-018) تظهر مرة وتتكرر في شاشة المراجعة
- [ ] T025 [US1] اختبار `test/ai_exam_source_sheet_test.dart` (حدود الصفحات، حذف صفحة، رسالة الحدود)
- [ ] T026 [US1] موضوع مساعدة «امتحان من صورة أو ملف» في `lib/help/help_content.dart` + `help_coverage.dart` + اختبارات help الثلاثة

---

## Phase 4: US3 — المراجعة والتعديل قبل النشر (P1)

**Goal**: ما ينفعش ينشر امتحان بلا مراجعة، والمسودة تفضل محفوظة.
**Independent Test**: توليد، تعديل إجابة، حذف سؤال، نشر ← الامتحان المنشور بيطابق التعديلات.

- [ ] T027 [US3] منع النشر لو أي سؤال بلا إجابة صحيحة، وتنبيه بعدد المعلّمة «محتاج مراجعة» مع تأكيد المدرس، في `online_exam_editor_page.dart`
- [ ] T028 [US3] تصفير علامة المراجعة عند تعديل نص السؤال أو الاختيارات أو الإجابة (مراجَع)، وحفظ العلامات مع المسودة عند إغلاق المحرر
- [ ] T029 [US3] علامة «مكرر؟» بجانب سؤال مشابه لسؤال تاني في الامتحان (بدون حذف تلقائي)
- [ ] T030 [US3] اختبار `test/online_exam_review_flags_test.dart` (منع النشر، تصفير العلامة، حفظ المسودة)

---

## Phase 5: US2 — توليد أسئلة من شرح درس (P1)

**Goal**: صور/PDF/نص درس ← أسئلة مولّدة بإجابات وشرح.
**Independent Test**: صفحتين درس و5 أسئلة سهلة ← 5 أسئلة بإجابة صحيحة وشرح بالعربي.

- [ ] T031 [US2] توسيع `ai_exam_source_sheet.dart` بوضع «توليد من شرح درس»: عدد الأسئلة (1–30)، الصعوبة (سهل/متوسط/صعب)، ولصق نص بدل الصور
- [ ] T032 [US2] تعامل الـ worker مع `notes` (المحتوى لا يكفي ← أقصى عدد ممكن) وعرضها في شاشة النتيجة بالعدد الفعلي
- [ ] T033 [US2] حفظ الشرح (`explanation`) مع السؤال المولّد (الحقل المحلي الموجود، ما بيترفعش للطالب قبل الاعتماد)
- [ ] T034 [US2] اختبار mapper لوضع التوليد (الشرح، الصعوبة، العدد) في `test/ai_exam_mapper_test.dart`

---

## Phase 6: US4 — الحصة الشهرية والرصيد (P2)

**Goal**: المدرس يشوف المتبقي ويتنبه، وتتقفل الميزة الذكية بس عند النفاد.
**Independent Test**: حصة 2، 3 عمليات ← الثالثة `quota` بدون خصم والعدّاد صح.

- [ ] T035 [US4] عرض المتبقي في `ai_exam_source_sheet.dart` وتحذير <20% (FR-014)
- [ ] T036 [US4] حالة نفاد الحصة: رسالة واضحة وتفضل الأزرار اليدوية والبنك شغّالة (FR-015)
- [ ] T037 [US4] لوحة الأدمن (repo منفصل): ضبط الحصة، إضافة رصيد، استهلاك كل مدرس، إيقاف مدرس/الكل (FR-019)
- [ ] T038 [US4] سجل العمليات في `ai-worker` وعرضه للأدمن (النوع، الوقت، العدد، النتيجة، المزوّد) بدون محتوى (FR-021)
- [ ] T039 [US4] اختبار `test/ai_exam_quota_ui_test.dart`

---

## Phase 7: US5 — أسئلة فيها رسومات (P3)

**Goal**: المدرس يرفق صورة الشكل بالسؤال.
**Independent Test**: سؤال معلّم «فيه شكل» ← قص الشكل وإرفاقه ← يظهر للطالب.

- [ ] T040 [US5] شارة «فيه شكل» وزر «قص وإرفاق» في المحرر يفتح قص من صورة الصفحة الأصلية ويرفقها بميزة صورة السؤال (spec 019)
- [ ] T041 [US5] اختبار `test/ai_exam_figure_attach_test.dart`

---

## Phase 7b: مفاتيح الخدمات من لوحة الأدمن (FR-023)

- [x] T047 `supabase/migration_app_secrets.sql`: جدول `app_secrets` (RLS بلا policies) + دوال `app_secrets_status` و`app_secret_set` (service_role فقط) — **التطبيق على السيرفر بعد موافقة المالك**
- [x] T048 قراءة المفاتيح من الجدول مع احتياطي البيئة: `supabase/wa-worker/src/secrets.js` (واتساب الآن) — و`ai-worker` يستخدم نفس الملف عند بنائه
- [x] T049 صفحة «مفاتيح الخدمات» في لوحة الأدمن (`active_class_admin/lib/views/api_keys_page.dart` + `services/api_keys_service.dart` + تبويب في `dashboard_page.dart`)

---

## Phase 8: Polish & تجريبي

- [ ] T042 [P] جولة «جرّبها بنفسك» اختيارية للميزة في `lib/tour/tour.dart` (+ `tour_sync_test`)
- [ ] T043 مراجعة الخصوصية: لا صور على القرص ولا في اللوج، `result` بيتحذف بعد 24 ساعة، مراجعة إعدادات الاحتفاظ/التدريب عند كل مزوّد وكتابتها في شرح الميزة
- [ ] T044 تشغيل سيناريوهات `quickstart.md` الـ11 على صور حقيقية، وتسجيل الدقة المقيسة مقابل SC-002/SC-003
- [ ] T045 تجريبي مغلق مع مدرس/اثنين لأسبوعين: مراقبة الدقة والتكلفة والحصة، ثم ضبط الحصة النهائية والمزوّد الافتراضي
- [ ] T046 رفع الإصدار + بناء + ملاحظات إصدار (بعد موافقة المالك على النشر)

---

## Dependencies

- Phase 1 (spike) → Phase 2 → US1 (3) → US3 (4) → US2 (5).
- US4 (6) يعتمد على Phase 2 فقط ويمشي بالتوازي مع 4–5 بعد T019.
- US5 (7) يعتمد على US1.
- T013/T014 (نشر السيرفر) شرط لأي اختبار حقيقي من التطبيق.
- **لو الـ spike (T003/T004) فشل في الجودة، نوقف قبل Phase 2.**

## Parallel Examples

- Phase 2: T006، T007، T008 معًا؛ T015، T016، T017 معًا (ملفات مختلفة).
- بعد T019: US4 (T035) بالتوازي مع T020 (US1).

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1 + US3**: تحويل ورقة امتحان مطبوعة لمسودة، مع منع النشر بدون مراجعة، لمدرس واحد بحصة ثابتة. نراجع الدقة والتكلفة.
2. بعدها التوليد من الدرس (US2)، ثم الحصة (US4)، ثم الرسومات (US5).
3. لا نفتح لكل المدرسين قبل T045.

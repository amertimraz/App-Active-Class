# Tasks: صور أسئلة الامتحان الإلكتروني — قص + صورة للشرح + صورة لكل اختيار

**Input**: plan.md, spec.md, research.md, data-model.md, contracts/question-images.md, quickstart.md
**Tests**: اختبار وحدة للمنطق الصرف (`test/exam_question_images_test.dart`) + تحقق يدوي (القص والرفع والعرض UI فعليين، مش قابلين لاختبار آلي في هذا المشروع).

## Format: `[ID] [P?] [Story?] Description`
- **[P]**: بالتوازي (ملفات مختلفة بلا تبعية)
- مسارات نسبية لجذر المشروع `C:\repo\active_class`

---

## Phase 1: Setup

- [x] T001 إضافة `image_cropper` في `pubspec.yaml` (`flutter pub get`)، وتسجيل `UCropActivity` في `android/app/src/main/AndroidManifest.xml` حسب توثيق المكتبة
- [x] T002 في `lib/config/constants.dart`: رفع `DATABASE_VERSION` إلى 36؛ إضافة `COL_EQ_EXPLANATION_IMAGE_URL`, `COL_EQ_OPTION_IMAGE_URLS`, `COL_BQ_EXPLANATION_IMAGE_URL`, `COL_BQ_OPTION_IMAGE_URLS`

---

## Phase 2: Foundational (blocking prerequisites)

- [x] T003 [P] إنشاء `lib/widgets/image_crop_picker.dart`: `pickAndCropImage(BuildContext)` حسب `contracts/question-images.md` — نفس إعدادات `ImagePicker` ومعالجة MIUI lost-data الحالية في `online_exam_editor_page.dart`، ثم `ImageCropper` بأي نسبة، يرجّع `Uint8List?` (null لو إلغاء في أي خطوة)
- [x] T004 [P] إضافة `alignOptionImages`, `addOptionImageSlot`, `removeOptionImageSlot` في نفس الملف أو `lib/utils/` (منطق صرف) حسب العقد
- [x] T005 [P] إنشاء `test/exam_question_images_test.dart` بالسيناريوهات في quickstart.md (1-5)
- [x] T006 تحديث `lib/models/exam_question_model.dart`: حقلا `explanationImageUrl`/`optionImageUrls` في الكونستركتور/`toMap`/`fromMap`/`copyWith` (نمط `_unset` الحالي)؛ `toCloudMap` تضيف `optionImageUrls` بس (مش `explanationImageUrl`)
- [x] T007 تحديث `lib/models/bank_question_model.dart` بنفس التعديل بالظبط (بدون `toCloudMap` — البنك مالوش نشر سحابي للطالب)
- [x] T008 تحديث `lib/models/exam_submission_model.dart` (`QuestionResult`): إضافة `explanationImageUrl`/`optionImageUrls`
- [x] T009 في `lib/services/database_service.dart`: `ALTER TABLE exam_questions/bank_questions ADD COLUMN` للأعمدة الأربعة داخل `if (oldVersion < 36)` (try/catch لكل عمود، نمط الفروع السابقة)؛ تضمينها في `_onCreate` (تعريف الجدولين الجديد لو بيتعرّف هنا، أو فقط `_onUpgrade` لو الجدولين بيتعرّفوا بأعمدتهم الكاملة مباشرة)
- [x] T010 في `lib/services/sync_engine.dart`: push/pull mapping لـ`TABLE_EXAM_QUESTIONS` و`TABLE_BANK_QUESTIONS` (القناة الممتدة، موجودة بالفعل) — إضافة الحقلين الجديدين في الاتجاهين، بنفس نمط `explanation`/`image_url` الحاليين
- [x] T011 [P] إنشاء `supabase/migration_exam_question_images.sql`: `alter table public.exam_questions add column if not exists explanation_image_url text, add column if not exists option_image_urls text;` ونفسها لـ`bank_questions` — idempotent، بلا تغيير RLS/triggers
- [x] T012 تطبيق `supabase/migration_exam_question_images.sql` عبر SSH (نفس مستخدم `exam_questions`/`bank_questions` الحالي) والتأكد من ظهور العمودين في الجدولين
- [x] T013 **CHECKPOINT**: `flutter analyze` + `flutter test` (شامل T005) صفر تراجع؛ تشغيل التطبيق والتأكد من ترقية DB لـv36 بدون كراش

**Checkpoint**: الأساس (موديلات + DB + مزامنة) جاهز لكل الـStories.

---

## Phase 3: User Story 1 - قص الصورة قبل رفعها (Priority: P1) 🎯 MVP الجزئي

**Goal**: أي صورة جديدة (سؤال بالذات أولًا، ثم شرح/اختيارات في Stories التالية) تمر بشاشة قص قبل الرفع.

**Independent Test**: اختيار صورة سؤال من المعرض → شاشة قص تظهر → الصورة المرفوعة هي الجزء المقصوص؛ الإلغاء لا يغيّر الصورة القديمة.

- [x] T014 [US1] في `lib/views/exams/online_exam_editor_page.dart`: استبدال منطق `_pickQuestionImage` بنداء `pickAndCropImage` (T003) ثم `_ec.uploadQuestionImage` بالـbytes الناتجة؛ null → لا تغيير ولا رفع
- [x] T015 [US1] [P] نفس الاستبدال في `lib/views/question_bank/question_editor_sheet.dart` لصورة سؤال البنك
- [ ] T016 [US1] **CHECKPOINT**: `flutter analyze` + تحقق يدوي (quickstart بند 1) على الشاشتين

---

## Phase 4: User Story 2 - صورة اختيارية مع شرح الإجابة (Priority: P1)

**Goal**: صورة شرح تمر بنفس خطوة القص، محلية فقط، تظهر للطالب بعد الاعتماد جنب نص الشرح.

**Independent Test**: شرح + صورة لسؤال → اعتماد تسليم طالب → ظهور الاتنين في مراجعته؛ طالب غير معتمد لا يرى شيئًا؛ حذف الصورة وحدها يبقي النص.

- [x] T017 [US2] في `_QDraft` (`online_exam_editor_page.dart`): حقل `explanationImageUrl` + `uploadingExplanationImage`؛ `toModel`/`fromBankQuestion` يمرّرانه
- [x] T018 [US2] في نفس الملف: زر/أيقونة "صورة للشرح" جنب حقل الشرح النصي الحالي (pick+crop عبر T003 → رفع → تخزين الرابط)، مع معاينة مصغّرة وزر حذف (نمط `_questionImageThumb` الحالي)
- [x] T019 [US2] [P] نفس الإضافة في `lib/views/question_bank/question_editor_sheet.dart`
- [x] T020 [US2] في `lib/controllers/exam_controller.dart` (`questionResults`): تمرير `q.explanationImageUrl` لـ`QuestionResult`
- [x] T021 [US2] في `lib/services/online_exam_service.dart` (`publishReview`): إضافة `explanationImageUrl` لمستند `results/{attemptKey}` بنفس شرط `explanation` (`if (r.explanationImageUrl != null && ...)`) — **لا** في أي مسار آخر
- [x] T022 [US2] في `booking_site/exam/index.html` (`renderReview`): عرض `q.explanationImageUrl` (لو موجودة) جنب `q.explanation` الحالية، داخل `.rexpl` أو عنصر مجاور
- [x] T023 [US2] في `lib/views/exams/online_exam_preview_page.dart`: عرض نص الشرح (لو موجود) وصورته تحت خيارات السؤال، لمعاينة المدرّس قبل النشر
- [ ] T024 [US2] **CHECKPOINT**: `flutter analyze` + تحقق يدوي (quickstart بند 2)

---

## Phase 5: User Story 3 - صورة لكل اختيار (Priority: P1)

**Goal**: صورة اختيارية لكل اختيار، تظهر وقت الأداء وفي المراجعة، وتُحذف مع حذف الاختيار.

**Independent Test**: صورة لاختيارين من 4 → طالب يشوفهم وقت الأداء وفي المراجعة؛ حذف اختيار يشيل صورته بس.

- [x] T025 [US3] في `_QDraft`: حقل `List<String?> optionImageUrls` متزامن مع `options` (استخدام `addOptionImageSlot`/`removeOptionImageSlot` من T004 عند إضافة/حذف اختيار)؛ `toModel`/`fromBankQuestion` يمرّرانه
- [x] T026 [US3] في `_questionCard`/صف كل اختيار (`online_exam_editor_page.dart`): أيقونة صغيرة لإضافة/استبدال/حذف صورة الاختيار (pick+crop عبر T003 → رفع → تخزين) مع معاينة مصغّرة بجنب حقل نص الاختيار
- [x] T027 [US3] [P] نفس الإضافة في `lib/views/question_bank/question_editor_sheet.dart`
- [x] T028 [US3] في `lib/views/exams/online_exam_preview_page.dart`: عرض صورة كل اختيار (لو موجودة) جنب نصه
- [x] T029 [US3] في `booking_site/exam/index.html`: عرض صورة الاختيار في `render()` (أثناء الأداء) باستخدام `q.v.optionImageUrls?.[op.i]` (المحاذاة بالـindex الأصلي بعد الخلط — راجع research.md §6)، وفي `renderReview()` بنفس الفكرة بدون خلط
- [x] T030 [US3] في `booking_site/exam/index.html`: معالجة `onerror` لكل `<img>` (سؤال/اختيار/شرح) تستبدل الصورة بنص "تعذّر تحميل الصورة" بدل ما تكسر التخطيط (FR-011/SC-005)
- [ ] T031 [US3] **CHECKPOINT**: `flutter analyze` + تحقق يدوي كامل من جهاز حقيقي (quickstart بنود 3، 6، 7) — أداء امتحان فعلي من متصفح

---

## Phase 6: Polish & Cross-Cutting

- [ ] T032 [P] تحقق يدوي بند 5 (بنك الأسئلة → "أضف من البنك" يحافظ على كل الصور)
- [x] T033 [P] `flutter analyze` كامل (صفر جديد) و`flutter test` كامل
- [ ] T034 بناء release وتثبيته على جهاز والتحقق النهائي، وتحديث `HANDOFF.md` بملخص spec 043

---

## Dependencies & Execution Order

- **T001/T002 → Foundational**: كل مهام Phase 2 تعتمد عليهم.
- **داخل Foundational**: T003/T004/T005 مستقلة بالتوازي؛ T006/T007/T008 بعدهم (تستخدم T004 اختياريًا)؛ T009 قبل T010؛ T011 مستقل بالتوازي مع T009/T010؛ T012 بعد T011؛ T013 بوابة قبل أي Story.
- **US1 → US2/US3**: US2 وUS3 تعتمدان على `pickAndCropImage` (T003) من Foundational فقط، فهما مستقلتان عن بعض فعليًا — لكن بالتسلسل هنا لأنهما بيعدّلوا نفس ملفات المحرّر (`online_exam_editor_page.dart`, `question_editor_sheet.dart`) بالتتابع لتفادي تعارض.
- **داخل كل Story**: الموديل/الحالة أولًا، ثم UI المحرّر، ثم المعاينة، ثم المسار السحابي (publishReview/الويب)، ثم CHECKPOINT.

### Parallel Opportunities
T003+T004+T005؛ T014+T015؛ T018+T019 (ملفات مختلفة)؛ T026+T027؛ T032+T033.

## Implementation Strategy

**MVP**: T001–T016 (الأساس + US1: القص شغّال على صورة السؤال القديمة). بعدها US2 (شرح) ثم US3 (اختيارات — الأكبر، يلمس صفحة الويب). كل Story CHECKPOINT (analyze + تحقق يدوي) قبل الانتقال، وUS3 لازم تحقّق فعلي من متصفح حقيقي قبل اعتبارها جاهزة (مش قابلة للاختبار الآلي).

# ملاحظات تنفيذ سبيك 016 — امتحان إلكتروني

**التاريخ**: 2026-09-02 · **الفرع**: `016-online-exam`

## الحالة: التنفيذ اكتمل (كود) — التحقّق على الجهاز/السحابة متبقّي

`flutter analyze` — صفر أخطاء/تحذيرات، صفر infos جديدة من كود السبيك (الـ40 info الظاهرة كلها موجودة قبل السبيك).

## الملفات

**جديدة:**
- `lib/models/exam_question_model.dart` — `ExamQuestion` + `ExamQuestionType`؛ `toCloudMap()` بدون مفتاح إجابة
- `lib/models/exam_submission_model.dart` — `ExamSubmission` + `SubmissionStatus` + `QuestionResult`
- `lib/services/online_exam_service.dart` — `OnlineExamService` (publish/unpublish/stopNow/deleteRemote/fetchSubmissions) + `CloudSubmission`
- `lib/views/exams/online_exams_tab.dart` — تبويب "امتحان إلكتروني" + الحالة المقفولة + كروت + أزرار
- `lib/views/exams/online_exam_editor_page.dart` — تأليف الأسئلة + التوقيت + المجموعات + نشر + شيت الرابط
- `lib/views/exams/online_exam_results_page.dart` — تحديث النتائج + مراجعة + تعديل يدوي + اعتماد
- `booking_site/exam/index.html` — صفحة الطالب (نمط `booking_site/track`)

**معدّلة:**
- `lib/config/constants.dart` — `DATABASE_VERSION` 22→23 + ثوابت الجداول/الأعمدة
- `lib/services/database_service.dart` — schema + migration v23 + CRUD (أسئلة/تسليمات/setExamOnlineFields/allowedStudentCodesForGroups)
- `lib/models/exam_model.dart` — 5 حقول إلكترونية + `OnlineExamStatus` (خارج `toMap` عمدًا — محلية)
- `lib/controllers/exam_controller.dart` — تأليف/نشر/سحب+تصحيح/اعتماد
- `lib/views/exams/exams_page.dart` — `TabController` بتبويبين (ورقي / إلكتروني)
- `lib/services/parent_portal_service.dart` — تعليق على `ensureSlug` (مصدر slug مشترك)
- `firestore.rules` — بلوك `online_exams/{slug}`

## شغل يدوي متبقّي على المستخدم (T030 / T015)

1. **نشر قواعد Firestore**: `firebase deploy --only firestore:rules`
2. **نشر صفحة الطالب**: رفع `booking_site/exam/` على الـVPS مع توجيه `/exam/*` → `index.html` (زي `/track` و`/book`)

## تحقّق متبقّي (محتاج جهاز/سحابة — T044/T045/T046)

- T044: ميجريشن v22→v23 على بيانات فعلية (156 طالب)
- T045: [quickstart.md](quickstart.md) سيناريوهات 1–5
- T046: تأكيد أمني — لا مفتاح إجابة في Firestore، لا تسليم مزدوج، لا رؤية درجة قبل الاعتماد

## باجات اتعالجت (بعد أول تنفيذ)

| # | كان | الإصلاح |
|---|---|---|
| 1 | فحص هوية الطالب يفشل لو ملخص بوابته مش منشور | `publish` بيتأكد من وجود مستند كل طالب مسموح ويعمل `pushStudentSummary` للناقص (`allowedStudentsForGroups` بترجّع `id`+`code`+`last4`) |
| 2 | مستمع `online` في صفحة الطالب ميت | إعادة هيكلة `submit`: `inFlight`/`wantsSubmit` + `retryTimer`؛ رجوع النت يحاول فورًا |
| 3 | صف `exams` الإلكتروني بيتسرّب لمساعدي الفريق | `insertExam`/`updateExam` + `skipSync: true` للامتحان الإلكتروني |
| 4 | ساعة جهاز الطالب الغلط تأثّر على الفتح/المؤقّت | مهلة دخول ±دقيقتين + `serverOffset` (فرق ساعة الجهاز عن الخادم للمحاولة الجديدة) يصحّح المؤقّت |
| 5 | سباق إنشاء `attempts` على جهازين | فشل `setDoc` على `attempts` يكمّل بالقراءة الموجودة بدل خطأ |
| 6 | "اعتماد الكل" يعلّم كل من لم يسلّم غائبًا | `approveAllOnlineGrades` يعتمد `pending` فقط؛ الغياب بضغطة يدوية |

`flutter analyze` بعد الإصلاحات — صفر أخطاء/تحذيرات، صفر infos جديدة. `node --check` على JS صفحة الطالب — سليم.

## قرارات تنفيذية مهمة

- **الأعمدة الإلكترونية على `exams` مش في `toMap`** → payload مزامنة الفريق يفضل نظيف (R7). `fromMap` بيقراها.
- **مستندان create-only** على السحابة: `attempts/{code}_{last4}` (يثبّت `startedAt`) + `submissions/{code}_{last4}` (الإجابات). الاستئناف من `attempts`.
- **التصحيح كله في `ExamController.pullAndGradeOnlineExam`** — `correctIndex` ما يغادرش الجهاز.
- **الاعتماد** يمر عبر `saveGrade` الموجود → `pushStudentSummary` + خط واتساب (سبيك 008) يشتغلوا بلا تعديل.
- الميزة مقفولة خلف `LicenseController.to.parentPortalActiveNow`.

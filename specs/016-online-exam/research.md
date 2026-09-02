# Phase 0 — Research: امتحان إلكتروني

كل قرارات النطاق اتحسمت مع المستخدم قبل السبيك. الباقي قرارات تقنية محلولة تحت.

## R1 — قناة النشر: Firestore بنمط بوابة الأهالي

**Decision**: إعادة استخدام Firestore مشروع `active-class-72e0f` ونفس `{slug}` الحتمي المشتق من كود الترخيص (`ParentPortalService._deterministicSlug`). شجرة جديدة `online_exams/{slug}`.

**Rationale**:
- `booking_site/track` و`booking_site/book` بيثبتوا النمط: صفحة ثابتة + Firebase JS SDK عبر CDN + مصادقة مجهولة + قراءة عامة مقفولة بمعرّف مستند غير متوقّع. صفر بنية خادم.
- الميزة مقفولة خلف `parentPortalEnabled` أصلًا، فالـslug موجود ومنشور.
- `firebase_auth` + `cloud_firestore` مضمّنين ومستخدمين.

**Alternatives considered**:
- Supabase (`team_schema`) — مرفوض: مصمّم لمزامنة المدرس↔المساعدين بمصادقة إيميل، مش لوصول طلاب مجهولين؛ ومحتاج RLS جديدة معقّدة.
- خادم مخصّص — مرفوض: مفيش بنية استضافة تطبيق، الـVPS ثابت فقط.

## R2 — إثبات هوية الطالب على صفحة الويب

**Decision**: التحقق بقراءة `parent_portal/{slug}/students/{code}_{last4}` الموجود (لو المستند موجود → الطالب معروف، ونجيب منه `groupName`). التفويض بفحص `code` ضمن خريطة `allowedCodes` في مستند الامتحان.

**Rationale**:
- `{code}_{last4}` هو نفس عمود الحماية المستخدم في `/track` — الطالب يعرف كوده ورقم ولي أمره.
- إعادة استخدام مستندات ملخّص الطلاب المنشورة بالفعل → مفيش نشر بيانات طلاب جديد لهذه الميزة.
- `allowedCodes` (خريطة `{ "A05": true }`) تسمح لقاعدة الأمان وللصفحة يفحصوا مفتاحًا واحدًا بسرعة بدون سرد.

**Dependency**: الامتحان الإلكتروني يتطلّب إن ملخصات الطلاب منشورة (بوابة الأهالي نشطة) — موثّق كافتراض في السبيك. عند النشر، `OnlineExamService` يستدعي `publishAllStudents()` أولًا لو لزم (best-effort) لضمان وجود المستندات.

**Alternatives considered**:
- كود امتحان لكل طالب — مرفوض من المستخدم (اختار هوية بوابة الأهالي).
- تضمين هاش الأرقام في مستند الامتحان — تعقيد زائد بلا فائدة على `{code}_{last4}`.

## R3 — تسليم واحد + استئناف بعد إغلاق المتصفح

**Decision**: مستندان منفصلان، كلاهما **create-only**:
- `online_exams/{slug}/exams/{examId}/attempts/{code}_{last4}` — يُنشأ لحظة أول فتح، يحمل `startedAt: serverTimestamp()`.
- `online_exams/{slug}/exams/{examId}/submissions/{code}_{last4}` — يُنشأ لحظة التسليم، يحمل `answers` + `submittedAt` + `autoSubmitted`.

منطق صفحة الطالب:
- لو `submissions` موجود → "لقد سلّمت هذا الامتحان بالفعل" (نهائي).
- لو `attempts` موجود بلا `submissions` و`now < startedAt + duration` و`now < closesAt` → استئناف؛ المؤقّت المتبقّي = `startedAt + duration - now`؛ الإجابات المدخلة من `localStorage`.
- لو انتهى الوقت بلا تسليم → الصفحة تحاول إنشاء `submissions` تلقائيًا بالإجابات المخزّنة (`autoSubmitted: true`).

**Rationale**: كلا المستندين create-only → قواعد أمان بسيطة، ومستحيل الطالب يصفّر مؤقّته (ما يقدرش يحذف `attempts`). تبديل الجهاز = `attempts` موجود → يستأنف بالوقت الصحيح (FR-015، edge case الجهازين).

**Alternatives considered**:
- مستند واحد بحالة متغيّرة + قاعدة update مشروطة — مرفوض: منطق قاعدة أعقد وسطح خطأ أكبر.
- المؤقّت client-side فقط بلا `attempts` — مرفوض: يُصفَّر بمسح `localStorage` أو تبديل جهاز.

## R4 — التصحيح داخل التطبيق فقط

**Decision**: مستند الامتحان المرفوع يحمل `questions: [{ id, type, text, options }]` **بلا** حقل `correct`. الإجابات الصحيحة تفضل في `exam_questions` المحلي فقط. عند "تحديث النتائج": التطبيق يسحب `submissions`، ويصحّح لكل تسليم: `score = Σ points(q) حيث answer[q.id] == correct(q)`.

**Rationale**: يمنع استخراج الحل من الشبكة/Firestore (SC-004). التصحيح يشتغل أوفلاين بعد السحب.

**Alternatives considered**:
- رفع الحل مشفّرًا — مرفوض: المفتاح لازم يوصل العميل عشان المؤقّت الفوري، فمش أمان حقيقي.
- Cloud Function للتصحيح — مرفوض: بنية زائدة، والمستخدم اختار "المدرس يراجع أولًا" فمفيش داعي لتصحيح سحابي فوري.

## R5 — التوقيت بوقت مطلق

**Decision**: `opensAt`/`closesAt` تُخزَّن وتُرفع كـ ISO-8601 UTC (`.toUtc().toIso8601String()`، نمط `_publishProfile`). `attempts.startedAt` = `serverTimestamp()` من Firestore. صفحة الطالب تقارن بـ `Date.now()` (لحظة مطلقة).

**Rationale**: نفس الحادثة اللي اتعالجت في `parent_portal` (تعليق `.toUtc()` في `parent_portal_service.dart:250`) — جهاز الطالب في منطقة زمنية/ساعة مختلفة ما يعتمدش عليه.

## R6 — مكان حالة الامتحان الإلكتروني

**Decision**: أعمدة إضافية على جدول `exams` الحالي (`is_online INTEGER DEFAULT 0`, `online_status TEXT`, `opens_at TEXT`, `closes_at TEXT`, `duration_minutes INTEGER`) بدل جدول منفصل. الأسئلة والتسليمات في جدولين جديدين.

**Rationale**: `getAllExams`/`getExamsForGroup`/كل استعلامات الامتحان الحالية تفضل شغّالة بلا تعديل؛ الامتحان الإلكتروني = امتحان عادي + علم. `ExamStatus` (progress) الحالي منفصل عن `online_status` الجديد (مسودّة/منشور/موقوف/محذوف-من-الويب).

**Alternatives considered**:
- جدول `online_exams` محلي منفصل بـ FK — مرفوض: ازدواج، و`exam_grades` أصلًا مربوط بـ `exam_id`.

## R7 — المزامنة مع الفريق (Supabase)

**Decision**: v1 — `exam_questions` و`exam_submissions` والأعمدة الجديدة على `exams` **خارج** مخطط `sync_engine`. التأليف والنشر والتصحيح كلها من جهاز المدرس الأساسي فقط.

**Rationale**: المستخدم أجّل مزامنة الفريق لـ v2. الأعمدة الجديدة على `exams` ما تدخلش payload الـpush/pull الحالي (الكود يذكر أعمدة صراحةً، مش `SELECT *`)، فمفيش تسرّب.

**Note لـ v2**: إضافة `exam_questions` لمخطط المزامنة + جدول Supabase مناظر لو اتطلب.

## R8 — إعادة استخدام `{slug}` من ParentPortalService

**Decision**: كشف `ensureSlug()` (موجودة، `Future<String>`) للاستخدام العام من `OnlineExamService`، أو استخراج اشتقاق الـslug لـ helper مشترك. `OnlineExamService` يستدعي `ParentPortalService().ensureSlug()`.

**Rationale**: مصدر واحد لاشتقاق الـslug (تجنّب انحراف لو اتغيّرت الخوارزمية). `ensureSlug` عندها side-effect (migration الطلاب) لكنه idempotent وحميد.

## R9 — idempotency التصحيح والاعتماد

**Decision**: `exam_submissions` بفهرس فريد `(exam_id, student_id)`. "تحديث النتائج" = upsert على المفتاح ده. `exam_grades` upsert موجود بمفتاح `(exam_id, student_id)` (`database_service.dart:1872`). الاعتماد يكتب في `exam_grades`؛ إعادة السحب ما تدهسش صف `exam_submissions` حالته `approved` بقيمة محسوبة إلا لو المدرس طلب "إعادة حساب".

**Rationale**: FR-027 — لا صفوف مكرّرة، لا دهس لاعتماد يدوي.

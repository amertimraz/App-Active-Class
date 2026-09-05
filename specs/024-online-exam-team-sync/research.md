# Phase 0 Research: مزامنة الامتحانات الإلكترونية عبر الفريq 024

## R1 — مرونة Realtime: إزاي جدول ناقص ما يكسرش القناة كلها

**السياق**: `_subscribeRealtime()` بيعمل `client.channel('team-$teamId')` واحدة، بيسجّل `onPostgresChanges` لكل جدول في `_tables`، وبعدين `channel.subscribe()`. في supabase-flutter v2، أي binding لجدول مش في `supabase_realtime` publication (أو غير موجود) → `CHANNEL_ERROR` للـchannel join كله → **كل** البثّ اللحظي بيقع، و`catchUpPull()` (المربوط بـ`RealtimeSubscribeStatus.subscribed`) ما بيتنادىش. ده اللي حصل مع `student_follow_ups`.

**الخيارات**:
| الخيار | + | − |
|---|---|---|
| قناة واحدة لكل جدول | عزل كامل | ~10 اتصالات socket، ~10 subscribe |
| قناتان: أساسية + ممتدة | عزل عملي، اتصالان بس | الجداول الممتدة بتفشل مع بعض لو أي واحد ناقص |
| قناة واحدة + تخطّي binding لجدول ناقص | اتصال واحد | محتاج فحص وجود الجدول قبل الاشتراك (round-trip إضافي)، وما يحميش من فشل غير متوقّع |

**القرار**: **قناتان**.
- `team-$teamId` (أساسية): `groups`, `students`, `attendance`, `payments`, `homework`, `exams`, `exam_groups`, `exam_grades`. `channel.subscribe` بتاعتها هي اللي بتنادي `catchUpPull()`.
- `team-$teamId-x` (ممتدة): `exam_questions`, `exam_submissions` (وأي جدول جديد مستقبلًا زي `student_follow_ups`). فشلها ما بيلمسش الأساسية ولا `catchUpPull`. لو نجحت، تنادي `catchUpPull()` كمان (idempotent — `_pulling` guard موجود).
- الاتنين بيتعملهم `_channel`/`_channelX` ويتقفلوا في `stop()`.

**الأثر**: ~20 سطر في `_subscribeRealtime` + حقل `_channelX`. الجداول الأساسية تفضل مضمونة مهما حصل للامتحانات الإلكترونية.

## R2 — أعمدة المزامنة على الجدولين المحليين + تنسيق مع spec 023

**السياق**: `exam_questions` و`exam_submissions` دلوقتي محليان بالكامل — **مالهمش** `sync_updated_at` ولا `sync_remote_id` (باقي الجداول المتزامنة عندها العمودين دول). المزامنة محتاجاهم.

**القرار**:
- ترقية DB واحدة تضيف الأربع أعمدة (`ALTER TABLE exam_questions ADD COLUMN sync_updated_at TEXT` + `sync_remote_id TEXT`، ونفسهم لـ`exam_submissions`).
- رقم النسخة = **`DATABASE_VERSION` الحالي وقت التنفيذ + 1**. لو spec 023 نزل الأول (v26) → دي v27. لو 024 الأول → v26. التاسكات تقرأ الرقم الحالي.
- `COL_SYNC_UPDATED_AT`/`COL_SYNC_REMOTE_ID` ثوابت موجودة بالفعل في `constants.dart` (مستخدمة لباقي الجداول) — نعيد استخدامها.
- بلا CHECK constraints فمفيش تعقيد ترقية.

**البديل المرفوض**: جدول جديد بدل ALTER — يكسر كل استعلامات `exam_questions`/`exam_submissions` الموجودة.

## R3 — `exam_submissions.pulled_at`: يتزامن ولا محلي؟

**السياق**: `pulled_at` = آخر مرة **الجهاز ده** سحب التسليم ده من Firestore. معلومة خاصة بكل جهاز (جهاز A سحب الساعة 3، جهاز B ما سحبش خالص لكن استلم عبر المزامنة).

**القرار**: **محلي لكل جهاز — ما يتزامنش**. مش في `_buildRemoteRow` ولا `_toLocalMap`. الجهاز اللي بيستقبل التسليم عبر المزامنة يسيب `pulled_at = null` (يعني "ما سحبتوش أنا من Firestore" — صح). لو حبّ يسحب بنفسه بعدين، يتحدّث محليًا.

## R4 — حقول الأونلاين على `exams`

**السياق**: `is_online`, `online_status`, `opens_at`, `closes_at`, `duration_minutes` أعمدة على `exams` المحلي، لكن **مش في payload مزامنة `exams`** (السطور 344–352 في `sync_engine.dart`: `name, exam_date, report_month, max_grade, passing_grade` بس). يعني المساعد ما بيشوفش الامتحان كـ"أونلاين" أصلًا.

**القرار**: نضيفهم لنفس payload مزامنة `exams` الموجود (`_buildRemoteRow(TABLE_EXAMS)` + `_toLocalMap(TABLE_EXAMS)`) + أعمدة مقابلة على جدول `exams` البعيد (`ALTER TABLE public.exams ADD COLUMN ...`). `online_status` نص، `is_online` boolean (نمط `is_absent`). دوال `setExamOnlineFields`/`setExamOnlineStatus` تنادي `_queueSync(TABLE_EXAMS, examId, 'update', ...)` (دلوقتي بتحدّث الصف مباشرة بلا queue — تعليق السطر 2104 "الأعمدة دي محلية" بيتغيّر).

**الأثر**: 5 مفاتيح في payload `exams` + 5 أعمدة SQL + `_queueSync` في دالتين.

## R5 — dedup للـ`exam_submissions` الواردة

**السياق**: `exam_submissions` عندها `UNIQUE(exam_id, student_id)` محلي. لو المدرس والمساعد الاتنين سحبوا نفس التسليم من Firestore قبل تبادل المزامنة، كل واحد عمل صف محلي بـ`remote_id` مختلف → لما يتبادلوا، `db.insert` يفشل بـUNIQUE.

**القرار**: نفس نمط `TABLE_EXAM_GRADES` في `_applyRemoteRow` (السطور 819–832): قبل `_insertWithCodeRetry`، فحص `db.query(exam_submissions WHERE exam_id=? AND student_id=?)` — لو موجود، تجاهل الصف الوارد بهدوء (`debugPrint` + `return`). الصف الموجود هيتحدّث في دورة لاحقة عبر مسار `existing by remote_id` أو يفضل زي ما هو (آخر تعديل يفوز).

**ملاحظة**: التصادم ده نادر (لازم الجهازين يسحبوا نفس الامتحان قبل أول مزامنة بينهم). المسار الطبيعي: جهاز واحد يسحب، الباقي يستلم.

## R6 — مين بيصحّح تلقائيًا؟

**القرار**: الجهاز اللي بيسحب من Firestore (`pullAndGradeOnlineExam`) هو اللي بيصحّح ويحسب `auto_score`. `auto_score` بيتزامن مع التسليم فالجهاز التاني ما بيعيدش الحساب (ولا محتاج — عنده الأسئلة عبر US1 بس مش محتاجها للعرض). `pullAndGradeOnlineExam` يفضل إجراء يبدأه المستخدم (زرار "سحب التسليمات") — أي جهاز في الفريq يقدر ينفّذه (نفس رابط الترخيص)، لكن جهاز واحد يكفي.

## R7 — FR-016: تنظيف طابور الدفع

**السياق**: اتعمل كإصلاح عاجل في جلسة 2026-09-05 (commit `3c3e0b2`): `_drainOutbox` بيمسح صف الطابور لأي جدول مش في `_tables`.

**القرار**: يتثبّت كجزء من الميزة + سيناريو quickstart. صفر كود جديد (موجود) — بس تأكيد إنه مغطّى باختبار/تحقّق.

## R8 — `_refreshUiForTable` للجدولين

**القرار**:
- `TABLE_EXAM_QUESTIONS` → `ExamController.loadExams()` (زي `TABLE_EXAMS`/`TABLE_EXAM_GRADES`).
- `TABLE_EXAM_SUBMISSIONS` → `ExamController.loadExams()` + (لو شاشة `OnlineExamResultsPage` مفتوحة) إعادة تحميلها. أبسط: نفس `loadExams()` والشاشة بتعيد القراءة عند العودة/التحديث اليدوي؛ تحسين اختياري: بثّ حدث تسمعه الشاشة.

## R9 — نشر الـmigration: خطوة موثّقة

**القرار** ([contracts/supabase-migration.md](contracts/supabase-migration.md)):
- ملف `supabase/migration_online_exam_sync.sql` بترويسة تعليق واضحة (زي `migration_exams.sql`): "شغّله مرة واحدة على SQL Editor في لوحة Supabase قبل توزيع نسخة التطبيق اللي فيها الميزة".
- README قصير أو سطر في الملف: "الميزة (مزامنة أسئلة/تسليمات الامتحان الإلكتروني) معطّلة وظيفيًا حتى تشغيل الملف ده — لكن **مش هتكسر** مزامنة الواجب/الدرجات لو ماتشغّلش (قناة Realtime منفصلة، R1)".
- التاسكات تضيف الجدولين لـ`_tables` **في نفس PR** مع تحسين R1 — آمن لأن الجدول الناقص دلوقتي معزول.

## ملخص القرارات

| # | القرار |
|---|---|
| R1 | قناتان Realtime: `team-$id` (أساسية) + `team-$id-x` (ممتدة: exam_questions/exam_submissions) |
| R2 | ترقية DB واحدة تضيف `sync_updated_at`+`sync_remote_id` للجدولين؛ الرقم = الحالي+1 |
| R3 | `pulled_at` محلي لكل جهاز — ما يتزامنش |
| R4 | حقول الأونلاين تنضم لـpayload مزامنة `exams` الموجود + 5 أعمدة SQL |
| R5 | dedup `exam_submissions` الواردة على `UNIQUE(exam_id,student_id)` — نمط `exam_grades` |
| R6 | التصحيح التلقائي على جهاز السحب فقط؛ `auto_score` يتزامن |
| R7 | FR-016 (تنظيف الطابور) اتعمل عاجل — يتثبّت + يتغطّى بتحقّق |
| R8 | `_refreshUiForTable` للجدولين → `ExamController.loadExams()` |
| R9 | `migration_online_exam_sync.sql` بترويسة نشر صريحة؛ يُضاف لـ`_tables` بأمان بفضل R1 |

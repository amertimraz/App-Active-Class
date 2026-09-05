# Implementation Plan: مزامنة الامتحانات الإلكترونية عبر وضع الفريق

**Branch**: `024-online-exam-team-sync` | **Date**: 2026-09-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/024-online-exam-team-sync/spec.md`

## Summary

نخلّي المساعد يقدر يشغّل الامتحانات الإلكترونية اللي المدرس عملها:

1. **US1 (P1)** — مزامنة `exam_questions` + حقول "أونلاين" على `exams` (`is_online`, `online_status`, `opens_at`, `closes_at`, `duration_minutes`) عبر الفريق، بنفس نمط `exam_grades`.
2. **US2 (P1)** — مزامنة `exam_submissions` (إجابات/درجة تلقائية/نهائية/حالة/auto_submitted) عبر الفريق؛ آخر تعديل يفوز؛ حالة `voided` محترمة.
3. **US3 (P2)** — مرونة المزامنة: قناتان Realtime (أساسية + ممتدة) عشان فشل جدول ناقص ما يكسرش القناة كلها؛ تثبيت إصلاح تنظيف طابور الدفع (FR-016، اتعمل عاجل commit `3c3e0b2`)؛ توثيق نشر migration صريح.

**تبعية DB**: عمودَي مزامنة (`sync_updated_at`, `sync_remote_id`) لازم يتضافوا لـ`exam_questions` و`exam_submissions` (دلوقتي محليان بالكامل بلا أعمدة مزامنة) → ترقية `DATABASE_VERSION`.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX، sqflite (rollback-journal)، `supabase_flutter` (وضع الفريق)، `cloud_firestore` (الامتحان الإلكتروني — بلا تغيير هنا). صفر تبعيات جديدة.

**Storage**:
- SQLite: `exam_questions` و`exam_submissions` يكسبوا `COL_SYNC_UPDATED_AT` + `COL_SYNC_REMOTE_ID` (نمط باقي الجداول المتزامنة). ترقية `DATABASE_VERSION` (v26→v27 لو spec 023 نزل الأول، وإلا v25→v26 — التاسكات تستخدم `الحالي + 1`).
- Supabase: `migration_online_exam_sync.sql` جديد — جدولين `exam_questions`/`exam_submissions` + أعمدة أونلاين على `exams` الموجود + RLS (`is_team_member` + `is_team_license_active`) + soft-delete trigger (صلاحية `delete_attendance` زي `migration_exams.sql`) + إضافة للـ`supabase_realtime` publication. **لازم يتنفّذ يدويًا على السيرفر قبل ما الميزة تشتغل** (بس مش هيكسر المزامنة الأساسية لو ماتنفّذش — بفضل US3).
- Firestore: **بلا تغيير**. `ExamQuestion.toCloudMap()` يفضل بلا `correctIndex`/`points`/`explanation` (spec 016 FR-034).

**Testing**: `flutter test` — وحدات للـmapping لو أمكن؛ تحقّق يدوي عبر quickstart بجهازين (الأساسي هنا).

**Target Platform**: Android (جهاز مدرس + جهاز مساعد على نفس الترخيص/الفريq).

**Project Type**: Mobile single-project (`lib/`) + ملفات SQL في `supabase/`.

**Constraints**:
- **أمني**: `correctIndex`/`points`/`explanation` يُسمح لهم في جدول `exam_questions` بتاع الفريq في Supabase (محميّ بـRLS، أجهزة نفس الترخيص، زي `exam_grades`). **ممنوع** في مستند Firestore العام — `toCloudMap` بلا تغيير، واختبار يفرض ذلك.
- **مرونة**: جدول ناقص على الخادم أو فشل اشتراك جدول واحد MUST ما يعطّلش بثّ باقي الجداول ولا `catchUpPull`.
- كل كتابات Supabase best-effort في مسار الـpush (نمط `_drainOutbox` الحالي).
- آخر-تعديل-يفوز كافٍ للتعارض (بلا أقفال/دمج).

**Scale/Scope**: عشرات–مئات أسئلة/تسليمات لكل فريq — بلا قلق أداء. ~2 ملف جديد (SQL + ربما موديل mapping)، ~4 ملفات معدّلة.

## Constitution Check

`.specify/memory/constitution.md` قالب فارغ — تُطبَّق أعراف المشروع:

| العُرف | الالتزام |
|---|---|
| مزامنة جدول جديد = نمط `exam_grades` بالحرف (`_tables` + `_buildRemoteRow` + `_toLocalMap` + `_pkCol` + `_refreshUiForTable` + SQL migration + publication) | ✅ |
| ترقية DB تدريجية `ALTER TABLE ADD COLUMN` | ✅ (أعمدة المزامنة) |
| RLS = `is_team_member` + `is_team_license_active`؛ حذف = soft-delete + صلاحية `delete_attendance` | ✅ (نسخ `migration_exams.sql`) |
| مفاتيح التصحيح بره مستند Firestore العام | ✅ بلا تغيير + اختبار |
| صفر تبعيات جديدة | ✅ |
| **درس `student_follow_ups`**: migration قبل التفعيل + عزل فشل الجدول | ✅ US3 صراحة |

**النتيجة**: PASS. `Complexity Tracking` غير مطلوب.

## Project Structure

### Documentation (this feature)

```text
specs/024-online-exam-team-sync/
├── plan.md
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1 — تحقّق بجهازين
├── contracts/           # Phase 1
│   ├── sync-exam-questions.md
│   ├── sync-exam-submissions.md
│   ├── realtime-resilience.md
│   └── supabase-migration.md
├── checklists/
│   └── requirements.md  # موجود
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart              # [M] DATABASE_VERSION +1
├── services/
│   ├── database_service.dart       # [M] أعمدة sync على exam_questions/exam_submissions + migration؛
│   │                               #     _queueSync/_queueDelete في insertQuestion/updateQuestion/deleteQuestion
│   │                               #     + مسارات كتابة exam_submissions (updateSubmissionApproval,
│   │                               #     voidSubmissionLocally, كتابة pullAndGradeOnlineExam)؛
│   │                               #     + payload مزامنة exams يشمل حقول الأونلاين (setExamOnlineFields/Status)
│   └── sync_engine.dart            # [M] _tables (+ exam_questions بعد exams، + exam_submissions بعد exams/students)؛
│                                   #     _pkCol / _buildRemoteRow / _toLocalMap / _refreshUiForTable cases؛
│                                   #     _buildRemoteRow(exams) + _toLocalMap(exams) يشملوا حقول الأونلاين؛
│                                   #     _subscribeRealtime → قناتان (أساسية + ممتدة)؛
│                                   #     dedup على exam_submissions UNIQUE(exam_id,student_id)؛
│                                   #     _fullPull: تخطّي جدول راجع خطأ "relation does not exist" بهدوء (موجود جزئيًا)
├── controllers/
│   └── exam_controller.dart        # [M] (لو لزم) reload شاشة النتائج المفتوحة عند وصول submission متزامن
└── views/exams/
    └── online_exams_tab.dart       # [M] (لو لزم) عرض حالة "الأسئلة لسه بتتزامن" لو exam.isOnline بلا أسئلة محليًا

supabase/
└── migration_online_exam_sync.sql  # [NEW] — نسخة من نمط migration_exams.sql

test/
└── exam_question_cloud_map_test.dart  # [NEW أو مشترك مع spec 023] — toCloudMap بلا مفاتيح تصحيح
```

**Structure Decision**: Mobile single-project قائم. صفر شاشات جديدة — كله في طبقة المزامنة + DB. ملف SQL واحد جديد. التغيير الأكبر في `sync_engine.dart` (نمط متكرر معروف) و`database_service.dart` (إضافة `_queueSync` لدوال موجودة).

## Phase 0 — Research

انظر [research.md](research.md). أسئلة محسومة:
- شكل مرونة Realtime (قناة واحدة مقاومة أم قناتان أم قناة لكل جدول).
- أعمدة المزامنة على الجدولين المحليين — ترقية DB مشتركة أم منفصلة عن spec 023.
- `exam_submissions.pulled_at` — يتزامن ولا محلي لكل جهاز.
- حقول الأونلاين على `exams` — تنضم لنفس payload المزامنة الموجود.
- dedup للـ`exam_submissions` الواردة (UNIQUE محلي).
- تنسيق ترقية DB مع spec 023 (اللي بيضيف `explanation`).

## Phase 1 — Design & Contracts

- [data-model.md](data-model.md) — سكيمة `exam_questions`/`exam_submissions` البعيدة، أعمدة الأونلاين على `exams`، أعمدة المزامنة المحلية، ترقية DB.
- [contracts/](contracts/) — ٤ عقود.
- [quickstart.md](quickstart.md) — سيناريوهات تحقّق بجهازين + محاكاة الجدول الناقص.

## Complexity Tracking

لا انتهاكات.

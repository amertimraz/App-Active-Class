# Implementation Plan: بنك الأسئلة + نسخ/قوالب الامتحان

**Branch**: `025-question-bank-exam-templates` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/025-question-bank-exam-templates/spec.md`

## Summary

1. **US1 (P1)** — جدول `bank_questions` (محتوى سؤال الامتحان + `subject` + `tags`) + شاشة `QuestionBankPage` (تصفّح/بحث/فلترة/CRUD) + `QuestionBankController`. متزامن عبر الفريق بنمط spec 024 (القناة الممتدة).
2. **US2 (P1)** — "أضف من البنك" في `online_exam_editor_page` (فردي بـcheckbox أو N عشوائي من مادة/وسم) → نسخ مستقلة كـ`_QDraft`؛ "احفظ في البنك" لسؤال / للكل.
3. **US3 (P2)** — `ExamController.duplicateExam(examId)` → مسودّة جديدة "(نسخة)" بنفس الأسئلة/المدة/الدرجات، بلا مجموعات/مواعيد/تسليمات/نشر. زر في `online_exams_tab`.

**تبعية DB**: ترقية `DATABASE_VERSION` (27 → 28) — جدول `bank_questions` جديد (بأعمدة مزامنة من البداية).

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX، sqflite، `supabase_flutter` (مزامنة الفريق). صفر تبعيات جديدة.

**Storage**:
- SQLite: جدول جديد `bank_questions` (id, type, text, options JSON, correct_index, points, image_url, explanation, subject, tags, created_at, `sync_updated_at`, `sync_remote_id`). ترقية v27→v28 — جدول جديد بالكامل، صفر ALTER على جداول موجودة.
- Supabase: `migration_question_bank.sql` جديد — جدول `bank_questions` + RLS (`is_team_member` + `is_team_license_active`) + soft-delete trigger (يعيد استخدام `check_delete_exams`) + إضافة للـ`supabase_realtime` publication. **يُطبَّق عبر SSH لحاوية `active-class-auth-db-1`** (نمط spec 024 T029)، مش خطوة لوحة تحكم.
- Firestore: **بلا تغيير**. الأسئلة المنسوخة من البنك لامتحان منشور تمرّ بـ`ExamQuestion.toCloudMap()` (بلا `correctIndex`/`points`/`explanation`).

**Testing**: `flutter test` — وحدات لمنطق "أضف N عشوائي" (اختيار بلا تكرار، N > المتاح) ولنسخ الامتحان (ما يُنسخ وما لا يُنسخ). تحقّق يدوي عبر quickstart.

**Target Platform**: Android (تطبيق المدرس + المساعد على نفس الفريق).

**Project Type**: Mobile single-project (`lib/`) + ملف SQL في `supabase/`.

**Constraints**:
- **أمني**: `correct_index`/`points`/`explanation` مسموحين في `bank_questions` على SQLite وفي جدول الفريq على Supabase (RLS) — **ممنوعين** في مستند Firestore العام. النسخ من البنك لامتحان = نسخ لصف `exam_questions` عادي؛ النشر يمرّ بـ`toCloudMap` كالمعتاد. اختبار spec 023/024 (`exam_question_cloud_map_test`) يظل يفرض ذلك.
- المزامنة: `bank_questions` على القناة الممتدة (`_extendedTables`) — فشل جدول ناقص على الخادم لا يكسر القناة الأساسية.
- محرّر سؤال البنك = **نفس مكوّن تحرير السؤال** (يُستخرج كـwidget مشترك من `online_exam_editor_page`).

**Scale/Scope**: عشرات–مئات أسئلة بنك لكل فريق. ~4 ملفات جديدة، ~5 معدّلة، ملف SQL واحد.

## Constitution Check

`.specify/memory/constitution.md` قالب فارغ — تُطبَّق أعراف المشروع:

| العُرف | الالتزام |
|---|---|
| مزامنة جدول جديد = نمط `exam_questions` (spec 024) بالحرف | ✅ |
| ترقية DB تدريجية (جدول جديد، لا ALTER مدمّر) | ✅ v27→v28 |
| RLS = `is_team_member` + `is_team_license_active`؛ حذف = soft-delete + `check_delete_exams` | ✅ |
| مفاتيح التصحيح بره مستند Firestore العام | ✅ بلا تغيير + اختبار قائم |
| القناة الممتدة للجداول الجديدة (درس CHANNEL_ERROR) | ✅ `bank_questions` في `_extendedTables` |
| هجرة Supabase عبر SSH (spec 024) مش يدوي | ✅ |
| صفر تبعيات جديدة | ✅ |

**النتيجة**: PASS. `Complexity Tracking` غير مطلوب.

## Project Structure

### Documentation (this feature)

```text
specs/025-question-bank-exam-templates/
├── plan.md
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/           # Phase 1
│   ├── bank-question-model-db.md
│   ├── bank-sync.md
│   ├── editor-integration.md
│   └── exam-duplicate.md
├── checklists/
│   └── requirements.md  # موجود
└── tasks.md             # Phase 2
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart              # [M] DATABASE_VERSION 28؛ TABLE_BANK_QUESTIONS + COL_BQ_*؛ ROUTE_QUESTION_BANK
├── models/
│   ├── bank_question_model.dart    # [NEW] BankQuestion + toExamQuestion(examId, position) + fromExamQuestion
│   └── exam_question_model.dart    # [—] بلا تغيير (يُقرأ فقط)
├── services/
│   ├── database_service.dart       # [M] _bankQuestionsTableSql + migration v28؛ CRUD (insert/update/delete/query
│   │                               #     مع فلاتر subject/tag/بحث) + _queueRowUpsert للمزامنة؛ distinctSubjects/distinctTags
│   └── sync_engine.dart            # [M] TABLE_BANK_QUESTIONS في _tables + _extendedTables؛
│                                   #     _pkCol / _buildRemoteRow / _toLocalMap / _refreshUiForTable cases
├── controllers/
│   └── question_bank_controller.dart  # [NEW] GetxController — RxList<BankQuestion>، فلاتر (subjectFilter/tagFilter/query)،
│                                      #       refresh/add/update/remove، subjects/tags getters
├── views/
│   ├── question_bank/
│   │   ├── question_bank_page.dart       # [NEW] تصفّح/بحث/فلترة/CRUD
│   │   └── question_bank_picker_page.dart# [NEW] اختيار متعدد + "أضف N عشوائي" — يرجّع List<BankQuestion>
│   ├── exams/
│   │   ├── question_editor.dart          # [NEW] widget تحرير سؤال مشترك (يُستخرج من online_exam_editor_page)
│   │   ├── online_exam_editor_page.dart  # [M] يستخدم QuestionEditor؛ زر "أضف من البنك"؛ "احفظ في البنك" (سؤال/الكل)
│   │   └── online_exams_tab.dart         # [M] زر "نسخة جديدة" في _actions
│   └── home_page.dart              # [M] _DrawerItem "بنك الأسئلة"
├── main.dart                       # [M] GetPage لـ ROUTE_QUESTION_BANK

supabase/
└── migration_question_bank.sql     # [NEW] نمط migration_online_exam_sync.sql

test/
├── question_bank_random_test.dart  # [NEW] "أضف N عشوائي" — بلا تكرار، N > المتاح، نطاق فارغ
└── exam_duplicate_test.dart        # [NEW] ما يُنسخ / ما لا يُنسخ (منطق نقي إن أمكن، وإلا يُدمج في quickstart)
```

**Structure Decision**: Mobile single-project قائم. مجلد جديد `lib/views/question_bank/`. استخراج `QuestionEditor` widget مشترك (يقلّل تكرار ~150 سطر بين محرّر الامتحان وشاشة البنك). باقي التغييرات حقن في ملفات موجودة + نمط مزامنة spec 024 المتكرر.

## Phase 0 — Research

انظر [research.md](research.md). أسئلة محسومة:
- استخراج `QuestionEditor` widget مشترك أم تكرار مبسّط.
- `BankQuestion` صنف مستقل أم امتداد لـ`ExamQuestion`.
- تخزين `tags` (JSON list في عمود واحد) + آلية الفلترة.
- المادة: حقل حر + autocomplete من `SELECT DISTINCT`.
- "أضف N عشوائي": أين يتم الاختيار (Dart بعد جلب النطاق).
- "نسخة جديدة" للامتحان الورقي: متاح أم إلكتروني فقط.
- قسم قوالب منفصل أم "تكرار" فقط (الحسم: "تكرار" فقط في v1).
- تنسيق ترقية DB مع الوضع الحالي (v27 بعد spec 024).

## Phase 1 — Design & Contracts

- [data-model.md](data-model.md) — سكيمة `bank_questions` (محلي + Supabase)، `BankQuestion`، ترقية v28، ما يُنسخ في `duplicateExam`.
- [contracts/](contracts/) — ٤ عقود.
- [quickstart.md](quickstart.md) — سيناريوهات تحقّق (بنك، إضافة للمحرّر، تكرار، مزامنة بجهازين، فحص Firestore).

## Complexity Tracking

لا انتهاكات.

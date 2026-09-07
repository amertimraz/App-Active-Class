# Implementation Plan: حذف السجلات بمدى تواريخ مع تحكّم كامل في نوع السجلات

**Branch**: `028-delete-records-by-date-range` | **Date**: 2026-09-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/028-delete-records-by-date-range/spec.md`

## Summary

شاشة جديدة في الإعدادات (`DeleteRecordsPage`) تسمح للمدرّس باختيار مدى تواريخ (من/إلى شامل) ومجموعة أنواع سجلّات (حضور، دفعات، درجات، امتحانات، واجبات، سجلّات تقارير)، تعرض معاينة بالأعداد الفعلية، تُنشئ نسخة احتياطية كاملة إجبارية، تطلب تأكيدًا (بكتابة كلمة للكميات > 100)، ثم تحذف الصفوف المطابقة في transaction واحدة. في وضع الفريق: كل صف محذوف من نوع مُزامَن يُدخَل في `sync_outbox` كـ `delete` مع `remote_id` — فالحذف ينتشر لكل الفريق في الاتجاهين عبر آلية `SyncEngine` القائمة بلا كود جديد. `report_logs` (غير مُزامَن) يُحذف محليًا فقط. صفر تغيير DB schema (v28)، صفر مكتبات جديدة.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX، sqflite (`db.transaction`)، `BackupService().createBackup()` القائم، `SyncEngine` + `sync_outbox` + `_queueDelete` القائمة. `intl` للتواريخ. لا مكتبات جديدة.

**Storage**: sqflite المحلي. DB version يبقى **28**. لا جداول/أعمدة جديدة. جداول متأثّرة (حذف صفوف فقط): `attendance`, `payments`, `exam_grades`, `exams` (+ توابعها `exam_groups`/`exam_questions`/`exam_submissions`), `homework`, `report_logs`.

**Testing**: `flutter test` — وحدة لمنطق فلترة المدى/النوع وحساب المعاينة (دوال `DatabaseService` جديدة قابلة للاختبار بقاعدة in-memory أو منطق تواريخ منعزل).

**Target Platform**: Android (وأي منصة).

**Project Type**: تطبيق موبايل Flutter (هيكل `lib/` مفرد).

**Performance Goals**: المعاينة = `SELECT COUNT` لكل نوع ضمن المدى (سريع). الحذف = `DELETE ... WHERE date BETWEEN` لكل نوع داخل transaction واحدة + إدراج صفوف outbox (لكل صف محذوف، في وضع الفريق فقط). حذف بضع آلاف صف مقبول (< بضع ثوانٍ).

**Constraints**: نسخة احتياطية إجبارية قبل الحذف؛ فشلها → إلغاء كامل. الحذف ذرّي (transaction). لا حذف روستر (طلاب/مجموعات) تحت أي حال. لا تغيير DB schema/مزامنة (بروتوكول). منفصل تمامًا عن `deleteAllData()` القائم.

**Scale/Scope**: 1 شاشة جديدة + 1 controller/state · 1 enum · ~3 دوال `DatabaseService` جديدة (count، delete range) · 1 سطر دخول في شاشة الإعدادات · ~1 ملف اختبار. صفر تعديل في `SyncEngine`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

الدستور `.specify/memory/constitution.md` قالب فارغ. أعراف المشروع:

| عرف | الحالة |
|---|---|
| صفر تغيير DB schema إلا بترقية صريحة | ✅ PASS — حذف صفوف فقط |
| صفر تغيير في بروتوكول المزامنة | ✅ PASS — يعيد استخدام `_queueDelete`/`sync_outbox` كما هي |
| لا مكتبات جديدة | ✅ PASS |
| إعادة استخدام: نسخ احتياطي، حذف الامتحان، transactions | ✅ PASS |
| عملية حذف بيانات = لا رجعة → نسخة احتياطية + تأكيد صريح | ✅ مبني في التصميم (FR-006/007) |
| اختبارات + `flutter analyze` نظيف | ✅ مخطّط |
| git push بإذن؛ commit على `main` | ✅ ملحوظ |

**النتيجة: PASS** — لا انتهاكات، لا Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/028-delete-records-by-date-range/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — 7 قرارات محسومة
├── data-model.md        # Phase 1 — أنواع السجلّات + أعمدة التاريخ، لا سكيمة
├── quickstart.md        # Phase 1 — سيناريوهات تحقّق
├── contracts/
│   ├── delete-records-service.md   # عقد دوال DatabaseService (count + delete range)
│   └── delete-records-screen.md    # عقد الشاشة + تدفّق الأمان
└── tasks.md             # Phase 2 — /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── models/
│   └── deletable_record_type.dart   # جديد — enum + labels + أعمدة التاريخ/الجداول
├── services/
│   └── database_service.dart        # + countDeletableRecordsInRange(...) + deleteRecordsInRange(...)
├── controllers/
│   └── delete_records_controller.dart  # جديد — GetxController: المدى، الأنواع المختارة، المعاينة، التنفيذ
├── views/
│   └── settings/
│       ├── delete_records_page.dart  # جديد — الشاشة (تواريخ + checkboxes + معاينة + تأكيد)
│       └── settings_page.dart        # + سطر دخول "حذف سجلّات بمدى تواريخ"

test/
└── delete_records_range_test.dart    # جديد — منطق الفلترة/المعاينة + قواعد التأكيد
```

**Structure Decision**: هيكل Flutter المفرد. المنطق الثقيل (فلترة/حذف بمدى) في `DatabaseService` بجوار `deleteAllData` و`deleteExam`. الشاشة + الحالة في `views/settings/` و`controllers/`. الـenum في `models/` عشان تُشارَك بين الطبقات. صفر لمس لـ`SyncEngine` — `_queueDelete` القائمة تكفي.

## Complexity Tracking

> لا انتهاكات — لا شيء يُبرَّر.

# Implementation Plan: دعم ربط 3 إخوة بخصم مشترك

**Branch**: `007-three-sibling-support` | **Date**: 2026-08-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/007-three-sibling-support/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

استبدال مفهوم "الربط الثنائي المباشر" الحالي (`siblingId` يشير لطالب واحد) بمفهوم **مجموعة إخوة مشتركة** (`siblingGroupId` — عمود جديد، قيمته اختيارية = نفس القيمة لكل الأعضاء 2 أو 3، عمليًا نستخدم أصغر `id` بين الأعضاء كقيمة المجموعة تجنبًا لجدول جديد). كل مكان في الكود بيفترض حاليًا "أخ واحد" (`getStudent(student.siblingId!)`) يتحول لـ"كل أعضاء المجموعة عدا الطالب نفسه" (`getStudentsInSiblingGroup(groupId, excludeId)`). القسمة الثابتة `/2.0` في `pricing_helper.dart` و`qr_controller.dart` تتحول لقسمة على `عدد الأعضاء الفعلي`. Migration تلقائي (DB v17→18) يحوّل أزواج `siblingId` الحالية لقيمة `siblingGroupId` مشتركة من غير أي تدخل من المدرس.

## Technical Context

**Language/Version**: Dart 3 / Flutter (نفس إصدار المشروع الحالي)

**Primary Dependencies**: لا مكتبات جديدة — `sqflite` الموجودة بالفعل لتنفيذ الـmigration.

**Storage**: SQLite (sqflite) — migration من `DATABASE_VERSION = 17` إلى `18`: إضافة عمود `sibling_group_id INTEGER` جديد (nullable) لجدول `students`، بجانب `sibling_id`/`siblings_total` الحاليين (نُبقيهما مؤقتًا لتوافق خلفي أثناء الانتقال، أو نحذفهما حسب قرار التنفيذ في research.md).

**Testing**: لا يوجد إطار اختبارات آلي مُفعَّل حاليًا لهذا الجزء من المشروع — تحقق يدوي/على الجهاز، مع تركيز خاص على اختبار الـmigration على قاعدة بيانات فيها أزواج إخوة حقيقية موجودة بالفعل (لا تراجع FR مسموح).

**Target Platform**: Android (تطبيق Flutter، فلافورز `play`/`direct`)

**Project Type**: mobile-app (Flutter/GetX) — تعديل في الطبقات الثلاث (Model → Service → Controller/UI) لميزة موجودة، لا شاشات جديدة كليًا (تعديل شاشات موجودة).

**Performance Goals**: استعلام "كل أعضاء مجموعة الإخوة" بحد أقصى 3 صفوف — بلا أثر أداء ملحوظ.

**Constraints**: التوافق الخلفي إلزامي (FR الأخير في spec.md) — أي مجموعة أخوين (2) موجودة حاليًا في قواعد بيانات المدرسين يجب أن تستمر تعمل بلا أي تدخل يدوي بعد التحديث؛ الحد الأقصى لحجم المجموعة = 3 بالضبط (مش قابل للتوسعة في نطاق هذه الميزة)؛ يجب عدم كسر مسارات: مجموعات "بالحصة"، "الإعفاء الكامل"، أرشفة طالب عضو في مجموعة إخوة.

**Scale/Scope**: تعديل 6 ملفات معروفة بالضبط (مؤكَّدة عبر grep قبل التخطيط): `student_model.dart`، `database_service.dart` (migration + linkSiblings + query جديد)، `student_controller.dart` (linkSiblings)، `pricing_helper.dart` (القسمة)، `qr_controller.dart` (تقسيم الدفع)، `add_student_sheet.dart`/`edit_student_sheet.dart` (اختيار حتى عضوين إضافيين بدل واحد).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

لا يوجد ملف دستور (`constitution.md`) مُعبَّأ لهذا المشروع — لا توجد بوابات حوكمة إضافية واجبة التطبيق. المرجع الوحيد هو نمط الـmigrations الموجود بالفعل (`DATABASE_VERSION`/`_onUpgrade` في `database_service.dart`، نفس الأسلوب المستخدم في ميزة الأرشفة السابقة `specs/002-student-archiving`).

## Project Structure

### Documentation (this feature)

```text
specs/007-three-sibling-support/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

لا يوجد `contracts/` لهذه الميزة — لا واجهة خارجية (API/CLI)، تعديل داخلي في تطبيق موبايل واحد.

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart              # DATABASE_VERSION 17 → 18، عمود جديد COL_STUDENT_SIBLING_GROUP_ID
├── models/
│   └── student_model.dart          # إضافة siblingGroupId (nullable int)
├── services/
│   └── database_service.dart       # migration v18، linkSiblings يقبل قائمة (2-3)،
│                                     # getStudentsInSiblingGroup(groupId, excludeId)
├── controllers/
│   └── student_controller.dart     # linkSiblings مُحدَّثة لتتعامل مع مجموعة بدل زوج
├── utils/
│   └── pricing_helper.dart         # القسمة على عدد أعضاء المجموعة الفعلي بدل /2.0 ثابتة
├── controllers/
│   └── qr_controller.dart          # تقسيم الدفع على كل أعضاء المجموعة (2 أو 3)
└── widgets/
    ├── add_student_sheet.dart      # اختيار حتى عضوين إضافيين (بدل واحد) + عرض كل الأعضاء
    └── edit_student_sheet.dart     # نفس التعديل
```

**Structure Decision**: مشروع Flutter موحّد واحد (mobile-app) — لا خيارات هيكل بديلة. كل التعديلات في الملفات المذكورة أعلاه، الستة المؤكَّدة بالفعل بأنها تحتوي منطق "الأخوين" الحالي (عبر `grep` قبل التخطيط)، بالإضافة لملف الثوابت (`constants.dart`) لعمود قاعدة البيانات الجديد.

## Complexity Tracking

> لا توجد انتهاكات لبوابة الدستور تستوجب تبريرًا — لا يوجد ملف دستور مُعبَّأ. التعقيد الوحيد المُبرَّر هنا هو الـmigration نفسه (v17→18)، وهو أمر لازم لأي تغيير في مخطط قاعدة بيانات SQLite، ونفس النمط مُستخدم بالفعل في الميزات السابقة (002-student-archiving).

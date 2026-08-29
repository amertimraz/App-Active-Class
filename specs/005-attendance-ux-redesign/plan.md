# Implementation Plan: إعادة هيكلة شاشة تسجيل الحضور

**Branch**: `005-attendance-ux-redesign` | **Date**: 2026-08-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-attendance-ux-redesign/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

**تحديث (إعادة تخطيط بعد أول تجربة على الجهاز)**: التنفيذ الأول (بحث + تمييز بصري + شريط قفز، كل حاجة داخل صفحة واحدة طويلة) اتبنى واتحقق منه (`flutter analyze` نظيف)، لكن بعد رؤيته على الجهاز طلب المستخدم إعادة هيكلة أعمق. الخطة الجديدة: تبويب "تسجيل" في [attendance_page.dart](../../lib/views/attendance/attendance_page.dart) يعرض شبكة بطاقات مختصرة (بطاقة واحدة لكل مجموعة ليها حصة اليوم — اسم، ميعاد، إحصائية) بدل القائمة الطويلة المفرودة. الضغط على كارت يفتح موديل (`showDialog` + `Dialog` + `ConstrainedBox`، **نفس النمط المستخدم بالفعل** في [add_student_sheet.dart](../../lib/widgets/add_student_sheet.dart)/[edit_student_sheet.dart](../../lib/widgets/edit_student_sheet.dart) — راجع القرار الموثّق في research.md) فيه تفاصيل تسجيل حضور المجموعة دي بس: البحث بالاسم (من التكرار الأول)، التمييز البصري لـ`_StudentAttendanceChip` (من التكرار الأول، بلا تغيير)، تحضير الكل، واجب الكل، شريط التقدّم، وزر إرسال تقرير واتساب. شريط "القفز بين المجموعات" من التكرار الأول أُزيل لأنه أصبح غير لازم — شبكة البطاقات نفسها هي وسيلة الوصول المباشر. كل الوظائف الحالية تبقى كما هي، منقولة لسياقها الجديد داخل الموديل.

## Technical Context

**Language/Version**: Dart 3 / Flutter (نفس إصدار المشروع الحالي)

**Primary Dependencies**: Flutter Material widgets فقط — إعادة استخدام `CustomSearchBar` الموجود بالفعل في [lib/widgets/custom_widgets.dart](../../lib/widgets/custom_widgets.dart) بدل إنشاء ودجت بحث جديدة؛ لا مكتبات جديدة.

**Storage**: لا شيء — قراءة فقط من بيانات `Attendance`/`Student`/`Group` المحمّلة بالفعل في `AttendanceController`/`StudentController`/`GroupController` (لا تغيير في قاعدة البيانات).

**Testing**: لا يوجد إطار اختبارات آلي مُفعَّل حاليًا لهذا الجزء من المشروع — تحقق يدوي/على الجهاز، اتساقًا مع بقية المستودع (نفس نمط ميزتَي 003 و004).

**Target Platform**: Android (تطبيق Flutter، فلافورز `play`/`direct`)

**Project Type**: mobile-app (Flutter/GetX) — تعديل داخل شاشة موجودة، لا مشروع أو هيكل جديد

**Performance Goals**: التمرير والبحث يجب أن يفضلوا سلسين (60fps) حتى مع مجموعة من 40+ طالب أو يوم فيه 5+ مجموعات (SC-005) — التصفية بالاسم محلية بالكامل على قوائم محمّلة بالفعل في الذاكرة، بدون أي طلب شبكة أو قاعدة بيانات إضافي

**Constraints**: عدم كسر أي وظيفة موجودة (FR-007)؛ لا تغيير في منطق `toggleAttendance`/`markGroupAllPresent`/حساب الإحصائيات؛ التعديل محصور في طبقة العرض (Widgets) فقط داخل `attendance_page.dart`؛ الموديل يجب يستخدم نفس نمط `Dialog`+`ConstrainedBox` (minWidth/maxWidth=92%، maxHeight=85%) الموجود بالفعل بدل نمط جديد

**Scale/Scope**: إعادة هيكلة `_RegisterTab` (تبسيط — إزالة حالة البحث/القفز اللي بقت غير لازمة هنا)، استبدال `_GroupAttendanceCard` القديمة (كانت بتعرض كل الطلاب مفرودين) بكارت مختصر جديد (`_GroupSummaryCard`) + دالة فتح موديل جديدة (`showAttendanceSheet` أو مكافئ) تحتوي محتوى تسجيل الحضور الكامل (منقول من `_GroupAttendanceCard` القديمة كما هو تقريبًا: البحث، القائمة، الأزرار). `_StudentAttendanceChip` بلا أي تعديل إضافي (خلاص اتصمم صح من التكرار الأول). لا شاشات routes جديدة — موديل فقط.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

لا يوجد ملف دستور (`constitution.md`) مُعبَّأ لهذا المشروع — لا توجد بوابات حوكمة إضافية واجبة التطبيق. المرجع الوحيد للاتساق هو الأنماط البصرية والتفاعلية الموجودة بالفعل في نفس الشاشة وباقي التطبيق (الألوان، الخطوط، أسلوب البطاقات).

## Project Structure

### Documentation (this feature)

```text
specs/005-attendance-ux-redesign/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

لا يوجد `contracts/` لهذه الميزة — لا واجهة خارجية (API/CLI)، تعديل عرض داخلي بحت.

### Source Code (repository root)

```text
lib/
├── views/
│   └── attendance/
│       └── attendance_page.dart   # كل التعديلات هنا:
│                                   #  - _RegisterTab: تبسيط — إزالة البحث/شريط القفز/GlobalKeys
│                                   #    (بقت غير لازمة)، ListView.builder يبني _GroupSummaryCard
│                                   #  - _GroupSummaryCard (جديد): كارت مختصر (اسم/ميعاد/إحصائية)
│                                   #    بديل لـ _GroupAttendanceCard القديمة، onTap يفتح الموديل
│                                   #  - _AttendanceSheet (جديد): محتوى الموديل — منقول تقريبًا
│                                   #    حرفيًا من جسم _GroupAttendanceCard القديمة (البحث، القائمة،
│                                   #    الأزرار)، ملفوف بنفس نمط Dialog+ConstrainedBox
│                                   #  - _StudentAttendanceChip: بلا تعديل (من التكرار الأول)
└── widgets/
    └── custom_widgets.dart         # بدون تعديل — CustomSearchBar الموجودة تُعاد استخدامها كما هي
```

**Structure Decision**: مشروع Flutter موحّد واحد (mobile-app) — لا خيارات هيكل بديلة. كل التعديل داخل ملف واحد موجود (`attendance_page.dart`)؛ لا ملفات جديدة، إعادة تنظيم كود داخلي بين widgets في نفس الملف.

## Complexity Tracking

> لا توجد انتهاكات لبوابة الدستور تستوجب تبريرًا — لا يوجد ملف دستور مُعبَّأ. أبسط حل ممكن: تعديلات محلية داخل نفس الملف، وإعادة استخدام widget بحث موجود بدل ودجت جديدة.

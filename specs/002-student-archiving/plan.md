# Implementation Plan: أرشفة الطلاب

**Branch**: `002-student-archiving` | **Date**: 2026-08-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-student-archiving/spec.md`

## Summary

إضافة حالة "أرشفة" (soft delete) للطالب كبديل للحذف النهائي الحالي. الطالب المؤرشف يختفي من كل الشاشات والحسابات النشطة (قوائم، حضور، دفع بالـQR، داشبورد، مديونية) بينما تفضل بياناته التاريخية (حضور، مدفوعات، درجات، واجب) محفوظة كاملة بدون حذف. تُضاف شاشة "الأرشيف" لعرض/استعادة/حذف نهائي للطلاب المؤرشفين. الحالة تتزامن مع وضع الفريق زي باقي بيانات الطالب.

النهج التقني: عمودان جديدان على جدول `students` المحلي (`is_archived`, `archived_at`) بدل جدول منفصل — نفس نمط `is_absent` الموجود بالفعل على `exam_grades`. `StudentController` بيوفّر قائمتين منفصلتين (نشطين/مؤرشفين) بدل قائمة واحدة تتفلتر، وكل شاشة "نشطة" (قوائم، حضور، QR، داشبورد) بتتحول لتستخدم القائمة النشطة بس. المزامنة بتتوسّع بنفس الأسلوب المستخدم مع الامتحانات هذه الجلسة (عمود جديد في `_buildRemoteRow`/`_toLocalMap` لجدول already-synced، مش جدول جديد).

## Technical Context

**Language/Version**: Dart (Flutter SDK ^3.5.4)

**Primary Dependencies**: GetX (إدارة الحالة والتنقل)، sqflite (قاعدة بيانات محلية)، supabase_flutter (مزامنة وضع الفريق الاختيارية)، firebase_core/cloud_firestore (الترخيص فقط، غير مرتبط بهذه الميزة)

**Storage**: SQLite محلي (sqflite) كمصدر الحقيقة الأساسي؛ Supabase Postgres كمرآة مزامنة اختيارية لوضع الفريق فقط (لو مفعّل)

**Testing**: لا يوجد test suite آلي في المشروع حاليًا — بوابة الجودة المستخدمة طوال هذه الجلسة هي `flutter analyze` (تحليل ثابت) + مراجعة يدوية للمنطق + اختبار حي على جهاز فعلي عبر adb عند توفره. الخطة هتتبع نفس الأسلوب.

**Target Platform**: Android (المنصة الوحيدة المستهدفة فعليًا حاليًا — التطبيق موزَّع عبر Google Play ومباشرة عبر GitHub/الموقع)

**Project Type**: mobile-app (Flutter، مشروع واحد، بدون فصل frontend/backend)

**Performance Goals**: لا يوجد هدف رقمي محدد؛ المتوقع أداء استجابة فوري (نفس معيار باقي شاشات التطبيق — قوائم بمئات الطلاب بحد أقصى فعليًا)

**Constraints**: يجب أن تعمل الميزة أوفلاين بالكامل (SQLite محلي)؛ المزامنة مع وضع الفريق طبقة إضافية اختيارية فوقها فقط، مش شرط لعملها

**Scale/Scope**: تطبيق مدرس واحد لكل تثبيت (بمساعد اختياري واحد في وضع الفريق)، بحد أقصى مئات الطلاب حسب حدود الباقة (15/30/غير محدود)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` لسه ملف قالب فاضي (placeholder) — لم يتم اعتماد أي مبادئ رسمية للمشروع حتى الآن. **لا توجد بوابات (gates) رسمية تُفحص هذه الميزة مقابلها.** بدلاً من ذلك، الخطة بتلتزم بالأنماط المعمول بها فعليًا في الكود (established conventions) اللي اتبنت عليها كل الميزات المماثلة هذه الجلسة (مزامنة الامتحانات، المديونية المتراكمة):

- ✅ أي تعديل سكيمة محلي بيتماشى مع نمط `ALTER TABLE ... ADD COLUMN` + ترقية `DATABASE_VERSION` الموجود بالفعل في `database_service.dart`.
- ✅ أي توسعة مزامنة بتتبع نفس نمط `sync_engine.dart` (تعديل `_buildRemoteRow`/`_toLocalMap` لجدول موجود، بدون كسر التوافق مع الأجهزة القديمة).
- ✅ كل حساب مالي (مديونية، تقارير) بيمر عبر `PricingHelper` الموحّد — مفيش منطق مالي مكرر في شاشة جديدة.
- ✅ لا توجد بيانات حساسة تُحذف أو تُفقد — الأرشفة عملية soft فقط.

## Project Structure

### Documentation (this feature)

```text
specs/002-student-archiving/
├── plan.md              # هذا الملف
├── research.md          # ناتج Phase 0
├── data-model.md        # ناتج Phase 1
├── quickstart.md        # ناتج Phase 1
├── contracts/           # عقد واجهة التخزين المحلي (لا يوجد API خارجي)
└── tasks.md             # ناتج /speckit-tasks (غير منشأ بواسطة هذا الأمر)
```

### Source Code (repository root)

هذا مشروع Flutter واحد (mobile-app) — مفيش فصل frontend/backend. البنية الفعلية الحالية:

```text
lib/
├── models/
│   └── student_model.dart          # يُعدَّل: يضاف isArchived + archivedAt
├── controllers/
│   ├── student_controller.dart     # يُعدَّل: قوائم نشطين/مؤرشفين منفصلة + archiveStudent/unarchiveStudent
│   └── dashboard_controller.dart   # يُعدَّل: يستبعد المؤرشفين من كل الإحصائيات
├── services/
│   ├── database_service.dart       # يُعدَّل: عمودا الأرشفة + ترقية DB + دوال archive/unarchive
│   └── sync_engine.dart            # يُعدَّل: عمودا الأرشفة يُضافا لحمولة/فك تشفير جدول students
├── utils/
│   └── pricing_helper.dart         # بدون تعديل منطقي — بس المستدعين لازم يمرّروا طلاب نشطين بس
├── views/
│   ├── students/
│   │   ├── students_page.dart      # يُعدَّل: زرار أرشفة بدل/بجانب الحذف، القائمة تستخدم النشطين بس
│   │   ├── student_details_page.dart  # يُعدَّل: زرار أرشفة، تنبيه لو الطالب مؤرشف
│   │   └── archived_students_page.dart # جديد: شاشة الأرشيف
│   ├── groups/group_details_page.dart # يُعدَّل: نفس معاملة students_page.dart
│   ├── attendance/attendance_page.dart # يُعدَّل: يستبعد المؤرشفين من قوائم التحضير
│   └── qr_scanner/*.dart              # يُعدَّل: يرفض مسح/دفع لطالب مؤرشف
└── widgets/
    └── (أزرار/حوارات تأكيد الأرشفة تُضاف كمكوّنات صغيرة مشتركة إن أمكن)

android/  # بدون تعديل لهذه الميزة (لا علاقة لها بصلاحيات/build)
supabase/
└── migration_student_archiving.sql # جديد: عمودا الأرشفة على جدول students في Supabase
```

**Structure Decision**: تعديل داخل البنية الحالية لمشروع Flutter واحد (`lib/models`, `lib/controllers`, `lib/services`, `lib/views`) — بدون إنشاء أي مشروع/باكدج فرعي جديد. شاشة الأرشيف الجديدة الوحيدة تُضاف تحت `lib/views/students/` بجانب شاشات الطلاب الحالية لأنها منطقيًا امتداد لنفس الدومين.

## Complexity Tracking

لا توجد انتهاكات تستدعي تبريرًا — لا بوابات دستور رسمية مُفعَّلة (راجع Constitution Check أعلاه)، والتصميم يعيد استخدام الأنماط الموجودة (عمودان جديدان + مزامنة موسَّعة لجدول موجود) بدل بنية جديدة.

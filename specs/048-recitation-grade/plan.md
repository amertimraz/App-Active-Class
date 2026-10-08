# Implementation Plan: درجة التسميع أثناء الحصة

**Branch**: `048-recitation-grade` | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)

## Summary
عمود جديد `recitation` (INTEGER، 1..10، NULL) على جدول `attendance` المتزامن، بنفس نمط `interaction` (spec 040): DB v38 + migration Supabase + حقل في payload المزامنة (إرسال واستقبال). إدخال سريع في صف الطالب بورقة حضور اليوم (10 أزرار أرقام تحت صف التفاعل، للحاضر/المتأخر فقط)، وعرض الدرجة ومتوسط الشهر والإجمالي في تفاصيل الطالب. دوال صرفة للتحقق والمتوسط.

## Technical Context
Flutter 3.38 / Dart 3.5, GetX, sqflite (DB 37 → 38), Supabase self-hosted (migration واحد على attendance)، SyncEngine. اختبارات `flutter test`. قيد: تطبيق migration على الـVPS يحتاج موافقة المستخدم.

## Constitution Check
القالب غير مُعبَّأ → لا بوابات. ملتزم بنمط التفاعل (spec 040) ودوال صرفة + اختبارات.

## Project Structure
```
lib/utils/recitation.dart                    (جديد، صرف)
lib/models/attendance_model.dart             (حقل recitation + toMap/fromMap/copyWith(clearRecitation) + canRecordRecitation)
lib/config/constants.dart                    (COL_ATTENDANCE_RECITATION + DATABASE_VERSION=38)
lib/services/database_service.dart           (ALTER في onUpgrade v38 + عمود في create)
lib/services/sync_engine.dart                (attendance payload push/pull: 'recitation')
lib/controllers/attendance_controller.dart   (setRecitation + مسح عند الغياب/القلب لغائب تلقائي)
lib/controllers/qr_controller.dart           (لا تغيير متوقع — الغياب التلقائي بلا درجة؛ التحويل لحاضر يبدأ بلا درجة)
lib/views/attendance/attendance_page.dart    (_RecitationRow داخل _StudentAttendanceChip + recitationMap)
lib/views/students/student_details_page.dart (درجة بجانب اليوم + بطاقة متوسط الشهر/الإجمالي)
supabase/migration_attendance_recitation.sql (جديد)
test/recitation_test.dart                    (جديد)
```

## Design notes
- الدرجة حقل على سجل الحضور فتتحذف مع حذف السجل (فردي/جماعي/نطاق تاريخ/إلغاء تحضير الكل) تلقائيًا؛ صفر كود إضافي لها.
- مسح عند التحويل لغائب في `setAttendanceStatus` (جنب `clearInteraction`) ولا مسح عند حاضر⇄متأخر.
- `setRecitation(studentId, day, value)`: تتجاهل بصمت لو لا سجل أو الحالة غير مؤهلة أو القيمة خارج 1..10؛ الضغط على نفس القيمة (في الواجهة) يمرر null للمسح.
- تحضير الكل لا يضيف درجات ولا يمسحها لحاضر/متأخر (يتخطى الموجودين).
- نسب الحضور والمديونية لا تقرأ العمود → صفر تأثير.

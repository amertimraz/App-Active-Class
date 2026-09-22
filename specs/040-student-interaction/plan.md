# Implementation Plan: تفاعل الطالب في حضور اليوم — تقييم إيموجي بسيط

**Branch**: `040-student-interaction` | **Date**: 2026-09-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/040-student-interaction/spec.md`

## Summary

إضافة عمود اختياري جديد `interaction` على جدول `attendance` الموجود بالفعل (بدل كيان منفصل)، يخزّن واحدة من 3 قيم ثابتة (نشيط/عادي/غير متفاعل) أو `NULL`. الواجهة: صف صغير من 3 أزرار إيموجي يظهر تحت `_AttendanceStatusSegmented` الحالي في `attendance_page.dart`، يظهر بس لما حالة الحضور "حاضر"/"متأخر"، بنفس نمط toggle-select (ضغط نفس القيمة يمسحها). زرار "تطبيق على الكل" جنب زرار "تحضير الكل" الموجود بالفعل في نفس الشاشة، بنفس نمطه (bulk action على كل طلاب المجموعة المؤهَّلين). التفاعل يظهر بعد كده في: سجل حضور الطالب، تقرير الحضور الشهري (شاشة + PDF)، وملخّص في رسالة "تقرير الشهر" على واتساب. يتطلب migration على السيرفر (Supabase self-hosted) بنفس نمط `migration_guardian_whatsapp.sql`، وbump لـ`DATABASE_VERSION` محليًا.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX (AttendanceController)، sqflite (SQLite محلي)، Supabase self-hosted (مزامنة وضع الفريق)، `pdf`/`printing` (تصدير PDF — الإيموجي مدعوم بالفعل في نفس المستندات عبر `attendanceStatusLabel` الحالية)

**Storage**: عمود جديد `interaction TEXT NULL` على جدول `attendance` المحلي (sqflite) والبعيد (Postgres على Supabase self-hosted) — لا جدول جديد

**Testing**: `flutter test` لمنطق صرف جديد (تحديد ظهور خيار التفاعل بناءً على الحالة، ومسحه عند التحوّل لغائب) + اختبار يدوي على جهاز حقيقي لباقي السيناريوهات (لا widget tests لشاشة الحضور حاليًا، اتساقًا مع نمط specs 038/039)

**Target Platform**: Android (تطبيق موبايل للمدرّسين)

**Project Type**: mobile-app (مشروع Flutter واحد)

**Performance Goals**: لا هدف أداء خاص — تسجيل التفاعل عملية SQLite محلية فورية زي أي تحديث حضور موجود بالفعل.

**Constraints**: التفاعل يعتمد كليًا على وجود سجل حضور "حاضر"/"متأخر" بالفعل لنفس اليوم (FR-002/FR-006) — لا يمكن إنشاء سجل حضور جديد فقط لتسجيل تفاعل. صفر تأثير على حسابات الفوترة/نسبة الحضور (FR-011).

**Scale/Scope**: عمود واحد جديد + دالتين في `AttendanceController` (`setInteraction`, `markGroupInteraction`) + تعديل `setAttendanceStatus` (مسح التفاعل عند التحوّل لغائب) + ويدجت واجهة جديدة صغيرة + تعديلات عرض في 3 أماكن تقارير موجودة + migration واحدة.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

لا دستور مُفعَّل — تُطبَّق ممارسات المشروع القائمة: نفس نمط إضافة عمود اختياري على جدول متزامن (specs 021/033)، صفر جدول جديد أو معمارية جديدة، إعادة استخدام مكوّنات العرض والمزامنة الموجودة (`_AttendanceStatusSegmented`, `markGroupAllPresent`, `sync_engine` mapping). **لا مخالفات.**

## Project Structure

### Documentation (this feature)

```text
specs/040-student-interaction/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart                          # [MODIFY] DATABASE_VERSION 33→34، COL_ATTENDANCE_INTERACTION، ثوابت القيم الثلاث (STUDENT_INTERACTION_ACTIVE/NEUTRAL/DISENGAGED)
├── models/
│   └── attendance_model.dart                    # [MODIFY] حقل interaction + clearInteraction في copyWith + دوال عرض (interactionEmoji/interactionLabel) بنفس نمط attendanceStatusLabel/attendanceStatusColor
├── services/
│   ├── database_service.dart                    # [MODIFY] _onUpgrade (oldVersion < 34) + إدراج العمود في CREATE TABLE الأساسي لتنصيب جديد
│   └── sync_engine.dart                          # [MODIFY] push mapping (~سطر 558) وpull mapping (~سطر 1507) لعمود interaction
├── controllers/
│   └── attendance_controller.dart                # [MODIFY] setAttendanceStatus (مسح التفاعل عند غائب/إلغاء) + دالتين جديدتين: setInteraction، markGroupInteraction
├── views/
│   ├── attendance/
│   │   └── attendance_page.dart                  # [MODIFY] _StudentAttendanceChip (صف إيموجي جديد شرطي) + زرار "تطبيق على الكل" جنب "تحضير الكل"
│   ├── students/
│   │   └── student_details_page.dart             # [MODIFY] _AttendanceTab — عرض إيموجي التفاعل جنب كل سجل حضور
│   └── reports/
│       └── (شاشة/قسم تقرير الحضور الشهري الموجود)  # [MODIFY] عرض عمود/إيموجي التفاعل لكل يوم
├── services/
│   └── export_service.dart                       # [MODIFY] exportAttendancePDF — عمود التفاعل في جدول الحضور المُصدَّر
└── utils/
    └── monthly_report_message.dart                # [MODIFY] قسم ملخّص عدد أيام كل مستوى تفاعل في نص رسالة واتساب

supabase/
└── migration_student_interaction.sql              # [NEW] ALTER TABLE attendance ADD COLUMN interaction — بنفس نمط migration_guardian_whatsapp.sql

test/
└── student_interaction_test.dart                   # [NEW] اختبار الدالة الصرفة لتحديد الأهلية (حاضر/متأخر فقط) ومنطق المسح التلقائي
```

**Structure Decision**: لا هيكل جديد — تعديلات على ملفات موجودة بالفعل + ملف migration جديد وملف اختبار جديد واحد، بنفس نمط الميزات السابقة المشابهة (021 عمود اختياري جديد على جدول متزامن، 029 دالة عرض حالة جديدة).

## Complexity Tracking

*لا مخالفات تستدعي تبرير.*

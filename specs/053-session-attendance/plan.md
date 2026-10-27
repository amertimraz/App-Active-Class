# Implementation Plan: الحضور بالحصة

**Branch**: `053-session-attendance` | **Date**: 2026-10-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/053-session-attendance/spec.md`

## Summary

شاشة جديدة "تفاصيل الحصة" (مجموعة + تاريخ) بملخص حاضر/متأخر/غائب/لم يُسجَّل، تبويبات تصفية (الكل/حاضر/متأخر/غائب/لم يُسجَّل) وبحث، تسجيل/تعديل حالة كل طالب، تحضير غير المسجَّلين، وإرسال واتساب للغايبين المحدّدين. بتتفتح من (1) كارت الحصة في **جدول الحصص** اللي هيتحوّل من "يوم من الأسبوع" لتنقّل بالتاريخ (أسبوع/شهر قبل وبعد + اختيار تاريخ)، و(2) كارت الحصة في تبويب الحضور. **مفيش جداول ولا مزامنة جديدة**: الحصة تتشتق من المجموعة + التاريخ + `session_overrides`، والحضور يتسجّل بنفس `AttendanceController.setAttendanceStatus`. المنطق الحسابي (الملخص، التصفية، بناء رسالة الغياب، حساب تاريخ الأسبوع) في دوال صرفة مختبَرة.

## Technical Context

**Language/Version**: Dart 3.5 / Flutter 3.38

**Primary Dependencies**: GetX (controllers)، sqflite (قراءة فقط عبر controllers الحالية)، `launchGuardianWhatsapp` الموجود

**Storage**: لا تغيير — سجلات `attendance` (فريدة بالطالب+اليوم، `idx_attendance_student_day`) و`session_overrides` الموجودة؛ DB تبقى v39

**Testing**: `flutter test` — اختبارات وحدة للدوال الصرفة (+ widget smoke للصفحة الجديدة بالأسلوب المتبع في المشروع)

**Target Platform**: Android (الأساسي)، Flutter RTL عربي

**Project Type**: mobile-app (Flutter)

**Performance Goals**: فتح الشاشة بمجموعة 200 طالب < ثانيتين؛ تحديث الملخص عند كل ضغطة فوري (بدون إعادة قراءة DB كاملة)

**Constraints**: بدون تغيير schema/مزامنة؛ احترام صلاحيات وضع الفريق؛ تحديث محلي للسجل الواحد (مش `loadAttendance` كامل) زي `_replaceLocal`

**Scale/Scope**: شاشة جديدة + تعديل شاشتين (جدول الحصص، تبويب الحضور) + 2 ملف utils

## Constitution Check

`.specify/memory/constitution.md` قالب فارغ (لسه ما اتملاش) → مفيش بوابات رسمية. تم الالتزام بمبادئ المشروع العملية: (1) منطق صرف قابل للاختبار منفصل عن الواجهة، (2) لا تغيير schema/مزامنة، (3) ما نكسرش سلوك قائم ("غياب اليوم" وورقة الحضور الحالية تفضل زي ما هي)، (4) تحديث محلي بدل إعادة قراءة كاملة. **النتيجة: pass** (قبل وبعد التصميم).

## Project Structure

### Documentation (this feature)

```text
specs/053-session-attendance/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

(لا `contracts/`: ميزة داخلية للتطبيق بدون واجهات خارجية.)

### Source Code (repository root)

```text
lib/
├── utils/
│   ├── session_attendance.dart      # جديد: بناء roster الحصة + الملخص + التصفية (صرف)
│   ├── schedule_week.dart           # جديد: حساب تاريخ اليوم لأسبوع بإزاحة (السبت=0) (صرف)
│   └── absence_message.dart         # جديد: بناء رسالة تنبيه الغياب/التأخير (مستخرجة من _AbsentTodayTab)
├── views/
│   ├── attendance/
│   │   ├── session_detail_page.dart # جديد: شاشة تفاصيل الحصة
│   │   └── attendance_page.dart     # تعديل: استخدام absence_message + زرار "تفاصيل" على _GroupSummaryCard
│   └── schedule/
│       └── schedule_page.dart       # تعديل: تنقّل بالتاريخ + حصص override-aware + الضغط يفتح تفاصيل الحصة
test/
├── session_attendance_test.dart
├── schedule_week_test.dart
├── absence_message_test.dart
└── session_detail_page_test.dart    # widget smoke
```

**Structure Decision**: Flutter app أحادي المشروع؛ المنطق الصرف في `lib/utils` والواجهة في `lib/views/...` بنفس عُرف المشروع. الصفحة الجديدة ملف مستقل (مش داخل `attendance_page.dart` الضخم) وبتعتمد على `AttendanceController`/`StudentController`/`GroupController`/`SessionOverrideController` الموجودة.

## Complexity Tracking

لا مخالفات تحتاج تبرير.

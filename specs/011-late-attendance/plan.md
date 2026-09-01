# Implementation Plan: حالة حضور "متأخر"

**Branch**: `011-late-attendance` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/011-late-attendance/spec.md`

## Summary

إضافة حالة حضور ثالثة "متأخر" بجانب "حاضر"/"غائب". التخزين: قيمة نصّية جديدة `'متأخر'` في
عمود `attendance.status` + توسيع قيد `CHECK` عبر migration نسخة قاعدة 20→21. التسجيل: استبدال
التبديل الدوّار في `_StudentAttendanceChip` بـsegmented ثلاثي (نفس نمط `_HomeworkStatusSegmented`
من spec 010). مسح QR يحسب "متأخر" تلقائيًا لو وقت المسح بعد (بداية الحصة + مهلة قابلة للضبط من
الإعدادات، افتراضي 15 دقيقة). طبقة تطبيع/تسمية مشتركة (`attendance_model.dart`) هي مصدر الحقيقة
الوحيد؛ كل نقاط `== ATTENDANCE_PRESENT` اللي معناها "حضر" تتحوّل لـ`attendanceCountsAsPresent()`.
"متأخر" يُحتسب حضورًا في النسبة والفوترة بالحصة، ويظهر كفئة منفصلة في الإحصائيات/الداشبورد/ملخّص
المجموعة/تبويب "غياب اليوم" (قسم "متأخرين" منفصل)/تقارير الواتساب/البوابة/PDF.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter (stable)

**Primary Dependencies**: GetX (state)، sqflite (تخزين محلي)، pdf/printing (تقارير)، cloud_firestore (مزامنة الفريق + بوابة أولياء الأمور)

**Storage**: sqflite — جدول `attendance` (عمود `status` عليه `CHECK`)، جدول `app_settings` (مفتاح/قيمة)

**Testing**: يدوي عبر [quickstart.md](quickstart.md) على جهاز (نفس نهج specs 009/010) + `flutter analyze`

**Target Platform**: Android (arm64 + armeabi-v7a، split-per-abi)

**Project Type**: تطبيق موبايل single-project (`lib/`)

**Performance Goals**: تغيير حالة الحضور يظهر فورًا (< 100ms) زي السلوك الحالي

**Constraints**: offline-first؛ migration لازم تشتغل داخل transaction الـonUpgrade (بلا `db.transaction` متداخلة)؛ البيانات التاريخية ما تتكسرش

**Scale/Scope**: ~66 موضع `== ATTENDANCE_PRESENT/ABSENT` عبر 13 ملف؛ لمسة UI واحدة (segmented)؛ إعدادان جديدان (مهلة + مفتاح QR)؛ migration واحدة

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

ملف الدستور `.specify/memory/constitution.md` لسه template بـplaceholders — **مفيش مبادئ
ملزمة معرّفة**، فمفيش بوابات تُقيَّم. المشروع يتبع نمط specs 009/010 المُثبت:

- مصدر حقيقة واحد لتطبيع/تسمية الحالة (زي `homework_model.dart`).
- migration محافظة، guard بـ`oldVersion < N`، بلا transaction متداخلة.
- تحقّق يدوي عبر quickstart (مفيش بنية اختبار آلي في المشروع).

**النتيجة**: PASS (لا انتهاكات، لا تعقيد يحتاج تبرير).

## Project Structure

### Documentation (this feature)

```text
specs/011-late-attendance/
├── plan.md              # هذا الملف
├── research.md          # مكتمل — 7 قرارات
├── data-model.md        # مخطط التخزين + الإعداد الجديد
├── quickstart.md        # سيناريوهات تحقّق يدوية
├── checklists/
│   └── requirements.md   # مكتمل — كل البنود اجتازت
└── tasks.md             # ينشئه /speckit-tasks لاحقًا
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart                 # + ATTENDANCE_LATE = 'متأخر'؛ DATABASE_VERSION 20 → 21
├── models/
│   └── attendance_model.dart          # جديد — normalizeAttendanceStatus / attendanceStatusLabel
│                                      #        / attendanceCountsAsPresent / attendanceStatusColor
├── services/
│   ├── database_service.dart          # _onCreate CHECK موسّع + migration v21 (إعادة بناء الجدول)
│   ├── parent_portal_service.dart     # عدّاد late + attendanceHistory[].statusLabel
│   └── export_service.dart            # PDF — خانة/عدّاد "متأخر"
├── controllers/
│   ├── attendance_controller.dart     # setAttendanceStatus → String?‏ (null = حذف)؛
│   │                                  # getStudentMonthAttendance / buildGuardianReportMessage
│   │                                  #   → attendanceCountsAsPresent؛
│   │                                  # markGroupAllPresent → يتخطّى المسجّلين "متأخر" (FR-004)
│   │                                  # ملاحظة: isAttendanceCompleteForGroupToday يشيك على وجود
│   │                                  #   السجل فقط (مش الحالة) — بلا تغيير
│   ├── qr_controller.dart             # حساب "متأخر" تلقائيًا وقت المسح (لو الإعداد مفعّل)؛
│   │                                  # عدّادات الحصص بالحصة (status == PRESENT، ~سطر 534/585)
│   │                                  #   → attendanceCountsAsPresent (FR-013)
│   ├── dashboard_controller.dart      # فئة "متأخر" منفصلة
│   ├── report_controller.dart         # lateByStudent + طيّها في نسبة الحضور
│   └── settings_controller.dart       # lateGraceMinutes (افتراضي 15) + qrAutoLateEnabled (افتراضي true)
├── helpers/
│   └── pricing_helper.dart            # sessionsAttended → attendanceCountsAsPresent (حرج للفوترة)
├── views/
│   ├── attendance/
│   │   ├── attendance_page.dart       # _StudentAttendanceChip → segmented ثلاثي؛
│   │   │                              # ملخّص المجموعة + تبويب "غياب اليوم" قسم "متأخرين"
│   │   └── qr_scanner_attendance_page.dart  # رسالة تأكيد تعكس "متأخر"
│   ├── students/
│   │   └── student_details_page.dart  # تبويب الحضور + التقرير الشهري — عدّاد "متأخر"
│   ├── groups/
│   │   └── group_details_page.dart    # نسبة الحضور في البطاقات
│   └── settings/
│       └── settings_page.dart         # حقل "مهلة التأخير (دقائق)" + مفتاح "تسجيل المتأخر تلقائيًا عبر QR" + التقرير الشهري
└── helpers/
    └── student_sort_helper.dart       # فرز بنسبة الحضور → attendanceCountsAsPresent

booking_site/track/index.html          # واجهة البوابة — حالة "متأخر" ثالثة (نشر VPS يدوي)
```

**Structure Decision**: single-project موبايل. التغيير الأساسي: ملف `attendance_model.dart`
جديد كمصدر حقيقة، + تعديلات موضعية في الملفات أعلاه. مفيش وحدات/طبقات جديدة.

## Complexity Tracking

> لا انتهاكات دستورية — القسم فاضي.

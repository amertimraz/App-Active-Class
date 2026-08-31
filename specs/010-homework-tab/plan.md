# Implementation Plan: تبويب واجب + 3 حالات + ربط الغياب + التقارير

**Branch**: `010-homework-tab` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/010-homework-tab/spec.md`

## Summary

جسم موديل المجموعة (`_AttendanceSheet`) يتحوّل لشريط تبويبين **"حضور" | "واجب"** (يفتح على "حضور").
تبويب "حضور" = القائمة الحالية بدون شارة/زر واجب. تبويب "واجب" = صف لكل طالب غير غائب مع **3 أزرار
مجزّأة** (🟢 تم الحل / 🟡 ناقص / 🔴 لم يُحل) يُختار منها واحد (الضغط عليها تاني = غير مسجّل) + زر
"الكل عمل" + ملخّص. الطالب الغائب يعرض "غائب — لا واجب" وسجل واجبه يُحذف عند تسجيله غائبًا. حالة
الواجب (بالقيم الـ3 + غائب + غير مسجّل) تدخل في **كل** رسائل تقارير الواتساب والبوابة.
**بدون هجرة قاعدة بيانات** — بس قيمة نصّية جديدة `'ناقص'` + طبقة تطبيع للبيانات القديمة.

## Technical Context

**Language/Version**: Dart / Flutter (نفس إصدار المشروع)

**Primary Dependencies**: GetX (`HomeworkController`, `AttendanceController`), Flutter `TabBar`/`TabBarView` داخل `showModalBottomSheet`

**Storage**: `sqflite` — بنية جدول `homework` بدون تغيير؛ قيمة `status` النصّية تقبل `'ناقص'`

**Testing**: يدوي على الجهاز عبر quickstart.md

**Target Platform**: Android (Flutter mobile)

**Project Type**: تطبيق موبايل موحّد

**Performance Goals**: غير منطبق

**Constraints**: لا هجرة قاعدة بيانات؛ البيانات القديمة (`'عمل'`/`'لم يعمل'`) تُقرأ عبر تطبيع، مش تُعاد كتابتها؛ شاشة الحضور (تبويبات الصفحة) بدون تغيير؛ حالة الواجب في كل تقارير الواتساب

**Scale/Scope**: `attendance_page.dart` (التبويبات + الودجت) + `homework_controller.dart` + `constants.dart` + 4-5 نقاط تقارير/بوابة

## Constitution Check

`.specify/memory/constitution.md` قالب فارغ — لا بوابات. المبادئ: إعادة استخدام، تغيير أدنى، helper واحد لتطبيع/تسمية الحالة (مصدر حقيقة واحد).

## Project Structure

### Documentation (this feature)

```text
specs/010-homework-tab/  ├ plan.md · research.md · data-model.md · quickstart.md · tasks.md
```

### Source Code (repository root)

```text
lib/config/constants.dart
  + HOMEWORK_PARTIAL = 'ناقص'
  (HOMEWORK_DONE / HOMEWORK_NOT_DONE يفضلوا 'عمل'/'لم يعمل' — بيانات قديمة)

lib/controllers/homework_controller.dart
  + normalizeStatus(String? raw) -> 'عمل'/'لم يعمل'/'ناقص'/null   (تطبيع القديم)
  + setHomeworkStatus(int id, DateTime day, String? status)      (ضبط صريح / حذف لو null أو نفس القيمة)
  + clearHomework(int id, DateTime day)                          (حذف — يُنادى عند تسجيل غياب)
  + homeworkSummary(List<int> ids, DateTime day) -> {done, partial, notDone, unset}
  ~ markGroupAllHomeworkDone(ids, day)                           (المُستدعي يبعت ids بدون الغائبين)
  ~ toggleHomework                                               (يُشال — مفيش مستدعي بعد التبويب الجديد)

lib/views/attendance/attendance_page.dart
  ~ _AttendanceSheetState.build:
      - الهيدر المشترك يفضل فوق
      - + DefaultTabController(2) + TabBar(['حضور','واجب']) + Expanded(TabBarView)
      - تبويب "حضور": _buildAttendanceList (القائمة الحالية) - شارة الواجب - زر "واجب الكل"
      - تبويب "واجب": _buildHomeworkList (جديد):
          · صف ملخّص (homeworkSummary)
          · زر "الكل عمل / إلغاء الكل" (ids غير الغائبين)
          · لكل طالب: لو غائب -> "غائب — لا واجب"؛ غير كده -> _HomeworkStatusSegmented
  + _HomeworkStatusSegmented(status, onSelect)   (3 أزرار: نقطة ملوّنة + تسمية، واحد مختار)
  ~ عند تسجيل طالب غائب داخل الموديل -> homeworkCtrl.clearHomework(id, selectedDay)
  ~ صف أزرار "تحضير الكل" (~882): شيل بلوك "واجب الكل"
  ~ ودجت صف الطالب (~1238): homeworkStatus/onHomeworkTap يفضلوا nullable، تبويب الحضور مايبعتهمش
  = _HomeworkBadge: يُشال أو يُستبدل بـ_HomeworkStatusSegmented

lib/utils/helpers.dart (أو homework_controller.dart)
  + homeworkStatusLabel(String? raw, {bool absent}) -> نص للعرض/التقارير
    (تم الحل 🟢 / ناقص 🟡 / لم يُحل 🔴 / غائب (لا واجب) / لم يُسجَّل)

lib/controllers/attendance_controller.dart
  ~ buildGuardianReportMessage: hwLabel يستخدم homeworkStatusLabel(status, absent: <من attendanceStatus>)

lib/views/students/student_details_page.dart  +  lib/views/settings/settings_page.dart
  ~ التقرير الشهري: عدّاد 3 حالات + سطور اليوم بالتسمية الصح (homeworkStatusLabel)

lib/services/parent_portal_service.dart
  ~ homeworkHistory[].status يتطبّع؛ + homeworkPartial count

lib/controllers/report_controller.dart
  ~ + homeworkPartialByStudent في التجميعات

booking_site/track/index.html        # يُتحقق إن كان يعرض الواجب أصلاً؛ لو أيوة -> تحديث + نشر VPS
```

**Structure Decision**: كل بيانات الموديل (`group`, `selectedDay`, `statusMap` للحضور,
`studentCtrl`, `homeworkCtrl`) موجودة في `_AttendanceSheetState` — التبويبان يقروا منها،
و`groupStudents` يُحسب مرة واحدة. helper واحد `homeworkStatusLabel` + `normalizeStatus` =
مصدر حقيقة واحد للتسمية/التطبيع عبر كل نقاط العرض والتقارير.

## نهج التنفيذ (تفصيل من research.md)

1. **الثوابت + التطبيع**: `HOMEWORK_PARTIAL`، `normalizeStatus`، `homeworkStatusLabel`.
2. **`HomeworkController`**: `setHomeworkStatus` / `clearHomework` / `homeworkSummary`؛ `markGroupAllHomeworkDone` يستقبل ids مفلترة.
3. **`_AttendanceSheet` → تبويبين**: `DefaultTabController` + `TabBar` + `TabBarView`، الهيدر مشترك.
4. **تبويب حضور**: نفس القائمة، شيل الواجب + "واجب الكل".
5. **تبويب واجب**: `_HomeworkStatusSegmented` لكل طالب غير غائب، "غائب — لا واجب" للغائب، زر جماعي، ملخّص.
6. **ربط الغياب**: تسجيل غياب → `clearHomework`.
7. **التقارير + البوابة**: كل نقاط `HOMEWORK_DONE/NOT_DONE` تمرّ عبر `homeworkStatusLabel`/`normalizeStatus` وتتعامل مع "ناقص" و"غائب".
8. **الصفحة العامة**: تحقّق → تحديث + نشر لو لازم.

### خارج النطاق (نسخة لاحقة)

نص واجب اليوم للمجموعة، نسبة الالتزام، فرز/فلترة بالحالة، خريطة حرارية، لوحة التزام، إشعار تذكير، أي تبويب واجب على مستوى شاشة الحضور.

## Complexity Tracking

لا مخالفات دستورية. التعقيد الوحيد المقصود: طبقة تطبيع للبيانات القديمة بدل هجرة — مبرَّرة (أقل مخاطرة، لا تلمس صفوف موجودة).

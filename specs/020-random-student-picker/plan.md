# Implementation Plan: اختيار طالب عشوائي أثناء الحصة

**Branch**: `020-random-student-picker` | **Date**: 2026-09-04 | **Spec**: [spec.md](spec.md)

## Summary

زر واحد في `_AttendanceSheet` + دالة اختيار + حوار عرض. كله UI محلي، صفر قاعدة بيانات، صفر حزم، صفر شبكة.

## Technical Context

- **Language**: Dart 3.5.4 / Flutter 3.38.1، GetX.
- **Deps**: `dart:math` (`Random`). لا جديد.
- **State**: `Set<int> _calledStudentIds` داخل `_AttendanceSheetState` (in-memory، بيتصفّر مع dispose الشيت).
- **Testing**: `flutter analyze` صفر تحذيرات + تحقّق يدوي (quickstart).

## Constitution Check

PASS — أداة عرض بسيطة، نفس نمط بقية عناصر `_AttendanceSheet` (Obx، ألوان AppTheme). صفر أثر على أي بيانات.

## Source Changes

```text
lib/views/attendance/attendance_page.dart
  _AttendanceSheetState:
    + Set<int> _calledStudentIds = {}
    + void _pickRandomStudent(List<Student> groupStudents, Map<int,String> statusMap)
        - pool = groupStudents حاضرين (attendanceCountsAsPresent) — fallback كل groupStudents
        - eligible = pool - _calledStudentIds ؛ لو فاضية → صفّر _calledStudentIds + eligible = pool
          + toast "خلصنا الكل — بندأ من الأول"
        - pick = eligible[Random().nextInt(len)] ؛ _calledStudentIds.add(pick.id)
        - showDialog(_RandomPickDialog(name: pick.name, onAgain: ..., ...))
    + زر IconButton/FilledButton "اختيار عشوائي" (Icons.casino_rounded) في صف أدوات الشيت
      (جنب البحث/الفرز، ~سطر 900+) — معطّل لو groupStudents فاضية

  + class _RandomPickDialog (StatefulWidget)
      - Timer.periodic(60ms) يبدّل نص عشوائي من الأسماء ~1s ثم يستقر على الاسم النهائي
      - خط كبير (28+)، أيقونة 🎯، زر "تاني" (يقفل ويعيد النداء عبر callback) + "تم"
```

**نقطة الإدراج للزر**: صف الأدوات في `_AttendanceSheet` (بعد الترويسة، قبل قايمة الطلاب) — نفس مكان حقل البحث/الفرز الموجود.

## Complexity Tracking

> لا انتهاكات.

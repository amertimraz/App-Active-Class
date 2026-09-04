# Tasks: اختيار طالب عشوائي أثناء الحصة

**Tests**: تحقّق يدوي + `flutter analyze` صفر تحذيرات. لا مهام اختبار.

## Phase 1: US1 — الاختيار العشوائي (P1) 🎯 MVP

- [x] T001 [US1] في `lib/views/attendance/attendance_page.dart` — `_AttendanceSheetState`: أضف `final Set<int> _calledStudentIds = {}`. (يتصفّر تلقائيًا مع كل فتح جديد للشيت لأن الـState بيتعمله dispose.)
- [x] T002 [US1] في نفس الملف: `class _RandomPickDialog extends StatefulWidget` — يستقبل `List<String> allNames`, `String finalName`, `VoidCallback onAgain`. `initState` يشغّل `Timer.periodic(const Duration(milliseconds: 60))` يبدّل نص معروض عشوائي من `allNames`؛ بعد ~1000ms يوقف الـTimer ويثبت `finalName`. UI: حوار، أيقونة 🎯، الاسم بخط `fontSize: 30 w900`، زرّين: "تاني" (`Navigator.pop` ثم `onAgain()`) و"تم" (`Navigator.pop`). `dispose` يلغي الـTimer.
- [x] T003 [US1] في `_AttendanceSheetState`: `void _pickRandomStudent(List<Student> groupStudents, Map<int,String> statusMap)`:
  - `present = groupStudents.where((s) => attendanceCountsAsPresent(statusMap[s.id]))` → `pool = present.isNotEmpty ? present : groupStudents`
  - `eligible = pool.where((s) => !_calledStudentIds.contains(s.id)).toList()`
  - لو `eligible.isEmpty`: `_calledStudentIds.clear()`; `eligible = pool.toList()`; `ToastHelper.info('خلصنا الكل — بندأ من الأول')`
  - `if (eligible.isEmpty) return;`
  - `final pick = eligible[math.Random().nextInt(eligible.length)]`; `_calledStudentIds.add(pick.id!)`
  - `showDialog(context, builder: (_) => _RandomPickDialog(allNames: pool.map((s)=>s.name).toList(), finalName: pick.name, onAgain: () => _pickRandomStudent(groupStudents, statusMap)))`
  - أضف `import 'dart:math' as math;` لو مش موجود.
- [x] T004 [US1] في `build` بتاع `_AttendanceSheet` — صف أدوات الشيت (جنب البحث/الفرز، بعد الترويسة): زر `FilledButton.tonalIcon` / `IconButton` بأيقونة `Icons.casino_rounded` ونص "اختيار عشوائي"؛ `onPressed: groupStudents.isEmpty ? null : () => _pickRandomStudent(groupStudents, statusMap)`.

## Phase 2: Polish

- [x] T005 `flutter analyze` صفر أخطاء/تحذيرات.
- [ ] T006 تحقّق يدوي (quickstart): ضغطتين متتاليتين = اسمين مختلفين؛ بعد ما القايمة تخلص → toast + دورة جديدة؛ قفل/فتح الشيت = تصفير؛ مجموعة فاضية = زر معطّل؛ صفر تغيير في سجلات الحضور.
- [x] T007 [P] حدّث ملاحظات الجلسة (سبيك 020).

## Dependencies

T001 → T003 → T004. T002 مستقل (قبل T003 لأنه بيستدعيه). Polish بعد الكل.

## MVP

كل US1 (T001–T004) = MVP كامل. مفيش US تانية.

# Internal Contract: AttendanceController — تفاعل الطالب

التطبيق موبايل offline-first بدون API خارجي — العقود هنا واجهات داخلية بين شاشة الحضور و`AttendanceController`.

## `setInteraction`

```dart
/// يسجّل/يلغي/يغيّر تفاعل طالب لسجل حضور يوم معيّن. لا يفعل شيئًا (أو
/// يرمي خطأ واضح) لو السجل مش موجود أو حالته لا تسمح بتسجيل تفاعل
/// (canRecordInteraction == false).
Future<void> setInteraction(int studentId, DateTime day, String? interaction);
```

**السلوك المتوقَّع**:
- لو `interaction == null`: يمسح القيمة الحالية (toggle-off) — يطابق سلوك الضغط على نفس الإيموجي المختار.
- لو السجل غير موجود لنفس اليوم، أو `canRecordInteraction(record.status) == false`: لا تنفيذ، بلا استثناء غير متوقَّع (الواجهة أصلاً بتمنع الاستدعاء في هذه الحالة — دفاع إضافي فقط).
- بعد النجاح: `loadAttendance()` يُستدعى (بنفس نمط `setAttendanceStatus`) عشان الواجهة تتحدّث فورًا.

## `markGroupInteraction`

```dart
/// يطبّق مستوى تفاعل واحد على كل الطلاب في [studentIds] اللي عندهم
/// سجل حضور اليوم [day] بحالة تسمح بتسجيل تفاعل (حاضر/متأخر) — الطلاب
/// الغائبون أو بلا سجل حضور يُتخطّون تلقائيًا بلا خطأ.
Future<void> markGroupInteraction(
    List<int> studentIds, DateTime day, String interaction);
```

**السلوك المتوقَّع**:
- يكتب فوق أي تفاعل فردي مسجَّل مسبقًا لنفس اليوم لنفس الطلاب المؤهَّلين (FR-013).
- لو مفيش أي طالب مؤهَّل في `studentIds` وقت التنفيذ: لا يُسجَّل أي شيء، وتُرجع الدالة إشارة (مثلاً عدد التطبيقات = صفر) تسمح للواجهة بإبلاغ المدرّس بوضوح (FR-014) — الشكل الدقيق (Exception أم قيمة راجعة) يُحسَم وقت التنفيذ بما يتّسق مع نمط `markGroupAllPresent` الحالي (بيرجع `void` ويبلّغ عن طريق تتبّع succeeded/failed داخليًا وعرض SnackBar من الشاشة).

## تعديل `setAttendanceStatus` الموجودة

**السلوك الجديد المطلوب إضافته** (بدون تغيير التوقيع الخارجي):
- عند `status == null` (حذف السجل) أو `status == ATTENDANCE_ABSENT`: أي `interaction` مخزَّن على نفس السجل يُمسح كجزء من نفس عملية التحديث/الحذف (FR-006) — لا حاجة لاستدعاء منفصل من الشاشة.

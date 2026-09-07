# Contract: `PricingHelper.showsAttendanceOverdueWarning`

يُضاف إلى `lib/utils/pricing_helper.dart` بجوار `isOverdue`.

## التوقيع

```dart
/// هل يُعرَض تنبيه "متأخر في الدفع" لهذا الطالب في شاشة الحضور؟
/// - معفى بالكامل → false
/// - مجموعة شهرية / بلا مجموعة → isOverdue(...) (بمهلة السماح)
/// - مجموعة بالحصة → مديونية باقية بعد استثناء حصص اليوم → true
static bool showsAttendanceOverdueWarning({
  required Student student,
  required Group? group,
  required List<Attendance> allAttendance,
  required List<Payment> payments,          // كل الدفعات أو دفعات الطالب — الحساب القائم يفلتر
  required int graceDays,
  List<Student>? siblingGroupMembers,
});

/// عدد حصص الطالب المحتسبة حضورًا في يوم بعينه (helper داخلي، @visibleForTesting).
static int sessionsAttendedOn({
  required Student student,
  required DateTime day,
  required List<Attendance> allAttendance,
});
```

## المنطق

```
if (student.isFullyExempt) return false;

final perSession = group != null && group.isPerSession;

if (!perSession) {
  return isOverdue(
    student: student, group: group, allAttendance: allAttendance,
    payments: payments, graceDays: graceDays,
    siblingGroupMembers: siblingGroupMembers);
}

final debt = accumulatedDebt(
  student: student, group: group, allAttendance: allAttendance,
  payments: payments, siblingGroupMembers: siblingGroupMembers);
if (debt <= 0.01) return false;

final todayValue =
  sessionsAttendedOn(student: student, day: DateTime.now(), allAttendance: allAttendance)
  * student.effectivePrice;

return (debt - todayValue) > 0.01;
```

`sessionsAttendedOn`:
```
allAttendance.where((a) =>
  a.studentId == student.id &&
  attendanceCountsAsPresent(a.status) &&
  a.date.year == day.year && a.date.month == day.month && a.date.day == day.day
).length
```

## ثوابت لا تُكسر

- لا يستدعي أي كتابة قاعدة بيانات — دالة نقية.
- `isFullyExempt` تسبق كل شيء.
- per-session: عتبة `0.01` على الطرفين (debt نفسه، والفرق بعد الاستثناء) لتفادي ضجيج التقريب.
- المهلة (`graceDays`) تؤثّر فقط على الفرع الشهري.
- الدالة لا تعتمد الوقت إلا عبر `DateTime.now()` في فرع per-session — الاختبار يحقن الحضور بتواريخ نسبية.

## اختبارات (`test/attendance_overdue_warning_test.dart`)

| # | السيناريو | المتوقّع |
|---|---|---|
| 1 | شهري، مديونية شهر سابق، خارج المهلة | true |
| 2 | شهري، مديونية الشهر الحالي فقط، ضمن المهلة (graceDays=10، اليوم ≤10) | false |
| 3 | شهري، مدفوع بالكامل | false |
| 4 | معفى بالكامل (أي نوع) | false |
| 5 | per-session، حضر حصة اليوم فقط، صفر دفعات | false |
| 6 | per-session، حضر حصتين أمس، صفر دفعات | true (قيمة الحصتين) |
| 7 | per-session، حضر 3 حصص سابقة + دفعها كلها + حصة اليوم غير مدفوعة | false |
| 8 | per-session، حصص سابقة قيمتها 100 + دفع 60 + حصة اليوم | true (باقي 40 من القديم) |
| 9 | per-session، `effectivePrice == 0` | false |
| 10 | `sessionsAttendedOn` يحسب "متأخر" ضمن حضور اليوم | يُستثنى مثل "حاضر" |

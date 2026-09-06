# Contract: توسيع نطاق الشهور للمسار per-session في `QRController`

## الهدف
جعل عدّ الحصص المستحقة وتواريخها في شاشة الدفع بالماسح يشمل كل الحصص غير المدفوعة من شهر انضمام الطالب حتى الشهر الحالي (لا الشهر الحالي فقط) — بحيث تطابق `scannedStudentDebt`.

## التغيير في `_preparePayment(Student student)`

```
final isPerSession = _scannedGroup.value?.isPerSession ?? false;
final nowMonth = DateTime(now.year, now.month);

// قبل:  final start = isPerSession ? nowMonth : _oldestUnpaidMonth(...);
// بعد:
final DateTime start;
if (isPerSession) {
  final joined = student.attendanceStart ?? student.createdAt;
  start = joined != null
      ? DateTime(joined.year, joined.month)
      : nowMonth;
} else {
  start = _oldestUnpaidMonth(student, _scannedGroup.value, payments);
}

final months = _buildUpcomingMonths(start, perSession: isPerSession);
upcomingMonths.assignAll(months);

// autoSelect: للـper-session اختر كل الشهور من start حتى الشهر الحالي (شامل).
// المجموعات الشهرية: كما هو (شهر واحد أقدم لو فات).
final autoSelect = isPerSession || start.isBefore(nowMonth);
if (isPerSession) {
  selectedMonths.assignAll(
      months.where((m) => !m.isAfter(nowMonth)).toList());
} else {
  selectedMonths.assignAll(autoSelect && months.isNotEmpty ? [months.first] : []);
}
```

## التغيير في `_buildUpcomingMonths`

توقيع جديد: `List<DateTime> _buildUpcomingMonths(DateTime start, {bool perSession = false})`.
- المجموعات الشهرية: بلا تغيير (سقف 12، `+2` شهر قدّام، حد أدنى 4).
- `perSession: true`: من `start` حتى الشهر الحالي فقط (بلا شهور مستقبلية)، **بلا سقف 12** (أو سقف 60 حارسًا).

## الـgetters المتأثرة (تتصحّح تلقائيًا — لا تعديل في كودها)

| getter | قبل (per-session) | بعد |
|---|---|---|
| `selectedSessionsCount` | حضور الشهر الحالي | حضور كل الشهور join→now |
| `_paidSessionsInSelectedMonths` | `sessions=` لدفعات الشهر الحالي | لكل دفعات join→now |
| `unpaidSessionsCount` | الفرق (شهر واحد) | الفرق الكلي |
| `unpaidSessionDates` | تواريخ الشهر الحالي بعد حذف المدفوع | كل التواريخ مرتّبة بعد حذف أقدم `paid` |
| `fullyPaidUp` | مدفوع للشهر الحالي | مدفوع بالكامل فعليًا |
| `effectiveSessionsSelected` / `resetSessionsToPaySelection` | يعتمد `unpaidSessionsCount` | يتبع الكلي |
| `_recalculateTotal` (per-session) | `effectivePrice * effectiveSessionsSelected` | نفسه، بقيمة كلية |

## ثبات (invariants) بعد التغيير

1. `unpaidSessionsCount == scannedStudentDebtSessions` عندما `effectivePrice > 0` وكل الحصص بنفس السعر (تسامح ±0 حصة؛ فرق ممكن لو تغيّر `student.price` تاريخيًا — مقبول، `scannedStudentDebt` بالجنيه هو المرجع).
2. بعد `payAllUnpaidSessions()` ثم `confirmPayment()`: `scannedStudentDebt` عند إعادة الفتح = 0 (± سعر حصة واحدة لو تغيّر السعر).
3. الخاصية المقصودة القديمة: حصة تُحضَر في شهر به دفعة سابقة تظل مستحقة — محفوظة (الشهر ضمن النطاق).
4. المجموعات الشهرية: صفر تغيير سلوكي.
5. `_paidSessionsInSelectedMonths` regex `sessions=(\d+)`؛ دفعة بلا عدّاد = 1 — بلا تغيير.

## اختبار القبول
- طالب per-session سعر 20، انضم 1 أغسطس، حضر 6 حصص أغسطس + 1 سبتمبر، بلا دفعات → فتح الشاشة (تاريخ النظام سبتمبر): `unpaidSessionsCount == 7`، `unpaidSessionDates.length == 7` مرتبة تصاعديًا، `scannedStudentDebt == 140`.
- نفس الطالب + دفعة سابقة `amount=60, note=...;sessions=3` بتاريخ أغسطس → `unpaidSessionsCount == 4`، `unpaidSessionDates` = آخر 4 تواريخ.

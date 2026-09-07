# Research: تنبيه المتأخر في شاشة الحضور

## قرار 1 — دالة قرار واحدة في `PricingHelper`

**القرار**: `static bool showsAttendanceOverdueWarning({required Student student, required Group? group, required List<Attendance> allAttendance, required List<Payment> payments, required int graceDays, List<Student>? siblingGroupMembers})`.

المنطق:
```
if (student.isFullyExempt) return false;
final perSession = group != null && group.isPerSession;
if (!perSession) {
  return isOverdue(student, group, allAttendance, payments, graceDays, siblings);
}
// per-session:
final debt = accumulatedDebt(student, group, allAttendance, payments, siblings);
if (debt <= 0.01) return false;
final todaySessions = _sessionsAttendedOn(student, DateTime.now(), allAttendance);
final todayValue = todaySessions * student.effectivePrice;
return (debt - todayValue) > 0.01;
```

**السبب**: مكان واحد بجوار `isOverdue`؛ يعيد استخدام `accumulatedDebt` (نفس رقم كارت الطالب) و`isOverdue` (نفس منطق مهلة السماح). دالة `bool` نقية قابلة للاختبار بلا widgets ولا GetX.

**قيمة العرض**: الودجت يعرض `accumulatedDebt(...).round()` — القيمة الحقيقية الكاملة (مش `debt - todayValue`)؛ المدرّس يشوف كل المديونية.

**البدائل المرفوضة**:
- حساب في `AtRiskService` — ده لإشعارات مجدولة، مش قرار لحظي.
- تكرار منطق التسعير في الشاشة — يخالف "لا تكرار".

---

## قرار 2 — "حصص اليوم" لطالب per-session

**القرار**: helper داخلي `_sessionsAttendedOn(student, date, allAttendance)` = عدد سجلّات الحضور للطالب في نفس اليوم (سنة/شهر/يوم) اللي `attendanceCountsAsPresent(status)` (يشمل "حاضر" و"متأخر" — spec 011).

**السبب**: `sessionsAttended` القائمة بحبيبة الشهر مش اليوم. helper صغير بنفس نمطها. "متأخر" حصة محضورة كاملة فتُستثنى زي "حاضر".

**البدائل المرفوضة**: استثناء "كل حصص الشهر الحالي" — غلط، لو حضر أول الشهر ومادفعش يبقى متأخر فعلًا. المطلوب استثناء **اليوم** فقط.

---

## قرار 3 — مهلة السماح لا تنطبق على per-session

**القرار**: per-session صارم — أي رصيد لحصة سابقة لليوم = تنبيه فورًا، بلا مهلة. المهلة (`graceDays`) تُمرَّر للدالة لكن تُستخدم فقط في فرع `isOverdue` (الشهري).

**السبب**: طلب المستخدم الصريح. منطق المهلة الشهري مبني على "الشهر الحالي" — مالوش معنى للحصص.

---

## قرار 4 — تحميل الدفعات في شاشة الـQR للحضور

**القرار**: `QRScannerAttendancePage` تكتسب `PaymentController` (`Get.isRegistered ? find : put`) وتنادي `loadPayments()` في `postFrameCallback` بجانب تحميل الطلاب/المجموعات/الحضور الحالي. الودجت يقرأ `payments` عبر `Obx`/`GetBuilder` فيتحدّث لو اتغيّرت (FR-009).

**السبب**: `attendance_page.dart` بيعمل كده بالفعل (سطر 728). التكلفة مرة واحدة عند الفتح. الحساب لكل طالب يتم عند بناء الودجت مش عند المسح.

**البدائل المرفوضة**: تحميل دفعات طالب واحد عند المسح — تأخير في مسار المسح؛ ومش هيغطّي كروت البحث.

**أداء**: `accumulatedDebt` لكل طالب في قائمة بحث كبيرة = O(n × دفعات). لو ظهر بطء، نحسب لكل عنصر مرئي فقط (ListView.builder بيعمل كده تلقائيًا) — كافٍ لـ v1.

---

## قرار 5 — مفتاح إعداد واحد

**القرار**: `SETTING_ATTENDANCE_OVERDUE_WARNING = 'attendance_overdue_warning'`، `RxBool attendanceOverdueWarning` (افتراضي `true`)، محلي عبر `_dbSet`، غير مُزامن. مفتاح واحد يحكم كل المواضع (شاشتان). سطر Switch في الإعدادات بجانب "تسجيل متأخر تلقائيًا".

**السبب**: نمط `qrAutoLateEnabled` بالظبط. مفتاح لكل شاشة = تعقيد بلا داعٍ.

---

## قرار 6 — عرض الودجت: بصري بحت

**القرار**: `OverdueWarningBadge` — شريط مضغوط بلون تحذيري (`0xFFEF4444` أو `0xFFF59E0B`) + أيقونة `Icons.warning_amber_rounded` + "متأخر في الدفع • مديونية N ج". يظهر فقط لو `settings.attendanceOverdueWarning.value` والدالة رجعت `true`. لا `onTap`، لا زر، لا يمنع أي شيء.

**السبب**: FR-012 صريح. اتساق مع تنبيهات التطبيق.

**مواضع الدمج**:
- `_AttendancePanel` (نتيجة المسح) — أعلى البطاقة تحت اسم الطالب.
- `_StudentSearchCard` (كروت البحث) — سطر تحت الكود/المجموعة.
- `attendance_page.dart` القوائم — بادج صغير جنب الاسم (نسخة `compact`).

---

## ملخّص الحسم

| # | الموضوع | القرار |
|---|---|---|
| 1 | الدالة | `PricingHelper.showsAttendanceOverdueWarning` — نقية، تبني على `isOverdue`/`accumulatedDebt` |
| 2 | حصص اليوم | `_sessionsAttendedOn` داخلي، "متأخر" محسوب كحضور |
| 3 | المهلة | شهري فقط؛ per-session صارم |
| 4 | تحميل الدفعات | `PaymentController` في شاشة الـQR، `loadPayments` عند الفتح |
| 5 | الإعداد | مفتاح واحد `attendanceOverdueWarning` افتراضي on |
| 6 | العرض | `OverdueWarningBadge` بصري بحت، نسخة عادية + compact |

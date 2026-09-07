# Contract: `OverdueWarningBadge` + مواضع الدمج

ملف جديد: `lib/widgets/overdue_warning_badge.dart`. يعتمد `flutter/material.dart` فقط + `FormatHelper` القائم للعملة.

## الواجهة

```dart
class OverdueWarningBadge extends StatelessWidget {
  const OverdueWarningBadge({
    super.key,
    required this.debtAmount,   // قيمة المديونية المتراكمة الحقيقية
    this.compact = false,       // نسخة صغيرة لقوائم attendance_page
  });

  final double debtAmount;
  final bool compact;
}
```

- `compact == false`: شريط عرض كامل — خلفية `0xFFEF4444` بشفافية 0.1، حد بنفس اللون بشفافية 0.3، أيقونة `Icons.warning_amber_rounded` + نص "متأخر في الدفع • مديونية ${FormatHelper.formatCurrency(debtAmount)}".
- `compact == true`: شارة صغيرة (أيقونة + "متأخر" أو الرقم فقط) بجانب اسم الطالب في القوائم.
- بلا `onTap`، بلا سلوك. بصري بحت (FR-012).

## مواضع الدمج — `qr_scanner_attendance_page.dart`

### `initState` / تحميل
- اكتسب `PaymentController _payCtrl` (نمط `Get.isRegistered ? find : put`).
- في `postFrameCallback` الموجود: `await _payCtrl.loadPayments();` بجانب `loadAllStudents/loadGroups/loadAttendance`.

### `_AttendancePanel` (نتيجة المسح)
داخل `Obx`/build، بعد بطاقة الطالب مباشرةً:
```dart
if (settings.attendanceOverdueWarning.value) {
  final show = PricingHelper.showsAttendanceOverdueWarning(
    student: student, group: group,
    allAttendance: attCtrl.attendance,
    payments: payCtrl.payments,
    graceDays: settings.paymentGraceDays,
    siblingGroupMembers: stuCtrl.students);
  if (show) {
    final debt = PricingHelper.accumulatedDebt(... نفس المدخلات ...);
    → OverdueWarningBadge(debtAmount: debt)
  }
}
```
`_AttendancePanel` محتاج يستقبل `PaymentController` + `SettingsController` + قائمة الطلاب (تمرير من الأب) أو `Get.find` داخله.

### `_StudentSearchCard` (كروت البحث)
نفس الحساب؛ `OverdueWarningBadge(debtAmount: debt, compact: true)` كسطر تحت `${student.code} · ${group?.name}`.

## مواضع الدمج — `attendance_page.dart`

- `PaymentController _payCtrl` موجود بالفعل (سطر ~728). تأكّد `loadPayments()` اتنادت (غالبًا نعم عبر الشاشة؛ لو لأ ضيفها).
- في عنصر قائمة الطالب (`itemBuilder` بتبويب تسجيل الحضور، و`_SessionSheet` لو له عرض طلاب): بعد اسم الطالب، نفس شرط `showsAttendanceOverdueWarning` → `OverdueWarningBadge(compact: true)`.

## مواضع الدمج — `settings_page.dart`

سطر `_buildSwitchTile` جديد في قسم إعدادات الحضور/المسح (بجانب "تسجيل متأخر تلقائيًا عبر QR"):
```
العنوان : "تنبيه المتأخر في شاشة الحضور"
الأيقونة: Icons.warning_amber_rounded
اللون   : const Color(0xFFF59E0B)
rxValue : settings.attendanceOverdueWarning
onChanged: (v) async => await settings.setAttendanceOverdueWarning(v)
subtitle عند التفعيل: "بيظهر شريط تحذير جنب اسم الطالب المتأخر وقت تسجيل حضوره"
subtitle عند التعطيل: "معطّل — مفيش تحذير دفع في شاشة الحضور"
```

## ثوابت

- لو المفتاح معطّل: الودجت لا يُبنى والدالة لا تُنادى → صفر أثر أداء (SC-005).
- التنبيه لا يظهر قبل اكتمال تحميل الدفعات (تجنّب وميض): لو `payCtrl.payments` فاضية والتحميل لسه شغّال، الحساب هيرجع "لا مديونية" طبيعيًا — مقبول، أو نحرس بعلم `_paymentsLoaded`.

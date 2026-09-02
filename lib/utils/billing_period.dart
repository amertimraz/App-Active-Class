// lib/utils/billing_period.dart
//
// "شهر التحصيل الافتراضي" — مصدر واحد لتعريف الشهر اللي يفتح عليه أي
// شاشة فيها منتقي شهر (التقارير، المدفوعات، تقرير المدفوعات، تفاصيل
// الرسوم، كارت دفعات الداشبورد، موديلات تقرير الواتساب). راجع spec 013.
//
// المنطق: في أول أيام الشهر الجديد المدرس لسه بيحصّل الشهر اللي فات،
// وفي وضع "التحصيل المؤخّر" (spec 012) الشهر الجاري أصلاً مش مستحق —
// فالافتراضي في الحالتين = آخر شهر مكتمل.
import 'package:get/get.dart';

import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/pricing_helper.dart';

/// الشهر (اليوم 1) اللي المفروض أي شاشة شهرية تفتح عليه افتراضيًا.
DateTime defaultCollectionMonth() {
  final now = DateTime.now();
  final current = DateTime(now.year, now.month, 1);

  final grace = Get.isRegistered<SettingsController>()
      ? Get.find<SettingsController>().paymentGraceDays.value
      : 0;
  final threshold = grace > 5 ? grace : 5;
  final earlyInMonth = now.day <= threshold;

  if (PricingHelper.billingArrears || earlyInMonth) {
    // Dart بينرمل الشهر 0 → ديسمبر السنة اللي فاتت
    return DateTime(now.year, now.month - 1, 1);
  }
  return current;
}

// lib/utils/team_shared_settings.dart
//
// الإعدادات المشتركة في وضع الفريق: المدرس (المالك) هو اللي بيضبطها، وبتتطبّق
// تلقائيًا على أجهزة المساعدين اللي ما يقدروش يعدّلوها. دي الإعدادات اللي
// بتأثر على حسابات أو بيانات مشتركة (المديونية، الحضور، التقارير)؛ أما
// تفضيلات الاستخدام الشخصية (المظهر، الساعة، الإشعارات، ماسح الباركود،
// النسخ الاحتياطي) فبتفضل محلية لكل جهاز.
import 'package:active_class/config/constants.dart';

/// مفاتيح app_settings المشتركة. لو ضفت إعداد جديد بيأثر على بيانات الفريق،
/// ضيفه هنا.
const Set<String> kTeamSharedSettingKeys = {
  // المالية
  'currency_code',
  'payment_grace_days',
  SETTING_BILLING_ARREARS,
  SETTING_BILLING_DAY,
  SETTING_PRORATE_FIRST_MONTH,
  // الحضور
  SETTING_LATE_GRACE_MINUTES,
  SETTING_QR_AUTO_LATE_ENABLED,
  SETTING_ATTENDANCE_OVERDUE_WARNING,
  SETTING_SHOW_HOMEWORK,
  SETTING_SHOW_RECITATION,
  SETTING_SHOW_INTERACTION,
  SETTING_RECITATION_MAX,
  SETTING_ALLOW_GUEST_STUDENTS,
  SETTING_AUTO_ABSENT_ENABLED,
  SETTING_AUTO_ABSENT_GRACE_MINUTES,
  // الواتساب والتقارير
  'country_dial',
  'wa_button_enabled',
  'wa_send_day',
  SETTING_REPORT_ON_COMPLETION_ENABLED,
  // طلاب محتاجين متابعة
  SETTING_ATRISK_ABSENCE_ENABLED,
  SETTING_ATRISK_ABSENCE_THRESHOLD,
  SETTING_ATRISK_HOMEWORK_ENABLED,
  SETTING_ATRISK_HOMEWORK_M,
  SETTING_ATRISK_HOMEWORK_W,
  SETTING_ATRISK_GRADE_ENABLED,
  SETTING_ATRISK_GRADE_DROP_POINTS,
  SETTING_ATRISK_PAYMENT_ENABLED,
  SETTING_ATRISK_COOLDOWN_DAYS,
};

bool isSharedSettingKey(String key) => kTeamSharedSettingKeys.contains(key);

/// الفرق اللي لازم يتطبّق على جهاز المساعد: المفاتيح المشتركة اللي قيمتها
/// عند المدرس ([remote]) مختلفة عن المحلية ([local]). قيمة null عند
/// المدرس = "الافتراضي" (المساعد يرجع للافتراضي كمان). مفاتيح مش
/// مشتركة أو مش موجودة عند المدرس بتتجاهل.
Map<String, String?> sharedSettingsToApply({
  required Map<String, String?> remote,
  required Map<String, String?> local,
}) {
  final out = <String, String?>{};
  for (final e in remote.entries) {
    if (!isSharedSettingKey(e.key)) continue;
    if (e.value != local[e.key]) out[e.key] = e.value;
  }
  return out;
}

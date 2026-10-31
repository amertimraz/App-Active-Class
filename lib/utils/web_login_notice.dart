// lib/utils/web_login_notice.dart
//
// spec 055 — رسالة واضحة على الويب لو الدخول نجح بس بيانات الفريق ماتحمّلتش
// (بدل ما التطبيق يفتح فاضي). دالة صرفة.

/// نتيجة محاولة استعادة الفريق بعد تسجيل الدخول.
class TeamRestoreStatus {
  TeamRestoreStatus._();
  static const ok = 'ok';
  static const noTeam = 'noTeam';
  static const deviceLocked = 'deviceLocked';
  static const failed = 'failed';
}

/// رسالة المستخدم للحالة؛ null لو الحالة سليمة.
String? webLoginNoticeFor(String status, {String detail = ''}) {
  switch (status) {
    case TeamRestoreStatus.ok:
      return null;
    case TeamRestoreStatus.noTeam:
      return 'الحساب ده مش مفعّل عليه وضع الفريق، فمفيش بيانات تتحمّل هنا. '
          'افتح تطبيق الموبايل ← الإعدادات ← الحساب والفريق وفعّل وضع الفريق، '
          'وبعد ما البيانات ترفع ادخل من هنا تاني.';
    case TeamRestoreStatus.deviceLocked:
      return 'حسابك مساعد ومربوط بجهاز تاني. اطلب من المدرس فك ارتباط جهازك '
          'من شاشة إدارة الأعضاء، أو تواصل معنا.';
    default:
      final base = 'اتسجّل دخولك لكن تعذّر تحميل بيانات الفريق. اتأكد من '
          'الاتصال بالإنترنت وجرّب تدخل تاني.';
      return detail.isEmpty ? base : '$base\nتفاصيل فنية: $detail';
  }
}

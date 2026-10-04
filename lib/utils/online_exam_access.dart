// lib/utils/online_exam_access.dart
//
// spec 044 — قرار توافر الامتحانات الإلكترونية (مدرس/مساعد). دالة صرفة
// بلا GetX/DB عشان تتختبر مباشرة (test/online_exam_access_test.dart) وكل
// الشاشات والخدمات تستهلكها بدل شروط متفرقة.

class OnlineExamAccess {
  /// التبويب مقفول (رسالة إضافة البوابة).
  final bool locked;

  /// يشوف القائمة والنتايج فقط بدون أي إجراء كتابي/نشر.
  final bool readOnly;

  /// زر "امتحان إلكتروني جديد" + النشر.
  final bool canCreate;

  const OnlineExamAccess({
    required this.locked,
    required this.readOnly,
    required this.canCreate,
  });

  static const lockedAccess =
      OnlineExamAccess(locked: true, readOnly: false, canCreate: false);
}

/// - خارج الفريق أو مالك: يعتمد على اشتراك جهازه ([ownPortalActive]).
/// - مساعد: يعتمد على اشتراك المدرس ([teamPortalActive])، والكتابة
///   ([canCreate]) محتاجة صلاحية [canManage] + وجود slug الفريق.
OnlineExamAccess onlineExamAccess({
  required bool inTeam,
  required bool isOwner,
  required bool canManage,
  required bool ownPortalActive,
  required bool teamPortalActive,
  required bool hasTeamSlug,
}) {
  if (!inTeam || isOwner) {
    return ownPortalActive
        ? const OnlineExamAccess(locked: false, readOnly: false, canCreate: true)
        : OnlineExamAccess.lockedAccess;
  }
  if (!teamPortalActive) return OnlineExamAccess.lockedAccess;
  final can = canManage && hasTeamSlug;
  return OnlineExamAccess(locked: false, readOnly: !can, canCreate: can);
}

/// هل اشتراك الفريق شغّال دلوقتي (enabled + لسه ماعدّاش تاريخ الانتهاء)؟
bool teamPortalActiveAt({
  required bool enabled,
  required DateTime? expiresAt,
  required DateTime now,
}) =>
    enabled && (expiresAt == null || expiresAt.isAfter(now));

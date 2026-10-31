// lib/utils/web_owner_license.dart
//
// spec 055 — على الويب مفيش ترخيص للجهاز؛ بنعرض ترخيص صاحب الفريق (قراءة بس،
// من غير ربط جهاز ولا تجربة). دالة صرفة لتحديد الحالة من بيانات مستند الترخيص.

/// حالة ترخيص صاحب الفريق: 'active' | 'expired' | 'suspended'.
String webOwnerLicenseStatus({
  required String status,
  required DateTime? expiresAt,
  required DateTime now,
}) {
  if (status == 'suspended') return 'suspended';
  if (expiresAt != null && expiresAt.isBefore(now)) return 'expired';
  return 'active';
}

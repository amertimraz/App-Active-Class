// lib/utils/cloud_backup_retry_policy.dart
//
// دالة نقية لسياسة إعادة محاولة الرفع السحابي (spec 037) — مستقلة
// تمامًا عن sync_retry_policy.dart (بلا أي علاقة بـsync_engine.dart أو
// وضع الفريق). قابلة للاختبار بمعزل عن أي شبكة أو حالة.

/// أقصى عدد محاولات فشل متتالية قبل ما نتوقف لحد النسخة الدورية الجاية.
const int kMaxCloudBackupRetries = 5;

/// هل نحاول الرفع السحابي تاني بعد [pendingRetries] فشل متتالي؟
bool shouldAttemptCloudUpload({
  required int pendingRetries,
  int maxRetries = kMaxCloudBackupRetries,
}) =>
    pendingRetries < maxRetries;

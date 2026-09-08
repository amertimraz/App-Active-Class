// lib/utils/sync_conflict.dart
//
// حسم تعارض المزامنة عند وصول صف يطابق منطقيًا صفًا محليًا بمعرّف
// مزامنة مختلف (spec 031). دالة نقية قابلة للاختبار بمعزل.

/// هل الصف الوارد (من جهاز آخر) يفوز على الصف المحلي المكرّر منطقيًا؟
///
/// - وقت وارد أحدث من المحلي → true (last-write-wins).
/// - أقدم → false.
/// - تعادل تام → الصف صاحب `remote_id` الأصغر معجميًا يفوز (حسم ثابت
///   يصل بيه كل الأجهزة لنفس النتيجة).
///
/// بعد migration وقت الخادم (spec 031)، الطوابع كلها من `now()` على
/// الخادم فالمقارنة موحّدة رغم انحراف ساعات الأجهزة.
bool syncConflictIncomingWins({
  DateTime? localUpdatedAt,
  DateTime? remoteUpdatedAt,
  required String localRemoteId,
  required String remoteRemoteId,
}) {
  if (remoteUpdatedAt == null) return false; // لا وقت وارد → مانلمسش المحلي
  if (localUpdatedAt == null) return true; // محلي بلا وقت → الوارد أولى
  final cmp = remoteUpdatedAt.compareTo(localUpdatedAt);
  if (cmp != 0) return cmp > 0;
  return remoteRemoteId.compareTo(localRemoteId) < 0;
}

// lib/utils/sync_retry_policy.dart
//
// دوال نقية لسياسة إعادة المحاولة في محرّك المزامنة (spec 030) —
// قابلة للاختبار بمعزل عن أي شبكة أو حالة.
import 'dart:async' show TimeoutException;

/// عتبة الفشل التي بعدها يُعدّ صف الطابور "مسموم" ويُتخطّى في الجولات
/// العادية.
const int kMaxOutboxFails = 5;

/// كل كام جولة drainOutbox نعيد المحاولة على الصفوف المتخطّاة.
const int kPoisonRetryEvery = 20;

/// كام نتيجة استعلام عضوية فاضية متتالية قبل ما نستنتج الإزالة فعلًا.
const int kTeamExitStreak = 3;

/// هل نحاول إرسال صف طابور عدّاد فشله [fails] في جولة [round]؟
/// - أقل من [maxFails] → دايمًا نحاول.
/// - بلغ/تجاوز [maxFails] (متخطّى) → نحاول فقط كل [poisonRetryEvery] جولة.
bool shouldAttemptOutboxRow(
  int fails,
  int round, {
  int maxFails = kMaxOutboxFails,
  int poisonRetryEvery = kPoisonRetryEvery,
}) {
  if (fails < maxFails) return true;
  return round % poisonRetryEvery == 0;
}

/// هل نُطلق إجراء الخروج من الفريق (إزالة عضو / فكّ جهاز)؟
/// يتطلب جلسة دخول صالحة **و** [emptyStreak] نتائج فاضية متتالية
/// لا تقل عن [threshold].
bool shouldFireTeamExit({
  required bool sessionUsable,
  required int emptyStreak,
  int threshold = kTeamExitStreak,
}) =>
    sessionUsable && emptyStreak >= threshold;

/// فشل مؤقت (شبكة/مهلة/بوابة/جلسة) — مش عيب في الصف نفسه. الصف ده لازم
/// يفضل في الطابور ويتعاد لحد ما النت يرجع؛ وإلا بعد ٥ فشلات (حوالي دقيقتين
/// من انقطاع النت) كان بيتمسح من الطابور وتفضل الدفعة موجودة على الجهاز ده
/// بس للأبد (بلاغ فرق المدفوعات بين المدرس والمساعد، نوفمبر 2026).
///
/// بنفحص اسم النوع بدل استيراد dart:io/supabase هنا — عشان الدالة تفضل نقية
/// وتشتغل على الويب كمان (SocketException مش موجود هناك).
bool isTransientSyncError(Object e) {
  if (e is TimeoutException) return true;
  final type = e.runtimeType.toString();
  if (type == 'SocketException' ||
      type == 'ClientException' ||
      type == 'HandshakeException' ||
      type == 'WebSocketException' ||
      type == 'TlsException' ||
      type.startsWith('Auth')) {
    return true;
  }
  if (type == 'PostgrestException') {
    String? code;
    String message = '';
    try {
      code = (e as dynamic).code?.toString();
      message = ((e as dynamic).message ?? '').toString();
    } catch (_) {}
    if (code != null) {
      // أكواد HTTP من البوابة ٣ أرقام (502/503/504) — وSQLSTATE خمس خانات
      // (42501 مثلاً) فمايتقارنش كرقم.
      final n = code.length == 3 ? int.tryParse(code) : null;
      if (n != null && n >= 500) return true;
      const transientCodes = {
        'PGRST301', // JWT expired
        'PGRST302',
        '57014', // statement timeout
        '08000',
        '08003',
        '08006', // connection failure
        '53300', // too many connections
      };
      if (transientCodes.contains(code)) return true;
    }
    final m = message.toLowerCase();
    return m.contains('timeout') ||
        m.contains('timed out') ||
        m.contains('failed host lookup') ||
        m.contains('connection');
  }
  return false;
}

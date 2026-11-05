// lib/models/free_month_promo.dart
//
// حملة «شهر مجانًا»: الأدمن بيشغّلها من لوحة الأدمن (مستند Firestore
// app_config/free_month_promo)، فيظهر للمدرس بنر تحت زر الترقية + إشعار على
// التليفون (مرة لكل تعديل للحملة). الضغط على البنر بيبعت طلب لصفحة طلبات
// الترقية في الأدمن (promo = free_month)، والأدمن بيفعّل الشهر بضغطة
// (ترخيص كامل المميزات لمدة محدّدة، ويتفعّل على جهاز المدرس تلقائيًا).

/// معرّف مستند الإعداد.
const String kFreeMonthPromoDocId = 'free_month_promo';

/// قيمة حقل promo على طلب الترقية.
const String kFreeMonthPromoTag = 'free_month';

/// الجمهور: «جدد» = تجربة جارية أو منتهية بلا ترخيص، «منتهي» = ترخيص كان
/// فعّال وانتهى.
const String kPromoAudienceNew = 'new';
const String kPromoAudienceExpired = 'expired';

/// جمهور الحملة المناسب لحالة الترخيص (اسم LicenseState)، أو null لو مش
/// مستهدف (مفعّل/موقوف/جاري التحميل).
String? promoAudienceForState(String stateName) => switch (stateName) {
      'trial' || 'trialExpired' => kPromoAudienceNew,
      'expired' => kPromoAudienceExpired,
      _ => null,
    };

class FreeMonthPromo {
  final bool enabled;
  final int days; // مدة الشهر المجاني (افتراضي 30)
  final String plan; // الباقة المفعّلة (افتراضي pro = كل المميزات)
  final String title;
  final String subtitle;

  /// مين يشوف الحملة (جدد / منتهي اشتراكهم).
  final List<String> audiences;

  /// يتبعت إشعار على التليفون؟
  final bool notify;

  /// وقت آخر حفظ للإعداد (ملّي ثانية). بيحدد «إصدار الحملة»: أي تعديل من
  /// الأدمن = إشعار جديد مرة واحدة.
  final int? updatedAtMs;

  const FreeMonthPromo({
    required this.enabled,
    this.days = 30,
    this.plan = 'pro',
    this.title = 'فعّل شهر مجانًا الآن',
    this.subtitle = 'كل المميزات لمدة شهر كامل',
    this.audiences = const [kPromoAudienceNew],
    this.notify = true,
    this.updatedAtMs,
  });

  /// مفتاح إصدار الحملة (للإشعار مرة واحدة)، أو null لو مفيش تاريخ حفظ.
  String? get campaignKey => updatedAtMs == null ? null : 'promo:$updatedAtMs';

  static const _defaults = FreeMonthPromo(enabled: false);

  static List<String> _audiencesOf(Object? raw) {
    final list = raw is List
        ? raw
            .map((e) => '$e')
            .where((e) => e == kPromoAudienceNew || e == kPromoAudienceExpired)
            .toList()
        : <String>[];
    return list.isEmpty ? const [kPromoAudienceNew] : list;
  }

  static FreeMonthPromo? fromMap(Map<String, dynamic>? m, {int? updatedAtMs}) {
    if (m == null) return null;
    int days = (m['days'] as num?)?.toInt() ?? 30;
    if (days < 1) days = 30;
    if (days > 365) days = 365;
    final title = (m['title'] as String?)?.trim() ?? '';
    final sub = (m['subtitle'] as String?)?.trim() ?? '';
    return FreeMonthPromo(
      enabled: m['enabled'] == true,
      days: days,
      plan: (m['plan'] as String?)?.trim().isNotEmpty == true
          ? (m['plan'] as String).trim()
          : 'pro',
      title: title.isEmpty ? _defaults.title : title,
      subtitle: sub.isEmpty ? _defaults.subtitle : sub,
      audiences: _audiencesOf(m['audiences']),
      notify: m['notify'] != false, // افتراضي: يتبعت إشعار
      updatedAtMs: updatedAtMs,
    );
  }

  /// من رد Firestore REST (للمهمة الخلفية — بدون Firebase في الـisolate).
  /// شكل المستند: {fields: {enabled: {booleanValue: true}, ...}}.
  static FreeMonthPromo? fromRestDocument(Map<String, dynamic> doc) {
    final fields = doc['fields'];
    if (fields is! Map) return null;
    Object? v(String k) {
      final f = fields[k];
      if (f is! Map) return null;
      if (f.containsKey('booleanValue')) return f['booleanValue'];
      if (f.containsKey('integerValue')) {
        return int.tryParse('${f['integerValue']}');
      }
      if (f.containsKey('doubleValue')) return f['doubleValue'];
      if (f.containsKey('stringValue')) return f['stringValue'];
      if (f.containsKey('timestampValue')) return f['timestampValue'];
      if (f.containsKey('arrayValue')) {
        final vals = (f['arrayValue'] as Map)['values'];
        return vals is List
            ? [
                for (final e in vals)
                  if (e is Map && e['stringValue'] != null) e['stringValue']
              ]
            : <String>[];
      }
      return null;
    }

    int? ms;
    final ts = v('updatedAt');
    if (ts is String) ms = DateTime.tryParse(ts)?.millisecondsSinceEpoch;
    return fromMap({
      'enabled': v('enabled'),
      'days': v('days'),
      'plan': v('plan'),
      'title': v('title'),
      'subtitle': v('subtitle'),
      'audiences': v('audiences'),
      'notify': v('notify'),
    }, updatedAtMs: ms);
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'days': days,
        'plan': plan,
        'title': title,
        'subtitle': subtitle,
        'audiences': audiences,
        'notify': notify,
      };
}

/// هل يظهر البنر؟ الحملة شغّالة، وجمهور المدرس ([audience]) ضمن الجمهور
/// المستهدف، ومفيش طلب قيد المراجعة، وما استخدمش الشهر المجاني قبل كده،
/// وهو مش مساعد في فريق (بيشتغل بترخيص المدرس).
bool shouldShowFreeMonthPromo({
  required FreeMonthPromo? promo,
  required String? audience,
  required bool hasPendingRequest,
  required bool alreadyUsed,
  required bool isTeamAssistant,
}) {
  if (promo == null || !promo.enabled || audience == null) return false;
  if (isTeamAssistant || alreadyUsed || hasPendingRequest) return false;
  return promo.audiences.contains(audience);
}

/// إشعار الحملة: يتبعت لو الحملة شغّالة وفيها notify، والمدرس مستهدف وغير
/// محجوب (طلب/استخدم/مساعد)، والإصدار ده ما اتبعتش قبل كده.
bool shouldNotifyFreeMonthPromo({
  required FreeMonthPromo? promo,
  required String? audience,
  required bool blocked,
  required String? lastNotifiedKey,
}) {
  if (promo == null || !promo.enabled || !promo.notify) return false;
  final key = promo.campaignKey;
  if (key == null || key == lastNotifiedKey) return false;
  if (blocked || audience == null) return false;
  return promo.audiences.contains(audience);
}

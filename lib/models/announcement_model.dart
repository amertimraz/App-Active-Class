// lib/models/announcement_model.dart
//
// spec 054 — إعلان تسويقي (خصم/عرض/تنبيه) بيكتبه الأدمن في Firestore
// (`announcements/{id}`) ويعرضه التطبيق. التحليل متسامح: أي قيمة مجهولة أو
// ناقصة بترجع لافتراضي آمن بدل ما تكسر الشاشة (إصدار تطبيق أقدم قدّام
// تصميم/لون جديد).
import 'dart:convert';

enum AnnouncementPlacement { home, plans, popup, notify }

const kAnnouncementDesigns = [
  'classic',
  'poster',
  'glass',
  'strip',
  'coupon',
  'minimal'
];
const kAnnouncementColors = [
  'purple',
  'teal',
  'coral',
  'pink',
  'blue',
  'green',
  'amber',
  'red'
];
const kAnnouncementKinds = ['deal', 'warn', 'news'];
const kAnnouncementPlans = ['trial', 'basic', 'pro', 'lifetime'];
const kAnnouncementCtaTypes = ['whatsapp', 'link', 'plans', 'none'];

class AnnouncementCta {
  final String type; // whatsapp | link | plans | none
  final String label;
  final String phone;
  final String message;
  final String url;
  const AnnouncementCta({
    this.type = 'none',
    this.label = '',
    this.phone = '',
    this.message = '',
    this.url = '',
  });

  bool get isActionable => type != 'none' && label.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        'phone': phone,
        'message': message,
        'url': url,
      };

  factory AnnouncementCta.fromMap(Object? raw) {
    if (raw is! Map) return const AnnouncementCta();
    final t = _str(raw['type']);
    return AnnouncementCta(
      type: kAnnouncementCtaTypes.contains(t) ? t : 'none',
      label: _clip(_str(raw['label']), 40),
      phone: _str(raw['phone']),
      message: _clip(_str(raw['message']), 500),
      url: _str(raw['url']),
    );
  }
}

/// نص تذكير واحد (إشعار) ضمن إعلان — بيتبعت بالتناوب بفاصل أيام.
class AnnouncementReminder {
  final String title;
  final String body;
  const AnnouncementReminder({this.title = '', this.body = ''});

  Map<String, dynamic> toJson() => {'title': title, 'body': body};

  static List<AnnouncementReminder> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <AnnouncementReminder>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final t = _clip(_str(e['title']), 60);
      if (t.isEmpty) continue;
      out.add(AnnouncementReminder(title: t, body: _clip(_str(e['body']), 240)));
      if (out.length >= kMaxReminders) break;
    }
    return out;
  }
}

const int kMaxReminders = 10;

class Announcement {
  final String id;
  final String title;
  final String body;
  final String kind;
  final String badge;
  final String design;
  final String color;
  final String couponCode;
  final bool showCountdown;
  final bool published;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final Map<AnnouncementPlacement, bool> placements;
  final List<String> audience; // فاضية = الكل
  final AnnouncementCta cta;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  /// تذكيرات الإشعار: لو فاضية الإشعار بيتبعت مرة واحدة بعنوان/نص الإعلان.
  final List<AnnouncementReminder> reminders;
  final int reminderEveryDays; // 1..14
  final int reminderHour; // 0..23

  const Announcement({
    required this.id,
    this.title = '',
    this.body = '',
    this.kind = 'news',
    this.badge = '',
    this.design = 'classic',
    this.color = 'purple',
    this.couponCode = '',
    this.showCountdown = false,
    this.published = false,
    this.startsAt,
    this.endsAt,
    this.placements = const {},
    this.audience = const [],
    this.cta = const AnnouncementCta(),
    this.publishedAt,
    this.updatedAt,
    this.reminders = const [],
    this.reminderEveryDays = 1,
    this.reminderHour = 10,
  });

  /// إصدار الإعلان — بيتغيّر مع كل حفظ (updatedAt بالمللي ثانية).
  int get version => updatedAt?.millisecondsSinceEpoch ?? 0;

  /// مفتاح "مرة واحدة": النافذة/الإشعار/إغلاق البنر بتتحفظ بيه، فتعديل
  /// الإعلان بيعيد ظهورها.
  String get displayKey => '$id:$version';

  bool shows(AnnouncementPlacement p) => placements[p] ?? false;

  /// العداد بيشتغل بس لو فيه تاريخ نهاية.
  bool get countdownEnabled => showCountdown && endsAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'kind': kind,
        'badge': badge,
        'design': design,
        'color': color,
        'couponCode': couponCode,
        'showCountdown': showCountdown,
        'status': published ? 'published' : 'draft',
        'startsAt': startsAt?.toIso8601String(),
        'endsAt': endsAt?.toIso8601String(),
        'placements': {
          for (final p in AnnouncementPlacement.values)
            p.name: placements[p] ?? false
        },
        'audience': audience,
        'cta': cta.toJson(),
        'publishedAt': publishedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'reminders': [for (final r in reminders) r.toJson()],
        'reminderEveryDays': reminderEveryDays,
        'reminderHour': reminderHour,
      };

  factory Announcement.fromMap(String id, Map<String, dynamic> m) {
    final plc = m['placements'];
    final audience = m['audience'];
    return Announcement(
      id: id,
      title: _clip(_str(m['title']), 60),
      body: _clip(_str(m['body']), 240),
      kind: _oneOf(_str(m['kind']), kAnnouncementKinds, 'news'),
      badge: _clip(_str(m['badge']), 12),
      design: _oneOf(_str(m['design']), kAnnouncementDesigns, 'classic'),
      color: _oneOf(_str(m['color']), kAnnouncementColors, 'purple'),
      couponCode: _clip(_str(m['couponCode']), 16),
      showCountdown: m['showCountdown'] == true,
      published: _str(m['status']) == 'published',
      startsAt: _dt(m['startsAt']),
      endsAt: _dt(m['endsAt']),
      placements: {
        for (final p in AnnouncementPlacement.values)
          p: plc is Map && plc[p.name] == true
      },
      audience: audience is List
          ? [
              for (final a in audience)
                if (kAnnouncementPlans.contains(a)) a as String
            ]
          : const [],
      cta: AnnouncementCta.fromMap(m['cta']),
      publishedAt: _dt(m['publishedAt']),
      updatedAt: _dt(m['updatedAt']),
      reminders: AnnouncementReminder.listFrom(m['reminders']),
      reminderEveryDays: _intIn(m['reminderEveryDays'], 1, 14, 1),
      reminderHour: _intIn(m['reminderHour'], 0, 23, 10),
    );
  }

  factory Announcement.fromJson(String source) {
    final m = jsonDecode(source) as Map<String, dynamic>;
    return Announcement.fromMap(m['id'] as String? ?? '', m);
  }

  String toJsonString() => jsonEncode(toJson());

  /// مستند Firestore REST (`{name, fields:{...}}`) — للمهمة الخلفية.
  factory Announcement.fromRestDocument(Map<String, dynamic> doc) {
    final name = _str(doc['name']);
    final id = name.contains('/') ? name.split('/').last : name;
    final fields = doc['fields'];
    final decoded = fields is Map
        ? {
            for (final e in fields.entries)
              e.key as String: _decodeRestValue(e.value)
          }
        : <String, dynamic>{};
    return Announcement.fromMap(id, decoded);
  }
}

/// فك قيمة Firestore REST المطبوعة (`{stringValue: ..}` إلخ) لقيمة Dart عادية.
Object? _decodeRestValue(Object? v) {
  if (v is! Map) return null;
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('integerValue')) {
    return int.tryParse('${v['integerValue']}');
  }
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num?)?.toDouble();
  if (v.containsKey('timestampValue')) return v['timestampValue'];
  if (v.containsKey('nullValue')) return null;
  if (v.containsKey('arrayValue')) {
    final vals = (v['arrayValue'] as Map?)?['values'];
    return vals is List ? [for (final x in vals) _decodeRestValue(x)] : <Object?>[];
  }
  if (v.containsKey('mapValue')) {
    final f = (v['mapValue'] as Map?)?['fields'];
    return f is Map
        ? {for (final e in f.entries) e.key as String: _decodeRestValue(e.value)}
        : <String, dynamic>{};
  }
  return null;
}

int _intIn(Object? v, int lo, int hi, int fallback) {
  final n = v is num ? v.toInt() : null;
  return n == null || n < lo || n > hi ? fallback : n;
}

String _str(Object? v) => v is String ? v.trim() : '';

String _clip(String s, int max) => s.length > max ? s.substring(0, max) : s;

String _oneOf(String v, List<String> allowed, String fallback) =>
    allowed.contains(v) ? v : fallback;

/// Timestamp (Firestore SDK) / DateTime / ISO string / ms — لأي مصدر.
DateTime? _dt(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  try {
    return ((v as dynamic).toDate() as DateTime).toLocal();
  } catch (_) {
    return null;
  }
}

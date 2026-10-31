// test/announcement_logic_test.dart — spec 054
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/announcement_model.dart';
import 'package:active_class/utils/announcement_logic.dart';

final now = DateTime(2026, 10, 29, 12, 0);

Announcement ann(
  String id, {
  bool published = true,
  DateTime? startsAt,
  DateTime? endsAt,
  Map<AnnouncementPlacement, bool>? placements,
  List<String> audience = const [],
  DateTime? publishedAt,
  DateTime? updatedAt,
}) =>
    Announcement(
      id: id,
      title: 't$id',
      body: 'b',
      published: published,
      startsAt: startsAt,
      endsAt: endsAt,
      placements: placements ?? {AnnouncementPlacement.home: true},
      audience: audience,
      publishedAt: publishedAt ?? DateTime(2026, 10, 1),
      updatedAt: updatedAt ?? DateTime(2026, 10, 1),
    );

void main() {
  durationTests();
  group('النشاط والحالة', () {
    test('داخل النطاق، قبل البداية، بعد النهاية، بلا نهاية', () {
      expect(
          isAnnouncementActive(
              ann('a', startsAt: now.subtract(const Duration(hours: 1)), endsAt: now.add(const Duration(hours: 1))), now),
          isTrue);
      expect(
          isAnnouncementActive(ann('a', startsAt: now.add(const Duration(minutes: 1))), now),
          isFalse);
      expect(
          isAnnouncementActive(ann('a', endsAt: now.subtract(const Duration(seconds: 1))), now),
          isFalse);
      expect(isAnnouncementActive(ann('a'), now), isTrue);
    });
    test('النهاية بالظبط = منتهي', () {
      expect(isAnnouncementActive(ann('a', endsAt: now), now), isFalse);
    });
    test('الحالات الأربع', () {
      expect(announcementStatus(ann('a', published: false), now), AnnouncementStatus.draft);
      expect(announcementStatus(ann('a', startsAt: now.add(const Duration(days: 1))), now), AnnouncementStatus.scheduled);
      expect(announcementStatus(ann('a'), now), AnnouncementStatus.active);
      expect(announcementStatus(ann('a', endsAt: now.subtract(const Duration(days: 1))), now), AnnouncementStatus.expired);
    });
  });

  group('الجمهور', () {
    test('فاضي = الكل', () {
      expect(matchesAudience(ann('a'), 'trial'), isTrue);
      expect(matchesAudience(ann('a'), 'lifetime'), isTrue);
    });
    test('محدد', () {
      final a = ann('a', audience: ['trial']);
      expect(matchesAudience(a, 'trial'), isTrue);
      expect(matchesAudience(a, 'basic'), isFalse);
      final b = ann('b', audience: ['basic', 'pro']);
      expect(matchesAudience(b, 'lifetime'), isFalse);
      expect(matchesAudience(b, 'pro'), isTrue);
    });
  });

  group('pickAnnouncement', () {
    Announcement? pick(List<Announcement> l, {String plan = 'basic', AnnouncementPlacement p = AnnouncementPlacement.home}) =>
        pickAnnouncement(l, now: now, planKey: plan, placement: p);

    test('الأحدث نشرًا يكسب', () {
      final old = ann('old', publishedAt: DateTime(2026, 10, 1));
      final fresh = ann('new', publishedAt: DateTime(2026, 10, 20));
      expect(pick([old, fresh])!.id, 'new');
    });
    test('المسودة والمنتهي والمجدول يُستبعدون', () {
      expect(pick([ann('d', published: false)]), isNull);
      expect(pick([ann('e', endsAt: now.subtract(const Duration(days: 1)))]), isNull);
      expect(pick([ann('s', startsAt: now.add(const Duration(days: 1)))]), isNull);
    });
    test('المكان المعطّل', () {
      final a = ann('a', placements: {AnnouncementPlacement.plans: true});
      expect(pick([a]), isNull);
      expect(pick([a], p: AnnouncementPlacement.plans)!.id, 'a');
    });
    test('خارج الجمهور', () {
      expect(pick([ann('a', audience: ['trial'])], plan: 'pro'), isNull);
    });
    test('الأحدث غير المناسب لا يحجب الأقدم المناسب', () {
      final fit = ann('fit', publishedAt: DateTime(2026, 10, 1));
      final other = ann('other', audience: ['trial'], publishedAt: DateTime(2026, 10, 20));
      expect(pick([fit, other], plan: 'pro')!.id, 'fit');
    });
    test('قائمة فاضية', () => expect(pick(const []), isNull));
  });

  group('مرة واحدة والإشعار', () {
    test('shouldShowOnce', () {
      expect(shouldShowOnce(null, 'a:1'), isTrue);
      expect(shouldShowOnce('a:1', 'a:1'), isFalse);
      expect(shouldShowOnce('a:1', 'a:2'), isTrue);
    });
    test('announcementToNotify', () {
      final a = ann('a', placements: {AnnouncementPlacement.notify: true}, updatedAt: DateTime(2026, 10, 2));
      expect(announcementToNotify([a], now: now, planKey: 'basic')!.id, 'a');
      expect(announcementToNotify([a], now: now, planKey: 'basic', lastNotifiedKey: a.displayKey), isNull);
      final edited = ann('a', placements: {AnnouncementPlacement.notify: true}, updatedAt: DateTime(2026, 10, 3));
      expect(announcementToNotify([edited], now: now, planKey: 'basic', lastNotifiedKey: a.displayKey)!.id, 'a');
      final expired = ann('a', placements: {AnnouncementPlacement.notify: true}, endsAt: now.subtract(const Duration(minutes: 1)));
      expect(announcementToNotify([expired], now: now, planKey: 'basic'), isNull);
    });
  });

  group('العداد', () {
    test('تفصيل الوقت', () {
      final end = now.add(const Duration(days: 3, hours: 4, minutes: 27, seconds: 12));
      final p = countdownParts(end, now);
      expect([p.days, p.hours, p.minutes, p.seconds], [3, 4, 27, 12]);
      expect(p.isZero, isFalse);
    });
    test('الصفر لا يقل عنه', () {
      expect(countdownParts(now, now).isZero, isTrue);
      expect(countdownParts(now.subtract(const Duration(hours: 5)), now).isZero, isTrue);
    });
  });

  group('روابط آمنة', () {
    test('http/https فقط', () {
      expect(safeHttpUrl('https://active-class.online/x'), isNotNull);
      expect(safeHttpUrl('http://a.com'), isNotNull);
      expect(safeHttpUrl('javascript:alert(1)'), isNull);
      expect(safeHttpUrl('active-class.online'), isNull);
      expect(safeHttpUrl('ftp://a.com'), isNull);
      expect(safeHttpUrl(''), isNull);
      expect(safeHttpUrl(null), isNull);
      expect(safeHttpUrl('https://'), isNull);
    });
    test('تنظيف رقم واتساب', () {
      expect(cleanWhatsappPhone('+20 101-234-5678'), '201012345678');
      expect(cleanWhatsappPhone('123'), isNull);
      expect(cleanWhatsappPhone('1' * 16), isNull);
      expect(cleanWhatsappPhone(null), isNull);
    });
    test('رابط واتساب برسالة وبيانات المدرس', () {
      final u = announcementWhatsappUri(
        phone: '+201012345678',
        message: 'عايز الخصم',
        name: 'حازم',
        code: 'ACTV-1',
        planName: 'أساسي',
      )!;
      expect(u.host, 'wa.me');
      expect(u.path, '/201012345678');
      final t = u.queryParameters['text']!;
      expect(t.split('\n'), ['عايز الخصم', 'الاسم: حازم', 'الكود: ACTV-1', 'الباقة: أساسي']);
    });
    test('الأسطر الفاضية تُحذف ورقم غير صالح null', () {
      final u = announcementWhatsappUri(phone: '201012345678', message: '', name: '', code: '', planName: '')!;
      expect(u.hasQuery, isFalse);
      expect(announcementWhatsappUri(phone: 'abc', message: 'x'), isNull);
    });
  });
}

void durationTests() {
  group('formatArabicDuration', () {
    String f(int d, int h, int m, int s) => formatArabicDuration(
        Duration(days: d, hours: h, minutes: m, seconds: s));
    test('أمثلة أساسية', () {
      expect(f(0, 3, 2, 5), '3 ساعات ودقيقتين و5 ثواني');
      expect(f(0, 1, 1, 1), 'ساعة ودقيقة وثانية');
      expect(f(2, 0, 0, 0), 'يومين');
      expect(f(1, 2, 0, 10), 'يوم وساعتين و10 ثواني');
    });
    test('بتخفي الوحدات الفاضية من الأول والنص', () {
      expect(f(0, 0, 5, 0), '5 دقائق');
      expect(f(0, 0, 0, 45), '45 ثانية');
      expect(f(0, 0, 0, 2), 'ثانيتين');
      expect(f(0, 0, 0, 0), '0 ثانية');
    });
    test('الجمع والمفرد (11 فما فوق مفرد)', () {
      expect(f(11, 11, 11, 11), '11 يوم و11 ساعة و11 دقيقة و11 ثانية');
      expect(f(4, 10, 3, 0), '4 أيام و10 ساعات و3 دقائق');
    });
    test('سالب = صفر', () {
      expect(formatArabicDuration(const Duration(seconds: -5)), '0 ثانية');
    });
  });
}

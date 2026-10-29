// test/announcement_model_test.dart — spec 054
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/announcement_model.dart';

Map<String, dynamic> full() => {
      'title': 'خصم 30%',
      'body': 'اشترك الآن',
      'kind': 'deal',
      'badge': '-30%',
      'design': 'coupon',
      'color': 'teal',
      'couponCode': 'BF30',
      'showCountdown': true,
      'status': 'published',
      'startsAt': '2026-10-29T00:00:00Z',
      'endsAt': '2026-11-01T00:00:00Z',
      'placements': {'home': true, 'plans': true, 'popup': false, 'notify': true},
      'audience': ['trial', 'basic'],
      'cta': {
        'type': 'whatsapp',
        'label': 'احجز',
        'phone': '201012345678',
        'message': 'عايز الخصم'
      },
      'publishedAt': '2026-10-29T08:00:00Z',
      'updatedAt': '2026-10-29T09:00:00Z',
    };

void main() {
  test('تحليل كامل', () {
    final a = Announcement.fromMap('x1', full());
    expect(a.id, 'x1');
    expect(a.design, 'coupon');
    expect(a.color, 'teal');
    expect(a.published, isTrue);
    expect(a.shows(AnnouncementPlacement.home), isTrue);
    expect(a.shows(AnnouncementPlacement.popup), isFalse);
    expect(a.audience, ['trial', 'basic']);
    expect(a.cta.type, 'whatsapp');
    expect(a.cta.isActionable, isTrue);
    expect(a.countdownEnabled, isTrue);
    expect(a.endsAt, isNotNull);
    expect(a.displayKey, 'x1:${a.updatedAt!.millisecondsSinceEpoch}');
  });

  test('قيم مجهولة/ناقصة ترجع لافتراضات آمنة', () {
    final a = Announcement.fromMap('x', {
      'title': 't',
      'design': 'hologram',
      'color': 'neon',
      'kind': '???',
      'audience': ['trial', 'vip', 5],
      'cta': {'type': 'teleport'},
    });
    expect(a.design, 'classic');
    expect(a.color, 'purple');
    expect(a.kind, 'news');
    expect(a.audience, ['trial']);
    expect(a.cta.type, 'none');
    expect(a.published, isFalse);
    expect(a.version, 0);
    for (final p in AnnouncementPlacement.values) {
      expect(a.shows(p), isFalse);
    }
  });

  test('عداد بلا تاريخ نهاية لا يُفعَّل', () {
    final m = full()..remove('endsAt');
    expect(Announcement.fromMap('x', m).countdownEnabled, isFalse);
  });

  test('حدود الأطوال', () {
    final a = Announcement.fromMap('x', {
      'title': 'ع' * 200,
      'body': 'ع' * 1000,
      'badge': 'ع' * 50,
    });
    expect(a.title.length, 60);
    expect(a.body.length, 240);
    expect(a.badge.length, 12);
  });

  test('نص فيه HTML يبقى حرفيًا', () {
    final a = Announcement.fromMap('x', {'title': '<b>خصم</b>'});
    expect(a.title, '<b>خصم</b>');
  });

  test('JSON ذهابًا وإيابًا', () {
    final a = Announcement.fromMap('x1', full());
    final b = Announcement.fromJson(a.toJsonString());
    expect(b.id, 'x1');
    expect(b.title, a.title);
    expect(b.design, a.design);
    expect(b.audience, a.audience);
    expect(b.shows(AnnouncementPlacement.notify), isTrue);
    expect(b.endsAt, a.endsAt);
    expect(b.cta.phone, a.cta.phone);
    expect(b.version, a.version);
  });

  test('مستند Firestore REST بكل الأنواع', () {
    final doc = {
      'name':
          'projects/p/databases/(default)/documents/announcements/abc123',
      'fields': {
        'title': {'stringValue': 'خصم'},
        'body': {'stringValue': 'نص'},
        'status': {'stringValue': 'published'},
        'design': {'stringValue': 'poster'},
        'color': {'stringValue': 'coral'},
        'showCountdown': {'booleanValue': true},
        'endsAt': {'timestampValue': '2026-11-01T00:00:00Z'},
        'updatedAt': {'timestampValue': '2026-10-29T09:00:00Z'},
        'placements': {
          'mapValue': {
            'fields': {
              'home': {'booleanValue': true},
              'notify': {'booleanValue': true},
              'popup': {'booleanValue': false},
            }
          }
        },
        'audience': {
          'arrayValue': {
            'values': [
              {'stringValue': 'pro'},
              {'stringValue': 'lifetime'}
            ]
          }
        },
        'cta': {
          'mapValue': {
            'fields': {
              'type': {'stringValue': 'plans'},
              'label': {'stringValue': 'الباقات'},
            }
          }
        },
        'extra': {'nullValue': null},
      },
    };
    final a = Announcement.fromRestDocument(doc);
    expect(a.id, 'abc123');
    expect(a.published, isTrue);
    expect(a.design, 'poster');
    expect(a.shows(AnnouncementPlacement.notify), isTrue);
    expect(a.shows(AnnouncementPlacement.plans), isFalse);
    expect(a.audience, ['pro', 'lifetime']);
    expect(a.cta.type, 'plans');
    expect(a.endsAt!.toUtc(), DateTime.utc(2026, 11, 1));
    expect(a.countdownEnabled, isTrue);
  });

  test('مستند REST فارغ لا يكسر', () {
    final a = Announcement.fromRestDocument({'name': 'x/announcements/z'});
    expect(a.id, 'z');
    expect(a.published, isFalse);
  });
}

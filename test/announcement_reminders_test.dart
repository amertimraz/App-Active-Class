// test/announcement_reminders_test.dart — spec 054 (تذكيرات الإشعارات)
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/models/announcement_model.dart';
import 'package:active_class/services/announcement_background.dart';
import 'package:active_class/utils/announcement_logic.dart';

const three = [
  AnnouncementReminder(title: 'تذكير 1', body: 'نص 1'),
  AnnouncementReminder(title: 'تذكير 2', body: 'نص 2'),
  AnnouncementReminder(title: 'تذكير 3', body: ''),
];

Announcement ann({
  List<AnnouncementReminder> reminders = three,
  int every = 2,
  int hour = 10,
  DateTime? startsAt,
  DateTime? publishedAt,
  DateTime? endsAt,
}) =>
    Announcement(
      id: 'a',
      title: 'خصم',
      body: 'نص الإعلان',
      published: true,
      startsAt: startsAt ?? DateTime(2026, 10, 29),
      publishedAt: publishedAt ?? DateTime(2026, 10, 28),
      endsAt: endsAt,
      placements: const {AnnouncementPlacement.notify: true},
      reminders: reminders,
      reminderEveryDays: every,
      reminderHour: hour,
      updatedAt: DateTime(2026, 10, 28),
    );

AnnouncementNotification? at(Announcement a, DateTime now, {String? last}) =>
    notificationToSend([a], now: now, planKey: 'basic', lastNotifiedKey: last);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('currentReminderSlot', () {
    final a = ann();
    test('قبل ساعة أول دورة أو قبل البداية → -1', () {
      expect(currentReminderSlot(a, DateTime(2026, 10, 29, 9)), -1);
      expect(currentReminderSlot(a, DateTime(2026, 10, 28, 23)), -1);
    });
    test('الدورات بفاصل يومين عند الساعة', () {
      expect(currentReminderSlot(a, DateTime(2026, 10, 29, 10)), 0);
      expect(currentReminderSlot(a, DateTime(2026, 10, 30, 23)), 0);
      expect(currentReminderSlot(a, DateTime(2026, 10, 31, 9, 59)), 0);
      expect(currentReminderSlot(a, DateTime(2026, 10, 31, 10)), 1);
      expect(currentReminderSlot(a, DateTime(2026, 11, 4, 11)), 3);
    });
    test('فاصل يوم واحد', () {
      final d = ann(every: 1);
      expect(currentReminderSlot(d, DateTime(2026, 10, 30, 11)), 1);
    });
  });

  group('notificationToSend', () {
    final a = ann();
    test('نص مختلف في كل دورة بالتناوب', () {
      expect(at(a, DateTime(2026, 10, 29, 10, 30))!.title, 'تذكير 1');
      expect(at(a, DateTime(2026, 10, 31, 10, 5))!.title, 'تذكير 2');
      expect(at(a, DateTime(2026, 11, 2, 10, 5))!.title, 'تذكير 3');
      expect(at(a, DateTime(2026, 11, 4, 10, 5))!.title, 'تذكير 1'); // يدور
    });
    test('نص فاضي يرجع لنص الإعلان', () {
      expect(at(a, DateTime(2026, 11, 2, 10, 5))!.body, 'نص الإعلان');
    });
    test('مرة لكل دورة (لا تكرار في نفس الدورة)', () {
      final first = at(a, DateTime(2026, 10, 29, 10, 30))!;
      expect(at(a, DateTime(2026, 10, 30, 12), last: first.key), isNull);
      expect(at(a, DateTime(2026, 10, 31, 10), last: first.key), isNotNull);
    });
    test('بعد غياب طويل بتتبعت آخر دورة بس', () {
      final n = at(a, DateTime(2026, 11, 10, 12))!;
      expect(n.key.endsWith('#6'), isTrue); // 12 يوم / فاصل 2
    });
    test('تعديل الإعلان يغيّر المفتاح فيتبعت تاني', () {
      final first = at(a, DateTime(2026, 10, 29, 10, 30))!;
      final edited = Announcement(
        id: 'a',
        title: 'خصم',
        body: 'نص',
        published: true,
        startsAt: DateTime(2026, 10, 29),
        placements: const {AnnouncementPlacement.notify: true},
        reminders: three,
        reminderEveryDays: 2,
        reminderHour: 10,
        updatedAt: DateTime(2026, 10, 29, 9),
      );
      expect(at(edited, DateTime(2026, 10, 29, 10, 30), last: first.key), isNotNull);
    });
    test('منتهٍ أو مجدول → لا شيء', () {
      expect(at(ann(endsAt: DateTime(2026, 10, 30)), DateTime(2026, 10, 31, 11)), isNull);
      expect(at(a, DateTime(2026, 10, 20, 11)), isNull);
    });
    test('بدون تذكيرات: إشعار واحد بعنوان الإعلان مرة واحدة', () {
      final s = ann(reminders: const []);
      final n = at(s, DateTime(2026, 10, 29, 12))!;
      expect(n.title, 'خصم');
      expect(at(s, DateTime(2026, 11, 3, 12), last: n.key), isNull);
    });
    test('نُشر بعد الساعة → أول تذكير فورًا', () {
      final late = ann(startsAt: DateTime(2026, 10, 29), hour: 8);
      expect(at(late, DateTime(2026, 10, 29, 15))!.title, 'تذكير 1');
    });
  });

  group('تحليل التذكيرات', () {
    test('من map: تنظيف وحد أقصى 10 وتجاهل بلا عنوان', () {
      final a = Announcement.fromMap('x', {
        'reminders': [
          for (var i = 0; i < 15; i++) {'title': 't$i', 'body': 'b'},
          {'title': '', 'body': 'x'},
        ],
        'reminderEveryDays': 99,
        'reminderHour': 30,
      });
      expect(a.reminders.length, kMaxReminders);
      expect(a.reminderEveryDays, 1); // خارج النطاق → افتراضي
      expect(a.reminderHour, 10);
    });
    test('JSON ذهابًا وإيابًا', () {
      final a = Announcement.fromMap('x', {
        'reminders': [
          {'title': 'أ', 'body': 'ب'}
        ],
        'reminderEveryDays': 3,
        'reminderHour': 18,
      });
      final b = Announcement.fromJson(a.toJsonString());
      expect(b.reminders.single.title, 'أ');
      expect(b.reminderEveryDays, 3);
      expect(b.reminderHour, 18);
    });
  });

  group('المهمة الخلفية مع التذكيرات', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    test('تبعت نص الدورة ولا تكرر في نفس الدورة', () async {
      final titles = <String>[];
      Future<void> run(DateTime t) => runAnnouncementBackgroundCheck(
          fetch: () async => [ann()],
          show: (n) async => titles.add(n.title),
          now: t);
      await run(DateTime(2026, 10, 29, 10, 30));
      await run(DateTime(2026, 10, 29, 13));
      await run(DateTime(2026, 10, 30, 13));
      await run(DateTime(2026, 10, 31, 11));
      expect(titles, ['تذكير 1', 'تذكير 2']);
    });
  });
}

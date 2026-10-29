// test/announcement_background_test.dart — spec 054
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/models/announcement_model.dart';
import 'package:active_class/services/announcement_background.dart';
import 'package:active_class/services/announcement_service.dart';

final now = DateTime(2026, 10, 29, 12);

Announcement ann({
  String id = 'a',
  bool notify = true,
  List<String> audience = const [],
  DateTime? endsAt,
  DateTime? updatedAt,
}) =>
    Announcement(
      id: id,
      title: 'خصم',
      body: 'نص',
      published: true,
      endsAt: endsAt,
      placements: {AnnouncementPlacement.notify: notify},
      audience: audience,
      publishedAt: DateTime(2026, 10, 1),
      updatedAt: updatedAt ?? DateTime(2026, 10, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<int> run(List<Announcement> items) async {
    var shown = 0;
    await runAnnouncementBackgroundCheck(
        fetch: () async => items, show: (_) async => shown++, now: now);
    return shown;
  }

  test('إشعار واحد ثم لا تكرار في الدورات التالية', () async {
    expect(await run([ann()]), 1);
    expect(await run([ann()]), 0);
    expect(await run([ann()]), 0);
  });

  test('تعديل الإعلان يرسل إشعارًا جديدًا', () async {
    expect(await run([ann()]), 1);
    expect(await run([ann(updatedAt: DateTime(2026, 10, 9))]), 1);
  });

  test('منتهٍ أو مكان معطّل أو قائمة فاضية → لا إشعار', () async {
    expect(await run([ann(endsAt: now.subtract(const Duration(minutes: 1)))]), 0);
    expect(await run([ann(notify: false)]), 0);
    expect(await run(const []), 0);
  });

  test('الباقة من SharedPreferences (الافتراضي trial)', () async {
    expect(await run([ann(audience: ['pro'])]), 0); // trial افتراضيًا
    SharedPreferences.setMockInitialValues({kAnnPlanKey: 'pro'});
    expect(await run([ann(audience: ['pro'])]), 1);
  });

  test('فشل الجلب أو الإظهار لا يرمي ويرجع true', () async {
    expect(
        await runAnnouncementBackgroundCheck(
            fetch: () async => throw Exception('net'), now: now),
        isTrue);
    expect(
        await runAnnouncementBackgroundCheck(
            fetch: () async => [ann()],
            show: (_) async => throw Exception('ui'),
            now: now),
        isTrue);
  });

  test('مفتاح مختلف للإعلان يحجز قبل الإظهار (لا إشعار مزدوج)', () async {
    SharedPreferences.setMockInitialValues({});
    await run([ann()]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kAnnNotifiedKey), startsWith('a:'));
  });
}

// test/announcement_controller_test.dart — spec 054
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/controllers/announcement_controller.dart';
import 'package:active_class/models/announcement_model.dart';
import 'package:active_class/services/announcement_service.dart';

Announcement ann(String id,
        {Map<AnnouncementPlacement, bool>? placements,
        List<String> audience = const [],
        DateTime? endsAt,
        DateTime? updatedAt}) =>
    Announcement(
      id: id,
      title: 't',
      body: 'b',
      published: true,
      endsAt: endsAt,
      placements: placements ?? {AnnouncementPlacement.home: true},
      audience: audience,
      publishedAt: DateTime(2026, 10, 1),
      updatedAt: updatedAt ?? DateTime(2026, 10, 1),
    );

Future<AnnouncementController> make(
  List<Announcement> items, {
  String plan = 'basic',
  DateTime? now,
}) async {
  Get.reset();
  final svc = AnnouncementService.instance;
  await svc.saveCache(items);
  final c = AnnouncementController(
      clock: () => now ?? DateTime(2026, 10, 29, 12),
      planKey: () => plan,
      listenRemote: false);
  Get.put(c);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);

  test('الاختيار حسب الباقة والمكان من الكاش', () async {
    final c = await make([
      ann('a', audience: ['trial']),
      ann('b', placements: {AnnouncementPlacement.plans: true}),
    ]);
    expect(c.forPlacement(AnnouncementPlacement.home), isNull); // trial فقط وباقتي basic
    expect(c.forPlacement(AnnouncementPlacement.plans)!.id, 'b');
  });

  test('تغيّر الباقة يغيّر الاختيار', () async {
    final trial = await make([ann('a', audience: ['trial'])], plan: 'trial');
    expect(trial.forPlacement(AnnouncementPlacement.home)!.id, 'a');
  });

  test('الإغلاق يُحفظ ويعود عند تغيّر الإصدار', () async {
    final a = ann('a');
    final c = await make([a]);
    expect(c.forPlacement(AnnouncementPlacement.home), isNotNull);
    await c.dismiss(AnnouncementPlacement.home, a);
    expect(c.forPlacement(AnnouncementPlacement.home), isNull);
    // تحميل جديد (إعادة فتح): الإغلاق محفوظ
    final c2 = await make([a]);
    expect(c2.forPlacement(AnnouncementPlacement.home), isNull);
    // تعديل الإعلان → إصدار جديد → يظهر
    final c3 = await make([ann('a', updatedAt: DateTime(2026, 10, 5))]);
    expect(c3.forPlacement(AnnouncementPlacement.home), isNotNull);
  });

  test('المنتهي من الكاش لا يظهر', () async {
    final c = await make([ann('a', endsAt: DateTime(2026, 10, 29, 11))]);
    expect(c.forPlacement(AnnouncementPlacement.home), isNull);
  });

  test('النافذة مرة واحدة لكل إصدار، وتعديل الإعلان يعيدها', () async {
    final pop = {AnnouncementPlacement.popup: true};
    final c = await make([ann('a', placements: pop)]);
    expect((await c.takePopup())!.id, 'a');
    expect(await c.takePopup(), isNull);
    final edited = await make([ann('a', placements: pop, updatedAt: DateTime(2026, 10, 9))]);
    expect((await edited.takePopup())!.id, 'a');
  });

  test('النافذة: لا تظهر خارج الجمهور أو لو المكان معطّل', () async {
    final pop = {AnnouncementPlacement.popup: true};
    final c = await make([ann('a', placements: pop, audience: ['trial'])], plan: 'pro');
    expect(await c.takePopup(), isNull);
    final d = await make([ann('a')]); // home فقط
    expect(await d.takePopup(), isNull);
  });

  test('REST: تحليل الرد يبقي المنشور فقط', () {
    const body = '''
{"documents":[
 {"name":"x/announcements/a","fields":{"title":{"stringValue":"ن"},"status":{"stringValue":"published"}}},
 {"name":"x/announcements/b","fields":{"title":{"stringValue":"م"},"status":{"stringValue":"draft"}}}
]}''';
    final list = AnnouncementService.parseRestListResponse(body);
    expect(list.map((a) => a.id), ['a']);
    expect(AnnouncementService.parseRestListResponse('{}'), isEmpty);
  });
}

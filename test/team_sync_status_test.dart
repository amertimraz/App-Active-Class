// تصنيف صحّة المزامنة، نصوص الأوقات، وwidgets السحابة وقايمة أجهزة الفريق.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/device_sync_status.dart';
import 'package:active_class/views/team/team_sync_widgets.dart';

Widget _host(Widget child, {bool dark = false, double scale = 1}) => MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: TextDirection.rtl, child: w!),
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

DeviceSyncStatus _dev({
  String name = 'سعد',
  bool owner = false,
  int pending = 0,
  int unsynced = 0,
  String? error,
  Duration since = const Duration(seconds: 20),
}) =>
    DeviceSyncStatus(
      deviceId: 'd1',
      name: name,
      isOwner: owner,
      pending: pending,
      unsynced: unsynced,
      lastPushAt: null,
      lastPullAt: null,
      lastError: error,
      appVersion: '1.2.85+4103',
      sinceUpdate: since,
      sincePush: const Duration(minutes: 3),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  group('classifySyncHealth', () {
    test('متزامن لما مفيش معلّق ولا ناقص', () {
      expect(classifySyncHealth(pending: 0, unsynced: 0), SyncHealth.ok);
    });
    test('معلّق بيتصفّى = pending', () {
      expect(classifySyncHealth(pending: 5, unsynced: 0), SyncHealth.pending);
    });
    test('صفوف ناقصة (اتشالت من الطابور) = stuck حتى من غير خطأ', () {
      expect(classifySyncHealth(pending: 0, unsynced: 30), SyncHealth.stuck);
    });
    test('خطأ حقيقي مع معلّق = stuck، وخطأ شبكة مؤقت = pending', () {
      expect(
          classifySyncHealth(pending: 3, unsynced: 0, lastError: 'RLS'),
          SyncHealth.stuck);
      expect(
          classifySyncHealth(
              pending: 3, unsynced: 0, lastError: 'timeout', errorTransient: true),
          SyncHealth.pending);
    });
    test('مفيش اتصال من ساعة = stale (يغلب أي حاجة)', () {
      expect(
          classifySyncHealth(
              pending: 0,
              unsynced: 0,
              sinceLastContact: const Duration(hours: 2)),
          SyncHealth.stale);
    });
    test('خطأ قديم من غير معلّق ولا ناقص = ok', () {
      expect(classifySyncHealth(pending: 0, unsynced: 0, lastError: 'x'),
          SyncHealth.ok);
    });
  });

  test('agoText', () {
    expect(agoText(const Duration(seconds: 10)), 'دلوقتي');
    expect(agoText(const Duration(minutes: 1)), 'من دقيقة');
    expect(agoText(const Duration(minutes: 2)), 'من دقيقتين');
    expect(agoText(const Duration(minutes: 7)), 'من 7 دقايق');
    expect(agoText(const Duration(hours: 2)), 'من ساعتين');
    expect(agoText(const Duration(hours: 5)), 'من 5 ساعات');
    expect(agoText(const Duration(days: 3)), 'من 3 أيام');
  });

  test('DeviceSyncStatus.fromRow بيحسب الأعمار بوقت السيرفر', () {
    final s = DeviceSyncStatus.fromRow({
      'device_id': 'abc',
      'display_name': '  ',
      'is_owner': false,
      'pending': 0,
      'unsynced': 30,
      'last_push_at': '2026-11-08T09:00:00+00:00',
      'last_pull_at': null,
      'last_error': null,
      'app_version': '1.2.84',
      'updated_at': '2026-11-08T09:10:00+00:00',
      'server_now': '2026-11-08T09:12:00+00:00',
    });
    expect(s.name, 'عضو'); // اسم فاضي
    expect(s.sinceUpdate, const Duration(minutes: 2));
    expect(s.sincePush, const Duration(minutes: 12));
    expect(s.sincePull, isNull);
    expect(s.health, SyncHealth.stuck);
  });

  group('السحابة', () {
    for (final h in SyncHealth.values) {
      for (final dark in [false, true]) {
        testWidgets('بلا overflow ×1.6 على 320: $h dark=$dark', (tester) async {
          tester.view.physicalSize = const Size(640, 1136);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_host(
              SyncCloudView(
                  health: h,
                  pending: 4,
                  unsynced: 30,
                  lastError: 'new row violates row-level security policy',
                  isDark: dark,
                  onUploadNow: () {}),
              dark: dark,
              scale: 1.6));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('عالق: بيعرض العدد وزرار ارفع دلوقتي', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_host(SyncCloudView(
          health: SyncHealth.stuck,
          pending: 0,
          unsynced: 30,
          isDark: false,
          onUploadNow: () => tapped++)));
      expect(find.text('30 صف ما وصلش للفريق'), findsOneWidget);
      await tester.tap(find.text('ارفع دلوقتي'));
      expect(tapped, 1);
    });

    testWidgets('متزامن: مفيش زرار', (tester) async {
      await tester.pumpWidget(_host(const SyncCloudView(
          health: SyncHealth.ok, pending: 0, unsynced: 0, isDark: false)));
      expect(find.text('كل بياناتك متزامنة مع الفريق'), findsOneWidget);
      expect(find.text('ارفع دلوقتي'), findsNothing);
    });
  });

  group('قايمة أجهزة الفريق', () {
    for (final dark in [false, true]) {
      testWidgets('بلا overflow ×1.6 على 320 dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
            Column(children: [
              DeviceStatusTile(
                  status: _dev(name: 'الدكتور حازم خضر الطويل جدًا', owner: true),
                  isMe: true,
                  isDark: dark),
              DeviceStatusTile(
                  status: _dev(unsynced: 30, error: 'violates row-level security'),
                  isMe: false,
                  isDark: dark),
              DeviceStatusTile(
                  status: _dev(since: const Duration(hours: 5)),
                  isMe: false,
                  isDark: dark),
            ]),
            dark: dark,
            scale: 1.6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('بيعرض حالة كل جهاز بنصها', (tester) async {
      await tester.pumpWidget(_host(Column(children: [
        DeviceStatusTile(status: _dev(), isMe: true, isDark: false),
        DeviceStatusTile(
            status: _dev(name: 'مساعد', unsynced: 30), isMe: false, isDark: false),
        DeviceStatusTile(
            status: _dev(name: 'قديم', since: const Duration(hours: 3)),
            isMe: false,
            isDark: false),
      ])));
      expect(find.text('متزامن ✓'), findsOneWidget);
      expect(find.text('جهازك'), findsOneWidget);
      expect(find.text('30 صف ما وصلش السيرفر'), findsOneWidget);
      expect(find.text('مش متصل من 3 ساعات'), findsOneWidget);
    });
  });
}

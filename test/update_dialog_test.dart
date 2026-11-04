// ignore_for_file: must_call_super
// test/update_dialog_test.dart
//
// بلاغ: "تحديث الآن" من جوه التطبيق مابيعملش حاجة. السبب: الديالوج بيتقفل أول
// ما يتضغط الزر، وسياقه كان بيتمرّر لـ_downloadAndInstall، فبعد النسخة
// الاحتياطية (بتاخد وقت) كان `context.mounted` بيرجع false والدالة تخرج بصمت.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/services/update_service.dart';
import 'package:active_class/widgets/update_dialog.dart';

class _SlowBackupSettings extends SettingsController {
  bool backupCalled = false;
  @override
  void onInit() {}
  @override
  Future<String> backupData() async {
    backupCalled = true;
    await Future.delayed(const Duration(milliseconds: 900)); // قاعدة كبيرة
    return '/tmp/backup.db';
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
        .load();
  });
  tearDown(Get.reset);

  testWidgets('تحديث الآن يكمّل للتحميل حتى لو النسخة الاحتياطية بطيئة',
      (t) async {
    Get.reset();
    final settings = _SlowBackupSettings();
    Get.put<SettingsController>(settings);
    const info = UpdateInfo(
      version: '9.9.9',
      apkUrl:
          'http://127.0.0.1:1/app.apk', // مش هيتحمّل — يهمنا الوصول لمرحلة التحميل
      htmlUrl: 'https://example.com',
      releaseNotes: '- تجربة',
    );
    await t.pumpWidget(GetMaterialApp(
      locale: const Locale('ar'),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showUpdateDialogForTest(ctx, info),
              child: const Text('افتح'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('افتح'));
    await t.pumpAndSettle();
    expect(find.text('تحديث الآن'), findsOneWidget);

    await t.tap(find.text('تحديث الآن'));
    // الديالوج بيتقفل ويتفك سياقه، والنسخة الاحتياطية لسه شغّالة.
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }

    expect(settings.backupCalled, isTrue);
    // وصلنا لمرحلة التحميل: إما حوار التقدّم أو رسالة فشل التحميل. قبل
    // الإصلاح ماكانش بيظهر ولا واحد منهم أبدًا.
    final reachedDownload =
        find.text('جاري تحميل التحديث...').evaluate().isNotEmpty ||
            find.text('فشل تحميل التحديث داخل التطبيق').evaluate().isNotEmpty;
    expect(reachedDownload, isTrue,
        reason: 'تحديث الآن ما كمّلش بعد النسخة الاحتياطية');
    await t.pump(const Duration(seconds: 1));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/team_shared_settings.dart';

void main() {
  group('الإعدادات المشتركة', () {
    test('الإعدادات المؤثرة على الحسابات مشتركة، والشخصية لا', () {
      for (final k in [
        SETTING_BILLING_DAY,
        SETTING_BILLING_ARREARS,
        SETTING_PRORATE_FIRST_MONTH,
        SETTING_AUTO_ABSENT_ENABLED,
        SETTING_SHOW_HOMEWORK,
        'payment_grace_days',
        'currency_code',
      ]) {
        expect(isSharedSettingKey(k), isTrue, reason: k);
      }
      for (final k in [
        'use_24h_time_format',
        SETTING_HARDWARE_SCANNER_ENABLED,
        'hide_qr_payment',
        SETTING_AUTO_ABSENT_ENABLED_AT, // خاص بجهاز المدرس
        SETTING_ATRISK_NOTIF_DAY, // إشعار شخصي
        SETTING_TEAM_ID,
      ]) {
        expect(isSharedSettingKey(k), isFalse, reason: k);
      }
    });

    test('بيطبّق بس اللي اختلف', () {
      final out = sharedSettingsToApply(
        remote: {
          SETTING_BILLING_DAY: '5',
          SETTING_BILLING_ARREARS: '1',
          SETTING_SHOW_HOMEWORK: null,
        },
        local: {
          SETTING_BILLING_DAY: '5', // نفسه
          SETTING_BILLING_ARREARS: '0',
          SETTING_SHOW_HOMEWORK: '0',
        },
      );
      expect(out, {SETTING_BILLING_ARREARS: '1', SETTING_SHOW_HOMEWORK: null});
    });

    test('قيمة المدرس null = الافتراضي، فالمساعد اللي عنده قيمة يرجع للافتراضي',
        () {
      final out = sharedSettingsToApply(
          remote: {SETTING_BILLING_DAY: null},
          local: {SETTING_BILLING_DAY: '9'});
      expect(out, {SETTING_BILLING_DAY: null});
    });

    test('مفتاح مش مشترك أو مش موجود عند المدرس بيتجاهل', () {
      final out = sharedSettingsToApply(
        remote: {'use_24h_time_format': '1'},
        local: {'use_24h_time_format': '0', SETTING_BILLING_DAY: '9'},
      );
      expect(out, isEmpty);
    });

    test('ما فيش اختلاف = ما فيش تغيير', () {
      final m = {SETTING_BILLING_DAY: '3', SETTING_SHOW_RECITATION: null};
      expect(sharedSettingsToApply(remote: m, local: Map.of(m)), isEmpty);
    });
  });
}

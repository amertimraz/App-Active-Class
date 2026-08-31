// test/format_clock_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/helpers.dart';

// اختبار وحدة لـ FormatHelper.formatClock — دالة نقية. بيغطّي 24/12 ساعة
// وحواف منتصف الليل والظهر (spec 009، SC-004).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    Get.put(SettingsController());
  });

  void set24h(bool v) =>
      Get.find<SettingsController>().use24hFormat.value = v;

  group('24 ساعة', () {
    setUp(() => set24h(true));

    test('صباحًا', () {
      expect(FormatHelper.formatClock(const TimeOfDay(hour: 9, minute: 5)),
          '09:05');
    });
    test('بعد الظهر', () {
      expect(FormatHelper.formatClock(const TimeOfDay(hour: 14, minute: 30)),
          '14:30');
    });
    test('منتصف الليل', () {
      expect(FormatHelper.formatClock(const TimeOfDay(hour: 0, minute: 0)),
          '00:00');
    });
  });

  group('12 ساعة', () {
    setUp(() => set24h(false));

    test('صباحًا', () {
      expect(FormatHelper.formatClock(const TimeOfDay(hour: 9, minute: 5)),
          contains('9:05'));
    });
    test('1:00 م', () {
      final s = FormatHelper.formatClock(const TimeOfDay(hour: 13, minute: 0));
      expect(s, contains('1:00'));
    });
    test('منتصف الليل 12:15 ص', () {
      final s = FormatHelper.formatClock(const TimeOfDay(hour: 0, minute: 15));
      expect(s, contains('12:15'));
    });
    test('الظهر 12:15 م', () {
      final s = FormatHelper.formatClock(const TimeOfDay(hour: 12, minute: 15));
      expect(s, contains('12:15'));
    });
  });
}

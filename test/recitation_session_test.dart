// test/recitation_session_test.dart — منطق قائمة التسميع (صرف).
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/utils/recitation_session.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('recitationLevelOf', () {
    test('أقل من النص → تراجع', () {
      expect(recitationLevelOf(4, 10), RecitationLevel.low);
      expect(recitationLevelOf(7, 15), RecitationLevel.low);
      expect(recitationLevelOf(9, 20), RecitationLevel.low);
    });
    test('النص بالظبط → عادي (مش تراجع)', () {
      expect(recitationLevelOf(5, 10), RecitationLevel.ok);
      expect(recitationLevelOf(10, 20), RecitationLevel.ok);
    });
    test('90% فأكثر → نجمة', () {
      expect(recitationLevelOf(9, 10), RecitationLevel.star);
      expect(recitationLevelOf(10, 10), RecitationLevel.star);
      expect(recitationLevelOf(18, 20), RecitationLevel.star);
      expect(recitationLevelOf(17, 20), RecitationLevel.ok);
    });
    test('بدون درجة أو خارج النطاق → none', () {
      expect(recitationLevelOf(null, 10), RecitationLevel.none);
      expect(recitationLevelOf(0, 10), RecitationLevel.none);
      expect(recitationLevelOf(11, 10), RecitationLevel.none);
    });
  });

  group('stepRecitationMax', () {
    test('بيزيد وينقص', () {
      expect(stepRecitationMax(10, 1), 11);
      expect(stepRecitationMax(15, -1), 14);
    });
    test('حدود 1 و100', () {
      expect(stepRecitationMax(1, -1), 1);
      expect(stepRecitationMax(100, 1), 100);
    });
  });

  group('parseRecitationInput', () {
    test('رقم صالح', () => expect(parseRecitationInput('8', 10), 8));
    test('أرقام هندية', () => expect(parseRecitationInput('١٢', 20), 12));
    test('فاضي أو غير رقم → null', () {
      expect(parseRecitationInput('', 10), isNull);
      expect(parseRecitationInput('abc', 10), isNull);
    });
    test('خارج النطاق → null', () {
      expect(parseRecitationInput('11', 10), isNull);
      expect(parseRecitationInput('0', 10), isNull);
    });
  });

  group('الرسائل', () {
    final d = DateTime(2026, 11, 1);
    test('تنبيه التراجع فيه الاسم والدرجة بدون توقيع المعلم', () {
      final m = buildRecitationLowAlertMessage(
          studentName: 'منى', grade: 4, max: 15, date: d, groupName: 'تسميع');
      expect(m, contains('منى'));
      expect(m, contains('4 من 15'));
      expect(m, contains('تسميع'));
      expect(m, isNot(contains('👨‍🏫')));
    });
    test('التهنئة فيها الدرجة', () {
      final m = buildRecitationStarMessage(
          studentName: 'منى', grade: 20, max: 20, date: d);
      expect(m, contains('20 من 20'));
      expect(m, contains('⭐'));
    });
  });

  group('التقرير النصي', () {
    final d = DateTime(2026, 11, 1);
    final g = RecitationReportGroup(groupName: 'مجموعة أ', max: 10, rows: const [
      RecitationReportRow(studentName: 'أ', attendanceLabel: 'حاضر', grade: 10),
      RecitationReportRow(studentName: 'ب', attendanceLabel: 'حاضر', grade: 3),
      RecitationReportRow(studentName: 'ج', attendanceLabel: 'غائب'),
      RecitationReportRow(studentName: 'د', attendanceLabel: 'حاضر', grade: 6),
    ]);
    test('عدّادات المجموعة', () {
      expect(g.graded.length, 3);
      expect(g.lowCount, 1);
      expect(g.starCount, 1);
      expect(g.averageFraction, closeTo((1.0 + 0.3 + 0.6) / 3, 1e-9));
    });
    test('النص بيعلّم النجمة والتحذير ويوضّح الغياب', () {
      final t = buildRecitationReportText(d, [g]);
      expect(t, contains('مجموعة أ'));
      expect(t, contains('أ: 10/10 ⭐'));
      expect(t, contains('ب: 3/10 ⚠️'));
      expect(t, contains('ج: غائب'));
      expect(t, contains('د: 6/10'));
      expect(t, contains('سمّع 3 من 4'));
    });
    test('مجموعة بلا درجات', () {
      const e = RecitationReportGroup(groupName: 'فاضية', max: 10, rows: [
        RecitationReportRow(studentName: 'س', attendanceLabel: 'حاضر'),
      ]);
      expect(e.averageFraction, isNull);
      expect(buildRecitationReportText(d, [e]), contains('لم تُسجَّل درجات'));
    });
  });

  group('resolveGroupRecitationMax', () {
    test('مقياس درجات اليوم المسجّلة أولاً', () {
      expect(
          resolveGroupRecitationMax(recordMax: 20, savedMax: 15, settingsMax: 10),
          20);
    });
    test('بعده آخر قيمة محفوظة للمجموعة', () {
      expect(resolveGroupRecitationMax(savedMax: 15, settingsMax: 10), 15);
    });
    test('وإلا القيمة العامة', () {
      expect(resolveGroupRecitationMax(settingsMax: 10), 10);
    });
    test('بيتقصّ للحدود', () {
      expect(resolveGroupRecitationMax(savedMax: 500, settingsMax: 10), 100);
    });
    test('مفتاح الإعداد', () {
      expect(recitationGroupMaxKey(7), 'recitation_max_g7');
    });
  });
}

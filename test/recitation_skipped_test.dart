// «حضر وما سمّعش»: بتتخزّن -1 على attendance.recitation (والصفر درجة حقيقية).
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/utils/recitation.dart';
import 'package:active_class/utils/recitation_session.dart';

Attendance att(int? r, {String status = ATTENDANCE_PRESENT}) => Attendance(
    studentId: 1, date: DateTime(2026, 10, 3), status: status, recitation: r);

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  test('القيمة -1 مش درجة: recitationGradeOf = null (مش صفر في المتوسط)', () {
    final a = att(kRecitationSkipped);
    expect(recitationGradeOf(a), isNull);
    expect(recitationFractionOf(a), isNull);
    expect(recitationLevelOf(a.recitation, 10), RecitationLevel.none);
  });

  test('isRecitationSkipped: حاضر/متأخر بقيمة -1 فقط', () {
    expect(isRecitationSkipped(att(-1)), isTrue);
    expect(isRecitationSkipped(att(-1, status: ATTENDANCE_LATE)), isTrue);
    expect(isRecitationSkipped(att(-1, status: ATTENDANCE_ABSENT)), isFalse);
    expect(isRecitationSkipped(att(0)), isFalse); // الصفر درجة حقيقية
    expect(isRecitationSkipped(att(null)), isFalse);
    expect(isRecitationSkipped(att(5)), isFalse);
  });

  test('المتوسط بيتجاهل «ما سمّعش» ولا بيتحسب صفر', () {
    final month = DateTime(2026, 10, 1);
    final list = [att(8), att(-1), att(10)];
    // المتوسط على اللي سمّعوا بس: (8/10 + 10/10) / 2 × 10 = 9.0
    expect(recitationAverage(list, month: month), 9.0);
    expect(recitationCount(list, month: month), 2);
  });

  test('الصفر درجة حقيقية: بيتحسب في المتوسط والتحقق', () {
    final month = DateTime(2026, 10, 1);
    expect(recitationGradeOf(att(0)), 0);
    expect(recitationFractionOf(att(0)), 0.0);
    expect(recitationLevelOf(0, 10), RecitationLevel.low);
    expect(parseRecitationInput('0', 10), 0);
    expect(normalizeRecitation(0), 0);
    // (0/10 + 10/10) / 2 × 10 = 5.0
    expect(recitationAverage([att(0), att(10)], month: month), 5.0);
  });

  test('بوابة الأهل: «ما سمّعش» بيظهر بتاريخه من غير ما يأثّر على المتوسط', () {
    final f = recitationPortalFields([att(-1), att(8)], enabled: true);
    final h = f['recitationHistory'] as List;
    expect(h.length, 2);
    expect(h.where((e) => (e as Map)['skipped'] == true).length, 1);
    expect(f['recitationCount'], 1);
    expect(f['recitationAverage'], 8.0);
    final only = recitationPortalFields([att(-1)], enabled: true);
    expect((only['recitationHistory'] as List).length, 1);
    expect(only.containsKey('recitationAverage'), isFalse);
  });

  test('normalizeRecitationStored: يحافظ على -1 ويطبّع الباقي', () {
    expect(normalizeRecitationStored(-1), -1);
    expect(normalizeRecitationStored(0), 0);
    expect(normalizeRecitationStored(5, max: 10), 5);
    expect(normalizeRecitationStored(11, max: 10), isNull);
    expect(normalizeRecitationStored(-2), isNull);
    expect(normalizeRecitationStored(null), isNull);
  });

  test('التقرير النصي: «ما سمّعش» بدل الشرطة', () {
    final text = buildRecitationReportText(DateTime(2026, 10, 3), [
      const RecitationReportGroup(groupName: 'ج', max: 10, rows: [
        RecitationReportRow(
            studentName: 'منى',
            attendanceLabel: kRecitationSkippedLabel,
            grade: null),
        RecitationReportRow(
            studentName: 'علي', attendanceLabel: 'حاضر', grade: 9),
      ]),
    ]);
    expect(text, contains('• منى: ما سمّعش'));
    expect(text, contains('• علي: 9/10'));
  });
}

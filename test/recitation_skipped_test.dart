// «حضر وما سمّعش»: بتتخزّن 0 على attendance.recitation، ومش بتتحسب درجة.
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

  test('القيمة 0 مش درجة: recitationGradeOf = null (مش صفر في المتوسط)', () {
    final a = att(kRecitationSkipped);
    expect(recitationGradeOf(a), isNull);
    expect(recitationFractionOf(a), isNull);
    expect(recitationLevelOf(a.recitation, 10), RecitationLevel.none);
  });

  test('isRecitationSkipped: حاضر/متأخر بقيمة 0 فقط', () {
    expect(isRecitationSkipped(att(0)), isTrue);
    expect(isRecitationSkipped(att(0, status: ATTENDANCE_LATE)), isTrue);
    expect(isRecitationSkipped(att(0, status: ATTENDANCE_ABSENT)), isFalse);
    expect(isRecitationSkipped(att(null)), isFalse);
    expect(isRecitationSkipped(att(5)), isFalse);
  });

  test('المتوسط بيتجاهل «ما سمّعش» ولا بيتحسب صفر', () {
    final month = DateTime(2026, 10, 1);
    final list = [att(8), att(0), att(10)];
    // المتوسط على اللي سمّعوا بس: (8/10 + 10/10) / 2 × 10 = 9.0
    expect(recitationAverage(list, month: month), 9.0);
    expect(recitationCount(list, month: month), 2);
  });

  test('normalizeRecitationStored: يحافظ على 0 ويطبّع الباقي', () {
    expect(normalizeRecitationStored(0), 0);
    expect(normalizeRecitationStored(5, max: 10), 5);
    expect(normalizeRecitationStored(11, max: 10), isNull);
    expect(normalizeRecitationStored(-1), isNull);
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

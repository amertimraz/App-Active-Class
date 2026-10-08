// test/recitation_test.dart — spec 048 (درجة التسميع)
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/utils/recitation.dart';
import 'package:flutter_test/flutter_test.dart';

Attendance att(DateTime d, int? r, {String status = ATTENDANCE_PRESENT}) =>
    Attendance(studentId: 1, date: d, status: status, recitation: r);

void main() {
  test('normalizeRecitation', () {
    expect(normalizeRecitation(1), 1);
    expect(normalizeRecitation(10), 10);
    expect(normalizeRecitation(0), isNull);
    expect(normalizeRecitation(11), isNull);
    expect(normalizeRecitation(-3), isNull);
    expect(normalizeRecitation(null), isNull);
  });

  test('canRecordRecitation: حاضر/متأخر فقط', () {
    expect(canRecordRecitation(ATTENDANCE_PRESENT), true);
    expect(canRecordRecitation(ATTENDANCE_LATE), true);
    expect(canRecordRecitation(ATTENDANCE_ABSENT), false);
    expect(canRecordRecitation(null), false);
  });

  group('recitationAverage', () {
    final oct = DateTime(2026, 10, 3);
    final sep = DateTime(2026, 9, 20);
    test('إجمالي وشهر', () {
      final recs = [att(oct, 8), att(oct.add(const Duration(days: 1)), 6), att(sep, 10)];
      expect(recitationAverage(recs), 8.0);
      expect(recitationAverage(recs, month: DateTime(2026, 10, 1)), 7.0);
      expect(recitationAverage(recs, month: DateTime(2026, 9, 1)), 10.0);
    });
    test('يتجاهل الفارغ والخارج النطاق', () {
      final recs = [att(oct, null), att(oct, 0), att(oct, 11), att(oct, 9)];
      expect(recitationAverage(recs), 9.0);
      expect(recitationCount(recs), 1);
    });
    test('تقريب لعشري واحد', () {
      final recs = [att(oct, 8), att(oct, 8), att(oct, 9)]; // 8.333
      expect(recitationAverage(recs), 8.3);
    });
    test('بلا درجات → null و "—"', () {
      expect(recitationAverage([att(oct, null)]), isNull);
      expect(recitationAverage([]), isNull);
      expect(recitationAverageLabel(null), '—');
      expect(recitationAverageLabel(8.0), '8.0');
    });
    test('شهر بلا درجات → null', () {
      expect(recitationAverage([att(oct, 7)], month: DateTime(2026, 8, 1)), isNull);
    });
  });

  group('Attendance.copyWith', () {
    final a = att(DateTime(2026, 10, 3), 7);
    test('يحافظ على الدرجة عند تغيير الحالة لمتأخر', () {
      expect(a.copyWith(status: ATTENDANCE_LATE).recitation, 7);
    });
    test('clearRecitation يمسحها', () {
      expect(a.copyWith(status: ATTENDANCE_ABSENT, clearRecitation: true).recitation, isNull);
    });
    test('toMap/fromMap round-trip', () {
      final m = a.toMap();
      expect(m['recitation'], 7);
      expect(Attendance.fromMap(m).recitation, 7);
      expect(Attendance.fromMap({...m, 'recitation': null}).recitation, isNull);
    });
  });

  group('recitationStandings', () {
    Attendance a(int sid, int day, int? r, {int month = 10}) => Attendance(
        studentId: sid,
        date: DateTime(2026, month, day),
        status: ATTENDANCE_PRESENT,
        recitation: r);
    test('ترتيب تنازلي بالمتوسط ثم عدد المرات', () {
      final recs = [
        a(1, 1, 8), a(1, 2, 8), // 8.0 × 2
        a(2, 1, 8), // 8.0 × 1
        a(3, 1, 10), a(3, 2, 9), // 9.5
        a(4, 1, null), // مستبعد
      ];
      final r = recitationStandings(recs);
      expect(r.map((e) => e.studentId), [3, 1, 2]);
      expect(r.first.average, 9.5);
      expect(r.first.count, 2);
    });
    test('فلتر الشهر والحد', () {
      final recs = [a(1, 1, 9), a(2, 1, 5), a(2, 3, 7, month: 9)];
      final r = recitationStandings(recs, month: DateTime(2026, 10, 1));
      expect(r.map((e) => e.studentId), [1, 2]);
      expect(r.last.average, 5.0);
      expect(recitationStandings(recs, limit: 1).length, 1);
    });
    test('فاضي', () => expect(recitationStandings([]), isEmpty));
  });

  group('recitationPortalFields', () {
    Attendance a(int day, int? r) => Attendance(
        studentId: 1,
        date: DateTime(2026, 10, day),
        status: ATTENDANCE_PRESENT,
        recitation: r);
    test('مقفول → فاضي', () {
      expect(recitationPortalFields([a(1, 8)], enabled: false), isEmpty);
    });
    test('بلا درجات → فاضي', () {
      expect(recitationPortalFields([a(1, null)], enabled: true), isEmpty);
    });
    test('متوسط وعدد وآخر الدرجات الأحدث أولًا', () {
      final f = recitationPortalFields([a(1, 6), a(3, 10), a(2, 8)],
          enabled: true, historyLimit: 2);
      expect(f['recitationAverage'], 8.0);
      expect(f['recitationCount'], 3);
      final h = f['recitationHistory'] as List;
      expect(h.length, 2);
      expect((h.first as Map)['grade'], 10);
    });
  });
}

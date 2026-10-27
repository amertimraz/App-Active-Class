// test/schedule_week_test.dart — spec 053
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/utils/schedule_week.dart';

void main() {
  // 2026-10-27 = الثلاثاء → السبت=0 ... الثلاثاء=3
  final tue = DateTime(2026, 10, 27);

  test('فهرس اليوم (السبت=0)', () {
    expect(dayIndexOf(DateTime(2026, 10, 24)), 0); // السبت
    expect(dayIndexOf(DateTime(2026, 10, 25)), 1); // الأحد
    expect(dayIndexOf(tue), 3);
    expect(dayIndexOf(DateTime(2026, 10, 30)), 6); // الجمعة
  });

  test('بداية الأسبوع سبت، والجمعة بتفضل في نفس الأسبوع', () {
    expect(weekStartSaturday(tue), DateTime(2026, 10, 24));
    expect(weekStartSaturday(DateTime(2026, 10, 30)), DateTime(2026, 10, 24));
    expect(weekStartSaturday(DateTime(2026, 10, 24)), DateTime(2026, 10, 24));
    expect(weekStartSaturday(DateTime(2026, 10, 31)), DateTime(2026, 10, 31));
  });

  test('تاريخ يوم بإزاحة أسبوع (موجبة وسالبة)', () {
    expect(dateForDayIndex(tue, 0, 3), tue);
    expect(dateForDayIndex(tue, -1, 0), DateTime(2026, 10, 17)); // السبت اللي فات
    expect(dateForDayIndex(tue, 1, 6), DateTime(2026, 11, 6));
  });

  test('عبور الشهر والسنة', () {
    final dec = DateTime(2026, 12, 30);
    expect(dateForDayIndex(dec, 1, 0), DateTime(2027, 1, 2));
    expect(dateForDayIndex(DateTime(2027, 1, 2), -1, 6), DateTime(2027, 1, 1));
  });

  test('weekOffsetFor عكس dateForDayIndex (شهور ورا/قدام)', () {
    for (final off in [-30, -5, -1, 0, 1, 4, 20]) {
      for (var i = 0; i < 7; i++) {
        final d = dateForDayIndex(tue, off, i);
        expect(weekOffsetFor(tue, d), off, reason: '$off/$i');
        expect(dayIndexOf(d), i);
      }
    }
  });

  test('تغيّر التوقيت الصيفي لا يكسر اليوم', () {
    // أسابيع عبر تواريخ الانتقال المحتملة (مارس/أكتوبر) في أي منطقة زمنية.
    final base = DateTime(2026, 3, 20);
    for (var off = -3; off <= 3; off++) {
      final d = dateForDayIndex(base, off, 2);
      expect(d.hour, 0);
      expect(dayIndexOf(d), 2);
      expect(weekOffsetFor(base, d), off);
    }
  });
}

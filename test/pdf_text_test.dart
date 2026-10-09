// test/pdf_text_test.dart — إصلاح عرض "ي" المنفصلة ونسبة الأقواس في PDF
import 'package:active_class/utils/pdf_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const feF0 = 'ﻰ';
  test('ي منفصلة بعد حرف لا يتّصل → تتبدّل', () {
    expect(fixArabicForPdf('هادي'), 'هاد$feF0');
    expect(fixArabicForPdf('عبد الهادي'), 'عبد الهاد$feF0');
    expect(fixArabicForPdf('نادي شادي وادي'),
        'ناد$feF0 شاد$feF0 واد$feF0');
  });
  test('ي متّصلة أو أول الكلمة → ما تتغيّرش', () {
    for (final w in ['علي', 'ياسين', 'يحيى', 'إسماعيل', 'رامي', 'سعيد', 'هاني']) {
      expect(fixArabicForPdf(w), w, reason: w);
    }
  });
  test('ي لوحدها → تتبدّل، وبعد التشكيل تتعامل صح', () {
    expect(fixArabicForPdf('ي'), feF0);
    expect(fixArabicForPdf('هادِي'), 'هادِ$feF0');
  });
  test('نص بلا ي أو لاتيني → كما هو', () {
    expect(fixArabicForPdf('محمد'), 'محمد');
    expect(fixArabicForPdf('Hamdi'), 'Hamdi');
  });
  test('نسبة بين أقواس تتكتب (%100)', () {
    expect(fixArabicForPdf('الدرجة: 30 من 30 (100%)'),
        'الدرجة: 30 من 30 (%100)');
    expect(fixArabicForPdf('(92.5%)'), '(%92.5)');
    expect(fixArabicForPdf('بمعدّل 95% عبر'), 'بمعدّل 95% عبر');
  });
}

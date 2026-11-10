// test/whatsapp_auto_rules_test.dart — spec 056: قواعد الإرسال التلقائي الصرفة.
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/utils/whatsapp_auto_rules.dart';

void main() {
  test('مفتاح منع التكرار ثابت لنفس الطالب واليوم، ومختلف بين الأيام والطلاب', () {
    final a = waAbsenceDedupeKey('o1', 7, DateTime(2026, 11, 9, 8));
    final b = waAbsenceDedupeKey('o1', 7, DateTime(2026, 11, 9, 23, 30));
    expect(a, b);
    expect(a, 'o1|7|absence|2026-11-09');
    expect(waAbsenceDedupeKey('o1', 7, DateTime(2026, 11, 10)), isNot(a));
    expect(waAbsenceDedupeKey('o1', 8, DateTime(2026, 11, 9)), isNot(a));
  });

  test('رقم ولي الأمر: وطني، دولي، أرقام عربية، وغير صالح', () {
    expect(waRecipientPhone('01095258041', '20'), '201095258041');
    expect(waRecipientPhone('+201095258041', '20'), '201095258041');
    expect(waRecipientPhone('٠١٠٩٥٢٥٨٠٤١', '20'), '201095258041');
    expect(waRecipientPhone('', '20'), isNull);
    expect(waRecipientPhone(null, '20'), isNull);
    expect(waRecipientPhone('12', '20'), isNull);
  });

  test('متغيرات قالب الغياب: ترتيب الحقول واستبدال الفاضي', () {
    final v = waAbsenceVars(
      studentName: ' أحمد ',
      groupName: '',
      day: DateTime(2026, 11, 9),
      teacherName: '',
    );
    expect(v['student'], 'أحمد');
    expect(v['group'], '-');
    expect(v['date'], '2026-11-09');
    expect(v['teacher'], 'الأكاديمية');
  });
}

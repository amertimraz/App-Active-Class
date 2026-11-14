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
    expect(v['teacher'], 'Active Class');
    expect(v['teacher_phone'], 'غير متاح'); // بدون رقم
    final w = waAbsenceVars(
        studentName: 'أ', groupName: 'ج', day: DateTime(2026, 11, 9),
        teacherName: 'أ/ سعد', teacherPhone: '+201012345678');
    expect(w['teacher_phone'], '+201012345678');
  });

  test('رقم المدرس للتواصل: صيغة دولية بـ+، وفاضي لو غير صالح', () {
    expect(waTeacherPhoneText('01012345678', '20'), '+201012345678');
    expect(waTeacherPhoneText('+201012345678', '20'), '+201012345678');
    expect(waTeacherPhoneText('', '20'), '');
    expect(waTeacherPhoneText(null, '20'), '');
    expect(waTeacherPhoneText('12', '20'), '');
  });

  test('مبلغ الرسالة: بدون كسور لو صحيح', () {
    expect(waAmountText(150), '150');
    expect(waAmountText(150.0), '150');
    expect(waAmountText(99.5), '99.50');
    expect(waAmountText(33.333), '33.33');
  });

  test('أسبوع ISO ومفتاح تذكير التأخر: نفس الأسبوع = نفس المفتاح', () {
    // الاثنين 2026-11-09 والأحد 2026-11-15 نفس الأسبوع، والاثنين اللي بعده لأ
    expect(waIsoWeekKey(DateTime(2026, 11, 9)), waIsoWeekKey(DateTime(2026, 11, 15)));
    expect(waIsoWeekKey(DateTime(2026, 11, 16)), isNot(waIsoWeekKey(DateTime(2026, 11, 15))));
    expect(waIsoWeekKey(DateTime(2026, 1, 1)), '2026-W01');
    expect(waIsoWeekKey(DateTime(2027, 1, 1)), '2026-W53'); // الجمعة 1 يناير 2027
    expect(waLateDedupeKey('o', 5, DateTime(2026, 11, 9)),
        waLateDedupeKey('o', 5, DateTime(2026, 11, 13)));
    expect(waLateDedupeKey('o', 5, DateTime(2026, 11, 9)),
        isNot(waLateDedupeKey('o', 6, DateTime(2026, 11, 9))));
  });

  test('إيصال: مفتاح منع التكرار بالدفعة، والمتغيرات والمتبقي ما يقلش عن صفر', () {
    final at = DateTime(2026, 11, 9, 10, 30);
    expect(waReceiptDedupeKey('o', 1, at, 200), waReceiptDedupeKey('o', 1, at, 200));
    expect(waReceiptDedupeKey('o', 1, at, 200), isNot(waReceiptDedupeKey('o', 1, at, 300)));
    final v = waReceiptVars(
        amount: 200, studentName: 'أحمد', monthLabel: 'نوفمبر 2026',
        remaining: -50, teacherName: 'أ/ سعد', teacherPhone: '+201012345678');
    expect(v['amount'], '200');
    expect(v['remaining'], '0');
    expect(v['teacher_phone'], '+201012345678');
    expect(waReceiptVars(amount: 1, studentName: 'أ', monthLabel: 'م', remaining: 0, teacherName: '')['teacher_phone'], 'غير متاح');
  });

  test('تذكير التأخر: المتغيرات', () {
    final v = waLateVars(studentName: 'أحمد', amount: 150.5, teacherName: '', teacherPhone: '');
    expect(v['amount'], '150.50');
    expect(v['teacher'], 'Active Class');
    expect(v['teacher_phone'], 'غير متاح');
  });
}

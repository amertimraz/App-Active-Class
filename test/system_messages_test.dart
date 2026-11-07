import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:active_class/utils/absence_message.dart';
import 'package:active_class/utils/payment_reminder_message.dart';
import 'package:active_class/utils/system_messages.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));
  tearDown(SystemMessages.clearAll);

  test('تعبئة وحذف السطر الفاضي', () {
    final out = renderSystemBody(
        'أ {الاسم}\n📘 {التخصص}\nثابت', {'الاسم': 'س', 'التخصص': ''});
    expect(out, 'أ س\nثابت');
  });

  test('متغيّر مجهول بيتساب، واكتشافه', () {
    final def = systemMessageDef('absence')!;
    expect(renderSystemBody('{غلط} {الكود}', {'الكود': 'A'}), '{غلط} A');
    expect(unknownVariables(def, 'x {غلط} {الكود}'), ['غلط']);
  });

  test('كل نوع: افتراضيه بيتعبّى بالمعاينة من غير متغيّر متروك', () {
    for (final d in kSystemMessageDefs) {
      final out = renderSystemBody(d.defaultBody, d.sample);
      expect(out.contains('{'), isFalse, reason: d.id);
      expect(unknownVariables(d, d.defaultBody), isEmpty, reason: d.id);
      expect(out.trim(), isNotEmpty);
    }
  });

  test('التخزين: set / decode / encode / مسح', () {
    expect(SystemMessages.isCustomized('absence'), isFalse);
    SystemMessages.set('absence', 'نص {اسم_الطالب}');
    expect(SystemMessages.renderOverride('absence', {'اسم_الطالب': 'ع'}),
        'نص ع');
    final raw = SystemMessages.encode();
    SystemMessages.clearAll();
    expect(SystemMessages.renderOverride('absence', {}), isNull);
    SystemMessages.decode(raw);
    expect(SystemMessages.isCustomized('absence'), isTrue);
    SystemMessages.set('absence', '  ');
    expect(SystemMessages.isCustomized('absence'), isFalse);
    SystemMessages.decode('مش json');
    expect(SystemMessages.isCustomized('absence'), isFalse);
  });

  test('دوال البناء: الأصلي من غير تعديل، والمعدّل لما يتحفظ', () {
    final orig = buildAbsenceMessage(
        studentName: 'س', studentCode: 'A1', groupName: 'ج', date: DateTime(2026, 11, 7));
    expect(orig, contains('تنبيه غياب'));
    SystemMessages.set('absence', 'غاب {اسم_الطالب} يوم {التاريخ}\n📘 {التخصص}');
    final custom = buildAbsenceMessage(
        studentName: 'س', studentCode: 'A1', groupName: 'ج', date: DateTime(2026, 11, 7));
    expect(custom, 'غاب س يوم 2026-11-07');
    SystemMessages.set('payment_reminder', 'متبقي {المتبقي} على {اسم_الطالب}');
    expect(
        buildPaymentReminderMessage(studentName: 'ع', remainingText: '50 ج'),
        'متبقي 50 ج على ع');
  });
}

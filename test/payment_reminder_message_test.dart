// test/payment_reminder_message_test.dart
//
// رسالة تأخر الدفع: مختصرة بأسلوب "تنبيه غياب/تأخير" وبكلمة "اشتراك".
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/utils/payment_reminder_message.dart';

void main() {
  teacherTests();
  test('رسالة كاملة: عنوان + طالب + مجموعة + شهر + المتبقي', () {
    final m = buildPaymentReminderMessage(
      studentName: 'أحمد علي',
      studentCode: 'S-12',
      groupName: 'أولى ثانوي',
      monthLabel: 'أكتوبر 2026',
      remainingText: '150 ج.م',
    );
    expect(m.split('\n'), [
      '⚠️ *تنبيه تأخر الدفع*',
      '👤 أحمد علي (S-12)',
      '👥 أولى ثانوي',
      '📅 اشتراك شهر أكتوبر 2026',
      '💰 المتبقي من الاشتراك: 150 ج.م',
    ]);
  });

  test('بلا كلمة "مديونية" ومختصرة', () {
    final m = buildPaymentReminderMessage(
      studentName: 'سارة',
      studentCode: 'S-1',
      groupName: 'ب',
      monthLabel: 'نوفمبر 2026',
      remainingText: '100 ج.م',
    );
    expect(m.contains('مديونية'), isFalse);
    expect(m.contains('اشتراك'), isTrue);
    expect(m.split('\n').length, lessThanOrEqualTo(5));
  });

  test('حقول ناقصة تتخطى بدون أسطر فاضية', () {
    final m = buildPaymentReminderMessage(
      studentName: 'منى',
      groupName: '-',
    );
    expect(m.split('\n'), [
      '⚠️ *تنبيه تأخر الدفع*',
      '👤 منى',
      '💰 يوجد اشتراك متأخر السداد',
    ]);
  });

  test('شهر معروف بدون مبلغ: بلا سطر مبلغ', () {
    final m = buildPaymentReminderMessage(
      studentName: 'منى',
      studentCode: 'S-2',
      monthLabel: 'أكتوبر 2026',
    );
    expect(m.contains('💰'), isFalse);
    expect(m.contains('📅 اشتراك شهر أكتوبر 2026'), isTrue);
  });
}

void teacherTests() {
  test('اسم المعلم وتخصصه في آخر الرسالة بنفس سطري الغياب', () {
    final m = buildPaymentReminderMessage(
      studentName: 'منى',
      studentCode: 'S-2',
      remainingText: '50 ج.م',
      teacherName: 'أ. كريم',
      teacherSpecialization: 'رياضيات',
    );
    final lines = m.split('\n');
    expect(lines[lines.length - 2], '👨‍🏫 أ. كريم');
    expect(lines.last, '📘 رياضيات');
  });
}

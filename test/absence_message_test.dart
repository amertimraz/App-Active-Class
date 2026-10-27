// test/absence_message_test.dart — spec 053
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:active_class/utils/absence_message.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ar'));

  final date = DateTime(2026, 10, 27);

  test('رسالة غياب كاملة (نفس نص غياب اليوم القديم)', () {
    final m = buildAbsenceMessage(
      studentName: 'أحمد علي',
      studentCode: 'S-1',
      groupName: 'العواسجة',
      date: date,
      teacherName: 'د. حازم',
      teacherSpecialization: 'علوم',
    );
    expect(m.split('\n'), [
      '⚠️ *تنبيه غياب*',
      '👤 أحمد علي (S-1)',
      '👥 العواسجة',
      '📅 2026-10-27',
      '👨‍🏫 د. حازم',
      '📘 علوم',
    ]);
  });

  test('بدون معلم/تخصص بلا أسطر فاضية', () {
    final m = buildAbsenceMessage(
        studentName: 'منى', studentCode: 'S-2', groupName: 'ب', date: date);
    expect(m.split('\n').length, 4);
    expect(m.endsWith('2026-10-27'), isTrue);
  });

  test('تنبيه تأخير بعنوانه، والتاريخ تاريخ الحصة مش النهاردة', () {
    final m = buildLateMessage(
        studentName: 'منى',
        studentCode: 'S-2',
        groupName: 'ب',
        date: DateTime(2026, 9, 5));
    expect(m.startsWith('⚠️ *تنبيه تأخير*'), isTrue);
    expect(m.contains('📅 2026-09-05'), isTrue);
  });
}

// lib/utils/payment_reminder_message.dart
//
// رسالة واتساب "تأخر الدفع" لولي الأمر — صيغة مختصرة بنفس أسلوب
// "تنبيه غياب" و"تنبيه تأخير" في شاشة الحضور، وبكلمة "اشتراك" (مش "مديونية").
// دالة صرفة (بلا GetX/DB) عشان تتختبر. اسم المعلم وتخصصه بنفس سطري رسائل
// الغياب/التأخير (👨‍🏫 / 📘)، فـlaunchGuardianWhatsapp مابيكررهمش.

import 'package:active_class/utils/system_messages.dart';

/// [remainingText] المبلغ المتبقي مُنسَّق جاهز (مثلاً "150 ج.م")، وفاضي لو
/// المبلغ مش معروف. [monthLabel] اسم الشهر ("أكتوبر 2026") وفاضي لو مش معروف.
String buildPaymentReminderMessage({
  required String studentName,
  String studentCode = '',
  String groupName = '',
  String monthLabel = '',
  String remainingText = '',
  String teacherName = '',
  String teacherSpecialization = '',
}) {
  final custom = SystemMessages.renderOverride('payment_reminder', {
    'اسم_الطالب': studentName,
    'الكود': studentCode.trim(),
    'المجموعة': groupName.trim() == '-' ? '' : groupName.trim(),
    'الشهر': monthLabel.trim(),
    'المتبقي': remainingText.trim(),
    'المعلم': teacherName.trim(),
    'التخصص': teacherSpecialization.trim(),
  });
  if (custom != null) return custom;
  final code = studentCode.trim();
  final b = StringBuffer()
    ..writeln('⚠️ *تنبيه تأخر الدفع*')
    ..writeln('👤 $studentName${code.isEmpty ? '' : ' ($code)'}');
  if (groupName.trim().isNotEmpty && groupName.trim() != '-') {
    b.writeln('👥 ${groupName.trim()}');
  }
  if (monthLabel.trim().isNotEmpty) {
    b.writeln('📅 اشتراك شهر ${monthLabel.trim()}');
  }
  if (remainingText.trim().isNotEmpty) {
    b.writeln('💰 المتبقي من الاشتراك: ${remainingText.trim()}');
  } else if (monthLabel.trim().isEmpty) {
    b.writeln('💰 يوجد اشتراك متأخر السداد');
  }
  if (teacherName.trim().isNotEmpty) b.writeln('👨‍🏫 ${teacherName.trim()}');
  if (teacherSpecialization.trim().isNotEmpty) {
    b.writeln('📘 ${teacherSpecialization.trim()}');
  }
  return b.toString().trimRight();
}

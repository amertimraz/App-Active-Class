// lib/utils/absence_message.dart
//
// رسائل واتساب "تنبيه غياب" و"تنبيه تأخير" لولي الأمر — دوال صرفة (spec 053)،
// مستخرجة من تبويب "غياب اليوم" بنفس النص حرفيًا، مع تاريخ كمعامل عشان
// شاشة تفاصيل الحصة تبعت بتاريخ الحصة (مش النهاردة).
import 'package:intl/intl.dart';

String _buildAttendanceAlert(
  String title, {
  required String studentName,
  required String studentCode,
  required String groupName,
  required DateTime date,
  String teacherName = '',
  String teacherSpecialization = '',
}) {
  final dateStr = DateFormat('yyyy-MM-dd', 'ar').format(date);
  final b = StringBuffer()
    ..writeln('⚠️ *$title*')
    ..writeln('👤 $studentName ($studentCode)')
    ..writeln('👥 $groupName')
    ..writeln('📅 $dateStr');
  if (teacherName.isNotEmpty) b.writeln('👨‍🏫 $teacherName');
  if (teacherSpecialization.isNotEmpty) b.writeln('📘 $teacherSpecialization');
  return b.toString().trimRight();
}

String buildAbsenceMessage({
  required String studentName,
  required String studentCode,
  required String groupName,
  required DateTime date,
  String teacherName = '',
  String teacherSpecialization = '',
}) =>
    _buildAttendanceAlert('تنبيه غياب',
        studentName: studentName,
        studentCode: studentCode,
        groupName: groupName,
        date: date,
        teacherName: teacherName,
        teacherSpecialization: teacherSpecialization);

String buildLateMessage({
  required String studentName,
  required String studentCode,
  required String groupName,
  required DateTime date,
  String teacherName = '',
  String teacherSpecialization = '',
}) =>
    _buildAttendanceAlert('تنبيه تأخير',
        studentName: studentName,
        studentCode: studentCode,
        groupName: groupName,
        date: date,
        teacherName: teacherName,
        teacherSpecialization: teacherSpecialization);

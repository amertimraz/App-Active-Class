// lib/utils/whatsapp_auto_rules.dart
//
// spec 056 — قواعد صرفة للإرسال التلقائي (بلا I/O): مفتاح منع التكرار،
// رقم ولي الأمر بالصيغة الدولية، ومتغيرات قالب الغياب. الأسماء والمتغيرات
// لازم تطابق supabase/wa-worker/src/templates.js.
import 'package:intl/intl.dart';

import 'package:active_class/utils/phone_helper.dart';

/// مفتاح منع التكرار لطلب غياب: رسالة واحدة لكل (مدرس + طالب + يوم).
/// بيطابق unique(dedupe_key) في wa_outbox، فتسجيل الغياب أكتر من مرة
/// (أو من جهازين) ما يبعتش أكتر من رسالة.
String waAbsenceDedupeKey(String ownerId, int studentId, DateTime day) {
  final d = DateFormat('yyyy-MM-dd').format(day);
  return '$ownerId|$studentId|absence|$d';
}

/// رقم ولي الأمر بصيغة digits دولية بلا '+' (نفس صيغة wa_outbox.to_phone)،
/// أو null لو فاضي/غير صالح (أقل من 8 أو أكتر من 15 خانة).
String? waRecipientPhone(String? raw, String dialCode) {
  if (raw == null || raw.trim().isEmpty) return null;
  final digits = PhoneHelper.waMe(raw, dialCode).replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8 || digits.length > 15) return null;
  return digits;
}

/// متغيرات قالب ac_absence_ar: student, group, date, teacher.
Map<String, String> waAbsenceVars({
  required String studentName,
  required String groupName,
  required DateTime day,
  required String teacherName,
}) =>
    {
      'student': studentName.trim(),
      'group': groupName.trim().isEmpty ? '-' : groupName.trim(),
      'date': DateFormat('yyyy-MM-dd').format(day),
      'teacher': teacherName.trim().isEmpty ? 'الأكاديمية' : teacherName.trim(),
    };

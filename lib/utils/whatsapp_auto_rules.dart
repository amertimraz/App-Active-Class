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

/// رقم المدرس للتواصل كنص دولي (+20…) — بيتبعت جوه نص القالب وواتساب بيخلّيه
/// قابل للضغط (Meta بترفض روابط واتساب المباشرة في أزرار القوالب). فاضي لو
/// الرقم غير موجود أو غير صالح.
String waTeacherPhoneText(String? raw, String dialCode) {
  final d = waRecipientPhone(raw, dialCode);
  return d == null ? '' : '+$d';
}

/// متغيرات قالب ac_absence_ar: student, group, date, teacher, teacher_phone.
Map<String, String> waAbsenceVars({
  required String studentName,
  required String groupName,
  required DateTime day,
  required String teacherName,
  String teacherPhone = '',
}) =>
    {
      'student': studentName.trim(),
      'group': groupName.trim().isEmpty ? '-' : groupName.trim(),
      'date': DateFormat('yyyy-MM-dd').format(day),
      'teacher': teacherName.trim().isEmpty ? 'الأكاديمية' : teacherName.trim(),
      // القالب بيحتاج قيمة دايمًا؛ لو المدرس ما سجّلش رقمه بنكتب «غير متاح».
      'teacher_phone': teacherPhone.trim().isEmpty ? 'غير متاح' : teacherPhone.trim(),
    };

/// مبلغ للعرض في الرسالة: بدون كسور لو صحيح، وإلا رقمين عشريين.
String waAmountText(double v) {
  final r = (v * 100).round() / 100;
  return r == r.roundToDouble() ? r.round().toString() : r.toStringAsFixed(2);
}

/// أسبوع ISO ("2026-W46") — مفتاح منع تكرار تذكير التأخر (واحد/أسبوع/طالب).
String waIsoWeekKey(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final thursday = day.add(Duration(days: 4 - (day.weekday == 7 ? 7 : day.weekday)));
  final jan1 = DateTime(thursday.year, 1, 1);
  final week = ((thursday.difference(jan1).inDays) / 7).floor() + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

String waReceiptDedupeKey(String ownerId, int studentId, DateTime at, double amount) =>
    '$ownerId|$studentId|receipt|${at.millisecondsSinceEpoch}|${amount.round()}';

String waLateDedupeKey(String ownerId, int studentId, DateTime now) =>
    '$ownerId|$studentId|late_payment|${waIsoWeekKey(now)}';

/// متغيرات قالب ac_receipt_ar: amount, student, month, remaining, teacher, teacher_phone.
Map<String, String> waReceiptVars({
  required double amount,
  required String studentName,
  required String monthLabel,
  required double remaining,
  required String teacherName,
  String teacherPhone = '',
}) =>
    {
      'amount': waAmountText(amount),
      'student': studentName.trim(),
      'month': monthLabel.trim(),
      'remaining': waAmountText(remaining < 0 ? 0 : remaining),
      'teacher': teacherName.trim().isEmpty ? 'الأكاديمية' : teacherName.trim(),
      'teacher_phone': teacherPhone.trim().isEmpty ? 'غير متاح' : teacherPhone.trim(),
    };

/// متغيرات قالب ac_late_payment_ar: student, amount, teacher, teacher_phone.
Map<String, String> waLateVars({
  required String studentName,
  required double amount,
  required String teacherName,
  String teacherPhone = '',
}) =>
    {
      'student': studentName.trim(),
      'amount': waAmountText(amount),
      'teacher': teacherName.trim().isEmpty ? 'الأكاديمية' : teacherName.trim(),
      'teacher_phone': teacherPhone.trim().isEmpty ? 'غير متاح' : teacherPhone.trim(),
    };

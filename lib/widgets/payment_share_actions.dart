// lib/widgets/payment_share_actions.dart
//
// إيصال دفع وكشف حساب الطالب: مشاركة PDF أو رسالة واتساب لولي الأمر.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/payment_note.dart';
import 'package:active_class/utils/receipt_message.dart';
import 'package:active_class/utils/student_statement.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/widgets/app_toast.dart';

String _money(double v) => FormatHelper.formatCurrency(v);
String _month(DateTime d) => DateFormat('MMMM yyyy', 'ar').format(d);
String _date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

enum _Channel { whatsapp, pdf }

Future<_Channel?> _pickChannel(BuildContext context, String title) {
  return showModalBottomSheet<_Channel>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        ListTile(
          leading: const Icon(Icons.chat_rounded),
          title: const Text('إرسال رسالة واتساب لولي الأمر'),
          onTap: () => Navigator.pop(ctx, _Channel.whatsapp),
        ),
        ListTile(
          leading: const Icon(Icons.picture_as_pdf_rounded),
          title: const Text('مشاركة PDF'),
          onTap: () => Navigator.pop(ctx, _Channel.pdf),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

Future<void> _sendWhatsapp(
    BuildContext context, Student s, String message) async {
  final settings = Get.find<SettingsController>();
  await launchGuardianWhatsapp(
    context: context,
    phone: s.guardianPhone?.trim(),
    whatsapp: s.guardianWhatsapp?.trim(),
    message: message,
    dialCode: settings.countryDial.value,
  );
}

Future<void> _sharePdf(BuildContext context, ExportResult r) async {
  if (!r.success || r.path == null) {
    if (context.mounted) AppToast.error(context, r.error ?? 'تعذّر إنشاء الملف');
    return;
  }
  await ExportService().sharePDF(r.path!);
}

/// إيصال دفعة واحدة. [remaining] المتبقي الحالي على الطالب (اختياري).
Future<void> showReceiptActions(
  BuildContext context, {
  required Student student,
  required Group? group,
  required Payment payment,
  double? remaining,
}) async {
  final ch = await _pickChannel(context, 'إيصال دفع');
  if (ch == null || !context.mounted) return;
  final months = PaymentNote.parse(payment.note).months;
  final settings = Get.find<SettingsController>();
  if (ch == _Channel.whatsapp) {
    final msg = buildReceiptMessage(
      studentName: student.name,
      studentCode: student.code,
      groupName: group?.name ?? '',
      amount: payment.amount,
      date: payment.date,
      months: months,
      remaining: remaining,
      money: _money,
      monthLabel: _month,
      dateLabel: _date,
    );
    await _sendWhatsapp(context, student, msg);
  } else {
    final r = await ExportService().exportPaymentReceiptPDF(
      student: student,
      groupName: group?.name ?? '',
      amount: payment.amount,
      date: payment.date,
      months: months,
      remaining: remaining,
      teacherName: settings.teacherFullName.value,
      teacherSpecialization: settings.teacherSpecialization.value,
    );
    if (!context.mounted) return;
    await _sharePdf(context, r);
  }
}

/// كشف حساب الطالب كامل.
Future<void> showStatementActions(
  BuildContext context, {
  required Student student,
  required Group? group,
  required List<Attendance> allAttendance,
  required List<Payment> payments,
  List<Student>? siblingGroupMembers,
}) async {
  final ch = await _pickChannel(context, 'كشف حساب ${student.name}');
  if (ch == null || !context.mounted) return;
  final st = StudentStatement.build(
    student: student,
    group: group,
    allAttendance: allAttendance,
    payments: payments,
    siblingGroupMembers: siblingGroupMembers,
  );
  final settings = Get.find<SettingsController>();
  if (ch == _Channel.whatsapp) {
    final msg = buildStatementMessage(
      studentName: student.name,
      studentCode: student.code,
      groupName: group?.name ?? '',
      statement: st,
      money: _money,
      monthLabel: _month,
    );
    await _sendWhatsapp(context, student, msg);
  } else {
    final r = await ExportService().exportStudentStatementPDF(
      student: student,
      groupName: group?.name ?? '',
      statement: st,
      teacherName: settings.teacherFullName.value,
    );
    if (!context.mounted) return;
    await _sharePdf(context, r);
  }
}

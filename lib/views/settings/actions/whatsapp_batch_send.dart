part of '../settings_page.dart';

// spec 051 — إرسال تقارير الشهر الجماعي (نقل حرفي)

Future<void> _startWhatsappBatchSend(
    BuildContext context, SettingsController settings) async {
  final db = DatabaseService();
  LoadingDialog.show(context, message: 'تحضير الرسائل...');
  try {
    final students = await db.getAllStudents();

    // مفيش داعي نبعت رسائل واتساب جماعية لأولياء أمور طلاب مؤرشفين —
    // ده شغل يومي نشط، مش سجل تاريخي.
    final valid = students
        .where((s) => !s.isArchived)
        .where((s) =>
            (s.guardianPhone ?? '').trim().isNotEmpty ||
            (s.guardianWhatsapp ?? '').trim().isNotEmpty)
        .toList();
    if (valid.isEmpty) {
      LoadingDialog.hide();
      ToastHelper.info('لا يوجد أولياء أمور بأرقام أو واتساب مسجلة');
      return;
    }

    LoadingDialog.hide();
    if (!context.mounted) return;
    final selected = await _pickRecipients(context, valid);
    if (selected == null || selected.isEmpty) return;

    // منتقي شهر التقرير — الافتراضي والحد الأقصى هو شهر التحصيل
    // (آخر شهر مكتمل) — spec 013 US3.
    if (!context.mounted) return;
    final collectionMonth = defaultCollectionMonth();
    final pickedMonth = await showDatePicker(
      context: context,
      initialDate: collectionMonth,
      firstDate: DateTime(collectionMonth.year - 3, 1, 1),
      lastDate: DateTime(collectionMonth.year, collectionMonth.month + 1, 0),
      helpText: 'اختر شهر التقرير',
    );
    if (pickedMonth == null) return;
    final month = DateTime(pickedMonth.year, pickedMonth.month, 1);
    final start = month;
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    var opened = 0;
    final failed = <String>[];
    for (final s in selected) {
      final group = await db.getGroup(s.groupId);

      final atts = await db.getAttendanceByStudent(s.id!);
      final pays = await db.getPaymentsByStudent(s.id!);
      final hw = await db.getHomeworkByStudent(s.id!);

      final attsMonth = atts
          .where((a) => !a.date.isBefore(start) && !a.date.isAfter(monthEnd))
          .toList();
      final paysMonth = pays
          .where((p) => !p.date.isBefore(start) && !p.date.isAfter(monthEnd))
          .toList();
      final hwMonth = hw
          .where((h) => !h.date.isBefore(start) && !h.date.isAfter(monthEnd))
          .toList();
      final examsMonth = (await db.getStudentExamHistory(s.id!))
          .where((r) =>
              r.reportMonth.year == month.year &&
              r.reportMonth.month == month.month)
          .toList();

      final message = buildMonthlyReportMessage(
        student: s,
        month: month,
        groupName: group?.name ?? '-',
        monthAtt: attsMonth,
        monthHw: hwMonth,
        monthPays: paysMonth,
        monthExams: examsMonth,
        teacherName: settings.teacherFullName.value,
        teacherSpecialization: settings.teacherSpecialization.value,
        canSeeFinancials: TeamModeService().canSeeFinancials,
        canSeeAcademics: TeamModeService().canSeeAcademics,
        bookletLines: bookletReportLines(s.id),
      );

      if (!context.mounted) break;
      // لو الفتح فشل (رقم غير صالح/واتساب ما فتحش) نعدّي للي بعده من غير انتظار —
      // الانتظار الأعمى لرجوع التطبيق كان بيعلّق الإرسال بعد عدد معيّن.
      final launched = await launchAndAwaitReturn(() => launchGuardianWhatsapp(
            context: context,
            phone: s.guardianPhone,
            whatsapp: s.guardianWhatsapp,
            message: message,
            dialCode: settings.countryDial.value,
          ));
      if (launched) {
        opened++;
      } else {
        failed.add(s.name);
      }
    }
    if (context.mounted) {
      if (failed.isEmpty) {
        ToastHelper.success('خلص: اتفتح واتساب لـ$opened ولي أمر');
      } else {
        ToastHelper.info('اتفتح $opened، وتعذّر ${failed.length}: '
            '${failed.take(3).join('، ')}${failed.length > 3 ? '…' : ''}');
      }
    }
  } catch (e) {
    LoadingDialog.hide();
    ToastHelper.error('تعذر التحضير أو الإرسال');
  }
}

Future<void> sendMonthlyReportsViaWhatsAppAuto(BuildContext context) async {
  final SettingsController settingsController = Get.find();
  await _startWhatsappBatchSend(context, settingsController);
}

// ══════════════════════════════════════════════════════════════════════════
//  Backup UI Helpers
// ══════════════════════════════════════════════════════════════════════════

/// صف معلومة صغير (أيقونة + نص)

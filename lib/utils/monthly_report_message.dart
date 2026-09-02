// lib/utils/monthly_report_message.dart
//
// مصدر واحد لبناء نص "تقرير الشهر" اللي بيتبعت لولي الأمر على واتساب —
// من المجموعة، أو الإرسال الجماعي من الإعدادات، أو صفحة الطالب. قبل
// spec 013 كان النص متكرّر في 3 نسخ باختلافات بسيطة. المتصل بيجمّع
// بيانات الطالب للشهر المطلوب (الحضور/الواجب/المدفوعات بالتاريخ،
// والامتحانات بـ effectiveReportMonth) وبينادي الدالة دي.
import 'package:intl/intl.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';

String buildMonthlyReportMessage({
  required Student student,
  required DateTime month,
  // spec 014 — لو periodStart != null: تقرير فترة [periodStart, periodEnd]
  // بدل الشهر. العنوان يتغيّر، والقسم المالي يتخفي بالكامل (Q3=B).
  DateTime? periodStart,
  DateTime? periodEnd,
  required String groupName,
  required List<Attendance> monthAtt,
  required List<Homework> monthHw,
  required List<Payment> monthPays,
  required List<StudentExamRecord> monthExams,
  required String teacherName,
  required String teacherSpecialization,
  required bool canSeeFinancials,
  required bool canSeeAcademics,
}) {
  final isPeriod = periodStart != null && periodEnd != null;
  final dFmt = DateFormat('d MMMM yyyy', 'ar');
  final monthLabel = isPeriod
      ? 'من ${dFmt.format(periodStart)} إلى ${dFmt.format(periodEnd)}'
      : DateFormat('MMMM yyyy', 'ar').format(month);

  final present =
      monthAtt.where((a) => attendanceCountsAsPresent(a.status)).length;
  final late = monthAtt
      .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_LATE)
      .length;
  final absent = monthAtt
      .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT)
      .length;
  final total = present + absent;
  final percent = total == 0 ? 0.0 : (present / total) * 100.0;

  final hwDone = monthHw
      .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_DONE)
      .length;
  final hwPartial = monthHw
      .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_PARTIAL)
      .length;
  final hwNotDone = monthHw
      .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_NOT_DONE)
      .length;

  final totalPaid = monthPays.fold<double>(0.0, (s, p) => s + p.amount);

  final attsSorted = List.of(monthAtt)..sort((a, b) => b.date.compareTo(a.date));
  final hwSorted = List.of(monthHw)..sort((a, b) => b.date.compareTo(a.date));
  final paysSorted = List.of(monthPays)..sort((a, b) => b.date.compareTo(a.date));
  final examsSorted = List.of(monthExams)
    ..sort((a, b) => b.examDate.compareTo(a.examDate));

  final buffer = StringBuffer()
    ..writeln(isPeriod ? '🧾 تقرير الفترة: $monthLabel' : '🧾 تقرير الشهر: $monthLabel')
    ..writeln('👤 الاسم: ${student.name}')
    ..writeln('🆔 الكود: ${student.code}')
    ..writeln('👥 المجموعة: $groupName')
    ..writeln(
        '📅 بداية الحضور: ${FormatHelper.formatDate(student.attendanceStart ?? student.createdAt)}')
    ..writeln('')
    ..writeln(late > 0
        ? '📊 الحضور: ✅ حاضر $present (منهم ⏰ متأخر $late) • ❌ غياب $absent • نسبة ${percent.toStringAsFixed(1)}%'
        : '📊 الحضور: ✅ حاضر $present • ❌ غياب $absent • نسبة ${percent.toStringAsFixed(1)}%');

  if (attsSorted.isNotEmpty) {
    buffer.writeln('\n📅 سجلات الحضور:');
    for (final a in attsSorted.take(10)) {
      buffer.writeln(
          '• ${DateFormat('yyyy-MM-dd').format(a.date)} — ${attendanceStatusLabel(a.status)}');
    }
    if (attsSorted.length > 10) {
      buffer.writeln('• … ${attsSorted.length - 10} سجلات إضافية');
    }
  }

  if (hwSorted.isNotEmpty) {
    buffer.writeln(
        '\n📖 الواجب: 🟢 تم الحل $hwDone • 🟡 ناقص $hwPartial • 🔴 لم يُحل $hwNotDone');
    for (final h in hwSorted.take(10)) {
      buffer.writeln(
          '• ${DateFormat('yyyy-MM-dd').format(h.date)} — ${homeworkStatusLabel(h.status)}');
    }
    if (hwSorted.length > 10) {
      buffer.writeln('• … ${hwSorted.length - 10} سجلات إضافية');
    }
  }

  // في وضع الفترة نخفي القسم المالي بالكامل — "المتبقّي/المديونية"
  // مفاهيم شهرية ومالهاش معنى لنطاق، وممكن تلبّس ولي الأمر (spec 014 Q3=B).
  if (canSeeFinancials && !isPeriod) {
    buffer.writeln(
        '\n💰 المدفوعات: إجمالي ${FormatHelper.formatCurrency(totalPaid)}');
    for (final p in paysSorted) {
      buffer.writeln(
          '• ${DateFormat('yyyy-MM-dd HH:mm').format(p.date)} — ${FormatHelper.formatCurrency(p.amount)}');
    }
  }

  if (canSeeAcademics && examsSorted.isNotEmpty) {
    buffer.writeln('\n📝 الامتحانات:');
    for (final r in examsSorted) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.examDate);
      if (r.isAbsent) {
        buffer.writeln('• $dateStr — ${r.examName}: غائب');
      } else if (r.grade != null) {
        buffer.writeln(
            '• $dateStr — ${r.examName}: ${FormatHelper.formatGrade(r.grade!)}/${r.maxGrade.toStringAsFixed(0)} (${r.category.label})');
      } else {
        buffer.writeln('• $dateStr — ${r.examName}: لم تُدخل الدرجة بعد');
      }
    }
  }

  final tName = teacherName.trim();
  final tSpec = teacherSpecialization.trim();
  if (tName.isNotEmpty || tSpec.isNotEmpty) {
    buffer
      ..writeln('\n👨‍🏫 المعلم: ${tName.isNotEmpty ? tName : '-'}')
      ..writeln('📘 التخصص: ${tSpec.isNotEmpty ? tSpec : '-'}');
  }

  buffer.writeln('\nتم الإرسال من تطبيق Active Class');
  return buffer.toString();
}

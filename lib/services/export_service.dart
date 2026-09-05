// lib/services/export_service.dart
// خدمة تصدير PDF لتقارير Active Class

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';

import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/pricing_helper.dart';

// ═══════════════════════════════════════════════════════════════════════
//  ExportFormat — صيغة ملف التصدير (spec 023 — تصدير نتائج الامتحان)
// ═══════════════════════════════════════════════════════════════════════
enum ExportFormat { xlsx, pdf }

// ═══════════════════════════════════════════════════════════════════════
//  ExportResult
// ═══════════════════════════════════════════════════════════════════════
class ExportResult {
  final bool success;
  final String? path;
  final String? error;
  ExportResult.ok(this.path)
      : success = true,
        error = null;
  ExportResult.fail(this.error)
      : success = false,
        path = null;
}

// ═══════════════════════════════════════════════════════════════════════
//  ExportService
// ═══════════════════════════════════════════════════════════════════════
class ExportService {
  static final ExportService _i = ExportService._();
  factory ExportService() => _i;
  ExportService._();

  // ── الألوان الرئيسية ──────────────────────────────────────────────
  static const _primary = PdfColor.fromInt(0xFF1565C0);
  static const _accent = PdfColor.fromInt(0xFF42A5F5);
  static const _success = PdfColor.fromInt(0xFF2E7D32);
  static const _warning = PdfColor.fromInt(0xFFF57F17);
  static const _error = PdfColor.fromInt(0xFFC62828);
  static const _grey = PdfColor.fromInt(0xFF757575);
  static const _lightGrey = PdfColor.fromInt(0xFFF5F5F5);
  static const _white = PdfColors.white;

  pw.Font? _regular;
  pw.Font? _bold;

  Future<void> _loadFonts() async {
    if (_regular != null) return;
    final regData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    _regular = pw.Font.ttf(regData);
    _bold = pw.Font.ttf(boldData);
  }

  pw.TextStyle _style({
    double size = 11,
    bool bold = false,
    PdfColor color = PdfColors.black,
  }) =>
      pw.TextStyle(
        font: bold ? _bold : _regular,
        fontBold: _bold,
        fontSize: size,
        color: color,
      );

  // ─────────────────────────────────────────────────────────────────
  //  تقرير الدفعات الشهري
  // ─────────────────────────────────────────────────────────────────
  Future<ExportResult> exportPaymentsPDF({
    required DateTime month,
    required List<Student> students,
    required List<Payment> payments,
    required List<Group> groups,
    required List<Attendance> attendance,
  }) async {
    try {
      await _loadFonts();
      final doc = pw.Document();

      // إجمالي كل مدفوعات الطالب (بغض النظر عن تاريخها) مقابل إجمالي
      // المستحق من شهر انضمامه لحد الشهر ده — نفس منطق المديونية المتراكمة
      // (PricingHelper) المستخدم في باقي التطبيق، عشان عمود "الحالة" هنا
      // ميقولش "لم يدفع" على طالب دافع مقدَّمًا شهر فات، أو "مكتمل" على
      // طالب لسه عليه شهر قديم.
      final paidMap = <int, double>{};
      for (final p in payments) {
        paidMap.update(p.studentId, (v) => v + p.amount,
            ifAbsent: () => p.amount);
      }
      final groupById = {for (final g in groups) g.id: g};

      // ترتيب: المجموعة ثم الاسم
      final sorted = List<Student>.from(students)
        ..sort((a, b) {
          final gc = a.groupId.compareTo(b.groupId);
          return gc != 0 ? gc : a.name.compareTo(b.name);
        });

      double totalExpected = 0;
      double totalPaid = 0;
      for (final s in sorted) {
        if (!s.isFullyExempt) {
          totalExpected += PricingHelper.totalDueThrough(
            student: s,
            group: groupById[s.groupId],
            month: month,
            allAttendance: attendance,
            siblingGroupMembers: students,
          );
          totalPaid += paidMap[s.id] ?? 0;
        }
      }

      final monthLabel = DateFormat('MMMM yyyy', 'ar').format(month);

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _pageHeader('تقرير الدفعات — $monthLabel'),
        footer: (ctx) => _pageFooter(ctx),
        build: (ctx) => [
          _summaryRow(totalExpected, totalPaid, sorted.length, monthLabel),
          pw.SizedBox(height: 16),
          _paymentsTable(sorted, paidMap, groupById, month, attendance),
        ],
      ));

      return _savePdf(doc, 'payments_${_fileMonth(month)}');
    } catch (e) {
      return ExportResult.fail('فشل إنشاء PDF: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  تقرير الحضور الشهري
  // ─────────────────────────────────────────────────────────────────
  Future<ExportResult> exportAttendancePDF({
    required DateTime month,
    // spec 014 — لو != null: تقرير فترة [month, periodEnd] شاملاً الطرفين
    // (month هنا = تاريخ البداية الفعلي، مش أول الشهر).
    DateTime? periodEnd,
    required List<Student> students,
    required List<Attendance> attendance,
    required List<Group> groups,
  }) async {
    try {
      await _loadFonts();
      final doc = pw.Document();

      final isRange = periodEnd != null;
      final start = isRange
          ? DateTime(month.year, month.month, month.day)
          : DateTime(month.year, month.month, 1);
      final end = isRange
          ? DateTime(periodEnd.year, periodEnd.month, periodEnd.day, 23, 59, 59)
          : DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final rangeAtt = attendance
          .where((a) => !a.date.isBefore(start) && !a.date.isAfter(end))
          .toList();

      // Map: studentId → Map<تاريخ اليوم, status>
      final attMap = <int, Map<DateTime, String>>{};
      for (final a in rangeAtt) {
        final d = DateTime(a.date.year, a.date.month, a.date.day);
        attMap.putIfAbsent(a.studentId, () => {})[d] = a.status;
      }
      final groupById = {for (final g in groups) g.id: g};

      final sorted = List<Student>.from(students)
        ..sort((a, b) {
          final gc = a.groupId.compareTo(b.groupId);
          return gc != 0 ? gc : a.name.compareTo(b.name);
        });

      final label = isRange
          ? _periodLabel(start, periodEnd)
          : DateFormat('MMMM yyyy', 'ar').format(month);

      // ننشئ صفحات منفصلة لكل مجموعة لأن الجدول عريض
      final byGroup = <int, List<Student>>{};
      for (final s in sorted) {
        byGroup.putIfAbsent(s.groupId, () => []).add(s);
      }

      for (final entry in byGroup.entries) {
        final g = groupById[entry.key];
        final gLabel = g?.name ?? 'مجموعة ${entry.key}';
        final gStudents = entry.value;

        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(20),
          header: (_) => _pageHeader('تقرير الحضور — $gLabel — $label'),
          footer: (ctx) => _pageFooter(ctx),
          build: (ctx) => [
            _attendanceTable(gStudents, attMap, start, end, isRange),
            pw.SizedBox(height: 12),
            _attendanceSummary(gStudents, attMap),
          ],
        ));
      }

      return _savePdf(
          doc,
          isRange
              ? 'attendance_${_fileRange(start, periodEnd)}'
              : 'attendance_${_fileMonth(month)}');
    } catch (e) {
      return ExportResult.fail('فشل إنشاء PDF: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  تقرير الواجب الشهري
  // ─────────────────────────────────────────────────────────────────
  Future<ExportResult> exportHomeworkPDF({
    required DateTime month,
    // spec 014 — لو != null: تقرير فترة [month, periodEnd] شاملاً الطرفين.
    DateTime? periodEnd,
    required List<Student> students,
    required List<Homework> homework,
    required List<Group> groups,
  }) async {
    try {
      await _loadFonts();
      final doc = pw.Document();

      final isRange = periodEnd != null;
      final start = isRange
          ? DateTime(month.year, month.month, month.day)
          : DateTime(month.year, month.month, 1);
      final end = isRange
          ? DateTime(periodEnd.year, periodEnd.month, periodEnd.day, 23, 59, 59)
          : DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final rangeHw = homework
          .where((h) => !h.date.isBefore(start) && !h.date.isAfter(end))
          .toList();

      final hwMap = <int, Map<DateTime, String>>{};
      for (final h in rangeHw) {
        final d = DateTime(h.date.year, h.date.month, h.date.day);
        hwMap.putIfAbsent(h.studentId, () => {})[d] = h.status;
      }
      final groupById = {for (final g in groups) g.id: g};

      final sorted = List<Student>.from(students)
        ..sort((a, b) {
          final gc = a.groupId.compareTo(b.groupId);
          return gc != 0 ? gc : a.name.compareTo(b.name);
        });

      final label = isRange
          ? _periodLabel(start, periodEnd)
          : DateFormat('MMMM yyyy', 'ar').format(month);

      final byGroup = <int, List<Student>>{};
      for (final s in sorted) {
        byGroup.putIfAbsent(s.groupId, () => []).add(s);
      }

      for (final entry in byGroup.entries) {
        final g = groupById[entry.key];
        final gLabel = g?.name ?? 'مجموعة ${entry.key}';
        final gStudents = entry.value;

        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(20),
          header: (_) => _pageHeader('تقرير الواجب — $gLabel — $label'),
          footer: (ctx) => _pageFooter(ctx),
          build: (ctx) => [
            _homeworkTable(gStudents, hwMap, start, end, isRange),
            pw.SizedBox(height: 12),
            _homeworkSummary(gStudents, hwMap),
          ],
        ));
      }

      return _savePdf(
          doc,
          isRange
              ? 'homework_${_fileRange(start, periodEnd)}'
              : 'homework_${_fileMonth(month)}');
    } catch (e) {
      return ExportResult.fail('فشل إنشاء PDF: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  تقرير ملخص المجموعات
  // ─────────────────────────────────────────────────────────────────
  Future<ExportResult> exportGroupsSummaryPDF({
    required DateTime month,
    required List<Student> students,
    required List<Payment> payments,
    required List<Attendance> attendance,
    required List<Group> groups,
  }) async {
    try {
      await _loadFonts();
      final doc = pw.Document();

      final monthAtt = attendance
          .where(
              (a) => a.date.year == month.year && a.date.month == month.month)
          .toList();

      // إجمالي كل مدفوعات الطالب لحد الآن، لا مدفوعات الشهر ده بس — نفس
      // منطق المديونية المتراكمة في باقي التطبيق.
      final paidMap = <int, double>{};
      for (final p in payments) {
        paidMap.update(p.studentId, (v) => v + p.amount,
            ifAbsent: () => p.amount);
      }
      final presentMap = <int, int>{};
      for (final a in monthAtt) {
        if (attendanceCountsAsPresent(a.status)) {
          presentMap.update(a.studentId, (v) => v + 1, ifAbsent: () => 1);
        }
      }

      final monthLabel = DateFormat('MMMM yyyy', 'ar').format(month);

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _pageHeader('ملخص المجموعات — $monthLabel'),
        footer: (ctx) => _pageFooter(ctx),
        build: (ctx) => [
          _groupsSummaryTable(
              groups, students, paidMap, presentMap, month, attendance),
        ],
      ));

      return _savePdf(doc, 'summary_${_fileMonth(month)}');
    } catch (e) {
      return ExportResult.fail('فشل إنشاء PDF: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  مشاركة ملف PDF
  // ─────────────────────────────────────────────────────────────────
  Future<void> sharePDF(String path) async {
    try {
      await Share.shareXFiles(
        [XFile(path)],
        text: 'تقرير Active Class — ${p.basename(path)}',
      );
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════
  //  Private builders
  // ══════════════════════════════════════════════════════════════════

  pw.Widget _pageHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _primary, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Text(title,
                style: _style(size: 14, bold: true, color: _primary),
                maxLines: 2),
          ),
          pw.SizedBox(width: 8),
          pw.Text('Active Class', style: _style(size: 10, color: _grey)),
        ],
      ),
    );
  }

  pw.Widget _pageFooter(pw.Context ctx) {
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _grey, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
              style: _style(size: 9, color: _grey)),
          pw.Text('تم التصدير: $now', style: _style(size: 9, color: _grey)),
        ],
      ),
    );
  }

  // ── ملخص الدفعات ─────────────────────────────────────────────────
  pw.Widget _summaryRow(double expected, double paid, int count, String month) {
    final remaining = (expected - paid).clamp(0.0, double.infinity);
    final rate = expected > 0 ? (paid / expected * 100) : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _accent, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _statBox('إجمالي الطلاب', '$count طالب', _primary),
          _statBox('المتوقع', _fmt(expected), _grey),
          _statBox('المحصّل', _fmt(paid), _success),
          _statBox(
              'المتبقي', _fmt(remaining), remaining > 0 ? _error : _success),
          _statBox(
              'نسبة التحصيل',
              '${rate.toStringAsFixed(1)}%',
              rate >= 80
                  ? _success
                  : rate >= 50
                      ? _warning
                      : _error),
        ],
      ),
    );
  }

  pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Column(children: [
      pw.Text(value, style: _style(size: 13, bold: true, color: color)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: _style(size: 9, color: _grey)),
    ]);
  }

  // ── جدول الدفعات ─────────────────────────────────────────────────
  pw.Widget _paymentsTable(List<Student> students, Map<int, double> paidMap,
      Map<int?, Group> groupById, DateTime month, List<Attendance> attendance) {
    const headers = [
      '#',
      'الاسم',
      'الكود',
      'المجموعة',
      'المطلوب',
      'المدفوع',
      'المتبقي',
      'الحالة'
    ];
    final colWidths = [
      pw.FixedColumnWidth(25),
      pw.FlexColumnWidth(3),
      pw.FlexColumnWidth(1.5),
      pw.FlexColumnWidth(2),
      pw.FlexColumnWidth(1.5),
      pw.FlexColumnWidth(1.5),
      pw.FlexColumnWidth(1.5),
      pw.FlexColumnWidth(1.5),
    ];

    final rows = <List<pw.Widget>>[];

    // Header
    rows.add(headers.map((h) => _th(h)).toList());

    // Rows
    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      final group = groupById[s.groupId];
      final paid = paidMap[s.id] ?? 0;
      final due = PricingHelper.totalDueThrough(
        student: s,
        group: group,
        month: month,
        allAttendance: attendance,
        siblingGroupMembers: students,
      );
      final remaining = (due - paid).clamp(0.0, double.infinity);
      final isEven = i % 2 == 0;

      String status;
      PdfColor statusColor;
      if (s.isFullyExempt) {
        status = 'معفى';
        statusColor = _success;
      } else if (paid >= due && due > 0) {
        status = 'مكتمل';
        statusColor = _success;
      } else if (paid > 0) {
        status = 'جزئي';
        statusColor = _warning;
      } else {
        status = 'لم يدفع';
        statusColor = _error;
      }

      rows.add([
        _td('${i + 1}', isEven: isEven),
        _td(s.name, isEven: isEven, bold: true),
        _td(s.code, isEven: isEven),
        _td(group?.name ?? '—', isEven: isEven),
        _td(_fmt(due), isEven: isEven),
        _td(_fmt(paid), isEven: isEven),
        _td(_fmt(remaining),
            isEven: isEven, color: remaining > 0 ? _error : _success),
        _tdStatus(status, statusColor, isEven: isEven),
      ]);
    }

    return pw.Table(
      columnWidths: {
        for (var i = 0; i < colWidths.length; i++) i: colWidths[i]
      },
      children: rows.map((cells) => pw.TableRow(children: cells)).toList(),
    );
  }

  // ── جدول الحضور ──────────────────────────────────────────────────
  pw.Widget _attendanceTable(List<Student> students,
      Map<int, Map<DateTime, String>> attMap, DateTime start, DateTime end,
      bool isRange) {
    // أعمدة الأيام = التواريخ اللي فيها تسجيل حصص فعلي فقط (spec 013 US5).
    // في وضع الفترة (spec 014) الترويسة تعرض يوم/شهر عشان الفترة اللي
    // بتمتد على أكتر من شهر ما يحصلش فيها لبس.
    final dateSet = <DateTime>{};
    for (final m in attMap.values) {
      dateSet.addAll(m.keys);
    }
    final sortedDates = dateSet.toList()..sort();
    if (sortedDates.isEmpty) {
      final label = isRange
          ? 'الفترة ${_periodLabel(start, end)}'
          : DateFormat('MMMM yyyy', 'ar').format(start);
      return pw.Text('لا توجد حصص مسجّلة في $label',
          style: _style(size: 10, color: _grey));
    }
    final n = sortedDates.length;

    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.5), // الاسم
    };
    for (var i = 1; i <= n; i++) {
      colWidths[i] = const pw.FixedColumnWidth(18);
    }
    colWidths[n + 1] = const pw.FixedColumnWidth(30); // حضور
    colWidths[n + 2] = const pw.FixedColumnWidth(30); // غياب

    final rows = <pw.TableRow>[];

    final headerCells = <pw.Widget>[_th('الاسم', size: 8)];
    for (final d in sortedDates) {
      final head = isRange ? '${d.day}/${d.month}' : '${d.day}';
      headerCells.add(_thSmall('$head\n${_weekdayShort(d.weekday)}'));
    }
    headerCells.add(_th('ح', size: 8));
    headerCells.add(_th('غ', size: 8));
    rows.add(pw.TableRow(children: headerCells));

    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      final sAtt = attMap[s.id] ?? {};
      final isEven = i % 2 == 0;
      int presentCount = 0;
      int absentCount = 0;

      final cells = <pw.Widget>[
        _td(s.name, isEven: isEven, bold: true, size: 8),
      ];
      for (final d in sortedDates) {
        final norm = normalizeAttendanceStatus(sAtt[d]);
        if (norm == ATTENDANCE_LATE) {
          presentCount++; // "متأخر" حضور (spec 011)
          cells.add(_attCell(true, isEven, late: true));
        } else if (norm == ATTENDANCE_PRESENT) {
          presentCount++;
          cells.add(_attCell(true, isEven));
        } else if (norm == ATTENDANCE_ABSENT) {
          absentCount++;
          cells.add(_attCell(false, isEven));
        } else {
          cells.add(_attCell(null, isEven));
        }
      }
      cells.add(_td('$presentCount', isEven: isEven, color: _success, size: 9));
      cells.add(_td('$absentCount', isEven: isEven, color: _error, size: 9));
      rows.add(pw.TableRow(children: cells));
    }

    return pw.Table(columnWidths: colWidths, children: rows);
  }

  pw.Widget _attendanceSummary(
      List<Student> students, Map<int, Map<DateTime, String>> attMap) {
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalLate = 0;
    for (final s in students) {
      final sAtt = attMap[s.id] ?? {};
      totalPresent +=
          sAtt.values.where((v) => attendanceCountsAsPresent(v)).length;
      totalLate += sAtt.values
          .where((v) => normalizeAttendanceStatus(v) == ATTENDANCE_LATE)
          .length;
      totalAbsent += sAtt.values
          .where((v) => normalizeAttendanceStatus(v) == ATTENDANCE_ABSENT)
          .length;
    }
    final total = totalPresent + totalAbsent;
    final rate = total > 0 ? (totalPresent / total * 100) : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _statBox('إجمالي الحضور', '$totalPresent جلسة', _success),
          if (totalLate > 0)
            _statBox('منها متأخر', '$totalLate جلسة', _warning),
          _statBox('إجمالي الغياب', '$totalAbsent جلسة', _error),
          _statBox(
              'نسبة الحضور',
              '${rate.toStringAsFixed(1)}%',
              rate >= 80
                  ? _success
                  : rate >= 60
                      ? _warning
                      : _error),
        ],
      ),
    );
  }

  // ── جدول الواجب ──────────────────────────────────────────────────
  pw.Widget _homeworkTable(List<Student> students,
      Map<int, Map<DateTime, String>> hwMap, DateTime start, DateTime end,
      bool isRange) {
    // أعمدة الأيام = تواريخ التسجيل الفعلي فقط (spec 013 US5)؛ ترويسة
    // يوم/شهر في وضع الفترة (spec 014).
    final dateSet = <DateTime>{};
    for (final m in hwMap.values) {
      dateSet.addAll(m.keys);
    }
    final sortedDates = dateSet.toList()..sort();
    if (sortedDates.isEmpty) {
      final label = isRange
          ? 'الفترة ${_periodLabel(start, end)}'
          : DateFormat('MMMM yyyy', 'ar').format(start);
      return pw.Text('لا يوجد واجب مسجّل في $label',
          style: _style(size: 10, color: _grey));
    }
    final n = sortedDates.length;

    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.5),
    };
    for (var i = 1; i <= n; i++) {
      colWidths[i] = const pw.FixedColumnWidth(18);
    }
    colWidths[n + 1] = const pw.FixedColumnWidth(30);
    colWidths[n + 2] = const pw.FixedColumnWidth(30);

    final rows = <pw.TableRow>[];

    final headerCells = <pw.Widget>[_th('الاسم', size: 8)];
    for (final d in sortedDates) {
      final head = isRange ? '${d.day}/${d.month}' : '${d.day}';
      headerCells.add(_thSmall('$head\n${_weekdayShort(d.weekday)}'));
    }
    headerCells.add(_th('عمل', size: 8));
    headerCells.add(_th('لم يعمل', size: 8));
    rows.add(pw.TableRow(children: headerCells));

    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      final sHw = hwMap[s.id] ?? {};
      final isEven = i % 2 == 0;
      int doneCount = 0;
      int notDoneCount = 0;

      final cells = <pw.Widget>[
        _td(s.name, isEven: isEven, bold: true, size: 8),
      ];
      for (final d in sortedDates) {
        // الناقص يُحتسب كـ"عمل" في تقرير الواجب PDF (محاولة تُحتسب).
        final status = normalizeHomeworkStatus(sHw[d]);
        if (status == HOMEWORK_DONE || status == HOMEWORK_PARTIAL) {
          doneCount++;
          cells.add(_attCell(true, isEven));
        } else if (status == HOMEWORK_NOT_DONE) {
          notDoneCount++;
          cells.add(_attCell(false, isEven));
        } else {
          cells.add(_attCell(null, isEven));
        }
      }
      cells.add(_td('$doneCount', isEven: isEven, color: _success, size: 9));
      cells.add(_td('$notDoneCount', isEven: isEven, color: _error, size: 9));
      rows.add(pw.TableRow(children: cells));
    }

    return pw.Table(columnWidths: colWidths, children: rows);
  }

  pw.Widget _homeworkSummary(
      List<Student> students, Map<int, Map<DateTime, String>> hwMap) {
    int totalDone = 0;
    int totalNotDone = 0;
    for (final s in students) {
      final sHw = hwMap[s.id] ?? {};
      totalDone += sHw.values.where((v) {
        final n = normalizeHomeworkStatus(v);
        return n == HOMEWORK_DONE || n == HOMEWORK_PARTIAL;
      }).length;
      totalNotDone += sHw.values
          .where((v) => normalizeHomeworkStatus(v) == HOMEWORK_NOT_DONE)
          .length;
    }
    final total = totalDone + totalNotDone;
    final rate = total > 0 ? (totalDone / total * 100) : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _statBox('إجمالي عمل الواجب', '$totalDone', _success),
          _statBox('إجمالي لم يعمل', '$totalNotDone', _error),
          _statBox(
              'نسبة الالتزام',
              '${rate.toStringAsFixed(1)}%',
              rate >= 80
                  ? _success
                  : rate >= 60
                      ? _warning
                      : _error),
        ],
      ),
    );
  }

  // ── جدول ملخص المجموعات ──────────────────────────────────────────
  pw.Widget _groupsSummaryTable(
      List<Group> groups,
      List<Student> students,
      Map<int, double> paidMap,
      Map<int, int> presentMap,
      DateTime month,
      List<Attendance> allAttendance) {
    final byGroup = <int, List<Student>>{};
    for (final s in students) {
      byGroup.putIfAbsent(s.groupId, () => []).add(s);
    }

    const headers = [
      'المجموعة',
      'الطلاب',
      'معفيون',
      'المتوقع',
      'المحصّل',
      'نسبة التحصيل',
      'جلسات الحضور'
    ];
    final colWidths = [
      pw.FlexColumnWidth(2.5),
      pw.FixedColumnWidth(45),
      pw.FixedColumnWidth(45),
      pw.FlexColumnWidth(1.5),
      pw.FlexColumnWidth(1.5),
      pw.FlexColumnWidth(1.5),
      pw.FlexColumnWidth(1.5),
    ];

    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(children: headers.map((h) => _th(h)).toList()));

    double grandExpected = 0;
    double grandPaid = 0;
    int grandStudents = 0;

    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final gStudents = byGroup[g.id] ?? [];
      final exempt = gStudents.where((s) => s.isFullyExempt).length;
      final active = gStudents.where((s) => !s.isFullyExempt).toList();
      // بيستخدم PricingHelper بدل effectivePrice مباشرة عشان مجموعات
      // "بالحصة" تُحسَب بعدد الحصص المحضورة فعليًا الشهر ده.
      final expected = active.fold<double>(
          0,
          (s, st) =>
              s +
              PricingHelper.totalDueThrough(
                  student: st,
                  group: g,
                  month: month,
                  allAttendance: allAttendance,
                  siblingGroupMembers: students));
      final paid = active.fold<double>(0, (s, st) => s + (paidMap[st.id] ?? 0));
      final sessions =
          gStudents.fold<int>(0, (s, st) => s + (presentMap[st.id] ?? 0));
      final rate = expected > 0 ? paid / expected * 100 : 0.0;
      final isEven = i % 2 == 0;

      grandExpected += expected;
      grandPaid += paid;
      grandStudents += gStudents.length;

      rows.add(pw.TableRow(children: [
        _td(g.name, isEven: isEven, bold: true),
        _td('${gStudents.length}', isEven: isEven),
        _td('$exempt', isEven: isEven, color: exempt > 0 ? _success : _grey),
        _td(_fmt(expected), isEven: isEven),
        _td(_fmt(paid), isEven: isEven),
        _tdStatus(
          '${rate.toStringAsFixed(0)}%',
          rate >= 80
              ? _success
              : rate >= 50
                  ? _warning
                  : _error,
          isEven: isEven,
        ),
        _td('$sessions', isEven: isEven),
      ]));
    }

    // Row الإجمالي
    final grandRate = grandExpected > 0 ? grandPaid / grandExpected * 100 : 0.0;
    rows.add(pw.TableRow(children: [
      _thTotal('الإجمالي'),
      _thTotal('$grandStudents'),
      _thTotal(''),
      _thTotal(_fmt(grandExpected)),
      _thTotal(_fmt(grandPaid)),
      _thTotal('${grandRate.toStringAsFixed(0)}%'),
      _thTotal(''),
    ]));

    return pw.Table(
      columnWidths: {
        for (var i = 0; i < colWidths.length; i++) i: colWidths[i]
      },
      children: rows,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  Cell builders
  // ══════════════════════════════════════════════════════════════════

  pw.Widget _th(String text, {double size = 10}) => pw.Container(
        color: _primary,
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: _style(size: size, bold: true, color: _white),
            textAlign: pw.TextAlign.center),
      );

  pw.Widget _thSmall(String text) => pw.Container(
        color: _primary,
        padding: const pw.EdgeInsets.all(2),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: _style(size: 6.5, bold: true, color: _white),
            textAlign: pw.TextAlign.center),
      );

  pw.Widget _thTotal(String text) => pw.Container(
        color: _accent,
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: _style(size: 10, bold: true, color: _white),
            textAlign: pw.TextAlign.center),
      );

  pw.Widget _td(
    String text, {
    bool isEven = true,
    bool bold = false,
    PdfColor? color,
    double size = 10,
  }) =>
      pw.Container(
        color: isEven ? _white : _lightGrey,
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style:
                _style(size: size, bold: bold, color: color ?? PdfColors.black),
            textAlign: pw.TextAlign.center),
      );

  pw.Widget _tdStatus(String text, PdfColor color, {bool isEven = true}) =>
      pw.Container(
        color: isEven ? _white : _lightGrey,
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        alignment: pw.Alignment.center,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
          decoration: pw.BoxDecoration(
            color: PdfColor(color.red, color.green, color.blue, 0.15),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: color, width: 0.5),
          ),
          child: pw.Text(text,
              style: _style(size: 9, bold: true, color: color),
              textAlign: pw.TextAlign.center),
        ),
      );

  // نرسم علامة الحضور/الغياب كشكل هندسي بدل رموز يونيكود (✓/●) — دي
  // مش مضمونة موجودة في خط Cairo المرفق، وبتطلع مربعات فاضية في الـPDF.
  pw.Widget _attCell(bool? present, bool isEven, {bool late = false}) =>
      pw.Container(
        color: isEven ? _white : _lightGrey,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.all(1),
        child: present == null
            ? pw.SizedBox()
            : pw.Container(
                width: 7,
                height: 7,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: late ? _warning : (present ? _success : null),
                  border: (present || late)
                      ? null
                      : pw.Border.all(color: _error, width: 1),
                ),
              ),
      );

  // ══════════════════════════════════════════════════════════════════
  //  Helpers
  // ══════════════════════════════════════════════════════════════════

  String _fmt(double v) => NumberFormat('#,##0', 'ar').format(v);

  String _fileMonth(DateTime m) =>
      '${m.year}_${m.month.toString().padLeft(2, '0')}';

  // spec 014 — تسمية/عنوان الفترة المخصصة
  String _fileRange(DateTime from, DateTime to) {
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    return '${d(from)}_الى_${d(to)}';
  }

  String _periodLabel(DateTime from, DateTime to) {
    final f = DateFormat('d MMMM yyyy', 'ar');
    return 'من ${f.format(from)} إلى ${f.format(to)}';
  }

  String _weekdayShort(int wd) {
    const days = ['', 'ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    return days[wd];
  }

  Future<ExportResult> _savePdf(pw.Document doc, String name) async {
    final bytes = await doc.save();
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'exports'));
    if (!folder.existsSync()) folder.createSync(recursive: true);
    final path = p.join(folder.path, '$name.pdf');
    await File(path).writeAsBytes(bytes);
    return ExportResult.ok(path);
  }
}

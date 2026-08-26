// lib/views/exams/exam_grades_page.dart
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/utils/helpers.dart';

class ExamGradesPage extends StatefulWidget {
  final Exam exam;
  final int groupId;
  final String groupName;

  const ExamGradesPage({
    super.key,
    required this.exam,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<ExamGradesPage> createState() => _ExamGradesPageState();
}

class _ExamGradesPageState extends State<ExamGradesPage> {
  late final ExamController _ec;
  List<ExamGrade> _grades = [];
  bool _loading = true;
  ExamGroupStats? _stats;

  final Map<int, TextEditingController> _ctrls = {};
  final Map<int, TextEditingController> _notes = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  // طابور بدل قفل: لو فيه حفظ شغال لنفس الطالب، الطلب الجديد بينتظره
  // يخلص الأول بدل ما يتجاهَل (منع فقدان تعديلات لو المستخدم كان سريع).
  final Map<int, Future<void>> _pending = {};

  @override
  void initState() {
    super.initState();
    _ec = Get.find<ExamController>();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<ExamGrade> get _filteredGrades {
    final q = _searchQuery.trim();
    if (q.isEmpty) return _grades;
    return _grades
        .where((g) => (g.studentName ?? '').contains(q))
        .toList();
  }

  // ── إحصائيات فورية من القائمة المحلية (بدون استعلام DB) ──────────────────
  ExamGroupStats _computeStatsFromGrades(List<ExamGrade> grades) {
    final absentList = grades.where((g) => g.isAbsent).toList();
    final entered = grades.where((g) => g.grade != null).toList();
    final maxGrade = widget.exam.maxGrade;
    final passingGrade = widget.exam.passingGrade;

    final passed = entered.where((g) => g.grade! >= passingGrade).length;
    final values = entered.map((g) => g.grade!).toList();

    final passingPct = maxGrade > 0 ? (passingGrade / maxGrade) * 100 : 60;
    int excellent = 0, veryGood = 0, good = 0, pass = 0, fail = 0;
    for (final g in entered) {
      final pct = maxGrade > 0 ? (g.grade! / maxGrade) * 100 : 0;
      if (pct >= 90) {
        excellent++;
      } else if (pct >= 80) {
        veryGood++;
      } else if (pct >= 70) {
        good++;
      } else if (pct >= passingPct) {
        pass++;
      } else {
        fail++;
      }
    }

    return ExamGroupStats(
      examId: widget.exam.id!,
      groupId: widget.groupId,
      groupName: widget.groupName,
      total: grades.length,
      entered: entered.length,
      passed: passed,
      failed: entered.length - passed,
      absent: absentList.length,
      average:
          values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length,
      highest: values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b),
      lowest: values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b),
      distribution: GradeDistribution(
        excellent: excellent,
        veryGood: veryGood,
        good: good,
        pass: pass,
        fail: fail,
        absent: absentList.length,
      ),
    );
  }

  // ── ضمان حفظ أي تعديل لسه ماوصلش لقاعدة البيانات قبل الخروج من الشاشة ─────
  // بيقارن نص كل خانة (درجة/ملاحظة) بآخر قيمة معروفة في _grades — بغض
  // النظر عن حالة الفوكس، عشان الاعتماد على أحداث فقدان التركيز وحده طلع
  // مش موثوق بالشكل الكافي لما المستخدم يخرج من الشاشة (زرار الرجوع) قبل
  // ما مهلة الحفظ التلقائي (debounce) تخلص.
  Future<void> _flushPendingEdits() async {
    final futures = <Future<void>>[..._pending.values];
    for (final g in _grades) {
      final ctrl = _ctrls[g.studentId];
      if (ctrl == null) continue;
      final expectedGradeText =
          g.isAbsent ? '' : (g.grade != null ? _fmt(g.grade!) : '');
      final expectedNotesText = g.notes ?? '';
      final notesCtrl = _notes[g.studentId];
      final gradeDirty = ctrl.text.trim() != expectedGradeText.trim();
      final notesDirty =
          (notesCtrl?.text.trim() ?? '') != expectedNotesText.trim();
      if (gradeDirty || notesDirty) {
        futures.add(_saveGrade(g.studentId, ctrl.text, absent: g.isAbsent));
      }
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final grades =
        await _ec.getGradesForExamGroup(widget.exam.id!, widget.groupId);

    for (final g in grades) {
      if (!_ctrls.containsKey(g.studentId)) {
        _ctrls[g.studentId] = TextEditingController(
            text: g.isAbsent
                ? ''
                : g.grade != null
                    ? _fmt(g.grade!)
                    : '');
        _notes[g.studentId] = TextEditingController(text: g.notes ?? '');
      }
    }
    if (mounted) {
      setState(() {
        _grades = grades;
        _stats = _computeStatsFromGrades(grades);
        _loading = false;
      });
    }
  }

  String _fmt(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _saveGrade(int studentId, String raw, {bool? absent}) async {
    // طابور بدل تجاهل: انتظر أي عملية حفظ سابقة لنفس الطالب تخلص الأول
    final previous = _pending[studentId] ?? Future<void>.value();
    final run =
        previous.then((_) => _doSaveGrade(studentId, raw, absent: absent));
    final queued = run.catchError((_) {}); // متابعة الطابور حتى لو فشلت
    _pending[studentId] = queued;
    queued.whenComplete(() {
      if (identical(_pending[studentId], queued)) _pending.remove(studentId);
    });
    return run;
  }

  Future<void> _doSaveGrade(int studentId, String raw, {bool? absent}) async {
    try {
      double? val;
      final trimmed = raw.trim();
      final isAbsent = absent ?? false;

      if (!isAbsent && trimmed.isNotEmpty) {
        val = double.tryParse(trimmed);
        if (val == null) {
          return;
        }
        if (val < 0) val = 0;
        if (val > widget.exam.maxGrade) val = widget.exam.maxGrade;
        final corrected = _fmt(val);
        if (_ctrls[studentId]?.text != corrected) {
          _ctrls[studentId]?.text = corrected;
        }
      }

      final notesTrimmed = _notes[studentId]?.text.trim();
      final notesValue = (notesTrimmed == null || notesTrimmed.isEmpty)
          ? null
          : notesTrimmed;

      await _ec.saveGrade(
        examId: widget.exam.id!,
        studentId: studentId,
        grade: isAbsent ? null : val,
        notes: notesValue,
        isAbsent: isAbsent,
      );

      // تحديث فوري للقائمة المحلية (بدون إعادة تحميل من DB)
      if (!mounted) return;
      final idx = _grades.indexWhere((g) => g.studentId == studentId);
      if (idx >= 0) {
        setState(() {
          _grades[idx] = _grades[idx].copyWith(
              grade: isAbsent ? null : val,
              notes: notesValue,
              isAbsent: isAbsent);
          // إحصائيات فورية من نفس القائمة المحلية بدل استعلام DB مؤجَّل —
          // كان بيعتمد على مهلة 1.5 ث بعد آخر حفظ، فلو المدرّس دخل درجات
          // كتير بسرعة (أقل من 1.5 ث بين كل طالب والتاني) أو خرج من
          // الشاشة قبل ما المهلة تخلص، الإحصائيات كانت تفضل واقفة عند
          // قيمتها الأولى وميتحدّثش شكلها خالص خلال الجلسة.
          _stats = _computeStatsFromGrades(_grades);
        });
      }
    } catch (e) {
      if (mounted) ToastHelper.error('فشل حفظ الدرجة — حاول تاني');
      rethrow; // يوصل الخطأ للـ _GradeRowState._runSave عشان يقفل الـ spinner
    }
  }

  // ── تصدير النص (واتساب) ────────────────────────────────────────────────────
  Future<void> _shareText() async {
    final buffer = StringBuffer();
    buffer.writeln('📋 كشف درجات امتحان: ${widget.exam.name}');
    buffer.writeln('👥 المجموعة: ${widget.groupName}');
    buffer.writeln(
        '📅 ${DateFormat('d MMMM yyyy', 'ar').format(widget.exam.date)}');
    buffer.writeln(
        '📊 الدرجة الكاملة: ${widget.exam.maxGrade.toStringAsFixed(0)}');
    buffer.writeln('─' * 30);

    for (final g in _grades) {
      final name = g.studentName ?? '---';
      if (g.isAbsent) {
        buffer.writeln('⚠️ $name — غائب');
      } else if (g.grade != null) {
        final pct = widget.exam.maxGrade > 0
            ? (g.grade! / widget.exam.maxGrade * 100).toStringAsFixed(0)
            : '0';
        final cat = g.category.label;
        buffer.writeln('• $name — ${_fmt(g.grade!)} ($pct%) [$cat]');
      } else {
        buffer.writeln('○ $name — لم يُدخل');
      }
    }

    if (_stats != null) {
      buffer.writeln('─' * 30);
      buffer.writeln(
          '✅ ناجح: ${_stats!.passed}  |  ❌ راسب: ${_stats!.failed}  |  ⚠️ غياب: ${_stats!.absent}');
      if (_stats!.entered > 0) {
        buffer.writeln(
            '📈 متوسط: ${_stats!.average.toStringAsFixed(1)} | أعلى: ${_stats!.highest.toStringAsFixed(0)} | نسبة النجاح: ${_stats!.passRate.toStringAsFixed(0)}%');
      }
    }

    await Share.share(buffer.toString(),
        subject: 'كشف درجات ${widget.exam.name}');
  }

  // ── تصدير PDF ─────────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    // جلب الخط
    final font = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    final fontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      build: (ctx) => [
          // Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('4F46E5'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('كشف درجات',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 18, color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text(widget.exam.name,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 22, color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${widget.groupName}  —  ${DateFormat('d MMMM yyyy', 'ar').format(widget.exam.date)}',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      color: const PdfColor(1, 1, 1, 0.7)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Stats row
          if (_stats != null)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStat(font, fontBold, 'إجمالي الطلاب', '${_stats!.total}',
                    PdfColors.blue700),
                _pdfStat(font, fontBold, 'ناجح', '${_stats!.passed}',
                    PdfColors.green700),
                _pdfStat(font, fontBold, 'راسب', '${_stats!.failed}',
                    PdfColors.red700),
                _pdfStat(font, fontBold, 'غياب', '${_stats!.absent}',
                    PdfColors.orange700),
                if (_stats!.entered > 0)
                  _pdfStat(font, fontBold, 'المتوسط',
                      _stats!.average.toStringAsFixed(1), PdfColors.purple700),
              ],
            ),
          pw.SizedBox(height: 16),

          // Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
                children: ['اسم الطالب', 'الدرجة', 'النسبة', 'التصنيف']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 11,
                                  color: PdfColors.white),
                              textAlign: pw.TextAlign.center),
                        ))
                    .toList(),
              ),
              // Data rows
              ..._grades.asMap().entries.map((entry) {
                final i = entry.key;
                final g = entry.value;
                final bg = i.isEven
                    ? PdfColors.white
                    : const PdfColor.fromInt(0xFFF8FAFF);

                String gradeStr, pctStr, catStr;
                if (g.isAbsent) {
                  gradeStr = 'غائب';
                  pctStr = '---';
                  catStr = 'غائب';
                } else if (g.grade != null) {
                  gradeStr = _fmt(g.grade!);
                  pctStr =
                      '${(g.grade! / widget.exam.maxGrade * 100).toStringAsFixed(0)}%';
                  catStr = g.category.label;
                } else {
                  gradeStr = '---';
                  pctStr = '---';
                  catStr = 'لم يُدخل';
                }

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [g.studentName ?? '---', gradeStr, pctStr, catStr]
                      .map((t) => pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(t,
                                style: pw.TextStyle(font: font, fontSize: 10),
                                textAlign: pw.TextAlign.center),
                          ))
                      .toList(),
                );
              }),
            ],
          ),
        ],
    ));

    final bytes = await pdf.save();
    await Printing.sharePdf(
        bytes: bytes, filename: 'grades_${widget.exam.name}.pdf');
  }

  pw.Widget _pdfStat(pw.Font font, pw.Font bold, String label, String value,
          PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
            color: color, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(children: [
          pw.Text(value,
              style: pw.TextStyle(
                  font: bold, fontSize: 14, color: PdfColors.white)),
          pw.Text(label,
              style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  color: const PdfColor(1, 1, 1, 0.7))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _flushPendingEdits();
        if (context.mounted) Navigator.of(context).pop(result);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.exam.name,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            Text(widget.groupName,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'مشاركة النص',
            onPressed: _shareText,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'تصدير PDF',
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_stats != null)
                  _StatsPanel(stats: _stats!, maxGrade: widget.exam.maxGrade),
                if (_grades.length > 6)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن طالب...',
                        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                Expanded(
                  child: _grades.isEmpty
                      ? Center(
                          child: Text('لا يوجد طلاب في هذه المجموعة',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: cs.onSurface.withValues(alpha: 0.4))))
                      : _filteredGrades.isEmpty
                      ? Center(
                          child: Text('لا يوجد نتائج',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: cs.onSurface.withValues(alpha: 0.4))))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: _filteredGrades.length,
                          itemBuilder: (_, i) {
                            final g = _filteredGrades[i];
                            return _GradeRow(
                              key: ValueKey(g.studentId),
                              grade: g,
                              ctrl: _ctrls[g.studentId]!,
                              notesCtrl: _notes[g.studentId]!,
                              maxGrade: widget.exam.maxGrade,
                              passingGrade: widget.exam.passingGrade,
                              onSaved: (raw) => _saveGrade(g.studentId, raw,
                                  absent: g.isAbsent),
                              onAbsent: (val) =>
                                  _saveGrade(g.studentId, '', absent: val),
                              onNotesSaved: () => _saveGrade(
                                  g.studentId, _ctrls[g.studentId]?.text ?? '',
                                  absent: g.isAbsent),
                            );
                          },
                        ),
                ),
              ],
            ),
      ),
    );
  }
}

// ─── لوحة الإحصائيات + التوزيع ───────────────────────────────────────────────
class _StatsPanel extends StatelessWidget {
  final ExamGroupStats stats;
  final double maxGrade;
  const _StatsPanel({required this.stats, required this.maxGrade});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDark
          ? AppTheme.primaryColor.withValues(alpha: 0.08)
          : AppTheme.primaryColor.withValues(alpha: 0.04),
      child: Column(
        children: [
          // ── Stats row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _StatChip('المُدخلة', '${stats.entered}/${stats.total}',
                    AppTheme.primaryColor),
                _StatChip('ناجح', '${stats.passed}', AppTheme.successColor),
                _StatChip('راسب', '${stats.failed}', AppTheme.errorColor),
                _StatChip('غياب', '${stats.absent}', Colors.grey),
                if (stats.entered > 0) ...[
                  _StatChip('المتوسط', stats.average.toStringAsFixed(1),
                      AppTheme.warningColor),
                  _StatChip('نجاح%', '${stats.passRate.toStringAsFixed(0)}%',
                      Colors.teal),
                ],
              ],
            ),
          ),

          // ── توزيع الدرجات ──────────────────────────────────────
          if (stats.entered > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                height: 70,
                child: _DistributionChart(dist: stats.distribution),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  color: color.withValues(alpha: 0.8))),
        ],
      );
}

// ─── رسم بياني للتوزيع ────────────────────────────────────────────────────────
class _DistributionChart extends StatelessWidget {
  final GradeDistribution dist;
  const _DistributionChart({required this.dist});

  @override
  Widget build(BuildContext context) {
    final cats = [
      (GradeCategory.excellent, dist.excellent),
      (GradeCategory.veryGood, dist.veryGood),
      (GradeCategory.good, dist.good),
      (GradeCategory.pass, dist.pass),
      (GradeCategory.fail, dist.fail),
    ];
    final maxVal = cats.map((c) => c.$2).fold(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxVal + 1).toDouble(),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (val, meta) {
                final cat = cats[val.toInt()].$1;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(cat.label,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 9,
                          color: cat.color,
                          fontWeight: FontWeight.w700)),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: cats.asMap().entries.map((e) {
          final cat = e.value.$1;
          final count = e.value.$2;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: cat.color,
                width: 22,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                rodStackItems: [],
              ),
            ],
            showingTooltipIndicators: count > 0 ? [0] : [],
          );
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gIdx, rod, rIdx) => BarTooltipItem(
              '${rod.toY.toInt()}',
              const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── تحويل الأرقام العربية/الفارسية والفاصلة العشرية العربية لأرقام
// إنجليزية أثناء الكتابة — كيبورد سامسونج العربي بيطلع أرقام عربية
// (١٢٣) حتى في حقول الأرقام أحيانًا، و double.tryParse مش بيتعرف
// عليها خالص فبترجع null بصمت (من غير أي رسالة خطأ)، فالدرجة كانت
// بتضيع تمامًا من غير ما المدرس ياخد باله — شكلها بتتكتب عادي في
// الحقل بس مبتتحفظش أبداً.
class _ArabicDigitsInputFormatter extends TextInputFormatter {
  static const _easternArabic = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final buffer = StringBuffer();
    for (final ch in newValue.text.split('')) {
      final eastern = _easternArabic.indexOf(ch);
      final persian = _persian.indexOf(ch);
      if (eastern != -1) {
        buffer.write(eastern.toString());
      } else if (persian != -1) {
        buffer.write(persian.toString());
      } else if (ch == '٫') {
        buffer.write('.');
      } else {
        buffer.write(ch);
      }
    }
    final converted = buffer.toString();
    if (converted == newValue.text) return newValue;
    final lengthDiff = newValue.text.length - converted.length;
    return newValue.copyWith(
      text: converted,
      selection: TextSelection.collapsed(
        offset: (newValue.selection.baseOffset - lengthDiff)
            .clamp(0, converted.length),
      ),
    );
  }
}

// ─── صف درجة طالب ─────────────────────────────────────────────────────────────
class _GradeRow extends StatefulWidget {
  final ExamGrade grade;
  final TextEditingController ctrl;
  final TextEditingController notesCtrl;
  final double maxGrade;
  final double passingGrade;
  final Future<void> Function(String) onSaved;
  final Future<void> Function(bool) onAbsent;
  final Future<void> Function() onNotesSaved;

  const _GradeRow({
    super.key,
    required this.grade,
    required this.ctrl,
    required this.notesCtrl,
    required this.maxGrade,
    required this.passingGrade,
    required this.onSaved,
    required this.onAbsent,
    required this.onNotesSaved,
  });

  @override
  State<_GradeRow> createState() => _GradeRowState();
}

class _GradeRowState extends State<_GradeRow> {
  bool _saving = false;
  bool _showNotes = false;
  String _lastSaved = ''; // آخر قيمة اتحفظت — منع double-fire
  String _lastSavedNotes = '';
  late final FocusNode _gradeFocusNode;
  late final FocusNode _notesFocusNode;
  // شبكة أمان مستقلة عن أحداث الفوكس تمامًا: بتحفظ لوحدها بعد وقفة
  // قصيرة من الكتابة، بغض النظر هل الحقل فقد التركيز فعليًا ولا لأ —
  // الاعتماد على أحداث الفوكس بس (فقدان التركيز/إغلاق الشاشة) طلع
  // مش موثوق بالشكل الكافي على بعض الأجهزة/الكيبوردات، وكان بيسيب
  // درجات متسجّلة محليًا في الحقل بس من غير ما توصل لقاعدة البيانات.
  Timer? _gradeDebounce;
  Timer? _notesDebounce;

  @override
  void initState() {
    super.initState();
    // تهيئة _lastSaved من القيمة الموجودة مسبقاً
    _lastSaved = widget.ctrl.text;
    _lastSavedNotes = widget.notesCtrl.text;

    // FocusNode listeners بدل الاعتماد على onTapOutside فقط —
    // onTapOutside مبيتفعّلش لما المستخدم يرجع للصفحة اللي قبلها
    // (زرار الرجوع)، فكانت الملاحظة بتتفقد من غير ما تتحفظ.
    _gradeFocusNode = FocusNode()..addListener(_onGradeFocusChange);
    _notesFocusNode = FocusNode()..addListener(_onNotesFocusChange);
  }

  void _onGradeFocusChange() {
    if (_gradeFocusNode.hasFocus) return;
    _saveGradeNow();
  }

  void _onNotesFocusChange() {
    if (_notesFocusNode.hasFocus) return;
    _saveNotesNow();
  }

  void _saveGradeNow() {
    _gradeDebounce?.cancel();
    final current = widget.ctrl.text;
    if (current == _lastSaved) return;
    _lastSaved = current;
    _runSave(() => widget.onSaved(current));
  }

  void _saveNotesNow() {
    _notesDebounce?.cancel();
    final current = widget.notesCtrl.text;
    if (current == _lastSavedNotes) return;
    _lastSavedNotes = current;
    _runSave(() => widget.onNotesSaved());
  }

  // شبكة الأمان: بعد وقفة قصيرة من الكتابة، بتحفظ لوحدها من غير ما
  // تستنى فقدان التركيز خالص.
  void _onGradeChanged() {
    setState(() {});
    _gradeDebounce?.cancel();
    _gradeDebounce = Timer(const Duration(milliseconds: 700), _saveGradeNow);
  }

  void _onNotesChanged() {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 700), _saveNotesNow);
  }

  @override
  void dispose() {
    _gradeDebounce?.cancel();
    _notesDebounce?.cancel();
    _gradeFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  /// ينفّذ عملية حفظ (درجة أو غياب) ويضمن إن الـ spinner يقفل دايماً،
  /// حتى لو فشل الحفظ فعلياً — بدل ما يفضل معلّق للأبد بصمت.
  Future<void> _runSave(Future<void> Function() action) async {
    if (mounted) setState(() => _saving = true);
    try {
      await action();
    } catch (e) {
      if (mounted) ToastHelper.error('فشل حفظ الدرجة — حاول تاني');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color? _rowBg(BuildContext context) {
    if (widget.grade.isAbsent) {
      return Colors.grey.withValues(alpha: 0.07);
    }
    final raw = widget.ctrl.text.trim();
    if (raw.isEmpty) return null;
    final val = double.tryParse(raw);
    if (val == null) return Colors.orange.withValues(alpha: 0.08);
    return val >= widget.passingGrade
        ? Colors.green.withValues(alpha: 0.07)
        : Colors.red.withValues(alpha: 0.07);
  }

  String get _pct {
    if (widget.grade.isAbsent) return '';
    final val = double.tryParse(widget.ctrl.text.trim());
    if (val == null || widget.maxGrade == 0) return '';
    return '${(val / widget.maxGrade * 100).toStringAsFixed(0)}%';
  }

  GradeCategory get _category {
    if (widget.grade.isAbsent) return GradeCategory.absent;
    final val = double.tryParse(widget.ctrl.text.trim());
    if (val == null) return GradeCategory.fail;
    final passingPct = widget.maxGrade > 0
        ? (widget.passingGrade / widget.maxGrade) * 100
        : 60.0;
    return GradeCategoryExt.fromPercentage((val / widget.maxGrade) * 100,
        passingPct: passingPct);
  }

  String get _initials {
    final name = widget.grade.studentName ?? '';
    if (name.isEmpty) return '؟';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return parts[0][0];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _rowBg(context);
    final cat = _category;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg ?? (isDark ? cs.surface.withValues(alpha: 0.6) : cs.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              // Avatar + Initials
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Text(_initials,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor)),
              ),
              const SizedBox(width: 10),

              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.grade.studentName ?? '---',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.grade.isAbsent
                                ? cs.onSurface.withValues(alpha: 0.4)
                                : cs.onSurface)),
                    // تصنيف الدرجة
                    if (widget.grade.isAbsent ||
                        widget.ctrl.text.trim().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(cat.label,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: cat.color)),
                      ),
                  ],
                ),
              ),

              // % badge
              if (_pct.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_pct,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                ),

              // Absent button
              GestureDetector(
                onTap: () async {
                  final now = !widget.grade.isAbsent;
                  if (now) {
                    widget.ctrl.clear();
                    _lastSaved = '';
                  }
                  await _runSave(() => widget.onAbsent(now));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.grade.isAbsent
                        ? Colors.grey.withValues(alpha: 0.25)
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.grade.isAbsent
                          ? Colors.grey
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text('غ',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: widget.grade.isAbsent
                              ? Colors.grey
                              : Colors.grey.withValues(alpha: 0.5))),
                ),
              ),

              // Grade input
              Opacity(
                opacity: widget.grade.isAbsent ? 0.3 : 1.0,
                child: SizedBox(
                  width: 65,
                  child: Tooltip(
                    // اضغط مطوّلاً لمعرفة إزاي تتراجع عن درجة مُدخلة
                    message: 'امسح الخانة وسيبها فاضية عشان تتراجع عن الدرجة',
                    triggerMode: TooltipTriggerMode.longPress,
                    child: TextField(
                      controller: widget.ctrl,
                      focusNode: _gradeFocusNode,
                      enabled: !widget.grade.isAbsent,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_ArabicDigitsInputFormatter()],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: '---',
                        hintStyle: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.3)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: cs.onSurface.withValues(alpha: 0.2))),
                        filled: true,
                        fillColor: isDark
                            ? cs.onSurface.withValues(alpha: 0.05)
                            : Colors.white,
                      ),
                      onChanged: (_) => _onGradeChanged(),
                      onSubmitted: (_) => _gradeFocusNode.unfocus(),
                      onTapOutside: (_) => _gradeFocusNode.unfocus(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              Text('/${widget.maxGrade.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.4))),

              // Notes icon
              GestureDetector(
                onTap: () => setState(() => _showNotes = !_showNotes),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    _showNotes ? Icons.note_rounded : Icons.note_add_outlined,
                    size: 18,
                    color: widget.notesCtrl.text.isNotEmpty
                        ? AppTheme.primaryColor
                        : cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),

              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ]),
          ),

          // Notes field (expandable)
          if (_showNotes)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: TextField(
                controller: widget.notesCtrl,
                focusNode: _notesFocusNode,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 12, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'ملاحظة على الطالب...',
                  hintStyle: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.35)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: isDark
                      ? cs.onSurface.withValues(alpha: 0.04)
                      : Colors.grey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: cs.onSurface.withValues(alpha: 0.15))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: cs.onSurface.withValues(alpha: 0.15))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppTheme.primaryColor)),
                ),
                onChanged: (_) => _onNotesChanged(),
                onSubmitted: (_) => _notesFocusNode.unfocus(),
                onTapOutside: (_) => _notesFocusNode.unfocus(),
              ),
            ),
        ],
      ),
    );
  }
}

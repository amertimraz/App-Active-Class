// lib/views/exams/student_exam_history_page.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';

class StudentExamHistoryPage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentExamHistoryPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentExamHistoryPage> createState() => _StudentExamHistoryPageState();
}

class _StudentExamHistoryPageState extends State<StudentExamHistoryPage> {
  List<StudentExamRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ExamController.to.getStudentHistory(widget.studentId);
    if (mounted)
      setState(() {
        _records = data;
        _loading = false;
      });
  }

  // ── مشاركة نتائج الامتحانات عبر واتساب ────────────────────────────────────
  Future<void> _shareViaWhatsApp() async {
    final student = await DatabaseService().getStudent(widget.studentId);
    final rawPhone = student?.guardianPhone?.trim() ?? '';
    if (rawPhone.isEmpty) {
      ToastHelper.error('لا يوجد رقم ولي أمر مسجّل لهذا الطالب');
      return;
    }

    final sorted = List<StudentExamRecord>.from(_records)
      ..sort((a, b) => b.examDate.compareTo(a.examDate));

    final buffer = StringBuffer()
      ..writeln('📋 نتائج امتحانات: ${widget.studentName}')
      ..writeln(
          '📊 المعدل العام: ${_overallPct.toStringAsFixed(1)}% (${_overallCategory.label})')
      ..writeln('✅ ناجح في $_passCount من ${_records.length} امتحان');
    if (_absentCount > 0) buffer.writeln('⚠️ غياب: $_absentCount امتحان');
    buffer.writeln('');

    for (final r in sorted) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.examDate);
      if (r.isAbsent) {
        buffer.writeln('• $dateStr — ${r.examName}: غائب');
      } else if (r.grade != null) {
        buffer.writeln(
            '• $dateStr — ${r.examName}: ${r.grade!.toStringAsFixed(1)}/${r.maxGrade.toStringAsFixed(0)} (${r.category.label})');
      } else {
        buffer.writeln('• $dateStr — ${r.examName}: لم تُدخل الدرجة بعد');
      }
    }
    buffer.writeln('\nتم الإرسال من تطبيق Active Class');

    String normalize(String input, String defaultDial) {
      var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
      if (p.startsWith('+')) p = p.substring(1);
      if (p.startsWith('00')) p = p.substring(2);
      if (p.startsWith(defaultDial)) return p;
      if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
      return defaultDial + p.replaceFirst(RegExp(r'^0+'), '');
    }

    final dial = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>().countryDial.value
        : '20';
    final phone = normalize(rawPhone, dial);
    final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  double get _overallPct {
    final withGrades =
        _records.where((r) => !r.isAbsent && r.grade != null).toList();
    if (withGrades.isEmpty) return 0;
    final total = withGrades.fold(0.0, (s, r) => s + r.grade!);
    final max = withGrades.fold(0.0, (s, r) => s + r.maxGrade);
    return max > 0 ? (total / max) * 100 : 0;
  }

  int get _absentCount => _records.where((r) => r.isAbsent).length;

  int get _passCount => _records
      .where(
          (r) => !r.isAbsent && r.grade != null && r.grade! >= r.passingGrade)
      .length;

  GradeCategory get _overallCategory =>
      GradeCategoryExt.fromPercentage(_overallPct);

  String get _initials {
    final parts = widget.studentName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return parts[0][0];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── SliverAppBar ────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  actions: [
                    if (_records.isNotEmpty)
                      IconButton(
                        tooltip: 'مشاركة عبر واتساب',
                        icon:
                            const Icon(Icons.chat_rounded, color: Colors.white),
                        onPressed: _shareViaWhatsApp,
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            const Color(0xFF7C3AED),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            // Avatar
                            CircleAvatar(
                              radius: 36,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              child: Text(_initials,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 10),
                            Text(widget.studentName,
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 6),
                            // Overall badge
                            if (_records.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_overallPct.toStringAsFixed(0)}%  •  ${_overallCategory.label}',
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    title: Text(widget.studentName,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white)),
                    titlePadding:
                        const EdgeInsets.only(right: 56, bottom: 14, left: 56),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                ),

                // ── Summary Cards ───────────────────────────────────
                if (_records.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                              child: _SummaryCard(
                                  icon: Icons.assignment_rounded,
                                  label: 'إجمالي الامتحانات',
                                  value: '${_records.length}',
                                  color: AppTheme.primaryColor)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _SummaryCard(
                                  icon: Icons.check_circle_rounded,
                                  label: 'ناجح',
                                  value: '$_passCount',
                                  color: AppTheme.successColor)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _SummaryCard(
                                  icon: Icons.warning_amber_rounded,
                                  label: 'غياب',
                                  value: '$_absentCount',
                                  color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),

                // ── Performance Chart ───────────────────────────────
                if (_records.length >= 2)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        height: 180,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? cs.surface : cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: cs.onSurface.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('منحنى الأداء',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.7))),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _PerformanceChart(records: _records),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Exam Records List ───────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: _records.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 80),
                              child: Column(children: [
                                Icon(Icons.assignment_outlined,
                                    size: 52,
                                    color: cs.onSurface.withValues(alpha: 0.2)),
                                const SizedBox(height: 12),
                                Text('لا توجد درجات مسجلة',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        color: cs.onSurface
                                            .withValues(alpha: 0.4))),
                              ]),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _ExamRecordCard(record: _records[i]),
                            childCount: _records.length,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ── ملخص رقمي ──────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _SummaryCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color)),
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9,
                color: cs.onSurface.withValues(alpha: 0.5)),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── منحنى الأداء ───────────────────────────────────────────────────────────────
class _PerformanceChart extends StatelessWidget {
  final List<StudentExamRecord> records;
  const _PerformanceChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final withGrades = records
        .where((r) => !r.isAbsent && r.grade != null)
        .toList()
      ..sort((a, b) => a.examDate.compareTo(b.examDate));

    if (withGrades.isEmpty) {
      return Center(
          child: Text('لا توجد درجات لعرض المنحنى',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.35))));
    }

    final spots = withGrades
        .asMap()
        .entries
        .map((e) =>
            FlSpot(e.key.toDouble(), (e.value.grade! / e.value.maxGrade) * 100))
        .toList();

    return LineChart(LineChartData(
      minX: 0,
      maxX: (withGrades.length - 1).toDouble(),
      minY: 0,
      maxY: 110,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (val) => FlLine(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (val, meta) {
              final idx = val.toInt();
              if (idx < 0 || idx >= withGrades.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('d/M').format(withGrades[idx].examDate),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 9,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppTheme.primaryColor,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
              radius: 4,
              color: AppTheme.primaryColor,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.25),
                AppTheme.primaryColor.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // خط النجاح 60%
        LineChartBarData(
          spots: [
            FlSpot(0, 60),
            FlSpot((withGrades.length - 1).toDouble(), 60),
          ],
          isCurved: false,
          color: AppTheme.errorColor.withValues(alpha: 0.4),
          barWidth: 1,
          isStrokeCapRound: false,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
        ),
      ],
    ));
  }
}

// ── بطاقة امتحان واحد ─────────────────────────────────────────────────────────
class _ExamRecordCard extends StatelessWidget {
  final StudentExamRecord record;
  const _ExamRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = record.category;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cat.color.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cat.color.withValues(alpha: 0.12),
          ),
          child: record.isAbsent
              ? Icon(Icons.warning_amber_rounded, size: 22, color: cat.color)
              : record.grade == null
                  ? Icon(Icons.help_outline_rounded, size: 22, color: cat.color)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          record.grade! == record.grade!.toInt()
                              ? record.grade!.toInt().toString()
                              : record.grade!.toStringAsFixed(1),
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: cat.color),
                        ),
                        Text(
                          '/${record.maxGrade.toInt()}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 9,
                              color: cat.color.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
        ),
        title: Text(record.examName,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${record.groupName}  •  ${DateFormat('d MMMM yyyy', 'ar').format(record.examDate)}',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cat.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cat.label,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cat.color)),
              if (!record.isAbsent && record.grade != null)
                Text(
                  '${record.percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 9,
                      color: cat.color.withValues(alpha: 0.7)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

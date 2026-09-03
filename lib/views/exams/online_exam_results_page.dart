// lib/views/exams/online_exam_results_page.dart
//
// spec 016 — سحب تسليمات الامتحان الإلكتروني، تصحيح تلقائي، مراجعة،
// تعديل يدوي، اعتماد → exam_grades.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_submission_model.dart';
import 'package:active_class/utils/helpers.dart';

class OnlineExamResultsPage extends StatefulWidget {
  final Exam exam;
  const OnlineExamResultsPage({super.key, required this.exam});

  @override
  State<OnlineExamResultsPage> createState() => _OnlineExamResultsPageState();
}

class _OnlineExamResultsPageState extends State<OnlineExamResultsPage> {
  final _ec = Get.find<ExamController>();
  List<ExamSubmission> _subs = [];
  bool _loading = true;
  bool _pulling = false;

  int get _examId => widget.exam.id!;
  double get _maxGrade => widget.exam.maxGrade;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _subs = await _ec.getSubmissions(_examId);
    setState(() => _loading = false);
  }

  Future<void> _pull() async {
    setState(() => _pulling = true);
    final r = await _ec.pullAndGradeOnlineExam(_examId);
    setState(() => _pulling = false);
    if (r.error != null) {
      ToastHelper.error(r.error!);
    } else {
      ToastHelper.success(
          'سُحب ${r.pulled} تسليم${r.notSubmitted > 0 ? ' · ${r.notSubmitted} لم يسلّم' : ''}');
    }
    await _load();
  }

  Future<void> _approve(ExamSubmission s, {double? override}) async {
    await _ec.approveOnlineGrade(_examId, s.studentId, overrideGrade: override);
    await _load();
  }

  Future<void> _approveAll() async {
    await _ec.approveAllOnlineGrades(_examId);
    ToastHelper.success('تم اعتماد الكل');
    await _load();
  }

  Future<void> _showDetails(ExamSubmission s) async {
    final results = await _ec.questionResults(s);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.studentName ?? 'طالب',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 12),
            ...results.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.questionText,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      ...r.options.asMap().entries.map((e) {
                        final isCorrect = e.key == r.correctIndex;
                        final isChosen = e.key == r.chosenIndex;
                        return Row(children: [
                          Icon(
                            isCorrect
                                ? Icons.check_circle
                                : (isChosen
                                    ? Icons.cancel
                                    : Icons.circle_outlined),
                            size: 15,
                            color: isCorrect
                                ? Colors.green
                                : (isChosen ? Colors.red : Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(e.value,
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: isChosen || isCorrect
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                          ),
                        ]);
                      }),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _editGrade(ExamSubmission s) async {
    final ctrl = TextEditingController(
        text: FormatHelper.formatGrade(s.finalGrade ?? s.autoScore ?? 0));
    final result = await Get.dialog<double>(AlertDialog(
      title: const Text('تعديل الدرجة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontFamily: 'Cairo'),
        decoration: InputDecoration(
            suffixText: '/ ${FormatHelper.formatGrade(_maxGrade)}'),
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        FilledButton(
            onPressed: () => Get.back(result: double.tryParse(ctrl.text)),
            child: const Text('اعتماد', style: TextStyle(fontFamily: 'Cairo'))),
      ],
    ));
    if (result != null) await _approve(s, override: result);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _subs.where((s) => s.status == SubmissionStatus.pending).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam.name,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        actions: [
          if (pending > 0)
            TextButton(
              onPressed: _approveAll,
              child: const Text('اعتماد الكل',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _summaryHeader(),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _pulling ? null : _pull,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: _pulling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_sync_rounded, size: 18),
                      label: Text(
                          _pulling ? 'جاري السحب...' : 'تحديث النتائج من السحابة',
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_subs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Center(
                        child: Column(children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.10),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.inbox_rounded,
                                size: 40, color: Color(0xFF6366F1)),
                          ),
                          const SizedBox(height: 14),
                          const Text('مفيش تسليمات بعد',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('اضغط "تحديث النتائج" بعد ما الطلاب يسلّموا.',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.grey.shade500)),
                        ]),
                      ),
                    ),
                  ..._subs.map(_row),
                ],
              ),
            ),
    );
  }

  Widget _summaryHeader() {
    final total = _subs.length;
    final approved =
        _subs.where((s) => s.status == SubmissionStatus.approved).length;
    final pending =
        _subs.where((s) => s.status == SubmissionStatus.pending).length;
    final notSub =
        _subs.where((s) => s.status == SubmissionStatus.notSubmitted).length;
    final graded = _subs.where((s) =>
        s.status != SubmissionStatus.notSubmitted && s.autoScore != null);
    final avg = graded.isEmpty
        ? 0.0
        : graded.map((s) => s.finalGrade ?? s.autoScore ?? 0).reduce((a, b) => a + b) /
            graded.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          _hStat('$total', 'تسليم'),
          _hDivider(),
          _hStat('$approved', 'معتمَد'),
          _hDivider(),
          _hStat('$pending', 'بانتظار'),
          _hDivider(),
          _hStat('$notSub', 'لم يسلّم'),
        ]),
        if (graded.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.insights_rounded,
                size: 16, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
            Text(
              'متوسط الدرجات: ${FormatHelper.formatGrade(avg)} / ${FormatHelper.formatGrade(_maxGrade)}',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _hDivider() => Container(
      width: 1, height: 34, color: Colors.white.withValues(alpha: 0.18));

  Widget _hStat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          Text(l,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.78))),
        ]),
      );

  Widget _row(ExamSubmission s) {
    final notSubmitted = s.status == SubmissionStatus.notSubmitted;
    final approved = s.status == SubmissionStatus.approved;
    final grade = s.finalGrade ?? s.autoScore ?? 0;
    final pct = _maxGrade > 0 ? (grade / _maxGrade) : 0.0;
    final Color color = approved
        ? const Color(0xFF10B981)
        : (notSubmitted ? const Color(0xFF94A3B8) : const Color(0xFFF59E0B));
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: notSubmitted ? null : () => _showDetails(s),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(children: [
              // دائرة الدرجة
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: notSubmitted
                    ? Icon(Icons.remove_rounded, color: color, size: 20)
                    : Text(FormatHelper.formatGrade(grade),
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.studentName ?? 'طالب',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: cs.onSurface)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(s.status.label,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: color)),
                      ),
                      if (!notSubmitted) ...[
                        const SizedBox(width: 6),
                        Text('من ${FormatHelper.formatGrade(_maxGrade)}',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.45))),
                      ],
                      if (s.autoSubmitted) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.timer_off_rounded,
                            size: 11,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                      ],
                    ]),
                    if (!notSubmitted) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: color.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!notSubmitted)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  onPressed: () => _editGrade(s),
                ),
              if (!approved)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                      notSubmitted
                          ? Icons.person_off_rounded
                          : Icons.check_circle_rounded,
                      size: 20),
                  color: AppTheme.primaryColor,
                  tooltip: notSubmitted ? 'تعليم غائب' : 'اعتماد',
                  onPressed: () => _approve(s),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

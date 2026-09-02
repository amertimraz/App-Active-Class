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
                  FilledButton.icon(
                    onPressed: _pulling ? null : _pull,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor),
                    icon: _pulling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text('تحديث النتائج',
                        style: TextStyle(fontFamily: 'Cairo')),
                  ),
                  const SizedBox(height: 12),
                  if (_subs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text('مفيش تسليمات بعد',
                            style: TextStyle(
                                fontFamily: 'Cairo', color: Colors.grey)),
                      ),
                    ),
                  ..._subs.map(_row),
                ],
              ),
            ),
    );
  }

  Widget _row(ExamSubmission s) {
    final notSubmitted = s.status == SubmissionStatus.notSubmitted;
    final grade = s.finalGrade ?? s.autoScore ?? 0;
    final color = s.status == SubmissionStatus.approved
        ? Colors.green
        : (notSubmitted ? Colors.grey : Colors.orange);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(s.studentName ?? 'طالب',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text(
          notSubmitted
              ? 'لم يسلّم'
              : '${FormatHelper.formatGrade(grade)} / ${FormatHelper.formatGrade(_maxGrade)}  ·  ${s.status.label}',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: color),
        ),
        onTap: notSubmitted ? null : () => _showDetails(s),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notSubmitted)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _editGrade(s),
              ),
            if (s.status != SubmissionStatus.approved)
              IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                color: AppTheme.primaryColor,
                tooltip: notSubmitted ? 'تعليم غائب' : 'اعتماد',
                onPressed: () => _approve(s),
              ),
          ],
        ),
      ),
    );
  }
}

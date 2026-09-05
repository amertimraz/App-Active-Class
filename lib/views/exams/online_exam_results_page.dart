// lib/views/exams/online_exam_results_page.dart
//
// spec 016 — سحب تسليمات الامتحان الإلكتروني، تصحيح تلقائي، مراجعة،
// تعديل يدوي، اعتماد → exam_grades.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/exam_submission_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/phone_format.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/views/exams/certificates_sheet.dart';
import 'package:active_class/views/exams/exam_analytics_page.dart';
import 'package:active_class/services/export_service.dart';

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

  // spec 022 — التسليمات المُبطَلة تتعرض في قسم منفصل، ومستبعدة من
  // إحصائيات الملخّص العلوي.
  List<ExamSubmission> get _activeSubs =>
      _subs.where((s) => s.status != SubmissionStatus.voided).toList();
  List<ExamSubmission> get _voidedSubs =>
      _subs.where((s) => s.status == SubmissionStatus.voided).toList();

  Future<void> _unapprove(ExamSubmission s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الاعتماد؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(
            'درجة ${s.studentName ?? "الطالب"} هتتشال من سجله وبوابة الأهالي. '
            'لو كان شايف نتيجته بالفعل، هتختفي من عنده كمان.',
            style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('إلغاء الاعتماد', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _ec.unapproveOnlineGrade(_examId, s.studentId);
    await _load();
  }

  Future<void> _void(ExamSubmission s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إبطال التسليم؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(
            'هيتمسح تسليم ${s.studentName ?? "الطالب"} الحالي (إجاباته + درجته '
            'لو كانت معتمَدة) نهائيًا، ويقدر يسلّم الامتحان من الأول لو المهلة '
            'لسه سارية.',
            style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('إبطال التسليم', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _ec.voidSubmission(_examId, s.studentId);
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

  // ── درجات معتمَدة (exam_grades) عبر كل مجموعات الامتحان ───────────────────
  Future<List<ExamGrade>> _approvedGrades() async {
    final byId = <int, ExamGrade>{};
    for (final gid in widget.exam.groupIds) {
      for (final g in await _ec.getGradesForExamGroup(_examId, gid)) {
        if (g.isEntered) byId[g.studentId] = g;
      }
    }
    return byId.values.toList();
  }

  // ── تصدير النتائج (spec 023 US4) ────────────────────────────────────────
  Future<void> _exportResults() async {
    final fmt = await showModalBottomSheet<ExportFormat>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          const Text('تصدير النتائج',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          ListTile(
            leading: const Icon(Icons.grid_on_rounded, color: Color(0xFF10B981)),
            title: const Text('Excel (.xlsx)',
                style: TextStyle(fontFamily: 'Cairo')),
            onTap: () => Navigator.pop(context, ExportFormat.xlsx),
          ),
          ListTile(
            leading:
                const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444)),
            title: const Text('PDF', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () => Navigator.pop(context, ExportFormat.pdf),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (fmt == null || !mounted) return;
    ToastHelper.info('جاري التصدير…');
    final students = <int, Student>{};
    for (final gid in widget.exam.groupIds) {
      for (final s in await DatabaseService().getStudentsByGroup(gid)) {
        if (s.id != null) students[s.id!] = s;
      }
    }
    final res = await ExportService().exportOnlineExamResults(
      exam: widget.exam,
      submissions: _subs,
      students: students.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name)),
      format: fmt,
    );
    if (!mounted) return;
    if (res.success && res.path != null) {
      await Share.shareXFiles([XFile(res.path!)],
          subject: 'نتائج ${widget.exam.name}');
    } else {
      ToastHelper.error(res.error ?? 'تعذّر التصدير');
    }
  }

  // ── إرسال النتائج واتساب (spec 018 US3) ──────────────────────────────────
  Future<void> _sendResults() async {
    final grades = await _approvedGrades();
    if (!mounted) return;
    if (grades.isEmpty) {
      ToastHelper.info('مفيش درجات معتمَدة للإرسال — اعتمد الدرجات الأول');
      return;
    }
    final students = <int, Student>{};
    for (final gid in widget.exam.groupIds) {
      for (final s in await DatabaseService().getStudentsByGroup(gid)) {
        if (s.id != null) students[s.id!] = s;
      }
    }
    final settings = Get.find<SettingsController>();
    final ready = <(ExamGrade, String)>[];
    final skipped = <String>[];
    for (final g in grades) {
      final raw = students[g.studentId]?.guardianPhone?.trim() ?? '';
      final phone = raw.isEmpty
          ? ''
          : normalizeWhatsappPhone(raw, settings.countryDial.value);
      if (phone.isEmpty) {
        skipped.add(g.studentName ?? '؟');
      } else {
        ready.add((g, phone));
      }
    }
    if (!mounted) return;
    if (ready.isEmpty) {
      ToastHelper.error('مفيش أرقام أولياء أمور مسجّلة للطلاب المعتمَدين');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('إرسال نتائج الامتحان؟',
            style: TextStyle(fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هيتبعت نتيجة "${widget.exam.name}" لـ ${ready.length} ولي أمر.',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            if (skipped.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${skipped.length} هيتم تخطّيهم (مفيش رقم): ${skipped.join("، ")}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.orange.shade800)),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    for (final (g, phone) in ready) {
      if (!mounted) break;
      final msg = _ec.buildGuardianExamResultMessage(
        grade: g,
        exam: widget.exam,
        teacherName: settings.teacherFullName.value.trim(),
        teacherSpecialization: settings.teacherSpecialization.value.trim(),
      );
      await launchUrl(
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}'),
        mode: LaunchMode.externalApplication,
      );
      await _waitForResume();
    }
    if (mounted) {
      ToastHelper.success('تم فتح ${ready.length} رسالة'
          '${skipped.isNotEmpty ? " (تم تخطّي ${skipped.length})" : ""}');
    }
  }

  // يستنى رجوع التطبيق من واتساب قبل فتح الرسالة اللي بعدها — مع مهلة
  // أمان لو الفتح فشل أصلاً (واتساب مش متثبّت) عشان اللوب ما يعلّقش.
  Future<void> _waitForResume() {
    final c = Completer<void>();
    late final AppLifecycleListener l;
    void done() {
      l.dispose();
      if (!c.isCompleted) c.complete();
    }

    l = AppLifecycleListener(onResume: done);
    Future.delayed(const Duration(seconds: 60), done);
    return c.future;
  }

  // ── شهادات تقدير (spec 018) ─────────────────────────────────────────────
  Future<void> _openCertificates() async {
    final cands = await _ec.certifiableStudents(_examId);
    if (!mounted) return;
    final items = cands
        .map((c) => _ec.buildExamCert(
              studentName: c.name,
              grade: c.grade,
              maxGrade: c.maxGrade,
              examName: widget.exam.name,
              date: widget.exam.date,
            ))
        .toList();
    Get.to(() => CertificatesSheet(
          title: 'شهادات تقدير — ${widget.exam.name}',
          fileName: 'شهادات_${widget.exam.name}',
          items: items,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final pending = _subs.where((s) => s.status == SubmissionStatus.pending).length;
    final approved =
        _subs.where((s) => s.status == SubmissionStatus.approved).length;
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
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'تحليل الأسئلة',
            onPressed: () =>
                Get.to(() => ExamAnalyticsPage(exam: widget.exam)),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'تصدير النتائج',
            onPressed: _exportResults,
          ),
          if (approved > 0) ...[
            IconButton(
              icon: const Icon(Icons.workspace_premium_rounded),
              tooltip: 'شهادات تقدير',
              onPressed: _openCertificates,
            ),
            IconButton(
              icon: const Icon(Icons.chat_rounded),
              tooltip: 'إرسال النتائج واتساب',
              onPressed: _sendResults,
            ),
          ],
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
                  ..._activeSubs.map(_row),
                  if (_voidedSubs.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      const Icon(Icons.block_rounded,
                          size: 15, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('مُبطَلة (${_voidedSubs.length})',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade600)),
                    ]),
                    const SizedBox(height: 8),
                    ..._voidedSubs.map(_row),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summaryHeader() {
    // مُستبعَدة من الإحصائيات دايمًا (FR-008) — قسمها منفصل تحت.
    final subs = _activeSubs;
    final total = subs.length;
    final approved =
        subs.where((s) => s.status == SubmissionStatus.approved).length;
    final pending =
        subs.where((s) => s.status == SubmissionStatus.pending).length;
    final notSub =
        subs.where((s) => s.status == SubmissionStatus.notSubmitted).length;
    final graded = subs.where((s) =>
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
    final voided = s.status == SubmissionStatus.voided;
    final grade = s.finalGrade ?? s.autoScore ?? 0;
    final pct = _maxGrade > 0 ? (grade / _maxGrade) : 0.0;
    final Color color = voided
        ? const Color(0xFF94A3B8)
        : approved
            ? const Color(0xFF10B981)
            : (notSubmitted
                ? const Color(0xFF94A3B8)
                : const Color(0xFFF59E0B));
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
          onTap: (notSubmitted || voided) ? null : () => _showDetails(s),
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
                child: (notSubmitted || voided)
                    ? Icon(voided ? Icons.block_rounded : Icons.remove_rounded,
                        color: color, size: 20)
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
                      if (!notSubmitted && !voided) ...[
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
              if (!notSubmitted && !voided)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  onPressed: () => _editGrade(s),
                ),
              if (!approved && !voided)
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
              // spec 022 — إجراءات أقل شيوعًا في قائمة ⋮ عشان الصف
              // ميزدحمش. مش بتظهر لـ"لم يسلّم" (مفيش تسليم يتبطّل) ولا
              // "مُبطَل" (اتبطّل بالفعل).
              if (!notSubmitted && !voided)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'unapprove') _unapprove(s);
                    if (v == 'void') _void(s);
                  },
                  itemBuilder: (_) => [
                    if (approved)
                      const PopupMenuItem(
                        value: 'unapprove',
                        child: Text('إلغاء الاعتماد',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      ),
                    const PopupMenuItem(
                      value: 'void',
                      child: Text('إبطال التسليم',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.red)),
                    ),
                  ],
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

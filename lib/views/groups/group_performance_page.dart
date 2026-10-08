// lib/views/groups/group_performance_page.dart
//
// spec 050 — أداء طلاب المجموعة: ترتيب بالمستوى مع اتجاه كل طالب، فلتر
// "المتراجعين"، وإرسال جماعي لأولياء الأمور (نص أو كارت). المستوى العام
// هنا للترتيب والفلتر بس.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/performance_service.dart';
import 'package:active_class/utils/helpers.dart' show ToastHelper;
import 'package:active_class/utils/performance.dart';
import 'package:active_class/views/students/performance_actions.dart';
import 'package:active_class/views/students/student_performance_tab.dart';
import 'package:active_class/widgets/performance_card.dart';

class GroupPerformancePage extends StatefulWidget {
  final Group group;
  const GroupPerformancePage({super.key, required this.group});

  @override
  State<GroupPerformancePage> createState() => _GroupPerformancePageState();
}

class _GroupPerformancePageState extends State<GroupPerformancePage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<StudentPerformance> _all = [];
  final Map<int, Student> _students = {};
  bool _loading = true;
  bool _onlyDeclining = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseService();
    final list = await db.getStudentsByGroup(widget.group.id!);
    _students
      ..clear()
      ..addEntries(list
          .where((s) => !s.isArchived && s.id != null)
          .map((s) => MapEntry(s.id!, s)));
    final perfs = await PerformanceService.forGroup(widget.group.id!, _month);
    if (!mounted) return;
    setState(() {
      _all = perfs;
      _loading = false;
    });
  }

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  void _shift(int d) {
    _month = DateTime(_month.year, _month.month + d, 1);
    _load();
  }

  Future<void> _bulkSend() async {
    final ranked = rankPerformances(_all);
    // اللي يتبعت لهم: عندهم بيانات + رقم ولي أمر
    final sendable = ranked
        .where((p) =>
            p.hasAnyData &&
            _students[p.studentId] != null &&
            studentHasGuardianContact(_students[p.studentId]!))
        .toList();
    final skipped = ranked.where((p) => !sendable.contains(p)).toList();
    if (sendable.isEmpty) {
      ToastHelper.error('مفيش طلاب يتبعت لهم (بيانات + رقم ولي أمر)');
      return;
    }
    String mode = 'text';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إرسال تقارير الأداء',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('هيتبعت لـ ${sendable.length} طالب',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (skipped.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                      '${skipped.length} هيتم تخطّيهم (بلا رقم أو بيانات): '
                      '${skipped.map((p) => p.name).join('، ')}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade800)),
                ],
                const SizedBox(height: 10),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: 'text',
                  groupValue: mode,
                  title: const Text('رسالة نصية واتساب'),
                  onChanged: (v) => setSt(() => mode = v!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: 'card',
                  groupValue: mode,
                  title: const Text('صورة كارت'),
                  subtitle: const Text('مشاركة كل كارت واختيار المحادثة'),
                  onChanged: (v) => setSt(() => mode = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ابدأ الإرسال')),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _sending = true);
    var sent = 0;
    for (final p in sendable) {
      if (!mounted) break;
      final s = _students[p.studentId]!;
      if (mode == 'text') {
        final ok = await sendPerformanceText(context, s, p);
        if (!ok) continue;
      } else {
        final bytes = await renderPerformanceCardOffscreen(context, p);
        if (bytes == null) continue;
        await sharePerformancePng(bytes, performanceFileName(p),
            text: 'تقرير مستوى ${p.name}');
      }
      sent++;
      await _waitUntilResumed();
    }
    if (mounted) setState(() => _sending = false);
    ToastHelper.success('تم إرسال $sent تقرير');
  }

  /// بعد فتح واتساب/مشاركة النظام: لو التطبيق خرج للخلفية نستنى يرجع،
  /// ولو فضل قدّام (مشاركة رجعت بسرعة) نكمّل — الانتظار الأعمى كان ممكن
  /// يعلّق الحلقة لو الرجوع حصل قبل ما نسجّل المراقب.
  Future<void> _waitUntilResumed() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final st = WidgetsBinding.instance.lifecycleState;
    if (st == null || st == AppLifecycleState.resumed) return;
    await _waitForResume();
  }

  Future<void> _waitForResume() {
    final c = Completer<void>();
    late _ResumeObserver obs;
    obs = _ResumeObserver(() {
      WidgetsBinding.instance.removeObserver(obs);
      if (!c.isCompleted) c.complete();
    });
    WidgetsBinding.instance.addObserver(obs);
    return c.future;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shown = rankPerformances(_all, onlyDeclining: _onlyDeclining);
    final decliningCount = _all.where((p) => p.isDeclining).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('أداء ${widget.group.name}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'إرسال تقارير الأداء',
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            onPressed: (_loading || _sending) ? null : _bulkSend,
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _shift(-1)),
            Expanded(
              child: Text(DateFormat('MMMM yyyy', 'ar').format(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _isCurrentMonth ? null : () => _shift(1)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            FilterChip(
              label: Text('المتراجعين ($decliningCount)'),
              selected: _onlyDeclining,
              avatar: const Icon(Icons.trending_down_rounded, size: 18),
              onSelected: (v) => setState(() => _onlyDeclining = v),
            ),
            const Spacer(),
            Text('${shown.length} طالب',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : shown.isEmpty
                  ? Center(
                      child: Text(
                          _onlyDeclining
                              ? 'مفيش طلاب متراجعين هذا الشهر 🎉'
                              : 'لا يوجد طلاب',
                          style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _StandingTile(
                        rank: i + 1,
                        perf: shown[i],
                        isDark: isDark,
                        onTap: () {
                          final s = _students[shown[i].studentId];
                          if (s == null) return;
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: Text(s.name)),
                              body: StudentPerformanceTab(
                                  student: s, groupName: widget.group.name),
                            ),
                          ));
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _ResumeObserver extends WidgetsBindingObserver {
  final void Function() onResume;
  _ResumeObserver(this.onResume);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

class _StandingTile extends StatelessWidget {
  final int rank;
  final StudentPerformance perf;
  final bool isDark;
  final VoidCallback onTap;
  const _StandingTile({
    required this.rank,
    required this.perf,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = perfTrendColor(perf.overallTrend);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2540) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: perf.isDeclining
                    ? kPerfDown.withValues(alpha: 0.35)
                    : Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Text(perf.overall == null ? '—' : '$rank',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Colors.grey.shade500)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(perf.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  perf.hasData
                      ? Wrap(spacing: 8, children: [
                          for (final i in perf.indicators)
                            if (i.current != null)
                              Text('${i.kind.emoji} ${perfPct(i.current)}',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600)),
                        ])
                      : Text('لا بيانات هذا الشهر',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (perf.overall != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(perfPct(perf.overall),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                if (perf.overallTrend != PerfTrend.none)
                  Text(
                      '${trendArrow(perf.overallTrend)} ${perfDelta(perf.overallDelta)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: tc)),
              ]),
          ]),
        ),
      ),
    );
  }
}

// lib/views/settings/data_health_page.dart
//
// spec 052 — شاشة "صحة البيانات": فحص التكرار ← حالات ← معاينة ← دمج.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/controllers/data_health_controller.dart';
import 'package:active_class/services/data_health_service.dart';
import 'package:active_class/utils/duplicate_detection.dart';
import 'package:active_class/utils/merge_plan.dart';

class DataHealthPage extends StatefulWidget {
  const DataHealthPage({super.key});

  @override
  State<DataHealthPage> createState() => _DataHealthPageState();
}

class _DataHealthPageState extends State<DataHealthPage> {
  late final DataHealthController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(DataHealthController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<DataHealthController>()) {
      Get.delete<DataHealthController>();
    }
    super.dispose();
  }

  // ── المعاينة والتنفيذ ───────────────────────────────────────────────────
  Future<void> _previewAndMerge() async {
    final plan = await c.buildPreview();
    if (!mounted) return;
    if (plan.isEmpty) {
      Get.snackbar('صحة البيانات', 'مفيش حالة محدّدة للدمج');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PreviewDialog(plan: plan),
    );
    if (ok != true || !mounted) return;
    await _run(plan, ignorePending: false);
  }

  Future<void> _run(MergePlan plan, {required bool ignorePending}) async {
    final outcome = await c.execute(plan, ignorePending: ignorePending);
    if (!mounted) return;
    switch (outcome) {
      case MergeSuccess s:
        await showDialog<void>(
          context: context,
          builder: (ctx) => _ResultDialog(entry: _entryOf(s)),
        );
      case MergeBlocked b:
        await _showBlocked(b, plan);
      case MergeBackupFailed f:
        _alert(
            'فشل أخذ النسخة الاحتياطية', 'ما اتنفّذش أي دمج. ${f.error ?? ''}');
      case MergeFailed f:
        _alert('حصل خطأ',
            'اتلغى الدمج بالكامل ومفيش تغيير في البيانات.\n${f.error}');
    }
  }

  MergeLogEntry _entryOf(MergeSuccess s) => MergeLogEntry(
        at: DateTime.now(),
        studentsMerged: s.result.studentsMerged,
        groupsMerged: s.result.groupsMerged,
        studentsMovedToGroup: s.result.studentsMovedToGroup,
        moved: s.result.moved,
        dropped: s.result.dropped,
        backupPath: s.backupPath,
      );

  Future<void> _showBlocked(MergeBlocked b, MergePlan plan) async {
    switch (b.reason) {
      case MergeBlock.notOwner:
        _alert('غير مسموح', 'الدمج متاح لمالك الفريق فقط.');
      case MergeBlock.notSynced:
        _alert('استنّى المزامنة',
            'الطالب أو المجموعة الأساسية لسه ما اتزامنتش مع الفريق. اتأكد من النت وحاول تاني بعد دقيقة.');
      case MergeBlock.empty:
        _alert('مفيش دمج', 'مفيش حالة محدّدة.');
      case MergeBlock.pendingSync:
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('فيه تغييرات لسه ما اتبعتتش'),
            content: Text(
                'فيه ${b.pending} عملية معلّقة للمزامنة. الأفضل تستنّى لحد ما تخلص قبل الدمج عشان ما يحصلش تعارض مع المساعد.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('استنّى')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('كمّل برضو')),
            ],
          ),
        );
        if (go == true && mounted) await _run(plan, ignorePending: true);
    }
  }

  void _alert(String title, String msg) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))
        ],
      ),
    );
  }

  // ── البناء ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صحة البيانات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: Obx(() {
        final r = c.result.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _IntroCard(
              scanning: c.scanning.value,
              onScan: c.scan,
              scannedAt: r?.at,
            ),
            if (c.error.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('تعذّر الفحص: ${c.error.value}',
                    style: const TextStyle(color: Colors.red)),
              ),
            if (r != null && r.isClean) const _CleanCard(),
            if (r != null && c.groupCases.isNotEmpty) ...[
              const _SectionTitle('مجموعات مكرّرة'),
              for (final cs in c.groupCases)
                _CaseCard(
                    key: ValueKey('g${DataHealthController.keyOf(cs)}'),
                    c: c,
                    cs: cs,
                    groupNames: r.groupNames),
            ],
            if (r != null && c.studentCases.isNotEmpty) ...[
              const _SectionTitle('طلاب مكرّرين'),
              for (final cs in c.studentCases)
                _CaseCard(
                    key: ValueKey('s${DataHealthController.keyOf(cs)}'),
                    c: c,
                    cs: cs,
                    groupNames: r.groupNames),
            ],
            const SizedBox(height: 24),
            _HistorySection(c: c),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        final n = c.selectedCount;
        if (c.result.value == null || n == 0) return const SizedBox.shrink();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: c.working.value ? null : _previewAndMerge,
              icon: c.working.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.merge_type_rounded),
              label: Text('معاينة ودمج المحدّد ($n)',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            ),
          ),
        );
      }),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final bool scanning;
  final Future<void> Function() onScan;
  final DateTime? scannedAt;
  const _IntroCard(
      {required this.scanning, required this.onScan, this.scannedAt});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيدوّر على الطلاب والمجموعات المكرّرة ويدمجهم بأمان. الفحص بيقرا بس ومش بيغيّر حاجة، والدمج بياخد نسخة احتياطية الأول.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 12),
            Row(children: [
              FilledButton.icon(
                onPressed: scanning ? null : onScan,
                icon: scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.health_and_safety_rounded),
                label: const Text('افحص التكرار',
                    style: TextStyle(fontFamily: 'Cairo')),
              ),
              if (scannedAt != null) ...[
                const SizedBox(width: 12),
                Text(
                    'آخر فحص ${scannedAt!.hour.toString().padLeft(2, '0')}:${scannedAt!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

class _CleanCard extends StatelessWidget {
  const _CleanCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: const Color(0xFF10B981).withValues(alpha: 0.12),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
          SizedBox(width: 10),
          Expanded(
            child: Text('بياناتك سليمة — مفيش تكرار',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900)),
      );
}

String _reasonLabel(MatchReason r) {
  switch (r) {
    case MatchReason.sameCode:
      return 'نفس الكود';
    case MatchReason.sameNameInGroup:
      return 'نفس الاسم فقط';
    case MatchReason.sameGroupName:
      return 'نفس اسم المجموعة';
  }
}

class _CaseCard extends StatelessWidget {
  final DataHealthController c;
  final DuplicateCase cs;
  final Map<int, String> groupNames;
  const _CaseCard(
      {super.key, required this.c, required this.cs, required this.groupNames});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final live = [...c.groupCases, ...c.studentCases].firstWhere(
          (x) =>
              DataHealthController.keyOf(x) == DataHealthController.keyOf(cs),
          orElse: () => cs);
      final sel = c.isSelected(live);
      final warn = live.reason == MatchReason.sameNameInGroup;
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Checkbox(value: sel, onChanged: (_) => c.toggle(live)),
                Expanded(
                  child: Text(live.copies.first.name,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (warn ? Colors.orange : Colors.blue)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_reasonLabel(live.reason),
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: warn ? Colors.orange.shade800 : Colors.blue)),
                ),
              ]),
              if (live.guardianMismatch)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                      'تنبيه: أرقام أولياء الأمور مختلفة — ممكن يكونوا طالبين مختلفين فعلًا.',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.red)),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 2),
                child: Text('اختار النسخة الأساسية (اللي هتفضل):',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
              ),
              for (final cp in live.copies)
                InkWell(
                  onTap: () => c.setCanonical(live, cp.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(
                          cp.id == live.canonicalId
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 20,
                          color: cp.id == live.canonicalId
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            cp.name,
                            if (cp.code.isNotEmpty) '(${cp.code})',
                            if (cp.groupId != null &&
                                live.kind == DuplicateKind.student)
                              '— ${groupNames[cp.groupId] ?? 'مجموعة'}',
                          ].join(' '),
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 12.5),
                        ),
                      ),
                      Text(
                          '${cp.recordCount} ${live.kind == DuplicateKind.group ? 'عنصر' : 'سجل'}'
                          '${cp.isArchived ? ' • مؤرشف' : ''}',
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 11.5)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _PreviewDialog extends StatelessWidget {
  final MergePlan plan;
  const _PreviewDialog({required this.plan});

  @override
  Widget build(BuildContext context) {
    final s = plan.summary;
    Widget line(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(t,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
        );
    String tableLine(Map<String, int> m) => m.entries
        .where((e) => e.value > 0)
        .map((e) => '${kMergeTableLabels[e.key] ?? e.key} ${e.value}')
        .join('، ');
    return AlertDialog(
      title: const Text('معاينة الدمج'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('هيتدمج: ${s.studentsMerged} طالب، ${s.groupsMerged} مجموعة'),
            if (s.studentsMovedToGroup > 0)
              line('هيتنقل للمجموعة الأساسية: ${s.studentsMovedToGroup} طالب'),
            const Divider(),
            line(
                'اللي هيتنقل للأساسي: ${s.totalMoved == 0 ? 'لا شيء' : tableLine(s.moved)}'),
            line(
                'اللي هيتشال لأنه مكرّر: ${s.totalDropped == 0 ? 'لا شيء' : tableLine(s.dropped)}'),
            if (s.conflicts > 0)
              line('حضور بحالة مختلفة (هيفضل سجل الأساسي): ${s.conflicts}'),
            const Divider(),
            const Text(
              'هتتاخد نسخة احتياطية تلقائيًا قبل التنفيذ، ولو حصل أي خطأ العملية كلها بتتلغي.\nلو بتستخدم وضع الفريق: لازم المساعد يكون على نسخة 1.2.74 أو أحدث عشان المكرّر ما يرجعش.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الدمج')),
      ],
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final MergeLogEntry entry;
  const _ResultDialog({required this.entry});

  @override
  Widget build(BuildContext context) {
    final text = DataHealthService.summaryText(entry);
    return AlertDialog(
      title: const Text('تم الدمج'),
      content: SingleChildScrollView(
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13, height: 1.6)),
      ),
      actions: [
        TextButton(
            onPressed: () => Share.share(text), child: const Text('مشاركة')),
        FilledButton(
            onPressed: () => Navigator.pop(context), child: const Text('تمام')),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  final DataHealthController c;
  const _HistorySection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.history.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('سجل عمليات الدمج'),
          for (final e in c.history)
            Card(
              child: ExpansionTile(
                title: Text(
                    '${e.at.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} — ${e.studentsMerged} طالب، ${e.groupsMerged} مجموعة',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DataHealthService.summaryText(e),
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                height: 1.6)),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                              onPressed: () =>
                                  Share.share(DataHealthService.summaryText(e)),
                              child: const Text('مشاركة')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

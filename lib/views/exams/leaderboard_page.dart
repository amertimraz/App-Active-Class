// lib/views/exams/leaderboard_page.dart
//
// spec 018 — صفحة المراكز المطوّرة: ترويسة متدرّجة + فلاتر
// (الكل / مجموعة / امتحان / شهر) + ميداليات ذهب/فضة/برونز + مشاركة
// نص واتساب + شهادات المراكز.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/certificate_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/utils/leaderboard_share.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/exams/certificates_sheet.dart';
import 'package:active_class/views/exams/student_exam_history_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late final ExamController _ec;
  late final GroupController _gc;

  LbFilter _filter = const LbFilter();
  List<LeaderboardEntry> _entries = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ec = Get.find<ExamController>();
    _gc = Get.isRegistered<GroupController>()
        ? Get.find<GroupController>()
        : Get.put(GroupController());
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    // فلتر بيشير لمجموعة/امتحان اتحذف → رجوع تلقائي لـ"الكل".
    if (_filter.scope == LbScope.group &&
        !_gc.groups.any((g) => g.id == _filter.groupId)) {
      _filter = const LbFilter();
    } else if (_filter.scope == LbScope.exam &&
        !_ec.exams.any((e) => e.id == _filter.examId)) {
      _filter = const LbFilter();
    }
    setState(() => _loading = true);
    final entries = await _ec.leaderboard(_filter);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  // ── تسميات الفلتر ─────────────────────────────────────────────────────────
  String get _filterLabel {
    switch (_filter.scope) {
      case LbScope.all:
        return 'كل الامتحانات';
      case LbScope.group:
        return 'مجموعة ${_groupName(_filter.groupId)}';
      case LbScope.exam:
        return 'امتحان «${_examName(_filter.examId)}»';
      case LbScope.month:
        return _monthLabel(_filter.month);
    }
  }

  /// لاحقة نص الإنجاز في شهادة المركز (FR-009).
  String get _certScope {
    switch (_filter.scope) {
      case LbScope.all:
        return '';
      case LbScope.group:
        return 'في مجموعة ${_groupName(_filter.groupId)}';
      case LbScope.exam:
        return 'في امتحان «${_examName(_filter.examId)}»';
      case LbScope.month:
        return 'خلال ${_monthLabel(_filter.month)}';
    }
  }

  String _groupName(int? id) {
    final g = _gc.groups.firstWhereOrNull((g) => g.id == id);
    return g?.name ?? '—';
  }

  String _examName(int? id) {
    final e = _ec.exams.firstWhereOrNull((e) => e.id == id);
    return e?.name ?? '—';
  }

  String _monthLabel(DateTime? m) =>
      m == null ? '—' : DateFormat('MMMM yyyy', 'ar').format(m);

  List<DateTime> get _availableMonths {
    final set = <String, DateTime>{};
    for (final e in _ec.exams) {
      final r = e.effectiveReportMonth;
      set['${r.year}-${r.month}'] = DateTime(r.year, r.month, 1);
    }
    final list = set.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  // ── منتقيات ──────────────────────────────────────────────────────────────
  Future<void> _pickGroup() async {
    final groups = _gc.groups.toList();
    if (groups.isEmpty) {
      ToastHelper.info('مفيش مجموعات');
      return;
    }
    final id = await _pickFrom<int>(
      'اختَر مجموعة',
      [for (final g in groups) (g.id!, g.name)],
    );
    if (id != null && mounted) {
      setState(() => _filter = LbFilter(scope: LbScope.group, groupId: id));
      _load();
    }
  }

  Future<void> _pickExam() async {
    final exams = _ec.exams.toList();
    if (exams.isEmpty) {
      ToastHelper.info('مفيش امتحانات');
      return;
    }
    final id = await _pickFrom<int>(
      'اختَر امتحانًا',
      [for (final e in exams) (e.id!, e.name)],
    );
    if (id != null && mounted) {
      setState(() => _filter = LbFilter(scope: LbScope.exam, examId: id));
      _load();
    }
  }

  Future<void> _pickMonth() async {
    final months = _availableMonths;
    if (months.isEmpty) {
      ToastHelper.info('مفيش امتحانات');
      return;
    }
    final picked = await _pickFrom<DateTime>(
      'اختَر شهرًا',
      [for (final m in months) (m, DateFormat('MMMM yyyy', 'ar').format(m))],
    );
    if (picked != null && mounted) {
      setState(() => _filter = LbFilter(scope: LbScope.month, month: picked));
      _load();
    }
  }

  Future<T?> _pickFrom<T>(String title, List<(T, String)> options) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(title,
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            ),
            ...options.map((o) => ListTile(
                  title: Text(o.$2,
                      style: const TextStyle(fontFamily: 'Cairo')),
                  onTap: () => Navigator.pop(context, o.$1),
                )),
          ],
        ),
      ),
    );
  }

  // ── مشاركة + شهادات ──────────────────────────────────────────────────────
  void _share() {
    if (_entries.isEmpty) return;
    final s = Get.find<SettingsController>();
    final tName = s.teacherFullName.value.trim();
    final tLine = tName.isEmpty
        ? ''
        : [
            '${s.teacherTitle} $tName',
            if (s.teacherSpecialization.value.trim().isNotEmpty)
              s.teacherSpecialization.value.trim(),
          ].join('، ');
    Share.share(buildLeaderboardShareText(_entries,
        filterLabel: _filterLabel, teacherLine: tLine));
  }

  void _rankCertificates() {
    if (_entries.isEmpty) return;
    const kinds = [CertKind.rank1, CertKind.rank2, CertKind.rank3];
    final items = <CertificateData>[];
    for (var i = 0; i < _entries.length && i < 3; i++) {
      final e = _entries[i];
      items.add(_ec.buildRankCert(
        studentName: e.studentName,
        kind: kinds[i],
        pct: e.percentage,
        examCount: e.examCount,
        scopeLabel: _certScope,
      ));
    }
    Get.to(() => CertificatesSheet(
          title: 'شهادات المراكز',
          fileName: 'شهادات_المراكز',
          items: items,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المراكز',
            style:
                TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium_rounded),
            tooltip: 'شهادات المراكز',
            onPressed: _entries.isEmpty ? null : _rankCertificates,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'مشاركة قائمة الأوائل',
            onPressed: _entries.isEmpty ? null : _share,
          ),
        ],
      ),
      body: Column(
        children: [
          _header(),
          _filterBar(cs),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? _EmptyLeaderboard(cs: cs, filter: _filter)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                        itemCount: _entries.length,
                        itemBuilder: (_, i) =>
                            _LeaderboardCard(entry: _entries[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏆 المراكز',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 3),
            Text(
              _loading
                  ? '...'
                  : '${_entries.length} طالب محتسب · $_filterLabel',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
      );

  Widget _filterBar(ColorScheme cs) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
              bottom:
                  BorderSide(color: cs.onSurface.withValues(alpha: 0.08))),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('الكل', _filter.scope == LbScope.all, () {
              setState(() => _filter = const LbFilter());
              _load();
            }),
            const SizedBox(width: 8),
            _chip(
                _filter.scope == LbScope.group
                    ? 'مجموعة: ${_groupName(_filter.groupId)}'
                    : 'مجموعة',
                _filter.scope == LbScope.group,
                _pickGroup),
            const SizedBox(width: 8),
            _chip(
                _filter.scope == LbScope.exam
                    ? 'امتحان: ${_examName(_filter.examId)}'
                    : 'امتحان',
                _filter.scope == LbScope.exam,
                _pickExam),
            const SizedBox(width: 8),
            _chip(
                _filter.scope == LbScope.month
                    ? 'شهر: ${_monthLabel(_filter.month)}'
                    : 'شهر',
                _filter.scope == LbScope.month,
                _pickMonth),
          ]),
        ),
      );

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on
              ? AppTheme.primaryColor
              : AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: on
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : AppTheme.primaryColor)),
      ),
    );
  }
}

// ─── بطاقة مركز ───────────────────────────────────────────────────────────────
class _LeaderboardCard extends StatelessWidget {
  final LeaderboardEntry entry;
  const _LeaderboardCard({required this.entry});

  Color get _rankColor {
    if (entry.rank == 1) return const Color(0xFFFFD700);
    if (entry.rank == 2) return const Color(0xFFC0C0C0);
    if (entry.rank == 3) return const Color(0xFFCD7F32);
    return AppTheme.primaryColor;
  }

  String get _rankEmoji {
    if (entry.rank == 1) return '🥇';
    if (entry.rank == 2) return '🥈';
    if (entry.rank == 3) return '🥉';
    return '${entry.rank}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTop3 = entry.rank <= 3;
    final rc = _rankColor;
    final pct = (entry.percentage / 100).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => Get.to(
        () => StudentExamHistoryPage(
          studentId: entry.studentId,
          studentName: entry.studentName,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: isTop3
              ? LinearGradient(
                  colors: [
                    rc.withValues(alpha: isDark ? 0.2 : 0.12),
                    rc.withValues(alpha: isDark ? 0.05 : 0.02),
                  ],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                )
              : null,
          color: isTop3 ? null : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTop3
                ? rc.withValues(alpha: 0.35)
                : cs.onSurface.withValues(alpha: 0.1),
            width: isTop3 ? 1.5 : 1,
          ),
          boxShadow: isTop3
              ? [
                  BoxShadow(
                      color: rc.withValues(alpha: isDark ? 0.1 : 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rc.withValues(alpha: isTop3 ? 0.16 : 0.10),
                shape: BoxShape.circle,
              ),
              child: Text(_rankEmoji,
                  style: TextStyle(
                      fontSize: isTop3 ? 18 : 14,
                      fontWeight: FontWeight.w900,
                      color: isTop3
                          ? null
                          : cs.onSurface.withValues(alpha: 0.5),
                      fontFamily: 'Cairo')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.studentName,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight:
                              isTop3 ? FontWeight.w900 : FontWeight.w700,
                          color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.groupName} · ${entry.totalGrade.toStringAsFixed(0)}/${entry.totalMax.toStringAsFixed(0)} · ${entry.examCount} امتحان',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        color: cs.onSurface.withValues(alpha: 0.45)),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: rc.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isTop3 ? rc : AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('${entry.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isTop3 ? rc : AppTheme.primaryColor)),
          ]),
        ),
      ),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────
class _EmptyLeaderboard extends StatelessWidget {
  final ColorScheme cs;
  final LbFilter filter;
  const _EmptyLeaderboard({required this.cs, required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = filter.scope == LbScope.month
        ? 'مفيش امتحانات في الشهر ده'
        : 'لا توجد نتائج بعد';
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🏆', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(msg,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 6),
        Text('أدخل درجات الطلاب أولاً',
            style: TextStyle(
                fontFamily: 'Cairo',
                color: cs.onSurface.withValues(alpha: 0.3))),
      ]),
    );
  }
}

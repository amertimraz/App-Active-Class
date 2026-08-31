// lib/views/exams/leaderboard_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/views/exams/student_exam_history_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late final ExamController  _ec;
  late final GroupController _gc;

  int? _selectedExamId;
  int? _selectedGroupId;

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
    setState(() => _loading = true);
    final entries = await _ec.getLeaderboard(
      examId:  _selectedExamId,
      groupId: _selectedGroupId,
    );
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 الأوائل',
            style: TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          // ── Filters ───────────────────────────────────────────────
          Obx(() {
            final exams  = _ec.exams.toList();
            final groups = _gc.groups.toList();
            return _FiltersBar(
              exams:           exams,
              groups:          groups,
              selectedExamId:  _selectedExamId,
              selectedGroupId: _selectedGroupId,
              onExamChanged: (id) {
                setState(() => _selectedExamId = id);
                _load();
              },
              onGroupChanged: (id) {
                setState(() => _selectedGroupId = id);
                _load();
              },
            );
          }),

          // ── List ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? _EmptyLeaderboard(cs: cs)
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _entries.length,
                        itemBuilder: (_, i) =>
                            _LeaderboardCard(entry: _entries[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── شريط الفلاتر ──────────────────────────────────────────────────────────────
class _FiltersBar extends StatelessWidget {
  final List<Exam>  exams;
  final List<Group> groups;
  final int?        selectedExamId;
  final int?        selectedGroupId;
  final void Function(int?) onExamChanged;
  final void Function(int?) onGroupChanged;

  const _FiltersBar({
    required this.exams,
    required this.groups,
    required this.selectedExamId,
    required this.selectedGroupId,
    required this.onExamChanged,
    required this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : AppTheme.primaryColor.withValues(alpha: 0.04),
        border: Border(
            bottom: BorderSide(
                color: cs.onSurface.withValues(alpha: 0.08))),
      ),
      child: Row(children: [
        Expanded(
          child: _DropdownFilter<int?>(
            hint: 'كل الامتحانات',
            value: selectedExamId,
            cs: cs, isDark: isDark,
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('كل الامتحانات',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
              ...exams.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.name,
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: onExamChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DropdownFilter<int?>(
            hint: 'كل المجموعات',
            value: selectedGroupId,
            cs: cs, isDark: isDark,
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('كل المجموعات',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
              ...groups.map((g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(g.name,
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: onGroupChanged,
          ),
        ),
      ]),
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  final String                    hint;
  final T                         value;
  final ColorScheme               cs;
  final bool                      isDark;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)         onChanged;

  const _DropdownFilter({
    required this.hint,
    required this.value,
    required this.cs,
    required this.isDark,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark
              ? cs.onSurface.withValues(alpha: 0.06)
              : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: cs.onSurface.withValues(alpha: 0.15)),
        ),
        child: DropdownButton<T>(
          value:      value,
          items:      items,
          onChanged:  onChanged,
          isExpanded: true,
          underline:  const SizedBox(),
          dropdownColor: cs.surface,
          hint: Text(hint,
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.5))),
        ),
      );
}

// ─── بطاقة الأول ──────────────────────────────────────────────────────────────
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

  String get _initials {
    final parts = entry.studentName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '؟';
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return parts[0][0];
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final isTop3   = entry.rank <= 3;
    final rc       = _rankColor;

    return GestureDetector(
      onTap: () => Get.to(
        () => StudentExamHistoryPage(
          studentId:   entry.studentId,
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
            ? [BoxShadow(
                color: rc.withValues(alpha: isDark ? 0.1 : 0.12),
                blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          // Rank
          SizedBox(
            width: 36,
            child: Text(_rankEmoji,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: isTop3 ? 24 : 14,
                    fontWeight: FontWeight.w900,
                    color: isTop3
                        ? null
                        : cs.onSurface.withValues(alpha: 0.4),
                    fontFamily: 'Cairo')),
          ),
          const SizedBox(width: 10),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: rc.withValues(alpha: 0.18),
            child: Text(_initials,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isTop3 ? rc : AppTheme.primaryColor)),
          ),
          const SizedBox(width: 12),

          // Name + Group
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.studentName,
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 14,
                        fontWeight: isTop3
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: cs.onSurface)),
                Text(
                  entry.examCount > 1
                      ? '${entry.groupName} · ${entry.examCount} امتحانات'
                      : entry.groupName,
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),

          // Grade + %
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalGrade.toStringAsFixed(0)} / ${entry.totalMax.toStringAsFixed(0)}',
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isTop3 ? rc : AppTheme.primaryColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: rc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${entry.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isTop3 ? rc : AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ]),
      ),
    ), // Container
    ); // GestureDetector
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────
class _EmptyLeaderboard extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyLeaderboard({required this.cs});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('لا توجد نتائج بعد',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 16,
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

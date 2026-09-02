// lib/views/exams/exams_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/views/exams/exam_grades_page.dart';
import 'package:active_class/views/exams/leaderboard_page.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';

// ─── حالة الامتحان ────────────────────────────────────────────────────────────
enum ExamStatus { notStarted, inProgress, complete }

extension ExamStatusExt on ExamStatus {
  String get label {
    switch (this) {
      case ExamStatus.notStarted:
        return 'لم يبدأ';
      case ExamStatus.inProgress:
        return 'قيد الإدخال';
      case ExamStatus.complete:
        return 'مكتمل';
    }
  }

  Color get color {
    switch (this) {
      case ExamStatus.notStarted:
        return const Color(0xFF6B7280);
      case ExamStatus.inProgress:
        return const Color(0xFFF59E0B);
      case ExamStatus.complete:
        return const Color(0xFF10B981);
    }
  }

  IconData get icon {
    switch (this) {
      case ExamStatus.notStarted:
        return Icons.radio_button_unchecked_rounded;
      case ExamStatus.inProgress:
        return Icons.timelapse_rounded;
      case ExamStatus.complete:
        return Icons.check_circle_rounded;
    }
  }
}

ExamStatus _statusOf(ExamProgress? p) {
  if (p == null || p.totalStudents == 0) return ExamStatus.notStarted;
  final done = p.enteredGrades + p.absentStudents;
  if (done == 0) return ExamStatus.notStarted;
  if (done >= p.totalStudents) return ExamStatus.complete;
  return ExamStatus.inProgress;
}

class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key});
  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  late final ExamController _ec;
  late final GroupController _gc;

  final _searchCtrl = TextEditingController();
  String _search = '';
  ExamStatus? _statusFilter;
  int? _groupFilter;

  final Map<int, ExamProgress> _progress = {};
  Worker? _examsWorker;

  @override
  void initState() {
    super.initState();
    _ec = Get.find<ExamController>();
    _gc = Get.isRegistered<GroupController>()
        ? Get.find<GroupController>()
        : Get.put(GroupController());

    _loadAllProgress();
    // إعادة تحميل التقدم عند تغيّر قائمة الامتحانات (إضافة/تعديل/حذف)
    _examsWorker = ever(_ec.exams, (_) => _loadAllProgress());
  }

  @override
  void dispose() {
    _examsWorker?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllProgress() async {
    // استعلامين مجمَّعين لكل الامتحانات مرة واحدة بدل استعلام منفصل لكل
    // امتحان — مع مدرّس متراكم عنده امتحانات كتير كان اللف التسلسلي ده
    // بياخد وقت محسوس (شبه تعليق) كل ما الصفحة تفتح.
    final progress = await _ec.getAllExamsProgress();
    _progress
      ..clear()
      ..addAll(progress);
    if (mounted) setState(() {});
  }

  Future<void> _refreshProgress(int examId) async {
    final p = await _ec.getExamProgress(examId);
    _progress[examId] = p;
    if (mounted) setState(() {});
  }

  List<Exam> _filtered(List<Exam> all) {
    return all.where((e) {
      if (_search.isNotEmpty &&
          !e.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      if (_groupFilter != null && !e.groupIds.contains(_groupFilter)) {
        return false;
      }
      if (_statusFilter != null &&
          _statusOf(_progress[e.id]) != _statusFilter) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الامتحانات والدرجات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        actions: [
          // زرار مزامنة الامتحانات القديمة — بيظهر بس لو وضع الفريق شغّال،
          // عشان يبعت الامتحانات اللي اتعملت قبل ما المزامنة دي تتوصّل
          // أصلاً (التحميل الأولي بيحصل مرة واحدة بس وقت تفعيل الفريق).
          if (TeamModeService().isEnabled.value)
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'مزامنة الامتحانات القديمة مع الفريق',
              onPressed: () async {
                final ok = await TeamModeService().resyncExams();
                if (!context.mounted) return;
                ok
                    ? ToastHelper.success('جاري مزامنة الامتحانات القديمة...')
                    : ToastHelper.error('وضع الفريق مش شغّال');
              },
            ),
          IconButton(
            icon: const Icon(Icons.emoji_events_rounded),
            tooltip: 'الأوائل',
            onPressed: () => Get.to(() => const LeaderboardPage()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExamSheet(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('امتحان جديد',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        final groups = _gc.groups.toList();
        final exams = _ec.exams.toList();

        if (_ec.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (exams.isEmpty) {
          return _EmptyState(onAdd: () => _showExamSheet(context, null));
        }

        final filtered = _filtered(exams);

        // إحصائيات اللوحة
        int complete = 0, inProgress = 0;
        for (final e in exams) {
          switch (_statusOf(_progress[e.id])) {
            case ExamStatus.complete:
              complete++;
              break;
            case ExamStatus.inProgress:
              inProgress++;
              break;
            default:
              break;
          }
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _ec.loadExams();
            await _loadAllProgress();
          },
          child: CustomScrollView(
            slivers: [
              // ── لوحة الإحصائيات ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _StatsDashboard(
                    total: exams.length,
                    complete: complete,
                    inProgress: inProgress,
                    pending: exams.length - complete - inProgress,
                  ),
                ),
              ),

              // ── البحث ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 13, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن امتحان...',
                      hintStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.35)),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              })
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? cs.onSurface.withValues(alpha: 0.05)
                          : Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                              color: cs.onSurface.withValues(alpha: 0.12))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                              color: cs.onSurface.withValues(alpha: 0.12))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 1.5)),
                    ),
                  ),
                ),
              ),

              // ── الفلاتر ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    children: [
                      // فلتر الحالة
                      _FilterChipW(
                        label: 'الكل',
                        selected: _statusFilter == null,
                        color: AppTheme.primaryColor,
                        onTap: () => setState(() => _statusFilter = null),
                      ),
                      ...ExamStatus.values.map((s) => _FilterChipW(
                            label: s.label,
                            icon: s.icon,
                            selected: _statusFilter == s,
                            color: s.color,
                            onTap: () => setState(() =>
                                _statusFilter = _statusFilter == s ? null : s),
                          )),
                      // فاصل
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        color: cs.onSurface.withValues(alpha: 0.12),
                      ),
                      // فلتر المجموعات
                      ...groups.map((g) {
                        final c = Color(g.color ?? 0xFF4F46E5);
                        return _FilterChipW(
                          label: g.name,
                          icon: Icons.groups_rounded,
                          selected: _groupFilter == g.id,
                          color: c,
                          onTap: () => setState(() => _groupFilter =
                              _groupFilter == g.id ? null : g.id),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // ── القائمة (مجمّعة بالشهور) ─────────────────────────
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.search_off_rounded,
                            size: 48,
                            color: cs.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 10),
                        Text('لا توجد نتائج مطابقة',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: cs.onSurface.withValues(alpha: 0.4))),
                      ]),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      _buildGroupedList(filtered, groups, isDark, cs),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // بناء القائمة مع عناوين الشهور
  List<Widget> _buildGroupedList(
      List<Exam> exams, List<Group> groups, bool isDark, ColorScheme cs) {
    final widgets = <Widget>[];
    String? lastMonth;

    for (final exam in exams) {
      final month = DateFormat('MMMM yyyy', 'ar').format(exam.date);
      if (month != lastMonth) {
        lastMonth = month;
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Row(children: [
            Icon(Icons.calendar_month_rounded,
                size: 15, color: cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Text(month,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.55))),
            const SizedBox(width: 10),
            Expanded(
                child: Divider(color: cs.onSurface.withValues(alpha: 0.08))),
          ]),
        ));
      }
      widgets.add(_ExamCard(
        exam: exam,
        groups: groups,
        isDark: isDark,
        progress: _progress[exam.id],
        onEdit: () => _showExamSheet(context, exam),
        onDelete: () => _confirmDelete(context, exam),
        onOpenGrades: (gId, gName) async {
          await Get.to(
              () => ExamGradesPage(exam: exam, groupId: gId, groupName: gName));
          _refreshProgress(exam.id!);
        },
      ));
    }
    return widgets;
  }

  // ── Sheet ──────────────────────────────────────────────────────────────────
  void _showExamSheet(BuildContext ctx, Exam? existing) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExamFormSheet(
        existing: existing,
        groups: _gc.groups.toList(),
        onSave: (name, date, max, passing, groupIds, reportMonth) async {
          String? err;
          if (existing == null) {
            err = await _ec.addExam(
              name: name,
              date: date,
              maxGrade: max,
              passingGrade: passing,
              groupIds: groupIds,
              reportMonth: reportMonth,
            );
          } else {
            err = await _ec.editExam(
              existing.copyWith(
                  name: name,
                  date: date,
                  maxGrade: max,
                  passingGrade: passing,
                  groupIds: groupIds,
                  reportMonth: reportMonth),
              groupIds,
            );
          }
          if (err == null && ctx.mounted) Navigator.pop(ctx);
          return err;
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Exam exam) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الامتحان',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(
          'سيتم حذف "${exam.name}" وجميع الدرجات المرتبطة به.\nهل أنت متأكد؟',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _ec.deleteExam(exam.id!);
              } catch (e) {
                if (context.mounted) {
                  ToastHelper.error('فشل حذف الامتحان — حاول تاني');
                }
              }
            },
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

// ─── لوحة الإحصائيات ──────────────────────────────────────────────────────────
class _StatsDashboard extends StatelessWidget {
  final int total, complete, inProgress, pending;
  const _StatsDashboard({
    required this.total,
    required this.complete,
    required this.inProgress,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _DashStat(
              value: '$total',
              label: 'إجمالي\nالامتحانات',
              icon: Icons.assignment_rounded),
          _dashDivider(),
          _DashStat(
              value: '$complete',
              label: 'مكتمل\nالإدخال',
              icon: Icons.check_circle_rounded),
          _dashDivider(),
          _DashStat(
              value: '$inProgress',
              label: 'قيد\nالإدخال',
              icon: Icons.timelapse_rounded),
          _dashDivider(),
          _DashStat(
              value: '$pending',
              label: 'لم\nيبدأ',
              icon: Icons.pending_outlined),
        ],
      ),
    );
  }

  Widget _dashDivider() => Container(
        width: 1,
        height: 40,
        color: Colors.white.withValues(alpha: 0.2),
      );
}

class _DashStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _DashStat(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 5),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9.5,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.75))),
        ]),
      );
}

// ─── شريحة فلتر ───────────────────────────────────────────────────────────────
class _FilterChipW extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChipW({
    required this.label,
    this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: selected ? Colors.white : color),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (cs.brightness == Brightness.dark ? color : color))),
        ]),
      ),
    );
  }
}

// ─── بطاقة الامتحان ────────────────────────────────────────────────────────────
class _ExamCard extends StatelessWidget {
  final Exam exam;
  final List<Group> groups;
  final bool isDark;
  final ExamProgress? progress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(int, String) onOpenGrades;

  const _ExamCard({
    required this.exam,
    required this.groups,
    required this.isDark,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenGrades,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final relatedGroups =
        groups.where((g) => exam.groupIds.contains(g.id)).toList();
    final status = _statusOf(progress);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: status.color.withValues(alpha: 0.18)),
      ),
      elevation: isDark ? 0 : 2,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_rounded,
                    color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exam.name,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface)),
                    Text(
                      DateFormat('d MMMM yyyy', 'ar').format(exam.date),
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              // شارة الحالة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(status.icon, size: 12, color: status.color),
                  const SizedBox(width: 4),
                  Text(status.label,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: status.color)),
                ]),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('تعديل', style: TextStyle(fontFamily: 'Cairo')),
                      ])),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_rounded,
                            size: 18, color: Colors.red.shade400),
                        const SizedBox(width: 8),
                        Text('حذف',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.red.shade400)),
                      ])),
                ],
              ),
            ]),
            const SizedBox(height: 10),

            // Info chips
            Wrap(spacing: 8, children: [
              _InfoChip(
                icon: Icons.grade_rounded,
                label: 'من ${exam.maxGrade.toStringAsFixed(0)} درجة',
                color: AppTheme.primaryColor,
              ),
              _InfoChip(
                icon: Icons.check_circle_outline_rounded,
                label: 'النجاح: ${exam.passingGrade.toStringAsFixed(0)}',
                color: AppTheme.successColor,
              ),
              if (progress != null && progress!.absentStudents > 0)
                _InfoChip(
                  icon: Icons.person_off_rounded,
                  label: 'غياب: ${progress!.absentStudents}',
                  color: Colors.grey,
                ),
            ]),
            const SizedBox(height: 12),

            // ── Progress Bar ────────────────────────────────────────
            if (progress != null && progress!.totalStudents > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تقدم الإدخال',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                  Text(
                    '${progress!.enteredGrades + progress!.absentStudents}'
                    '/${progress!.totalStudents}',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: status.color),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (progress!.enteredGrades + progress!.absentStudents) /
                      progress!.totalStudents,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(status.color),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Groups buttons
            if (relatedGroups.isEmpty)
              Text('لا توجد مجموعات مرتبطة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.4)))
            else ...[
              Text('إدخال الدرجات:',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: relatedGroups.map((g) {
                  final c = Color(g.color ?? 0xFF4F46E5);
                  return InkWell(
                    onTap: () => onOpenGrades(g.id!, g.name),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.groups_rounded, size: 13, color: c),
                        const SizedBox(width: 4),
                        Text(g.name,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: c),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Info Chip ────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      );
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_outlined,
              size: 72, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('لا توجد امتحانات بعد',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          Text('اضغط + لإضافة امتحان جديد',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: cs.onSurface.withValues(alpha: 0.35))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة امتحان',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── نموذج إضافة / تعديل امتحان ──────────────────────────────────────────────
class _ExamFormSheet extends StatefulWidget {
  final Exam? existing;
  final List<Group> groups;
  final Future<String?> Function(
      String, DateTime, double, double, List<int>, String?) onSave;

  const _ExamFormSheet({
    required this.existing,
    required this.groups,
    required this.onSave,
  });
  @override
  State<_ExamFormSheet> createState() => _ExamFormSheetState();
}

class _ExamFormSheetState extends State<_ExamFormSheet> {
  final _nameCtrl = TextEditingController();
  final _maxCtrl = TextEditingController(text: '100');
  final _passingCtrl = TextEditingController(text: '50');
  DateTime _date = DateTime.now();
  // "شهر التقرير" — لو null الامتحان بيتبع شهر تاريخه؛ المدرس يقدر
  // يحدّده صراحةً لامتحان على شهر فات (spec 013 US6). صيغة "YYYY-M".
  String? _reportMonth;
  final Set<int> _selectedGroups = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _maxCtrl.text = e.maxGrade.toStringAsFixed(0);
      _passingCtrl.text = e.passingGrade.toStringAsFixed(0);
      _date = e.date;
      _reportMonth = e.reportMonth;
      _selectedGroups.addAll(e.groupIds);
    }
  }

  DateTime get _effectiveReportMonth {
    final raw = _reportMonth;
    if (raw != null) {
      final p = raw.split('-');
      if (p.length == 2) {
        final y = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        if (y != null && m != null && m >= 1 && m <= 12) {
          return DateTime(y, m, 1);
        }
      }
    }
    return DateTime(_date.year, _date.month, 1);
  }

  Future<void> _pickReportMonth() async {
    final cur = _effectiveReportMonth;
    final picked = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'اختر شهر التقرير',
    );
    if (picked != null && mounted) {
      setState(() => _reportMonth = '${picked.year}-${picked.month}');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _maxCtrl.dispose();
    _passingCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.onSave(
      _nameCtrl.text,
      _date,
      double.tryParse(_maxCtrl.text) ?? 100,
      double.tryParse(_passingCtrl.text) ?? 50,
      _selectedGroups.toList(),
      _reportMonth,
    );
    if (mounted)
      setState(() {
        _saving = false;
        _error = err;
      });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.existing != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2))),
              ),
              Text(isEdit ? 'تعديل الامتحان' : 'امتحان جديد',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface)),
              const SizedBox(height: 16),

              // Name
              _SheetField(
                  ctrl: _nameCtrl,
                  hint: 'اسم الامتحان',
                  icon: Icons.assignment_rounded),
              const SizedBox(height: 12),

              // Date picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: cs.onSurface.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? cs.onSurface.withValues(alpha: 0.05) : null,
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded,
                        color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('d MMMM yyyy', 'ar').format(_date),
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: cs.onSurface),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: cs.onSurface.withValues(alpha: 0.4)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // شهر التقرير (spec 013 US6)
              InkWell(
                onTap: _pickReportMonth,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: cs.onSurface.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? cs.onSurface.withValues(alpha: 0.05) : null,
                  ),
                  child: Row(children: [
                    Icon(Icons.event_note_rounded,
                        color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('شهر التقرير',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        Text(
                          DateFormat('MMMM yyyy', 'ar')
                              .format(_effectiveReportMonth),
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              color: cs.onSurface),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_reportMonth != null)
                      InkWell(
                        onTap: () => setState(() => _reportMonth = null),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                        ),
                      )
                    else
                      Icon(Icons.arrow_drop_down_rounded,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // Grades row
              Row(children: [
                Expanded(
                  child: _SheetField(
                      ctrl: _maxCtrl,
                      hint: 'الدرجة الكاملة',
                      icon: Icons.grade_rounded,
                      type:
                          const TextInputType.numberWithOptions(decimal: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetField(
                      ctrl: _passingCtrl,
                      hint: 'درجة النجاح',
                      icon: Icons.check_circle_outline_rounded,
                      type:
                          const TextInputType.numberWithOptions(decimal: true)),
                ),
              ]),
              const SizedBox(height: 16),

              // Groups
              Text('المجموعات:',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
              const SizedBox(height: 8),
              if (widget.groups.isEmpty)
                Text('لا توجد مجموعات — أضف مجموعة أولاً',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: cs.onSurface.withValues(alpha: 0.4)))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: widget.groups.map((g) {
                    final sel = _selectedGroups.contains(g.id);
                    final c = Color(g.color ?? 0xFF4F46E5);
                    return FilterChip(
                      label: Text(g.name,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? c : cs.onSurface)),
                      selected: sel,
                      selectedColor: c.withValues(alpha: 0.15),
                      checkmarkColor: c,
                      side: BorderSide(
                          color: sel ? c : cs.onSurface.withValues(alpha: 0.2)),
                      backgroundColor: Colors.transparent,
                      onSelected: (_) => setState(() {
                        if (sel) {
                          _selectedGroups.remove(g.id);
                        } else {
                          _selectedGroups.add(g.id!);
                        }
                      }),
                    );
                  }).toList(),
                ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppTheme.errorColor,
                        fontSize: 12)),
              ],
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'حفظ التعديلات' : 'إضافة الامتحان',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType type;
  const _SheetField({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.type = TextInputType.text,
  });
  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(
            fontFamily: 'Cairo',
            color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontFamily: 'Cairo',
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4)),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}

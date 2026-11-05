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
import 'package:active_class/views/exams/online_exams_tab.dart';
import 'package:active_class/views/exams/games/game_type_picker_page.dart';
import 'package:active_class/views/exams/online_exam_editor_page.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/group_multi_select_field.dart';

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

/// ألوان الحالة من الـtokens (تتبدّل مع الوضع الليلي). fill = تعبئة الشرائط،
/// ink = لون النص.
extension ExamStatusTokens on ExamStatus {
  Color fill(AppTokens t) => switch (this) {
        ExamStatus.notStarted => t.inkFaint,
        ExamStatus.inProgress => t.cautionBar,
        ExamStatus.complete => t.positive,
      };
  Color ink(AppTokens t) => switch (this) {
        ExamStatus.notStarted => t.inkSoft,
        ExamStatus.inProgress => t.caution,
        ExamStatus.complete => t.positive,
      };
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

class _ExamsPageState extends State<ExamsPage>
    with SingleTickerProviderStateMixin {
  late final ExamController _ec;
  late final GroupController _gc;
  late final TabController _tab;

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
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));

    _loadAllProgress();
    // إعادة تحميل التقدم عند تغيّر قائمة الامتحانات (إضافة/تعديل/حذف)
    _examsWorker = ever(_ec.exams, (_) => _loadAllProgress());
  }

  @override
  void dispose() {
    _examsWorker?.dispose();
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllProgress() async {
    // استعلامين مجمَّعين لكل الامتحانات مرة واحدة بدل استعلام منفصل لكل
    // امتحان — مع مدرّس متراكم عنده امتحانات كتير كان اللف التسلسلي ده
    // بياخد وقت محسوس (شبه تعليق) كل ما الصفحة تفتح.
    final progress = await _ec.getAllExamsProgress();
    // مفيش إعادة رسم لو الأرقام ما اتغيّرتش (تفادي وميض بلا فايدة).
    var same = progress.length == _progress.length;
    if (same) {
      for (final e in progress.entries) {
        final o = _progress[e.key];
        final n = e.value;
        if (o == null ||
            o.totalStudents != n.totalStudents ||
            o.enteredGrades != n.enteredGrades ||
            o.absentStudents != n.absentStudents) {
          same = false;
          break;
        }
      }
    }
    if (same) return;
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
      if (e.isOnline) return false; // تبويب "إلكتروني" منفصل
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

    final tk = context.tokens;
    return Scaffold(
      backgroundColor: tk.page,
      appBar: buildBoardAppBar(
        context,
        title: 'الامتحانات والدرجات',
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
        bottom: TabBar(
          controller: _tab,
          labelColor: tk.boardInk,
          unselectedLabelColor: tk.boardInkSoft,
          indicatorColor: tk.chalk,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelStyle: AppType.label,
          unselectedLabelStyle: AppType.label,
          tabs: const [
            Tab(
                height: 46,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('ورقي'),
                    ])),
            Tab(
                height: 46,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_tethering_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('إلكتروني'),
                    ])),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showExamSheet(context, null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('امتحان جديد',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            )
          : Obx(() {
              final access = TeamModeService().onlineExamAccessNow;
              if (!access.canCreate) return const SizedBox.shrink();
              final games = OnlineExamsTab.section.value == 1;
              return FloatingActionButton.extended(
                onPressed: () async {
                  if (games) {
                    await Get.to(() => const GameTypePickerPage());
                    OnlineExamsTab.gamesKey.currentState?.reload();
                  } else {
                    await Get.to(() => const OnlineExamEditorPage());
                    _ec.loadExams();
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(games ? 'لعبة جديدة' : 'امتحان إلكتروني جديد',
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              );
            }),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildPaperTab(theme, isDark, cs),
          const OnlineExamsTab(),
        ],
      ),
    );
  }

  Widget _buildPaperTab(ThemeData theme, bool isDark, ColorScheme cs) {
    final t = context.tokens;
    return Obx(() {
        final groups = _gc.groups.toList();
        // التبويب ده للامتحانات الورقية فقط — الإلكترونية في تبويب منفصل.
        final exams = _ec.exams.where((e) => !e.isOnline).toList();

        // spinner بس عند أول تحميل (القائمة فاضية). إعادة التحميل الدورية
        // (مزامنة الفريق/أي تعديل) كانت بتبدّل الشاشة كلها بدوّامة وترجع
        // تاني = "ريفريش" مزعج. دلوقتي القائمة بتفضل ثابتة وتتحدّث بهدوء.
        if (_ec.isLoading.value && exams.isEmpty) {
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
              // ── شريط الحالات (إحصائيات + فلتر في عنصر واحد) ──────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _StatusStrip(
                    total: exams.length,
                    complete: complete,
                    inProgress: inProgress,
                    pending: exams.length - complete - inProgress,
                    selected: _statusFilter,
                    onSelect: (st) => setState(() => _statusFilter = st),
                  ),
                ),
              ),

              // ── البحث + فلتر المجموعة ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _search = v),
                        style: AppType.label.copyWith(color: t.ink),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن امتحان...',
                          hintStyle:
                              AppType.body.copyWith(color: t.inkFaint),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 22, color: t.inkFaint),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(
                                  tooltip: 'مسح البحث',
                                  icon: Icon(Icons.close_rounded,
                                      size: 20, color: t.inkSoft),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _search = '');
                                  })
                              : null,
                          filled: true,
                          fillColor: t.surface,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.panel),
                              borderSide: BorderSide(color: t.line)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.panel),
                              borderSide: BorderSide(color: t.line)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.panel),
                              borderSide:
                                  BorderSide(color: t.brand, width: 1.5)),
                        ),
                      ),
                    ),
                    if (groups.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _GroupFilterButton(
                        active: _groupFilter != null,
                        onTap: () => _pickGroupFilter(groups),
                      ),
                    ],
                  ]),
                ),
              ),

              // المجموعة المختارة (بتتشال بضغطة)
              if (_groupFilter != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InputChip(
                        avatar: const Icon(Icons.groups_rounded, size: 16),
                        label: Text(
                            groups
                                    .firstWhereOrNull(
                                        (g) => g.id == _groupFilter)
                                    ?.name ??
                                'مجموعة',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        onDeleted: () => setState(() => _groupFilter = null),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 4)),

              // ── القائمة (مجمّعة بالشهور) ─────────────────────────
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.search_off_rounded,
                            size: 48, color: t.inkFaint),
                        const SizedBox(height: 10),
                        Text('لا توجد نتائج مطابقة',
                            style: AppType.label.copyWith(color: t.inkSoft)),
                        const SizedBox(height: 2),
                        Text('غيّر البحث أو الفلتر',
                            style: AppType.caption.copyWith(color: t.inkFaint)),
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
      });
  }

  // اختيار مجموعة للفلترة (بدل صف شرائح طويل مختلط مع الحالات).
  Future<void> _pickGroupFilter(List<Group> groups) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive_rounded),
              title: const Text('كل المجموعات',
                  style: TextStyle(fontFamily: 'Cairo')),
              selected: _groupFilter == null,
              onTap: () => Navigator.pop(ctx, -1),
            ),
            for (final g in groups)
              ListTile(
                leading: Icon(Icons.groups_rounded,
                    color: Color(g.color ?? 0xFF4F46E5)),
                title: Text(g.name,
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                selected: _groupFilter == g.id,
                onTap: () => Navigator.pop(ctx, g.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _groupFilter = picked == -1 ? null : picked);
  }

  // بناء القائمة مع عناوين الشهور
  List<Widget> _buildGroupedList(
      List<Exam> exams, List<Group> groups, bool isDark, ColorScheme cs) {
    final widgets = <Widget>[];
    final tk = context.tokens;
    String? lastMonth;

    for (final exam in exams) {
      final month = DateFormat('MMMM yyyy', 'ar').format(exam.date);
      if (month != lastMonth) {
        lastMonth = month;
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Row(children: [
            Icon(Icons.calendar_month_rounded, size: 16, color: tk.inkSoft),
            const SizedBox(width: 6),
            Text(month, style: AppType.label.copyWith(color: tk.inkSoft)),
            const SizedBox(width: 10),
            Expanded(child: Divider(color: tk.line)),
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

// ─── شريط الحالات: إحصائيات وفلتر في عنصر واحد ───────────────────────────────
class _StatusStrip extends StatelessWidget {
  final int total, complete, inProgress, pending;
  final ExamStatus? selected;
  final ValueChanged<ExamStatus?> onSelect;
  const _StatusStrip({
    required this.total,
    required this.complete,
    required this.inProgress,
    required this.pending,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget seg(String label, int n, Color color, Color ink, ExamStatus? value) {
      final on = selected == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: '$label، $n',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => onSelect(on ? null : value),
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: on ? color.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(
                    color: on ? color.withValues(alpha: 0.6) : Colors.transparent),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$n', style: AppType.figure.copyWith(fontSize: 22, color: ink)),
                    Text(label,
                        maxLines: 1,
                        style: AppType.caption.copyWith(
                            fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                            color: on ? t.ink : t.inkSoft)),
                  ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: t.line),
      ),
      child: Row(children: [
        seg('الكل', total, t.brand, t.brand, null),
        seg(ExamStatus.complete.label, complete, ExamStatus.complete.fill(t),
            ExamStatus.complete.ink(t), ExamStatus.complete),
        seg(ExamStatus.inProgress.label, inProgress,
            ExamStatus.inProgress.fill(t), ExamStatus.inProgress.ink(t),
            ExamStatus.inProgress),
        seg(ExamStatus.notStarted.label, pending, ExamStatus.notStarted.fill(t),
            ExamStatus.notStarted.ink(t), ExamStatus.notStarted),
      ]),
    );
  }
}

// زر فلتر المجموعة جنب البحث (بلون لو فيه فلتر شغّال).
class _GroupFilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _GroupFilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: 'فلتر المجموعة',
      child: Material(
        color: active ? t.rosterTint : t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: BorderSide(color: active ? t.brand : t.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.groups_rounded,
                size: 24, color: active ? t.brand : t.inkSoft),
          ),
        ),
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
    final t = context.tokens;
    final relatedGroups =
        groups.where((g) => exam.groupIds.contains(g.id)).toList();
    final status = _statusOf(progress);
    final hasProgress = progress != null && progress!.totalStudents > 0;
    final done =
        hasProgress ? progress!.enteredGrades + progress!.absentStudents : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Material(
        color: t.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: BorderSide(color: t.line),
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // شريط لون الحالة على الجنب
            Container(width: 6, color: status.fill(t)),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.lg, AppSpace.md, AppSpace.xs, AppSpace.md + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(exam.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.title.copyWith(color: t.ink)),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'المزيد',
                        icon: Icon(Icons.more_vert_rounded, color: t.inkSoft),
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
                                Text('تعديل'),
                              ])),
                          PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_rounded,
                                    size: 18, color: t.danger),
                                const SizedBox(width: 8),
                                Text('حذف', style: TextStyle(color: t.danger)),
                              ])),
                        ],
                      ),
                    ]),
                    Text(
                      '${DateFormat('d MMMM', 'ar').format(exam.date)}  •  '
                      'من ${exam.maxGrade.toStringAsFixed(0)}  •  '
                      'النجاح ${exam.passingGrade.toStringAsFixed(0)}',
                      style: AppType.caption.copyWith(color: t.inkSoft),
                    ),
                    if (hasProgress) ...[
                      const SizedBox(height: AppSpace.md),
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: done / progress!.totalStudents,
                              backgroundColor: t.line,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(status.fill(t)),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Text('$done/${progress!.totalStudents}',
                            style: AppType.label.copyWith(
                                fontSize: 13, color: status.ink(t))),
                      ]),
                      if (progress!.absentStudents > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('منهم ${progress!.absentStudents} غياب',
                              style:
                                  AppType.caption.copyWith(color: t.inkFaint)),
                        ),
                    ],
                    const SizedBox(height: AppSpace.md),
                    if (relatedGroups.isEmpty)
                      Text('لا توجد مجموعات مرتبطة',
                          style: AppType.caption.copyWith(color: t.inkFaint))
                    else
                      Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm - 2,
                        children: relatedGroups.map((g) {
                          final c = Color(g.color ?? 0xFF4F46E5);
                          return Material(
                            color: c.withValues(alpha: isDark ? 0.2 : 0.1),
                            shape: StadiumBorder(
                                side: BorderSide(color: c.withValues(alpha: 0.45))),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => onOpenGrades(g.id!, g.name),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 40),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpace.md),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_note_rounded,
                                            size: 18, color: c),
                                        const SizedBox(width: 6),
                                        Text(g.name,
                                            style: AppType.caption.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: t.ink)),
                                      ]),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_outlined, size: 64, color: t.inkFaint),
          const SizedBox(height: AppSpace.lg),
          Text('لا توجد امتحانات بعد',
              style: AppType.title.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.xs),
          Text('سجّل درجات امتحان ورقي من هنا.',
              style: AppType.body.copyWith(color: t.inkSoft)),
          const SizedBox(height: AppSpace.xl),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة امتحان'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
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

  /// صف بيفتح منتقي (تاريخ/شهر) بنفس شكل الحقول.
  Widget _pickerRow(AppTokens t,
      {required IconData icon,
      String? label,
      required String value,
      required VoidCallback onTap,
      Widget? trailing}) {
    return Material(
      color: t.page,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md + 2, vertical: AppSpace.sm),
            child: Row(children: [
              Icon(icon, color: t.brand, size: 20),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label != null)
                      Text(label,
                          style: AppType.caption.copyWith(color: t.inkFaint)),
                    Text(value, style: AppType.label.copyWith(color: t.ink)),
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.expand_more_rounded, color: t.inkFaint, size: 22),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isEdit = widget.existing != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.board)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xl - 4, AppSpace.sm, AppSpace.xl - 4, AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: t.line, borderRadius: BorderRadius.circular(2))),
              ),
              Text(isEdit ? 'تعديل الامتحان' : 'امتحان جديد',
                  style: AppType.greeting.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.lg),

              _SheetField(
                  ctrl: _nameCtrl,
                  hint: 'اسم الامتحان',
                  icon: Icons.assignment_rounded),
              const SizedBox(height: AppSpace.md),

              _pickerRow(t,
                  icon: Icons.calendar_today_rounded,
                  label: 'تاريخ الامتحان',
                  value: DateFormat('d MMMM yyyy', 'ar').format(_date),
                  onTap: _pickDate),
              const SizedBox(height: AppSpace.md),

              // شهر التقرير (spec 013 US6)
              _pickerRow(t,
                  icon: Icons.event_note_rounded,
                  label: 'شهر التقرير',
                  value: DateFormat('MMMM yyyy', 'ar')
                      .format(_effectiveReportMonth),
                  onTap: _pickReportMonth,
                  trailing: _reportMonth != null
                      ? IconButton(
                          tooltip: 'رجّع شهر التاريخ',
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: t.inkSoft),
                          onPressed: () => setState(() => _reportMonth = null),
                        )
                      : null),
              const SizedBox(height: AppSpace.md),

              Row(children: [
                Expanded(
                  child: _SheetField(
                      ctrl: _maxCtrl,
                      hint: 'الدرجة الكاملة',
                      icon: Icons.grade_rounded,
                      type:
                          const TextInputType.numberWithOptions(decimal: true)),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _SheetField(
                      ctrl: _passingCtrl,
                      hint: 'درجة النجاح',
                      icon: Icons.check_circle_outline_rounded,
                      type:
                          const TextInputType.numberWithOptions(decimal: true)),
                ),
              ]),
              const SizedBox(height: AppSpace.lg),

              // المجموعات: قائمة منسدلة، وتقدر تختار أكتر من مجموعة للامتحان
              Text('المجموعات', style: AppType.label.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.sm),
              GroupMultiSelectField(
                groups: widget.groups,
                selected: _selectedGroups,
                title: 'المجموعات المشاركة في الامتحان',
                onChanged: (ids) => setState(() {
                  _selectedGroups
                    ..clear()
                    ..addAll(ids);
                }),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(_error!,
                    style: AppType.body.copyWith(color: t.danger)),
              ],
              const SizedBox(height: AppSpace.xl - 4),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 54)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'حفظ التعديلات' : 'إضافة الامتحان'),
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
  Widget build(BuildContext context) {
    final t = context.tokens;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: AppType.label.copyWith(color: t.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppType.body.copyWith(color: t.inkFaint),
        prefixIcon: Icon(icon, color: t.brand, size: 20),
        filled: true,
        fillColor: t.page,
        border: border(t.line),
        enabledBorder: border(t.line),
        focusedBorder: border(t.brand, 1.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      ),
    );
  }
}

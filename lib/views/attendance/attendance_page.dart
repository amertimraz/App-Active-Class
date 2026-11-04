// lib/views/attendance/attendance_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:active_class/utils/session_guest.dart';
import 'package:get/get.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/utils/absence_message.dart';
import 'package:active_class/views/attendance/session_detail_page.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/utils/student_sort_helper.dart';
import 'package:active_class/widgets/overdue_warning_badge.dart';
import 'package:active_class/widgets/session_override_widgets.dart';
import 'package:active_class/controllers/session_override_controller.dart';
import 'package:active_class/models/session_override_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/custom_dialogs.dart' as custom_dialogs;
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/archive_history.dart';
import 'package:active_class/utils/recitation.dart';
import 'package:active_class/views/help/help_widgets.dart';
import 'package:active_class/utils/recitation_session.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/widgets/archive_event_tile.dart';
import 'package:intl/intl.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  final AttendanceController controller = Get.put(AttendanceController());
  final StudentController studentCtrl = Get.put(StudentController());
  final GroupController groupCtrl = Get.put(GroupController());
  final HomeworkController homeworkCtrl = Get.put(HomeworkController());
  late final TabController _tabController;
  DateTime _selectedDay = DateTime.now();
  // بيحرّك إعادة رسم العداد التنازلي لحصص المجموعات الشغالة دلوقتي —
  // مش محتاج دقة أعلى من كده لعداد بيتقاس بالدقايق (زي _statsTimer في
  // exam_grades_page.dart بالظبط).
  Timer? _countdownTimer;
  // مجموعات اترسل تقريرها النهاردة بالفعل — مش بتمنع إعادة الإرسال
  // (لو المدرس عدّل الحضور بعدين وحب يبعت تاني)، بس بتغيّر شكل الزرار
  // لتلميح "اتبعت" بدل ما يفضل شايل زي أول مرة. في الذاكرة بس، بتتصفّر
  // تلقائيًا لو الصفحة اتقفلت وفتحت تاني.
  final Set<int> _reportSentGroupIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _reload();
  }

  Future<void> _reload() async {
    await studentCtrl.loadAllStudents();
    await groupCtrl.loadGroups();
    await controller.loadAttendance();
    controller.buildStudentMaps(studentCtrl.students);
    await homeworkCtrl.loadHomework();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(
        context,
        title: 'سجل الحضور',
        bottom: TabBar(
          controller: _tabController,
          labelColor: t.boardInk,
          unselectedLabelColor: t.boardInkSoft,
          indicatorColor: t.chalk,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelStyle: AppType.label,
          unselectedLabelStyle:
              AppType.label.copyWith(fontWeight: FontWeight.w400),
          // تابات ثابتة بعرض متساوي؛ النص بيصغر مع الخط الكبير بدل القص.
          tabs: const [
            _BoardTab('تسجيل'),
            _BoardTab('السجل'),
            _BoardTab('الإحصائيات'),
            _BoardTab('الغياب'),
          ],
        ),
        actions: [
          const HelpButton(topicId: 'attendance'),
          if (Get.find<SettingsController>().showRecitation.value)
            IconButton(
              icon: const Icon(Icons.record_voice_over_rounded),
              tooltip: 'قائمة التسميع',
              onPressed: () => Get.toNamed(ROUTE_RECITATION),
            ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'تسجيل حضور بالـQR',
            onPressed: () => Get.toNamed(ROUTE_QR_SCANNER_ATTENDANCE),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'تصدير PDF',
            onPressed: () => _exportPDF(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _reload,
          ),
        ],
      ),
      body: ColoredBox(
        color: t.page,
        child: Obx(() {
          if (controller.isLoading.value && controller.attendance.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _RegisterTab(
                controller: controller,
                studentCtrl: studentCtrl,
                groupCtrl: groupCtrl,
                homeworkCtrl: homeworkCtrl,
                selectedDay: _selectedDay,
                onDayChanged: (d) => setState(() => _selectedDay = d),
                reportSentGroupIds: _reportSentGroupIds,
                onReportSent: (groupId) =>
                    setState(() => _reportSentGroupIds.add(groupId)),
              ),
              _RecordsTab(
                controller: controller,
                studentCtrl: studentCtrl,
                groupCtrl: groupCtrl,
              ),
              _StatisticsTab(
                controller: controller,
                studentCtrl: studentCtrl,
                groupCtrl: groupCtrl,
              ),
              _AbsentTodayTab(
                controller: controller,
                studentCtrl: studentCtrl,
                groupCtrl: groupCtrl,
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _exportPDF(BuildContext context) async {
    AppToast.info(context, 'جاري إنشاء تقرير الحضور...');
    final month = DateTime(_selectedDay.year, _selectedDay.month);
    final svc = ExportService();
    final result = await svc.exportAttendancePDF(
      month: month,
      students: studentCtrl.students,
      attendance: controller.attendance,
      groups: groupCtrl.groups,
      homework: homeworkCtrl.homework,
    );
    if (!context.mounted) return;
    if (result.success && result.path != null) {
      AppToast.success(context, 'تم إنشاء التقرير');
      await svc.sharePDF(result.path!);
    } else {
      AppToast.error(context, result.error ?? 'فشل التصدير');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Tab 1 — تسجيل الحضور
// ═══════════════════════════════════════════════════════════════════════════════

class _RegisterTab extends StatefulWidget {
  final AttendanceController controller;
  final StudentController studentCtrl;
  final GroupController groupCtrl;
  final HomeworkController homeworkCtrl;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayChanged;
  final Set<int> reportSentGroupIds;
  final ValueChanged<int> onReportSent;

  const _RegisterTab({
    required this.controller,
    required this.studentCtrl,
    required this.groupCtrl,
    required this.homeworkCtrl,
    required this.selectedDay,
    required this.onDayChanged,
    required this.reportSentGroupIds,
    required this.onReportSent,
  });

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  @override
  void initState() {
    super.initState();
    // spec 032 — تحديث استثناءات الحصص عند فتح الشاشة (نمط spec 029).
    if (Get.isRegistered<SessionOverrideController>()) {
      Get.find<SessionOverrideController>().load();
    }
  }

  bool get _isToday {
    final n = DateTime.now();
    return widget.selectedDay.year == n.year &&
        widget.selectedDay.month == n.month &&
        widget.selectedDay.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dateFmt = DateFormat('EEEE، d MMMM', 'ar');
    final selectedDay = widget.selectedDay;
    final dayStart =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final dayEnd = DateTime(
        selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59);

    return Obx(() {
      final students = widget.studentCtrl.students;
      final allGroups = widget.groupCtrl.groups;
      // بطاقات اليوم تشمل المجموعات الملغاة (عشان زر التراجع) — لكن
      // إحصاءات الشريط العلوي تحسب المجموعات النشطة فقط (spec 032).
      final todayGroups =
          widget.controller.groupsForDayWithOverrides(allGroups, selectedDay);
      final activeGroups =
          widget.controller.groupsForDay(allGroups, selectedDay);

      final dayRecords = widget.controller.attendance
          .where((a) => !a.date.isBefore(dayStart) && !a.date.isAfter(dayEnd));
      final Map<int, String> statusMap = {
        for (final a in dayRecords) a.studentId: a.status,
      };

      final todayIds = students
          .where((s) => activeGroups.any((g) => g.id == s.groupId))
          .map((s) => s.id)
          .toSet();
      final presentCount = statusMap.entries
          .where((e) =>
              todayIds.contains(e.key) &&
              normalizeAttendanceStatus(e.value) == ATTENDANCE_PRESENT)
          .length;
      final lateCount = statusMap.entries
          .where((e) =>
              todayIds.contains(e.key) &&
              normalizeAttendanceStatus(e.value) == ATTENDANCE_LATE)
          .length;
      final absentCount = statusMap.entries
          .where((e) =>
              todayIds.contains(e.key) &&
              normalizeAttendanceStatus(e.value) == ATTENDANCE_ABSENT)
          .length;
      final totalStudents = todayIds.length;
      final unmarked =
          totalStudents - statusMap.keys.where(todayIds.contains).length;

      return Column(children: [
        // ── مؤشر اليوم ──────────────────────────────────────────────────────
        _DayNavigator(
          selectedDay: selectedDay,
          isToday: _isToday,
          dateFmt: dateFmt,
          onDayChanged: widget.onDayChanged,
          presentCount: presentCount,
          lateCount: lateCount,
          absentCount: absentCount,
          unmarked: unmarked,
          totalStudents: totalStudents,
        ),

        // ── شبكة بطاقات مختصرة للمجموعات (بدل قائمة الطلاب المفرودة) ─────────
        // الضغط على أي كارت بيفتح موديل مخصص لتسجيل حضور هذه المجموعة بس
        // (showAttendanceSheet) — راجع القرار 5 في research.md.
        Expanded(
          child: allGroups.isEmpty
              ? const EmptyState(
                  icon: Icons.group_off,
                  title: 'لا توجد مجموعات',
                  subtitle: 'أضف مجموعات أولاً من صفحة المجموعات',
                )
              : todayGroups.isEmpty
                  ? _NoSessionsToday(
                      allGroups: allGroups, selectedDay: selectedDay)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: todayGroups.length + 1,
                      itemBuilder: (ctx, gi) {
                        // آخر عنصر: زر إضافة حصة استثنائية (تعويضية/إضافية)
                        // لأي مجموعة — حتى لو اليوم ده مش في جدولها.
                        if (gi == todayGroups.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: () => showAddSessionOverrideFlow(
                                  context,
                                  groups: allGroups.cast<Group>(),
                                  day: selectedDay,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: t.brand,
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 20),
                                label: Text('حصة تعويضية / إضافية',
                                    style: AppType.label),
                              ),
                            ),
                          );
                        }
                        final group = todayGroups[gi];
                        final sessionTime = widget.controller
                            .sessionTimeForGroupOnDay(group, selectedDay);
                        final groupStudents = students
                            .where((s) => s.groupId == group.id)
                            .toList()
                          ..sort((a, b) => a.name.compareTo(b.name));
                        if (groupStudents.isEmpty)
                          return const SizedBox.shrink();

                        final gPresent = groupStudents
                            .where((s) =>
                                attendanceCountsAsPresent(statusMap[s.id]))
                            .length;
                        final gLate = groupStudents
                            .where((s) =>
                                normalizeAttendanceStatus(statusMap[s.id]) ==
                                ATTENDANCE_LATE)
                            .length;
                        final gTotal = groupStudents.length;
                        final gRate = gTotal > 0 ? gPresent / gTotal : 0.0;

                        return _GroupSummaryCard(
                          group: group,
                          sessionTime: sessionTime,
                          presentCount: gPresent,
                          lateCount: gLate,
                          totalCount: gTotal,
                          attendanceRate: gRate,
                          controller: widget.controller,
                          overrideType: widget.controller
                              .sessionOverrideFor(group, selectedDay)
                              ?.type,
                          onDetails: () => Get.to(() => SessionDetailPage(
                              group: group, day: selectedDay)),
                          onTap: () => showAttendanceSheet(
                            context,
                            group: group,
                            selectedDay: selectedDay,
                            studentCtrl: widget.studentCtrl,
                            controller: widget.controller,
                            homeworkCtrl: widget.homeworkCtrl,
                            alreadySentReport:
                                widget.reportSentGroupIds.contains(group.id),
                            onReportSent: () => widget.onReportSent(group.id!),
                          ),
                        );
                      },
                    ),
        ),
      ]);
    });
  }
}

// ── مؤشر التنقل بين الأيام ───────────────────────────────────────────────────

// ألوان حالة الحضور من توكنز الثيم (حاضر/متأخر/غائب/لم يُسجَّل).
Color _statusInk(AppTokens t, String? raw) {
  switch (normalizeAttendanceStatus(raw)) {
    case ATTENDANCE_PRESENT:
      return t.positive;
    case ATTENDANCE_LATE:
      return t.caution;
    case ATTENDANCE_ABSENT:
      return t.danger;
    default:
      return t.inkFaint;
  }
}

Color _statusSoft(AppTokens t, String? raw) {
  switch (normalizeAttendanceStatus(raw)) {
    case ATTENDANCE_PRESENT:
      return t.positiveSoft;
    case ATTENDANCE_LATE:
      return t.cautionSoft;
    case ATTENDANCE_ABSENT:
      return t.dangerSoft;
    default:
      return t.line;
  }
}

// نسبة حضور الطالب: 80 وأكتر أخضر، 60 وأكتر أصفر، غير كده أحمر.
Color _percentInk(AppTokens t, double p) =>
    p >= 80 ? t.positive : (p >= 60 ? t.caution : t.danger);
Color _percentSoft(AppTokens t, double p) =>
    p >= 80 ? t.positiveSoft : (p >= 60 ? t.cautionSoft : t.dangerSoft);

class _DayNavigator extends StatelessWidget {
  final bool isToday;
  final DateTime selectedDay;
  final DateFormat dateFmt;
  final ValueChanged<DateTime> onDayChanged;
  final int presentCount, lateCount, absentCount, unmarked, totalStudents;

  const _DayNavigator({
    required this.selectedDay,
    required this.isToday,
    required this.dateFmt,
    required this.onDayChanged,
    required this.presentCount,
    this.lateCount = 0,
    required this.absentCount,
    required this.unmarked,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // ألوان الحالات فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;
    // "متأخر" يُحتسب حضورًا في النسبة (spec 011)
    final rate =
        totalStudents > 0 ? (presentCount + lateCount) / totalStudents : 0.0;
    final barColor = totalStudents == 0
        ? t.boardInkSoft
        : rate >= 0.8
            ? on.positive
            : rate >= 0.5
                ? t.chalk
                : on.danger;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
      decoration: BoxDecoration(
        color: t.board,
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.board)),
      ),
      child: Column(children: [
        // التنقل
        Row(children: [
          if (!isToday)
            BoardIconButton(
              icon: Icons.today_rounded,
              tooltip: 'وصول سريع لليوم',
              onPressed: () => onDayChanged(DateTime.now()),
            ),
          BoardIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'اليوم السابق',
            onPressed: () =>
                onDayChanged(selectedDay.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.control),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: selectedDay,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  helpText: 'اختر اليوم',
                );
                if (p != null) onDayChanged(p);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            isToday ? 'اليوم' : dateFmt.format(selectedDay),
                            textAlign: TextAlign.center,
                            style: AppType.title
                                .copyWith(fontSize: 18, color: t.boardInk),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Icon(Icons.calendar_month_rounded,
                            size: 18, color: t.boardInkSoft),
                      ],
                    ),
                    if (!isToday)
                      Text(
                        DateFormat('yyyy/MM/dd').format(selectedDay),
                        style: AppType.caption.copyWith(color: t.boardInkSoft),
                      ),
                  ],
                ),
              ),
            ),
          ),
          BoardIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'اليوم التالي',
            onPressed: selectedDay
                    .isBefore(DateTime.now().subtract(const Duration(days: 1)))
                ? () => onDayChanged(selectedDay.add(const Duration(days: 1)))
                : null,
          ),
        ]),
        // شريط النسبة
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: LinearProgressIndicator(
              value: totalStudents == 0 ? 0 : rate.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: t.boardLine,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        // الإحصاء
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          child: Row(
            children: [
              Expanded(
                  child: BoardStat(
                      label: 'حاضر',
                      value: '$presentCount',
                      color: on.positive)),
              if (lateCount > 0)
                Expanded(
                    child: BoardStat(
                        label: 'متأخر', value: '$lateCount', color: t.chalk)),
              Expanded(
                  child: BoardStat(
                      label: 'غائب', value: '$absentCount', color: on.danger)),
              Expanded(
                  child: BoardStat(
                      label: 'لم يُسجَّل',
                      value: '$unmarked',
                      color: t.boardInkSoft)),
              Expanded(
                  child: BoardStat(
                      label: 'الكل',
                      value: '$totalStudents',
                      color: t.boardInk)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── كارت مختصر لمجموعة (اسم/ميعاد/إحصائية) — الضغط عليه يفتح موديل تسجيل
// الحضور الكامل. بديل لـ _GroupAttendanceCard القديمة اللي كانت بتفرد كل
// طلاب المجموعة في الشاشة الرئيسية مباشرة.
// ─────────────────────────────────────────────────────────────────────────

class _GroupSummaryCard extends StatelessWidget {
  final Group group;
  final String? sessionTime;
  final int presentCount, totalCount;
  final int lateCount;
  final double attendanceRate;
  final AttendanceController controller;
  final VoidCallback onTap;
  final VoidCallback? onDetails; // spec 053 — تفاصيل الحصة
  final SessionOverrideType? overrideType;

  const _GroupSummaryCard({
    required this.group,
    required this.sessionTime,
    required this.presentCount,
    this.lateCount = 0,
    required this.totalCount,
    required this.attendanceRate,
    required this.controller,
    required this.onTap,
    this.onDetails,
    this.overrideType,
  });

  Widget _chip(String label, Color ink, Color soft) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(label,
            style: AppType.caption
                .copyWith(fontWeight: FontWeight.w700, color: ink)),
      );

  Widget _overrideChip(AppTokens t, SessionOverrideType type) {
    switch (type) {
      case SessionOverrideType.cancelled:
        return _chip('ملغاة', t.danger, t.dangerSoft);
      case SessionOverrideType.makeup:
        return _chip('تعويضية', t.positive, t.positiveSoft);
      case SessionOverrideType.extra:
        return _chip('إضافية', t.brand, t.brand.withValues(alpha: 0.12));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final barColor = totalCount == 0
        ? t.inkFaint
        : attendanceRate >= 0.8
            ? t.positive
            : attendanceRate >= 0.5
                ? t.caution
                : t.danger;
    final fill = barColor == t.caution ? t.cautionBar : barColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: AppPanel(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(
            AppSpace.md, AppSpace.md, AppSpace.sm, AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم المجموعة بيظهر كامل دايمًا (بدون قص) ولو طويل بيلف سطر
            // تاني؛ الميعاد والشارات تحته في Wrap عشان ما تتزنقش.
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(Icons.groups_rounded, size: 20, color: t.brand),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.title.copyWith(color: t.ink)),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (sessionTime != null)
                          Text(sessionTime!,
                              style:
                                  AppType.caption.copyWith(color: t.inkSoft)),
                        Builder(builder: (context) {
                          final remaining = controller.remainingSessionTime(
                              group, DateTime.now());
                          if (remaining == null) return const SizedBox.shrink();
                          final mins = remaining.inMinutes;
                          final label = mins >= 60
                              ? '${mins ~/ 60}س ${mins % 60}د متبقية'
                              : '$mins د متبقية';
                          return _chip(label, t.caution, t.cautionSoft);
                        }),
                        if (lateCount > 0)
                          _chip('$lateCount متأخر', t.caution, t.cautionSoft),
                        if (overrideType != null)
                          _overrideChip(t, overrideType!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$presentCount',
                      style: AppType.figure.copyWith(color: barColor)),
                  Text('من $totalCount',
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                ],
              ),
              if (onDetails != null)
                IconButton(
                  tooltip: 'تفاصيل الحصة',
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon:
                      Icon(Icons.fact_check_outlined, size: 22, color: t.brand),
                  onPressed: onDetails,
                )
              else
                Icon(Icons.chevron_left_rounded, color: t.inkFaint),
            ]),
            const SizedBox(height: AppSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: LinearProgressIndicator(
                value: totalCount == 0 ? 0 : attendanceRate.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: t.line,
                valueColor: AlwaysStoppedAnimation<Color>(fill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── موديل تسجيل حضور مجموعة واحدة ────────────────────────────────────────
// نفس نمط Dialog+ConstrainedBox المستخدم بالفعل في showAddStudentSheet
// (lib/widgets/add_student_sheet.dart) — راجع القرار 5 في research.md.
Future<void> showAttendanceSheet(
  BuildContext context, {
  required Group group,
  required DateTime selectedDay,
  required StudentController studentCtrl,
  required AttendanceController controller,
  required HomeworkController homeworkCtrl,
  required bool alreadySentReport,
  required VoidCallback onReportSent,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width * 0.04,
          vertical: size.height * 0.03,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: size.width * 0.92,
            maxWidth: size.width * 0.92,
            maxHeight: size.height * 0.94,
          ),
          child: _AttendanceSheet(
            group: group,
            selectedDay: selectedDay,
            studentCtrl: studentCtrl,
            controller: controller,
            homeworkCtrl: homeworkCtrl,
            alreadySentReport: alreadySentReport,
            onReportSent: onReportSent,
          ),
        ),
      );
    },
  );
}

class _AttendanceSheet extends StatefulWidget {
  final Group group;
  final DateTime selectedDay;
  final StudentController studentCtrl;
  final AttendanceController controller;
  final HomeworkController homeworkCtrl;
  final bool alreadySentReport;
  final VoidCallback onReportSent;

  const _AttendanceSheet({
    required this.group,
    required this.selectedDay,
    required this.studentCtrl,
    required this.controller,
    required this.homeworkCtrl,
    required this.alreadySentReport,
    required this.onReportSent,
  });

  @override
  State<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<_AttendanceSheet> {
  // بحث سريع بالاسم داخل طلاب هذه المجموعة فقط (منقول من التكرار الأول).
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ترتيب قائمة الطلاب داخل الموديل — نفس معيار الترتيب المستخدم في
  // شاشة الطلاب/تفاصيل المجموعة (StudentSortBar)، عشان المدرس يقدر
  // يرتّب حسب حالة الدفع/نسبة الحضور وهو بيسجّل الحضور مباشرة بدل ما
  // يضطر يفتح شاشة تانية.
  StudentSort _sortBy = StudentSort.name;
  bool _sortAscending = true;
  final PaymentController _payCtrl = Get.isRegistered<PaymentController>()
      ? Get.find<PaymentController>()
      : Get.put(PaymentController());

  void _onSortTap(StudentSort sort) {
    setState(() {
      if (_sortBy == sort) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sort;
        _sortAscending = true;
      }
    });
  }

  // حالة محلية عشان زر إرسال التقرير يتغيّر شكله فورًا جوه الموديل، من غير
  // ما يستني إعادة بناء الأب (اللي هيحصل برضه عبر onReportSent).
  late bool _reportSent;

  // spec 020 — الطلاب اللي اتنده عليهم عشوائيًا في فتح الشيت ده. in-memory،
  // بيتصفّر لما الشيت يتقفل (State جديد كل مرة). بالـid مش الاسم — عشان
  // لو فيه طالبين بنفس الاسم كل واحد ياخد دوره لوحده.
  final Set<int> _calledIds = {};

  void _pickRandomStudent(
      List<Student> groupStudents, Map<int, String> statusMap) {
    final withId = groupStudents.where((s) => s.id != null).toList();
    if (withId.isEmpty) return;
    final present = withId
        .where((s) => attendanceCountsAsPresent(statusMap[s.id]))
        .toList();
    final pool = present.isNotEmpty ? present : withId;
    final poolIds = pool.map((s) => s.id).toSet();

    // شيل من "المتنادى عليهم" أي طالب مش في الـpool الحالي (اتغيّر الحضور).
    _calledIds.removeWhere((id) => !poolIds.contains(id));

    var eligible = pool.where((s) => !_calledIds.contains(s.id)).toList();
    bool cycleReset = false;
    if (eligible.isEmpty) {
      _calledIds.clear();
      eligible = pool.toList();
      cycleReset = pool.length > 1;
    }
    if (eligible.isEmpty) return;

    final pick = eligible[math.Random().nextInt(eligible.length)];
    _calledIds.add(pick.id!);

    final remaining = pool.length - _calledIds.length; // الفاضل في الدورة

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RandomPickDialog(
        shuffleNames: eligible.map((s) => s.name).toList(),
        finalName: pick.name,
        remainingInCycle: remaining,
        cycleSize: pool.length,
        cycleReset: cycleReset,
        onAgain: () => _pickRandomStudent(groupStudents, statusMap),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _reportSent = widget.alreadySentReport;
    if (_payCtrl.payments.isEmpty) _payCtrl.loadPayments();
    _loadGroupRecitationMax();
  }

  /// آخر درجة عظمى اتحفظت للمجموعة من قائمة التسميع (إعداد محلي اختياري).
  int? _savedGroupMax;
  Future<void> _loadGroupRecitationMax() async {
    final id = widget.group.id;
    if (id == null) return;
    try {
      final v = await DatabaseService().getSetting(recitationGroupMaxKey(id));
      final n = int.tryParse(v ?? '');
      if (n != null && mounted) setState(() => _savedGroupMax = n);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// اختيار طالب من أي مجموعة تانية كضيف في حصة [group] يوم [day].
  Future<void> _pickGuest(BuildContext context, Group group, DateTime day,
      Set<int> groupIds, Set<int> guestIds) async {
    final t = context.tokens;
    final groups = Get.isRegistered<GroupController>()
        ? Get.find<GroupController>().groups
        : <Group>[];
    final candidates = widget.studentCtrl.students
        .where((s) =>
            s.id != null &&
            s.groupId != group.id &&
            !groupIds.contains(s.id) &&
            !guestIds.contains(s.id) &&
            !s.isArchived)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final picked = await showDialog<Student>(
      context: context,
      builder: (ctx) {
        final q = TextEditingController();
        return StatefulBuilder(builder: (ctx, setSt) {
          final text = q.text.trim().toLowerCase();
          final list = text.isEmpty
              ? candidates
              : candidates
                  .where((s) =>
                      s.name.toLowerCase().contains(text) ||
                      s.code.toLowerCase().contains(text))
                  .toList();
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.panel)),
            title: Text('إضافة ضيف للحصة',
                style: AppType.title.copyWith(color: t.ink)),
            content: SizedBox(
              width: 360,
              height: 380,
              child: Column(children: [
                Text(
                    'طالب من مجموعة تانية بيحضر الحصة دي. حضوره بيتسجّل على سجله من غير ما تتضاف حصة لمجموعته الأصلية.',
                    style: AppType.caption.copyWith(color: t.inkSoft)),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: q,
                  autofocus: true,
                  onChanged: (_) => setSt(() {}),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الكود',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control)),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text('مفيش طلاب مطابقين',
                              style: AppType.body.copyWith(color: t.inkSoft)))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final s = list[i];
                            final g = groups
                                .firstWhereOrNull((x) => x.id == s.groupId);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(s.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.label
                                      .copyWith(fontSize: 13, color: t.ink)),
                              subtitle: Text('${s.code} · ${g?.name ?? "—"}',
                                  style: AppType.caption
                                      .copyWith(color: t.inkSoft)),
                              onTap: () => Navigator.of(ctx).pop(s),
                            );
                          },
                        ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء')),
            ],
          );
        });
      },
    );
    if (picked == null || picked.id == null || group.id == null) return;
    try {
      await widget.controller.addGuest(picked.id!, group.id!, day);
      ToastHelper.success('اتضاف ${picked.name} كضيف في الحصة');
    } catch (_) {
      ToastHelper.error('حدث خطأ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // ألوان الحالات فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;

    // Obx بيغلّف كل حساب المجموعة عشان يبقى تفاعلي داخل الموديل (الموديل
    // مش جزء من شجرة _RegisterTab، فمحتاج مصدر تفاعلية خاص بيه).
    return Obx(() {
      final group = widget.group;
      final selectedDay = widget.selectedDay;
      final controller = widget.controller;
      final homeworkCtrl = widget.homeworkCtrl;

      final groupStudents = widget.studentCtrl.students
          .where((s) => s.groupId == group.id)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final dayStart =
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      final dayEnd = DateTime(
          selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59);
      final dayRecords = controller.attendance
          .where((a) => !a.date.isBefore(dayStart) && !a.date.isAfter(dayEnd));
      final Map<int, String> statusMap = {
        for (final a in dayRecords) a.studentId: a.status,
      };
      // إظهار/إخفاء الواجب والتسميع والتفاعل (من الإعدادات).
      final cfg = Get.find<SettingsController>();
      final showHomework = cfg.showHomework.value;
      final showRecitation = cfg.showRecitation.value;
      final showInteraction = cfg.showInteraction.value;
      // نفس مقياس درجات المجموعة اللي في قائمة التسميع (مش القيمة العامة بس).
      final groupIds = groupStudents.map((s) => s.id).toSet();
      final scaleRec = dayRecords
          .where((a) =>
              groupIds.contains(a.studentId) && recitationGradeOf(a) != null)
          .firstOrNull;
      final recitationMaxNow = resolveGroupRecitationMax(
          recordMax: scaleRec == null ? null : recitationMaxOf(scaleRec),
          savedMax: _savedGroupMax,
          settingsMax: cfg.recitationMax.value);
      final hasSecondTab = showHomework || showRecitation;
      // spec 040 — تفاعل الطالب لنفس اليوم.
      final Map<int, (int, int)?> recitationMap = {
        for (final a in dayRecords)
          a.studentId: recitationGradeOf(a) == null
              ? null
              : (recitationGradeOf(a)!, recitationMaxOf(a)),
      };
      final Map<int, String?> interactionMap = {
        for (final a in dayRecords) a.studentId: a.interaction,
      };

      // ضيوف الحصة دي: طلاب من مجموعات تانية سجلنا لهم حضور اليوم بوسم الضيف
      // (حصة تعويضية/بديلة) — بيظهروا هنا بنفس أدوات الحضور والواجب والتسميع.
      final guestIdSet = <int>{
        for (final a in dayRecords)
          if (group.id != null && isGuestOfGroup(a, group.id!)) a.studentId
      };
      final guestStudents = widget.studentCtrl.students
          .where((s) =>
              s.id != null &&
              guestIdSet.contains(s.id) &&
              s.groupId != group.id)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final allGroups = Get.isRegistered<GroupController>()
          ? Get.find<GroupController>().groups
          : <Group>[];
      String guestLabelOf(Student s) {
        final g = allGroups.firstWhereOrNull((x) => x.id == s.groupId);
        return g == null ? 'ضيف' : 'ضيف من ${g.name}';
      }

      final presentCount = groupStudents
          .where((s) => attendanceCountsAsPresent(statusMap[s.id]))
          .length;
      final lateCount = groupStudents
          .where((s) =>
              normalizeAttendanceStatus(statusMap[s.id]) == ATTENDANCE_LATE)
          .length;
      final absentCount = groupStudents
          .where((s) =>
              normalizeAttendanceStatus(statusMap[s.id]) == ATTENDANCE_ABSENT)
          .length;
      final totalCount = groupStudents.length;
      final attendanceRate = totalCount > 0 ? presentCount / totalCount : 0.0;
      final barColor = totalCount == 0
          ? t.boardInkSoft
          : attendanceRate >= 0.8
              ? on.positive
              : attendanceRate >= 0.5
                  ? t.chalk
                  : on.danger;

      final q = _searchQuery.trim().toLowerCase();
      final filteredStudents = q.isEmpty
          ? groupStudents
          : groupStudents
              .where((s) => s.name.toLowerCase().contains(q))
              .toList();
      final visibleStudents = sortStudents(
        students: filteredStudents,
        sortBy: _sortBy,
        ascending: _sortAscending,
        groupOf: (_) => group,
        allAttendance: controller.attendance,
        allPayments: _payCtrl.payments,
      );

      final visibleGuests = q.isEmpty
          ? guestStudents
          : guestStudents
              .where((s) => s.name.toLowerCase().contains(q))
              .toList();

      final sessionTime =
          controller.sessionTimeForGroupOnDay(group, selectedDay);
      final cancelled =
          controller.sessionOverrideFor(group, selectedDay)?.type ==
              SessionOverrideType.cancelled;
      final remaining = controller.remainingSessionTime(group, DateTime.now());
      final allPresent = totalCount > 0 &&
          groupStudents.every((s) => statusMap[s.id] == ATTENDANCE_PRESENT);

      Widget attendanceRow(Student s, {bool guest = false}) =>
          _StudentAttendanceChip(
            student: s,
            guestLabel: guest ? guestLabelOf(s) : null,
            onRemoveGuest: guest && group.id != null
                ? () => controller.removeGuest(s.id!, group.id!, selectedDay)
                : null,
            status: statusMap[s.id],
            interaction: interactionMap[s.id],
            showInteraction: showInteraction,
            // مفيش Obx هنا — الأب (_AttendanceSheet.build) ملفوف في Obx
            // بيقرا controller.attendance، فأي تبديل بيعيد بناء الصف.
            onSelect: (newStatus) async {
              try {
                await controller.setAttendanceStatus(
                    s.id!, selectedDay, newStatus);
              } catch (_) {
                ToastHelper.error('حدث خطأ');
                return;
              }
              // غائب = لا واجب: امسح سجل الواجب لنفس اليوم (spec 010).
              // "متأخر" مش غياب → الواجب بيفضل.
              if (newStatus == ATTENDANCE_ABSENT) {
                await homeworkCtrl.clearHomework(s.id!, selectedDay);
              }
            },
            onInteractionSelect: (newInteraction) =>
                controller.setInteraction(s.id!, selectedDay, newInteraction),
          );

      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.board),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // رأس السبورة: اسم المجموعة (كامل دايمًا، بيلف على سطرين لو
            // طويل) + قائمة الحصة + إغلاق، وتحته الميعاد والنسبة والأرقام.
            Container(
              color: t.board,
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.lg, AppSpace.xs, AppSpace.xs, AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpace.xs),
                        child: Text(group.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.title
                                .copyWith(fontSize: 18, color: t.boardInk)),
                      ),
                    ),
                    IconTheme(
                      data: IconThemeData(color: t.boardInk),
                      child: SessionOverrideMenuButton(
                        group: group,
                        day: selectedDay,
                        attCtrl: controller,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: t.boardInk,
                      tooltip: 'إغلاق',
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ]),
                  if (!cancelled) ...[
                    // ميعاد الحصة + العداد التنازلي — Wrap عشان لو المساحة
                    // ضاقت الشارات تنزل سطر تاني بدل overflow.
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          end: AppSpace.md, bottom: AppSpace.sm),
                      child: Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (sessionTime != null)
                            Text(sessionTime,
                                style: AppType.caption
                                    .copyWith(color: t.boardInkSoft)),
                          if (remaining != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.sm, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.chalk,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.chip),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_outlined,
                                        size: 14, color: t.onChalk),
                                    const SizedBox(width: AppSpace.xs),
                                    Text(
                                        remaining.inMinutes >= 60
                                            ? '${remaining.inMinutes ~/ 60}س ${remaining.inMinutes % 60}د متبقية'
                                            : '${remaining.inMinutes} د متبقية',
                                        style: AppType.caption.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: t.onChalk)),
                                  ]),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(end: AppSpace.md),
                      child: Row(children: [
                        Expanded(
                            child: _InlineStat(
                                label: 'حاضر',
                                value: '$presentCount',
                                color: on.positive)),
                        if (lateCount > 0)
                          Expanded(
                              child: _InlineStat(
                                  label: 'متأخر',
                                  value: '$lateCount',
                                  color: t.chalk)),
                        Expanded(
                            child: _InlineStat(
                                label: 'غائب',
                                value: '$absentCount',
                                color: on.danger)),
                        Expanded(
                            child: _InlineStat(
                                label: 'الكل',
                                value: '$totalCount',
                                color: t.boardInk)),
                      ]),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(end: AppSpace.md),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        child: LinearProgressIndicator(
                          value: totalCount == 0
                              ? 0
                              : attendanceRate.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: t.boardLine,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // spec 032 — بانر حالة الاستثناء (ملغاة / تعويضية / إضافية)
            Builder(builder: (_) {
              final o = controller.sessionOverrideFor(group, selectedDay);
              return o == null
                  ? const SizedBox.shrink()
                  : SessionOverrideBanner(ovr: o);
            }),
            // spec 032 — حصة ملغاة: نخفي قائمة الطلاب ونعرض زر تراجع فقط
            // (منمنعش تسجيل حضور بالغلط على حصة اتلغت).
            if (cancelled)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(children: [
                  Icon(Icons.event_busy_rounded, size: 40, color: t.danger),
                  const SizedBox(height: AppSpace.md),
                  Text('الحصة اتلغت النهارده',
                      style: AppType.title.copyWith(color: t.ink)),
                  const SizedBox(height: AppSpace.xs),
                  Text('مفيش تسجيل حضور — ترجع تفتح الحصة من الزر ده',
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                  const SizedBox(height: AppSpace.lg),
                  FilledButton.icon(
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('رجّع الحصة'),
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () async {
                      final so = Get.find<SessionOverrideController>();
                      final o = so.overrideFor(group.id!, selectedDay);
                      if (o == null) return;
                      final done = await confirmUndoSessionCancel(context, o);
                      await controller.loadAttendance();
                      if (context.mounted && done) {
                        AppToast.info(context, 'رجعت الحصة');
                      }
                    },
                  ),
                ]),
              )
            else ...[
              // بحث سريع عن طالب داخل هذه المجموعة + ترتيب + اختيار عشوائي،
              // كلهم في صف واحد عشان القايمة ياخدوا أكبر مساحة.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
                child: Row(children: [
                  Expanded(
                    child: CustomSearchBar(
                      controller: _searchController,
                      hintText: 'ابحث عن طالب...',
                      onChanged: (v) => setState(() => _searchQuery = v),
                      onClear: () => setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      }),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  // ترتيب القايمة (نفس معايير StudentSortBar): الضغط على
                  // المعيار الحالي تاني بيعكس الاتجاه.
                  PopupMenuButton<StudentSort>(
                    tooltip: 'ترتيب الطلاب',
                    onSelected: _onSortTap,
                    itemBuilder: (_) => [
                      for (final sort in StudentSort.values)
                        PopupMenuItem(
                          value: sort,
                          child: Row(children: [
                            Icon(
                                sort == _sortBy
                                    ? (_sortAscending
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded)
                                    : Icons.sort_rounded,
                                size: 18,
                                color: sort == _sortBy ? t.brand : t.inkSoft),
                            const SizedBox(width: AppSpace.md),
                            Text(sort.label,
                                style: AppType.body.copyWith(
                                    fontWeight: sort == _sortBy
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                          ]),
                        ),
                    ],
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        border: Border.all(color: t.line),
                      ),
                      child: Icon(Icons.sort_rounded, color: t.inkSoft),
                    ),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  // spec 020 — اختيار طالب عشوائي للتسميع/السؤال أثناء الحصة
                  Tooltip(
                    message: 'اختيار طالب عشوائي',
                    child: Material(
                      color: groupStudents.isEmpty
                          ? t.line
                          : t.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: groupStudents.isEmpty
                            ? null
                            : () =>
                                _pickRandomStudent(groupStudents, statusMap),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.casino_rounded,
                              size: 22,
                              color:
                                  groupStudents.isEmpty ? t.inkFaint : t.brand),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              // تبويبان داخل الموديل: حضور | واجب (spec 010). يفتح على "حضور".
              // Expanded: التبويبات ياخدوا باقي ارتفاع الموديل مهما كان
              // حجم الرأس أو الخط.
              Expanded(
                child: DefaultTabController(
                  length: hasSecondTab ? 2 : 1,
                  child: Column(
                    children: [
                      if (hasSecondTab)
                        TabBar(
                          labelColor: t.brand,
                          unselectedLabelColor: t.inkSoft,
                          indicatorColor: t.brand,
                          dividerColor: t.line,
                          labelStyle: AppType.label,
                          unselectedLabelStyle: AppType.label
                              .copyWith(fontWeight: FontWeight.w400),
                          tabs: [
                            const Tab(text: 'حضور'),
                            // التسميع جوه تبويب الواجب؛ لو الواجب مخفي والتسميع
                            // ظاهر، التبويب بيتسمّى "تسميع".
                            Tab(text: showHomework ? 'واجب' : 'تسميع'),
                          ],
                        )
                      else
                        Divider(height: 1, thickness: 1, color: t.line),
                      Expanded(
                        child: TabBarView(children: [
                          // ── تبويب حضور ──────────────────────────────
                          SingleChildScrollView(
                            child: Column(children: [
                              // "تحضير الكل" + تطبيق تفاعل للكل + وسيلة إيضاح أزرار
                              // الحالة، في سطر واحد (بينزلوا سطر تاني لو الشاشة ضيقة).
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpace.md, 0, AppSpace.md, 0),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppSpace.sm,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () =>
                                          controller.markGroupAllPresent(
                                        groupStudents
                                            .map((s) => s.id!)
                                            .toList(),
                                        selectedDay,
                                      ),
                                      style: TextButton.styleFrom(
                                          minimumSize: const Size(48, 44),
                                          foregroundColor: allPresent
                                              ? t.inkSoft
                                              : t.positive),
                                      icon: Icon(
                                          allPresent
                                              ? Icons.remove_done_rounded
                                              : Icons.done_all_rounded,
                                          size: 20),
                                      label: Text(
                                          allPresent
                                              ? 'إلغاء تحضير الكل'
                                              : 'تحضير الكل',
                                          style: AppType.body.copyWith(
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    // طالب من مجموعة تانية بيحضر الحصة دي كضيف (تعويضية).
                                    TextButton.icon(
                                      onPressed: () => _pickGuest(
                                          context,
                                          group,
                                          selectedDay,
                                          groupStudents
                                              .map((s) => s.id)
                                              .whereType<int>()
                                              .toSet(),
                                          guestIdSet),
                                      style: TextButton.styleFrom(
                                          minimumSize: const Size(48, 44),
                                          foregroundColor: t.brand),
                                      icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 20),
                                      label: Text('إضافة ضيف',
                                          style: AppType.body.copyWith(
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    // spec 040 — تطبيق تفاعل واحد على كل
                                    // الطلاب المؤهَّلين (حاضر/متأخر) دفعة واحدة.
                                    if (showInteraction)
                                      PopupMenuButton<String>(
                                        tooltip: 'تطبيق تفاعل على الكل',
                                        onSelected: (value) async {
                                          final applied = await controller
                                              .markGroupInteraction(
                                            groupStudents
                                                .map((s) => s.id!)
                                                .toList(),
                                            selectedDay,
                                            value,
                                          );
                                          if (applied == 0) {
                                            ToastHelper.error(
                                                'لا يوجد طلاب حاضرين لتطبيق التفاعل عليهم');
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          STUDENT_INTERACTION_ACTIVE,
                                          STUDENT_INTERACTION_NEUTRAL,
                                          STUDENT_INTERACTION_DISENGAGED,
                                        ]
                                            .map((v) => PopupMenuItem(
                                                  value: v,
                                                  child: Text(
                                                      '${interactionEmoji(v)}  $v'),
                                                ))
                                            .toList(),
                                        child: SizedBox(
                                          height: 44,
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                    Icons
                                                        .emoji_emotions_rounded,
                                                    size: 20,
                                                    color: t.brand),
                                                const SizedBox(
                                                    width: AppSpace.xs),
                                                Text('تفاعل الكل',
                                                    style: AppType.body
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: t.brand)),
                                              ]),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (visibleStudents.isEmpty &&
                                  visibleGuests.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(AppSpace.lg),
                                  child: Text(
                                    'لا يوجد طلاب مطابقين في هذه المجموعة',
                                    textAlign: TextAlign.center,
                                    style: AppType.caption
                                        .copyWith(color: t.inkSoft),
                                  ),
                                )
                              else ...[
                                if (visibleStudents.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        AppSpace.sm,
                                        AppSpace.sm,
                                        AppSpace.sm,
                                        AppSpace.md),
                                    // لوحة واحدة بفواصل رفيعة بين الطلاب.
                                    child: AppPanel(
                                      padding: EdgeInsets.zero,
                                      child: Column(children: [
                                        for (var i = 0;
                                            i < visibleStudents.length;
                                            i++) ...[
                                          if (i > 0)
                                            Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: t.line),
                                          attendanceRow(visibleStudents[i]),
                                        ],
                                      ]),
                                    ),
                                  ),
                                if (visibleGuests.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        AppSpace.md,
                                        AppSpace.xs,
                                        AppSpace.md,
                                        AppSpace.xs),
                                    child: Row(children: [
                                      Icon(Icons.person_add_alt_1_rounded,
                                          size: 16, color: t.inkSoft),
                                      const SizedBox(width: AppSpace.xs),
                                      Text('ضيوف الحصة',
                                          style: AppType.label
                                              .copyWith(color: t.inkSoft)),
                                    ]),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        AppSpace.sm,
                                        0,
                                        AppSpace.sm,
                                        AppSpace.md),
                                    child: AppPanel(
                                      padding: EdgeInsets.zero,
                                      child: Column(children: [
                                        for (var i = 0;
                                            i < visibleGuests.length;
                                            i++) ...[
                                          if (i > 0)
                                            Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: t.line),
                                          attendanceRow(visibleGuests[i],
                                              guest: true),
                                        ],
                                      ]),
                                    ),
                                  ),
                                ],
                              ],
                              _buildReportButton(context, group, groupStudents,
                                  controller, homeworkCtrl, selectedDay),
                            ]),
                          ),
                          // ── تبويب واجب (+ التسميع) ──────────────────
                          if (hasSecondTab)
                            _HomeworkTabBody(
                              students: [...visibleStudents, ...visibleGuests],
                              statusMap: statusMap,
                              homeworkCtrl: homeworkCtrl,
                              selectedDay: selectedDay,
                              showHomework: showHomework,
                              showRecitation: showRecitation,
                              recitationMap: recitationMap,
                              recitationMaxNow: recitationMaxNow,
                              onRecitation: (id, v) => controller.setRecitation(
                                  id, selectedDay, v,
                                  groupMax: recitationMaxNow),
                              onOpenRecitationList: () =>
                                  Get.toNamed(ROUTE_RECITATION, arguments: {
                                'groupId': group.id,
                                'day': selectedDay,
                              }),
                            ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildReportButton(
    BuildContext context,
    Group group,
    List<Student> groupStudents,
    AttendanceController controller,
    HomeworkController homeworkCtrl,
    DateTime selectedDay,
  ) {
    // زرار إرسال تقرير واتساب — بيظهر بس لو الإعداد مفعّل من الإعدادات،
    // والتاريخ المعروض هو النهاردة فعلاً، وكل طلاب المجموعة ليهم حالة
    // حضور مسجّلة (مش وسط التسجيل).
    final settings = Get.find<SettingsController>();
    if (!settings.reportOnCompletionEnabled.value) {
      return const SizedBox.shrink();
    }
    final today = DateTime.now();
    final isToday = selectedDay.year == today.year &&
        selectedDay.month == today.month &&
        selectedDay.day == today.day;
    if (!isToday) return const SizedBox.shrink();
    if (!controller.isAttendanceCompleteForGroupToday(group, groupStudents)) {
      return const SizedBox.shrink();
    }
    final t = context.tokens;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
      child: Material(
        color: t.positiveSoft,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: t.positive.withValues(alpha: 0.4)),
        ),
        child: InkWell(
          onTap: () => _showSendReportConfirm(
              context, group, groupStudents, controller, homeworkCtrl,
              onSent: () {
            setState(() => _reportSent = true);
            widget.onReportSent();
          }),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md, vertical: AppSpace.sm),
              child: Row(children: [
                Icon(
                    _reportSent
                        ? Icons.check_circle_rounded
                        : Icons.chat_rounded,
                    size: 20,
                    color: t.positive),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                      _reportSent
                          ? 'تم إرسال التقرير — اضغط لإعادة الإرسال'
                          : 'إرسال تقرير واتساب لأولياء الأمور',
                      style: AppType.body.copyWith(
                          fontWeight: FontWeight.w700, color: t.positive)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── spec 020 — حوار "اختيار طالب عشوائي" ──────────────────────────────────
class _RandomPickDialog extends StatefulWidget {
  final List<String> shuffleNames; // أسماء الدورة الحالية (للخلط)
  final String finalName;
  final int remainingInCycle; // كام فاضل قبل ما الدورة تخلص
  final int cycleSize; // إجمالي المجموعة/الحاضرين في الدورة
  final bool cycleReset; // الدورة اتصفّرت لتوها (كله اتنده عليه)
  final VoidCallback onAgain;
  const _RandomPickDialog({
    required this.shuffleNames,
    required this.finalName,
    required this.remainingInCycle,
    required this.cycleSize,
    required this.cycleReset,
    required this.onAgain,
  });

  @override
  State<_RandomPickDialog> createState() => _RandomPickDialogState();
}

class _RandomPickDialogState extends State<_RandomPickDialog> {
  late String _shown = widget.finalName;
  Timer? _shuffle;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    final names = widget.shuffleNames.length > 1
        ? widget.shuffleNames
        : [widget.finalName];
    if (names.length > 1) {
      final rnd = math.Random();
      _shuffle = Timer.periodic(const Duration(milliseconds: 55), (_) {
        if (!mounted) return;
        setState(() => _shown = names[rnd.nextInt(names.length)]);
      });
      Timer(const Duration(milliseconds: 900), () {
        _shuffle?.cancel();
        if (!mounted) return;
        setState(() {
          _shown = widget.finalName;
          _settled = true;
        });
      });
    } else {
      _settled = true;
    }
  }

  @override
  void dispose() {
    _shuffle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // نص التقدّم: كام اتنده عليهم من الدورة
    final done = widget.cycleSize - widget.remainingInCycle;
    final progress = widget.cycleSize <= 1
        ? null
        : widget.remainingInCycle <= 0
            ? 'آخر واحد في الدورة'
            : 'اتنده على $done من ${widget.cycleSize} · فاضل ${widget.remainingInCycle}';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_settled && widget.cycleReset)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('🔄 اتنده على الكل — دورة جديدة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981))),
            ),
          const Text('🎯', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(_settled ? 'الدور على' : 'بنختار...',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 120),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: _settled ? 30 : 22,
              color: _settled
                  ? AppTheme.primaryColor
                  : cs.onSurface.withValues(alpha: 0.4),
            ),
            child: Text(_shown, textAlign: TextAlign.center),
          ),
          if (_settled && progress != null) ...[
            const SizedBox(height: 10),
            Text(progress,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5))),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onAgain();
          },
          child:
              const Text('اختيار تاني', style: TextStyle(fontFamily: 'Cairo')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('تم', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

// ── إرسال تقرير واتساب لأولياء الأمور بعد اكتمال الحضور ─────────────────────
// نفس نمط الإرسال الجماعي الموجود أصلاً في settings_page.dart: رابط
// wa.me لكل ولي أمر، بيُفتح واحد ورا التاني بعد ما التطبيق يرجع من
// الخلفية (المستخدم يرجع من واتساب لحد ما التطبيق يفتح تاني).

Future<void> _showSendReportConfirm(
  BuildContext context,
  Group group,
  List<Student> students,
  AttendanceController controller,
  HomeworkController homeworkCtrl, {
  required VoidCallback onSent,
}) async {
  final selectedDay = DateTime.now();
  final withPhone = <Student>[];
  final skipped = <Student>[];
  for (final s in students) {
    final hasContact = (s.guardianPhone?.trim().isNotEmpty ?? false) ||
        (s.guardianWhatsapp?.trim().isNotEmpty ?? false);
    if (hasContact) {
      withPhone.add(s);
    } else {
      skipped.add(s);
    }
  }

  if (withPhone.isEmpty) {
    if (context.mounted) {
      AppToast.error(
          context, 'مفيش أي طالب في المجموعة عنده رقم ولي أمر مسجّل');
    }
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('إرسال تقرير واتساب؟'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هيتبعت تقرير حضور وواجب النهاردة لـ ${withPhone.length} '
                'ولي أمر في مجموعة "${group.name}".'),
            if (skipped.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                  '${skipped.length} طالب هيتم تخطّيهم (مفيش رقم ولي أمر): '
                  '${skipped.map((s) => s.name).join('، ')}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.orange.shade800)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إرسال')),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  final settings = Get.find<SettingsController>();
  final countryDial = settings.countryDial.value;
  final teacherName = settings.teacherFullName.value.trim();
  final teacherSpecialization = settings.teacherSpecialization.value.trim();

  for (final s in withPhone) {
    final todayRec = controller.attendance.firstWhereOrNull((a) =>
        a.studentId == s.id &&
        a.date.year == selectedDay.year &&
        a.date.month == selectedDay.month &&
        a.date.day == selectedDay.day);
    final attStatus = todayRec?.status;
    if (attStatus == null) continue; // احتياطي: مفروض مستحيل لو الزرار ظاهر
    final hwStatus = homeworkCtrl.statusFor(s.id!, selectedDay);
    final message = controller.buildGuardianReportMessage(
      student: s,
      attendanceStatus: attStatus,
      homeworkStatus: hwStatus,
      recitation: settings.showRecitation.value && todayRec != null
          ? recitationGradeOf(todayRec)
          : null,
      recitationMax:
          todayRec == null ? kRecitationDefaultMax : recitationMaxOf(todayRec),
      includeHomework: settings.showHomework.value,
      interaction:
          settings.showInteraction.value ? todayRec?.interaction : null,
      teacherName: teacherName,
      teacherSpecialization: teacherSpecialization,
    );
    if (!context.mounted) break;
    await launchGuardianWhatsapp(
      context: context,
      phone: s.guardianPhone,
      whatsapp: s.guardianWhatsapp,
      message: message,
      dialCode: countryDial,
    );
    await _atWaitForResume();
  }
  onSent();
}

class _ATResumeObserver extends WidgetsBindingObserver {
  final void Function() onResume;
  _ATResumeObserver(this.onResume);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

Future<void> _atWaitForResume() {
  final c = Completer<void>();
  late _ATResumeObserver obs;
  obs = _ATResumeObserver(() {
    WidgetsBinding.instance.removeObserver(obs);
    if (!c.isCompleted) c.complete();
  });
  WidgetsBinding.instance.addObserver(obs);
  return c.future;
}

// ── بطاقة الطالب الكبيرة ────────────────────────────────────────────────────

/// رقم + اسمه في سطر واحد فوق السبورة (حاضر 17) — بديل BoardStat المكدّس
/// لما المساحة الرأسية غالية (موديل تسجيل الحضور).
class _InlineStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InlineStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: AppType.title.copyWith(fontSize: 20, color: color)),
        const SizedBox(width: AppSpace.xs),
        Text(label, style: AppType.caption.copyWith(color: t.boardInkSoft)),
      ]),
    );
  }
}

class _StudentAttendanceChip extends StatelessWidget {
  final Student student;
  final String? status;
  // onSelect(status) → يسجّل الحالة؛ onSelect(null) → يمسح السجل (spec 011).
  final ValueChanged<String?> onSelect;
  // spec 040 — تفاعل الطالب (نشيط/عادي/غير متفاعل). null لو مفيش تفاعل
  // أو الحالة غير مؤهَّلة (canRecordInteraction == false).
  final String? interaction;
  final ValueChanged<String?> onInteractionSelect;
  // إعداد "تفاعل الطالب" (إظهار/إخفاء صف التفاعل).
  final bool showInteraction;
  // لو الطالب ضيف على الحصة (من مجموعة تانية): نص الشارة، وإزالته من الحصة.
  final String? guestLabel;
  final VoidCallback? onRemoveGuest;

  const _StudentAttendanceChip({
    required this.student,
    required this.status,
    required this.onSelect,
    required this.interaction,
    required this.onInteractionSelect,
    required this.showInteraction,
    this.guestLabel,
    this.onRemoveGuest,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final norm = normalizeAttendanceStatus(status);
    final marked = norm != null;
    final ink = _statusInk(t, norm);

    // صف واحد لكل طالب: شريط حالة رفيع + اسم + 3 أزرار أيقونات. شريط
    // الحالة بدل مربع الحرف عشان الاسم ياخد المساحة. التفاعل بيظهر تحت
    // الاسم للحاضر/المتأخر بس، فباقي الصفوف تفضل بارتفاع صف واحد.
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md, vertical: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: marked ? ink : t.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    student.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(fontSize: 13, color: t.ink),
                  ),
                  // تنبيه متأخر في الدفع (spec 029)
                  OverdueWarningFor(student: student, compact: true),
                  if (guestLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(children: [
                        Icon(Icons.person_add_alt_1_rounded,
                            size: 13, color: t.brand),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(guestLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(
                                  color: t.brand, fontWeight: FontWeight.w700)),
                        ),
                        if (onRemoveGuest != null)
                          InkWell(
                            onTap: onRemoveGuest,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Text('إزالة',
                                  style: AppType.caption.copyWith(
                                      color: t.danger,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            AppStatusPicker(
              dense: true,
              value: norm,
              subject: student.name,
              onSelect: onSelect,
              items: [
                AppSegmentItem(ATTENDANCE_PRESENT, 'حاضر', Icons.check_rounded,
                    t.positive),
                AppSegmentItem(ATTENDANCE_LATE, 'متأخر', Icons.schedule_rounded,
                    t.caution),
                AppSegmentItem(
                    ATTENDANCE_ABSENT, 'غائب', Icons.close_rounded, t.danger),
              ],
            ),
          ]),
          if (showInteraction && canRecordInteraction(norm))
            Padding(
              padding:
                  const EdgeInsetsDirectional.only(start: 14, top: AppSpace.xs),
              child: _InteractionRow(
                  interaction: normalizeInteraction(interaction),
                  onSelect: onInteractionSelect),
            ),
        ],
      ),
    );
  }
}

// صف تفاعل الطالب (spec 040) — 3 إيموجي، toggle زي حالة الحضور: ضغط
// المختار يمسحه، ضغط مختلف يستبدله.
class _InteractionRow extends StatelessWidget {
  final String? interaction;
  final ValueChanged<String?> onSelect;

  const _InteractionRow({required this.interaction, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget btn(String value) {
      final selected = interaction == value;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: AppSpace.xs),
        child: Tooltip(
          message: value,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            onTap: () => onSelect(selected ? null : value),
            child: Container(
              width: 38,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? t.brand.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: selected ? t.brand : t.line),
              ),
              child: Text(interactionEmoji(value),
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(STUDENT_INTERACTION_ACTIVE),
      btn(STUDENT_INTERACTION_NEUTRAL),
      btn(STUDENT_INTERACTION_DISENGAGED),
    ]);
  }
}

// صف درجة التسميع (spec 048) — الدرجة من 1 لحد [max] (الدرجة العظمى من
// الإعدادات). لحد 10: أزرار أرقام (toggle: ضغط المختار يمسحه). أكتر من 10:
// خانة بتفتح إدخال رقم. بيظهر للحاضر/المتأخر بس.
class _RecitationRow extends StatelessWidget {
  final (int, int)? recitation; // (الدرجة، الدرجة العظمى وقت تسجيلها)
  final int max; // الدرجة العظمى الحالية
  final ValueChanged<int?> onSelect;

  const _RecitationRow(
      {required this.recitation, required this.max, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = t.brand;
    final rec = recitation;
    // الدرجة المسجّلة بدرجة عظمى مختلفة عن الحالية: نعرضها كما هي ولا
    // نحدّدها في الأزرار (الضغط على زر بيستبدلها بدرجة على المقياس الجديد).
    final sameScale = rec != null && rec.$2 == max;
    final current = sameScale ? rec.$1 : null;
    final otherScale = rec != null && !sameScale;

    Widget label() => Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
          child: Text('تسميع',
              style: AppType.caption
                  .copyWith(fontWeight: FontWeight.w700, color: t.inkSoft)),
        );

    Widget oldBadge() => otherScale
        ? Container(
            margin: const EdgeInsetsDirectional.only(end: AppSpace.sm),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: accent),
            ),
            child: Text('${rec.$1}/${rec.$2}',
                style: AppType.caption
                    .copyWith(fontWeight: FontWeight.w700, color: accent)),
          )
        : const SizedBox.shrink();

    // مقياس كبير: خانة واحدة + إدخال رقم.
    if (max > 10) {
      return Row(children: [
        label(),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          onTap: () async {
            final v = await _askGrade(context, max, current);
            if (v == _kClear) {
              onSelect(null);
            } else if (v != null) {
              onSelect(v);
            }
          },
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current != null
                  ? accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: current != null ? accent : t.line),
            ),
            child: Text(
                current != null
                    ? '$current / $max'
                    : (otherScale
                        ? '${rec.$1}/${rec.$2}  ← $max'
                        : 'سجّل الدرجة (من $max)'),
                style: AppType.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: current != null ? accent : t.inkSoft)),
          ),
        ),
      ]);
    }

    return Row(children: [
      label(),
      oldBadge(),
      for (var v = kRecitationMin; v <= max; v++)
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            onTap: () => onSelect(current == v ? null : v),
            child: Container(
              height: 34,
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: current == v
                    ? accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: current == v ? accent : t.line),
              ),
              child: Text('$v',
                  style: AppType.caption.copyWith(
                      fontWeight:
                          current == v ? FontWeight.w700 : FontWeight.w400,
                      color: current == v ? accent : t.inkSoft)),
            ),
          ),
        ),
    ]);
  }
}

const int _kClear = -1;

/// إدخال درجة تسميع لمقياس كبير. بيرجّع الدرجة، أو [_kClear] للمسح، أو null
/// لو اتلغى.
Future<int?> _askGrade(BuildContext context, int max, int? current) {
  final c = TextEditingController(text: current?.toString() ?? '');
  String? err;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Text('درجة التسميع (من $max)',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(hintText: 'من 1 إلى $max', errorText: err),
          onSubmitted: (_) {
            final v = int.tryParse(c.text.trim());
            if (v != null && v >= kRecitationMin && v <= max) {
              Navigator.pop(ctx, v);
            } else {
              setSt(() => err = 'أدخل رقم من 1 إلى $max');
            }
          },
        ),
        actions: [
          if (current != null)
            TextButton(
                onPressed: () => Navigator.pop(ctx, _kClear),
                child: const Text('مسح')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(c.text.trim());
              if (v != null && v >= kRecitationMin && v <= max) {
                Navigator.pop(ctx, v);
              } else {
                setSt(() => err = 'أدخل رقم من 1 إلى $max');
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  تبويب "واجب" داخل موديل المجموعة (spec 010)
// ═══════════════════════════════════════════════════════════════════════════════

class _HomeworkTabBody extends StatelessWidget {
  final List<Student> students;
  final Map<int, String> statusMap; // حالة الحضور لكل طالب في اليوم
  final HomeworkController homeworkCtrl;
  final DateTime selectedDay;
  // الإعدادات: الواجب / التسميع (spec 048 — التسميع جوه هذا التبويب).
  final bool showHomework;
  final bool showRecitation;
  final Map<int, (int, int)?> recitationMap;
  final int recitationMaxNow;
  final void Function(int studentId, int? value) onRecitation;
  final VoidCallback onOpenRecitationList;

  const _HomeworkTabBody({
    required this.students,
    required this.statusMap,
    required this.homeworkCtrl,
    required this.selectedDay,
    required this.showHomework,
    required this.showRecitation,
    required this.recitationMap,
    required this.recitationMaxNow,
    required this.onRecitation,
    required this.onOpenRecitationList,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Text('لا يوجد طلاب مطابقين في هذه المجموعة',
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: t.inkSoft)),
        ),
      );
    }
    return Obx(() {
      homeworkCtrl.homework.length; // ربط Obx بالقائمة التفاعلية
      final presentIds = students
          .where((s) => statusMap[s.id] != ATTENDANCE_ABSENT)
          .map((s) => s.id!)
          .toList();
      final sum = homeworkCtrl.homeworkSummary(presentIds, selectedDay);
      final allDone = presentIds.isNotEmpty &&
          presentIds.every((id) =>
              normalizeHomeworkStatus(
                  homeworkCtrl.statusFor(id, selectedDay)) ==
              HOMEWORK_DONE);

      Widget miniCount(Color c, String label, int n) => Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpace.md),
            child: Tooltip(
              message: label,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: c, shape: BoxShape.circle)),
                const SizedBox(width: AppSpace.xs),
                Text('$n',
                    style: AppType.body
                        .copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              ]),
            ),
          );

      return SingleChildScrollView(
        child: Column(children: [
          // شريط ملخّص + زر جماعي (الواجب فقط)
          if (showHomework) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.md, AppSpace.sm, AppSpace.sm, AppSpace.xs),
              child: Row(children: [
                miniCount(t.positive, 'تم الحل', sum.done),
                miniCount(t.caution, 'ناقص', sum.partial),
                miniCount(t.danger, 'لم يُحل', sum.notDone),
                miniCount(t.inkFaint, 'غير مسجّل', sum.unset),
                const Spacer(),
                TextButton(
                  onPressed: presentIds.isEmpty
                      ? null
                      : () => homeworkCtrl.markGroupAllHomeworkDone(
                          presentIds, selectedDay),
                  style: TextButton.styleFrom(
                      foregroundColor: t.brand,
                      minimumSize: const Size(48, 44)),
                  child: Text(allDone ? 'إلغاء الكل' : 'الكل عمل',
                      style:
                          AppType.body.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ],
          if (showRecitation)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.md, AppSpace.sm, AppSpace.md, 0),
              child: Row(children: [
                Expanded(
                  child: Text('التسميع من $recitationMaxNow',
                      style: AppType.label.copyWith(color: t.ink)),
                ),
                TextButton.icon(
                  onPressed: onOpenRecitationList,
                  icon: const Icon(Icons.record_voice_over_rounded, size: 18),
                  label: const Text('قائمة التسميع'),
                  style: TextButton.styleFrom(
                      foregroundColor: t.brand,
                      minimumSize: const Size(48, 44)),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.sm, AppSpace.sm, AppSpace.sm, AppSpace.md),
            // لوحة واحدة بفواصل رفيعة بين الطلاب.
            child: AppPanel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < students.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
                  Builder(builder: (_) {
                    final s = students[i];
                    final absent = statusMap[s.id] == ATTENDANCE_ABSENT;
                    return _HomeworkStudentRow(
                      name: s.name,
                      absent: absent,
                      status: absent
                          ? null
                          : normalizeHomeworkStatus(
                              homeworkCtrl.statusFor(s.id!, selectedDay)),
                      onSelect: (st) => homeworkCtrl.setHomeworkStatus(
                          s.id!, selectedDay, st),
                      showHomework: showHomework,
                      showRecitation: showRecitation,
                      recitation: recitationMap[s.id],
                      recitationMaxNow: recitationMaxNow,
                      onRecitation: (v) => onRecitation(s.id!, v),
                    );
                  }),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

class _HomeworkStudentRow extends StatelessWidget {
  final String name;
  final bool absent;
  final String?
      status; // مطبّع: HOMEWORK_DONE / HOMEWORK_PARTIAL / HOMEWORK_NOT_DONE / null
  final ValueChanged<String?> onSelect;
  final bool showHomework;
  final bool showRecitation;
  final (int, int)? recitation; // (الدرجة، الدرجة العظمى وقت التسجيل)
  final int recitationMaxNow;
  final ValueChanged<int?> onRecitation;

  const _HomeworkStudentRow({
    required this.name,
    required this.absent,
    required this.status,
    required this.onSelect,
    required this.showHomework,
    required this.showRecitation,
    required this.recitation,
    required this.recitationMaxNow,
    required this.onRecitation,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = status == HOMEWORK_DONE
        ? t.positive
        : status == HOMEWORK_PARTIAL
            ? t.caution
            : status == HOMEWORK_NOT_DONE
                ? t.danger
                : null;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md, vertical: AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accent ?? t.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(
                    fontSize: 13, color: absent ? t.inkFaint : t.ink)),
          ),
          const SizedBox(width: AppSpace.sm),
          if (absent)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm, vertical: 2),
              decoration: BoxDecoration(
                color: t.line,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(showHomework ? 'غائب — لا واجب' : 'غائب — لا تسميع',
                  style: AppType.caption.copyWith(color: t.inkSoft)),
            )
          else if (showHomework)
            AppStatusPicker(
              dense: true,
              value: status,
              subject: name,
              onSelect: onSelect,
              items: [
                AppSegmentItem(
                    HOMEWORK_DONE, 'تم الحل', Icons.check_rounded, t.positive),
                AppSegmentItem(
                    HOMEWORK_PARTIAL, 'ناقص', Icons.remove_rounded, t.caution),
                AppSegmentItem(HOMEWORK_NOT_DONE, 'لم يُحل',
                    Icons.close_rounded, t.danger),
              ],
            ),
        ]),
        // spec 048 — درجة التسميع 1..10 (للحاضر/المتأخر)
        if (!absent && showRecitation) ...[
          const SizedBox(height: AppSpace.sm),
          _RecitationRow(
              recitation: recitation,
              max: recitationMaxNow,
              onSelect: onRecitation),
        ],
      ]),
    );
  }
}

// ── No sessions today ─────────────────────────────────────────────────────────

class _NoSessionsToday extends StatelessWidget {
  final List allGroups;
  final DateTime selectedDay;

  const _NoSessionsToday({required this.allGroups, required this.selectedDay});

  static const _weekdays = {
    1: 'الاثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
    7: 'الأحد',
  };

  static const _arDays = {
    'الاثنين': 1,
    'الثلاثاء': 2,
    'الأربعاء': 3,
    'الخميس': 4,
    'الجمعة': 5,
    'السبت': 6,
    'الأحد': 7,
  };

  String _scheduleSummary(dynamic g) {
    final s = g.schedule as String?;
    if (s == null || s.trim().isEmpty) return 'بدون جدول';
    final days = <String>{};
    for (final k in _arDays.keys) {
      if (s.contains(k)) days.add(k);
    }
    return days.isEmpty ? s : days.join('، ');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 48, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد حصص ${_weekdays[selectedDay.weekday] ?? ''}',
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'لم يُجدوَل أي مجموعة في هذا اليوم',
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showAddSessionOverrideFlow(
                context,
                groups: allGroups.whereType<Group>().toList(),
                day: selectedDay,
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('حصة تعويضية / إضافية',
                  style: TextStyle(fontFamily: 'Cairo')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text('جدول المجموعات',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.grey.shade600)),
                ]),
                const SizedBox(height: 10),
                ...allGroups.map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.groups_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(g.name as String,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                        Text(_scheduleSummary(g),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ]),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Tab 2 — السجل
// ═══════════════════════════════════════════════════════════════════════════════

class _RecordsTab extends StatefulWidget {
  final AttendanceController controller;
  final StudentController studentCtrl;
  final GroupController groupCtrl;

  const _RecordsTab({
    required this.controller,
    required this.studentCtrl,
    required this.groupCtrl,
  });

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = '';
  int? _groupFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Obx(() {
      final q = _searchCtrl.text.toLowerCase();
      final students = widget.studentCtrl.students;
      final groups = widget.groupCtrl.groups;
      final groupById = {for (final g in groups) g.id: g};

      final list = widget.controller.attendance.where((a) {
        if (_statusFilter.isNotEmpty && a.status != _statusFilter) return false;
        final s = students.firstWhereOrNull((st) => st.id == a.studentId);
        if (_groupFilter != null && s?.groupId != _groupFilter) return false;
        if (q.isNotEmpty && !(s?.name.toLowerCase().contains(q) ?? false))
          return false;
        return true;
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      // spec 047 — أحداث أرشفة/استعادة الطلاب بين السجلات (عرض فقط، مع
      // فلتر "الكل" بس، ومش داخلة في عدّاد السجلات).
      final events = widget.controller.archiveEvents.where((e) {
        final st = students.firstWhereOrNull((x) => x.id == e.studentId);
        if (st == null) return false;
        return archiveEventVisible(
          statusFilter: _statusFilter,
          query: q,
          studentName: st.name,
          groupFilter: _groupFilter,
          studentGroupId: st.groupId,
        );
      }).toList();
      final items = mergeAttendanceAndArchive(list, events);

      return Column(children: [
        // Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(
              child: CustomSearchBar(
                controller: _searchCtrl,
                hintText: 'ابحث باسم الطالب...',
                onChanged: (_) => setState(() {}),
                onClear: () {
                  _searchCtrl.clear();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            _FilterBtn(
              label: _groupFilter == null
                  ? 'المجموعة'
                  : groupById[_groupFilter]?.name ?? 'المجموعة',
              onTap: () => _showGroupSheet(context, groups),
            ),
          ]),
        ),
        // Status chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // Wrap بدل Row: مع الخط الكبير الشرائح بتنزل سطر تاني بدل overflow.
          child: Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final item in [
                ('الكل', ''),
                ('حاضر', ATTENDANCE_PRESENT),
                ('متأخر', ATTENDANCE_LATE),
                ('غائب', ATTENDANCE_ABSENT),
              ])
                _StatusChip(
                  label: item.$1,
                  selected: _statusFilter == item.$2,
                  color: item.$2 == ATTENDANCE_PRESENT
                      ? t.positive
                      : item.$2 == ATTENDANCE_LATE
                          ? t.caution
                          : item.$2 == ATTENDANCE_ABSENT
                              ? t.danger
                              : t.brand,
                  onTap: () => setState(() => _statusFilter = item.$2),
                ),
              Text('${list.length} سجل',
                  style: AppType.caption.copyWith(color: t.inkFaint)),
            ],
          ),
        ),
        // List
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.event_note,
                  title: 'لا توجد سجلات',
                  subtitle: 'عدّل الفلاتر أو سجّل حضوراً',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    if (item is ArchiveItem) {
                      final st = students.firstWhereOrNull(
                          (x) => x.id == item.event.studentId);
                      return AppPanel(
                        padding: EdgeInsets.zero,
                        child: ArchiveEventTile(
                            event: item.event, studentName: st?.name),
                      );
                    }
                    final att = (item as AttendanceItem).record;
                    final s = students
                        .firstWhereOrNull((st) => st.id == att.studentId);
                    final norm = normalizeAttendanceStatus(att.status);
                    final isLate = norm == ATTENDANCE_LATE;
                    final isPresent = attendanceCountsAsPresent(att.status);
                    final ink = _statusInk(t, norm);
                    final soft = _statusSoft(t, norm);
                    final groupName = groupById[s?.groupId]?.name;

                    return AppPanel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md, vertical: AppSpace.sm),
                      child: Row(children: [
                        // أيقونة الحالة
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: soft,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Icon(
                            isLate
                                ? Icons.schedule_rounded
                                : isPresent
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                            color: ink,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s?.name ?? 'طالب',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.label.copyWith(color: t.ink)),
                              if (groupName != null)
                                Text(groupName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.caption
                                        .copyWith(color: t.inkSoft)),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        // حالة الحضور + التاريخ
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.sm + 2,
                                  vertical: AppSpace.xs),
                              decoration: BoxDecoration(
                                color: soft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.chip),
                              ),
                              child: Text(att.status,
                                  style: AppType.caption.copyWith(
                                      color: ink, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              FormatHelper.formatDate(att.date),
                              style: AppType.caption.copyWith(color: t.inkSoft),
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'خيارات السجل',
                          icon: Icon(Icons.more_vert_rounded, color: t.inkSoft),
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 44, minHeight: 44),
                          onSelected: (v) {
                            if (!requireDeletePermission(context,
                                TeamModeService().canDeleteAttendanceNow)) {
                              return;
                            }
                            if (v == 'edit') {
                              _editAttendanceDate(context, att, s?.name);
                            } else {
                              custom_dialogs.ConfirmDeleteDialog.show(
                                context,
                                title: 'حذف السجل',
                                message:
                                    'هل تريد حذف سجل حضور ${s?.name ?? "الطالب"} '
                                    'بتاريخ ${FormatHelper.formatDate(att.date)}؟',
                                onConfirm: () =>
                                    widget.controller.deleteAttendance(att.id!),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_calendar_outlined,
                                    size: 20, color: t.inkSoft),
                                const SizedBox(width: AppSpace.md),
                                Text('تعديل التاريخ', style: AppType.body),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded,
                                    size: 20, color: t.danger),
                                const SizedBox(width: AppSpace.md),
                                Text('حذف',
                                    style:
                                        AppType.body.copyWith(color: t.danger)),
                              ]),
                            ),
                          ],
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ]);
    });
  }

  Future<void> _editAttendanceDate(
      BuildContext context, Attendance att, String? studentName) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: att.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'اختر تاريخ الحضور الصحيح',
    );
    if (picked == null || !context.mounted) return;
    if (picked.year == att.date.year &&
        picked.month == att.date.month &&
        picked.day == att.date.day) {
      return;
    }

    final warning =
        await widget.controller.paidMonthWarning(att.studentId, att.date);
    if (!context.mounted) return;

    if (warning != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه', style: TextStyle(fontFamily: 'Cairo')),
          content: Text(warning, style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('متابعة التعديل',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!context.mounted) return;
    }

    final error = await widget.controller.editAttendanceDate(att, picked);
    if (error != null && context.mounted) {
      ToastHelper.error(error);
    }
  }

  void _showGroupSheet(BuildContext context, List<Group> groups) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => SafeArea(
          child: ListView(controller: scrollCtrl, children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(_groupFilter == null
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: const Text('كل المجموعات'),
              onTap: () {
                setState(() => _groupFilter = null);
                Get.back();
              },
            ),
            ...groups.map((g) => ListTile(
                  leading: Icon(_groupFilter == g.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off),
                  title: Text(g.name),
                  onTap: () {
                    setState(() => _groupFilter = g.id);
                    Get.back();
                  },
                )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Tab 3 — الإحصائيات
// ═══════════════════════════════════════════════════════════════════════════════

class _StatisticsTab extends StatefulWidget {
  final AttendanceController controller;
  final StudentController studentCtrl;
  final GroupController groupCtrl;

  const _StatisticsTab({
    required this.controller,
    required this.studentCtrl,
    required this.groupCtrl,
  });

  @override
  State<_StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<_StatisticsTab> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // ألوان الحالات فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;
    return Obx(() {
      final students = widget.studentCtrl.students;
      final groups = widget.groupCtrl.groups;

      final presentByStudent =
          widget.controller.getPresentCountByStudent(range: _range);
      final expectedPerGroup = widget.controller
          .getExpectedSessionsPerGroup(groups: groups, range: _range);

      final perStudent = students.map((s) {
        final present = presentByStudent[s.id ?? -1] ?? 0;
        final expected = expectedPerGroup[s.groupId] ?? 0;
        final percent = expected == 0 ? 0.0 : (present / expected) * 100.0;
        return _StudentStats(
            student: s, present: present, expected: expected, percent: percent);
      }).toList()
        ..sort((a, b) => a.percent.compareTo(b.percent));

      bool inRange(DateTime d) =>
          _range == null ||
          (!d.isBefore(_range!.start) && !d.isAfter(_range!.end));
      // "متأخر" يُحتسب حضورًا (spec 011)
      final rangePresent = widget.controller.attendance
          .where((a) => attendanceCountsAsPresent(a.status) && inRange(a.date))
          .length;
      final rangeLate = widget.controller.attendance
          .where((a) =>
              normalizeAttendanceStatus(a.status) == ATTENDANCE_LATE &&
              inRange(a.date))
          .length;
      final rangeAbsent = widget.controller.attendance
          .where((a) =>
              normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT &&
              inRange(a.date))
          .length;
      final total = rangePresent + rangeAbsent;
      final rate = total > 0 ? rangePresent / total : 0.0;

      final isCustomRange = _range != null &&
          !_isTodayRange(_range!) &&
          !_isThisWeekRange(_range!) &&
          !_isThisMonthRange(_range!);
      final rateColor = total == 0
          ? t.boardInkSoft
          : rate >= 0.8
              ? on.positive
              : rate >= 0.5
                  ? t.chalk
                  : on.danger;

      return Column(children: [
        // سبورة: فلتر الفترة وأرقامها (نفس سبورة تبويب التسجيل)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
          decoration: BoxDecoration(
            color: t.board,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.board)),
          ),
          child: Column(children: [
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                _BoardRangeChip(
                    label: 'الكل',
                    selected: _range == null,
                    onTap: () => setState(() => _range = null)),
                _BoardRangeChip(
                    label: 'اليوم',
                    selected: _range != null && _isTodayRange(_range!),
                    onTap: () => setState(() => _range = _todayRange())),
                _BoardRangeChip(
                    label: 'هذا الأسبوع',
                    selected: _range != null && _isThisWeekRange(_range!),
                    onTap: () => setState(() => _range = _thisWeekRange())),
                _BoardRangeChip(
                    label: 'هذا الشهر',
                    selected: _range != null && _isThisMonthRange(_range!),
                    onTap: () => setState(() => _range = _thisMonthRange())),
                _BoardRangeChip(
                  label: 'نطاق',
                  icon: Icons.date_range_rounded,
                  selected: isCustomRange,
                  onTap: () async {
                    final p = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      initialDateRange: _range,
                      helpText: 'اختر نطاقاً',
                      saveText: 'تأكيد',
                    );
                    if (p != null) setState(() => _range = _asFullDayRange(p));
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Row(children: [
              Expanded(
                  child: BoardStat(
                      label: 'حضور',
                      value: '$rangePresent',
                      color: on.positive)),
              if (rangeLate > 0)
                Expanded(
                    child: BoardStat(
                        label: 'متأخر', value: '$rangeLate', color: t.chalk)),
              Expanded(
                  child: BoardStat(
                      label: 'غياب', value: '$rangeAbsent', color: on.danger)),
              Expanded(
                  child: BoardStat(
                      label: 'نسبة الحضور',
                      value: '${(rate * 100).toStringAsFixed(0)}%',
                      color: rateColor)),
            ]),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('نسبة الحضور لكل طالب',
                style: AppType.title.copyWith(color: t.ink)),
          ),
        ),

        Expanded(
          child: perStudent.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  title: 'لا توجد بيانات',
                  subtitle: 'سجّل حضوراً أولاً',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: perStudent.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpace.sm),
                  itemBuilder: (ctx, i) {
                    final e = perStudent[i];
                    final ink = _percentInk(t, e.percent);
                    final soft = _percentSoft(t, e.percent);
                    final fill = ink == t.caution ? t.cautionBar : ink;

                    return AppPanel(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: soft,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.chip),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  e.student.name.isNotEmpty
                                      ? e.student.name[0]
                                      : '؟',
                                  style: AppType.label.copyWith(color: ink),
                                ),
                              ),
                              const SizedBox(width: AppSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.student.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.label
                                            .copyWith(color: t.ink)),
                                    Text('حضر ${e.present} من ${e.expected}',
                                        style: AppType.caption
                                            .copyWith(color: t.inkSoft)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpace.sm),
                              Text(
                                FormatHelper.formatPercentage(e.percent),
                                style: AppType.figure
                                    .copyWith(fontSize: 20, color: ink),
                              ),
                            ]),
                            const SizedBox(height: AppSpace.sm),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.chip),
                              child: LinearProgressIndicator(
                                value: e.expected == 0
                                    ? 0
                                    : (e.present / e.expected).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: t.line,
                                valueColor: AlwaysStoppedAnimation<Color>(fill),
                              ),
                            ),
                          ]),
                    );
                  },
                ),
        ),
      ]);
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Small reusable widgets
// ═══════════════════════════════════════════════════════════════════════════════

/// تاب نصه بيصغر لو الخط كبير، عشان التابات الأربعة تفضل ثابتة.
class _BoardTab extends StatelessWidget implements PreferredSizeWidget {
  final String label;
  const _BoardTab(this.label);

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StatusChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: selected ? color : t.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            // Row مش Center: Center كان بيمطّ الشريحة لعرض الشاشة جوه الـWrap.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: AppType.body.copyWith(
                        color: selected ? color : t.inkSoft,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FilterBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: t.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 150),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.group_outlined, size: 18, color: t.inkSoft),
              const SizedBox(width: AppSpace.xs + 2),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: t.inkSoft)),
              ),
              Icon(Icons.arrow_drop_down, size: 20, color: t.inkSoft),
            ]),
          ),
        ),
      ),
    );
  }
}

/// شريحة اختيار الفترة فوق السبورة: المختارة بلون الطباشير.
class _BoardRangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  const _BoardRangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.onChalk : t.boardInk;
    return Material(
      color: selected ? t.chalk : Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: selected ? BorderSide.none : BorderSide(color: t.boardLine),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: AppSpace.xs),
                ],
                Text(label,
                    style: AppType.body.copyWith(
                        color: fg,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _StudentStats {
  final Student student;
  final int present, expected;
  final double percent;
  _StudentStats(
      {required this.student,
      required this.present,
      required this.expected,
      required this.percent});
}

// ─── Date helpers ─────────────────────────────────────────────────────────────

DateTimeRange _todayRange() {
  final n = DateTime.now();
  return DateTimeRange(
    start: DateTime(n.year, n.month, n.day),
    end: DateTime(n.year, n.month, n.day, 23, 59, 59),
  );
}

DateTimeRange _thisWeekRange() {
  final n = DateTime.now();
  final start = n.subtract(Duration(days: n.weekday - 1));
  final ws = DateTime(start.year, start.month, start.day);
  final we = ws.add(const Duration(days: 6));
  return DateTimeRange(
    start: ws,
    end: DateTime(we.year, we.month, we.day, 23, 59, 59),
  );
}

DateTimeRange _thisMonthRange() {
  final n = DateTime.now();
  final s = DateTime(n.year, n.month, 1);
  final end =
      DateTime(n.year, n.month + 1, 1).subtract(const Duration(days: 1));
  return DateTimeRange(
    start: s,
    end: DateTime(end.year, end.month, end.day, 23, 59, 59),
  );
}

bool _isTodayRange(DateTimeRange r) {
  final t = _todayRange();
  return r.start.year == t.start.year &&
      r.start.month == t.start.month &&
      r.start.day == t.start.day;
}

bool _isThisWeekRange(DateTimeRange r) {
  final w = _thisWeekRange();
  return r.start == w.start && r.end == w.end;
}

bool _isThisMonthRange(DateTimeRange r) {
  final m = _thisMonthRange();
  return r.start == m.start && r.end == m.end;
}

DateTimeRange _asFullDayRange(DateTimeRange r) => DateTimeRange(
      start: DateTime(r.start.year, r.start.month, r.start.day),
      end: DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59),
    );

// ══════════════════════════════════════════════════════════════════
//  _AbsentTodayTab — غائبو اليوم مع إرسال رسالة واتساب لأولياء الأمور
// ══════════════════════════════════════════════════════════════════
class _AbsentEntry {
  final Student student;
  final String groupName;
  const _AbsentEntry({required this.student, required this.groupName});
}

class _AbsentTodayTab extends StatefulWidget {
  final AttendanceController controller;
  final StudentController studentCtrl;
  final GroupController groupCtrl;

  const _AbsentTodayTab({
    required this.controller,
    required this.studentCtrl,
    required this.groupCtrl,
  });

  @override
  State<_AbsentTodayTab> createState() => _AbsentTodayTabState();
}

class _AbsentTodayTabState extends State<_AbsentTodayTab> {
  final Set<int> _selected = {};
  final Set<int> _selectedLate = {};

  String _buildMessage(Student s, String groupName, String teacherName,
          String teacherSpecialization) =>
      buildAbsenceMessage(
        studentName: s.name,
        studentCode: s.code,
        groupName: groupName,
        date: DateTime.now(),
        teacherName: teacherName,
        teacherSpecialization: teacherSpecialization,
      );

  String _buildLateMessage(Student s, String groupName, String teacherName,
          String teacherSpecialization) =>
      buildLateMessage(
        studentName: s.name,
        studentCode: s.code,
        groupName: groupName,
        date: DateTime.now(),
        teacherName: teacherName,
        teacherSpecialization: teacherSpecialization,
      );

  Future<void> _sendWhatsapp(Student s, String groupName) async {
    final hasContact = (s.guardianPhone?.trim().isNotEmpty ?? false) ||
        (s.guardianWhatsapp?.trim().isNotEmpty ?? false);
    if (!hasContact) {
      AppToast.warning(context, 'لا يوجد رقم أو واتساب ولي أمر لـ ${s.name}');
      return;
    }
    final settings = Get.find<SettingsController>();
    final msg = _buildMessage(
        s,
        groupName,
        settings.teacherFullName.value.trim(),
        settings.teacherSpecialization.value.trim());
    await launchGuardianWhatsapp(
      context: context,
      phone: s.guardianPhone,
      whatsapp: s.guardianWhatsapp,
      message: msg,
      dialCode: settings.countryDial.value,
    );
  }

  Future<void> _sendLateWhatsapp(Student s, String groupName) async {
    final hasContact = (s.guardianPhone?.trim().isNotEmpty ?? false) ||
        (s.guardianWhatsapp?.trim().isNotEmpty ?? false);
    if (!hasContact) {
      AppToast.warning(context, 'لا يوجد رقم أو واتساب ولي أمر لـ ${s.name}');
      return;
    }
    final settings = Get.find<SettingsController>();
    final msg = _buildLateMessage(
        s,
        groupName,
        settings.teacherFullName.value.trim(),
        settings.teacherSpecialization.value.trim());
    await launchGuardianWhatsapp(
      context: context,
      phone: s.guardianPhone,
      whatsapp: s.guardianWhatsapp,
      message: msg,
      dialCode: settings.countryDial.value,
    );
  }

  Future<bool?> _confirmSendDialog(_AbsentEntry entry, int index, int total,
      {String label = 'غياب'}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إرسال $index من $total'),
        content: Text(
            'إرسال رسالة $label لولي أمر ${entry.student.name} (${entry.groupName})؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('إلغاء الكل'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تخطي'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendToSelected(List<_AbsentEntry> entries) async {
    final queue =
        entries.where((e) => _selected.contains(e.student.id)).toList();
    if (queue.isEmpty) return;

    final withPhone = queue
        .where((e) =>
            (e.student.guardianPhone ?? '').trim().isNotEmpty ||
            (e.student.guardianWhatsapp ?? '').trim().isNotEmpty)
        .toList();
    final withoutPhoneCount = queue.length - withPhone.length;

    if (withPhone.isEmpty) {
      AppToast.warning(context, 'لا يوجد أرقام أولياء أمور للطلاب المحددين');
      return;
    }

    for (var i = 0; i < withPhone.length; i++) {
      final entry = withPhone[i];
      final proceed = await _confirmSendDialog(entry, i + 1, withPhone.length);
      if (proceed == null) break;
      if (proceed) await _sendWhatsapp(entry.student, entry.groupName);
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(_selected.clear);
    AppToast.success(
      context,
      'تم الإرسال',
      subtitle: withoutPhoneCount > 0
          ? '$withoutPhoneCount طالب بدون رقم ولي أمر تم تخطيه'
          : null,
    );
  }

  Future<void> _sendLateToSelected(List<_AbsentEntry> lateEntries) async {
    final queue =
        lateEntries.where((e) => _selectedLate.contains(e.student.id)).toList();
    if (queue.isEmpty) return;

    final withPhone = queue
        .where((e) =>
            (e.student.guardianPhone ?? '').trim().isNotEmpty ||
            (e.student.guardianWhatsapp ?? '').trim().isNotEmpty)
        .toList();
    final withoutPhoneCount = queue.length - withPhone.length;

    if (withPhone.isEmpty) {
      AppToast.warning(context, 'لا يوجد أرقام أولياء أمور للطلاب المحددين');
      return;
    }

    for (var i = 0; i < withPhone.length; i++) {
      final entry = withPhone[i];
      final proceed = await _confirmSendDialog(entry, i + 1, withPhone.length,
          label: 'تأخير');
      if (proceed == null) break;
      if (proceed) await _sendLateWhatsapp(entry.student, entry.groupName);
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(_selectedLate.clear);
    AppToast.success(
      context,
      'تم الإرسال',
      subtitle: withoutPhoneCount > 0
          ? '$withoutPhoneCount طالب بدون رقم ولي أمر تم تخطيه'
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Obx(() {
      final students = widget.studentCtrl.students;
      final groups = widget.groupCtrl.groups;
      final groupById = {
        for (final g in groups)
          if (g.id != null) g.id!: g,
      };

      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      bool inToday(DateTime d) => !d.isBefore(dayStart) && !d.isAfter(dayEnd);
      final absentIds = widget.controller.attendance
          .where((a) =>
              normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT &&
              inToday(a.date))
          .map((a) => a.studentId)
          .toSet();
      // قسم "متأخرين" منفصل تحت الغايبين (spec 011) — المتأخر مش غايب.
      final lateIds = widget.controller.attendance
          .where((a) =>
              normalizeAttendanceStatus(a.status) == ATTENDANCE_LATE &&
              inToday(a.date))
          .map((a) => a.studentId)
          .toSet();

      _AbsentEntry mk(Student s) => _AbsentEntry(
          student: s, groupName: groupById[s.groupId]?.name ?? '-');
      int byGroupThenName(_AbsentEntry a, _AbsentEntry b) {
        final g = a.groupName.compareTo(b.groupName);
        return g != 0 ? g : a.student.name.compareTo(b.student.name);
      }

      final entries = students
          .where((s) => s.id != null && absentIds.contains(s.id))
          .map(mk)
          .toList()
        ..sort(byGroupThenName);
      final lateEntries = students
          .where((s) => s.id != null && lateIds.contains(s.id))
          .map(mk)
          .toList()
        ..sort(byGroupThenName);

      // نظّف أي تحديد لطالب مبقاش غايب/متأخر بعد إعادة تحميل الحضور
      final validIds = entries.map((e) => e.student.id!).toSet();
      _selected.removeWhere((id) => !validIds.contains(id));
      final validLateIds = lateEntries.map((e) => e.student.id!).toSet();
      _selectedLate.removeWhere((id) => !validLateIds.contains(id));

      if (entries.isEmpty && lateEntries.isEmpty) {
        return const EmptyState(
          icon: Icons.emoji_people_rounded,
          title: 'مفيش غياب النهاردة',
          subtitle: 'كل الطلاب اللي اتسجل حضورهم النهاردة حاضرين',
        );
      }

      final selectedCount =
          entries.where((e) => _selected.contains(e.student.id)).length;
      final allSelected = selectedCount == entries.length;
      final selectedLateCount =
          lateEntries.where((e) => _selectedLate.contains(e.student.id)).length;
      final allLateSelected = selectedLateCount == lateEntries.length;

      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.md, AppSpace.sm, AppSpace.xs),
          child: Row(children: [
            Expanded(
              child: Text(
                entries.isEmpty
                    ? 'متأخرو اليوم (${lateEntries.length})'
                    : 'غياب اليوم (${entries.length})',
                style: AppType.title.copyWith(color: t.ink),
              ),
            ),
            if (entries.isNotEmpty)
              _SelectAllButton(
                allSelected: allSelected,
                onTap: () => setState(() {
                  if (allSelected) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(entries.map((e) => e.student.id!));
                  }
                }),
              ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            // [غايبين...] + [عنوان "متأخرين"] + [متأخرين...]
            itemCount: entries.length +
                (lateEntries.isEmpty
                    ? 0
                    : (entries.isEmpty ? 0 : 1) + lateEntries.length),
            itemBuilder: (ctx, i) {
              // عنوان قسم "متأخرين" (لو فيه غايبين قبله)
              if (entries.isNotEmpty &&
                  lateEntries.isNotEmpty &&
                  i == entries.length) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.xs, AppSpace.lg, 0, AppSpace.xs),
                  child: Row(children: [
                    Icon(Icons.schedule_rounded, size: 18, color: t.caution),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text('متأخرون (${lateEntries.length})',
                          style: AppType.title.copyWith(color: t.ink)),
                    ),
                    _SelectAllButton(
                      allSelected: allLateSelected,
                      onTap: () => setState(() {
                        if (allLateSelected) {
                          _selectedLate.clear();
                        } else {
                          _selectedLate
                            ..clear()
                            ..addAll(lateEntries.map((e) => e.student.id!));
                        }
                      }),
                    ),
                  ]),
                );
              }

              // صفوف "متأخرين" — نفس أسلوب صفوف الغياب (تحديد + إرسال واتساب)
              final lateStart = entries.length + (entries.isEmpty ? 0 : 1);
              if (i >= lateStart) {
                final le = lateEntries[i - lateStart];
                return _AbsentRow(
                  entry: le,
                  late: true,
                  checked: _selectedLate.contains(le.student.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedLate.add(le.student.id!);
                    } else {
                      _selectedLate.remove(le.student.id);
                    }
                  }),
                  onSend: () => _sendLateWhatsapp(le.student, le.groupName),
                );
              }

              final entry = entries[i];
              return _AbsentRow(
                entry: entry,
                late: false,
                checked: _selected.contains(entry.student.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(entry.student.id!);
                  } else {
                    _selected.remove(entry.student.id);
                  }
                }),
                onSend: () => _sendWhatsapp(entry.student, entry.groupName),
              );
            },
          ),
        ),
        if (selectedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _sendToSelected(entries),
                icon: const Icon(Icons.chat_rounded),
                label: Text('إرسال واتساب للمحددين ($selectedCount)',
                    style: AppType.label),
                style: FilledButton.styleFrom(
                  backgroundColor: t.positive,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ),
        if (selectedLateCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _sendLateToSelected(lateEntries),
                icon: const Icon(Icons.chat_rounded),
                label: Text(
                    'إرسال واتساب للمتأخرين المحددين ($selectedLateCount)',
                    style: AppType.label),
                style: FilledButton.styleFrom(
                  backgroundColor: t.caution,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class _SelectAllButton extends StatelessWidget {
  final bool allSelected;
  final VoidCallback onTap;
  const _SelectAllButton({required this.allSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: t.brand,
        minimumSize: const Size(48, 44),
      ),
      icon: Icon(
        allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
        size: 20,
      ),
      label: Text(allSelected ? 'إلغاء التحديد' : 'تحديد الكل',
          style: AppType.body.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

/// صف طالب غايب أو متأخر: تحديد + إرسال واتساب لولي الأمر. مفيش رقم =
/// الزرار مقفول والسبب مكتوب تحت الاسم.
class _AbsentRow extends StatelessWidget {
  final _AbsentEntry entry;
  final bool late;
  final bool checked;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onSend;

  const _AbsentRow({
    required this.entry,
    required this.late,
    required this.checked,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = entry.student;
    final hasPhone = (s.guardianPhone ?? '').trim().isNotEmpty ||
        (s.guardianWhatsapp ?? '').trim().isNotEmpty;
    final accent = late ? t.caution : t.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: t.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: BorderSide(
              color: checked ? accent : t.line, width: checked ? 1.5 : 1),
        ),
        child: CheckboxListTile(
          value: checked,
          onChanged: onChanged,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: accent,
          checkColor: Colors.white,
          contentPadding: const EdgeInsetsDirectional.only(
              start: AppSpace.sm, end: AppSpace.xs),
          title: Text(s.name, style: AppType.label.copyWith(color: t.ink)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.md,
                children: [
                  Text(entry.groupName,
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                  Text('الكود ${s.code}',
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                ],
              ),
              if (!hasPhone)
                Text('لا يوجد رقم ولي أمر',
                    style: AppType.caption.copyWith(color: t.danger)),
            ],
          ),
          secondary: IconButton(
            tooltip: hasPhone ? 'إرسال واتساب' : 'لا يوجد رقم ولي أمر',
            icon: const Icon(Icons.chat_rounded),
            color: t.positive,
            disabledColor: t.inkFaint,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: hasPhone ? onSend : null,
          ),
        ),
      ),
    );
  }
}

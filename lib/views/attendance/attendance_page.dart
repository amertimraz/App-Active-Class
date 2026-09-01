// lib/views/attendance/attendance_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/qr_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/utils/student_sort_helper.dart';
import 'package:active_class/widgets/student_sort_bar.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/clock_text.dart';
import 'package:active_class/widgets/custom_dialogs.dart' as custom_dialogs;
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  final AttendanceController controller   = Get.put(AttendanceController());
  final StudentController studentCtrl     = Get.put(StudentController());
  final GroupController   groupCtrl       = Get.put(GroupController());
  final HomeworkController homeworkCtrl   = Get.put(HomeworkController());
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
    _tabController = TabController(length: 5, vsync: this);
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 30), (_) {
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
    return Scaffold(
      appBar: buildGradientAppBar(
        title: 'سجل الحضور',
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'تسجيل'),
            Tab(text: 'السجل'),
            Tab(text: 'الإحصائيات'),
            Tab(text: 'غياب اليوم'),
            Tab(text: 'QR Scan'),
          ],
        ),
        actions: [
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
      body: buildSoftBackground(
        context: context,
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
              _QRScanTab(
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
    final svc   = ExportService();
    final result = await svc.exportAttendancePDF(
      month:      month,
      students:   studentCtrl.students,
      attendance: controller.attendance,
      groups:     groupCtrl.groups,
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
  final GroupController   groupCtrl;
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
  bool get _isToday {
    final n = DateTime.now();
    return widget.selectedDay.year == n.year &&
        widget.selectedDay.month == n.month &&
        widget.selectedDay.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('EEEE، d MMMM', 'ar');
    final selectedDay = widget.selectedDay;
    final dayStart = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final dayEnd   = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59);

    return Obx(() {
      final students  = widget.studentCtrl.students;
      final allGroups = widget.groupCtrl.groups;
      final todayGroups = widget.controller.groupsForDay(allGroups, selectedDay);

      final dayRecords = widget.controller.attendance
          .where((a) => !a.date.isBefore(dayStart) && !a.date.isAfter(dayEnd));
      final Map<int, String> statusMap = {
        for (final a in dayRecords) a.studentId: a.status,
      };

      final todayIds = students
          .where((s) => todayGroups.any((g) => g.id == s.groupId))
          .map((s) => s.id)
          .toSet();
      final presentCount  = statusMap.entries.where((e) => todayIds.contains(e.key) && e.value == ATTENDANCE_PRESENT).length;
      final absentCount   = statusMap.entries.where((e) => todayIds.contains(e.key) && e.value == ATTENDANCE_ABSENT).length;
      final totalStudents = todayIds.length;
      final unmarked = totalStudents - statusMap.keys.where(todayIds.contains).length;

      return Column(children: [
        // ── مؤشر اليوم ──────────────────────────────────────────────────────
        _DayNavigator(
          isDark: isDark,
          selectedDay: selectedDay,
          isToday: _isToday,
          dateFmt: dateFmt,
          onDayChanged: widget.onDayChanged,
          presentCount:  presentCount,
          absentCount:   absentCount,
          unmarked:      unmarked,
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
                  ? _NoSessionsToday(allGroups: allGroups, selectedDay: selectedDay)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: todayGroups.length,
                      itemBuilder: (ctx, gi) {
                        final group = todayGroups[gi];
                        final sessionTime = widget.controller.sessionTimeForGroupOnDay(group, selectedDay);
                        final groupStudents = students
                            .where((s) => s.groupId == group.id)
                            .toList()
                          ..sort((a, b) => a.name.compareTo(b.name));
                        if (groupStudents.isEmpty) return const SizedBox.shrink();

                        final gPresent = groupStudents
                            .where((s) => statusMap[s.id] == ATTENDANCE_PRESENT)
                            .length;
                        final gTotal = groupStudents.length;
                        final gRate  = gTotal > 0 ? gPresent / gTotal : 0.0;

                        return _GroupSummaryCard(
                          isDark: isDark,
                          group: group,
                          sessionTime: sessionTime,
                          presentCount: gPresent,
                          totalCount: gTotal,
                          attendanceRate: gRate,
                          controller: widget.controller,
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

class _DayNavigator extends StatelessWidget {
  final bool isDark;
  final DateTime selectedDay;
  final bool isToday;
  final DateFormat dateFmt;
  final ValueChanged<DateTime> onDayChanged;
  final int presentCount, absentCount, unmarked, totalStudents;

  const _DayNavigator({
    required this.isDark,
    required this.selectedDay,
    required this.isToday,
    required this.dateFmt,
    required this.onDayChanged,
    required this.presentCount,
    required this.absentCount,
    required this.unmarked,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    final rate = totalStudents > 0 ? presentCount / totalStudents : 0.0;
    final barColor = rate >= 0.8
        ? const Color(0xFF10B981)
        : rate >= 0.5
            ? const Color(0xFFF59E0B)
            : totalStudents == 0
                ? AppTheme.primaryColor
                : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(children: [
          // التنقل
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(children: [
              if (!isToday)
                IconButton(
                  icon: const Icon(Icons.today_rounded),
                  color: AppTheme.primaryColor,
                  onPressed: () => onDayChanged(DateTime.now()),
                  tooltip: 'وصول سريع لليوم',
                ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => onDayChanged(selectedDay.subtract(const Duration(days: 1))),
                tooltip: 'اليوم السابق',
              ),
              Expanded(
                child: GestureDetector(
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
                  child: Column(children: [
                    Text(
                      isToday ? 'اليوم ✦' : dateFmt.format(selectedDay),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    if (!isToday)
                      Text(
                        DateFormat('yyyy/MM/dd').format(selectedDay),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    Text(
                      'اضغط لتغيير التاريخ',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ]),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: selectedDay.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                    ? () => onDayChanged(selectedDay.add(const Duration(days: 1)))
                    : null,
                tooltip: 'اليوم التالي',
              ),
            ]),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalStudents == 0 ? 0 : rate.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // الإحصاء
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatPill(label: 'حاضر',    value: presentCount,  color: const Color(0xFF10B981)),
                _StatPill(label: 'غائب',    value: absentCount,   color: const Color(0xFFEF4444)),
                _StatPill(label: 'لم يُسجَّل', value: unmarked,   color: Colors.grey),
                _StatPill(label: 'الكل',    value: totalStudents, color: AppTheme.primaryColor),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── كارت مختصر لمجموعة (اسم/ميعاد/إحصائية) — الضغط عليه يفتح موديل تسجيل
// الحضور الكامل. بديل لـ _GroupAttendanceCard القديمة اللي كانت بتفرد كل
// طلاب المجموعة في الشاشة الرئيسية مباشرة.
// ─────────────────────────────────────────────────────────────────────────

class _GroupSummaryCard extends StatelessWidget {
  final bool isDark;
  final Group group;
  final String? sessionTime;
  final int presentCount, totalCount;
  final double attendanceRate;
  final AttendanceController controller;
  final VoidCallback onTap;

  const _GroupSummaryCard({
    required this.isDark,
    required this.group,
    required this.sessionTime,
    required this.presentCount,
    required this.totalCount,
    required this.attendanceRate,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = attendanceRate >= 0.8
        ? const Color(0xFF10B981)
        : attendanceRate >= 0.5
            ? const Color(0xFFF59E0B)
            : totalCount == 0
                ? AppTheme.primaryColor
                : const Color(0xFFEF4444);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم المجموعة على سطره الخاص — بيظهر كامل دايمًا (بدون قص)،
            // ولو طويل جدًا بيتلف على سطر تاني بدل ما ياخد "..." أو يتزنق
            // جنب الشارات (العداد التنازلي/النسبة) — دول بقوا في صف منفصل
            // تحته عشان الاسم ميضطرش يتنافس معاهم على المساحة.
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded,
                    size: 18, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
              Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
            ]),
            const SizedBox(height: 6),
            // ميعاد الحصة + الشارات (العداد التنازلي/نسبة الحضور) — Wrap
            // بدل Row عشان لو المساحة ضاقت الشارات تنزل سطر تاني بدل ما
            // تتزنق أو تسبب overflow.
            Padding(
              padding: const EdgeInsets.only(right: 44), // نفس عرض الأيقونة+الفراغ
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (sessionTime != null)
                    Text(sessionTime!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  Builder(builder: (context) {
                    final remaining =
                        controller.remainingSessionTime(group, DateTime.now());
                    if (remaining == null) return const SizedBox.shrink();
                    final mins = remaining.inMinutes;
                    final label = mins >= 60
                        ? '${mins ~/ 60}س ${mins % 60}د متبقية'
                        : '$mins د متبقية';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.35)),
                      ),
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B))),
                    );
                  }),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: barColor.withValues(alpha: 0.3)),
                    ),
                    child: Text('$presentCount / $totalCount',
                        style: TextStyle(
                            color: barColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: totalCount == 0 ? 0 : attendanceRate.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
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
          vertical: size.height * 0.075,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: size.width * 0.92,
            maxWidth: size.width * 0.92,
            maxHeight: size.height * 0.85,
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

  @override
  void initState() {
    super.initState();
    _reportSent = widget.alreadySentReport;
    if (_payCtrl.payments.isEmpty) _payCtrl.loadPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

      final dayStart = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      final dayEnd = DateTime(
          selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59);
      final dayRecords = controller.attendance
          .where((a) => !a.date.isBefore(dayStart) && !a.date.isAfter(dayEnd));
      final Map<int, String> statusMap = {
        for (final a in dayRecords) a.studentId: a.status,
      };

      final presentCount =
          groupStudents.where((s) => statusMap[s.id] == ATTENDANCE_PRESENT).length;
      final totalCount = groupStudents.length;
      final attendanceRate = totalCount > 0 ? presentCount / totalCount : 0.0;
      final barColor = attendanceRate >= 0.8
          ? const Color(0xFF10B981)
          : attendanceRate >= 0.5
              ? const Color(0xFFF59E0B)
              : totalCount == 0
                  ? AppTheme.primaryColor
                  : const Color(0xFFEF4444);

      final q = _searchQuery.trim().toLowerCase();
      final filteredStudents = q.isEmpty
          ? groupStudents
          : groupStudents.where((s) => s.name.toLowerCase().contains(q)).toList();
      final visibleStudents = sortStudents(
        students: filteredStudents,
        sortBy: _sortBy,
        ascending: _sortAscending,
        groupOf: (_) => group,
        allAttendance: controller.attendance,
        allPayments: _payCtrl.payments,
      );

      final sessionTime = controller.sessionTimeForGroupOnDay(group, selectedDay);

      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شريط علوي: اسم المجموعة (كامل دايمًا، بيلف على سطرين لو طويل)
            // + زر إغلاق.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.groups_rounded,
                      size: 18, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            // ميعاد الحصة + العداد التنازلي + نسبة الحضور — Wrap عشان لو
            // المساحة ضاقت (اسم طويل أخد سطرين، أو شاشة صغيرة) الشارات
            // تنزل سطر تاني بدل overflow.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (sessionTime != null)
                    Text(sessionTime,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  Builder(builder: (context) {
                    final remaining =
                        controller.remainingSessionTime(group, DateTime.now());
                    if (remaining == null) return const SizedBox.shrink();
                    final mins = remaining.inMinutes;
                    final label = mins >= 60
                        ? '${mins ~/ 60}س ${mins % 60}د متبقية'
                        : '$mins د متبقية';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.timer_outlined,
                            size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(label,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFF59E0B))),
                      ]),
                    );
                  }),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: barColor.withValues(alpha: 0.3)),
                    ),
                    child: Text('$presentCount / $totalCount',
                        style: TextStyle(
                            color: barColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // بحث سريع عن طالب داخل هذه المجموعة + ترتيب (منقول من التكرار
            // الأول، وبنفس أيقونات الترتيب المستخدمة في شاشة الطلاب/تفاصيل
            // المجموعة).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Expanded(
                  child: CustomSearchBar(
                    controller: _searchController,
                    hintText: 'ابحث...',
                    onChanged: (v) => setState(() => _searchQuery = v),
                    onClear: () => setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                  ),
                ),
                const SizedBox(width: 4),
                StudentSortBar(
                  sortBy: _sortBy,
                  ascending: _sortAscending,
                  onChanged: _onSortTap,
                ),
              ]),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            // تبويبان داخل الموديل: حضور | واجب (spec 010). يفتح على "حضور".
            // TabBarView محتاج ارتفاع محدَّد — والـColumn الأب mainAxisSize.min
            // فبنحسب ارتفاع صريح من الشاشة (زي ما SingleChildScrollView كان
            // بيتصرّف قبل التبويبات).
            DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TabBar(
                    labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                    tabs: [Tab(text: 'حضور'), Tab(text: 'واجب')],
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).size.height * 0.46,
                      child: TabBarView(children: [
                        // ── تبويب حضور ──────────────────────────────
                        SingleChildScrollView(
                          child: Column(children: [
                            // "تحضير الكل" + شريط نسبة الحضور
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 8, 14, 4),
                              child: Row(children: [
                                Builder(builder: (context) {
                                  final allPresent = totalCount > 0 &&
                                      groupStudents.every((s) =>
                                          statusMap[s.id] ==
                                          ATTENDANCE_PRESENT);
                                  return TextButton.icon(
                                    onPressed: () =>
                                        controller.markGroupAllPresent(
                                      groupStudents
                                          .map((s) => s.id!)
                                          .toList(),
                                      selectedDay,
                                    ),
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: allPresent
                                            ? Colors.grey.shade600
                                            : const Color(0xFF10B981)),
                                    icon: Icon(
                                        allPresent
                                            ? Icons.remove_done_rounded
                                            : Icons.done_all_rounded,
                                        size: 18),
                                    label: Text(
                                        allPresent
                                            ? 'إلغاء تحضير الكل'
                                            : 'تحضير الكل',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Cairo')),
                                  );
                                }),
                                const Spacer(),
                              ]),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 0, 14, 4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: totalCount == 0
                                      ? 0
                                      : attendanceRate.clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: isDark
                                      ? Colors.white12
                                      : Colors.grey.shade100,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(barColor),
                                ),
                              ),
                            ),
                            if (visibleStudents.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                child: Text(
                                  'لا يوجد طلاب مطابقين في هذه المجموعة',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontFamily: 'Cairo'),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: visibleStudents.map((s) {
                                    final status = statusMap[s.id];
                                    // مفيش Obx هنا — الأب (_AttendanceSheet.build)
                                    // ملفوف في Obx بيقرا controller.attendance،
                                    // فأي تبديل بيعيد بناء الصف بـstatus جديد.
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8),
                                      child: _StudentAttendanceChip(
                                        student: s,
                                        status: status,
                                        onTap: () async {
                                          await controller.toggleAttendance(
                                              s.id!, selectedDay);
                                          // غائب = لا واجب: امسح سجل الواجب
                                          // لنفس اليوم (spec 010).
                                          final ns = controller.attendance
                                              .firstWhereOrNull((a) =>
                                                  a.studentId == s.id &&
                                                  a.date.year ==
                                                      selectedDay.year &&
                                                  a.date.month ==
                                                      selectedDay.month &&
                                                  a.date.day == selectedDay.day)
                                              ?.status;
                                          if (ns == ATTENDANCE_ABSENT) {
                                            await homeworkCtrl.clearHomework(
                                                s.id!, selectedDay);
                                          }
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            _buildReportButton(context, group, groupStudents,
                                controller, homeworkCtrl, selectedDay),
                          ]),
                        ),
                        // ── تبويب واجب ──────────────────────────────
                        _HomeworkTabBody(
                          students: visibleStudents,
                          statusMap: statusMap,
                          homeworkCtrl: homeworkCtrl,
                          selectedDay: selectedDay,
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
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
                    if (!controller.isAttendanceCompleteForGroupToday(
                        group, groupStudents)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showSendReportConfirm(
                            context, group, groupStudents, controller,
                            homeworkCtrl, onSent: () {
                          setState(() => _reportSent = true);
                          widget.onReportSent();
                        }),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: (_reportSent
                                    ? Colors.green
                                    : const Color(0xFF25D366))
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: (_reportSent
                                        ? Colors.green
                                        : const Color(0xFF25D366))
                                    .withValues(alpha: 0.35)),
                          ),
                          child: Row(children: [
                            Icon(
                                _reportSent
                                    ? Icons.check_circle_rounded
                                    : Icons.chat_rounded,
                                size: 16,
                                color: _reportSent
                                    ? Colors.green
                                    : const Color(0xFF25D366)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  _reportSent
                                      ? 'تم إرسال التقرير — اضغط لإعادة الإرسال'
                                      : 'إرسال تقرير واتساب لأولياء الأمور',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _reportSent
                                          ? Colors.green.shade800
                                          : const Color(0xFF128C7E))),
                            ),
                          ]),
                        ),
                      ),
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
    final phone = s.guardianPhone?.trim() ?? '';
    if (phone.isEmpty) {
      skipped.add(s);
    } else {
      withPhone.add(s);
    }
  }

  if (withPhone.isEmpty) {
    if (context.mounted) {
      AppToast.error(context, 'مفيش أي طالب في المجموعة عنده رقم ولي أمر مسجّل');
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
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
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

  String normalizePhone(String input, String defaultDial) {
    var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('00')) p = p.substring(2);
    if (p.startsWith(defaultDial)) return p;
    if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
    return defaultDial + p.replaceFirst(RegExp(r'^0+'), '');
  }

  final settings = Get.find<SettingsController>();
  final countryDial = settings.countryDial.value;
  final teacherName = settings.teacherFullName.value.trim();
  final teacherSpecialization = settings.teacherSpecialization.value.trim();

  for (final s in withPhone) {
    final attStatus = controller.attendance
        .firstWhereOrNull((a) =>
            a.studentId == s.id &&
            a.date.year == selectedDay.year &&
            a.date.month == selectedDay.month &&
            a.date.day == selectedDay.day)
        ?.status;
    if (attStatus == null) continue; // احتياطي: مفروض مستحيل لو الزرار ظاهر
    final hwStatus = homeworkCtrl.statusFor(s.id!, selectedDay);
    final message = controller.buildGuardianReportMessage(
      student: s,
      attendanceStatus: attStatus,
      homeworkStatus: hwStatus,
      teacherName: teacherName,
      teacherSpecialization: teacherSpecialization,
    );
    final phone = normalizePhone(s.guardianPhone!.trim(), countryDial);
    final uri =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

class _StudentAttendanceChip extends StatelessWidget {
  final Student student;
  final String? status;
  final VoidCallback onTap;

  const _StudentAttendanceChip({
    required this.student,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPresent = status == ATTENDANCE_PRESENT;
    final isAbsent  = status == ATTENDANCE_ABSENT;

    // هرمية بصرية متعمّدة: "غائب" هو الاستثناء اللي المدرس محتاج يلاحظه
    // فورًا فبيبان بأقوى تباين وحدود واضحة؛ "لم يُسجَّل" هي الحالة
    // الافتراضية الأكثر شيوعًا وقت بداية الحصة فبتبقى هادئة بصريًا (بلا
    // حدود بارزة) عشان العين تتجاهلها بسهولة وتلتقط الاستثناءات بدل ما
    // تقرأ كل صف على حدة؛ "حاضر" في المنتصف — واضح لكن أقل ثقلاً من الغياب.
    final color = isPresent
        ? const Color(0xFF10B981)
        : isAbsent
            ? const Color(0xFFEF4444)
            : Colors.grey.shade400;

    final bgColor = isPresent
        ? const Color(0xFF10B981).withValues(alpha: 0.08)
        : isAbsent
            ? const Color(0xFFEF4444).withValues(alpha: 0.16)
            : Colors.grey.withValues(alpha: 0.04);

    final borderColor = isAbsent
        ? const Color(0xFFEF4444).withValues(alpha: 0.6)
        : isPresent
            ? const Color(0xFF10B981).withValues(alpha: 0.25)
            : Colors.transparent;

    final borderWidth = isAbsent ? 1.6 : (isPresent ? 1.0 : 0.0);

    final icon = isPresent
        ? Icons.check_circle_rounded
        : isAbsent
            ? Icons.cancel_rounded
            : Icons.radio_button_unchecked_rounded;

    final initial = student.name.trim().isNotEmpty ? student.name.trim()[0] : '؟';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(children: [
          // دائرة الحرف الأول
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initial,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: color)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight:
                        isAbsent ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 12,
                    color: isPresent || isAbsent ? color : Colors.grey.shade600,
                  ),
                ),
                Text(
                  isPresent ? 'حاضر' : isAbsent ? 'غائب' : 'لم يُسجَّل',
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: isAbsent ? FontWeight.w800 : FontWeight.w600),
                ),
              ],
            ),
          ),
          Icon(icon, color: color, size: isAbsent ? 20 : 18),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  تبويب "واجب" داخل موديل المجموعة (spec 010)
// ═══════════════════════════════════════════════════════════════════════════════

class _HomeworkTabBody extends StatelessWidget {
  final List<Student> students;
  final Map<int, String> statusMap; // حالة الحضور لكل طالب في اليوم
  final HomeworkController homeworkCtrl;
  final DateTime selectedDay;

  const _HomeworkTabBody({
    required this.students,
    required this.statusMap,
    required this.homeworkCtrl,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('لا يوجد طلاب مطابقين في هذه المجموعة',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontFamily: 'Cairo')),
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
              normalizeHomeworkStatus(homeworkCtrl.statusFor(id, selectedDay)) ==
              HOMEWORK_DONE);

      Widget miniCount(Color c, int n) => Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('$n',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c,
                      fontFamily: 'Cairo')),
            ]),
          );

      return SingleChildScrollView(
        child: Column(children: [
          // شريط ملخّص + زر جماعي
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(children: [
              miniCount(const Color(0xFF10B981), sum.done),
              miniCount(const Color(0xFFF59E0B), sum.partial),
              miniCount(const Color(0xFFEF4444), sum.notDone),
              miniCount(Colors.grey, sum.unset),
              const Spacer(),
              TextButton(
                onPressed: presentIds.isEmpty
                    ? null
                    : () => homeworkCtrl.markGroupAllHomeworkDone(
                        presentIds, selectedDay),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(allDone ? 'إلغاء الكل' : 'الكل عمل',
                    style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
              ),
            ]),
          ),
          const Divider(height: 1, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              children: students.map((s) {
                final absent = statusMap[s.id] == ATTENDANCE_ABSENT;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _HomeworkStudentRow(
                    name: s.name,
                    absent: absent,
                    status: absent
                        ? null
                        : normalizeHomeworkStatus(
                            homeworkCtrl.statusFor(s.id!, selectedDay)),
                    onSelect: (st) =>
                        homeworkCtrl.setHomeworkStatus(s.id!, selectedDay, st),
                  ),
                );
              }).toList(),
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
  final String? status; // مطبّع: HOMEWORK_DONE / HOMEWORK_PARTIAL / HOMEWORK_NOT_DONE / null
  final ValueChanged<String?> onSelect;

  const _HomeworkStudentRow({
    required this.name,
    required this.absent,
    required this.status,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: absent
            ? Colors.grey.withValues(alpha: 0.05)
            : cs.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          if (absent)
            Text('غائب',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    fontFamily: 'Cairo')),
        ]),
        if (!absent) ...[
          const SizedBox(height: 7),
          _HomeworkStatusSegmented(status: status, onSelect: onSelect),
        ],
      ]),
    );
  }
}

/// 3 أزرار مجزّأة لحالة الواجب — يُختار منها واحد؛ الضغط على المختار = إلغاء.
class _HomeworkStatusSegmented extends StatelessWidget {
  final String? status;
  final ValueChanged<String?> onSelect;

  const _HomeworkStatusSegmented(
      {required this.status, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget btn(String value, String label, Color color) {
      final selected = status == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(selected ? null : value),
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.16)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: selected
                      ? color
                      : Colors.grey.withValues(alpha: 0.25),
                  width: selected ? 1.4 : 1),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'Cairo',
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? color : Colors.grey.shade600)),
              ),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      btn(HOMEWORK_DONE, 'تم الحل', const Color(0xFF10B981)),
      btn(HOMEWORK_PARTIAL, 'ناقص', const Color(0xFFF59E0B)),
      btn(HOMEWORK_NOT_DONE, 'لم يُحل', const Color(0xFFEF4444)),
    ]);
  }
}

// ── No sessions today ─────────────────────────────────────────────────────────

class _NoSessionsToday extends StatelessWidget {
  final List allGroups;
  final DateTime selectedDay;

  const _NoSessionsToday({required this.allGroups, required this.selectedDay});

  static const _weekdays = {
    1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس',
    5: 'الجمعة',  6: 'السبت',    7: 'الأحد',
  };

  static const _arDays = {
    'الاثنين': 1, 'الثلاثاء': 2, 'الأربعاء': 3, 'الخميس': 4,
    'الجمعة': 5,  'السبت': 6,    'الأحد': 7,
  };

  String _scheduleSummary(dynamic g) {
    final s = g.schedule as String?;
    if (s == null || s.trim().isEmpty) return 'بدون جدول';
    final days = <String>{};
    for (final k in _arDays.keys) { if (s.contains(k)) days.add(k); }
    return days.isEmpty ? s : days.join('، ');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'لم يُجدوَل أي مجموعة في هذا اليوم',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey.shade500),
              textAlign: TextAlign.center,
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
                      const Icon(Icons.groups_outlined, size: 14, color: Colors.grey),
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
  final GroupController   groupCtrl;

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
  int?   _groupFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final q        = _searchCtrl.text.toLowerCase();
      final students = widget.studentCtrl.students;
      final groups   = widget.groupCtrl.groups;
      final groupById = {for (final g in groups) g.id: g};

      final list = widget.controller.attendance.where((a) {
        if (_statusFilter.isNotEmpty && a.status != _statusFilter) return false;
        final s = students.firstWhereOrNull((st) => st.id == a.studentId);
        if (_groupFilter != null && s?.groupId != _groupFilter) return false;
        if (q.isNotEmpty && !(s?.name.toLowerCase().contains(q) ?? false)) return false;
        return true;
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

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
                onClear: () { _searchCtrl.clear(); setState(() {}); },
              ),
            ),
            const SizedBox(width: 8),
            _FilterBtn(
              label: _groupFilter == null
                  ? 'المجموعة'
                  : groupById[_groupFilter]?.name ?? 'المجموعة',
              isDark: isDark,
              onTap: () => _showGroupSheet(context, groups),
            ),
          ]),
        ),
        // Status chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            for (final item in [
              ('الكل', ''),
              ('حاضر', ATTENDANCE_PRESENT),
              ('غائب', ATTENDANCE_ABSENT),
            ])
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _StatusChip(
                  label: item.$1,
                  selected: _statusFilter == item.$2,
                  color: item.$2 == ATTENDANCE_PRESENT
                      ? const Color(0xFF10B981)
                      : item.$2 == ATTENDANCE_ABSENT
                          ? const Color(0xFFEF4444)
                          : AppTheme.primaryColor,
                  onTap: () => setState(() => _statusFilter = item.$2),
                ),
              ),
            const Spacer(),
            Text('${list.length} سجل',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
        // List
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.event_note,
                  title: 'لا توجد سجلات',
                  subtitle: 'عدّل الفلاتر أو سجّل حضوراً',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final att       = list[i];
                    final s         = students.firstWhereOrNull((st) => st.id == att.studentId);
                    final isPresent = att.status == ATTENDANCE_PRESENT;
                    final color     = isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                    final groupName = groupById[s?.groupId]?.name;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131D31) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(children: [
                        // أيقونة الحالة
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: color, size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s?.name ?? 'طالب',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              Row(children: [
                                if (groupName != null) ...[
                                  Icon(Icons.groups_outlined,
                                      size: 11, color: Colors.grey.shade400),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(groupName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                  ),
                                  Text('  •  ',
                                      style: TextStyle(color: Colors.grey.shade400)),
                                ],
                                Text(
                                  FormatHelper.formatDate(att.date),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        // Badge الحالة
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(att.status,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.edit_calendar_outlined,
                              size: 18, color: Colors.grey.shade400),
                          onPressed: () {
                            if (!requireDeletePermission(context,
                                TeamModeService().canDeleteAttendanceNow)) {
                              return;
                            }
                            _editAttendanceDate(context, att, s?.name);
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.grey.shade400),
                          onPressed: () {
                            if (!requireDeletePermission(context,
                                TeamModeService().canDeleteAttendanceNow)) {
                              return;
                            }
                            custom_dialogs.ConfirmDeleteDialog.show(
                              context,
                              title: 'حذف السجل',
                              message:
                                  'هل تريد حذف سجل حضور ${s?.name ?? "الطالب"} '
                                  'بتاريخ ${FormatHelper.formatDate(att.date)}؟',
                              onConfirm: () =>
                                  widget.controller.deleteAttendance(att.id!),
                            );
                          },
                          visualDensity: VisualDensity.compact,
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
              child: Container(width: 40, height: 4,
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
              onTap: () { setState(() => _groupFilter = null); Get.back(); },
            ),
            ...groups.map((g) => ListTile(
              leading: Icon(_groupFilter == g.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(g.name),
              onTap: () { setState(() => _groupFilter = g.id); Get.back(); },
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
  final GroupController   groupCtrl;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final students = widget.studentCtrl.students;
      final groups   = widget.groupCtrl.groups;

      final presentByStudent  = widget.controller.getPresentCountByStudent(range: _range);
      final expectedPerGroup  = widget.controller.getExpectedSessionsPerGroup(groups: groups, range: _range);

      final perStudent = students.map((s) {
        final present  = presentByStudent[s.id ?? -1] ?? 0;
        final expected = expectedPerGroup[s.groupId] ?? 0;
        final percent  = expected == 0 ? 0.0 : (present / expected) * 100.0;
        return _StudentStats(student: s, present: present, expected: expected, percent: percent);
      }).toList()
        ..sort((a, b) => a.percent.compareTo(b.percent));

      final rangePresent = widget.controller.attendance
          .where((a) => a.status == ATTENDANCE_PRESENT &&
              (_range == null || (!a.date.isBefore(_range!.start) && !a.date.isAfter(_range!.end))))
          .length;
      final rangeAbsent = widget.controller.attendance
          .where((a) => a.status == ATTENDANCE_ABSENT &&
              (_range == null || (!a.date.isBefore(_range!.start) && !a.date.isAfter(_range!.end))))
          .length;
      final total = rangePresent + rangeAbsent;
      final rate  = total > 0 ? rangePresent / total : 0.0;

      return Column(children: [
        // فلتر التاريخ
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D31) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                  blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(children: [
              // فلاتر سريعة
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _QuickRangeChip(label: 'الكل',       selected: _range == null,                    onTap: () => setState(() => _range = null)),
                  const SizedBox(width: 6),
                  _QuickRangeChip(label: 'اليوم',       selected: _range != null && _isTodayRange(_range!),    onTap: () => setState(() => _range = _todayRange())),
                  const SizedBox(width: 6),
                  _QuickRangeChip(label: 'هذا الأسبوع', selected: _range != null && _isThisWeekRange(_range!),  onTap: () => setState(() => _range = _thisWeekRange())),
                  const SizedBox(width: 6),
                  _QuickRangeChip(label: 'هذا الشهر',   selected: _range != null && _isThisMonthRange(_range!), onTap: () => setState(() => _range = _thisMonthRange())),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () async {
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
                    icon: const Icon(Icons.date_range_rounded, size: 15),
                    label: const Text('نطاق'),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // إحصاء كبير
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BigStat(label: 'حضور', value: rangePresent.toString(),
                      color: const Color(0xFF10B981), icon: Icons.check_circle_outline_rounded),
                  _BigStat(label: 'غياب', value: rangeAbsent.toString(),
                      color: const Color(0xFFEF4444), icon: Icons.cancel_outlined),
                  _BigStat(
                    label: 'نسبة الحضور',
                    value: '${(rate * 100).toStringAsFixed(0)}%',
                    color: rate >= 0.8
                        ? const Color(0xFF10B981)
                        : rate >= 0.5
                            ? const Color(0xFFF59E0B)
                            : total == 0 ? AppTheme.primaryColor : const Color(0xFFEF4444),
                    icon: Icons.bar_chart_rounded,
                  ),
                ],
              ),
            ]),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text('نسبة الحضور لكل طالب',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF111827))),
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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final e     = perStudent[i];
                    final color = ColorHelper.getPercentageColor(e.percent);
                    final isDk  = Theme.of(ctx).brightness == Brightness.dark;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDk ? const Color(0xFF131D31) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDk ? 0.12 : 0.04),
                            blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                e.student.name.isNotEmpty ? e.student.name[0] : '؟',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(e.student.name,
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ),
                          Text('${e.present} / ${e.expected}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              FormatHelper.formatPercentage(e.percent),
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: e.expected == 0 ? 0 : (e.present / e.expected).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: color.withValues(alpha: 0.10),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
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
//  Tab 4 — QR Scan
// ═══════════════════════════════════════════════════════════════════════════════

class _QRScanTab extends StatefulWidget {
  final AttendanceController controller;
  final StudentController studentCtrl;
  final GroupController   groupCtrl;

  const _QRScanTab({
    required this.controller,
    required this.studentCtrl,
    required this.groupCtrl,
  });

  @override
  State<_QRScanTab> createState() => _QRScanTabState();
}

class _QRScanTabState extends State<_QRScanTab> {
  late MobileScannerController _scanner;
  final QRController _qr = Get.put(QRController());
  Timer? _refreshTimer;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController();
    _qr.mode.value = QRMode.attendance;
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await widget.controller.loadAttendance();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final today    = _todayRange();

    return Column(children: [
      // ── عرض الكاميرا ────────────────────────────────────────────────────────
      Stack(children: [
        SizedBox(
          height: 230,
          width: double.infinity,
          child: ClipRRect(
            child: MobileScanner(
              controller: _scanner,
              onDetect: (capture) {
                final v = capture.barcodes.first.rawValue;
                if (v != null) _qr.handleScan(v);
              },
            ),
          ),
        ),
        // إطار المسح
        Positioned.fill(
          child: Center(
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        // أزرار الكاميرا
        Positioned(
          bottom: 10, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CamBtn(
                icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                label: 'فلاش',
                onTap: () {
                  _scanner.toggleTorch();
                  setState(() => _torchOn = !_torchOn);
                },
              ),
              const SizedBox(width: 16),
              _CamBtn(
                icon: Icons.flip_camera_ios_rounded,
                label: 'كاميرا',
                onTap: () => _scanner.switchCamera(),
              ),
            ],
          ),
        ),
      ]),

      // ── بطاقة الطالب الممسوح ────────────────────────────────────────────────
      Obx(() {
        final s = _qr.scannedStudent.value;
        if (s == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'وجّه الكاميرا نحو كود QR للطالب',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey.shade500),
            ),
          );
        }
        final group = widget.groupCtrl.groups
            .firstWhereOrNull((g) => g.id == s.groupId);
        return _ScannedStudentCard(student: s, group: group, isDark: isDark);
      }),

      // فاصل
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('آخر الحاضرين اليوم',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey.shade500)),
          ),
          const Expanded(child: Divider()),
        ]),
      ),

      // ── قائمة الحاضرين اليوم ────────────────────────────────────────────────
      Expanded(
        child: Obx(() {
          final presentToday = widget.controller.attendance
              .where((a) =>
                  a.status == ATTENDANCE_PRESENT &&
                  !a.date.isBefore(today.start) &&
                  !a.date.isAfter(today.end))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (presentToday.isEmpty) {
            return Center(
              child: Text(
                'لا يوجد حضور مسجّل اليوم',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: Colors.grey.shade500),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: presentToday.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final att = presentToday[i];
              final s   = widget.studentCtrl.students
                  .firstWhereOrNull((st) => st.id == att.studentId);
              final initial = s?.name.trim().isNotEmpty == true
                  ? s!.name.trim()[0]
                  : '؟';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D31) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(initial,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF10B981))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s?.name ?? 'طالب',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                  ClockText(att.date,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: Color(0xFF10B981)),
                ]),
              );
            },
          );
        }),
      ),
    ]);
  }
}

// ── بطاقة الطالب الممسوح ─────────────────────────────────────────────────────

class _ScannedStudentCard extends StatelessWidget {
  final Student student;
  final Group?  group;
  final bool    isDark;

  const _ScannedStudentCard({
    required this.student,
    required this.group,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF10B981);
    final initial = student.name.trim().isNotEmpty ? student.name.trim()[0] : '؟';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D2218) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.name,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: color)),
              if (group != null)
                Text(group!.name,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade500)),
            ]),
          ),
          // Icon حضور
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: color, size: 24),
          ),
        ]),
      ),
    );
  }
}

// ── زر كاميرا ─────────────────────────────────────────────────────────────────

class _CamBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _CamBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Small reusable widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _StatPill extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text('$value',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              color: Colors.grey.shade600)),
    ]);
  }
}

class _BigStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  final IconData icon;
  const _BigStat({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontFamily: 'Cairo',
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20)),
      Text(label,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Colors.grey.shade600)),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final Color  color;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                color: selected ? color : Colors.grey.shade600,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13)),
      ),
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final bool   isDark;
  final VoidCallback onTap;
  const _FilterBtn({required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group_outlined, size: 15, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade500),
        ]),
      ),
    );
  }
}

class _QuickRangeChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  const _QuickRangeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                color: selected ? color : Colors.grey.shade600,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13)),
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _StudentStats {
  final Student student;
  final int     present, expected;
  final double  percent;
  _StudentStats({required this.student, required this.present, required this.expected, required this.percent});
}

// ─── Date helpers ─────────────────────────────────────────────────────────────

DateTimeRange _todayRange() {
  final n = DateTime.now();
  return DateTimeRange(
    start: DateTime(n.year, n.month, n.day),
    end:   DateTime(n.year, n.month, n.day, 23, 59, 59),
  );
}

DateTimeRange _thisWeekRange() {
  final n     = DateTime.now();
  final start = n.subtract(Duration(days: n.weekday - 1));
  final ws    = DateTime(start.year, start.month, start.day);
  final we    = ws.add(const Duration(days: 6));
  return DateTimeRange(
    start: ws,
    end:   DateTime(we.year, we.month, we.day, 23, 59, 59),
  );
}

DateTimeRange _thisMonthRange() {
  final n   = DateTime.now();
  final s   = DateTime(n.year, n.month, 1);
  final end = DateTime(n.year, n.month + 1, 1).subtract(const Duration(days: 1));
  return DateTimeRange(
    start: s,
    end:   DateTime(end.year, end.month, end.day, 23, 59, 59),
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
  end:   DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59),
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

  String _normalizePhone(String input, String defaultDial) {
    var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('00')) p = p.substring(2);
    if (p.startsWith(defaultDial)) return p;
    if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
    return defaultDial + p.replaceFirst(RegExp(r'^0+'), '');
  }

  String _buildMessage(Student s, String groupName, String teacherName,
      String teacherSpecialization) {
    final dateStr = DateFormat('yyyy-MM-dd', 'ar').format(DateTime.now());
    final buffer = StringBuffer()
      ..writeln('⚠️ *تنبيه غياب*')
      ..writeln('👤 ${s.name} (${s.code})')
      ..writeln('👥 $groupName')
      ..writeln('📅 $dateStr');
    if (teacherName.isNotEmpty) {
      buffer.writeln('👨‍🏫 $teacherName');
    }
    if (teacherSpecialization.isNotEmpty) {
      buffer.writeln('📘 $teacherSpecialization');
    }
    return buffer.toString().trimRight();
  }

  Future<void> _sendWhatsapp(Student s, String groupName) async {
    final rawPhone = s.guardianPhone?.trim() ?? '';
    if (rawPhone.isEmpty) {
      AppToast.warning(context, 'لا يوجد رقم ولي أمر لـ ${s.name}');
      return;
    }
    final settings = Get.find<SettingsController>();
    final phone = _normalizePhone(rawPhone, settings.countryDial.value);
    final msg = _buildMessage(s, groupName, settings.teacherFullName.value.trim(),
        settings.teacherSpecialization.value.trim());
    final uri =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool?> _confirmSendDialog(_AbsentEntry entry, int index, int total) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إرسال $index من $total'),
        content: Text(
            'إرسال رسالة غياب لولي أمر ${entry.student.name} (${entry.groupName})؟'),
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
        .where((e) => (e.student.guardianPhone ?? '').trim().isNotEmpty)
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final students = widget.studentCtrl.students;
      final groups   = widget.groupCtrl.groups;
      final groupById = {
        for (final g in groups)
          if (g.id != null) g.id!: g,
      };

      final now       = DateTime.now();
      final dayStart  = DateTime(now.year, now.month, now.day);
      final dayEnd    = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final absentIds = widget.controller.attendance
          .where((a) =>
              a.status == ATTENDANCE_ABSENT &&
              !a.date.isBefore(dayStart) &&
              !a.date.isAfter(dayEnd))
          .map((a) => a.studentId)
          .toSet();

      final entries = students
          .where((s) => s.id != null && absentIds.contains(s.id))
          .map((s) => _AbsentEntry(
              student: s, groupName: groupById[s.groupId]?.name ?? '-'))
          .toList()
        ..sort((a, b) {
          final byGroup = a.groupName.compareTo(b.groupName);
          return byGroup != 0
              ? byGroup
              : a.student.name.compareTo(b.student.name);
        });

      // نظّف أي تحديد لطالب مبقاش غايب بعد إعادة تحميل الحضور
      final validIds = entries.map((e) => e.student.id!).toSet();
      _selected.removeWhere((id) => !validIds.contains(id));

      if (entries.isEmpty) {
        return const EmptyState(
          icon: Icons.emoji_people_rounded,
          title: 'مفيش غياب النهاردة',
          subtitle: 'كل الطلاب اللي اتسجل حضورهم النهاردة حاضرين',
        );
      }

      final selectedCount =
          entries.where((e) => _selected.contains(e.student.id)).length;
      final allSelected = selectedCount == entries.length;

      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Text(
              'غياب اليوم (${entries.length})',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() {
                if (allSelected) {
                  _selected.clear();
                } else {
                  _selected
                    ..clear()
                    ..addAll(entries.map((e) => e.student.id!));
                }
              }),
              icon: Icon(
                allSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                size: 18,
              ),
              label: Text(allSelected ? 'إلغاء التحديد' : 'تحديد الكل'),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final entry    = entries[i];
              final s        = entry.student;
              final hasPhone = (s.guardianPhone ?? '').trim().isNotEmpty;
              final checked  = _selected.contains(s.id);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D31) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: checked
                        ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade200),
                  ),
                ),
                child: CheckboxListTile(
                  value: checked,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(s.id!);
                    } else {
                      _selected.remove(s.id);
                    }
                  }),
                  title: Text(
                    s.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    'الكود: ${s.code} • المجموعة: ${entry.groupName}'
                    '${hasPhone ? '' : ' • لا يوجد رقم ولي أمر'}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: hasPhone
                          ? (isDark ? Colors.white60 : Colors.grey.shade600)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  secondary: IconButton(
                    tooltip: hasPhone ? 'إرسال واتساب' : 'لا يوجد رقم ولي أمر',
                    icon: const Icon(Icons.chat, color: Colors.green),
                    onPressed:
                        !hasPhone ? null : () => _sendWhatsapp(s, entry.groupName),
                  ),
                ),
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
                label: Text('إرسال واتساب للمحددين ($selectedCount)'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981)),
              ),
            ),
          ),
      ]);
    });
  }
}

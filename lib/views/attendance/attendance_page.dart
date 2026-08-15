// lib/views/attendance/attendance_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/qr_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/widgets/custom_widgets.dart';
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
  late final TabController _tabController;
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _reload();
  }

  Future<void> _reload() async {
    await studentCtrl.loadAllStudents();
    await groupCtrl.loadGroups();
    await controller.loadAttendance();
    controller.buildStudentMaps(studentCtrl.students);
  }

  @override
  void dispose() {
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
                selectedDay: _selectedDay,
                onDayChanged: (d) => setState(() => _selectedDay = d),
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

class _RegisterTab extends StatelessWidget {
  final AttendanceController controller;
  final StudentController studentCtrl;
  final GroupController   groupCtrl;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayChanged;

  const _RegisterTab({
    required this.controller,
    required this.studentCtrl,
    required this.groupCtrl,
    required this.selectedDay,
    required this.onDayChanged,
  });

  bool get _isToday {
    final n = DateTime.now();
    return selectedDay.year == n.year &&
        selectedDay.month == n.month &&
        selectedDay.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('EEEE، d MMMM', 'ar');
    final dayStart = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final dayEnd   = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59);

    return Obx(() {
      final students  = studentCtrl.students;
      final allGroups = groupCtrl.groups;
      final todayGroups = controller.groupsForDay(allGroups, selectedDay);

      final dayRecords = controller.attendance
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
          onDayChanged: onDayChanged,
          presentCount:  presentCount,
          absentCount:   absentCount,
          unmarked:      unmarked,
          totalStudents: totalStudents,
        ),

        // ── قائمة المجموعات ──────────────────────────────────────────────────
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
                        final sessionTime = controller.sessionTimeForGroupOnDay(group, selectedDay);
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

                        return _GroupAttendanceCard(
                          isDark: isDark,
                          group: group,
                          sessionTime: sessionTime,
                          students: groupStudents,
                          statusMap: statusMap,
                          presentCount: gPresent,
                          totalCount: gTotal,
                          attendanceRate: gRate,
                          selectedDay: selectedDay,
                          controller: controller,
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

// ── بطاقة مجموعة بالطلاب ─────────────────────────────────────────────────────

class _GroupAttendanceCard extends StatelessWidget {
  final bool isDark;
  final Group group;
  final String? sessionTime;
  final List<Student> students;
  final Map<int, String> statusMap;
  final int presentCount, totalCount;
  final double attendanceRate;
  final DateTime selectedDay;
  final AttendanceController controller;

  const _GroupAttendanceCard({
    required this.isDark,
    required this.group,
    required this.sessionTime,
    required this.students,
    required this.statusMap,
    required this.presentCount,
    required this.totalCount,
    required this.attendanceRate,
    required this.selectedDay,
    required this.controller,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header المجموعة
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(children: [
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    if (sessionTime != null)
                      Text(sessionTime!,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              // نسبة الحضور
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: barColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$presentCount / $totalCount',
                  style: TextStyle(
                      color: barColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              // الكل حاضر ← لو كله متحضّر بالفعل، الضغطة بتلغي التحضير
              Builder(builder: (context) {
                final allPresent = totalCount > 0 &&
                    students.every(
                        (s) => statusMap[s.id] == ATTENDANCE_PRESENT);
                return TextButton.icon(
                  onPressed: () => controller.markGroupAllPresent(
                    students.map((s) => s.id!).toList(),
                    selectedDay,
                  ),
                  icon: Icon(
                      allPresent
                          ? Icons.remove_done_rounded
                          : Icons.done_all_rounded,
                      size: 15),
                  label: Text(allPresent ? 'إلغاء الكل' : 'حاضر'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: allPresent
                        ? Colors.grey.shade600
                        : const Color(0xFF10B981),
                    textStyle: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                );
              }),
            ]),
          ),
          // Progress bar للمجموعة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: totalCount == 0 ? 0 : attendanceRate.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // الطلاب
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: students.map((s) {
                final status = statusMap[s.id];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _StudentAttendanceChip(
                    student: s,
                    status: status,
                    onTap: () => controller.toggleAttendance(s.id!, selectedDay),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
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
    final color = isPresent
        ? const Color(0xFF10B981)
        : isAbsent
            ? const Color(0xFFEF4444)
            : Colors.grey;

    final bgColor = isPresent
        ? const Color(0xFF10B981).withValues(alpha: 0.10)
        : isAbsent
            ? const Color(0xFFEF4444).withValues(alpha: 0.10)
            : Colors.grey.withValues(alpha: 0.07);

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
          border: Border.all(
            color: color.withValues(alpha: isPresent || isAbsent ? 0.4 : 0.15),
            width: isPresent || isAbsent ? 1.5 : 1,
          ),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isPresent || isAbsent ? color : null,
                  ),
                ),
                Text(
                  isPresent ? 'حاضر' : isAbsent ? 'غائب' : 'لم يُسجَّل',
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Icon(icon, color: color, size: 18),
        ]),
      ),
    );
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
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.grey.shade400),
                          onPressed: () => custom_dialogs.ConfirmDeleteDialog.show(
                            context,
                            title: 'حذف السجل',
                            message:
                                'هل تريد حذف سجل حضور ${s?.name ?? "الطالب"} '
                                'بتاريخ ${FormatHelper.formatDate(att.date)}؟',
                            onConfirm: () =>
                                widget.controller.deleteAttendance(att.id!),
                          ),
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
          // قراءة مباشرة هنا عشان القائمة تتحدّث لما نظام الساعة 12/24
          // يتغيّر من الإعدادات — لو القراءة جوه itemBuilder بس، GetX
          // مش هيسجّلها كـ dependency.
          Get.find<SettingsController>().use24hFormat.value;
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
                  Text(FormatHelper.formatTime(att.date),
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

  String _buildMessage(Student s, String groupName, String teacherName) {
    final dateStr = DateFormat('yyyy-MM-dd', 'ar').format(DateTime.now());
    final buffer = StringBuffer()
      ..writeln('⚠️ *تنبيه غياب*')
      ..writeln('👤 ${s.name} (${s.code})')
      ..writeln('👥 $groupName')
      ..writeln('📅 $dateStr');
    if (teacherName.isNotEmpty) {
      buffer.writeln('👨‍🏫 $teacherName');
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
    final msg = _buildMessage(s, groupName, settings.teacherFullName.value.trim());
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

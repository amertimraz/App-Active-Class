// lib/views/attendance/attendance_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:active_class/controllers/qr_controller.dart';

import 'package:active_class/models/student_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/custom_dialogs.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/utils/helpers.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final AttendanceController controller = Get.put(AttendanceController());
  final StudentController studentController = Get.put(StudentController());
  final GroupController groupController = Get.put(GroupController());
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(() => setState(() {}));
    controller.loadAttendance();
    studentController.loadAllStudents().then((_) {
      controller.buildStudentMaps(studentController.students);
    });
    groupController.loadGroups();
    controller.ensureTodayDefault();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: buildGradientAppBar(
          title: 'سجل الحضور',
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'حضور اليوم'),
              Tab(text: 'السجلات السابقة'),
              Tab(text: 'الإحصائيات'),
              Tab(text: 'QR Scan'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await studentController.loadAllStudents();
                await groupController.loadGroups();
                await controller.loadAttendance();
                controller.buildStudentMaps(studentController.students);
              },
            ),
            IconButton(
              tooltip: 'اختيار التاريخ',
              icon: const Icon(Icons.calendar_today),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023, 1, 1),
                  lastDate: DateTime(2100, 12, 31),
                  initialDateRange: controller.dateRange.value,
                  helpText: 'اختر نطاق التاريخ',
                  saveText: 'تأكيد',
                );
                if (picked != null) {
                  controller.setDateRange(_asFullDayRange(picked));
                }
              },
            ),
            IconButton(
              tooltip: 'تصدير PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                await _exportTodayPdf(
                    context, controller, studentController, groupController);
              },
            ),
          ],
        ),
        body: Container(
          decoration: buildScreenBackground(context),
          child: Obx(() {
            if (controller.isLoading.value && controller.attendance.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              children: [
                _buildTodayTab(
                    context, controller, studentController, groupController),
                _buildRecordsTab(
                    context, controller, studentController, groupController),
                _buildStatisticsTab(
                    context, controller, studentController, groupController),
                _buildQRTab(
                    context, controller, studentController, groupController),
              ],
            );
          }),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () =>
              _showAddAttendanceDialog(context, controller, studentController),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildTodayTab(
    BuildContext context,
    AttendanceController controller,
    StudentController studentController,
    GroupController groupController,
  ) {
    final students = studentController.students;
    final groups = groupController.groups;
    final today = _todayRange();
    final expectedPerGroup =
        controller.getExpectedSessionsPerGroup(groups: groups, range: today);

    final presentIds = controller.attendance
        .where((a) =>
            a.status == ATTENDANCE_PRESENT &&
            !a.date.isBefore(today.start) &&
            !a.date.isAfter(today.end))
        .map((a) => a.studentId)
        .toSet();

    final groupsToday =
        groups.where((g) => (expectedPerGroup[g.id] ?? 0) > 0).toList();

    if (groupsToday.isEmpty) {
      return const EmptyState(
        icon: Icons.group,
        title: 'لا توجد مجموعات لها حصة اليوم',
        subtitle: 'تحقق من جدول المجموعات',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await studentController.loadAllStudents();
        await groupController.loadGroups();
        await controller.loadAttendance();
        controller.buildStudentMaps(studentController.students);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PADDING_NORMAL),
        itemCount: groupsToday.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final qr = Get.put(QRController());
            return Obx(() {
              final s = qr.scannedStudent.value;
              if (s == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: SPACING_NORMAL),
                child: Card(
                  color: Colors.green.withValues(alpha: 0.08),
                  child: ListTile(
                    leading:
                        const Icon(Icons.check_circle, color: Colors.green),
                    title: Text('آخر حضور: ${s.name}'),
                    subtitle: Text(
                        'المجموعة: ${groupController.groups.firstWhereOrNull((g) => g.id == s.groupId)?.name ?? '-'}'),
                  ),
                ),
              );
            });
          }
          final g = groupsToday[index - 1];
          final groupStudents =
              students.where((s) => s.groupId == g.id).toList();
          final present =
              groupStudents.where((s) => presentIds.contains(s.id)).toList();
          final absent =
              groupStudents.where((s) => !presentIds.contains(s.id)).toList();

          return Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(PADDING_NORMAL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(g.name,
                              style: Theme.of(context).textTheme.titleMedium)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          key: ValueKey(
                              '${present.length}/${groupStudents.length}'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                              '${present.length} / ${groupStudents.length}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (present.isNotEmpty) ...[
                    Text('الحاضرون',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: present
                          .map((s) => Chip(
                                avatar: const Text('✅'),
                                label: Text(s.name),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text('الغائبون',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  if (absent.isEmpty)
                    const Text('لا يوجد غياب حتى الآن')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: absent
                          .map((s) => Chip(
                                avatar: const Text('❌'),
                                label: Text(s.name),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordsTab(
    BuildContext context,
    AttendanceController controller,
    StudentController studentController,
    GroupController groupController,
  ) {
    if (controller.filteredAttendance.isEmpty) {
      return EmptyState(
        icon: Icons.event_note,
        title: 'لا توجد سجلات حضور',
        subtitle: 'ابدأ بتسجيل حضور الطلاب',
        actionLabel: 'تسجيل حضور',
        onActionPressed: () =>
            _showAddAttendanceDialog(context, controller, studentController),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(PADDING_NORMAL),
          child: Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(PADDING_NORMAL),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Obx(() {
                          final groups = groupController.groups;
                          return DropdownButtonFormField<int?>(
                            decoration:
                                const InputDecoration(labelText: 'المجموعة'),
                            initialValue: controller.groupFilter.value,
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('الكل')),
                              ...groups.map((g) => DropdownMenuItem<int?>(
                                  value: g.id, child: Text(g.name)))
                            ],
                            onChanged: (v) => controller.setGroupFilter(v),
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: 'الحالة'),
                          initialValue: controller.statusFilter.value.isEmpty
                              ? ''
                              : controller.statusFilter.value,
                          items: const [
                            DropdownMenuItem<String>(
                                value: '', child: Text('الكل')),
                            DropdownMenuItem<String>(
                                value: ATTENDANCE_PRESENT, child: Text('حاضر')),
                            DropdownMenuItem<String>(
                                value: ATTENDANCE_ABSENT, child: Text('غائب')),
                          ],
                          onChanged: (v) => controller.setStatusFilter(v ?? ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: 'ترتيب حسب'),
                          initialValue: controller.sortBy.value,
                          items: const [
                            DropdownMenuItem<String>(
                                value: 'date', child: Text('التاريخ')),
                            DropdownMenuItem<String>(
                                value: 'name', child: Text('الاسم')),
                          ],
                          onChanged: (v) => controller.setSorting(
                              by: v ?? 'date', asc: controller.sortAsc.value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Obx(() => IconButton(
                            tooltip:
                                controller.sortAsc.value ? 'تصاعدي' : 'تنازلي',
                            onPressed: () => controller.setSorting(
                                by: controller.sortBy.value,
                                asc: !controller.sortAsc.value),
                            icon: Icon(controller.sortAsc.value
                                ? Icons.arrow_upward
                                : Icons.arrow_downward),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
          child: CustomSearchBar(
            controller: _searchCtrl,
            hintText: 'ابحث بالاسم أو الكود...',
            onChanged: (_) => setState(() {}),
            onClear: () {
              _searchCtrl.clear();
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: SPACING_NORMAL),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await studentController.loadAllStudents();
              await groupController.loadGroups();
              await controller.loadAttendance();
              controller.buildStudentMaps(studentController.students);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _RecordsList(
                    search: () => _searchCtrl.text,
                    controller: controller,
                    studentController: studentController),
                const SizedBox(height: SPACING_XLARGE),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, AttendanceController controller) {
    final range = controller.dateRange.value;
    String label;
    if (range == null) {
      label = 'اختر نطاق التاريخ';
    } else {
      label =
          '${FormatHelper.formatDate(range.start)} → ${FormatHelper.formatDate(range.end)}';
    }

    return Padding(
      padding: const EdgeInsets.all(PADDING_NORMAL),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023, 1, 1),
                      lastDate: DateTime(2100, 12, 31),
                      initialDateRange: controller.dateRange.value,
                      helpText: 'اختر نطاق التاريخ',
                      saveText: 'تأكيد',
                    );
                    if (picked != null) {
                      controller.setDateRange(_asFullDayRange(picked));
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(label, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'إزالة الفلتر',
                onPressed: () => controller.setDateRange(null),
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
          const SizedBox(height: SPACING_NORMAL),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('اليوم'),
                  selected: _isTodayRange(controller.dateRange.value),
                  selectedColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.18),
                  side: BorderSide(
                    color: _isTodayRange(controller.dateRange.value)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                  onSelected: (_) => controller.setDateRange(_todayRange()),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('هذا الأسبوع'),
                  selected: _isThisWeekRange(controller.dateRange.value),
                  selectedColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.18),
                  side: BorderSide(
                    color: _isThisWeekRange(controller.dateRange.value)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                  onSelected: (_) => controller.setDateRange(_thisWeekRange()),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('هذا الشهر'),
                  selected: _isThisMonthRange(controller.dateRange.value),
                  selectedColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.18),
                  side: BorderSide(
                    color: _isThisMonthRange(controller.dateRange.value)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                  onSelected: (_) => controller.setDateRange(_thisMonthRange()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab(
    BuildContext context,
    AttendanceController controller,
    StudentController studentController,
    GroupController groupController,
  ) {
    final DateTimeRange? range = controller.dateRange.value;
    final students = studentController.students;
    final groups = groupController.groups;

    final summary = controller.getSummary(
      students: students,
      groups: groups,
      range: range,
    );

    final presentByStudent = controller.getPresentCountByStudent(range: range);
    final expectedPerGroup =
        controller.getExpectedSessionsPerGroup(groups: groups, range: range);

    final List<_StudentStats> perStudent = students.map((s) {
      final present = presentByStudent[s.id ?? -1] ?? 0;
      final expected = expectedPerGroup[s.groupId] ?? 0;
      final percent = expected == 0 ? 0.0 : (present / expected) * 100.0;
      return _StudentStats(
          student: s, present: present, expected: expected, percent: percent);
    }).toList();
    perStudent.sort((a, b) => a.percent.compareTo(b.percent));

    final today = _todayRange();
    final groupsToday = groups
        .where((g) =>
            (controller.getExpectedSessionsPerGroup(
                    groups: [g], range: today)[g.id] ??
                0) >
            0)
        .length;
    final totalStudents = students.length;
    final totalPresent = controller.attendance
        .where((a) =>
            a.status == ATTENDANCE_PRESENT &&
            !a.date.isBefore((range ?? today).start) &&
            !a.date.isAfter((range ?? today).end))
        .length;
    final totalExpected = summary.totalExpected;
    final totalAbsent =
        totalExpected > totalPresent ? (totalExpected - totalPresent) : 0;

    return Column(
      children: [
        _buildFilters(context, controller),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
          child: Row(
            children: [
              Expanded(
                child: _miniCard(
                  'مجموعات اليوم',
                  '$groupsToday',
                  icon: Icons.groups_2_outlined,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniCard(
                  'إجمالي الطلاب',
                  '$totalStudents',
                  icon: Icons.people_alt_outlined,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniCard(
                  'الحاضرون',
                  '$totalPresent',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniCard(
                  'الغائبون',
                  '$totalAbsent',
                  icon: Icons.highlight_off_rounded,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SPACING_NORMAL),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await studentController.loadAllStudents();
              await groupController.loadGroups();
              await controller.loadAttendance();
              controller.buildStudentMaps(studentController.students);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
              children: [
                Text('نسبة حضور الطلاب',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: SPACING_NORMAL),
                if (perStudent.isEmpty)
                  const EmptyState(
                    icon: Icons.people_outline,
                    title: 'لا توجد بيانات ضمن النطاق',
                    subtitle: 'غيّر نطاق التاريخ أو سجّل حضورًا',
                  )
                else
                  ...perStudent.map((e) => Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                              child: Text(e.student.name.isNotEmpty
                                  ? e.student.name[0]
                                  : '?')),
                          title: Text(e.student.name),
                          subtitle: Text('حاضر ${e.present} من ${e.expected}'),
                          trailing: Text(
                            FormatHelper.formatPercentage(e.percent),
                            style: TextStyle(
                              color: ColorHelper.getPercentageColor(e.percent),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )),
                const SizedBox(height: SPACING_XLARGE),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniCard(
    String title,
    String value, {
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRTab(
    BuildContext context,
    AttendanceController controller,
    StudentController studentController,
    GroupController groupController,
  ) {
    return _QRInlineTab(
        controller: controller,
        studentController: studentController,
        groupController: groupController);
  }

  static Widget _buildAttendanceCard(
    BuildContext context,
    Attendance attendance,
    AttendanceController controller,
    StudentController studentController,
  ) {
    final isPresent = attendance.status == ATTENDANCE_PRESENT;
    final statusColor = isPresent ? Colors.green : Colors.red;
    final statusText = isPresent ? ATTENDANCE_PRESENT : ATTENDANCE_ABSENT;

    Student? student;
    for (final s in studentController.students) {
      if (s.id == attendance.studentId) {
        student = s;
        break;
      }
    }
    final displayName = student?.name ?? 'طالب';
    final initial = displayName.isNotEmpty ? displayName[0] : '?';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: SPACING_SMALL),
      child: ListTile(
        dense: true,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(child: Text(initial)),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(displayName),
        subtitle: Text('التاريخ: ${FormatHelper.formatDate(attendance.date)}'),
        trailing: Chip(
          label: Text(statusText,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          labelStyle: TextStyle(color: statusColor),
          side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
          backgroundColor: statusColor.withValues(alpha: 0.08),
          shape: StadiumBorder(
              side: BorderSide(color: statusColor.withValues(alpha: 0.2))),
        ),
      ),
    );
  }

  void _showAddAttendanceDialog(
    BuildContext context,
    AttendanceController controller,
    StudentController studentController,
  ) {
    SelectDialog.show(
      context,
      title: 'اختر الطالب',
      items: studentController.students
          .map((s) => {'id': s.id, 'name': s.name})
          .toList(),
      onSelected: (item) {
        final studentId = item['id'] as int;
        controller.addAttendance(
          Attendance(
            studentId: studentId,
            date: DateTime.now(),
            status: ATTENDANCE_PRESENT,
          ),
        );
      },
    );
  }
}

class _RecordsList extends StatelessWidget {
  final String Function() search;
  final AttendanceController controller;
  final StudentController studentController;
  const _RecordsList(
      {required this.search,
      required this.controller,
      required this.studentController});
  @override
  Widget build(BuildContext context) {
    final q = search().toLowerCase();
    final list = controller.filteredAttendance.where((a) {
      if (q.isEmpty) return true;
      final s = studentController.students
          .firstWhereOrNull((st) => st.id == a.studentId);
      final name = s?.name.toLowerCase() ?? '';
      final code = s?.code.toLowerCase() ?? '';
      return name.contains(q) || code.contains(q);
    }).toList();
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(PADDING_NORMAL),
        child: EmptyState(
            icon: Icons.search,
            title: 'لا نتائج',
            subtitle: 'حاول تعديل البحث أو الفلاتر'),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final attendance = list[index];
        return _AttendancePageState._buildAttendanceCard(
            context, attendance, controller, studentController);
      },
    );
  }
}

class _StudentStats {
  final Student student;
  final int present;
  final int expected;
  final double percent;
  _StudentStats(
      {required this.student,
      required this.present,
      required this.expected,
      required this.percent});
}

class _QRInlineTab extends StatefulWidget {
  final AttendanceController controller;
  final StudentController studentController;
  final GroupController groupController;
  const _QRInlineTab(
      {required this.controller,
      required this.studentController,
      required this.groupController});
  @override
  State<_QRInlineTab> createState() => _QRInlineTabState();
}

class _QRInlineTabState extends State<_QRInlineTab> {
  late MobileScannerController scannerController;
  final QRController qr = Get.put(QRController());
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    scannerController = MobileScannerController();
    qr.mode.value = QRMode.attendance;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await widget.controller.loadAttendance();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayRange();
    final presentToday = widget.controller.attendance
        .where((a) =>
            a.status == ATTENDANCE_PRESENT &&
            !a.date.isBefore(today.start) &&
            !a.date.isAfter(today.end))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: MobileScanner(
            controller: scannerController,
            onDetect: (capture) {
              final v = capture.barcodes.first.rawValue;
              if (v != null) qr.handleScan(v);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(PADDING_NORMAL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                  icon: const Icon(Icons.flash_on),
                  onPressed: () => scannerController.toggleTorch()),
              IconButton(
                  icon: const Icon(Icons.flip_camera_ios),
                  onPressed: () => scannerController.switchCamera()),
            ],
          ),
        ),
        if (qr.scannedStudent.value != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
            child: Card(
              color: Colors.green.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text('آخر حضور: ${qr.scannedStudent.value!.name}'),
                subtitle: Text(
                    'المجموعة: ${widget.groupController.groups.firstWhereOrNull((g) => g.id == qr.scannedStudent.value!.groupId)?.name ?? '-'}'),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
            itemCount: presentToday.length,
            itemBuilder: (context, index) {
              final att = presentToday[index];
              final s = widget.studentController.students
                  .firstWhereOrNull((st) => st.id == att.studentId);
              return ListTile(
                leading: const Icon(Icons.check, color: Colors.green),
                title: Text(s?.name ?? 'طالب'),
                subtitle: Text(FormatHelper.formatTime(att.date)),
              );
            },
          ),
        )
      ],
    );
  }
}

Future<void> _exportTodayPdf(
    BuildContext context,
    AttendanceController controller,
    StudentController studentController,
    GroupController groupController) async {
  final pdf = pw.Document();
  final today = _todayRange();
  final dateLabel = DateFormat('yyyy-MM-dd').format(today.start);
  final students = studentController.students;
  final groups = groupController.groups;
  final presentIds = controller.attendance
      .where((a) =>
          a.status == ATTENDANCE_PRESENT &&
          !a.date.isBefore(today.start) &&
          !a.date.isAfter(today.end))
      .map((a) => a.studentId)
      .toSet();
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) {
        return [
          pw.Text('سجل الحضور - $dateLabel',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          ...groups.map((g) {
            final groupStudents =
                students.where((s) => s.groupId == g.id).toList();
            final rows = <pw.TableRow>[
              pw.TableRow(children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('الطالب')),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('الحالة'))
              ])
            ];
            for (final s in groupStudents) {
              final present = presentIds.contains(s.id);
              rows.add(
                pw.TableRow(children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(s.name)),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(present ? 'حاضر' : 'غائب')),
                ]),
              );
            }
            return pw.Column(children: [
              pw.Text(g.name,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(border: pw.TableBorder.all(width: 0.5), children: rows),
              pw.SizedBox(height: 12),
            ]);
          })
        ];
      },
    ),
  );
  final bytes = await pdf.save();
  await Printing.sharePdf(bytes: bytes, filename: 'attendance_$dateLabel.pdf');
}

// ======== Date helpers ========
DateTimeRange _todayRange() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return DateTimeRange(start: start, end: end);
}

bool _isTodayRange(DateTimeRange? r) {
  if (r == null) return false;
  final t = _todayRange();
  return r.start.year == t.start.year &&
      r.start.month == t.start.month &&
      r.start.day == t.start.day &&
      r.end.year == t.end.year &&
      r.end.month == t.end.month &&
      r.end.day == t.end.day;
}

DateTimeRange _thisWeekRange() {
  final now = DateTime.now();
  final start = now.subtract(Duration(days: now.weekday - 1));
  final weekStart = DateTime(start.year, start.month, start.day);
  final weekEnd = weekStart.add(const Duration(days: 6));
  final end = DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);
  return DateTimeRange(start: weekStart, end: end);
}

bool _isThisWeekRange(DateTimeRange? r) {
  if (r == null) return false;
  final w = _thisWeekRange();
  return r.start == w.start && r.end == w.end;
}

DateTimeRange _thisMonthRange() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final nextMonth = DateTime(now.year, now.month + 1, 1);
  final endDay = nextMonth.subtract(const Duration(days: 1));
  final end = DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59);
  return DateTimeRange(start: start, end: end);
}

bool _isThisMonthRange(DateTimeRange? r) {
  if (r == null) return false;
  final m = _thisMonthRange();
  return r.start == m.start && r.end == m.end;
}

DateTimeRange _asFullDayRange(DateTimeRange r) {
  final s = DateTime(r.start.year, r.start.month, r.start.day);
  final e = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
  return DateTimeRange(start: s, end: e);
}

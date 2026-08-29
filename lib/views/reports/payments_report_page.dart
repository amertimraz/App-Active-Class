// lib/views/reports/payments_report_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:active_class/controllers/settings_controller.dart';

class PaymentsReportPage extends StatefulWidget {
  const PaymentsReportPage({super.key});

  @override
  State<PaymentsReportPage> createState() => _PaymentsReportPageState();
}

class _PaymentsReportPageState extends State<PaymentsReportPage> {
  final PaymentController paymentController = Get.put(PaymentController());
  final GroupController groupController = Get.put(GroupController());
  final StudentController studentController = Get.put(StudentController());
  final AttendanceController attendanceController =
      Get.isRegistered<AttendanceController>()
          ? Get.find<AttendanceController>()
          : Get.put(AttendanceController());

  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    paymentController.selectedMonth.value ??= DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    paymentController.loadPayments();
    studentController.loadAllStudents();
    groupController.loadGroups();
    attendanceController.loadAttendance();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير المدفوعات'),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await paymentController.loadPayments();
                await studentController.loadAllStudents();
                await groupController.loadGroups();
              },
            ),
          ],
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'تقرير شهري'),
              Tab(text: 'تقرير يومي'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMonthlyReport(),
            _buildDailyReport(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyReport() {
    return Obx(() {
      final month = paymentController.selectedMonth.value ?? DateTime.now();
      final dateFmt = DateFormat('MMMM yyyy', 'ar');

      final List<Student> students = List.of(studentController.students);
      final List<Group> groups = List.of(groupController.groups);
      final Map<int, Group> groupById = {
        for (final g in groups)
          if (g.id != null) g.id!: g
      };

      final DateTime monthEnd = DateTime(month.year, month.month + 1, 0);

      final List<Student> consideredStudents = students.where((s) {
        final DateTime? start = s.attendanceStart ?? s.createdAt;
        if (start == null) return true;
        return !start.isAfter(monthEnd);
      }).toList();

      // إجمالي كل مدفوعات الطالب (بغض النظر عن تاريخها) مقابل إجمالي
      // المستحق من شهر انضمامه لحد الشهر المختار — نفس منطق المديونية
      // المتراكمة (PricingHelper) المستخدم في باقي التطبيق، بدل مقارنة
      // مدفوعات الشهر ده بس بمستحق الشهر ده بس (كان بيوهم إن طالب دافع
      // مقدَّمًا "لسه مايدفعش"، وطالب سدد شهر قديم بمبلغ كبير "دافع بالكامل"
      // وهو لسه عليه شهر تاني).
      final Map<int, double> paidByStudent = {};
      for (final p in paymentController.payments) {
        paidByStudent.update(p.studentId, (v) => v + p.amount,
            ifAbsent: () => p.amount);
      }

      // Separate exempt vs non-exempt students
      final List<Student> exemptStudents =
          consideredStudents.where((s) => s.isExempt).toList();
      final List<Student> nonExemptStudents =
          consideredStudents.where((s) => !s.isExempt).toList();

      double totalDueAll = 0;
      double totalPaidAll = 0;
      int totalStudents = nonExemptStudents.length;
      int fullyPaidCountAll = 0;

      final List<Student> unpaidStudents = [];

      for (final s in nonExemptStudents) {
        // بيستخدم PricingHelper بدل effectivePrice مباشرة عشان مجموعات
        // "بالحصة" تُحسَب بعدد الحصص المحضورة فعليًا الشهر ده.
        final due = PricingHelper.totalDueThrough(
            student: s,
            group: groupById[s.groupId],
            month: month,
            allAttendance: attendanceController.attendance,
            siblingGroupMembers: students);
        final paid = paidByStudent[s.id ?? -1] ?? 0.0;
        totalDueAll += due;
        totalPaidAll += paid;
        if (paid >= due && due > 0) {
          fullyPaidCountAll++;
        } else if (due > 0 && paid < due) {
          unpaidStudents.add(s);
        }
      }

      final remainingAll =
          (totalDueAll - totalPaidAll).clamp(0.0, double.infinity).toDouble();
      final progressAll = totalDueAll > 0 ? (totalPaidAll / totalDueAll) : 0.0;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(PADDING_NORMAL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(PADDING_NORMAL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _pickMonth(context, month);
                            if (picked != null) {
                              paymentController.setMonth(
                                  DateTime(picked.year, picked.month, 1));
                            }
                          },
                          icon: const Icon(Icons.calendar_month),
                          label: Text(dateFmt.format(month)),
                        ),
                      ],
                    ),
                    const SizedBox(height: SPACING_NORMAL),
                    _ProgressBar(
                        value: progressAll,
                        label:
                            'التقدم العام: ${FormatHelper.formatPercentage(progressAll * 100)}'),
                    const SizedBox(height: 8),
                    _SummaryStats(
                      totalStudents: totalStudents,
                      totalDue: totalDueAll,
                      totalPaid: totalPaidAll,
                      fullyPaidCount: fullyPaidCountAll,
                      unpaidCount: (totalStudents - fullyPaidCountAll)
                          .clamp(0, totalStudents),
                      remaining: remainingAll,
                      onTapUnpaid: () => _showUnpaidDialog(
                        context,
                        month,
                        unpaidStudents,
                        groupById,
                        paidByStudent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Exempt students card ──────────────────────────
            if (exemptStudents.isNotEmpty) ...[
              const SizedBox(height: SPACING_NORMAL),
              _ExemptStudentsCard(
                students: exemptStudents,
                groupById: groupById,
              ),
            ],

            const SizedBox(height: SPACING_NORMAL),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(PADDING_NORMAL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.groups_2),
                        SizedBox(width: 8),
                        Text('المجموعات'),
                      ],
                    ),
                    const Divider(height: 20),
                    ...groups.map((g) {
                      final groupStudents = consideredStudents
                          .where((s) => s.groupId == g.id)
                          .toList();
                      double groupDue = 0;
                      double groupPaid = 0;
                      int groupFullyPaid = 0;
                      for (final s in groupStudents) {
                        if (s.isFullyExempt) continue; // لا يُحسب في المطلوب
                        final due = PricingHelper.totalDueThrough(
                            student: s,
                            group: g,
                            month: month,
                            allAttendance: attendanceController.attendance,
                            siblingGroupMembers: students);
                        final paid = paidByStudent[s.id ?? -1] ?? 0.0;
                        groupDue += due;
                        groupPaid += paid;
                        if (paid >= due && due > 0) groupFullyPaid++;
                      }
                      final groupUnpaid = groupStudents.where((s) {
                        if (s.isFullyExempt) return false;
                        final due = PricingHelper.totalDueThrough(
                            student: s,
                            group: g,
                            month: month,
                            allAttendance: attendanceController.attendance,
                            siblingGroupMembers: students);
                        final paid = paidByStudent[s.id ?? -1] ?? 0.0;
                        return due > 0 && paid < due;
                      }).toList();
                      final groupRemaining = (groupDue - groupPaid)
                          .clamp(0.0, double.infinity)
                          .toDouble();
                      final groupProgress =
                          groupDue > 0 ? (groupPaid / groupDue) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _GroupRow(
                          groupName: g.name,
                          studentCount: groupStudents.length,
                          progress: groupProgress,
                          totalDue: groupDue,
                          totalPaid: groupPaid,
                          fullyPaidCount: groupFullyPaid,
                          unpaidCount: (groupStudents.length - groupFullyPaid)
                              .clamp(0, groupStudents.length),
                          remaining: groupRemaining,
                          onTapUnpaid: () => _showUnpaidDialog(context, month,
                              groupUnpaid, groupById, paidByStudent),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<DateTime?> _pickMonth(BuildContext context, DateTime initial) async {
    int year = initial.year;
    return await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      onPressed: () => setState(() => year--),
                      icon: const Icon(Icons.chevron_right)),
                  Text('اختر الشهر - $year'),
                  IconButton(
                      onPressed: () => setState(() => year++),
                      icon: const Icon(Icons.chevron_left)),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.4),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final m = index + 1;
                    final label =
                        DateFormat('MMMM', 'ar').format(DateTime(2000, m, 1));
                    return OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(DateTime(year, m, 1)),
                      child: Text(label),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDailyReport() {
    return Obx(() {
      // قراءة مباشرة هنا عشان القائمة تتحدّث لما نظام الساعة 12/24 يتغيّر
      // من الإعدادات — القراءة جوه itemBuilder بس مش بتتسجل كـ dependency.
      Get.find<SettingsController>().use24hFormat.value;
      final payments = paymentController.payments
          .where((p) =>
              p.date.year == _selectedDay.year &&
              p.date.month == _selectedDay.month &&
              p.date.day == _selectedDay.day)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final studentById = {
        for (final s in studentController.students)
          if (s.id != null) s.id!: s
      };
      final groupById = {
        for (final g in groupController.groups)
          if (g.id != null) g.id!: g
      };

      final total = payments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final dateLabel = DateFormat('d MMMM yyyy', 'ar').format(_selectedDay);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(PADDING_NORMAL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(PADDING_NORMAL),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDay,
                          firstDate: DateTime(2020, 1, 1),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          helpText: 'اختر اليوم',
                        );
                        if (picked != null) {
                          setState(() => _selectedDay =
                              DateTime(picked.year, picked.month, picked.day));
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(dateLabel),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                        label: Text(
                            'إجمالي اليوم: ${FormatHelper.formatCurrency(total)}')),
                    Chip(label: Text('عدد الدفعات: ${payments.length}')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SPACING_NORMAL),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(PADDING_NORMAL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.payments),
                        SizedBox(width: 8),
                        Text('مدفوعات اليوم'),
                      ],
                    ),
                    const Divider(height: 20),
                    if (payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child:
                            Center(child: Text('لا توجد مدفوعات في هذا اليوم')),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: payments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = payments[index];
                          final student = studentById[p.studentId];
                          final group = student != null
                              ? groupById[student.groupId]
                              : null;
                          return ListTile(
                            leading: const Icon(Icons.payment),
                            title: Text(student?.name ?? 'طالب غير معروف'),
                            subtitle: Text(
                                '${group?.name ?? 'غير محدد'} • ${FormatHelper.formatPaymentDate(p.date)}'),
                            trailing:
                                Text(FormatHelper.formatCurrency(p.amount)),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final String label;
  const _ProgressBar({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: v,
          minHeight: 8,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _SummaryStats extends StatefulWidget {
  final int totalStudents;
  final double totalDue;
  final double totalPaid;
  final int fullyPaidCount;
  final int unpaidCount;
  final double remaining;
  final VoidCallback? onTapUnpaid;
  const _SummaryStats({
    required this.totalStudents,
    required this.totalDue,
    required this.totalPaid,
    required this.fullyPaidCount,
    required this.unpaidCount,
    required this.remaining,
    this.onTapUnpaid,
  });

  @override
  State<_SummaryStats> createState() => _SummaryStatsState();
}

class _SummaryStatsState extends State<_SummaryStats> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => setState(() => expanded = !expanded),
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(expanded ? 'طي الملخص' : 'عرض تفاصيل سريعة'),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _grid(),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _grid() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _miniStat('عدد الطلاب', widget.totalStudents.toString(),
            Icons.people_alt, Colors.blueGrey),
        _miniStat('المطلوب', FormatHelper.formatCurrency(widget.totalDue),
            Icons.request_page, Colors.orange),
        _miniStat('المدفوع', FormatHelper.formatCurrency(widget.totalPaid),
            Icons.attach_money, Colors.green),
        _miniStat('مدفوعين بالكامل', widget.fullyPaidCount.toString(),
            Icons.verified, Colors.teal),
        _miniStat('غير مدفوعين', widget.unpaidCount.toString(), Icons.pending,
            Colors.red,
            onTap: widget.onTapUnpaid),
        _miniStat('المتبقي', FormatHelper.formatCurrency(widget.remaining),
            Icons.account_balance_wallet, Colors.purple),
      ],
    );
  }

  Widget _miniStat(String title, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

class _GroupRow extends StatefulWidget {
  final String groupName;
  final int studentCount;
  final double progress;
  final double totalDue;
  final double totalPaid;
  final int fullyPaidCount;
  final int unpaidCount;
  final double remaining;
  final VoidCallback? onTapUnpaid;
  const _GroupRow({
    required this.groupName,
    required this.studentCount,
    required this.progress,
    required this.totalDue,
    required this.totalPaid,
    required this.fullyPaidCount,
    required this.unpaidCount,
    required this.remaining,
    this.onTapUnpaid,
  });

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.groupName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${widget.studentCount} طالب',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                      value: widget.progress.clamp(0.0, 1.0), minHeight: 6),
                  const SizedBox(height: 4),
                  Text(
                      'التقدم: ${FormatHelper.formatPercentage(widget.progress * 100)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => expanded = !expanded),
              icon: Icon(expanded ? Icons.unfold_less : Icons.unfold_more),
              tooltip: expanded ? 'طي' : 'فرد',
            ),
          ],
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _mini('المطلوب', FormatHelper.formatCurrency(widget.totalDue),
                    Colors.orange),
                _mini('المدفوع', FormatHelper.formatCurrency(widget.totalPaid),
                    Colors.green),
                _mini('المتبقي', FormatHelper.formatCurrency(widget.remaining),
                    Colors.purple),
                _mini('مدفوعين بالكامل', widget.fullyPaidCount.toString(),
                    Colors.teal),
                _mini('غير مدفوعين', widget.unpaidCount.toString(), Colors.red,
                    onTap: widget.onTapUnpaid),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _mini(String title, String value, Color color, {VoidCallback? onTap}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

extension on _PaymentsReportPageState {
  void _showUnpaidDialog(
    BuildContext context,
    DateTime month,
    List<Student> unpaid,
    Map<int, Group> groupById,
    Map<int, double> paidByStudent,
  ) {
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(month);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('غير المدفوعين - $monthLabel'),
          content: SizedBox(
            width: 520,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: unpaid.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = unpaid[i];
                final g = groupById[s.groupId];
                final paid = paidByStudent[s.id ?? -1] ?? 0.0;
                final due = PricingHelper.totalDueThrough(
                    student: s,
                    group: g,
                    month: month,
                    allAttendance: attendanceController.attendance,
                    siblingGroupMembers: Get.isRegistered<StudentController>()
                        ? Get.find<StudentController>().students
                        : null);
                final remaining =
                    (due - paid).clamp(0.0, double.infinity).toDouble();
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.person),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                                'الكود: ${s.code} • المجموعة: ${g?.name ?? '-'}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(FormatHelper.formatCurrency(remaining),
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                          _WhatsButton(
                              student: s,
                              groupName: g?.name ?? '-',
                              monthLabel: monthLabel,
                              remaining: remaining),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إغلاق')),
          ],
        );
      },
    );
  }
}

class _WhatsButton extends StatelessWidget {
  final Student student;
  final String groupName;
  final String monthLabel;
  final double remaining;
  const _WhatsButton(
      {required this.student,
      required this.groupName,
      required this.monthLabel,
      required this.remaining});

  @override
  Widget build(BuildContext context) {
    final phone = (student.guardianPhone ?? '').trim();
    final enabled = phone.isNotEmpty;
    return IconButton(
      tooltip: enabled ? 'إرسال تذكير واتساب' : 'لا يوجد رقم',
      icon: const Icon(Icons.chat, color: Colors.green),
      onPressed: !enabled
          ? null
          : () async {
              final settings = Get.find<SettingsController>();
              String normalize(String input, String defaultDial) {
                var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
                if (p.startsWith('+')) p = p.substring(1);
                if (p.startsWith('00')) p = p.substring(2);
                if (p.startsWith(defaultDial)) return p;
                if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
                p = p.replaceFirst(RegExp(r'^0+'), '');
                return defaultDial + p;
              }

              final dial = settings.countryDial.value;
              final phoneNorm = normalize(phone, dial);
              final msg =
                  'تذكير برسوم شهر $monthLabel للطالب ${student.name} (الكود: ${student.code}) في مجموعة $groupName. المتبقي: ${FormatHelper.formatCurrency(remaining)}';
              final uri = Uri.parse(
                  'https://wa.me/$phoneNorm?text=${Uri.encodeComponent(msg)}');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _ExemptStudentsCard — بطاقة الطلاب المعفيين في التقرير
// ══════════════════════════════════════════════════════════════════
class _ExemptStudentsCard extends StatefulWidget {
  const _ExemptStudentsCard({
    required this.students,
    required this.groupById,
  });
  final List<Student> students;
  final Map<int, Group> groupById;

  @override
  State<_ExemptStudentsCard> createState() => _ExemptStudentsCardState();
}

class _ExemptStudentsCardState extends State<_ExemptStudentsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const exemptColor = Color(0xFF2E7D32);
    final fullCount = widget.students.where((s) => s.isFullyExempt).length;
    final partialCount = widget.students.length - fullCount;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: exemptColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              color: exemptColor.withValues(alpha: 0.07),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: exemptColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.volunteer_activism_rounded,
                        color: exemptColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الطلاب المعفيون  (${widget.students.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: exemptColor,
                          ),
                        ),
                        Text(
                          '${fullCount > 0 ? "$fullCount إعفاء كامل" : ""}${fullCount > 0 && partialCount > 0 ? " • " : ""}${partialCount > 0 ? "$partialCount إعفاء جزئي" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            color: exemptColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: exemptColor,
                  ),
                ],
              ),
            ),
          ),

          // Expanded list
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0x332E7D32)),
            ...widget.students.map((s) {
              final group = widget.groupById[s.groupId];
              final groupColor =
                  group?.color != null ? Color(group!.color!) : Colors.grey;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: exemptColor.withValues(alpha: 0.1),
                  radius: 18,
                  child: Text(
                    s.name.trim().isNotEmpty ? s.name.trim()[0] : '?',
                    style: const TextStyle(
                      color: exemptColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                title: Text(s.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Row(
                  children: [
                    if (group != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: groupColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          group.name,
                          style: TextStyle(
                              color: groupColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (s.exemptReason != null && s.exemptReason!.isNotEmpty)
                      Text(
                        s.exemptReason!,
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.5)),
                      ),
                  ],
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.isFullyExempt
                        ? exemptColor.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: s.isFullyExempt
                          ? exemptColor.withValues(alpha: 0.4)
                          : Colors.orange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    s.isFullyExempt ? 'كامل' : '${s.exemptPercent.toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: s.isFullyExempt ? exemptColor : Colors.orange,
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

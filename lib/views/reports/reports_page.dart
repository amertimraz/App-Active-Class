import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/report_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ReportController reportController = Get.put(ReportController());
  final GroupController groupController = Get.put(GroupController());
  final StudentController studentController = Get.put(StudentController());

  @override
  void initState() {
    super.initState();
    reportController.loadReports();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final summaryCrossAxisCount = width > 980 ? 3 : 2;
    return Scaffold(
      appBar: buildGradientAppBar(
        title: 'التقارير والسجلات',
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: () => reportController.exportPDF(),
          ),
        ],
      ),
      body: Container(
        decoration: buildScreenBackground(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PADDING_NORMAL),
          child: Obx(() {
            return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ملخص عام',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: SPACING_NORMAL),
              GridView.count(
                crossAxisCount: summaryCrossAxisCount,
                crossAxisSpacing: SPACING_NORMAL,
                mainAxisSpacing: SPACING_NORMAL,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatsCard(
                    title: 'عدد المجموعات',
                    value: reportController.totalGroups.value.toString(),
                    icon: Icons.group,
                    color: AppTheme.primaryColor,
                  ),
                  StatsCard(
                    title: 'عدد الطلاب',
                    value: reportController.totalStudents.value.toString(),
                    icon: Icons.person,
                    color: Colors.green,
                  ),
                  StatsCard(
                    title: 'إجمالي المدفوعات',
                    value: '${reportController.totalPayments.value.toStringAsFixed(2)} ج.م',
                    icon: Icons.attach_money,
                    color: Colors.blue,
                  ),
                  StatsCard(
                    title: 'عدد المدفوعات',
                    value: reportController.paymentCount.value.toString(),
                    icon: Icons.receipt_long,
                    color: Colors.teal,
                  ),
                  StatsCard(
                    title: 'إجمالي الحضور',
                    value: reportController.totalAttendance.value.toString(),
                    icon: Icons.event_available,
                    color: Colors.purple,
                  ),
                  StatsCard(
                    title: 'نسبة الحضور',
                    value: '${reportController.attendancePercentage.value.toStringAsFixed(1)}%',
                    icon: Icons.check_circle,
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: SPACING_LARGE),
              Text(
                'تقارير تفصيلية',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: SPACING_NORMAL),
              _buildReportCard(
                context: context,
                title: 'تقرير المجموعات',
                icon: Icons.groups_2,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    groupController.groups.length,
                    (index) {
                      final group = groupController.groups[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(group.name),
                            FutureBuilder<int>(
                              future: groupController.getGroupStudentCount(group.id!),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$count طالب',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: SPACING_NORMAL),
              _buildReportCard(
                context: context,
                title: 'آخر المدفوعات',
                icon: Icons.payments,
                content: Column(
                  children: reportController.recentPayments.map((p) {
                    final matches = studentController.students.where((s) => s.id == p.studentId);
                    final studentName = matches.isNotEmpty ? matches.first.name : '#${p.studentId}';
                    final dateStr = p.date.toLocal().toString().split('T').first;
                    return ListCard(
                      title: studentName,
                      subtitle: dateStr,
                      trailing: '${p.amount.toStringAsFixed(2)} ج.م',
                      icon: Icons.attach_money,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: SPACING_NORMAL),
              _buildReportCard(
                context: context,
                title: 'سجل الحضور الأخير',
                icon: Icons.history,
                content: Column(
                  children: reportController.recentAttendance.map((a) {
                    final matches = studentController.students.where((s) => s.id == a.studentId);
                    final studentName = matches.isNotEmpty ? matches.first.name : '#${a.studentId}';
                    final dateStr = a.date.toLocal().toString().split('T').first;
                    return ListCard(
                      title: studentName,
                      subtitle: dateStr,
                      trailing: a.status,
                      icon: a.status == 'حاضر' ? Icons.check_circle : Icons.cancel,
                    );
                  }).toList(),
                ),
              ),
            ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(PADDING_NORMAL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const Divider(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}

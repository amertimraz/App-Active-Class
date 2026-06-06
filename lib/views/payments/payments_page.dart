// lib/views/payments/payments_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/payment_model.dart' show Payment;
import 'package:active_class/models/student_model.dart' show Student;
import 'package:active_class/models/group_model.dart' show Group;
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/custom_dialogs.dart' as custom_dialogs;
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/utils/helpers.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final PaymentController controller = Get.put(PaymentController());
  final StudentController studentController = Get.put(StudentController());
  final GroupController groupController = Get.put(GroupController());

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    controller.loadPayments();
    studentController.loadAllStudents();
    groupController.loadGroups();
    final now = DateTime.now();
    controller.selectedMonth.value ??= DateTime(now.year, now.month, 1);
    _searchController = TextEditingController(text: controller.searchName.value);
    _searchController.addListener(() {
      controller.filterByStudentName(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(
        title: 'المدفوعات',
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await controller.loadPayments();
              await studentController.loadAllStudents();
              await groupController.loadGroups();
            },
          ),
        ],
      ),
      body: Container(
        decoration: buildScreenBackground(context),
        child: Obx(() {
          final studentById = {
            for (final s in studentController.students)
              if (s.id != null) s.id!: s
          };
          final groupById = {
            for (final g in groupController.groups)
              if (g.id != null) g.id!: g
          };

        controller.bindStudentNameResolver((id) => studentById[id]?.name);

        final DateTime month = controller.selectedMonth.value!;
        final int? selectedGroupId = controller.selectedGroupId.value;
        final String selectedStatus = controller.statusFilter.value;

        final List<Student> scopedStudents = studentController.students
            .where((s) => selectedGroupId == null || s.groupId == selectedGroupId)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        final List<Payment> monthlyPayments = controller.payments
            .where((p) => p.date.year == month.year && p.date.month == month.month)
            .toList();

        final Map<int, double> paidByStudent = {};
        for (final p in monthlyPayments) {
          paidByStudent.update(p.studentId, (v) => v + p.amount, ifAbsent: () => p.amount);
        }

        final rows = <_StudentMonthRow>[];
        for (final s in scopedStudents) {
          final paid = paidByStudent[s.id!] ?? 0.0;
          final due = s.price;
          final remaining = (due - paid).clamp(0.0, double.infinity).toDouble();
          final status = due <= 0
              ? 'مُعفى'
              : paid >= due
                  ? 'مدفوع بالكامل'
                  : paid > 0
                      ? 'جزئي'
                      : 'متأخر';
          if (selectedStatus != 'الكل' && status != selectedStatus) continue;
          rows.add(_StudentMonthRow(
            student: s,
            group: groupById[s.groupId],
            month: month,
            due: due,
            paid: paid,
            remaining: remaining,
            status: status,
          ));
        }

        final totalPaidInScope = rows.fold<double>(0.0, (sum, r) => sum + r.paid);
        final fullyPaidCount =
            rows.where((r) => r.status == 'مدفوع بالكامل').length;
        final partialCount = rows.where((r) => r.status == 'جزئي').length;
        final lateCount = rows.where((r) => r.status == 'متأخر').length;
        final dateFmt = DateFormat('MMMM yyyy', 'ar');

          return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(PADDING_NORMAL),
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(PADDING_NORMAL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withValues(alpha: 0.16),
                              Colors.green.withValues(alpha: 0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.attach_money, color: Colors.green),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'إجمالي المدفوعات للشهر المحدد',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    FormatHelper.formatCurrency(totalPaidInScope),
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricPill(
                            label: 'مدفوع بالكامل',
                            value: fullyPaidCount.toString(),
                            color: Colors.green,
                            icon: Icons.check_circle_outline,
                          ),
                          _MetricPill(
                            label: 'جزئي',
                            value: partialCount.toString(),
                            color: Colors.orange,
                            icon: Icons.timelapse_rounded,
                          ),
                          _MetricPill(
                            label: 'متأخر',
                            value: lateCount.toString(),
                            color: Colors.red,
                            icon: Icons.warning_amber_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: SPACING_NORMAL),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'تختلف الأسعار حسب المجموعة ويمكن تعيين سعر مخصص لكل طالب. تعكس الحالة المدفوعة مقارنة بالسعر الشهري.',
                          textAlign: TextAlign.start,
                        ),
                      ),
                      const SizedBox(height: SPACING_NORMAL),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 260,
                            child: CustomSearchBar(
                              controller: _searchController,
                              hintText: 'ابحث باسم الطالب...',
                              onChanged: controller.filterByStudentName,
                              onClear: () {
                                _searchController.clear();
                                controller.filterByStudentName('');
                              },
                            ),
                          ),
                          DropdownButton<int?>(
                            hint: const Text('اختر المجموعة'),
                            value: selectedGroupId,
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('كل المجموعات')),
                              ...groupController.groups.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.name))),
                            ],
                            onChanged: (v) => controller.setGroupFilter(v),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: month,
                                firstDate: DateTime(2020, 1, 1),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                helpText: 'اختر تاريخًا داخل الشهر',
                              );
                              if (picked != null) {
                                controller.setMonth(DateTime(picked.year, picked.month, 1));
                              }
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: Text(dateFmt.format(month)),
                          ),
                          DropdownButton<String>(
                            value: selectedStatus,
                            items: const [
                              DropdownMenuItem(value: 'الكل', child: Text('كل الحالات')),
                              DropdownMenuItem(value: 'مدفوع بالكامل', child: Text('مدفوع بالكامل')),
                              DropdownMenuItem(value: 'جزئي', child: Text('جزئي')),
                              DropdownMenuItem(value: 'متأخر', child: Text('متأخر')),
                              DropdownMenuItem(value: 'مُعفى', child: Text('مُعفى')),
                            ],
                            onChanged: (v) => controller.setStatusFilter(v ?? 'الكل'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: EmptyState(
                            icon: Icons.payment,
                            title: 'لا توجد سجلات لهذا الشهر',
                            subtitle: 'عدّل المرشحات أو سجّل دفعة جديدة',
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 800),
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('الطالب')),
                                DataColumn(label: Text('المجموعة')),
                                DataColumn(label: Text('الشهر')),
                                DataColumn(label: Text('السعر المستحق')),
                                DataColumn(label: Text('المدفوع')),
                                DataColumn(label: Text('المتبقي')),
                                DataColumn(label: Text('الحالة')),
                                DataColumn(label: Text('إجراءات')),
                              ],
                              rows: rows.map((r) {
                                final statusColor = _statusColor(r.status);
                                return DataRow(cells: [
                                  DataCell(Text(r.student.name)),
                                  DataCell(Text(r.group?.name ?? 'غير محدد')),
                                  DataCell(Text(dateFmt.format(r.month))),
                                  DataCell(Text(FormatHelper.formatCurrency(r.due))),
                                  DataCell(Text(FormatHelper.formatCurrency(r.paid))),
                                  DataCell(Text(FormatHelper.formatCurrency(r.remaining))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(r.status, style: TextStyle(color: statusColor)),
                                  )),
                                  DataCell(Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showAddPaymentDialog(
                                          context,
                                          controller,
                                          studentController,
                                          preselectedStudentId: r.student.id,
                                          initialDate: r.month,
                                        ),
                                        icon: const Icon(Icons.add),
                                        label: const Text('تسجيل دفعة'),
                                      ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
            ),
          ],
        );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPaymentDialog(context, controller, studentController),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'مدفوع بالكامل':
        return Colors.green;
      case 'جزئي':
        return Colors.orange;
      case 'متأخر':
        return Colors.red;
      case 'مُعفى':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  void _showAddPaymentDialog(
    BuildContext context,
    PaymentController controller,
    StudentController studentController, {
    int? preselectedStudentId,
    DateTime? initialDate,
  }) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = initialDate ?? DateTime.now();

    void openForm(int studentId) {
      Get.dialog(
        AlertDialog(
          title: const Text('إضافة مدفوعات جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await custom_dialogs.DatePickerDialog.show(context, title: 'اختر التاريخ', initialDate: selectedDate);
                    if (picked != null) {
                      selectedDate = picked;
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(FormatHelper.formatDate(selectedDate)),
                ),
              ),
              const SizedBox(height: SPACING_NORMAL),
              CustomTextField(
                controller: amountController,
                label: 'المبلغ',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: SPACING_NORMAL),
              CustomTextField(
                controller: noteController,
                label: 'ملاحظات',
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('إلغاء'),
            ),
            CustomButton(
              label: 'إضافة',
              onPressed: () {
                final text = amountController.text.trim();
                final parsed = double.tryParse(text);
                if (text.isNotEmpty && parsed != null) {
                  controller.addPayment(
                    Payment(
                      studentId: studentId,
                      date: selectedDate,
                      amount: parsed,
                      note: noteController.text,
                    ),
                  );
                  Get.back();
                }
              },
            ),
          ],
        ),
      );
    }

    if (preselectedStudentId != null) {
      openForm(preselectedStudentId);
      return;
    }

    custom_dialogs.SelectDialog.show(
      context,
      title: 'اختر الطالب',
      items: studentController.students
          .map((s) => {'id': s.id, 'name': s.name})
          .toList(),
      onSelected: (item) {
        final studentId = item['id'] as int;
        openForm(studentId);
      },
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentMonthRow {
  final Student student;
  final Group? group;
  final DateTime month;
  final double due;
  final double paid;
  final double remaining;
  final String status;

  _StudentMonthRow({
    required this.student,
    required this.group,
    required this.month,
    required this.due,
    required this.paid,
    required this.remaining,
    required this.status,
  });
}

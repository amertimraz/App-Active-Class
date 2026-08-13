// lib/views/payments/payments_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/models/payment_model.dart' show Payment;
import 'package:active_class/models/student_model.dart' show Student;
import 'package:active_class/models/group_model.dart' show Group;
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/custom_dialogs.dart' as custom_dialogs;
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_toast.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final PaymentController controller = Get.put(PaymentController());
  final StudentController studentController = Get.put(StudentController());
  final GroupController groupController = Get.put(GroupController());
  final AttendanceController attendanceController =
      Get.isRegistered<AttendanceController>()
          ? Get.find<AttendanceController>()
          : Get.put(AttendanceController());

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    controller.loadPayments();
    studentController.loadAllStudents();
    groupController.loadGroups();
    attendanceController.loadAttendance();
    final now = DateTime.now();
    controller.selectedMonth.value ??= DateTime(now.year, now.month, 1);
    _searchController =
        TextEditingController(text: controller.searchName.value);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              await attendanceController.loadAttendance();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showAddPaymentDialog(context, controller, studentController),
        icon: const Icon(Icons.add),
        label: const Text('تسجيل دفعة'),
      ),
      body: buildSoftBackground(
        context: context,
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
          final dateFmt = DateFormat('MMMM yyyy', 'ar');

          final List<Student> scopedStudents = studentController.students
              .where((s) =>
                  selectedGroupId == null || s.groupId == selectedGroupId)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          final List<Payment> monthlyPayments = controller.payments
              .where((p) =>
                  p.date.year == month.year && p.date.month == month.month)
              .toList();

          final Map<int, double> paidByStudent = {};
          for (final p in monthlyPayments) {
            paidByStudent.update(p.studentId, (v) => v + p.amount,
                ifAbsent: () => p.amount);
          }

          final rows = <_StudentMonthRow>[];
          for (final s in scopedStudents) {
            final paid = paidByStudent[s.id!] ?? 0.0;
            final due = PricingHelper.monthlyDue(
              student: s,
              group: groupById[s.groupId],
              month: month,
              allAttendance: attendanceController.attendance,
            );
            final remaining =
                (due - paid).clamp(0.0, double.infinity).toDouble();
            final status = due <= 0
                ? 'مُعفى'
                : paid >= due
                    ? 'مدفوع بالكامل'
                    : paid > 0
                        ? 'جزئي'
                        : 'متأخر';
            if (selectedStatus != 'الكل' && status != selectedStatus) continue;
            final nameQuery = controller.searchName.value.trim().toLowerCase();
            if (nameQuery.isNotEmpty &&
                !s.name.toLowerCase().contains(nameQuery)) continue;
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

          final totalPaidInScope =
              rows.fold<double>(0.0, (sum, r) => sum + r.paid);
          final fullyPaidCount =
              rows.where((r) => r.status == 'مدفوع بالكامل').length;
          final partialCount = rows.where((r) => r.status == 'جزئي').length;
          final lateCount = rows.where((r) => r.status == 'متأخر').length;

          return Column(
            children: [
              // ─── Header card ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    PADDING_NORMAL, PADDING_NORMAL, PADDING_NORMAL, 0),
                child: buildSoftPanel(
                  context: context,
                  radius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Month row
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            tooltip: 'الشهر السابق',
                            onPressed: () {
                              final prev = DateTime(
                                  month.year, month.month - 1, 1);
                              controller.setMonth(prev);
                            },
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: month,
                                  firstDate: DateTime(2020, 1, 1),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                  helpText: 'اختر شهرًا',
                                );
                                if (picked != null) {
                                  controller.setMonth(
                                      DateTime(picked.year, picked.month, 1));
                                }
                              },
                              child: Column(
                                children: [
                                  Text(
                                    dateFmt.format(month),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'اضغط لتغيير الشهر',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            tooltip: 'الشهر التالي',
                            onPressed: () {
                              final next = DateTime(
                                  month.year, month.month + 1, 1);
                              controller.setMonth(next);
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      // Total amount
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'إجمالي المحصّل',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 2),
                            CurrencyText(
                              totalPaidInScope,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Status summary pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _SummaryPill(
                            label: 'مدفوع',
                            value: fullyPaidCount,
                            color: Colors.green,
                            icon: Icons.check_circle_outline,
                          ),
                          _SummaryPill(
                            label: 'جزئي',
                            value: partialCount,
                            color: Colors.orange,
                            icon: Icons.timelapse_rounded,
                          ),
                          _SummaryPill(
                            label: 'متأخر',
                            value: lateCount,
                            color: Colors.red,
                            icon: Icons.warning_amber_rounded,
                          ),
                          _SummaryPill(
                            label: 'الكل',
                            value: rows.length,
                            color: Theme.of(context).colorScheme.primary,
                            icon: Icons.people_outline,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Filters ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    PADDING_NORMAL, 10, PADDING_NORMAL, 0),
                child: Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 8),
                    _FilterButton(
                      label: selectedGroupId == null
                          ? 'المجموعة'
                          : groupById[selectedGroupId]?.name ?? 'المجموعة',
                      icon: Icons.group_outlined,
                      isDark: isDark,
                      onTap: () => _showGroupFilter(
                          context, groupController.groups, selectedGroupId),
                    ),
                  ],
                ),
              ),

              // ─── Status filter tabs ────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: PADDING_NORMAL, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in const [
                        'الكل',
                        'متأخر',
                        'جزئي',
                        'مدفوع بالكامل',
                        'مُعفى'
                      ])
                        _StatusTab(
                          label: s,
                          selected: selectedStatus == s,
                          color: _statusColor(s),
                          onTap: () => controller.setStatusFilter(s),
                        ),
                    ],
                  ),
                ),
              ),

              // ─── Student list ──────────────────────────────────────────
              Expanded(
                child: controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                        ? buildSoftPanel(
                            context: context,
                            child: const EmptyState(
                              icon: Icons.payment,
                              title: 'لا توجد سجلات',
                              subtitle:
                                  'عدّل المرشحات أو سجّل دفعة جديدة',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                PADDING_NORMAL,
                                0,
                                PADDING_NORMAL,
                                80),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = rows[i];
                              return _StudentPaymentCard(
                                row: r,
                                isDark: isDark,
                                onAddPayment: () {
                                  final now = DateTime.now();
                                  final safeDate = r.month.isAfter(
                                          DateTime(now.year, now.month, 1))
                                      ? DateTime(now.year, now.month, 1)
                                      : r.month;
                                  _showAddPaymentDialog(
                                    context,
                                    controller,
                                    studentController,
                                    preselectedStudentId: r.student.id,
                                    initialDate: safeDate,
                                    defaultAmount: r.remaining,
                                  );
                                },
                                onViewHistory: () => _showPaymentHistory(
                                  context,
                                  r.student,
                                  r.month,
                                  controller,
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        }),
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

  void _showGroupFilter(
      BuildContext context, List<Group> groups, int? current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(current == null
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: const Text('كل المجموعات'),
              onTap: () {
                controller.setGroupFilter(null);
                Get.back();
              },
            ),
            ...groups.map((g) => ListTile(
                  leading: Icon(current == g.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off),
                  title: Text(g.name),
                  onTap: () {
                    controller.setGroupFilter(g.id);
                    Get.back();
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPaymentHistory(
    BuildContext context,
    Student student,
    DateTime month,
    PaymentController ctrl,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'دفعات ${student.name} هذا الشهر',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                // قراءة مباشرة هنا (مش جوه itemBuilder) عشان GetX يسجّلها
                // كـ dependency — لو قريناها بس جوه itemBuilder، القائمة مش
                // هتتحدّث لما نظام الساعة 12/24 يتغيّر من الإعدادات.
                Get.find<SettingsController>().use24hFormat.value;
                final payments = ctrl.payments
                    .where((p) =>
                        p.studentId == student.id &&
                        p.date.year == month.year &&
                        p.date.month == month.month)
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
                if (payments.isEmpty) {
                  return const Center(child: Text('لا توجد دفعات هذا الشهر'));
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  itemCount: payments.length,
                  itemBuilder: (_, i) {
                    final p = payments[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Colors.green.withValues(alpha: 0.12),
                        child: const Icon(Icons.payments_rounded,
                            color: Colors.green, size: 18),
                      ),
                      title: CurrencyText(
                        p.amount,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(FormatHelper.formatPaymentDate(p.date)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p.note?.isNotEmpty == true)
                            Tooltip(
                              message: p.note!,
                              child: const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.notes_rounded,
                                    size: 18, color: Colors.grey),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            tooltip: 'تعديل',
                            onPressed: () =>
                                _editPayment(context, p, ctrl),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded,
                                size: 18, color: Colors.red),
                            tooltip: 'حذف',
                            onPressed: () =>
                                _confirmDeletePayment(context, p, ctrl),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePayment(
      BuildContext context, Payment p, PaymentController ctrl) {
    custom_dialogs.ConfirmDeleteDialog.show(
      context,
      title: 'حذف الدفعة',
      message: 'هل تريد حذف دفعة بقيمة ${FormatHelper.formatCurrency(p.amount)}؟',
      onConfirm: () => ctrl.deletePayment(p.id!),
    );
  }

  void _editPayment(
      BuildContext context, Payment p, PaymentController ctrl) {
    final amountCtrl = TextEditingController(text: p.amount.toString());
    final noteCtrl = TextEditingController(text: p.note ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الدفعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) {
                ToastHelper.error('أدخل مبلغ صحيح');
                return;
              }
              Navigator.pop(ctx);
              final ok = await ctrl.updatePayment(Payment(
                id: p.id,
                studentId: p.studentId,
                date: p.date,
                amount: amount,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                createdAt: p.createdAt,
              ));
              if (ok) ToastHelper.success('تم تعديل الدفعة بنجاح');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog(
    BuildContext context,
    PaymentController controller,
    StudentController studentController, {
    int? preselectedStudentId,
    DateTime? initialDate,
    double? defaultAmount,
  }) {
    void openSheet(int studentId, {double? price, String? studentName}) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AddPaymentSheet(
          studentId: studentId,
          studentName: studentName ?? '',
          initialDate: initialDate ?? DateTime.now(),
          defaultAmount: price ?? defaultAmount,
          controller: controller,
        ),
      );
    }

    final month = controller.selectedMonth.value ?? DateTime.now();
    // المتبقي فعليًا بعد خصم أي دفعات سابقة هذا الشهر — مش المستحق الكامل،
    // عشان مانعبّيش الحقل بمبلغ زيادة لطالب دفع جزء بالفعل.
    double? dueFor(Student? student) {
      if (student == null) return null;
      final group = groupController.groups
          .firstWhereOrNull((g) => g.id == student.groupId);
      final due = PricingHelper.monthlyDue(
        student: student,
        group: group,
        month: month,
        allAttendance: attendanceController.attendance,
      );
      final paidThisMonth = controller.payments
          .where((p) =>
              p.studentId == student.id &&
              p.date.year == month.year &&
              p.date.month == month.month)
          .fold<double>(0.0, (sum, p) => sum + p.amount);
      return (due - paidThisMonth).clamp(0.0, double.infinity);
    }

    if (preselectedStudentId != null) {
      final student = studentController.students
          .firstWhereOrNull((s) => s.id == preselectedStudentId);
      openSheet(preselectedStudentId,
          price: defaultAmount ?? dueFor(student),
          studentName: student?.name);
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
        final student = studentController.students
            .firstWhereOrNull((s) => s.id == studentId);
        openSheet(studentId, price: dueFor(student), studentName: student?.name);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student payment card
// ─────────────────────────────────────────────────────────────────────────────

class _StudentPaymentCard extends StatelessWidget {
  final _StudentMonthRow row;
  final bool isDark;
  final VoidCallback onAddPayment;
  final VoidCallback onViewHistory;

  const _StudentPaymentCard({
    required this.row,
    required this.isDark,
    required this.onAddPayment,
    required this.onViewHistory,
  });

  Color get _statusColor {
    switch (row.status) {
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

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final progress =
        row.due > 0 ? (row.paid / row.due).clamp(0.0, 1.0) : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name + status
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Text(
                    row.student.name.isNotEmpty
                        ? row.student.name[0]
                        : '؟',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.student.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (row.group != null)
                        Text(
                          row.group!.name,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    row.status,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Amounts row
            Row(
              children: [
                _AmountBox(
                  label: 'المستحق',
                  amount: row.due,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                _AmountBox(
                  label: 'المدفوع',
                  amount: row.paid,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _AmountBox(
                  label: 'المتبقي',
                  amount: row.remaining,
                  color: row.remaining > 0 ? Colors.red : Colors.grey,
                ),
              ],
            ),

            if (row.due > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onViewHistory,
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('السجل'),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  onPressed: onAddPayment,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('تسجيل دفعة'),
                  style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _AmountBox(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            CurrencyText(
              amount,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _SummaryPill(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              value.toString(),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _StatusTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StatusTab(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.grey.shade600,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _FilterButton(
      {required this.label,
      required this.icon,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 16, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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

// ══════════════════════════════════════════════════════════════════
//  _AddPaymentSheet — bottom sheet لتسجيل دفعة
// ══════════════════════════════════════════════════════════════════
class _AddPaymentSheet extends StatefulWidget {
  const _AddPaymentSheet({
    required this.studentId,
    required this.studentName,
    required this.initialDate,
    required this.controller,
    this.defaultAmount,
  });

  final int studentId;
  final String studentName;
  final DateTime initialDate;
  final double? defaultAmount;
  final PaymentController controller;

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _amountCtrl = TextEditingController(
      text: (widget.defaultAmount != null && widget.defaultAmount! > 0)
          ? widget.defaultAmount!.toStringAsFixed(0)
          : '',
    );
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _amountCtrl.text.trim();
    final parsed = double.tryParse(text);
    if (text.isEmpty || parsed == null || parsed <= 0) {
      if (mounted) AppToast.error(context, 'يرجى إدخال مبلغ صحيح');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.addPayment(
        Payment(
          studentId: widget.studentId,
          date: _date,
          amount: parsed,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ),
      );
      if (mounted) {
        AppToast.success(
          context,
          'تم تسجيل الدفعة بنجاح',
          subtitle: '${widget.studentName} • ${FormatHelper.formatCurrency(parsed)}',
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final surface = Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.payments_rounded, color: primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تسجيل دفعة',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        if (widget.studentName.isNotEmpty)
                          Text(widget.studentName,
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Form
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _date.isAfter(DateTime.now()) ? DateTime.now() : _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        helpText: 'اختر التاريخ',
                        confirmText: 'تأكيد',
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 18, color: primary),
                        const SizedBox(width: 10),
                        Text(
                          FormatHelper.formatDate(_date),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        Icon(Icons.edit_calendar_rounded,
                            size: 16, color: Colors.grey.shade400),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Amount
                  CustomTextField(
                    controller: _amountCtrl,
                    label: 'المبلغ *',
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 12),

                  // Note
                  CustomTextField(
                    controller: _noteCtrl,
                    label: 'ملاحظات (اختياري)',
                    maxLines: 2,
                  ),

                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving ? 'جاري الحفظ...' : 'تسجيل الدفعة',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

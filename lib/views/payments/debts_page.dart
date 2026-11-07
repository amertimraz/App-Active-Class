// lib/views/payments/debts_page.dart
//
// «المديونيات»: كل الطلاب اللي عليهم متبقي، وكل شهر متبقي فيه كام. فلتر
// «أقل من سعر الشهر» بيطلّع الفتات (10 أو 20 من 80) مع زر إسقاط لكل واحد،
// وزر إسقاط جماعي بعد تأكيد.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/widgets/chalk_dialog.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/utils/debts_overview.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/help/help_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/services/bulk_send_service.dart';
import 'package:active_class/views/messages/bulk_send_page.dart';
import 'package:active_class/widgets/app_panel.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  final PaymentController _pay = Get.put(PaymentController());
  final StudentController _students = Get.put(StudentController());
  final GroupController _groups = Get.put(GroupController());
  final AttendanceController _att = Get.isRegistered<AttendanceController>()
      ? Get.find<AttendanceController>()
      : Get.put(AttendanceController());

  bool _loading = true;
  bool _onlySmall = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await Future.wait([
      _pay.loadPayments(),
      _students.loadAllStudents(),
      _groups.loadGroups(),
      _att.loadAttendance(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  List<StudentDebtRow> _compute() {
    // الطلاب النشطين بس — المؤرشفين مش بيتحسبوا ولا بيظهروا هنا.
    final all = _students.students.toList();
    return computeDebtRows(
      students: all,
      groups: _groups.groups.toList(),
      allAttendance: _att.attendance.toList(),
      payments: _pay.payments.toList(),
      siblingGroupMembers: all,
    );
  }

  String _money(double v) => FormatHelper.formatCurrency(v);
  String _month(DateTime d) => DateFormat('MMMM yyyy', 'ar').format(d);

  Future<bool> _confirm(String title, String body) => showChalkConfirm(
        context,
        icon: Icons.cleaning_services_rounded,
        title: title,
        message: body,
        confirmLabel: 'تأكيد الإسقاط',
        destructive: true,
      );

  Future<void> _writeOffOne(StudentDebtRow r) async {
    final prefix = r.writablePrefix;
    if (prefix.isEmpty) return;
    final amount = r.writablePrefixTotal;
    final months = prefix.map((m) => _month(m.month)).join('، ');
    final ok = await _confirm(
      'إسقاط ${r.student.name}',
      'هيتسقط ${_money(amount)} (عن $months).\n\n'
      'الإجراء ده مش بيترجع تلقائيًا — لو حصل غلط احذف عملية «إسقاط مديونية» '
      'من سجل المدفوعات.',
    );
    if (!ok) return;
    final err = await _pay.writeOffDebt(
      student: r.student,
      group: r.group,
      allAttendance: _att.attendance.toList(),
      payments:
          _pay.payments.where((p) => p.studentId == r.student.id).toList(),
      siblingGroupMembers: _students.students.toList(),
      amount: amount,
    );
    if (!mounted) return;
    if (err != null) {
      ToastHelper.error(err);
    } else {
      ToastHelper.success('تم إسقاط ${_money(amount)}');
    }
    setState(() {});
  }

  Future<void> _writeOffAllSmall(List<StudentDebtRow> rows) async {
    final todo = rows.where((r) => r.writablePrefix.isNotEmpty).toList();
    if (todo.isEmpty) return;
    final total = todo.fold(0.0, (s, r) => s + r.writablePrefixTotal);
    final ok = await _confirm(
      'إسقاط كل الفتات',
      'هيتسقط ${_money(total)} عن ${todo.length} طالب (متبقي أقل من سعر '
      'الشهر لكل واحد).\n\n'
      'الإجراء ده مش بيترجع تلقائيًا — الحل الوحيد حذف عمليات «إسقاط '
      'مديونية» يدويًا من سجل المدفوعات.',
    );
    if (!ok) return;
    // نعيد الحساب لحظة التنفيذ عشان مبلغ قديم ما يتسقطش بالغلط.
    final fresh = _compute().where((r) => r.writablePrefix.isNotEmpty);
    final ids = todo.map((r) => r.student.id).toSet();
    final amounts = <int, double>{
      for (final r in fresh)
        if (ids.contains(r.student.id)) r.student.id!: r.writablePrefixTotal,
    };
    final n = await _pay.writeOffMany(amounts);
    if (!mounted) return;
    ToastHelper.success('اتسقطت مديونية $n طالب');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'المديونيات', actions: [
        const HelpButton(topicId: 'debts'),
        IconButton(
            tooltip: 'تذكير الكل بالواتساب',
            icon: const Icon(Icons.send_rounded),
            onPressed: () => Get.to(() =>
                const BulkSendPage(initialKind: BulkKind.payments))),
        IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _reload),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Obx(() {
              // قراءة الـRx هنا عشان الشاشة تتحدّث بعد أي إسقاط.
              _pay.payments.length;
              final all = _compute();
              final q = _query.trim();
              var rows = all
                  .where((r) => q.isEmpty || r.student.name.contains(q))
                  .toList();
              if (_onlySmall) rows = rows.where((r) => r.hasSmall).toList();
              final smallAll = all.where((r) => r.hasSmall).toList();
              final smallSum = smallAll.fold(
                  0.0,
                  (s, r) =>
                      s + r.smallMonths.fold(0.0, (a, m) => a + m.remaining));
              final totalAll = all.fold(0.0, (s, r) => s + r.total);
              final writable =
                  rows.where((r) => r.writablePrefix.isNotEmpty).toList();
              return Column(children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.md, AppSpace.lg, 120),
                    children: [
                      _summary(t, all.length, totalAll, smallAll.length,
                          smallSum),
                      const SizedBox(height: AppSpace.md),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'ابحث باسم الطالب',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Wrap(spacing: AppSpace.sm, children: [
                        ChoiceChip(
                          label: const Text('أقل من سعر الشهر'),
                          selected: _onlySmall,
                          onSelected: (_) => setState(() => _onlySmall = true),
                        ),
                        ChoiceChip(
                          label: const Text('كل المديونيات'),
                          selected: !_onlySmall,
                          onSelected: (_) => setState(() => _onlySmall = false),
                        ),
                      ]),
                      const SizedBox(height: AppSpace.md),
                      if (rows.isEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSpace.xl),
                          child: Text(
                              _onlySmall
                                  ? 'مفيش مديونيات أقل من سعر الشهر 👌'
                                  : 'مفيش مديونيات على أي طالب 👌',
                              textAlign: TextAlign.center,
                              style: AppType.body.copyWith(color: t.inkSoft)),
                        ),
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: _studentCard(t, r),
                        ),
                    ],
                  ),
                ),
                if (_onlySmall && writable.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
                      child: FilledButton.icon(
                        onPressed: () => _writeOffAllSmall(writable),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: t.danger),
                        icon: const Icon(Icons.cleaning_services_rounded),
                        label: Text(
                            'إسقاط كل الفتات (${writable.length} طالب · '
                            '${_money(writable.fold(0.0, (s, r) => s + r.writablePrefixTotal))})'),
                      ),
                    ),
                  ),
              ]);
            }),
    );
  }

  Widget _summary(AppTokens t, int students, double total, int smallStudents,
      double smallSum) {
    Widget cell(String label, String value, Color color) => Expanded(
          child: Column(children: [
            Text(value,
                style: AppType.title.copyWith(color: color),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label,
                style: AppType.caption.copyWith(color: t.inkSoft),
                textAlign: TextAlign.center),
          ]),
        );
    return AppPanel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(children: [
        cell('طالب عليه متبقي', '$students', t.ink),
        cell('إجمالي المتبقي', _money(total), t.danger),
        cell('فتات أقل من سعر الشهر', _money(smallSum), t.caution),
      ]),
    );
  }

  Widget _studentCard(AppTokens t, StudentDebtRow r) {
    final shown = _onlySmall ? r.smallMonths : r.months;
    final hidden = r.months.length - shown.length;
    final writableMonths = r.writablePrefix.map((m) => m.month).toSet();
    return AppPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
                r.student.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(color: t.ink)),
          ),
          Text(_money(r.total),
              style: AppType.label.copyWith(color: t.danger)),
        ]),
        Text(
            '${r.group?.name ?? '—'} • سعر الشهر ${_money(r.monthPrice)}',
            style: AppType.caption.copyWith(color: t.inkSoft)),
        const SizedBox(height: AppSpace.sm),
        for (final m in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(
                child: Text(
                    '${_month(m.month)} — متبقي ${_money(m.remaining)}'
                    '${m.isPartial ? ' من ${_money(m.due)}' : ''}',
                    style: AppType.body.copyWith(
                        color: m.isSmall ? t.caution : t.ink)),
              ),
              if (r.writablePrefix.isNotEmpty &&
                  m.month == r.writablePrefix.first.month)
                TextButton(
                  onPressed: () => _writeOffOne(r),
                  child: Text(
                      r.writablePrefix.length > 1
                          ? 'إسقاط الكل (${_money(r.writablePrefixTotal)})'
                          : 'إسقاط',
                      style: TextStyle(color: t.danger)),
                )
              else if (m.isSmall && !writableMonths.contains(m.month))
                Text('اسقط اللي قبله الأول',
                    style: AppType.caption.copyWith(color: t.inkFaint)),
            ]),
          ),
        if (hidden > 0)
          Text('+ $hidden شهر تاني متبقي كامل',
              style: AppType.caption.copyWith(color: t.inkFaint)),
      ]),
    );
  }
}

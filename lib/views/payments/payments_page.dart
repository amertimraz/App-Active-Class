// lib/views/payments/payments_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/widgets/clock_text.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/models/payment_model.dart' show Payment;
import 'package:active_class/models/student_model.dart' show Student;
import 'package:active_class/models/group_model.dart' show Group;
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/custom_dialogs.dart' as custom_dialogs;
import 'package:active_class/views/help/help_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/services/team_mode_service.dart';
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
    // شاشة المدفوعات هي مكان *تسجيل* الدفعات — فتفتح على الشهر الحالي
    // (اللي بيتسجّل فيه النهارده)، مش شهر التحصيل. لو فتحناها على الشهر
    // اللي فات (spec 013)، المدرس يسجّل دفعة النهارده وماتظهرش في القائمة
    // لأنها مفلترة على شهر تاني، وطلاب الحصص بيتحجبوا لغياب "شهر التحصيل".
    // اللي عايز يحصّل الشهر اللي فات يرجع شهر واحد بالسهم.
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
    final t = context.tokens;
    // ألوان الحالات فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(
        context,
        title: 'المدفوعات',
        actions: [
          const HelpButton(topicId: 'payments'),
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
        backgroundColor: t.chalk,
        foregroundColor: t.onChalk,
        icon: const Icon(Icons.add),
        label: const Text('تسجيل دفعة'),
      ),
      body: ColoredBox(
        color: t.page,
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

          // المديونية المتراكمة الحقيقية على الطالب **دلوقتي** — من شهر
          // تسجيله لحد الشهر الحالي (أو آخر شهر مكتمل في وضع التحصيل
          // المؤخّر) — نفس مصدر تفاصيل الطالب بالظبط. مش بتتقيّد بالشهر
          // المختار في المنتقي: طالب دفع شهر التحصيل بالكامل وعليه الشهر
          // الجاري كان بيظهر "مدفوع بالكامل" غلط (bug).
          final Map<int, List<Payment>> paymentsByStudent = {};
          for (final p in controller.payments) {
            paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
          }
          final nowMonth = DateTime.now();

          // allRows = نطاق المجموعة + البحث بالاسم (من غير فلتر الحالة) —
          // منه بنحسب الأعداد والمحصّل، وrows هي اللي بتتعرض بعد فلتر الحالة.
          final allRows = <_StudentMonthRow>[];
          // محصّل الشهر المعروض: دفعات تاريخها في الشهر ده (من غير إسقاط
          // المديونية) لطلاب النطاق — مش إجمالي كل الدفعات.
          double monthCollected = 0;
          for (final s in scopedStudents) {
            final group = groupById[s.groupId];
            final studentPayments = paymentsByStudent[s.id] ?? const [];
            final paid =
                studentPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
            // spec 038 — نسخة مستبعدة منها إسقاط المديونية، تُستخدَم فقط
            // في إجمالي "المحصّل" المعروض أعلى الشاشة (راجع research.md
            // § تفصيل تقني مهم في specs/038-debt-write-off).
            final realPaid = studentPayments
                .where((p) => p.note != kDebtWriteOffNote)
                .fold<double>(0.0, (sum, p) => sum + p.amount);
            final due = PricingHelper.totalDueThrough(
              student: s,
              group: group,
              month: nowMonth,
              allAttendance: attendanceController.attendance,
              siblingGroupMembers: studentController.students,
            );
            final remaining =
                (due - paid).clamp(0.0, double.infinity).toDouble();
            final status = s.isFullyExempt
                ? 'مُعفى'
                : remaining <= 0
                    ? 'مدفوع بالكامل'
                    : paid > 0
                        ? 'جزئي'
                        : 'متأخر';
            final nameQuery = controller.searchName.value.trim().toLowerCase();
            if (nameQuery.isNotEmpty &&
                !s.name.toLowerCase().contains(nameQuery)) continue;
            monthCollected += studentPayments
                .where((p) =>
                    p.date.year == month.year &&
                    p.date.month == month.month &&
                    p.note != kDebtWriteOffNote)
                .fold<double>(0.0, (sum, p) => sum + p.amount);
            allRows.add(_StudentMonthRow(
              student: s,
              group: groupById[s.groupId],
              month: month,
              due: due,
              paid: paid,
              realPaid: realPaid,
              remaining: remaining,
              status: status,
            ));
          }

          // spec 038 — "محصّل الشهر" رقم مالي حقيقي، فيستبعد صفوف إسقاط
          // المديونية (monthCollected فوق).
          final totalPaidInScope = monthCollected;
          final rows = selectedStatus == 'الكل'
              ? allRows
              : allRows.where((r) => r.status == selectedStatus).toList();
          // أعداد الحالات من النطاق الكامل — مش بتتصفّر لما تختار تاب حالة.
          final fullyPaidCount =
              allRows.where((r) => r.status == 'مدفوع بالكامل').length;
          final partialCount = allRows.where((r) => r.status == 'جزئي').length;
          final lateCount = allRows.where((r) => r.status == 'متأخر').length;

          return Column(
            children: [
              // ─── سبورة: الشهر + المحصّل + أعداد الحالات ─────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
                decoration: BoxDecoration(
                  color: t.board,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppRadius.board)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // الشهر: تنقّل + اختيار + أيقونة شرح (بدل البانر الطويل)
                    Row(
                      children: [
                        BoardIconButton(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'الشهر السابق',
                          onPressed: () {
                            final prev =
                                DateTime(month.year, month.month - 1, 1);
                            controller.setMonth(prev);
                          },
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppRadius.control),
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
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      dateFmt.format(month),
                                      style: AppType.title.copyWith(
                                          fontSize: 18, color: t.boardInk),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpace.xs),
                                  Icon(Icons.expand_more_rounded,
                                      size: 20, color: t.boardInkSoft),
                                ],
                              ),
                            ),
                          ),
                        ),
                        BoardIconButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'الشهر التالي',
                          onPressed: () {
                            final next =
                                DateTime(month.year, month.month + 1, 1);
                            controller.setMonth(next);
                          },
                        ),
                        BoardIconButton(
                          icon: Icons.info_outline_rounded,
                          tooltip: 'إزاي بتتعرض الدفعات؟',
                          onPressed: () => _showMonthInfo(context, month),
                        ),
                      ],
                    ),
                    // إجمالي المحصّل
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpace.sm,
                        children: [
                          Text('محصّل الشهر',
                              style: AppType.caption
                                  .copyWith(color: t.boardInkSoft)),
                          CurrencyText(
                            totalPaidInScope,
                            style:
                                AppType.figure.copyWith(color: on.positive),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(children: [
                      Expanded(
                          child: BoardStat(
                              label: 'مدفوع',
                              value: '$fullyPaidCount',
                              color: on.positive)),
                      Expanded(
                          child: BoardStat(
                              label: 'جزئي',
                              value: '$partialCount',
                              color: t.chalk)),
                      Expanded(
                          child: BoardStat(
                              label: 'متأخر',
                              value: '$lateCount',
                              color: on.danger)),
                      Expanded(
                          child: BoardStat(
                              label: 'الكل',
                              value: '${allRows.length}',
                              color: t.boardInk)),
                    ]),
                  ],
                ),
              ),

              // ─── بحث + مجموعة ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
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
                    const SizedBox(width: AppSpace.sm),
                    _FilterButton(
                      label: selectedGroupId == null
                          ? 'المجموعة'
                          : groupById[selectedGroupId]?.name ?? 'المجموعة',
                      icon: Icons.group_outlined,
                      onTap: () => _showGroupFilter(
                          context, groupController.groups, selectedGroupId),
                    ),
                  ],
                ),
              ),

              // ─── شرائح الحالة: Wrap عشان كلها باينة من غير سحب ────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final s in const [
                        'الكل',
                        'متأخر',
                        'جزئي',
                        'مدفوع بالكامل',
                        'مُعفى'
                      ])
                        _StatusTab(
                          // الشريحة بتتسمّى «مدفوع» (قصيرة) والقيمة المصفّى بيها
                          // لسه 'مدفوع بالكامل'.
                          label: s == 'مدفوع بالكامل' ? 'مدفوع' : s,
                          selected: selectedStatus == s,
                          color: _statusInk(t, s),
                          onTap: () => controller.setStatusFilter(s),
                        ),
                    ],
                  ),
                ),
              ),

              // ─── قايمة الطلاب ──────────────────────────────────────────
              Expanded(
                child: controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                        ? const EmptyState(
                            icon: Icons.payment,
                            title: 'لا توجد سجلات',
                            subtitle: 'عدّل المرشحات أو سجّل دفعة جديدة',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpace.lg, 0, AppSpace.lg, 88),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpace.sm),
                            itemBuilder: (context, i) {
                              final r = rows[i];
                              return _StudentPaymentCard(
                                row: r,
                                onAddPayment: () {
                                  final now = DateTime.now();
                                  DateTime safeDate;
                                  if (r.month.year == now.year &&
                                      r.month.month == now.month) {
                                    safeDate = now;
                                  } else {
                                    final lastDayOfMonth = DateTime(
                                            r.month.year, r.month.month + 1, 0)
                                        .day;
                                    final day = now.day < lastDayOfMonth
                                        ? now.day
                                        : lastDayOfMonth;
                                    safeDate = DateTime(
                                        r.month.year,
                                        r.month.month,
                                        day,
                                        now.hour,
                                        now.minute,
                                        now.second);
                                  }
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

  /// الشرح اللي كان بانر طويل في الهيدر — دلوقتي في نافذة بتتفتح بأيقونة ⓘ.
  void _showMonthInfo(BuildContext context, DateTime month) {
    final dateFmt = DateFormat('MMMM yyyy', 'ar');
    final n = DateTime.now();
    final isCurrent = month.year == n.year && month.month == n.month;
    final txt = isCurrent
        ? 'بتشوف دفعات ${dateFmt.format(month)} — أي دفعة تسجّلها بتاريخ الشهر ده بتظهر هنا فورًا.'
        : 'بتشوف ${dateFmt.format(month)}. الدفعة اللي تسجّلها النهارده بتظهر في ${dateFmt.format(DateTime(n.year, n.month, 1))} — بس مديونية الطالب الكلية بتتحسب صح مهما كان الشهر المعروض.';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزاي بتتعرض الدفعات؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(txt,
            style: const TextStyle(fontFamily: 'Cairo', height: 1.7)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تمام', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
  }

  void _showGroupFilter(
      BuildContext context, List<Group> groups, int? current) {
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
          child: ListView(
            controller: scrollCtrl,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2)),
                ),
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
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final t = sheetCtx.tokens;
        // ألوان الحالات فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
        final on = AppTokens.dark;
        final monthLabel = DateFormat('MMMM yyyy', 'ar').format(month);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (_, scrollCtrl) => Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.board)),
            ),
            child: Obx(() {
              final payments = ctrl.payments
                  .where((p) =>
                      p.studentId == student.id &&
                      p.date.year == month.year &&
                      p.date.month == month.month)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));
              // إجمالي الشهر بدون إسقاط المديونية (مش فلوس اتحصّلت فعلًا).
              final total = payments
                  .where((p) => p.note != kDebtWriteOffNote)
                  .fold<double>(0.0, (sum, p) => sum + p.amount);

              return Column(
                children: [
                  // رأس السبورة: اسم الطالب والشهر وملخص الدفعات
                  Container(
                    color: t.board,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpace.lg, AppSpace.sm, AppSpace.xs, AppSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: t.boardLine,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpace.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('دفعات ${student.name}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.title.copyWith(
                                          fontSize: 18, color: t.boardInk)),
                                  Text(monthLabel,
                                      style: AppType.caption
                                          .copyWith(color: t.boardInkSoft)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            color: t.boardInk,
                            tooltip: 'إغلاق',
                            constraints: const BoxConstraints(
                                minWidth: 44, minHeight: 44),
                            onPressed: () => Navigator.of(sheetCtx).pop(),
                          ),
                        ]),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                              end: AppSpace.md, top: AppSpace.xs),
                          child: Row(children: [
                            Expanded(
                                child: BoardStat(
                                    label: 'عدد الدفعات',
                                    value: '${payments.length}',
                                    color: t.boardInk)),
                            Expanded(
                                child: BoardStat(
                                    label: 'إجمالي الشهر',
                                    value: FormatHelper.formatCurrency(total),
                                    color: on.positive)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: payments.isEmpty
                        ? ListView(
                            controller: scrollCtrl,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(AppSpace.xl),
                                child: Column(children: [
                                  Icon(Icons.receipt_long_rounded,
                                      size: 36, color: t.inkFaint),
                                  const SizedBox(height: AppSpace.sm),
                                  Text('لا توجد دفعات هذا الشهر',
                                      style: AppType.label
                                          .copyWith(color: t.inkSoft)),
                                ]),
                              ),
                            ],
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.all(AppSpace.md),
                            itemCount: payments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpace.sm),
                            itemBuilder: (_, i) {
                              final p = payments[i];
                              final writeOff = p.note == kDebtWriteOffNote;
                              final ink = writeOff ? t.caution : t.positive;
                              final soft =
                                  writeOff ? t.cautionSoft : t.positiveSoft;
                              return AppPanel(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    AppSpace.md,
                                    AppSpace.sm,
                                    AppSpace.xs,
                                    AppSpace.sm),
                                child: Row(children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: soft,
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.chip),
                                    ),
                                    child: Icon(
                                        writeOff
                                            ? Icons.remove_circle_outline_rounded
                                            : Icons.payments_rounded,
                                        color: ink,
                                        size: 20),
                                  ),
                                  const SizedBox(width: AppSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CurrencyText(
                                          p.amount,
                                          style: AppType.label
                                              .copyWith(color: t.ink),
                                        ),
                                        ClockPaymentDateText(
                                          p.date,
                                          style: AppType.caption
                                              .copyWith(color: t.inkSoft),
                                        ),
                                        if (p.note?.isNotEmpty == true)
                                          Text(p.note!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppType.caption.copyWith(
                                                  color: t.inkFaint)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit_rounded,
                                        size: 20, color: t.inkSoft),
                                    tooltip: 'تعديل',
                                    constraints: const BoxConstraints(
                                        minWidth: 44, minHeight: 44),
                                    onPressed: () =>
                                        _editPayment(context, p, ctrl),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_rounded,
                                        size: 20, color: t.danger),
                                    tooltip: 'حذف',
                                    constraints: const BoxConstraints(
                                        minWidth: 44, minHeight: 44),
                                    onPressed: () =>
                                        _confirmDeletePayment(context, p, ctrl),
                                  ),
                                ]),
                              );
                            },
                          ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  void _confirmDeletePayment(
      BuildContext context, Payment p, PaymentController ctrl) {
    if (!requireDeletePermission(
        context, TeamModeService().canDeletePaymentsNow)) {
      return;
    }
    custom_dialogs.ConfirmDeleteDialog.show(
      context,
      title: 'حذف الدفعة',
      message:
          'هل تريد حذف دفعة بقيمة ${FormatHelper.formatCurrency(p.amount)}؟',
      onConfirm: () => ctrl.deletePayment(p.id!),
    );
  }

  void _editPayment(BuildContext context, Payment p, PaymentController ctrl) {
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              // نفس سقف "تسجيل دفع" — بنستبعد الدفعة دي نفسها من حساب
              // المديونية قبل المقارنة، عشان قيمتها القديمة (المحسوبة
              // أصلاً كمدفوعة) ماتمنعش زيادتها لحد المستحق الحقيقي.
              final student = studentController.students
                  .firstWhereOrNull((s) => s.id == p.studentId);
              if (student != null) {
                final group = groupController.groups
                    .firstWhereOrNull((g) => g.id == student.groupId);
                final otherPayments = ctrl.payments
                    .where((x) => x.studentId == p.studentId && x.id != p.id)
                    .toList();
                final remaining = PricingHelper.accumulatedDebt(
                  student: student,
                  group: group,
                  allAttendance: attendanceController.attendance,
                  payments: otherPayments,
                  siblingGroupMembers: studentController.students,
                );
                if (amount > remaining + 0.01) {
                  final proceed = await showDialog<bool>(
                    context: context,
                    builder: (ctx2) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('المبلغ أكبر من المستحق'),
                      content: Text(
                          'المبلغ (${FormatHelper.formatCurrency(amount)}) أكبر من '
                          'المستحق على الطالب (${FormatHelper.formatCurrency(remaining)}).'
                          ' متأكد إنك عايز تسجّل الدفعة دي؟'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx2, false),
                            child: const Text('إلغاء')),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(ctx2, true),
                            child: const Text('تسجيل على أي حال')),
                      ],
                    ),
                  );
                  if (proceed != true) return;
                }
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              final ok = await ctrl.updatePayment(Payment(
                id: p.id,
                studentId: p.studentId,
                date: p.date,
                amount: amount,
                note:
                    noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
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
          attendanceController: attendanceController,
        ),
      );
    }

    final month = controller.selectedMonth.value ?? DateTime.now();
    // إجمالي المديونية المتراكمة (كل الشهور غير المدفوعة، مش بس الشهر
    // ده) — عشان الحقل يتعبّى بالمبلغ الحقيقي المطلوب من الطالب، ولو
    // عليه شهر قديم يبان معاه.
    double? dueFor(Student? student) {
      if (student == null) return null;
      final group = groupController.groups
          .firstWhereOrNull((g) => g.id == student.groupId);
      return PricingHelper.accumulatedDebt(
        student: student,
        group: group,
        allAttendance: attendanceController.attendance,
        payments: controller.payments
            .where((p) => p.studentId == student.id)
            .toList(),
        siblingGroupMembers: studentController.students,
      );
    }

    // المتبقي فعليًا على *الشهر المختار بس* بعد خصم دفعاته — مختلف عن
    // dueFor (اللي بقى إجمالي متراكم لكل الشهور) عشان فحص "دفع مكرر"
    // تحت لازم يبص على الشهر ده تحديدًا، مش على مديونية قديمة ممكن
    // تخلّي الإجمالي أكبر من صفر حتى لو الشهر ده مدفوع بالكامل.
    double thisMonthRemaining(Student student) {
      final group = groupController.groups
          .firstWhereOrNull((g) => g.id == student.groupId);
      final due = PricingHelper.monthlyDue(
        student: student,
        group: group,
        month: month,
        allAttendance: attendanceController.attendance,
        siblingGroupMembers: studentController.students,
      );
      final paidThisMonth = controller.payments
          .where((p) =>
              p.studentId == student.id &&
              p.date.year == month.year &&
              p.date.month == month.month)
          .fold<double>(0.0, (sum, p) => sum + p.amount);
      return (due - paidThisMonth).clamp(0.0, double.infinity);
    }

    // لطلاب التسعير بالحصة — تنبيه (مش حجب) لو الطالب لسه ماحضرش أي حصة
    // في الشهر المعروض، أو دافع عن كل حصصه. الزر لازم يفتح دايمًا (المدرس
    // ممكن يكون بيحصّل مقدّمًا أو بيسجّل دفعة قديمة) — بس نوضّح الموقف.
    void warnForAttendance(Student student) {
      final group = groupController.groups
          .firstWhereOrNull((g) => g.id == student.groupId);
      if (group == null || !group.isPerSession) return;
      final attended = PricingHelper.sessionsAttended(
          student: student,
          month: month,
          allAttendance: attendanceController.attendance);
      if (attended == 0) {
        ToastHelper.info(
            '${student.name} لسه محضرش حصص في ${DateFormat('MMMM', 'ar').format(month)} — تقدر تسجّل الدفعة برضه');
      } else if (thisMonthRemaining(student) <= 0) {
        ToastHelper.info(
            '${student.name} دافع عن كل حصصه الحاضرة — أي دفعة زيادة هتتحسب رصيد');
      }
    }

    if (preselectedStudentId != null) {
      final student = studentController.students
          .firstWhereOrNull((s) => s.id == preselectedStudentId);
      if (student != null && student.isFullyExempt) {
        ToastHelper.error(
            '${student.name} معفي بالكامل من الرسوم — لا داعي لتسجيل دفعة');
        return;
      }
      if (student != null) warnForAttendance(student);
      openSheet(preselectedStudentId,
          price: defaultAmount ?? dueFor(student), studentName: student?.name);
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
        if (student != null && student.isFullyExempt) {
          ToastHelper.error(
              '${student.name} معفي بالكامل من الرسوم — لا داعي لتسجيل دفعة');
          return;
        }
        if (student != null) warnForAttendance(student);
        openSheet(studentId,
            price: dueFor(student), studentName: student?.name);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student payment card
// ─────────────────────────────────────────────────────────────────────────────

// حالة الدفع → لون الحبر واللون الخفيف (توكنز الثيم).
Color _statusInk(AppTokens t, String status) {
  switch (status) {
    case 'مدفوع بالكامل':
      return t.positive;
    case 'جزئي':
      return t.caution;
    case 'متأخر':
      return t.danger;
    case 'مُعفى':
      return t.inkSoft;
    default:
      return t.brand;
  }
}

Color _statusSoft(AppTokens t, String status) {
  switch (status) {
    case 'مدفوع بالكامل':
      return t.positiveSoft;
    case 'جزئي':
      return t.cautionSoft;
    case 'متأخر':
      return t.dangerSoft;
    case 'مُعفى':
      return t.line;
    default:
      return t.brand.withValues(alpha: 0.12);
  }
}

/// صف الطالب: شريط حالة + الاسم والمجموعة والحالة + المتبقي + زرار دفعة.
/// الضغط على الصف يفتح سجل دفعاته.
class _StudentPaymentCard extends StatelessWidget {
  final _StudentMonthRow row;
  final VoidCallback onAddPayment;
  final VoidCallback onViewHistory;

  const _StudentPaymentCard({
    required this.row,
    required this.onAddPayment,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ink = _statusInk(t, row.status);
    final soft = _statusSoft(t, row.status);
    final progress = row.due > 0 ? (row.paid / row.due).clamp(0.0, 1.0) : 1.0;
    final exempt = row.status == 'مُعفى';
    final owes = row.remaining > 0;

    return AppPanel(
      onTap: onViewHistory,
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpace.md, AppSpace.md, AppSpace.sm, AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.student.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.label.copyWith(color: t.ink)),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (row.group != null)
                          Text(row.group!.name,
                              style: AppType.caption
                                  .copyWith(color: t.inkSoft)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm, vertical: 1),
                          decoration: BoxDecoration(
                            color: soft,
                            borderRadius:
                                BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Text(row.status,
                              style: AppType.caption.copyWith(
                                  fontWeight: FontWeight.w700, color: ink)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!exempt) ...[
                const SizedBox(width: AppSpace.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(owes ? 'المتبقي' : 'مدفوع',
                          style:
                              AppType.caption.copyWith(color: t.inkSoft)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: CurrencyText(
                          owes ? row.remaining : row.paid,
                          style: AppType.title
                              .copyWith(color: owes ? ink : t.positive),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'تسجيل دفعة',
                  onPressed: onAddPayment,
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: t.brand,
                    backgroundColor: t.brand.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ],
          ),
          if (row.due > 0) ...[
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: t.line,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        ink == t.caution ? t.cautionBar : ink),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              CurrencyText(
                row.due,
                style: AppType.caption.copyWith(color: t.inkSoft),
              ),
              const SizedBox(width: AppSpace.sm),
              // الصف كله بيفتح سجل الدفعات: الأيقونة بتقول كده.
              Tooltip(
                message: 'سجل الدفعات',
                child: Icon(Icons.history_rounded, size: 18, color: t.inkFaint),
              ),
            ]),
          ],
        ],
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
            // Row مش Center: Center كان بيمطّ الشريحة جوه الـWrap.
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

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FilterButton(
      {required this.label, required this.icon, required this.onTap});

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: t.inkSoft),
                const SizedBox(width: AppSpace.xs + 2),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(color: t.inkSoft)),
                ),
                Icon(Icons.arrow_drop_down, size: 20, color: t.inkSoft),
              ],
            ),
          ),
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
  final double realPaid;
  final double remaining;
  final String status;

  _StudentMonthRow({
    required this.student,
    required this.group,
    required this.month,
    required this.due,
    required this.paid,
    required this.realPaid,
    required this.remaining,
    required this.status,
  });
}

// ══════════════════════════════════════════════════════════════════
//  _AttendanceHintChip — ملخص حضور/غياب الطالب هذا الشهر
// ══════════════════════════════════════════════════════════════════
class _AttendanceHintChip extends StatelessWidget {
  final int presentCount;
  final List<DateTime> absentDates;
  final String studentName;

  const _AttendanceHintChip({
    required this.presentCount,
    required this.absentDates,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasAbsences = absentDates.isNotEmpty;
    final ink = hasAbsences ? t.caution : t.positive;
    final soft = hasAbsences ? t.cautionSoft : t.positiveSoft;
    final icon =
        hasAbsences ? Icons.event_busy_rounded : Icons.event_available_rounded;
    final text = hasAbsences
        ? 'غائب ${absentDates.length} يوم هذا الشهر'
        : (presentCount > 0
            ? 'حضر $presentCount يوم — بدون غياب'
            : 'لا يوجد سجل حضور هذا الشهر');

    return Material(
      color: soft,
      borderRadius: BorderRadius.circular(AppRadius.control),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasAbsences
            ? () => _showAbsenceDatesSheet(context, studentName, absentDates)
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.sm),
            child: Row(
              children: [
                Icon(icon, size: 20, color: ink),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    text,
                    style: AppType.body
                        .copyWith(fontWeight: FontWeight.w700, color: ink),
                  ),
                ),
                if (hasAbsences)
                  Icon(Icons.chevron_left_rounded, size: 20, color: ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showAbsenceDatesSheet(
    BuildContext context, String studentName, List<DateTime> absentDates) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final t = sheetCtx.tokens;
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.board)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpace.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: t.line, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
                child: Row(
                  children: [
                    Icon(Icons.event_busy_rounded, color: t.caution),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        studentName.isEmpty
                            ? 'أيام الغياب هذا الشهر'
                            : 'أيام غياب $studentName هذا الشهر',
                        style: AppType.title.copyWith(color: t.ink),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: t.line),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                  itemCount: absentDates.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: t.line),
                  itemBuilder: (_, i) {
                    final d = absentDates[i];
                    return ListTile(
                      dense: true,
                      leading:
                          Icon(Icons.close_rounded, color: t.danger, size: 18),
                      title: Text(FormatHelper.formatDate(d),
                          style: AppType.body.copyWith(color: t.ink)),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
          ),
        ),
      );
    },
  );
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
    required this.attendanceController,
    this.defaultAmount,
  });

  final int studentId;
  final String studentName;
  final DateTime initialDate;
  final double? defaultAmount;
  final PaymentController controller;
  final AttendanceController attendanceController;

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

  /// إجمالي المديونية المتراكمة الحقيقية على الطالب دلوقتي — بيُحسب هنا
  /// من غير الاعتماد على defaultAmount اللي ممكن يكون مبلغ شهر واحد بس
  /// (لو الشيت اتفتحت من صف "لم يدفع" لشهر معيّن)، عشان السقف يفضل
  /// صحيح حتى لو الطالب عليه أكتر من شهر.
  double? _remainingDebt() {
    final allStudents = Get.find<StudentController>().students;
    final student =
        allStudents.firstWhereOrNull((s) => s.id == widget.studentId);
    if (student == null) return null;
    final group = Get.find<GroupController>()
        .groups
        .firstWhereOrNull((g) => g.id == student.groupId);
    return PricingHelper.accumulatedDebt(
      student: student,
      group: group,
      allAttendance: widget.attendanceController.attendance,
      payments: widget.controller.payments
          .where((p) => p.studentId == widget.studentId)
          .toList(),
      siblingGroupMembers: allStudents,
    );
  }

  Future<void> _save() async {
    final text = _amountCtrl.text.trim();
    final parsed = double.tryParse(text);
    if (text.isEmpty || parsed == null || parsed <= 0) {
      if (mounted) AppToast.error(context, 'يرجى إدخال مبلغ صحيح');
      return;
    }
    final remaining = _remainingDebt();
    if (remaining != null && parsed > remaining + 0.01) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('المبلغ أكبر من المستحق'),
          content: Text(
              'المبلغ (${FormatHelper.formatCurrency(parsed)}) أكبر من '
              'المستحق على الطالب (${FormatHelper.formatCurrency(remaining)}).'
              ' متأكد إنك عايز تسجّل الدفعة دي؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('تسجيل على أي حال')),
          ],
        ),
      );
      if (!mounted || proceed != true) return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.addPayment(
        Payment(
          studentId: widget.studentId,
          date: _date,
          amount: parsed,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        AppToast.success(
          context,
          'تم تسجيل الدفعة بنجاح',
          subtitle:
              '${widget.studentName} • ${FormatHelper.formatCurrency(parsed)}',
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
    final t = context.tokens;
    // ألوان الحالات فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final remaining = _remainingDebt();
    final paidUp = remaining != null && remaining <= 0.01;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.board)),
        ),
        // SingleChildScrollView: لوحة المفاتيح والشاشات الصغيرة.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس السبورة: العنوان واسم الطالب والمتبقي عليه
              Container(
                color: t.board,
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.lg, AppSpace.sm, AppSpace.xs, AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: t.boardLine,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(children: [
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSpace.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تسجيل دفعة',
                                  style: AppType.title.copyWith(
                                      fontSize: 18, color: t.boardInk)),
                              if (widget.studentName.isNotEmpty)
                                Text(widget.studentName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.body
                                        .copyWith(color: t.boardInkSoft)),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: t.boardInk,
                        tooltip: 'إغلاق',
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
                    ]),
                    // حالة المديونية — قبل ما المدرس يكتب أي مبلغ، يعرف على
                    // طول لو الطالب دافع بالفعل أو لسه عليه فلوس.
                    if (remaining != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            end: AppSpace.md, top: AppSpace.xs),
                        child: paidUp
                            ? Row(children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 20, color: on.positive),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: Text(
                                      'الطالب مفيهوش أي مديونية حاليًا',
                                      style: AppType.body
                                          .copyWith(color: on.positive)),
                                ),
                              ])
                            : Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: AppSpace.sm,
                                children: [
                                  Text('متبقي عليه',
                                      style: AppType.caption
                                          .copyWith(color: t.boardInkSoft)),
                                  Text(
                                      FormatHelper.formatCurrency(remaining),
                                      style: AppType.figure
                                          .copyWith(color: on.danger)),
                                ],
                              ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ملخص الحضور هذا الشهر
                    Obx(() {
                      final summary = widget.attendanceController
                          .getStudentMonthAttendance(
                              widget.studentId, widget.initialDate);
                      return _AttendanceHintChip(
                        presentCount: summary.presentCount,
                        absentDates: summary.absentDates,
                        studentName: widget.studentName,
                      );
                    }),
                    const SizedBox(height: AppSpace.md),

                    // التاريخ
                    Material(
                      color: t.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        side: BorderSide(color: t.line),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date.isAfter(DateTime.now())
                                ? DateTime.now()
                                : _date,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 30)),
                            helpText: 'اختر التاريخ',
                            confirmText: 'تأكيد',
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.md),
                            child: Row(children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 20, color: t.brand),
                              const SizedBox(width: AppSpace.md),
                              Text(FormatHelper.formatDate(_date),
                                  style:
                                      AppType.body.copyWith(color: t.ink)),
                              const Spacer(),
                              Icon(Icons.edit_calendar_rounded,
                                  size: 20, color: t.inkFaint),
                            ]),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpace.md),

                    // المبلغ
                    CustomTextField(
                      controller: _amountCtrl,
                      label: 'المبلغ *',
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: AppSpace.md),

                    // ملاحظات
                    CustomTextField(
                      controller: _noteCtrl,
                      label: 'ملاحظات (اختياري)',
                      maxLines: 2,
                    ),

                    const SizedBox(height: AppSpace.lg),

                    // زرار الحفظ
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.control)),
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
                          style: AppType.label.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/utils/payment_reminder_message.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/report_controller.dart';
import 'package:active_class/utils/billing_period.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/income_hint.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/reports/session_breakdown_page.dart';
import 'package:active_class/utils/recitation.dart';
import 'package:active_class/utils/reports_overview.dart';
import 'package:active_class/utils/exams_report.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/report_trend.dart';
import 'package:active_class/widgets/report_trend_card.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/utils/report_scope.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  final ReportController ctrl = Get.put(ReportController());
  late final TabController _tabs = TabController(length: 6, vsync: this);

  /// فلتر المجموعة المشترك بين كل التبويبات (null = كل المجموعات).
  final Rxn<int> _groupId = Rxn<int>();

  /// فلتر السنتر (null = كل السناتر، أو اسم سنتر، أو kNoCenterFilter لـ«بدون سنتر»). لو اتحدد
  /// بتتحسب كل التقارير على مجموعات السنتر ده (أو مجموعة منه لو اخترت واحدة).
  final Rxn<String> _center = Rxn<String>();

  /// نطاق التقرير: null = كل المجموعات.
  Set<int>? get _scope => reportScope(
      groupId: _groupId.value, center: _center.value, groups: ctrl.allGroups);

  static const _kTabOverview = 0;
  static const _kTabAttendance = 1;
  static const _kTabPayments = 2;
  static const _kTabHomework = 3;
  static const _kTabExams = 4;
  static const _kTabGroups = 5;

  @override
  void initState() {
    super.initState();
    // الـcontroller بيفضل عايش، فالشهر القديم كان بيتفتح عليه تاني — نرجّعه
    // للشهر الافتراضي في كل دخول.
    ctrl.setMonth(defaultCollectionMonth());
    ctrl.loadReports();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ─── بيانات بعد فلتر المجموعة ────────────────────────────────────────────
  // شامل المؤرشفين: حضورهم بيتحسب في شهور شغّلوا فيها، ومجموعتهم لازم
  // تتعرف (كان بيظهر تحت «مجموعة محذوفة»).
  Map<int, int> get _groupOfStudent => {
        for (final s in [...ctrl.allStudents, ...ctrl.archivedStudents])
          if (s.id != null) s.id!: s.groupId
      };

  Iterable<GroupMonthSummary> get _summaries {
    final scope = _scope;
    return scope == null
        ? ctrl.groupSummaries
        : ctrl.groupSummaries.where((g) => inReportScope(g.group.id, scope));
  }

  List<AtRiskStudent> get _unpaid {
    final scope = _scope;
    final all = ctrl.unpaidStudents;
    return scope == null
        ? all
        : all.where((u) => inReportScope(u.group?.id, scope)).toList();
  }

  double get _expected => _scope == null
      ? ctrl.monthExpected
      : _summaries.fold<double>(0, (a, g) => a + g.expectedIncome);

  double get _collected => _scope == null
      ? ctrl.monthTotalCollected
      : _summaries.fold<double>(0, (a, g) => a + g.collectedIncome);

  double get _overdue => _scope == null
      ? ctrl.totalOverdue
      : _unpaid.fold<double>(0, (a, u) => a + u.remaining);

  AttendanceReport get _attendance => computeAttendanceReport(
        monthAttendance: ctrl.monthAttendance,
        groupOfStudent: _groupOfStudent,
        groupIds: _scope,
        // المؤرشفين في الإجماليات بس، مش في قوايم «أكتر غياب/تأخير».
        rankExclude: {
          for (final s in ctrl.archivedStudents)
            if (s.id != null) s.id!
        },
      );

  /// اسم الطالب لكل id — شامل المؤرشفين (حضورهم لسه ظاهر في شهور شغّلوا فيها)،
  /// وإلا كان بيظهر «طالب» من غير اسم.
  Map<int, String> get _studentNames => {
        for (final s in ctrl.allStudents)
          if (s.id != null) s.id!: s.name,
        for (final s in ctrl.archivedStudents)
          if (s.id != null) s.id!: '${s.name} (مؤرشف)',
      };

  ExamsReport get _exams => computeExamsReport(
        month: ctrl.selectedMonth.value,
        exams: ctrl.allExams,
        grades: ctrl.allExamGrades,
        groupOfStudent: _groupOfStudent,
        studentsPerGroup: {
          for (final g in ctrl.allGroups)
            if (g.id != null)
              g.id!: ctrl.allStudents.where((s) => s.groupId == g.id).length
        },
        groupIds: _scope,
      );

  // ─── اتجاه آخر ٦ شهور (نفس فلتر المجموعة) ──────────────────────────────────
  TrendPoint _pointFor(DateTime m) {
    final scope = _scope;
    final sums = ctrl
        .groupSummariesFor(m)
        .where((g) => inReportScope(g.group.id, scope))
        .toList();
    final exp = sums.fold<double>(0, (a, g) => a + g.expectedIncome);
    final col = sums.fold<double>(0, (a, g) => a + g.collectedIncome);
    final hwDone = sums.fold<int>(0, (a, g) => a + g.totalHomeworkDone);
    final hwNot = sums.fold<int>(0, (a, g) => a + g.totalHomeworkNotDone);
    final att = computeAttendanceReport(
      monthAttendance: ctrl.attendanceIn(m),
      groupOfStudent: _groupOfStudent,
      groupIds: scope,
    ).rate;
    final ex = computeExamsReport(
      month: m,
      exams: ctrl.allExams,
      grades: ctrl.allExamGrades,
      groupOfStudent: _groupOfStudent,
      studentsPerGroup: const {},
      groupIds: scope,
    ).avgPct;
    return TrendPoint(
      month: m,
      attendance: att,
      collection: ratio(col, exp),
      homework: ratio(hwDone, hwDone + hwNot),
      exams: ex == null ? null : ex / 100,
    );
  }

  List<TrendPoint> get _trend => [
        for (final m in lastMonths(ctrl.selectedMonth.value)) _pointFor(m)
      ];

  String _money(double v) => FormatHelper.formatCurrency(v);
  String _pct(double? r) => r == null ? '—' : '${(r * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(
        context,
        title: 'التقارير',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              ctrl.loadReports();
            },
          ),
          Obx(() => ctrl.isExporting.value
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: t.boardInk),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'تصدير PDF',
                  onPressed: () => _showExportMenu(context, ctrl),
                )),
        ],
      ),
      body: ColoredBox(
        color: t.page,
        child: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              _hero(context),
              _tabBar(t),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _overviewTab(context),
                    _attendanceTab(context),
                    _paymentsTab(context),
                    _homeworkTab(context),
                    _examsTab(context),
                    _groupsTab(context),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─── سبورة: الشهر + فلتر المجموعة (مشتركين بين كل التبويبات) ───────────────
  Widget _hero(BuildContext context) {
    final t = context.tokens;
    final month = ctrl.selectedMonth.value;
    final dateFmt = DateFormat('MMMM yyyy', 'ar');
    return Container(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.md),
      decoration: BoxDecoration(
        color: t.board,
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.board)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'الشهر السابق',
                icon: Icon(Icons.chevron_right_rounded, color: t.boardInk),
                onPressed: () =>
                    ctrl.setMonth(DateTime(month.year, month.month - 1)),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: month,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      helpText: 'اختر شهرًا',
                    );
                    if (picked != null) {
                      ctrl.setMonth(DateTime(picked.year, picked.month));
                    }
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(dateFmt.format(month),
                              textAlign: TextAlign.center,
                              style:
                                  AppType.title.copyWith(color: t.boardInk)),
                          Text('اضغط لتغيير الشهر',
                              textAlign: TextAlign.center,
                              style:
                                  AppType.caption.copyWith(color: t.chalk)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'الشهر التالي',
                icon: Icon(Icons.chevron_left_rounded, color: t.boardInk),
                onPressed: !DateTime(month.year, month.month + 1).isAfter(
                        DateTime(DateTime.now().year, DateTime.now().month))
                    ? () => ctrl
                        .setMonth(DateTime(month.year, month.month + 1))
                    : null,
              ),
            ],
          ),
          // فلتر السنتر (بيظهر بس لو فيه سناتر)
          if (GroupController.centersOf(ctrl.allGroups).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                decoration: BoxDecoration(
                  color: t.boardLine,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Row(children: [
                  Icon(Icons.apartment_rounded, size: 18, color: t.boardInkSoft),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _center.value,
                        isExpanded: true,
                        dropdownColor: t.board,
                        iconEnabledColor: t.boardInk,
                        style: AppType.label.copyWith(color: t.boardInk),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('كل السناتر')),
                          for (final c in GroupController.centersOf(ctrl.allGroups))
                            DropdownMenuItem<String?>(value: c, child: Text(c)),
                          if (ctrl.allGroups.any((g) =>
                              GroupController.normalizeCenter(g.center) == null))
                            const DropdownMenuItem<String?>(
                                value: GroupController.kNoCenterFilter,
                                child: Text('بدون سنتر')),
                        ],
                        onChanged: (v) {
                          _center.value = v;
                          // المجموعة المختارة لازم تفضل جوّه السنتر الجديد.
                          final gid = _groupId.value;
                          if (gid != null) {
                            final g = ctrl.allGroups
                                .firstWhereOrNull((x) => x.id == gid);
                            if (g == null ||
                                !GroupController.matchesCenter(g, v)) {
                              _groupId.value = null;
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: AppSpace.xs),
          ],
          // فلتر المجموعة (جوّه السنتر المختار لو فيه)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              decoration: BoxDecoration(
                color: t.boardLine,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(children: [
                Icon(Icons.groups_rounded, size: 18, color: t.boardInkSoft),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _groupId.value,
                      isExpanded: true,
                      dropdownColor: t.board,
                      iconEnabledColor: t.boardInk,
                      style: AppType.label.copyWith(color: t.boardInk),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('كل المجموعات')),
                        for (final g in ctrl.allGroups.where(
                            (x) => GroupController.matchesCenter(x, _center.value)))
                          DropdownMenuItem<int?>(
                              value: g.id, child: Text(g.name)),
                      ],
                      onChanged: (v) => _groupId.value = v,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar(AppTokens t) => Container(
        color: t.page,
        child: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: t.brand,
          unselectedLabelColor: t.inkSoft,
          indicatorColor: t.brand,
          dividerColor: t.line,
          labelStyle: AppType.label,
          unselectedLabelStyle: AppType.label.copyWith(fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'نظرة عامة'),
            Tab(text: 'الحضور'),
            Tab(text: 'الدفعات'),
            Tab(text: 'الواجب والتسميع'),
            Tab(text: 'الامتحانات'),
            Tab(text: 'المجموعات'),
          ],
        ),
      );

  EdgeInsets get _pad => const EdgeInsets.fromLTRB(
      PADDING_NORMAL, PADDING_NORMAL, PADDING_NORMAL, 80);

  // ═══════════════════════════ نظرة عامة ═══════════════════════════════════
  Widget _overviewTab(BuildContext context) {
    final t = context.tokens;
    final month = ctrl.selectedMonth.value;
    final att = _attendance;
    final exr = _exams;
    final trend = _trend;
    final cur = trend.last;
    final prev = trend[trend.length - 2];
    final summaries = _summaries.toList();
    final unpaid = _unpaid;
    final scope = _scope;

    final hwDone = summaries.fold<int>(0, (a, g) => a + g.totalHomeworkDone);
    final hwNot = summaries.fold<int>(0, (a, g) => a + g.totalHomeworkNotDone);
    final hwRate = ratio(hwDone, hwDone + hwNot);
    final collectRate = ratio(_collected, _expected);

    final studentsCount = scope == null
        ? ctrl.allStudents.length
        : ctrl.allStudents.where((s) => scope.contains(s.groupId)).length;
    final nameById = _studentNames;

    return ListView(
      padding: _pad,
      children: [
        LayoutBuilder(builder: (ctx, c) {
          final w = (c.maxWidth - AppSpace.sm) / 2;
          Widget k(Widget x) => SizedBox(width: w, child: x);
          return Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
            k(_Kpi(
              icon: Icons.fact_check_rounded,
              color: t.positive,
              label: 'نسبة الحضور',
              value: _pct(att.rate),
              sub: '${att.present} حضور • ${att.absent} غياب',
              delta: pointsDelta(cur.attendance, prev.attendance),
              onTap: () => _tabs.animateTo(_kTabAttendance),
            )),
            k(_Kpi(
              icon: Icons.request_quote_rounded,
              color: t.brand,
              label: 'المتوقع',
              value: _money(_expected),
              sub: scope == null && ctrl.archivedPaidIncluded > 0.5
                  ? 'مستحق ${DateFormat('MMMM', 'ar').format(month)} + ${_money(ctrl.archivedPaidIncluded)} مؤرشفين'
                  : 'مستحق ${DateFormat('MMMM', 'ar').format(month)}',
              onTap: () => _tabs.animateTo(_kTabPayments),
            )),
            k(_Kpi(
              icon: Icons.account_balance_wallet_outlined,
              color: t.positive,
              label: 'المحصّل',
              value: _money(_collected),
              sub: collectRate == null
                  ? 'مفيش مستحق'
                  : '${_pct(collectRate)} من المتوقع',
              delta: pointsDelta(cur.collection, prev.collection),
              onTap: () => _tabs.animateTo(_kTabPayments),
            )),
            k(_Kpi(
              icon: Icons.warning_amber_rounded,
              color: t.danger,
              label: 'المتأخر',
              value: _money(_overdue),
              sub: '${unpaid.length} طالب لم يسددوا',
              onTap: () => _tabs.animateTo(_kTabPayments),
            )),
            k(_Kpi(
              icon: Icons.menu_book_rounded,
              color: t.caution,
              label: 'التزام الواجب',
              value: _pct(hwRate),
              sub: '$hwDone عملوه • $hwNot لم يعملوه',
              delta: pointsDelta(cur.homework, prev.homework),
              onTap: () => _tabs.animateTo(_kTabHomework),
            )),
            if (TeamModeService().canSeeAcademics)
              k(_Kpi(
              icon: Icons.quiz_rounded,
              color: t.brand,
              label: 'متوسط الامتحانات',
              value: exr.avgPct == null ? '—' : '${exr.avgPct!.round()}%',
              sub: exr.exams.isEmpty
                  ? 'مفيش امتحانات الشهر ده'
                  : '${exr.exams.length} امتحان • نجاح ${_pct(exr.passRate)}',
              delta: pointsDelta(cur.exams, prev.exams),
              onTap: () => _tabs.animateTo(_kTabExams),
            )),
            k(_Kpi(
              icon: Icons.groups_rounded,
              color: t.inkSoft,
              label: 'الطلاب',
              value: '$studentsCount',
              sub: scope == null
                  ? '${ctrl.allGroups.length} مجموعة'
                  : 'في ${scope.length == 1 ? 'المجموعة دي' : 'النطاق ده'}',
              onTap: () => _tabs.animateTo(_kTabGroups),
            )),
          ]);
        }),
        const SizedBox(height: AppSpace.lg),

        // ── الاتجاه ──
        Text('الاتجاه — آخر ٦ شهور', style: AppType.label.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        ReportTrendCard(
            points: trend, showExams: TeamModeService().canSeeAcademics),
        const SizedBox(height: AppSpace.lg),

        // ── محتاج انتباه ──
        Text('محتاج انتباه', style: AppType.label.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _attnTitle(t, Icons.money_off_rounded, t.danger, 'أكتر مديونية',
                  () => _tabs.animateTo(_kTabPayments)),
              if (unpaid.isEmpty)
                _attnEmpty(t, 'مفيش حد عليه مديونية الشهر ده 🎉')
              else
                for (final u in unpaid.take(3))
                  _attnRow(t, u.student.name, _money(u.remaining), t.danger),
              const Divider(height: AppSpace.lg),
              _attnTitle(t, Icons.person_off_rounded, t.caution, 'أكتر غياب',
                  () => _tabs.animateTo(_kTabAttendance)),
              if (att.topAbsent.isEmpty)
                _attnEmpty(t, 'مفيش غياب متسجّل الشهر ده')
              else
                for (final e in att.topAbsent.take(3))
                  _attnRow(t, nameById[e.studentId] ?? 'طالب محذوف',
                      '${e.count} غياب', t.caution),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),

        // ── تقارير تانية ──
        Text('تقارير وصفحات تانية', style: AppType.label.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        _LinkTile(
            icon: Icons.quiz_rounded,
            title: 'الامتحانات',
            sub: 'الدرجات ولوحة الشرف والتحليلات',
            onTap: () => Get.toNamed(ROUTE_EXAMS)),
        const SizedBox(height: AppSpace.sm),
        _LinkTile(
            icon: Icons.health_and_safety_rounded,
            title: 'الطلاب المحتاجين متابعة',
            sub: 'غياب متتالي، واجب ناقص، هبوط درجات',
            onTap: () => Get.toNamed(ROUTE_AT_RISK_STUDENTS)),
        const SizedBox(height: AppSpace.sm),
        _LinkTile(
            icon: Icons.payments_rounded,
            title: 'دخلي (الكاش الفعلي)',
            sub: 'الفلوس اللي دخلت فعلًا في ${DateFormat('MMMM', 'ar').format(month)}',
            onTap: () => openIncomePage(month: month)),
        const SizedBox(height: AppSpace.sm),
        _LinkTile(
            icon: Icons.receipt_long_rounded,
            title: 'تقرير الدفعات التفصيلي',
            sub: 'جدول بالطلاب والمبالغ والحالة',
            onTap: () => Get.toNamed(ROUTE_PAYMENTS_REPORT)),
      ],
    );
  }

  Widget _attnTitle(AppTokens t, IconData icon, Color c, String title,
          VoidCallback onAll) =>
      Row(children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 6),
        Expanded(
            child: Text(title, style: AppType.label.copyWith(color: t.ink))),
        TextButton(
          onPressed: onAll,
          style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
          child: const Text('عرض الكل'),
        ),
      ]);

  Widget _attnRow(AppTokens t, String name, String value, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: t.ink))),
          Text(value,
              style: AppType.label.copyWith(color: c)),
        ]),
      );

  Widget _attnEmpty(AppTokens t, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: AppType.body.copyWith(color: t.inkSoft)),
      );

  // ═══════════════════════════ الحضور ═══════════════════════════════════════
  Widget _attendanceTab(BuildContext context) {
    final t = context.tokens;
    final att = _attendance;
    final nameById = _studentNames;
    final groupName = {for (final g in ctrl.allGroups) g.id: g.name};

    if (att.total == 0) {
      return ListView(padding: _pad, children: const [
        EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'مفيش حضور متسجّل',
          subtitle: 'مفيش تسجيل حضور في الشهر ده للمجموعة المختارة',
        ),
      ]);
    }

    final groupsList = att.byGroup.entries.toList()
      ..sort((a, b) =>
          (b.value.rate ?? -1).compareTo(a.value.rate ?? -1));

    return ListView(
      padding: _pad,
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: _Fig('نسبة الحضور', _pct(att.rate), t.positive)),
                Expanded(child: _Fig('حضور', '${att.present}', t.positive)),
                Expanded(child: _Fig('غياب', '${att.absent}', t.danger)),
                Expanded(child: _Fig('منهم متأخر', '${att.late}', t.caution)),
              ]),
              const SizedBox(height: AppSpace.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (att.rate ?? 0).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: t.danger.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation(t.positive),
                ),
              ),
              const SizedBox(height: 4),
              Text('النسبة = (حاضر + متأخر) ÷ (حاضر + متأخر + غائب)',
                  style: AppType.caption.copyWith(color: t.inkFaint)),
            ],
          ),
        ),
        if (_groupId.value == null && groupsList.length > 1) ...[
          const SizedBox(height: AppSpace.lg),
          Text('حسب المجموعة', style: AppType.label.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.sm),
          AppPanel(
            child: Column(children: [
              for (final e in groupsList)
                _barRow(
                    t,
                    groupName[e.key] ?? 'بدون مجموعة',
                    e.value.rate,
                    '${e.value.present} حضور • ${e.value.absent} غياب'),
            ]),
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        _rankPanel(t, 'أكتر الطلاب غيابًا', Icons.person_off_rounded, t.danger,
            [for (final e in att.topAbsent) (nameById[e.studentId] ?? 'طالب محذوف', '${e.count} غياب')]),
        const SizedBox(height: AppSpace.md),
        _rankPanel(t, 'أكتر الطلاب تأخيرًا', Icons.schedule_rounded, t.caution,
            [for (final e in att.topLate) (nameById[e.studentId] ?? 'طالب محذوف', '${e.count} مرة')]),
        const SizedBox(height: AppSpace.md),
        OutlinedButton.icon(
          onPressed: () => _showExportMenu(context, ctrl),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('تقرير الحضور PDF'),
        ),
      ],
    );
  }

  Widget _rankPanel(AppTokens t, String title, IconData icon, Color c,
      List<(String, String)> rows) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 6),
            Text(title, style: AppType.label.copyWith(color: t.ink)),
          ]),
          const SizedBox(height: AppSpace.sm),
          if (rows.isEmpty)
            Text('مفيش',
                style: AppType.body.copyWith(color: t.inkSoft))
          else
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                      width: 24,
                      child: Text('${i + 1}',
                          style: AppType.label.copyWith(color: t.inkSoft))),
                  Expanded(
                      child: Text(rows[i].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(color: t.ink))),
                  Text(rows[i].$2,
                      style: AppType.label.copyWith(color: c)),
                ]),
              ),
        ],
      ),
    );
  }

  Widget _barRow(AppTokens t, String name, double? rate, String sub) {
    final c = rate == null
        ? t.inkFaint
        : rate >= 0.8
            ? t.positive
            : rate >= 0.6
                ? t.caution
                : t.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: t.ink))),
          Text(_pct(rate), style: AppType.label.copyWith(color: c)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (rate ?? 0).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: t.line,
            valueColor: AlwaysStoppedAnimation(c),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(sub, style: AppType.caption.copyWith(color: t.inkFaint)),
        ),
      ]),
    );
  }

  // ═══════════════════════════ الدفعات ═══════════════════════════════════════
  Widget _paymentsTab(BuildContext context) {
    final t = context.tokens;
    final month = ctrl.selectedMonth.value;
    final dateFmt = DateFormat('MMMM yyyy', 'ar');
    final unpaid = _unpaid;
    return ListView(
      padding: _pad,
      children: [
                    // ─── Monthly income summary ─────────────────────────────
                    AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: t.positive.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: t.positive),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'المحصّلات الشهرية',
                                style: AppType.label
                                    .copyWith(color: context.tokens.ink),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _IncomeBox(
                                  label: 'المحصّل',
                                  amount: _collected,
                                  color: t.positive,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _IncomeBox(
                                  label: 'المتوقع',
                                  amount: _expected,
                                  color: t.brand,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _IncomeBox(
                                  label: 'المتأخر',
                                  // نفس مجموع قايمة «غير المسددين» (متراكم)
                                  amount: _overdue,
                                  color: t.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'المتأخر = المتبقي من مستحق الشهر (زي الرئيسية)',
                            style: TextStyle(fontSize: 11, color: t.inkSoft),
                          ),
                          const SizedBox(height: 12),
                          // Collection progress bar
                          Builder(builder: (context) {
                            final expected = _expected;
                            final collected = _collected;
                            final progress = expected == 0
                                ? 0.0
                                : (collected / expected).clamp(0.0, 1.0);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('نسبة التحصيل',
                                        style: TextStyle(
                                            fontSize: 12, color: t.inkSoft)),
                                    Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: progress >= 0.8
                                              ? t.positive
                                              : t.caution),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor:
                                        t.positive.withValues(alpha: 0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        progress >= 0.8
                                            ? t.positive
                                            : t.cautionBar),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),

        if (_scope == null && ctrl.archivedPaidIncluded > 0.5)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'المتوقع والمحصّل شاملين ${_money(ctrl.archivedPaidIncluded)} دفعها طلاب مؤرشفين كانوا شغّالين في الشهر ده (من غير مديونية عليهم).',
              style: AppType.caption.copyWith(color: t.inkSoft, height: 1.5),
            ),
          ),
        const SizedBox(height: 12),
        IncomeLinkTile(
          month: month,
          title: 'دخلي ${DateFormat('MMMM', 'ar').format(month)}',
          hint: 'الكاش اللي دخل فعلًا بتاريخ الدفعة، مش توزيع المستحق.',
        ),
        const SizedBox(height: AppSpace.lg),

        // ── المتأخرين ──
        _SectionHeader(
            icon: Icons.warning_amber_rounded,
            title: 'طلاب لم يسددوا بالكامل',
            subtitle: dateFmt.format(month),
            color: t.caution),
        const SizedBox(height: 8),
        if (unpaid.isEmpty)
          AppPanel(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, color: t.positive),
                  const SizedBox(width: 8),
                  Text('جميع الطلاب سددوا هذا الشهر 🎉',
                      style: AppType.body.copyWith(color: t.ink)),
                ],
              ),
            ),
          )
        else ...[
          AppPanel(
            child: Column(children: [
              for (final u in unpaid.take(15))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.student.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.body.copyWith(color: t.ink)),
                          if (u.group != null)
                            Text(u.group!.name,
                                style: AppType.caption
                                    .copyWith(color: t.inkFaint)),
                        ],
                      ),
                    ),
                    Text(_money(u.remaining),
                        style: AppType.label.copyWith(color: t.danger)),
                  ]),
                ),
              if (unpaid.length > 15)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('و${unpaid.length - 15} طالب تانيين — في تقرير الدفعات',
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                ),
            ]),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDebtorsGroupAndPrint(context, ctrl),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('طباعة المديونيات'),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Get.toNamed(ROUTE_PAYMENTS_REPORT),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('تقرير الدفعات'),
              ),
            ),
          ]),
        ],
      ],
    );
  }

  // ═══════════════════════════ الامتحانات ═══════════════════════════════════
  Widget _miniTitle(AppTokens t, IconData icon, Color c, String title) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 6),
          Text(title, style: AppType.label.copyWith(color: t.ink)),
        ]),
      );

  Widget _examsTab(BuildContext context) {
    final t = context.tokens;
    // المساعد من غير صلاحية «الأكاديمي»: درجات الامتحانات مقفولة عنده.
    if (!TeamModeService().canSeeAcademics) {
      return ListView(padding: _pad, children: [
        AppPanel(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Column(children: [
              Icon(Icons.lock_rounded, color: t.inkSoft, size: 28),
              const SizedBox(height: AppSpace.sm),
              Text('درجات الامتحانات مقفولة عليك',
                  textAlign: TextAlign.center,
                  style: AppType.label.copyWith(color: t.ink)),
              const SizedBox(height: 4),
              Text('اطلب من المدرس يفتح لك صلاحية عرض الأكاديمي.',
                  textAlign: TextAlign.center,
                  style: AppType.caption.copyWith(color: t.inkSoft)),
            ]),
          ),
        ),
      ]);
    }
    final r = _exams;
    final names = _studentNames;
    final dayFmt = DateFormat('d MMMM', 'ar');
    final link = _LinkTile(
        icon: Icons.quiz_rounded,
        title: 'صفحة الامتحانات',
        sub: 'الدرجات ولوحة الشرف والتحليلات',
        onTap: () => Get.toNamed(ROUTE_EXAMS));
    if (r.exams.isEmpty) {
      return ListView(padding: _pad, children: [
        AppPanel(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Text('مفيش امتحانات محسوبة على الشهر ده.',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: t.inkSoft)),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        link,
      ]);
    }
    Color rateColor(double? pct) => pct == null
        ? t.inkFaint
        : pct >= 80
            ? t.positive
            : pct >= 60
                ? t.caution
                : t.danger;
    String p0(double? v) => v == null ? '—' : '${v.round()}%';
    Color passColor(double? r) => rateColor(r == null ? null : r * 100);
    final dist = r.distribution;
    return ListView(
      padding: _pad,
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: _Fig(
                        'متوسط الدرجات', p0(r.avgPct), rateColor(r.avgPct))),
                Expanded(
                    child: _Fig('نسبة النجاح', _pct(r.passRate),
                        passColor(r.passRate))),
                Expanded(child: _Fig('امتحانات', '${r.exams.length}', t.brand)),
              ]),
              const SizedBox(height: AppSpace.sm),
              Text(
                '${r.graded} درجة متسجّلة • ${r.absent} غياب عن الامتحان. الغايب مش داخل في المتوسط ولا النجاح.',
                style: AppType.caption.copyWith(color: t.inkSoft, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text('امتحانات الشهر', style: AppType.label.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        for (final x in r.exams) ...[
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(x.exam.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.label.copyWith(color: t.ink))),
                  Text(dayFmt.format(x.exam.date),
                      style: AppType.caption.copyWith(color: t.inkFaint)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: _Fig(
                          'المتوسط', p0(x.avgPct), rateColor(x.avgPct))),
                  Expanded(
                      child: _Fig(
                          'النجاح', _pct(x.passRate), passColor(x.passRate))),
                  Expanded(child: _Fig('الأعلى', p0(x.maxPct), t.positive)),
                  Expanded(child: _Fig('الأقل', p0(x.minPct), t.danger)),
                ]),
                const SizedBox(height: 6),
                Text(
                  '${x.graded} اتصحّح'
                  '${x.absent > 0 ? ' • ${x.absent} غايب' : ''}'
                  '${x.pending > 0 ? ' • ${x.pending} لسه ما اتسجلش' : ''}',
                  style: AppType.caption.copyWith(color: t.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        if (dist.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Text('توزيع التقديرات', style: AppType.label.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.sm),
          AppPanel(
            child: Column(children: [
              for (final c in const [
                GradeCategory.excellent,
                GradeCategory.veryGood,
                GradeCategory.good,
                GradeCategory.pass,
                GradeCategory.fail,
              ])
                _barRow(t, c.label, ratio(dist[c] ?? 0, r.graded),
                    '${dist[c] ?? 0} درجة'),
            ]),
          ),
          const SizedBox(height: AppSpace.lg),
        ],
        Text('الطلاب (متوسط امتحانات الشهر)',
            style: AppType.label.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _miniTitle(t, Icons.emoji_events_rounded, t.positive, 'الأعلى'),
              for (final s in r.top)
                _attnRow(t, names[s.studentId] ?? 'طالب محذوف', p0(s.avgPct),
                    t.positive),
              if (r.studentsCount > r.top.length) ...[
                const Divider(height: AppSpace.lg),
                _miniTitle(
                    t, Icons.trending_down_rounded, t.danger, 'الأقل'),
                for (final s in r.bottom)
                  _attnRow(t, names[s.studentId] ?? 'طالب محذوف',
                      p0(s.avgPct), t.danger),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        link,
      ],
    );
  }

  // ═══════════════════════════ الواجب والتسميع ═══════════════════════════════
  Widget _homeworkTab(BuildContext context) {
    final t = context.tokens;
    final month = ctrl.selectedMonth.value;
    final dateFmt = DateFormat('MMMM yyyy', 'ar');
    final summaries = _summaries.toList();
    final done = summaries.fold<int>(0, (a, g) => a + g.totalHomeworkDone);
    final notDone = summaries.fold<int>(0, (a, g) => a + g.totalHomeworkNotDone);
    return ListView(
      padding: _pad,
      children: [
        AppPanel(
          child: done + notDone == 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  child: Text('مفيش واجب متسجّل في الشهر ده.',
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(color: t.inkSoft)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: _Fig('نسبة الالتزام',
                              _pct(ratio(done, done + notDone)), t.positive)),
                      Expanded(child: _Fig('عملوه', '$done', t.positive)),
                      Expanded(child: _Fig('لم يعملوه', '$notDone', t.danger)),
                    ]),
                    if (_groupId.value == null && summaries.length > 1) ...[
                      const SizedBox(height: AppSpace.md),
                      for (final g in summaries)
                        _barRow(
                            t,
                            g.group.name,
                            ratio(g.totalHomeworkDone,
                                g.totalHomeworkDone + g.totalHomeworkNotDone),
                            '${g.totalHomeworkDone} عملوه • ${g.totalHomeworkNotDone} لم يعملوه'),
                    ],
                    const SizedBox(height: 4),
                    Text('«عمل الواجب» يشمل الناقص (محاولة تُحتسب).',
                        style: AppType.caption.copyWith(color: t.inkFaint)),
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.sm),
                    // ─── spec 048: التسميع (لو مفعّل وفيه درجات الشهر) ─────
                    Builder(builder: (context) {
                      final cfg = Get.find<SettingsController>();
                      if (!cfg.showRecitation.value)
                        return const SizedBox.shrink();
                      final maxNow = cfg.recitationMax.value;
                      final standings = recitationStandings(ctrl.allAttendance,
                          month: month, scaleTo: maxNow);
                      if (standings.isEmpty) return const SizedBox.shrink();
                      final monthAvg = recitationAverage(ctrl.allAttendance,
                          month: month, scaleTo: maxNow);
                      final nameById = _studentNames;
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AppPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0EA5E9)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.record_voice_over_rounded,
                                      color: Color(0xFF0EA5E9)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                      'التسميع — ${dateFmt.format(month)}',
                                      style: AppType.label
                                          .copyWith(color: context.tokens.ink)),
                                ),
                                Text(
                                    'المتوسط ${recitationAverageLabel(monthAvg)}/$maxNow',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0EA5E9))),
                              ]),
                              const SizedBox(height: 10),
                              for (var i = 0; i < standings.take(5).length; i++)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(children: [
                                    SizedBox(
                                        width: 22,
                                        child: Text('${i + 1}',
                                            style: TextStyle(
                                                color: t.inkSoft,
                                                fontWeight: FontWeight.w700))),
                                    Expanded(
                                        child: Text(
                                            nameById[standings[i].studentId] ??
                                                'طالب محذوف',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                    Text(
                                        '${recitationAverageLabel(standings[i].average)}/$maxNow  (${standings[i].count})',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
        const SizedBox(height: AppSpace.md),
        OutlinedButton.icon(
          onPressed: () => _showExportMenu(context, ctrl),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('تقرير الواجب PDF'),
        ),
      ],
    );
  }

  // ═══════════════════════════ المجموعات ═════════════════════════════════════
  Widget _groupsTab(BuildContext context) {
    final t = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final month = ctrl.selectedMonth.value;
    final dateFmt = DateFormat('MMMM yyyy', 'ar');
    final groupSummaries = _summaries.toList();
    final unpaid = ctrl.unpaidStudents;
    return ListView(
      padding: _pad,
      children: [
                    // ─── Per-group breakdown ────────────────────────────────
                    _SectionHeader(
                        icon: Icons.groups_rounded,
                        title: 'تفصيل المجموعات',
                        subtitle: dateFmt.format(month)),
                    const SizedBox(height: 8),
                    if (groupSummaries.isEmpty)
                      const EmptyState(
                        icon: Icons.group_off,
                        title: 'لا توجد مجموعات',
                        subtitle: 'أضف مجموعات من الصفحة الرئيسية',
                      )
                    else
                      ...groupSummaries.map((gs) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _GroupSummaryCard(
                              summary: gs,
                              isDark: isDark,
                              // طلاب المجموعة دي بس اللي لسه ماسددوش — بيتعرضوا
                              // في نافذة منفصلة من داخل الكارت نفسه بدل قائمة
                              // طويلة تحت الصفحة (مهم لو عدد الطلاب كبير).
                              unpaidInGroup: unpaid
                                  .where((u) => u.group?.id == gs.group.id)
                                  .toList(),
                            ),
                          )),

      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group summary card
// ─────────────────────────────────────────────────────────────────────────────

class _GroupSummaryCard extends StatelessWidget {
  final GroupMonthSummary summary;
  final bool isDark;
  final List<AtRiskStudent> unpaidInGroup;
  const _GroupSummaryCard({
    required this.summary,
    required this.isDark,
    this.unpaidInGroup = const [],
  });

  void _showUnpaidDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('غير المسددين - ${summary.group.name}'),
        content: SizedBox(
          width: 480,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: unpaidInGroup.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                _UnpaidStudentCard(data: unpaidInGroup[i], isDark: isDark),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Get.find<ReportController>()
                  .printDebtors(groupId: summary.group.id);
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('طباعة'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // لو مفيش أي مستحق أصلاً (زي مجموعة بالحصة لسه محضرش فيها حد الشهر
    // ده)، نسبة التحصيل بتترجع 1.0 افتراضيًا رياضيًا (صفر ÷ صفر)، لكن ده
    // مش معناه "100% تحصيل" فعلي — بنعرضه كحالة محايدة بدل ما يبان أخضر
    // ومطمئن غلط وكأن كل حاجة اتحصّلت.
    final hasExpected = summary.expectedIncome > 0;
    final rate = summary.collectionRate;
    final rateColor = !hasExpected
        ? t.inkFaint
        : rate >= 0.8
            ? t.positive
            : rate >= 0.5
                ? t.caution
                : t.danger;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      onTap: !summary.group.isPerSession
          ? null
          : () => Get.to(() => SessionBreakdownPage(group: summary.group)),
      child: Container(
        decoration: BoxDecoration(
          color: context.tokens.surface,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: Border.all(color: context.tokens.line),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.groups_rounded,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary.group.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Text(
                  '${summary.studentCount} طالب',
                  style: TextStyle(fontSize: 12, color: t.inkSoft),
                ),
                if (summary.group.isPerSession) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_left_rounded, size: 18, color: t.inkFaint),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Row(
              children: [
                _StatBox(
                  label: 'محصّل',
                  child: CurrencyText(
                    summary.collectedIncome,
                    stacked: true,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: t.positive),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                _StatBox(
                  label: 'متوقع',
                  child: CurrencyText(
                    summary.expectedIncome,
                    stacked: true,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: t.brand),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                _StatBox(
                  label: 'مدفوع بالكامل',
                  child: Text(
                    '${summary.fullyPaidCount} / ${summary.dueStudentCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                _StatBox(
                  label: 'حضور',
                  child: Text(
                    summary.totalPresentSessions.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: t.positive),
                  ),
                ),
              ],
            ),
            if (summary.totalHomeworkDone > 0 ||
                summary.totalHomeworkNotDone > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatBox(
                    label: 'عمل الواجب',
                    child: Text(
                      summary.totalHomeworkDone.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: t.brand),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _StatBox(
                    label: 'لم يعمل الواجب',
                    child: Text(
                      summary.totalHomeworkNotDone.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: t.caution),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            // Collection rate bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: hasExpected ? rate.clamp(0.0, 1.0) : 0.0,
                      minHeight: 6,
                      backgroundColor: rateColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          rateColor == t.caution ? t.cautionBar : rateColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  hasExpected ? '${(rate * 100).toStringAsFixed(0)}%' : '—',
                  style: TextStyle(
                      color: rateColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ],
            ),
            // بدل ما نعرض كل الطلاب الغير مسددين في قائمة طويلة تحت الصفحة
            // (ممكن تبقى مئات لو عدد الطلاب كبير)، بنكتفي هنا بعدد لكل
            // مجموعة وزرار يفتح تفاصيلها في نافذة منفصلة.
            if (unpaidInGroup.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showUnpaidDialog(context),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.caution.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: t.caution),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            '${unpaidInGroup.length} طالب لم يسدد بالكامل',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: t.caution)),
                      ),
                      Icon(Icons.chevron_left_rounded,
                          size: 18, color: t.caution),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unpaid student card
// ─────────────────────────────────────────────────────────────────────────────

class _UnpaidStudentCard extends StatelessWidget {
  final AtRiskStudent data;
  final bool isDark;
  const _UnpaidStudentCard({required this.data, required this.isDark});

  Future<void> _sendReminder(BuildContext context) async {
    final hasContact = (data.student.guardianPhone ?? '').trim().isNotEmpty ||
        (data.student.guardianWhatsapp ?? '').trim().isNotEmpty;
    if (!hasContact) {
      AppToast.error(context, 'مفيش رقم أو واتساب ولي أمر مسجّل لهذا الطالب');
      return;
    }
    final settings = Get.find<SettingsController>();
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(data.month);
    final remaining = data.due - data.paid;
    final message = buildPaymentReminderMessage(
      studentName: data.student.name,
      studentCode: data.student.code,
      groupName: data.group?.name ?? '',
      // لو المتبقي متراكم (فيه شهور أقدم) ما نحطش اسم شهر واحد عشان الرسالة
      // ما تقولش إن كل المبلغ عن الشهر ده.
      monthLabel: data.includesOlderMonths ? '' : monthLabel,
      remainingText:
          remaining > 0 ? FormatHelper.formatCurrency(remaining) : '',
      teacherName: settings.teacherFullName.value.trim(),
      teacherSpecialization: settings.teacherSpecialization.value.trim(),
    );
    await launchGuardianWhatsapp(
      context: context,
      phone: data.student.guardianPhone,
      whatsapp: data.student.guardianWhatsapp,
      message: message,
      dialCode: settings.countryDial.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress =
        data.due > 0 ? (data.paid / data.due).clamp(0.0, 1.0) : 0.0;
    final color = data.paid == 0 ? t.danger : t.caution;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  data.student.name.isNotEmpty ? data.student.name[0] : '؟',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.student.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (data.group != null)
                      Text(data.group!.name,
                          style: TextStyle(fontSize: 12, color: t.inkSoft)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CurrencyText(
                    data.remaining,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                  Text('متبقي',
                      style: TextStyle(fontSize: 11, color: t.inkSoft)),
                ],
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _sendReminder(context),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: t.positiveSoft, shape: BoxShape.circle),
                  child:
                      Icon(Icons.message_rounded, size: 16, color: t.positive),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        data.paid > 0 ? t.caution : t.danger),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CurrencyText(
                data.paid,
                style: TextStyle(fontSize: 11, color: t.inkSoft),
              ),
              Text(' / ', style: TextStyle(fontSize: 11, color: t.inkFaint)),
              CurrencyText(
                data.due,
                style: TextStyle(fontSize: 11, color: t.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _IncomeBox extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _IncomeBox(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: t.inkSoft)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: CurrencyText(
              amount,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final Widget child;
  const _StatBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: t.page,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: t.inkSoft)),
            const SizedBox(height: 3),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  const _SectionHeader(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(title,
              style: AppType.label.copyWith(color: context.tokens.ink)),
        ),
        Text(subtitle, style: TextStyle(fontSize: 12, color: t.inkSoft)),
      ],
    );
  }
}

/// نافذة اختيار "كل المجموعات" أو مجموعة فيها طلاب مديونين، ثم الطباعة.
Future<void> _pickDebtorsGroupAndPrint(
    BuildContext context, ReportController ctrl) async {
  final unpaid = ctrl.unpaidStudents;
  if (unpaid.isEmpty) {
    ToastHelper.info('مفيش طلاب عليهم مديونية');
    return;
  }
  final counts = <int, int>{};
  final names = <int, String>{};
  for (final u in unpaid) {
    final gid = u.group?.id;
    if (gid == null) continue;
    counts[gid] = (counts[gid] ?? 0) + 1;
    names[gid] = u.group!.name;
  }
  // -1 = كل المجموعات، null = إلغاء
  final choice = await showModalBottomSheet<int>(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text('طباعة المديونيات',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.groups_rounded),
            title: Text('كل المجموعات (${unpaid.length} طالب)'),
            onTap: () => Navigator.pop(ctx, -1),
          ),
          for (final e in counts.entries)
            ListTile(
              leading: const Icon(Icons.group_rounded),
              title: Text('${names[e.key]} (${e.value} طالب)'),
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  await ctrl.printDebtors(groupId: choice == -1 ? null : choice);
}

// ── حالة "الوضع + النطاق" لشيت التصدير — تتذكّر خلال الجلسة، تتصفّر
//    مع إعادة تشغيل التطبيق (spec 014 US3). لو المدرس غيّر الشهر المعروض
//    في شاشة التقارير، النطاق يتبع الشهر الجديد بدل ما يفضل قديم.
bool _exportRangeMode = false;
DateTime? _exportFrom;
DateTime? _exportTo;
DateTime? _exportSeedMonth;

// فوق حد معيّن الجدول بيطلع أعمدة كتير جدًا (عمود لكل يوم فيه حصة) —
// نحذّر المدرس قبل ما نولّد PDF عريض صعب القراءة (spec 014).
const int _longRangeDaysThreshold = 100;

Future<void> _exportRangeReport(
  BuildContext context,
  ReportController ctrl, {
  required bool attendance,
  required DateTime from,
  required DateTime to,
}) async {
  if (!context.mounted) return;
  final days = to.difference(from).inDays + 1;
  if (days > _longRangeDaysThreshold) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('فترة طويلة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(
            'الفترة $days يوم — جدول التقرير ممكن يطلع عريض جدًا وصعب القراءة على الورق. تحب تكمّل؟',
            style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('متابعة')),
        ],
      ),
    );
    if (ok != true) return;
  }
  if (attendance) {
    ctrl.exportAttendancePDF(from: from, to: to);
  } else {
    ctrl.exportHomeworkPDF(from: from, to: to);
  }
}

// ── قائمة التصدير helper ─────────────────────────────────────────────────────
void _showExportMenu(BuildContext context, ReportController ctrl) {
  final selMonth = ctrl.selectedMonth.value;
  if (_exportFrom == null ||
      _exportSeedMonth == null ||
      _exportSeedMonth!.year != selMonth.year ||
      _exportSeedMonth!.month != selMonth.month) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var f = DateTime(selMonth.year, selMonth.month, 1);
    // "إلى" = نهاية الشهر المختار، بحد أقصى النهاردة (مفيش سجلات في
    // المستقبل، والشهر المستقبلي بالكامل بيبقى نطاق فاضي).
    final monthEnd = DateTime(selMonth.year, selMonth.month + 1, 0);
    var t = monthEnd.isAfter(today) ? today : monthEnd;
    if (f.isAfter(t)) f = t; // شهر مستقبلي → انهار النطاق ليوم واحد
    _exportFrom = f;
    _exportTo = t;
    _exportSeedMonth = DateTime(selMonth.year, selMonth.month, 1);
  }
  if (_exportTo!.isBefore(_exportFrom!)) _exportTo = _exportFrom;

  final dFmt = DateFormat('d MMMM yyyy', 'ar');

  bool licenceOk() => requireLicenseFeature(
      context,
      Get.find<LicenseController>().canExport,
      'تصدير التقارير غير متاح في الفترة التجريبية — قم بالترقية');

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        final range = _exportRangeMode;
        final title = range
            ? 'تصدير تقرير — من ${dFmt.format(_exportFrom!)} إلى ${dFmt.format(_exportTo!)}'
            : 'تصدير تقرير — ${DateFormat('MMMM yyyy', 'ar').format(selMonth)}';

        Future<void> pickFrom() async {
          final p = await showDatePicker(
            context: ctx,
            initialDate: _exportFrom!,
            firstDate: DateTime(2020),
            lastDate: _exportTo!, // مايتعدّاش "إلى"
            helpText: 'من تاريخ',
          );
          if (p != null) {
            setSt(() => _exportFrom = DateTime(p.year, p.month, p.day));
          }
        }

        Future<void> pickTo() async {
          final p = await showDatePicker(
            context: ctx,
            initialDate: _exportTo!,
            firstDate: _exportFrom!, // ماينفعش يبقى قبل "من"
            lastDate: DateTime.now().add(const Duration(days: 365)),
            helpText: 'إلى تاريخ',
          );
          if (p != null) {
            setSt(() => _exportTo = DateTime(p.year, p.month, p.day));
          }
        }

        Widget dateRow(String label, DateTime value, VoidCallback onTap) =>
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Text(label,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                  Text(dFmt.format(value),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Icon(Icons.calendar_today_rounded, size: 16),
                ]),
              ),
            );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // مفتاح الوضع: شهر / فترة مخصصة
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('شهر')),
                  ButtonSegment(value: true, label: Text('فترة مخصصة')),
                ],
                selected: {range},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setSt(() => _exportRangeMode = s.first),
              ),
              const SizedBox(height: 14),

              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),

              if (range) ...[
                const SizedBox(height: 8),
                dateRow('من', _exportFrom!, pickFrom),
                const Divider(height: 1),
                dateRow('إلى', _exportTo!, pickTo),
              ] else ...[
                const SizedBox(height: 4),
                Text('اختر نوع التقرير الذي تريد تصديره كـ PDF',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade600)),
              ],
              const SizedBox(height: 20),

              if (!range) ...[
                _ExportOption(
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF1565C0),
                  title: 'تقرير الدفعات',
                  subtitle: 'جدول بالطلاب والمبالغ والحالة',
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!licenceOk()) return;
                    ctrl.exportPaymentsPDF();
                  },
                ),
                const SizedBox(height: 10),
                _ExportOption(
                  icon: Icons.print_rounded,
                  color: const Color(0xFFDC2626),
                  title: 'طباعة المديونيات',
                  subtitle:
                      'الطلاب اللي عليهم مديونية — كل المجموعات أو مجموعة معيّنة',
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!licenceOk()) return;
                    _pickDebtorsGroupAndPrint(context, ctrl);
                  },
                ),
                const SizedBox(height: 10),
              ],
              _ExportOption(
                icon: Icons.how_to_reg_rounded,
                color: const Color(0xFF2E7D32),
                title: 'تقرير الحضور',
                subtitle: 'حضور وغياب كل طالب + الواجب والتسميع',
                onTap: () {
                  Navigator.pop(ctx);
                  if (!licenceOk()) return;
                  if (range) {
                    _exportRangeReport(context, ctrl,
                        attendance: true, from: _exportFrom!, to: _exportTo!);
                  } else {
                    ctrl.exportAttendancePDF();
                  }
                },
              ),
              const SizedBox(height: 10),
              _ExportOption(
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF2563EB),
                title: 'تقرير الواجب',
                subtitle: 'حالة الواجب لكل طالب + متوسط التسميع',
                onTap: () {
                  Navigator.pop(ctx);
                  if (!licenceOk()) return;
                  if (range) {
                    _exportRangeReport(context, ctrl,
                        attendance: false, from: _exportFrom!, to: _exportTo!);
                  } else {
                    ctrl.exportHomeworkPDF();
                  }
                },
              ),
              if (!range) ...[
                const SizedBox(height: 10),
                _ExportOption(
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFF6A1B9A),
                  title: 'ملخص المجموعات',
                  subtitle: 'إجماليات كل مجموعة (دفعات + حضور + واجب + تسميع)',
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!licenceOk()) return;
                    ctrl.exportGroupsSummaryPDF();
                  },
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

// ── ExportOption widget ───────────────────────────────────────────────────────
class _ExportOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ExportOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: 'Cairo', fontSize: 11, color: t.inkSoft)),
                ],
              ),
            ),
            Icon(Icons.picture_as_pdf_rounded,
                color: color.withValues(alpha: 0.6), size: 18),
          ]),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// ودجتس تبويبات التقارير
// ─────────────────────────────────────────────────────────────────────────────

/// كارت رقم رئيسي قابل للضغط (نظرة عامة).
class _Kpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;

  /// الفرق بالنقط المئوية عن الشهر اللي فات (null = مفيش مقارنة).
  final double? delta;
  const _Kpi({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: '$label: $value. $sub',
      excludeSemantics: true,
      child: AppPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: t.inkSoft)),
              ),
            ]),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value,
                  maxLines: 1,
                  style: AppType.figure.copyWith(color: color, fontSize: 22)),
            ),
            if (delta != null && delta!.abs() >= 0.5)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${delta! > 0 ? '▲' : '▼'} ${delta!.abs().round()} نقط عن الشهر اللي فات',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(
                      color: delta! > 0 ? t.positive : t.danger),
                ),
              ),
            const SizedBox(height: 2),
            Text(sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption.copyWith(color: t.inkFaint)),
          ],
        ),
      ),
    );
  }
}

/// رقم صغير بعنوان (داخل لوحات التبويبات).
class _Fig extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Fig(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value,
            maxLines: 1,
            style: AppType.title.copyWith(color: color)),
      ),
      Text(label,
          textAlign: TextAlign.center,
          style: AppType.caption.copyWith(color: t.inkSoft)),
    ]);
  }
}

/// صف رابط لصفحة تانية.
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _LinkTile(
      {required this.icon,
      required this.title,
      required this.sub,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppPanel(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.rosterTint,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(icon, color: t.rosterInk, size: 22),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.label.copyWith(color: t.ink)),
              Text(sub, style: AppType.caption.copyWith(color: t.inkSoft)),
            ],
          ),
        ),
        Icon(Icons.chevron_left_rounded, size: 20, color: t.inkSoft),
      ]),
    );
  }
}

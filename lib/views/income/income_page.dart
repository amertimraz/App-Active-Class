// lib/views/income/income_page.dart
//
// «دخلي»: الكاش اللي دخل فعلًا في الشهر (بتاريخ الدفعة) — بعيد عن حساب
// المستحق والتوزيع. اشتراكات + كراسات، المصاريف والصافي، مقارنة بالشهر اللي
// فات، دخل كل يوم، وتفصيل بالمجموعات. الحساب كله في computeIncome (صرف).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/models/expense_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/income_summary.dart';
import 'package:active_class/views/help/help_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  final _db = DatabaseService();
  late DateTime _month;
  bool _loading = true;
  Object? _error;

  List<Payment> _payments = const [];
  List<BookletPayment> _booklets = const [];
  Map<int, int> _groupOfStudent = const {};
  Map<int?, String> _groupName = const {};
  List<Expense> _expenses = const [];

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    final nowMonth = DateTime(n.year, n.month, 1);
    // ممكن يتفتح على شهر معيّن (من شاشة المدفوعات)، ومش بعد الشهر الحالي.
    final arg = Get.arguments;
    var m = arg is DateTime ? DateTime(arg.year, arg.month, 1) : nowMonth;
    if (m.isAfter(nowMonth)) m = nowMonth;
    _month = m;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _db.getAllPayments(),
        _db.getAllBookletPayments(),
        _db.getAllStudents(),
        _db.getAllGroups(),
      ]);
      final students = results[2] as List;
      final groups = results[3] as List<Group>;
      _payments = results[0] as List<Payment>;
      _booklets = results[1] as List<BookletPayment>;
      _groupOfStudent = {
        for (final s in students)
          if (s.id != null) s.id as int: s.groupId as int
      };
      _groupName = {for (final g in groups) g.id: g.name};
      await _loadExpenses();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadExpenses() async {
    _expenses = await _db.getExpensesInRange(
        _month, DateTime(_month.year, _month.month + 1, 1));
  }

  Future<void> _shift(int delta) async {
    final next = DateTime(_month.year, _month.month + delta, 1);
    final n = DateTime.now();
    if (next.isAfter(DateTime(n.year, n.month, 1))) return;
    _month = next;
    await _loadExpenses();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final canSee = TeamModeService().canSeeFinancials;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context,
          title: 'دخلي', actions: const [HelpButton(topicId: 'income')]),
      body: !canSee
          ? _centerMsg(t, Icons.lock_rounded,
              'الصفحة دي بتعرض الفلوس، ومتاحة للمدرس أو لمساعد عنده صلاحية الماليات.')
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _errorState(t)
                  : _content(context, t),
    );
  }

  Widget _centerMsg(AppTokens t, IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: t.inkFaint),
            const SizedBox(height: AppSpace.md),
            Text(text,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: t.inkSoft)),
          ]),
        ),
      );

  Widget _errorState(AppTokens t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, size: 40, color: t.danger),
            const SizedBox(height: AppSpace.md),
            Text('تعذّر تحميل الدخل',
                style: AppType.label.copyWith(color: t.ink)),
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ]),
        ),
      );

  String _money(double v) => FormatHelper.formatCurrency(v);

  Widget _content(BuildContext context, AppTokens t) {
    final s = computeIncome(
      month: _month,
      payments: _payments,
      bookletPayments: _booklets,
      groupOfStudent: _groupOfStudent,
      expenses: _expenses,
    );
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final canNext = _month.isBefore(DateTime(now.year, now.month, 1));
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(_month);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
      children: [
        // ── التنقل بين الشهور ──
        Row(children: [
          IconButton(
            tooltip: 'الشهر السابق',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _shift(-1),
          ),
          Expanded(
            child: Text(monthLabel,
                textAlign: TextAlign.center,
                style: AppType.title.copyWith(color: t.ink)),
          ),
          IconButton(
            tooltip: 'الشهر التالي',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: canNext ? () => _shift(1) : null,
          ),
        ]),
        const SizedBox(height: AppSpace.sm),

        _hero(t, s, isCurrent),
        const SizedBox(height: AppSpace.md),

        // ── التفصيل: اشتراكات / كراسات / مصاريف ──
        Row(children: [
          Expanded(
              child: _Figure('اشتراكات', _money(s.tuition), t.positive,
                  sub: '${s.tuitionCount} دفعة')),
          const SizedBox(width: AppSpace.sm),
          Expanded(
              child: _Figure('كراسات', _money(s.booklets), t.brand,
                  sub: '${s.bookletCount} دفعة')),
          const SizedBox(width: AppSpace.sm),
          Expanded(
              child: _Figure('مصاريف', _money(s.expenses), t.danger,
                  sub: s.expenses > 0 ? 'من المصاريف' : 'مفيش')),
        ]),
        if (s.expenses > 0) ...[
          const SizedBox(height: AppSpace.sm),
          AppPanel(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(children: [
              Icon(Icons.savings_rounded,
                  color: s.net >= 0 ? t.positive : t.danger),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text('الصافي بعد المصاريف',
                    style: AppType.label.copyWith(color: t.ink)),
              ),
              Text(_money(s.net),
                  style: AppType.title.copyWith(
                      color: s.net >= 0 ? t.positive : t.danger)),
            ]),
          ),
        ],
        const SizedBox(height: AppSpace.lg),

        // ── دخل كل يوم ──
        Text('دخل كل يوم', style: AppType.label.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        AppPanel(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.md),
          child: s.total == 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                  child: Text('مفيش دفعات متسجّلة في الشهر ده لسه.',
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(color: t.inkSoft)),
                )
              : Column(children: [
                  SizedBox(height: 160, child: _dayChart(t, s, isCurrent)),
                  const SizedBox(height: AppSpace.sm),
                  if (s.bestDay != null)
                    Text(
                      'أعلى يوم: ${s.bestDay} ${DateFormat('MMMM', 'ar').format(_month)} — ${_money(s.bestDayAmount)}',
                      style: AppType.caption.copyWith(color: t.inkSoft),
                    ),
                ]),
        ),
        const SizedBox(height: AppSpace.lg),

        // ── حسب المجموعة ──
        if (s.byGroup.isNotEmpty) ...[
          Text('حسب المجموعة', style: AppType.label.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.sm),
          AppPanel(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(children: [
              for (final e in (s.byGroup.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value))))
                _groupRow(t, e.key == null ? 'بدون مجموعة' : (_groupName[e.key] ?? 'مجموعة محذوفة'),
                    e.value, s.total),
            ]),
          ),
          const SizedBox(height: AppSpace.lg),
        ],

        // ── المصاريف ──
        OutlinedButton.icon(
          onPressed: () async {
            await Get.toNamed(ROUTE_EXPENSES);
            await _loadExpenses();
            if (mounted) setState(() {});
          },
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('المصاريف وصافي الدخل'),
        ),
        const SizedBox(height: AppSpace.lg),
        _differenceNote(t),
      ],
    );
  }

  /// إيه الفرق بين «دخلي» وحسبة التقارير/المدفوعات؟ (مع مثال).
  Widget _differenceNote(AppTokens t) => AppPanel(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.lightbulb_outline_rounded, size: 20, color: t.caution),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text('إيه الفرق بينه وبين التقارير؟',
                    style: AppType.label.copyWith(color: t.ink)),
              ),
            ]),
            const SizedBox(height: AppSpace.sm),
            _bullet(t, 'دخلي',
                'الكاش اللي دخل جيبك فعلًا، بتاريخ الدفعة (اشتراكات + كراسات). بيجاوب: «قبضت كام الشهر ده؟».'),
            _bullet(t, 'التقارير',
                'بتوزّع كل دفعة على الشهور اللي عليها مستحق (الأقدم أولًا). بتجاوب: «كام من مستحق الشهر ده اتسدّد؟».'),
            _bullet(t, 'المدفوعات',
                'كاش الشهر فيها = دفعات الشهر بتاريخها لطلاب المجموعة المختارة، من غير الكراسات.'),
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.all(AppSpace.sm),
              decoration: BoxDecoration(
                color: t.cautionSoft,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                'مثال: طالب دفع 300 في نوفمبر عن اشتراك أكتوبر. في «دخلي» الـ300 بتتحسب في نوفمبر (الفلوس دخلت نوفمبر). في التقارير بتتحسب لأكتوبر (الشهر اللي اتسدّد). الرقمين مظبوطين، بس بيجاوبوا على سؤالين مختلفين.',
                style: AppType.caption.copyWith(color: t.caution, height: 1.6),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Get.toNamed(ROUTE_REPORTS),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44)),
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: const Text('التقارير'),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Get.toNamed(ROUTE_PAYMENTS),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44)),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('المدفوعات'),
                ),
              ),
            ]),
          ],
        ),
      );

  Widget _bullet(AppTokens t, String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$title: ',
              style: AppType.caption
                  .copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          TextSpan(
              text: text,
              style: AppType.caption.copyWith(color: t.inkSoft, height: 1.6)),
        ])),
      );

  // ── سبورة الدخل ──
  Widget _hero(AppTokens t, IncomeSummary s, bool isCurrent) {
    final pct = s.changePct;
    final up = (pct ?? 0) >= 0;
    return Material(
      color: t.board,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.board),
        side: BorderSide(color: t.boardLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                isCurrent
                    ? 'دخلك الشهر ده (${DateFormat('MMMM', 'ar').format(s.month)})'
                    : 'دخلك في ${DateFormat('MMMM yyyy', 'ar').format(s.month)}',
                style: AppType.label.copyWith(color: t.boardInkSoft)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(_money(s.total),
                  style: AppType.figure.copyWith(fontSize: 38, color: t.chalk)),
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.xs, children: [
              _chip(
                t,
                pct == null
                    ? (s.previousTotal <= 0 ? 'مفيش شهر قبله للمقارنة' : '—')
                    : '${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}% عن الشهر اللي فات',
                color: pct == null
                    ? t.boardInkSoft
                    : (up ? const Color(0xFF4AD6A3) : const Color(0xFFFF8A8A)),
              ),
              _chip(t, '${s.count} دفعة', color: t.boardInkSoft),
              if (s.count > 0)
                _chip(t, 'متوسط ${_money(s.average)}', color: t.boardInkSoft),
            ]),
            if (s.previousTotal > 0) ...[
              const SizedBox(height: AppSpace.xs),
              Text('الشهر اللي فات: ${_money(s.previousTotal)}',
                  style: AppType.caption.copyWith(color: t.boardInkSoft)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(AppTokens t, String text, {required Color color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: t.boardLine,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(text,
            style: AppType.caption
                .copyWith(color: color, fontWeight: FontWeight.w700)),
      );

  // ── مخطط الأيام ──
  Widget _dayChart(AppTokens t, IncomeSummary s, bool isCurrent) {
    final today = DateTime.now().day;
    final maxV = s.byDay.fold<double>(0, (a, b) => b > a ? b : a);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: BarChart(
        BarChartData(
          maxY: maxV * 1.15,
          alignment: BarChartAlignment.spaceBetween,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxV <= 0 ? 1 : maxV / 3,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: t.line, strokeWidth: 0.6),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final day = v.toInt() + 1;
                  final show = day == 1 || day % 5 == 0;
                  return show
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('$day',
                              style: AppType.caption
                                  .copyWith(color: t.inkFaint, fontSize: 12)),
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => t.board,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                'يوم ${group.x + 1}\n${_money(rod.toY)}',
                AppType.caption.copyWith(color: Colors.white),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < s.byDay.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: s.byDay[i],
                  width: s.byDay.length > 28 ? 5 : 6,
                  borderRadius: BorderRadius.circular(2),
                  color: (isCurrent && i + 1 == today) ? t.brand : t.positive,
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _groupRow(AppTokens t, String name, double amount, double total) {
    final share = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(color: t.ink)),
          ),
          Text(_money(amount), style: AppType.label.copyWith(color: t.ink)),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('${(share * 100).round()}%',
                textAlign: TextAlign.end,
                style: AppType.caption.copyWith(color: t.inkSoft)),
          ),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 6,
            backgroundColor: t.line,
            valueColor: AlwaysStoppedAnimation(t.positive),
          ),
        ),
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _Figure(this.label, this.value, this.color, {required this.sub});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.caption.copyWith(color: t.inkSoft)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value,
                style: AppType.label.copyWith(color: color, fontSize: 16)),
          ),
          Text(sub, style: AppType.caption.copyWith(color: t.inkFaint)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/report_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/utils/helpers.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ReportController ctrl = Get.put(ReportController());

  @override
  void initState() {
    super.initState();
    ctrl.loadReports();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('MMMM yyyy', 'ar');

    return Scaffold(
      appBar: buildGradientAppBar(
        title: 'التقارير',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: ctrl.loadReports,
          ),
          Obx(() => ctrl.isExporting.value
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'تصدير PDF',
                  onPressed: () => _showExportMenu(context, ctrl),
                )),
        ],
      ),
      body: buildSoftBackground(
        context: context,
        child: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final month = ctrl.selectedMonth.value;
          final groupSummaries = ctrl.groupSummaries;
          final unpaid = ctrl.unpaidStudents;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                PADDING_NORMAL, PADDING_NORMAL, PADDING_NORMAL, 80),
            children: [
              // ─── Month navigator ───────────────────────────────────
              buildSoftPanel(
                context: context,
                radius: 20,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => ctrl.setMonth(
                          DateTime(month.year, month.month - 1)),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: month,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                            helpText: 'اختر شهرًا',
                          );
                          if (picked != null) {
                            ctrl.setMonth(
                                DateTime(picked.year, picked.month));
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
                                  ?.copyWith(fontWeight: FontWeight.w800),
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
                      onPressed: () => ctrl.setMonth(
                          DateTime(month.year, month.month + 1)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ─── KPI row ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'الطلاب',
                      value: ctrl.allStudents.length.toString(),
                      icon: Icons.people_outline,
                      color: Colors.blue,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiCard(
                      label: 'المجموعات',
                      value: ctrl.allGroups.length.toString(),
                      icon: Icons.groups_outlined,
                      color: Colors.indigo,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiCard(
                      label: 'حضور الشهر',
                      value: ctrl.monthPresentCount.toString(),
                      icon: Icons.how_to_reg_outlined,
                      color: Colors.green,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiCard(
                      label: 'غياب الشهر',
                      value: ctrl.monthAbsentCount.toString(),
                      icon: Icons.person_off_outlined,
                      color: Colors.red,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ─── Monthly income summary ─────────────────────────────
              buildSoftPanel(
                context: context,
                radius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined,
                              color: Colors.green),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'المحصّلات الشهرية',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _IncomeBox(
                            label: 'المحصّل',
                            amount: ctrl.monthTotalCollected,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _IncomeBox(
                            label: 'المتوقع',
                            amount: groupSummaries.fold(
                                0.0, (s, g) => s + g.expectedIncome),
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _IncomeBox(
                            label: 'المتأخر',
                            amount: groupSummaries.fold(0.0,
                                (s, g) => s + (g.expectedIncome - g.collectedIncome).clamp(0, double.infinity)),
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Collection progress bar
                    Builder(builder: (context) {
                      final expected = groupSummaries.fold(
                          0.0, (s, g) => s + g.expectedIncome);
                      final collected = ctrl.monthTotalCollected;
                      final progress =
                          expected == 0 ? 0.0 : (collected / expected).clamp(0.0, 1.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('نسبة التحصيل',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: progress >= 0.8
                                        ? Colors.green
                                        : Colors.orange),
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
                                  Colors.green.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 0.8
                                      ? Colors.green
                                      : Colors.orange),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 12),

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
                          summary: gs, isDark: isDark),
                    )),

              const SizedBox(height: 4),

              // ─── Unpaid students ────────────────────────────────────
              _SectionHeader(
                  icon: Icons.warning_amber_rounded,
                  title: 'طلاب لم يسددوا بالكامل',
                  subtitle: dateFmt.format(month),
                  color: Colors.orange),
              const SizedBox(height: 8),
              if (unpaid.isEmpty)
                buildSoftPanel(
                  context: context,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.green),
                        SizedBox(width: 8),
                        Text('جميع الطلاب سددوا هذا الشهر 🎉'),
                      ],
                    ),
                  ),
                )
              else
                ...unpaid.map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _UnpaidStudentCard(
                          data: u, isDark: isDark),
                    )),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group summary card
// ─────────────────────────────────────────────────────────────────────────────

class _GroupSummaryCard extends StatelessWidget {
  final GroupMonthSummary summary;
  final bool isDark;
  const _GroupSummaryCard(
      {required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rate = summary.collectionRate;
    final rateColor =
        rate >= 0.8 ? Colors.green : rate >= 0.5 ? Colors.orange : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                    size: 18,
                    color: Theme.of(context).colorScheme.primary),
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
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
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
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              _StatBox(
                label: 'متوقع',
                child: CurrencyText(
                  summary.expectedIncome,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              _StatBox(
                label: 'مدفوع بالكامل',
                child: Text(
                  '${summary.fullyPaidCount} / ${summary.studentCount}',
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
                      color: Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Collection rate bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: rateColor.withValues(alpha: 0.1),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(rateColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(rate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    color: rateColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ],
          ),
        ],
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
  const _UnpaidStudentCard(
      {required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final progress =
        data.due > 0 ? (data.paid / data.due).clamp(0.0, 1.0) : 0.0;
    final color =
        data.paid == 0 ? Colors.red : Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
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
                  data.student.name.isNotEmpty
                      ? data.student.name[0]
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
                    Text(data.student.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    if (data.group != null)
                      Text(data.group!.name,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
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
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
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
                        data.paid > 0 ? Colors.orange : Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CurrencyText(
                data.paid,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
              Text(' / ',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400)),
              CurrencyText(
                data.due,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
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

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _IncomeBox extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _IncomeBox(
      {required this.label,
      required this.amount,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 3),
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
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final Widget child;
  const _StatBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
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
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Text(subtitle,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }
}

// ── قائمة التصدير helper ─────────────────────────────────────────────────────
void _showExportMenu(BuildContext context, ReportController ctrl) {
    final month = DateFormat('MMMM yyyy', 'ar').format(ctrl.selectedMonth.value);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('تصدير تقرير — $month',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 4),
            Text('اختر نوع التقرير الذي تريد تصديره كـ PDF',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            _ExportOption(
              icon: Icons.payments_rounded,
              color: const Color(0xFF1565C0),
              title: 'تقرير الدفعات',
              subtitle: 'جدول بالطلاب والمبالغ والحالة',
              onTap: () {
                Navigator.pop(ctx);
                if (!requireLicenseFeature(
                    context,
                    Get.find<LicenseController>().canExport,
                    'تصدير التقارير غير متاح في الفترة التجريبية — قم بالترقية')) {
                  return;
                }
                ctrl.exportPaymentsPDF();
              },
            ),
            const SizedBox(height: 10),
            _ExportOption(
              icon: Icons.how_to_reg_rounded,
              color: const Color(0xFF2E7D32),
              title: 'تقرير الحضور',
              subtitle: 'جدول تفصيلي لحضور وغياب كل طالب',
              onTap: () {
                Navigator.pop(ctx);
                if (!requireLicenseFeature(
                    context,
                    Get.find<LicenseController>().canExport,
                    'تصدير التقارير غير متاح في الفترة التجريبية — قم بالترقية')) {
                  return;
                }
                ctrl.exportAttendancePDF();
              },
            ),
            const SizedBox(height: 10),
            _ExportOption(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF6A1B9A),
              title: 'ملخص المجموعات',
              subtitle: 'إجماليات كل مجموعة (دفعات + حضور)',
              onTap: () {
                Navigator.pop(ctx);
                if (!requireLicenseFeature(
                    context,
                    Get.find<LicenseController>().canExport,
                    'تصدير التقارير غير متاح في الفترة التجريبية — قم بالترقية')) {
                  return;
                }
                ctrl.exportGroupsSummaryPDF();
              },
            ),
          ],
        ),
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
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.picture_as_pdf_rounded, color: color.withValues(alpha: 0.6), size: 18),
          ]),
        ),
      ),
    );
  }
}

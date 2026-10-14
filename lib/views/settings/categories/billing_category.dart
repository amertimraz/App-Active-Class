part of '../settings_page.dart';

// spec 051 — فئة «الفلوس والتحصيل»

class _BillingCategoryPage extends StatelessWidget {
  const _BillingCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final SettingsController settings = Get.find();
    return _CategoryScaffold(
      title: 'الفلوس والتحصيل',
      highlightId: highlightId,
      children: [
        _buildSection(
          context,
          isDark,
          title: 'الفوترة والتحصيل',
          icon: Icons.payments_rounded,
          color: const Color(0xFF10B981),
          children: [
            // ── مهلة السماح قبل اعتبار الطالب "متأخر" ──
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.hourglass_bottom_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'مهلة السماح قبل "متأخر"',
                  value: settings.paymentGraceDays.value,
                  items: List.generate(15, (i) => i)
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d == 0
                                ? 'بدون مهلة (من أول يوم)'
                                : 'بعد $d يوم من بداية الشهر'),
                          ))
                      .toList(),
                  onChanged: (d) async {
                    if (d != null) {
                      await settings.setPaymentGraceDays(d);
                      ToastHelper.success(
                        d == 0
                            ? 'هيظهر الطالب "متأخر" من أول يوم في الشهر'
                            : 'هيظهر الطالب "متأخر" بعد $d يوم من بداية الشهر',
                        title: 'تم التغيير',
                      );
                    }
                  },
                )),
            _buildDivider(isDark),
            // ── نظام التحصيل: مقدّم / مؤخّر (spec 012) ──
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.event_repeat_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'تحصيل مؤخّر (بالمنقضي)',
                  subtitle: settings.billingArrears.value
                      ? 'الشهر الجاري ما يتحسبش في المديونية لحد ما يخلص'
                      : 'مقدّم — الشهر مستحق من أول يومه (الافتراضي)',
                  rxValue: settings.billingArrears,
                  onChanged: (v) async {
                    await settings.setBillingArrears(v);
                    ToastHelper.success(
                      v
                          ? 'الشهر الجاري مش هيتحسب لحد ما يخلص'
                          : 'الشهر مستحق من أول يومه',
                      title: 'نظام التحصيل',
                    );
                  },
                )),
            _buildDivider(isDark),
            // ── يوم نزول المديونية (spec 045) ──
            Obx(() {
              final arrears = settings.billingArrears.value;
              final d = settings.billingDay.value;
              final preview = arrears
                  ? 'غير مستخدم مع التحصيل المؤخّر — الشهر بينزل بعد ما يخلص'
                  : d == 1
                      ? 'اشتراك الشهر بينزل من أول يوم فيه (الافتراضي)'
                      : 'اشتراك الشهر بينزل يوم $d من كل شهر — قبله مابيظهرش كمديونية';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdownTile<int>(
                    context,
                    isDark,
                    icon: Icons.event_available_rounded,
                    iconColor: const Color(0xFF0EA5E9),
                    title: 'يوم نزول المديونية',
                    value: d,
                    items: List.generate(28, (i) => i + 1)
                        .map((x) => DropdownMenuItem(
                              value: x,
                              child: Text(
                                  x == 1 ? 'من أول الشهر' : 'يوم $x من كل شهر'),
                            ))
                        .toList(),
                    onChanged: arrears
                        ? null
                        : (x) async {
                            if (x == null) return;
                            await settings.setBillingDay(x);
                            ToastHelper.success(
                              x == 1
                                  ? 'الاشتراك بينزل من أول الشهر'
                                  : 'الاشتراك هينزل يوم $x من كل شهر',
                              title: 'يوم النزول',
                            );
                          },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(68, 0, 16, 10),
                    child: Text(
                      preview +
                          (TeamModeService().isEnabled.value
                              ? '\nفي وضع الفريق: اضبط نفس اليوم على جهاز المساعد.'
                              : ''),
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          height: 1.6,
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              );
            }),
            _buildDivider(isDark),
            // ── حساب نسبي للشهر الأول (spec 012) ──
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.pie_chart_outline_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'حساب نسبي للشهر الأول',
                  subtitle: settings.prorateFirstMonth.value
                      ? 'الطالب اللي بينضم نص الشهر يدفع نسبة الأيام (تقريب لأقرب 5 ج)'
                      : 'الشهر الأول شهر كامل زي أي شهر (الافتراضي)',
                  rxValue: settings.prorateFirstMonth,
                  onChanged: (v) async {
                    await settings.setProrateFirstMonth(v);
                    ToastHelper.success(
                      v
                          ? 'شهر الانضمام هيتحسب بنسبة أيامه'
                          : 'شهر الانضمام شهر كامل',
                      title: 'الحساب النسبي',
                    );
                  },
                )),
          ],
        ),
        const SizedBox(height: 14),
        _buildSection(
          context,
          isDark,
          title: 'تأخّر الدفع',
          icon: Icons.payments_rounded,
          color: const Color(0xFF10B981),
          children: [
            _buildSwitchTile(
              context,
              isDark,
              icon: Icons.payments_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'تأخّر الدفع',
              subtitle: 'بيظهر في قائمة المتابعة بنفس مهلة السماح فوق',
              rxValue: settings.atRiskPaymentEnabled,
              onChanged: settings.setAtRiskPaymentEnabled,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSection(
          context,
          isDark,
          title: 'العملة',
          icon: Icons.language_rounded,
          color: const Color(0xFF10B981),
          children: [
            Obx(() {
              final items = SettingsController.supported;
              return _buildDropdownTile(
                context,
                isDark,
                icon: Icons.attach_money_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'العملة',
                value: settings.currencyCode.value,
                items: items
                    .map((c) => DropdownMenuItem(
                          value: c.code,
                          child: Text('${c.nameAr} (${c.symbol})'),
                        ))
                    .toList(),
                onChanged: (code) {
                  if (code != null) {
                    settings.setCurrency(code);
                    ToastHelper.success(
                      'تم تعيين العملة إلى: ${settings.currentCurrency.nameAr}',
                      title: 'تم التغيير',
                    );
                  }
                },
              );
            }),
          ],
        ),
      ],
    );
  }
}

part of '../settings_page.dart';

// spec 051 — فئة «الفلوس والتحصيل» بتصميم السبورة والكروت:
// سبورة بملخص الإعدادات، كروت تشغيل/إيقاف، وقايمة المواعيد والعملة.

class _BillingCategoryPage extends StatelessWidget {
  const _BillingCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _tk(isDark);
    final SettingsController settings = Get.find();
    const green = Color(0xFF10B981);
    const sky = Color(0xFF0EA5E9);
    const gap = SizedBox(height: AppSpace.lg);
    return _CategoryScaffold(
      title: 'الفلوس والتحصيل',
      highlightId: highlightId,
      children: [
        // ── السبورة: ملخص الإعدادات الحالية ──
        Obx(() {
          final arrears = settings.billingArrears.value;
          final day = settings.billingDay.value;
          final grace = settings.paymentGraceDays.value;
          final code = settings.currencyCode.value; // اشتراك في تغيير العملة
          final cur = SettingsController.supported.firstWhere(
              (c) => c.code == code,
              orElse: () => settings.currentCurrency);
          return _boardSummary(
            t,
            icon: Icons.payments_rounded,
            title: 'الفلوس والتحصيل',
            subtitle: 'ملخص الإعدادات الحالية',
            stats: [
              (label: 'العملة', value: '${cur.nameAr} (${cur.symbol})'),
              (label: 'نظام التحصيل', value: arrears ? 'مؤخّر' : 'مقدّم'),
              (
                label: 'مهلة السماح',
                value: grace == 0 ? 'بدون مهلة' : '$grace يوم'
              ),
              (
                label: 'نزول المديونية',
                value: arrears
                    ? 'بعد نهاية الشهر'
                    : day == 1
                        ? 'من أول الشهر'
                        : 'يوم $day'
              ),
            ],
          );
        }),
        gap,
        // ── نظام الفوترة: كروت تشغيل/إيقاف ──
        _plainSectionBlock(
          t,
          'الفوترة والتحصيل',
          Icons.payments_rounded,
          green,
          _cardGrid([
            _toggleCard(
              t,
              rx: settings.billingArrears,
              icon: Icons.event_repeat_rounded,
              color: sky,
              title: 'تحصيل مؤخّر (بالمنقضي)',
              sharedKey: SETTING_BILLING_ARREARS,
              onHint: 'الشهر الجاري ما يتحسبش في المديونية لحد ما يخلص',
              offHint: 'مقدّم — الشهر مستحق من أول يومه',
              set: (v) async {
                await settings.setBillingArrears(v);
                ToastHelper.success(
                  v
                      ? 'الشهر الجاري مش هيتحسب لحد ما يخلص'
                      : 'الشهر مستحق من أول يومه',
                  title: 'نظام التحصيل',
                );
              },
            ),
            _toggleCard(
              t,
              rx: settings.prorateFirstMonth,
              icon: Icons.pie_chart_outline_rounded,
              color: sky,
              title: 'حساب نسبي للشهر الأول',
              sharedKey: SETTING_PRORATE_FIRST_MONTH,
              onHint: 'اللي بينضم نص الشهر يدفع نسبة الأيام (لأقرب 5 ج)',
              offHint: 'الشهر الأول شهر كامل زي أي شهر',
              set: (v) async {
                await settings.setProrateFirstMonth(v);
                ToastHelper.success(
                  v
                      ? 'شهر الانضمام هيتحسب بنسبة أيامه'
                      : 'شهر الانضمام شهر كامل',
                  title: 'الحساب النسبي',
                );
              },
            ),
          ]),
        ),
        gap,
        // ── المواعيد والمهلة: قوايم اختيار ──
        _buildSection(
          context,
          isDark,
          title: 'المواعيد والمهلة',
          icon: Icons.schedule_rounded,
          color: green,
          children: [
            // ── مهلة السماح قبل اعتبار الطالب "متأخر" ──
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.hourglass_bottom_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'مهلة السماح قبل "متأخر"',
                  sharedKey: 'payment_grace_days',
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
            // ── يوم نزول المديونية (spec 045) ──
            Obx(() {
              final arrears = settings.billingArrears.value;
              final d = settings.billingDay.value;
              final preview = arrears
                  ? 'غير مستخدم مع التحصيل المؤخّر — الشهر بينزل بعد ما يخلص'
                  : d == 1
                      ? 'اشتراك الشهر بينزل من أول يوم فيه (الافتراضي)'
                      : 'اشتراك الشهر بينزل يوم $d من كل شهر — قبله مابيظهرش كمديونية';
              return _buildDropdownTile<int>(
                context,
                isDark,
                icon: Icons.event_available_rounded,
                iconColor: sky,
                title: 'يوم نزول المديونية',
                sharedKey: SETTING_BILLING_DAY,
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
                helper: preview +
                    (TeamModeService().isEnabled.value
                        ? '\nفي وضع الفريق: اضبط نفس اليوم على جهاز المساعد.'
                        : ''),
              );
            }),
          ],
        ),
        gap,
        // ── تأخّر الدفع ──
        _plainSectionBlock(
          t,
          'تأخّر الدفع',
          Icons.payments_rounded,
          green,
          _toggleCard(
            t,
            rx: settings.atRiskPaymentEnabled,
            icon: Icons.payments_rounded,
            color: green,
            title: 'تأخّر الدفع',
            onHint: 'بيظهر في قائمة المتابعة بنفس مهلة السماح فوق',
            offHint: 'مش هيظهر المتأخرين في قائمة المتابعة',
            set: (v) async => settings.setAtRiskPaymentEnabled(v),
          ),
        ),
        gap,
        // ── العملة ──
        _buildSection(
          context,
          isDark,
          title: 'العملة',
          icon: Icons.language_rounded,
          color: green,
          children: [
            Obx(() {
              final items = SettingsController.supported;
              return _buildDropdownTile(
                context,
                isDark,
                icon: Icons.attach_money_rounded,
                iconColor: green,
                title: 'العملة',
                sharedKey: 'currency_code',
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

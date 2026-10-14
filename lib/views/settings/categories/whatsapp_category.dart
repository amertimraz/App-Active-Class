part of '../settings_page.dart';

// spec 051 — فئة «الواتساب والتقارير»

class _WhatsappCategoryPage extends StatelessWidget {
  const _WhatsappCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final SettingsController settings = Get.find();
    return _CategoryScaffold(
      title: 'الواتساب والتقارير',
      highlightId: highlightId,
      children: [
        _buildSection(
          context,
          isDark,
          title: 'الواتساب والتقارير',
          icon: Icons.chat_rounded,
          color: const Color(0xFF25D366),
          children: [
            Obx(() {
              final items = SettingsController.arabCountryDials;
              return _buildDropdownTile(
                context,
                isDark,
                icon: Icons.flag_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'رمز دولة الواتساب',
                value: settings.countryDial.value,
                items: items
                    .map((c) => DropdownMenuItem(
                          value: c.dial,
                          child: Text('${c.nameAr} (+${c.dial})'),
                        ))
                    .toList(),
                onChanged: (dial) async {
                  if (dial != null) {
                    await settings.setCountryDial(dial);
                    ToastHelper.success(
                      'تم تعيين رمز الدولة: +${settings.countryDial.value}',
                      title: 'تم التغيير',
                    );
                  }
                },
              );
            }),
            _buildDivider(isDark),
            _buildNavTile(
              context,
              isDark,
              icon: Icons.send_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'إرسال تقارير الشهر',
              subtitle: 'يفتح محادثة واتساب لكل ولي أمر بتقرير مفصل',
              onTap: () {
                if (!requireLicenseFeature(
                    context,
                    Get.find<LicenseController>().canWhatsApp,
                    'الإرسال الجماعي عبر واتساب غير متاح في باقتك الحالية — قم بالترقية')) {
                  return;
                }
                _startWhatsappBatchSend(context, settings);
              },
            ),
            _buildDivider(isDark),
            // ── إظهار زر الواتساب في المجموعات ──────────
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.smart_button_rounded,
                  iconColor: const Color(0xFF25D366),
                  title: 'زر الواتساب في المجموعات',
                  subtitle: settings.whatsappEnabled.value
                      ? (settings.isWhatsappDayReached
                          ? 'ظاهر الآن — يبدأ يوم ${settings.whatsappSendDay.value} من الشهر'
                          : 'سيظهر يوم ${settings.whatsappSendDay.value} من الشهر')
                      : 'الزر مخفي في صفحات المجموعات',
                  rxValue: settings.whatsappEnabled,
                  onChanged: (v) async => await settings.setWhatsappEnabled(v),
                )),
            // ── يوم ظهور الزر ──────────────────────────
            Obx(() {
              if (!settings.whatsappEnabled.value) {
                return const SizedBox.shrink();
              }
              return Column(children: [
                _buildDivider(isDark),
                _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.event_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'يوم ظهور الزر',
                  value: settings.whatsappSendDay.value,
                  items: List.generate(28, (i) => i + 1)
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text('يوم $d من الشهر'),
                          ))
                      .toList(),
                  onChanged: (d) async {
                    if (d != null) {
                      await settings.setWhatsappSendDay(d);
                      ToastHelper.success(
                        'سيظهر زر الواتساب يوم $d من كل شهر',
                        title: 'تم التغيير',
                      );
                    }
                  },
                ),
              ]);
            }),
            _buildDivider(isDark),
            // ── تقرير حضور/واجب تلقائي بعد اكتمال التحضير ──
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.mark_chat_read_rounded,
                  iconColor: const Color(0xFF25D366),
                  title: 'تقرير واتساب بعد اكتمال الحضور',
                  subtitle: settings.reportOnCompletionEnabled.value
                      ? 'هيظهر زرار إرسال تقرير في كارت المجموعة أول ما تحضير النهاردة يكتمل'
                      : 'معطّل — مفيش زرار إرسال هيظهر',
                  rxValue: settings.reportOnCompletionEnabled,
                  onChanged: (v) async =>
                      await settings.setReportOnCompletionEnabled(v),
                )),
          ],
        ),
      ],
    );
  }
}

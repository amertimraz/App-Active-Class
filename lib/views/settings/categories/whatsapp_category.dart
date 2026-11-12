part of '../settings_page.dart';

// spec 051 — فئة «الواتساب والتقارير»
// ثلاث مجموعات: الإرسال التلقائي، التقارير والقوالب، إعدادات الإرسال اليدوي.

class _WhatsappCategoryPage extends StatelessWidget {
  const _WhatsappCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final SettingsController settings = Get.find();
    const green = Color(0xFF25D366);
    return _CategoryScaffold(
      title: 'الواتساب والتقارير',
      highlightId: highlightId,
      children: [
        // ── 1) الإرسال التلقائي: كارت سبورة ──────────────
        Obx(() {
          final t = _tk(isDark);
          final on = settings.waAutoEnabled.value;
          return Material(
            color: t.board,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.board),
              side: BorderSide(color: t.boardLine),
            ),
            child: InkWell(
              onTap: () => Get.to(() => const _WaAutoCategoryPage()),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(AppRadius.panel),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إرسال تلقائي',
                            style: AppType.title.copyWith(color: t.boardInk)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: on
                                ? const Color(0xFF4AD6A3)
                                : t.boardLine,
                            borderRadius:
                                BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Text(on ? 'شغّال' : 'مقفول',
                              style: AppType.caption.copyWith(
                                  color: on
                                      ? const Color(0xFF062B20)
                                      : t.boardInk,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          on
                              ? 'الموافقات والرصيد وآخر الرسايل'
                              : 'فعّله وسجّل موافقات أولياء الأمور',
                          style: AppType.caption
                              .copyWith(color: t.boardInkSoft),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: t.boardInkSoft),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpace.lg),
        // ── 2) التقارير والقوالب: كروت إجراءات ───────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpace.sm),
          child: _sectionHeader(_tk(isDark), 'التقارير والقوالب',
              Icons.description_rounded, const Color(0xFF3B82F6)),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _actionCard(
                _tk(isDark),
                icon: Icons.send_rounded,
                color: green,
                title: 'إرسال تقارير الشهر',
                hint: 'محادثة واتساب لكل ولي أمر بتقرير مفصل',
                onTap: () {
                  if (!requireLicenseFeature(
                      context,
                      Get.find<LicenseController>().canWhatsApp,
                      'الإرسال الجماعي عبر واتساب غير متاح في باقتك الحالية — قم بالترقية')) {
                    return;
                  }
                  _startWhatsappBatchSend(context, settings);
                },
              )),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: _actionCard(
                _tk(isDark),
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF3B82F6),
                title: 'قوالب الرسائل',
                hint: 'عدّل رسائل البرنامج واكتب رسايلك الجاهزة',
                onTap: () => Get.to(() => const MessageTemplatesPage()),
              )),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        _buildSection(
          context,
          isDark,
          title: 'تقرير تلقائي',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF3B82F6),
          children: [
            // ── تقرير حضور/واجب تلقائي بعد اكتمال التحضير ──
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.mark_chat_read_rounded,
                  iconColor: green,
                  title: 'تقرير واتساب بعد اكتمال الحضور',
                  sharedKey: SETTING_REPORT_ON_COMPLETION_ENABLED,
                  subtitle: settings.reportOnCompletionEnabled.value
                      ? 'هيظهر زرار إرسال تقرير في كارت المجموعة أول ما تحضير النهاردة يكتمل'
                      : 'معطّل — مفيش زرار إرسال هيظهر',
                  rxValue: settings.reportOnCompletionEnabled,
                  onChanged: (v) async =>
                      await settings.setReportOnCompletionEnabled(v),
                )),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        // ── 3) إعدادات الإرسال اليدوي ───────────────────
        _buildSection(
          context,
          isDark,
          title: 'إعدادات الإرسال اليدوي',
          icon: Icons.tune_rounded,
          color: const Color(0xFF8B5CF6),
          children: [
            Obx(() => _buildDropdownTile<String>(
                  context,
                  isDark,
                  icon: Icons.switch_account_rounded,
                  iconColor: green,
                  title: 'تطبيق واتساب للإرسال',
                  value: settings.waApp.value,
                  items: const [
                    DropdownMenuItem(
                        value: 'default', child: Text('اختيار الجهاز (زي الأول)')),
                    DropdownMenuItem(
                        value: 'ask', child: Text('اسألني كل مرة')),
                    DropdownMenuItem(value: 'whatsapp', child: Text('واتساب')),
                    DropdownMenuItem(
                        value: 'business', child: Text('واتساب Business')),
                  ],
                  onChanged: (v) async {
                    if (v != null) await settings.setWaApp(v);
                  },
                )),
            _buildDivider(isDark),
            Obx(() {
              final items = SettingsController.arabCountryDials;
              return _buildDropdownTile(
                context,
                isDark,
                icon: Icons.flag_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'رمز دولة الواتساب',
                sharedKey: 'country_dial',
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
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.person_rounded,
                  iconColor: green,
                  title: 'رسائل واتساب للطالب نفسه',
                  subtitle: settings.studentWhatsappEnabled.value
                      ? 'مفعّل — تقدر تبعت لولي الأمر أو الطالب أو الاتنين'
                      : 'معطّل — الرسائل لولي الأمر بس',
                  rxValue: settings.studentWhatsappEnabled,
                  onChanged: (v) async =>
                      await settings.setStudentWhatsappEnabled(v),
                )),
            _buildDivider(isDark),
            // ── إظهار زر الواتساب في المجموعات ──────────
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.smart_button_rounded,
                  iconColor: green,
                  title: 'زر الواتساب في المجموعات',
                  sharedKey: 'wa_button_enabled',
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
                  sharedKey: 'wa_send_day',
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
          ],
        ),
      ],
    );
  }
}

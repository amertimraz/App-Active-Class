import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/billing_period.dart';
import 'package:active_class/utils/monthly_report_message.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/theme_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/auth_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/views/settings/account_team_screen.dart';
import 'package:active_class/widgets/custom_dialogs.dart';
import 'package:active_class/widgets/progress_dialog.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/backup_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:active_class/services/auto_backup_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/license/trial_banner.dart';
import 'package:active_class/widgets/update_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ThemeController themeController = Get.find();
    final SettingsController settings = Get.find();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FF),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF08101F), Color(0xFF121A2D)]
                      : const [Color(0xFFFDFDFF), Color(0xFFEEF4FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // ── 0. حالة الترخيص ──────────────────────────
                      const LicenseStatusTile(),
                      const SizedBox(height: 14),

                      // ── 1. بيانات المعلم ─────────────────────────
                      _buildTeacherSection(context, isDark, settings),
                      const SizedBox(height: 14),

                      // ── 1ب. المساعدين والحسابات (حساب + وضع الفريق) ──
                      _buildSection(
                        context,
                        isDark,
                        title: 'المساعدين والحسابات',
                        icon: Icons.account_circle_rounded,
                        color: const Color(0xFF4F46E5),
                        children: [
                          Obx(() {
                            final auth = Get.find<AuthController>();
                            final phone = auth.currentPhone.value ?? '';
                            return _buildNavTile(
                              context,
                              isDark,
                              icon: Icons.groups_rounded,
                              iconColor: const Color(0xFF4F46E5),
                              title: 'المساعدين والحسابات',
                              subtitle: auth.isLoggedIn.value
                                  ? phone
                                  : 'تسجيل دخول ومشاركة البيانات مع مساعدين',
                              onTap: () => Get.to(() => const AccountTeamScreen()),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── متابعة أولياء الأمور (إضافة مدفوعة، spec 016) ──
                      Obx(() {
                        final lic = Get.find<LicenseController>();
                        // قراءة العدادين دول مقصودة عشان الـObx يعيد البناء:
                        // - recheckTick كل 5 دقايق (الفحص الدوري لانتهاء المدة)
                        // - verifiedTick بعد كل قراءة ترخيص ناجحة (عشان القسم
                        //   يظهر فورًا لما القراءة تخلص/تتغيّر، مش بعد 5 دقايق)
                        // ignore: unnecessary_statements
                        lic.parentPortalRecheckTick.value;
                        // ignore: unnecessary_statements
                        lic.licenseVerifiedTick.value;

                        // نعرض القسم طول ما الإضافة مفعّلة على الترخيص — حتى لو
                        // مدتها المستقلة انتهت — عشان المدرس يشوف تاريخ الانتهاء
                        // ويعرف يجدّد، بدل ما تختفي وتبان وكأنها "اتلغت".
                        if (!lic.parentPortalEnabled.value) {
                          return const SizedBox.shrink();
                        }
                        final expired = !lic.parentPortalActiveNow;
                        return Column(children: [
                          _buildSection(
                            context,
                            isDark,
                            title: 'متابعة أولياء الأمور',
                            icon: Icons.family_restroom_rounded,
                            color: expired
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                            children: [
                              _ParentPortalTile(
                                  isDark: isDark, expired: expired),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ]);
                      }),

                      // ── 3. العملة ورمز الدولة ────────────────────
                      _buildSection(
                        context,
                        isDark,
                        title: 'العملة ورمز الدولة',
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
                                        child:
                                            Text('${c.nameAr} (${c.symbol})'),
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
                          _buildDivider(isDark),
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
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── الفوترة والتحصيل (spec 012/013 — منقولة من قسم الواتساب) ──
                      _buildSection(
                        context,
                        isDark,
                        title: 'الفوترة والتحصيل',
                        icon: Icons.payments_rounded,
                        color: const Color(0xFF10B981),
                        collapsible: true,
                        initiallyExpanded: false,
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

                      // ── طلاب محتاجين متابعة (spec 021) ───────────
                      _buildSection(
                        context,
                        isDark,
                        title: 'طلاب محتاجين متابعة',
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFEF4444),
                        collapsible: true,
                        initiallyExpanded: false,
                        children: [
                          Obx(() => _buildSwitchTile(
                                context,
                                isDark,
                                icon: Icons.event_busy_rounded,
                                iconColor: const Color(0xFFEF4444),
                                title: 'غياب متتالي',
                                subtitle:
                                    'رصد بعد ${settings.atRiskAbsenceThreshold.value} حصص غياب ورا بعض',
                                rxValue: settings.atRiskAbsenceEnabled,
                                onChanged: (v) =>
                                    settings.setAtRiskAbsence(enabled: v),
                              )),
                          Obx(() => _buildDropdownTile<int>(
                                context,
                                isDark,
                                icon: Icons.repeat_rounded,
                                iconColor: const Color(0xFFEF4444),
                                title: 'عدد حصص الغياب المتتالي',
                                value: settings.atRiskAbsenceThreshold.value,
                                items: List.generate(9, (i) => i + 1)
                                    .map((n) => DropdownMenuItem(
                                        value: n, child: Text('$n حصص')))
                                    .toList(),
                                onChanged: (n) {
                                  if (n != null) {
                                    settings.setAtRiskAbsence(threshold: n);
                                  }
                                },
                              )),
                          _buildDivider(isDark),
                          Obx(() => _buildSwitchTile(
                                context,
                                isDark,
                                icon: Icons.assignment_late_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: 'واجب ناقص متكرر',
                                subtitle:
                                    '${settings.atRiskHomeworkM.value} من آخر ${settings.atRiskHomeworkW.value} حصص',
                                rxValue: settings.atRiskHomeworkEnabled,
                                onChanged: (v) =>
                                    settings.setAtRiskHomework(enabled: v),
                              )),
                          Obx(() => _buildDropdownTile<int>(
                                context,
                                isDark,
                                icon: Icons.pending_actions_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: 'عدد مرات الواجب الناقص',
                                value: settings.atRiskHomeworkM.value,
                                items: List.generate(10, (i) => i + 1)
                                    .map((n) => DropdownMenuItem(
                                        value: n, child: Text('$n مرات')))
                                    .toList(),
                                onChanged: (n) {
                                  if (n != null) {
                                    settings.setAtRiskHomework(m: n);
                                  }
                                },
                              )),
                          Obx(() => _buildDropdownTile<int>(
                                context,
                                isDark,
                                icon: Icons.view_week_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: 'من آخر كام حصة',
                                value: settings.atRiskHomeworkW.value,
                                items: List.generate(15, (i) => i + 1)
                                    .map((n) => DropdownMenuItem(
                                        value: n, child: Text('$n حصص')))
                                    .toList(),
                                onChanged: (n) {
                                  if (n != null) {
                                    settings.setAtRiskHomework(w: n);
                                  }
                                },
                              )),
                          _buildDivider(isDark),
                          Obx(() => _buildSwitchTile(
                                context,
                                isDark,
                                icon: Icons.trending_down_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                title: 'هبوط الدرجات',
                                subtitle:
                                    'رصد لو نزلت ${settings.atRiskGradeDropPoints.value} نقطة أو تحت النجاح',
                                rxValue: settings.atRiskGradeEnabled,
                                onChanged: (v) =>
                                    settings.setAtRiskGrade(enabled: v),
                              )),
                          Obx(() => _buildDropdownTile<int>(
                                context,
                                isDark,
                                icon: Icons.percent_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                title: 'مقدار هبوط الدرجة',
                                value: settings.atRiskGradeDropPoints.value,
                                items: [5, 10, 15, 20, 25, 30, 40, 50]
                                    .map((n) => DropdownMenuItem(
                                        value: n, child: Text('$n نقطة')))
                                    .toList(),
                                onChanged: (n) {
                                  if (n != null) {
                                    settings.setAtRiskGrade(dropPoints: n);
                                  }
                                },
                              )),
                          _buildDivider(isDark),
                          _buildSwitchTile(
                            context,
                            isDark,
                            icon: Icons.payments_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: 'تأخّر الدفع',
                            subtitle: 'بنفس مهلة السماح في قسم الفوترة فوق',
                            rxValue: settings.atRiskPaymentEnabled,
                            onChanged: settings.setAtRiskPaymentEnabled,
                          ),
                          _buildDivider(isDark),
                          Obx(() => _buildDropdownTile<int>(
                                context,
                                isDark,
                                icon: Icons.snooze_rounded,
                                iconColor: const Color(0xFF64748B),
                                title: 'مدة التهدئة بعد "تمّت المتابعة"',
                                value: settings.atRiskCooldownDays.value,
                                items: [1, 3, 5, 7, 10, 14, 21, 30]
                                    .map((n) => DropdownMenuItem(
                                        value: n, child: Text('$n يوم')))
                                    .toList(),
                                onChanged: (n) {
                                  if (n != null) {
                                    settings.setAtRiskCooldownDays(n);
                                  }
                                },
                              )),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── المظهر والتوقيت ─────────────────────────
                      _buildSection(
                        context,
                        isDark,
                        title: 'المظهر والتوقيت',
                        icon: Icons.palette_rounded,
                        color: const Color(0xFF8B5CF6),
                        children: [
                          _buildSwitchTile(
                            context,
                            isDark,
                            icon: Icons.dark_mode_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            title: 'الوضع الليلي',
                            subtitle: 'تغيير مظهر التطبيق',
                            rxValue: themeController.isDarkMode,
                            onChanged: themeController.setTheme,
                          ),
                          _buildDivider(isDark),
                          Obx(() => _buildSwitchTile(
                                context,
                                isDark,
                                icon: Icons.access_time_rounded,
                                iconColor: const Color(0xFF06B6D4),
                                title: 'نظام الساعة 24',
                                subtitle: settings.use24hFormat.value
                                    ? 'يعرض 14:30'
                                    : 'يعرض 2:30 م',
                                rxValue: settings.use24hFormat,
                                onChanged: (v) async =>
                                    await settings.setUse24hFormat(v),
                              )),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── 4. الإشعارات ─────────────────────────────
                      _buildSection(
                        context,
                        isDark,
                        title: 'الإشعارات',
                        icon: Icons.notifications_rounded,
                        color: const Color(0xFFEF4444),
                        children: [
                          _buildNavTile(
                            context,
                            isDark,
                            icon: Icons.tune_rounded,
                            iconColor: const Color(0xFFEF4444),
                            title: 'مركز الإشعارات',
                            subtitle: 'إشعارات الميلاد والحصص والدفعات',
                            onTap: () =>
                                Get.toNamed(ROUTE_NOTIFICATION_SETTINGS),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── 5. الواتساب والتقارير ────────────────────
                      _buildSection(
                        context,
                        isDark,
                        title: 'الواتساب والتقارير',
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF25D366),
                        collapsible: true,
                        initiallyExpanded: false,
                        children: [
                          _buildNavTile(
                            context,
                            isDark,
                            icon: Icons.send_rounded,
                            iconColor: const Color(0xFF25D366),
                            title: 'إرسال تقارير الشهر',
                            subtitle:
                                'يفتح محادثة واتساب لكل ولي أمر بتقرير مفصل',
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
                                onChanged: (v) async =>
                                    await settings.setWhatsappEnabled(v),
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
                      const SizedBox(height: 14),

                      // ── 5ب. ماسح QR ─────────────────────────────
                      _buildSection(
                        context,
                        isDark,
                        title: 'ماسح QR',
                        icon: Icons.qr_code_scanner_rounded,
                        color: const Color(0xFF0EA5E9),
                        collapsible: true,
                        initiallyExpanded: false,
                        children: [
                          Obx(() => _buildSwitchTile(
                                context,
                                isDark,
                                icon: Icons.payments_rounded,
                                iconColor: const Color(0xFF0EA5E9),
                                title: 'إخفاء ماسح QR في الدفع',
                                subtitle: settings.hideQrInPayment.value
                                    ? 'شاشة "تسجيل دفع" هتفتح على البحث اليدوي مباشرة'
                                    : 'مناسب لو مش بتطبع أكواد QR للطلاب',
                                rxValue: settings.hideQrInPayment,
                                onChanged: (v) async =>
                                    await settings.setHideQrInPayment(v),
                              )),
                          _buildDivider(isDark),
                          Obx(() => _buildSwitchTile(
                                context,
                                isDark,
                                icon: Icons.event_available_rounded,
                                iconColor: const Color(0xFF0EA5E9),
                                title: 'إخفاء ماسح QR في الحضور',
                                subtitle: settings.hideQrInAttendance.value
                                    ? 'شاشة تسجيل الحضور هتفتح على البحث اليدوي مباشرة'
                                    : 'مناسب لو مش بتطبع أكواد QR للطلاب',
                                rxValue: settings.hideQrInAttendance,
                                onChanged: (v) async =>
                                    await settings.setHideQrInAttendance(v),
                              )),
                          _buildDivider(isDark),
                          // ── تسجيل "متأخر" تلقائيًا عبر QR (spec 011) ──
                          Obx(() => _buildSwitchTile(
                                context,
                                isDark,
                                icon: Icons.schedule_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: 'تسجيل "متأخر" تلقائيًا عبر QR',
                                subtitle: settings.qrAutoLateEnabled.value
                                    ? 'لو الطالب اتمسح بعد بداية الحصة بأكتر من المهلة، يتسجّل "متأخر"'
                                    : 'معطّل — المسح يسجّل "حاضر" دايمًا',
                                rxValue: settings.qrAutoLateEnabled,
                                onChanged: (v) async =>
                                    await settings.setQrAutoLateEnabled(v),
                              )),
                          Obx(() => settings.qrAutoLateEnabled.value
                              ? Column(children: [
                                  _buildDivider(isDark),
                                  _buildDropdownTile<int>(
                                    context,
                                    isDark,
                                    icon: Icons.hourglass_bottom_rounded,
                                    iconColor: const Color(0xFFF59E0B),
                                    title: 'مهلة التأخير (دقائق)',
                                    value: settings.lateGraceMinutes.value,
                                    items: const [0, 5, 10, 15, 20, 30, 45, 60]
                                        .map((m) => DropdownMenuItem(
                                              value: m,
                                              child: Text(m == 0
                                                  ? 'فورًا بعد البداية'
                                                  : '$m دقيقة'),
                                            ))
                                        .toList(),
                                    onChanged: (m) async {
                                      if (m != null) {
                                        await settings.setLateGraceMinutes(m);
                                        ToastHelper.success('تم التغيير',
                                            title: 'مهلة التأخير');
                                      }
                                    },
                                  ),
                                ])
                              : const SizedBox.shrink()),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── 6. النسخ الاحتياطي ───────────────────────
                      _buildSection(
                        context,
                        isDark,
                        title: 'النسخ الاحتياطي',
                        icon: Icons.storage_rounded,
                        color: const Color(0xFF4F46E5),
                        collapsible: true,
                        initiallyExpanded: false,
                        children: [
                          // ── حفظ تلقائي ─────────────────────────────
                          Obx(() {
                            final svc = AutoBackupService();
                            return _buildSwitchTile(
                              context,
                              isDark,
                              icon: Icons.cloud_sync_rounded,
                              iconColor: const Color(0xFF4F46E5),
                              title: 'الحفظ التلقائي',
                              subtitle: svc.enabled.value
                                  ? svc.lastBackupTime.value != null
                                      ? svc.lastBackupLabel
                                      : 'يحفظ تلقائياً بعد كل تغيير'
                                  : 'يحفظ نسخة بعد كل تغيير',
                              rxValue: svc.enabled,
                              onChanged: (v) => svc.setEnabled(v),
                            );
                          }),
                          _buildDivider(isDark),
                          _buildNavTile(
                            context,
                            isDark,
                            icon: Icons.backup_rounded,
                            iconColor: const Color(0xFF4F46E5),
                            title: 'إنشاء نسخة احتياطية',
                            subtitle:
                                'نسخ كامل لقاعدة البيانات مع خيار المشاركة',
                            onTap: () {
                              if (!requireLicenseFeature(
                                  context,
                                  Get.find<LicenseController>().canBackup,
                                  'النسخ الاحتياطي غير متاح في الفترة التجريبية — قم بالترقية')) {
                                return;
                              }
                              _handleEnhancedBackup(context);
                            },
                          ),
                          _buildDivider(isDark),
                          _buildNavTile(
                            context,
                            isDark,
                            icon: Icons.restore_rounded,
                            iconColor: const Color(0xFF06B6D4),
                            title: 'استعادة نسخة احتياطية',
                            subtitle: 'استعادة البيانات من نسخة محفوظة',
                            onTap: () {
                              if (!requireLicenseFeature(
                                  context,
                                  Get.find<LicenseController>().canBackup,
                                  'استعادة النسخ الاحتياطية غير متاحة في الفترة التجريبية — قم بالترقية')) {
                                return;
                              }
                              if (!requireTeamOwnerIfTeamMode(context)) return;
                              _handleRestoreBackup(context);
                            },
                          ),
                          _buildDivider(isDark),
                          _buildNavTile(
                            context,
                            isDark,
                            icon: Icons.folder_open_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: 'إدارة النسخ الاحتياطية',
                            subtitle: 'عرض وحذف النسخ القديمة',
                            onTap: () => _handleManageBackups(context),
                          ),
                          _buildDivider(isDark),
                          _buildNavTile(
                            context,
                            isDark,
                            icon: Icons.delete_forever_rounded,
                            iconColor: const Color(0xFFEF4444),
                            title: 'حذف جميع البيانات',
                            subtitle: 'حذف نهائي — لا يمكن التراجع',
                            titleColor: const Color(0xFFEF4444),
                            onTap: () {
                              if (!requireTeamOwnerIfTeamMode(context)) return;
                              _handleDeleteAll(context, settings);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── 7. عن التطبيق ─────────────────────────────
                      // ── المجتمع والدعم (spec 017) ────────────────
                      _buildCommunitySection(context, isDark),
                      const SizedBox(height: 14),

                      _buildAboutSection(context, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: () => Get.back(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'الإعدادات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Container ────────────────────────────────────────────────────

  Widget _buildSection(
    BuildContext context,
    bool isDark, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    bool collapsible = false,
    bool initiallyExpanded = true,
  }) {
    final header = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white70 : const Color(0xFF374151),
          ),
        ),
      ],
    );

    final card = Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131D31).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.18)
                : const Color(0xFFD8E0F0).withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );

    if (!collapsible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: header,
          ),
          card,
        ],
      );
    }

    // قسم قابل للطي — ترويسة واضحة (كارت + سهم كبير ملوّن + "اضغط للفتح")
    // بدل السهم الرمادي الصغير القديم.
    return _CollapsibleSection(
      isDark: isDark,
      color: color,
      header: header,
      card: card,
      initiallyExpanded: initiallyExpanded,
    );
  }

  // ─── معلومات المعلم ───────────────────────────────────────────────────────

  Widget _buildTeacherSection(
    BuildContext context,
    bool isDark,
    SettingsController settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D7A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded,
                    size: 16, color: Color(0xFFFF4D7A)),
              ),
              const SizedBox(width: 8),
              Text(
                'بيانات المعلم',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131D31).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFFD8E0F0).withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Obx(() {
            final team = TeamModeService();
            final isAssistant = team.isEnabled.value && !team.isOwner.value;
            final fullName = settings.teacherFullName.value.trim();
            final avatarPath = settings.teacherAvatarPath.value.trim();

            ImageProvider? avatarImage;
            if (avatarPath.isNotEmpty) {
              final f = File(avatarPath);
              if (f.existsSync()) avatarImage = FileImage(f);
            }
            final initial =
                fullName.isNotEmpty ? fullName.characters.first : 'م';

            if (isAssistant) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'بيانات المعلم بتتعرض من حساب المدرس اللي انت مساعد لديه — معندكش صلاحية تعدّلها من جهازك',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ]),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
              children: [
                // ── الصورة ──────────────────────────────────────────
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final x = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 800,
                      imageQuality: 85,
                    );
                    if (x != null) {
                      settings.setTeacherAvatarPath(x.path);
                      await settings.saveTeacherInfo();
                    }
                  },
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: avatarImage,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: avatarImage == null
                            ? Text(initial,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ))
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isDark ? const Color(0xFF131D31) : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 11, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // ── الاسم + الجنس ─────────────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      _buildTextField(
                        isDark,
                        label: 'اسم المعلم',
                        value: settings.teacherFullName.value,
                        icon: Icons.badge_rounded,
                        onChanged: (v) async {
                          settings.setTeacherFullName(v);
                          await settings.saveTeacherInfo();
                        },
                      ),
                      const SizedBox(height: 12),
                      // ── اختيار الجنس ──────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _GenderChip(
                              isDark: isDark,
                              label: 'مستر',
                              icon: Icons.male_rounded,
                              color: const Color(0xFF4F46E5),
                              selected: settings.teacherGender.value == 'male',
                              onTap: () async {
                                settings.setTeacherGender('male');
                                await settings.saveTeacherInfo();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _GenderChip(
                              isDark: isDark,
                              label: 'مس',
                              icon: Icons.female_rounded,
                              color: const Color(0xFFE91E8C),
                              selected:
                                  settings.teacherGender.value == 'female',
                              onTap: () async {
                                settings.setTeacherGender('female');
                                await settings.saveTeacherInfo();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
                ),
                const SizedBox(height: 14),
                // ── التخصص — بيتكتب في رسائل الواتساب اللي بتتبعت لأولياء الأمور ──
                _buildTextField(
                  isDark,
                  label: 'التخصص',
                  value: settings.teacherSpecialization.value,
                  icon: Icons.school_rounded,
                  onChanged: (v) async {
                    settings.setTeacherSpecialization(v);
                    await settings.saveTeacherInfo();
                  },
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  // ─── عن التطبيق ───────────────────────────────────────────────────────────

  Widget _buildAboutSection(BuildContext context, bool isDark) {
    return _buildSection(
      context,
      isDark,
      title: 'عن التطبيق',
      icon: Icons.info_rounded,
      color: const Color(0xFF64748B),
      collapsible: true,
      initiallyExpanded: false,
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '—';
            return _buildInfoTile(
              isDark,
              icon: Icons.verified_rounded,
              iconColor: const Color(0xFF4F46E5),
              title: 'الإصدار',
              trailing: version,
            );
          },
        ),
        _buildDivider(isDark),
        _buildNavTile(
          context,
          isDark,
          icon: Icons.system_update_rounded,
          iconColor: const Color(0xFF10B981),
          title: 'تحقق من التحديثات',
          subtitle: 'ابحث عن نسخة أحدث من التطبيق',
          onTap: () => checkAndShowUpdateDialog(context, silent: false),
        ),
        _buildDivider(isDark),
        _buildNavTile(
          context,
          isDark,
          icon: Icons.help_outline_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: 'المساعدة والدعم',
          subtitle: 'تواصل معنا',
          onTap: () => _openSupportWhatsApp(),
        ),
        _buildDivider(isDark),
        _buildNavTile(
          context,
          isDark,
          icon: Icons.privacy_tip_outlined,
          iconColor: const Color(0xFF6366F1),
          title: 'سياسة الخصوصية',
          subtitle: 'كيف نتعامل مع بياناتك',
          onTap: () => _openPrivacyPolicy(),
        ),
      ],
    );
  }

  // spec 017 — قناة واتساب المجتمع (تحديثات + دعم + اقتراحات). رابط ثابت.
  static const String _kCommunityChannelUrl =
      'https://whatsapp.com/channel/0029VbDFTCsEquiR7nSaO52X';

  Future<void> _openCommunityChannel() async {
    try {
      await launchUrl(Uri.parse(_kCommunityChannelUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      ToastHelper.error('تعذّر فتح القناة، حاول تاني');
    }
  }

  Widget _buildCommunitySection(BuildContext context, bool isDark) {
    return _buildSection(
      context,
      isDark,
      title: 'المجتمع والدعم',
      icon: Icons.forum_rounded,
      color: const Color(0xFF25D366),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'قناة التحديثات والدعم — تابع الجديد أول بأول، وشارك مشاكلك واقتراحاتك مع مجتمع المدرسين.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.7,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openCommunityChannel,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('انضم لقناة التحديثات والدعم',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(
        'https://amertimraz.github.io/App-Active-Class/privacy-policy.html');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ToastHelper.error('تعذر فتح صفحة سياسة الخصوصية');
    }
  }

  Future<void> _openSupportWhatsApp() async {
    const supportPhone = '201096066818';
    final settings = Get.find<SettingsController>();
    final teacherName = settings.teacherFullName.value.trim();

    final message = StringBuffer()
      ..writeln('مرحبًا، أنا مدرس بستخدم تطبيق Active Class وعايز مساعدة/دعم فني.');
    if (teacherName.isNotEmpty) {
      message.writeln('الاسم: $teacherName');
    }

    final uri = Uri.parse(
        'https://wa.me/$supportPhone?text=${Uri.encodeComponent(message.toString())}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ToastHelper.error('تعذر فتح واتساب');
    }
  }

  // ─── Tile Builders ────────────────────────────────────────────────────────

  Widget _buildSwitchTile(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required RxBool rxValue,
    required void Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Obx(() => Switch(
                value: rxValue.value,
                onChanged: onChanged,
                activeColor: iconColor,
              )),
        ],
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor ??
                          (isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color:
                            isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.grey[500] : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTile<T>(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                DropdownButtonFormField<T>(
                  value: value,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: items,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    bool isDark, {
    required String label,
    required String value,
    required IconData icon,
    required void Function(String) onChanged,
    TextInputType? keyboardType,
    ui.TextDirection? textDirection,
    bool enabled = true,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: keyboardType,
      textDirection: textDirection ?? ui.TextDirection.rtl,
      enabled: enabled,
      onChanged: onChanged,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        color: isDark ? Colors.white : const Color(0xFF111827),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
        ),
        prefixIcon: Icon(icon,
            size: 18,
            color: isDark ? Colors.grey[400] : const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8FAFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.6), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 52,
      endIndent: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFE5E7EB),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  // ── Backup ────────────────────────────────────────────────────────────────
  Future<void> _handleEnhancedBackup(BuildContext context) async {
    final svc = BackupService();
    final result = await ProgressDialog.run(
      context,
      title: 'جاري إنشاء النسخة الاحتياطية...',
      icon: Icons.backup_rounded,
      task: svc.createBackup,
    );
    // فسحة صغيرة عشان أنيميشن إغلاق حوار التقدّم يخلص تماماً قبل ما
    // نفتح حوار تاني على نفس الـ Navigator (تجنّب تعارض بين إغلاق
    // وفتح حوارين في نفس الوقت تقريباً).
    await Future.delayed(const Duration(milliseconds: 80));
    if (!context.mounted) return;

    if (!result.success) {
      ToastHelper.error(result.error ?? 'فشل إنشاء النسخة الاحتياطية');
      return;
    }

    // نسخة Downloads اختيارية وبطيئة على بعض الأجهزة (MediaStore بيجمّد
    // الـ main thread لثوانٍ — قيد في المكتبة الأصلية مش حاجة نقدر نلغيها
    // من الداخل) — بنأجّلها شوية عشان شاشة النجاح تترسم وتبان فعلاً
    // للمستخدم قبل ما الجمود المؤقت يحصل، بدل ما تفضل شاشة "معلّقة"
    // بصريًا من أول لمسة. من غير toast عمداً: بتتنفذ بعيد زمنياً عن
    // لمسة المستخدم وممكن تحصل بعد ما يغيّر شاشة.
    if (result.localPath != null && result.fileName != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        svc.saveToDownloads(result.localPath!, result.fileName!);
      });
    }

    // البيانات اللي فعلياً اتحفظت جوه النسخة (نفس محتوى قاعدة البيانات
    // الحالية وقت الحفظ)، عشان المستخدم يشوف بالظبط قد إيه اتحفظ.
    final summary = await DatabaseService().getDataSummary();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('✅ تم إنشاء النسخة الاحتياطية',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(Icons.storage_rounded, Colors.green,
                'محفوظة داخل التطبيق (دائمة)'),
            const SizedBox(height: 6),
            Text('الحجم: ${result.fileSize ?? '—'}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            const Divider(height: 20),
            _DataSummaryList(summary: summary),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
          ),
          if (result.localPath != null)
            ElevatedButton.icon(
              onPressed: () {
                svc.shareBackup(result.localPath!);
                Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.share_rounded, size: 16),
              label:
                  const Text('مشاركة', style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Restore ───────────────────────────────────────────────────────────────
  Future<void> _handleRestoreBackup(BuildContext context) async {
    final svc = BackupService();

    // عرض خيارات الاستعادة
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('استعادة نسخة احتياطية',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // تحذير
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم استبدال جميع البيانات الحالية بالنسخة المختارة. هذا الإجراء لا يمكن التراجع عنه.',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // خيار 1: نسخ محفوظة
            _ChoiceButton(
              icon: Icons.history_rounded,
              color: AppTheme.primaryColor,
              title: 'من النسخ المحفوظة',
              subtitle: 'استعادة من نسخة أنشأتها سابقاً',
              onTap: () => Navigator.of(ctx).pop('local'),
            ),
            const SizedBox(height: 10),
            // خيار 2: اختيار ملف
            _ChoiceButton(
              icon: Icons.folder_open_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'اختيار ملف من الجهاز',
              subtitle: 'اختر ملف .db من Downloads أو أي مكان آخر',
              onTap: () => Navigator.of(ctx).pop('pick'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    String? selectedPath;

    if (choice == 'local') {
      // عرض النسخ المحفوظة
      LoadingDialog.show(context, message: 'جاري تحميل النسخ...');
      final backups = await svc.getLocalBackups();
      if (!context.mounted) return;
      LoadingDialog.hide();

      if (backups.isEmpty) {
        ToastHelper.info(
            'لا توجد نسخ احتياطية محفوظة داخل التطبيق.\nجرّب "اختيار ملف من الجهاز"');
        return;
      }

      selectedPath = await showDialog<String>(
        context: context,
        builder: (ctx) => _BackupListDialog(backups: backups, svc: svc),
      );
    } else {
      // File picker
      final picked = await svc.pickBackupFile();
      if (picked == 'INVALID_EXT') {
        if (context.mounted) {
          ToastHelper.error('الملف المختار ليس ملف .db صالح');
        }
        return;
      }
      selectedPath = picked;
    }

    if (selectedPath == null || !context.mounted) return;

    // تأكيد نهائي
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الاستعادة',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                color: Colors.red)),
        content: const Text(
          'هل أنت متأكد؟\nسيتم مسح جميع البيانات الحالية واستبدالها بالنسخة المختارة.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('استعادة الآن',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    // فسحة صغيرة عشان أنيميشن إغلاق حوار التأكيد يخلص الأول
    await Future.delayed(const Duration(milliseconds: 80));
    if (!context.mounted) return;

    final success = await ProgressDialog.run(
      context,
      title: 'جاري استعادة النسخة الاحتياطية...',
      icon: Icons.restore_rounded,
      color: const Color(0xFF06B6D4),
      task: () => svc.restoreBackup(selectedPath!),
    );
    if (!context.mounted) return;

    if (success) {
      // كل الكنترولرز لسه فاكرة بيانات ما قبل الاستعادة في الذاكرة —
      // لازم نعيد تحميلها كلها من القاعدة المستعادة، وإلا التطبيق يفضل
      // يعرض الطلاب/المجموعات/الامتحانات القديمة (أو فاضية لو استعادة
      // على تثبيت جديد) رغم إن القاعدة اتغيّرت فعلاً.
      await _reloadAllControllers();
      if (!context.mounted) return;
      ToastHelper.success('تم استعادة النسخة الاحتياطية بنجاح');
      await Future.delayed(const Duration(milliseconds: 400));
      Get.offAllNamed(ROUTE_HOME);
    } else {
      ToastHelper.error('فشل الاستعادة — البيانات الأصلية لا تزال سليمة');
    }
  }

  Future<void> _reloadAllControllers() async {
    Future<void> tryReload(bool registered, Future<void> Function() fn) async {
      if (!registered) return;
      try {
        await fn();
      } catch (_) {}
    }

    await tryReload(Get.isRegistered<SettingsController>(),
        () => Get.find<SettingsController>().reloadFromDatabase());
    await tryReload(Get.isRegistered<GroupController>(),
        () => Get.find<GroupController>().loadGroups());
    await tryReload(Get.isRegistered<StudentController>(),
        () => Get.find<StudentController>().loadAllStudents());
    await tryReload(Get.isRegistered<ExamController>(),
        () => Get.find<ExamController>().loadExams());
    await tryReload(Get.isRegistered<AttendanceController>(),
        () => Get.find<AttendanceController>().loadAttendance());
    await tryReload(Get.isRegistered<PaymentController>(),
        () => Get.find<PaymentController>().loadPayments());
    await tryReload(Get.isRegistered<HomeworkController>(),
        () => Get.find<HomeworkController>().loadHomework());
    await tryReload(Get.isRegistered<DashboardController>(),
        () async => Get.find<DashboardController>().refresh());
  }

  // ── Manage backups ────────────────────────────────────────────────────────
  Future<void> _handleManageBackups(BuildContext context) async {
    final svc = BackupService();
    LoadingDialog.show(context, message: 'جاري تحميل النسخ...');
    final backups = await svc.getLocalBackups();
    if (!context.mounted) return;
    LoadingDialog.hide();

    if (backups.isEmpty) {
      ToastHelper.info(
          'لا توجد نسخ احتياطية محفوظة\nأنشئ نسخة أولاً من "نسخ احتياطي"');
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => _ManageBackupsDialog(
        backups: backups,
        svc: svc,
        onChanged: () {
          Navigator.of(ctx).pop();
          _handleManageBackups(context);
        },
      ),
    );
  }

  void _handleDeleteAll(
      BuildContext context, SettingsController settingsController) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ConfirmDeleteDialog.show(
        context,
        title: 'حذف جميع البيانات',
        message:
            'هل أنت متأكد؟ سيتم حذف جميع البيانات بشكل نهائي ولا يمكن التراجع',
        onConfirm: () async {
          try {
            // لازم ناخد الملخص قبل الحذف — بعد الحذف كل الأعداد بتبقى صفر
            final summary = await DatabaseService().getDataSummary();
            // فسحة صغيرة عشان أنيميشن إغلاق حوار التأكيد يخلص الأول
            await Future.delayed(const Duration(milliseconds: 80));
            if (!context.mounted) return;
            await ProgressDialog.run(
              context,
              title: 'جاري حذف البيانات...',
              icon: Icons.delete_forever_rounded,
              color: Colors.red,
              task: settingsController.deleteAllData,
            );
            await Future.delayed(const Duration(milliseconds: 80));
            if (!context.mounted) return;
            SuccessDialog.show(
              context,
              title: 'تم الحذف',
              message: 'تم حذف جميع البيانات بنجاح',
              content: _DataSummaryList(summary: summary),
            );
          } catch (e) {
            if (!context.mounted) return;
            ErrorDialog.show(
              context,
              title: 'فشل الحذف',
              message: e.toString(),
            );
          }
        },
      );
    });
  }

  Future<void> _startWhatsappBatchSend(
      BuildContext context, SettingsController settings) async {
    final db = DatabaseService();
    LoadingDialog.show(context, message: 'تحضير الرسائل...');
    try {
      final students = await db.getAllStudents();

      // مفيش داعي نبعت رسائل واتساب جماعية لأولياء أمور طلاب مؤرشفين —
      // ده شغل يومي نشط، مش سجل تاريخي.
      final valid = students
          .where((s) => !s.isArchived)
          .where((s) => (s.guardianPhone ?? '').trim().isNotEmpty)
          .toList();
      if (valid.isEmpty) {
        LoadingDialog.hide();
        ToastHelper.info('لا يوجد أولياء أمور بأرقام مسجلة');
        return;
      }

      LoadingDialog.hide();
      if (!context.mounted) return;
      final selected = await _pickRecipients(context, valid);
      if (selected == null || selected.isEmpty) return;

      // منتقي شهر التقرير — الافتراضي والحد الأقصى هو شهر التحصيل
      // (آخر شهر مكتمل) — spec 013 US3.
      if (!context.mounted) return;
      final collectionMonth = defaultCollectionMonth();
      final pickedMonth = await showDatePicker(
        context: context,
        initialDate: collectionMonth,
        firstDate: DateTime(collectionMonth.year - 3, 1, 1),
        lastDate: DateTime(collectionMonth.year, collectionMonth.month + 1, 0),
        helpText: 'اختر شهر التقرير',
      );
      if (pickedMonth == null) return;
      final month = DateTime(pickedMonth.year, pickedMonth.month, 1);
      final start = month;
      final monthEnd =
          DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      String normalize(String input, String defaultDial) {
        var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
        if (p.startsWith('+')) p = p.substring(1);
        if (p.startsWith('00')) p = p.substring(2);
        if (p.startsWith(defaultDial)) return p;
        if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
        p = p.replaceFirst(RegExp(r'^0+'), '');
        return defaultDial + p;
      }

      for (final s in selected) {
        final rawPhone = s.guardianPhone!.trim();
        final phone = normalize(rawPhone, settings.countryDial.value);

        final group = await db.getGroup(s.groupId);

        final atts = await db.getAttendanceByStudent(s.id!);
        final pays = await db.getPaymentsByStudent(s.id!);
        final hw = await db.getHomeworkByStudent(s.id!);

        final attsMonth = atts
            .where((a) => !a.date.isBefore(start) && !a.date.isAfter(monthEnd))
            .toList();
        final paysMonth = pays
            .where((p) => !p.date.isBefore(start) && !p.date.isAfter(monthEnd))
            .toList();
        final hwMonth = hw
            .where((h) => !h.date.isBefore(start) && !h.date.isAfter(monthEnd))
            .toList();
        final examsMonth = (await db.getStudentExamHistory(s.id!))
            .where((r) =>
                r.reportMonth.year == month.year &&
                r.reportMonth.month == month.month)
            .toList();

        final message = buildMonthlyReportMessage(
          student: s,
          month: month,
          groupName: group?.name ?? '-',
          monthAtt: attsMonth,
          monthHw: hwMonth,
          monthPays: paysMonth,
          monthExams: examsMonth,
          teacherName: settings.teacherFullName.value,
          teacherSpecialization: settings.teacherSpecialization.value,
          canSeeFinancials: TeamModeService().canSeeFinancials,
          canSeeAcademics: TeamModeService().canSeeAcademics,
        );

        final uri = Uri.parse(
            'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await _waitForResume();
      }
    } catch (e) {
      LoadingDialog.hide();
      ToastHelper.error('تعذر التحضير أو الإرسال');
    }
  }
}

// ─── Helper Widgets ────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF131D31).withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.16)
                  : const Color(0xFFD9E1F2).withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
      ),
    );
  }
}

// ─── Gender Chip ──────────────────────────────────────────────────────────

class _GenderChip extends StatelessWidget {
  final bool isDark;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.isDark,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 20,
                color: selected
                    ? color
                    : (isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected
                    ? color
                    : (isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top-level helpers (unchanged logic) ──────────────────────────────────

Future<List<Student>?> _pickRecipients(
    BuildContext context, List<Student> all) async {
  return await showDialog<List<Student>>(
    context: context,
    builder: (ctx) {
      List<Student> items = List.of(all)
        ..sort((a, b) => a.name.compareTo(b.name));
      List<bool> sel = List<bool>.filled(items.length, true);
      bool selectAll = true;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('اختر أولياء الأمور',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: selectAll,
                  onChanged: (v) {
                    setState(() {
                      selectAll = v ?? false;
                      for (int i = 0; i < sel.length; i++) {
                        sel[i] = selectAll;
                      }
                    });
                  },
                  title: const Text('تحديد الكل',
                      style: TextStyle(fontFamily: 'Cairo')),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(height: 0),
                SizedBox(
                  height: 360,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final s = items[i];
                      return CheckboxListTile(
                        value: sel[i],
                        onChanged: (v) => setState(() => sel[i] = v ?? false),
                        title: Text(s.name,
                            style: const TextStyle(fontFamily: 'Cairo')),
                        subtitle: Text(s.guardianPhone ?? '-',
                            style: const TextStyle(fontFamily: 'Cairo')),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: sel.any((e) => e)
                  ? () {
                      final chosen = <Student>[];
                      for (int i = 0; i < items.length; i++) {
                        if (sel[i]) chosen.add(items[i]);
                      }
                      Navigator.of(ctx).pop(chosen);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ابدأ الإرسال',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
    },
  );
}

class _ResumeObserver extends WidgetsBindingObserver {
  final void Function() onResume;
  _ResumeObserver(this.onResume);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

Future<void> _waitForResume() {
  final c = Completer<void>();
  late _ResumeObserver obs;
  obs = _ResumeObserver(() {
    WidgetsBinding.instance.removeObserver(obs);
    if (!c.isCompleted) c.complete();
  });
  WidgetsBinding.instance.addObserver(obs);
  return c.future;
}

Future<void> sendMonthlyReportsViaWhatsAppAuto(BuildContext context) async {
  final SettingsController settingsController = Get.find();
  await const SettingsPage()
      ._startWhatsappBatchSend(context, settingsController);
}

// ══════════════════════════════════════════════════════════════════════════
//  Backup UI Helpers
// ══════════════════════════════════════════════════════════════════════════

/// صف معلومة صغير (أيقونة + نص)
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _InfoRow(this.icon, this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
        ),
      ]),
    );
  }
}

/// ملخص أعداد البيانات — بيُستخدم في حوارات نجاح النسخ الاحتياطي والحذف
class _DataSummaryList extends StatelessWidget {
  final DataSummary summary;
  const _DataSummaryList({required this.summary});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String)>[
      (Icons.groups_rounded, '${summary.groups} مجموعة'),
      (Icons.person_rounded, '${summary.students} طالب'),
      (Icons.how_to_reg_rounded, '${summary.attendanceRecords} سجل حضور'),
      (Icons.payments_rounded, '${summary.payments} دفعة'),
      (Icons.assignment_rounded, '${summary.exams} امتحان'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          rows.map((r) => _InfoRow(r.$1, AppTheme.primaryColor, r.$2)).toList(),
    );
  }
}

/// زر اختيار كبير
class _ChoiceButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
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
                          fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ]),
        ),
      ),
    );
  }
}

/// ديالوج اختيار نسخة للاستعادة
class _BackupListDialog extends StatelessWidget {
  final List<BackupInfo> backups;
  final BackupService svc;
  const _BackupListDialog({required this.backups, required this.svc});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('النسخ المحفوظة (${backups.length})',
          style: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.separated(
          itemCount: backups.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final b = backups[i];
            final isLatest = i == 0;
            return ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLatest
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.backup_rounded,
                        color: isLatest
                            ? const Color(0xFFF59E0B)
                            : AppTheme.primaryColor,
                        size: 20),
                  ),
                  if (isLatest)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('أحدث',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                ],
              ),
              title: Text(b.dateLabel,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isLatest ? const Color(0xFFF59E0B) : null)),
              subtitle: Text(b.sizeLabel,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
              onTap: () => Navigator.of(context).pop(b.path),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

/// ديالوج إدارة النسخ الاحتياطية
class _ManageBackupsDialog extends StatefulWidget {
  final List<BackupInfo> backups;
  final BackupService svc;
  final VoidCallback onChanged;
  const _ManageBackupsDialog(
      {required this.backups, required this.svc, required this.onChanged});

  @override
  State<_ManageBackupsDialog> createState() => _ManageBackupsDialogState();
}

class _ManageBackupsDialogState extends State<_ManageBackupsDialog> {
  late List<BackupInfo> _backups;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _backups = List.from(widget.backups);
  }

  void _confirmDeleteOne(BackupInfo b) {
    ConfirmDeleteDialog.show(
      context,
      title: 'حذف النسخة الاحتياطية',
      message:
          'هل تريد حذف هذه النسخة الاحتياطية نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
      onConfirm: () => _deleteOne(b),
    );
  }

  Future<void> _deleteOne(BackupInfo b) async {
    setState(() => _deleting = true);
    await widget.svc.deleteBackup(b.path);
    if (!mounted) return;
    setState(() {
      _backups.remove(b);
      _deleting = false;
    });
    if (_backups.isEmpty && mounted) Navigator.of(context).pop();
  }

  void _confirmCleanOld() {
    ConfirmDeleteDialog.show(
      context,
      title: 'حذف النسخ القديمة',
      message:
          'سيتم حذف ${_backups.length - 5} نسخة احتياطية قديمة نهائياً والاحتفاظ بأحدث 5 فقط. لا يمكن التراجع عن هذا الإجراء.',
      onConfirm: _cleanOld,
    );
  }

  Future<void> _cleanOld() async {
    setState(() => _deleting = true);
    final deleted = await widget.svc.cleanOldBackups(keepCount: 5);
    if (!mounted) return;
    setState(() => _deleting = false);
    Navigator.of(context).pop();
    ToastHelper.success('تم حذف $deleted نسخة قديمة — تم الاحتفاظ بأحدث 5');
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('النسخ الاحتياطية (${_backups.length})',
          style: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // زر "احتفظ بأحدث 5"
            if (_backups.length > 5)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _deleting ? null : _confirmCleanOld,
                    icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                    label: Text(
                        'احتفظ بأحدث 5 فقط (احذف ${_backups.length - 5})',
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            // القائمة
            Expanded(
              child: ListView.separated(
                itemCount: _backups.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final b = _backups[i];
                  final isLatest = i == 0;
                  return ListTile(
                    dense: true,
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.backup_rounded,
                            color: isLatest
                                ? const Color(0xFFF59E0B)
                                : AppTheme.primaryColor,
                            size: 20),
                        if (isLatest)
                          Positioned(
                            top: -6,
                            left: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text('★',
                                  style: TextStyle(
                                      fontSize: 7,
                                      color: Colors.white,
                                      height: 1)),
                            ),
                          ),
                      ],
                    ),
                    title: Text(b.dateLabel,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isLatest ? const Color(0xFFF59E0B) : null)),
                    subtitle: Text(b.sizeLabel,
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    trailing: i == 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('أحدث',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFF59E0B))),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.red, size: 20),
                                onPressed: _deleting
                                    ? null
                                    : () => _confirmDeleteOne(b),
                                tooltip: 'حذف هذه النسخة',
                              ),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red, size: 20),
                            onPressed:
                                _deleting ? null : () => _confirmDeleteOne(b),
                            tooltip: 'حذف هذه النسخة',
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

class _ParentPortalTile extends StatefulWidget {
  final bool isDark;
  final bool expired;
  const _ParentPortalTile({required this.isDark, this.expired = false});
  @override
  State<_ParentPortalTile> createState() => _ParentPortalTileState();
}

class _ParentPortalTileState extends State<_ParentPortalTile> {
  String? _slug;
  bool _loading = true;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slug = await ParentPortalService().ensureSlug();
    // ننشر بروفايل المدرس (اسمه) فورًا من غير ما ننتظر أول طالب عنده
    // رقم تليفون صحيح — وإلا صفحة المتابعة تفضل من غير اسم لحد ما
    // تتنشر أول بيانات طالب فعليًا.
    unawaited(ParentPortalService().publishProfile());
    if (mounted) setState(() { _slug = slug; _loading = false; });
  }

  String get _url => 'https://active-class.online/track/${_slug ?? ''}';

  Future<void> _publishAll() async {
    setState(() => _publishing = true);
    try {
      final count = await ParentPortalService().publishAllStudents();
      if (!mounted) return;
      ToastHelper.success('اتنشرت بيانات $count طالب (اللي عندهم رقم ولي أمر)');
    } catch (e) {
      // لو النشر فشل (اتصال ضعيف، أو صف واحد بس رفضته قاعدة الأمان)
      // Firestore بترجع الـ batch كله بالفشل من غير ما تنفّذ ولا صف —
      // من غير catch هنا، الزرار كان بيفضل "بينشر..." للأبد من غير أي
      // رسالة، وده اللي كان بيبان وكأن التطبيق "علّق".
      debugPrint('SettingsPage: publishAllStudents failed — $e');
      if (!mounted) return;
      ToastHelper.error('فشل النشر — تأكد من الاتصال بالإنترنت وحاول تاني');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // حالة الاشتراك + تاريخ الانتهاء
          Obx(() {
            final lic = Get.find<LicenseController>();
            // ignore: unnecessary_statements
            lic.parentPortalRecheckTick.value;
            // ignore: unnecessary_statements
            lic.licenseVerifiedTick.value;
            final exp = lic.parentPortalExpiresAt.value;
            final active = lic.parentPortalActiveNow;
            final Color c = active
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444);
            final String line;
            if (!active) {
              line = exp != null
                  ? 'انتهت مدة الإضافة في ${FormatHelper.formatFullDate(exp)} — تواصل معنا لتجديدها.'
                  : 'الإضافة غير مفعّلة حاليًا.';
            } else if (exp == null) {
              line = 'الإضافة مفعّلة — مدى الحياة.';
            } else {
              final days = exp.difference(DateTime.now()).inDays;
              line = days <= 7
                  ? 'الإضافة مفعّلة — تنتهي بعد $days يوم (${FormatHelper.formatFullDate(exp)}).'
                  : 'الإضافة مفعّلة — تنتهي في ${FormatHelper.formatFullDate(exp)}.';
            }
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                Icon(active ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 16, color: c),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(line,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c)),
                ),
              ]),
            );
          }),
          if (widget.expired)
            Text(
              'صفحة المتابعة مقفولة على أولياء الأمور لحد ما تجدّد الاشتراك.',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black45),
            )
          else
            Text(
              'ابعت الرابط ده لأولياء الأمور — هيقدروا يدخلوا كود الطالب وآخر 4 أرقام من رقم تليفونهم يشوفوا حضوره ومدفوعاته.',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black45),
            ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_url,
                textDirection: ui.TextDirection.ltr,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _url));
                  ToastHelper.success('تم نسخ الرابط');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('نسخ', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Share.share(_url),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('مشاركة', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _publishing ? null : _publishAll,
              icon: _publishing
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded, size: 16),
              label: const Text('نشر بيانات كل الطلاب الآن',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── قسم إعدادات قابل للطي بترويسة واضحة ──────────────────────────────────────
class _CollapsibleSection extends StatefulWidget {
  final bool isDark;
  final Color color;
  final Widget header;
  final Widget card;
  final bool initiallyExpanded;
  const _CollapsibleSection({
    required this.isDark,
    required this.color,
    required this.header,
    required this.card,
    required this.initiallyExpanded,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final headerBar = InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _open = !_open),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF131D31).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE7E9F3),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: widget.header),
            if (!_open)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('اضغط للفتح',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: widget.color.withValues(alpha: 0.75))),
              ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: widget.color, size: 22),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerBar,
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: widget.card,
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }
}

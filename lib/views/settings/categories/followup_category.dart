part of '../settings_page.dart';

// spec 051 — فئة «المتابعة والتنبيهات» بتصميم السبورة والكروت:
// سبورة بعدد القواعد المفعّلة، كروت تشغيل للقواعد، قايمة الحدود، وكروت روابط.

class _FollowupCategoryPage extends StatelessWidget {
  const _FollowupCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _tk(isDark);
    final SettingsController settings = Get.find();
    const red = Color(0xFFEF4444);
    const amber = Color(0xFFF59E0B);
    const violet = Color(0xFF8B5CF6);
    const gap = SizedBox(height: AppSpace.lg);
    return _CategoryScaffold(
      title: 'المتابعة والتنبيهات',
      highlightId: highlightId,
      children: [
        // ── السبورة: القواعد المفعّلة ──
        Obx(() {
          final rules = [
            settings.atRiskAbsenceEnabled.value,
            settings.atRiskHomeworkEnabled.value,
            settings.atRiskGradeEnabled.value,
            settings.atRiskPaymentEnabled.value,
          ];
          final on = rules.where((e) => e).length;
          return _boardSummary(
            t,
            icon: Icons.warning_amber_rounded,
            title: 'المتابعة والتنبيهات',
            subtitle: 'الطلاب اللي محتاجين انتباه',
            stats: [
              (label: 'القواعد المفعّلة', value: '$on من ${rules.length}'),
              (
                label: 'كارت الرئيسية',
                value: settings.homeAtRiskCard.value ? 'ظاهر' : 'مخفي'
              ),
              (
                label: 'غياب متتالي',
                value: settings.atRiskAbsenceEnabled.value
                    ? '${settings.atRiskAbsenceThreshold.value} حصص'
                    : 'مقفول'
              ),
              (
                label: 'التهدئة',
                value: '${settings.atRiskCooldownDays.value} يوم'
              ),
            ],
          );
        }),
        gap,
        // ── القواعد: كروت تشغيل/إيقاف ──
        _plainSectionBlock(
          t,
          'طلاب محتاجين متابعة',
          Icons.warning_amber_rounded,
          red,
          _cardGrid([
            _toggleCard(
              t,
              rx: settings.homeAtRiskCard,
              icon: Icons.dashboard_customize_rounded,
              color: red,
              title: 'كارت المتابعة في الرئيسية',
              onHint: 'ظاهر — كارت عريض لو فيه طلاب محتاجين متابعة',
              offHint: 'مخفي — الأيقونة فوق في الرئيسية كفاية',
              set: (v) async => await settings.setHomeAtRiskCard(v),
            ),
            Obx(() => _toggleCard(
                  t,
                  rx: settings.atRiskAbsenceEnabled,
                  icon: Icons.event_busy_rounded,
                  color: red,
                  title: 'غياب متتالي',
                  sharedKey: SETTING_ATRISK_ABSENCE_ENABLED,
                  onHint:
                      'رصد بعد ${settings.atRiskAbsenceThreshold.value} حصص غياب ورا بعض',
                  offHint:
                      'مقفول — رصد بعد ${settings.atRiskAbsenceThreshold.value} حصص غياب',
                  set: (v) async => settings.setAtRiskAbsence(enabled: v),
                )),
            Obx(() => _toggleCard(
                  t,
                  rx: settings.atRiskHomeworkEnabled,
                  icon: Icons.assignment_late_rounded,
                  color: amber,
                  title: 'واجب ناقص متكرر',
                  sharedKey: SETTING_ATRISK_HOMEWORK_ENABLED,
                  onHint:
                      '${settings.atRiskHomeworkM.value} من آخر ${settings.atRiskHomeworkW.value} حصص',
                  offHint:
                      'مقفول — ${settings.atRiskHomeworkM.value} من آخر ${settings.atRiskHomeworkW.value} حصص',
                  set: (v) async => settings.setAtRiskHomework(enabled: v),
                )),
            Obx(() => _toggleCard(
                  t,
                  rx: settings.atRiskGradeEnabled,
                  icon: Icons.trending_down_rounded,
                  color: violet,
                  title: 'هبوط الدرجات',
                  sharedKey: SETTING_ATRISK_GRADE_ENABLED,
                  onHint:
                      'رصد لو نزلت ${settings.atRiskGradeDropPoints.value} نقطة أو تحت النجاح',
                  offHint:
                      'مقفول — رصد لو نزلت ${settings.atRiskGradeDropPoints.value} نقطة',
                  set: (v) async => settings.setAtRiskGrade(enabled: v),
                )),
          ]),
        ),
        gap,
        // ── حدود الرصد: قوايم اختيار ──
        _buildSection(
          context,
          isDark,
          title: 'حدود الرصد',
          icon: Icons.tune_rounded,
          color: red,
          children: [
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.repeat_rounded,
                  iconColor: red,
                  title: 'عدد حصص الغياب المتتالي',
                  sharedKey: SETTING_ATRISK_ABSENCE_THRESHOLD,
                  value: settings.atRiskAbsenceThreshold.value,
                  items: List.generate(9, (i) => i + 1)
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text('$n حصص')))
                      .toList(),
                  onChanged: (n) {
                    if (n != null) {
                      settings.setAtRiskAbsence(threshold: n);
                    }
                  },
                )),
            _buildDivider(isDark),
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.pending_actions_rounded,
                  iconColor: amber,
                  title: 'عدد مرات الواجب الناقص',
                  sharedKey: SETTING_ATRISK_HOMEWORK_M,
                  value: settings.atRiskHomeworkM.value,
                  items: List.generate(10, (i) => i + 1)
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text('$n مرات')))
                      .toList(),
                  onChanged: (n) {
                    if (n != null) {
                      settings.setAtRiskHomework(m: n);
                    }
                  },
                )),
            _buildDivider(isDark),
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.view_week_rounded,
                  iconColor: amber,
                  title: 'من آخر كام حصة',
                  sharedKey: SETTING_ATRISK_HOMEWORK_W,
                  value: settings.atRiskHomeworkW.value,
                  items: List.generate(15, (i) => i + 1)
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text('$n حصص')))
                      .toList(),
                  onChanged: (n) {
                    if (n != null) {
                      settings.setAtRiskHomework(w: n);
                    }
                  },
                )),
            _buildDivider(isDark),
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.percent_rounded,
                  iconColor: violet,
                  title: 'مقدار هبوط الدرجة',
                  sharedKey: SETTING_ATRISK_GRADE_DROP_POINTS,
                  value: settings.atRiskGradeDropPoints.value,
                  items: [5, 10, 15, 20, 25, 30, 40, 50]
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text('$n نقطة')))
                      .toList(),
                  onChanged: (n) {
                    if (n != null) {
                      settings.setAtRiskGrade(dropPoints: n);
                    }
                  },
                )),
            _buildDivider(isDark),
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.snooze_rounded,
                  iconColor: const Color(0xFF64748B),
                  title: 'مدة التهدئة بعد "تمّت المتابعة"',
                  sharedKey: SETTING_ATRISK_COOLDOWN_DAYS,
                  value: settings.atRiskCooldownDays.value,
                  items: [1, 3, 5, 7, 10, 14, 21, 30]
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text('$n يوم')))
                      .toList(),
                  onChanged: (n) {
                    if (n != null) {
                      settings.setAtRiskCooldownDays(n);
                    }
                  },
                )),
          ],
        ),
        gap,
        // ── الإشعارات وتأخّر الدفع: كروت روابط ──
        _plainSectionBlock(
          t,
          'الإشعارات',
          Icons.notifications_rounded,
          red,
          _cardGrid([
            _actionCard(
              t,
              icon: Icons.tune_rounded,
              color: red,
              title: 'مركز الإشعارات',
              hint: 'إشعارات الميلاد والحصص والدفعات',
              onTap: () => Get.toNamed(ROUTE_NOTIFICATION_SETTINGS),
            ),
            // تأخّر الدفع بقى في فئة الفلوس والتحصيل (مع مهلة السماح) —
            // كارت تنقّل بدل ما المدرس يدوّر عليه.
            _actionCard(
              t,
              icon: Icons.payments_rounded,
              color: const Color(0xFF10B981),
              title: 'تأخّر الدفع',
              hint: 'بيتظبط من «الفلوس والتحصيل» مع مهلة السماح',
              onTap: () => Get.to(() => const _BillingCategoryPage()),
            ),
          ]),
        ),
      ],
    );
  }
}

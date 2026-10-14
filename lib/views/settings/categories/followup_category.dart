part of '../settings_page.dart';

// spec 051 — فئة «المتابعة والتنبيهات»

class _FollowupCategoryPage extends StatelessWidget {
  const _FollowupCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final SettingsController settings = Get.find();
    return _CategoryScaffold(
      title: 'المتابعة والتنبيهات',
      highlightId: highlightId,
      children: [
        _buildSection(
          context,
          isDark,
          title: 'طلاب محتاجين متابعة',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
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
                  onChanged: (v) => settings.setAtRiskAbsence(enabled: v),
                )),
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.repeat_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'عدد حصص الغياب المتتالي',
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
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.assignment_late_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'واجب ناقص متكرر',
                  subtitle:
                      '${settings.atRiskHomeworkM.value} من آخر ${settings.atRiskHomeworkW.value} حصص',
                  rxValue: settings.atRiskHomeworkEnabled,
                  onChanged: (v) => settings.setAtRiskHomework(enabled: v),
                )),
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.pending_actions_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'عدد مرات الواجب الناقص',
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
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.view_week_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'من آخر كام حصة',
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
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.trending_down_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'هبوط الدرجات',
                  subtitle:
                      'رصد لو نزلت ${settings.atRiskGradeDropPoints.value} نقطة أو تحت النجاح',
                  rxValue: settings.atRiskGradeEnabled,
                  onChanged: (v) => settings.setAtRiskGrade(enabled: v),
                )),
            Obx(() => _buildDropdownTile<int>(
                  context,
                  isDark,
                  icon: Icons.percent_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'مقدار هبوط الدرجة',
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
            _buildDivider(isDark),
            // تأخّر الدفع بقى في فئة الفلوس والتحصيل (مع مهلة السماح) —
            // سطر تنقّل بدل ما المدرس يدوّر عليه.
            _buildNavTile(
              context,
              isDark,
              icon: Icons.payments_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'تأخّر الدفع',
              subtitle: 'بيتظبط من «الفلوس والتحصيل» مع مهلة السماح',
              onTap: () => Get.to(() => const _BillingCategoryPage()),
            ),
          ],
        ),
        const SizedBox(height: 14),
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
              onTap: () => Get.toNamed(ROUTE_NOTIFICATION_SETTINGS),
            ),
          ],
        ),
      ],
    );
  }
}

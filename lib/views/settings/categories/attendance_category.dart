part of '../settings_page.dart';

// spec 051 — فئة «الحضور والحصص»

class _AttendanceCategoryPage extends StatelessWidget {
  const _AttendanceCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final SettingsController settings = Get.find();
    return _CategoryScaffold(
      title: 'الحضور والحصص',
      highlightId: highlightId,
      children: [
        _buildSection(
          context,
          isDark,
          title: 'ورقة الحضور',
          icon: Icons.fact_check_rounded,
          color: const Color(0xFF3B82F6),
          children: [
            // ── تنبيه المتأخر في الدفع بشاشة الحضور (spec 029) ──
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'تنبيه المتأخر في شاشة الحضور',
                  subtitle: settings.attendanceOverdueWarning.value
                      ? 'بيظهر شريط تحذير جنب اسم الطالب المتأخر وقت تسجيل حضوره'
                      : 'معطّل — مفيش تحذير دفع في شاشة الحضور',
                  rxValue: settings.attendanceOverdueWarning,
                  onChanged: (v) async =>
                      await settings.setAttendanceOverdueWarning(v),
                )),
            _buildDivider(isDark),
            // ── أدوات الحصة في ورقة حضور اليوم: واجب / تسميع / تفاعل ──
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'الواجب في حضور اليوم',
                  subtitle: settings.showHomework.value
                      ? 'ظاهر — تبويب الواجب في ورقة حضور اليوم'
                      : 'مخفي — لا يظهر تسجيل الواجب',
                  rxValue: settings.showHomework,
                  onChanged: (v) async => await settings.setShowHomework(v),
                )),
            _buildDivider(isDark),
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.record_voice_over_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'درجة التسميع',
                  subtitle: settings.showRecitation.value
                      ? 'ظاهرة — داخل تبويب الواجب (1 إلى 10)'
                      : 'مخفية — لا يظهر تسجيل التسميع',
                  rxValue: settings.showRecitation,
                  onChanged: (v) async => await settings.setShowRecitation(v),
                )),
            // الدرجة العظمى للتسميع (مش لازم تكون 10)
            Obx(() => settings.showRecitation.value
                ? Column(children: [
                    _buildDivider(isDark),
                    _buildDropdownTile<int>(
                      context,
                      isDark,
                      icon: Icons.stairs_rounded,
                      iconColor: const Color(0xFF0EA5E9),
                      title: 'الدرجة العظمى للتسميع',
                      value: settings.recitationMax.value,
                      items: const [5, 10, 15, 20, 25, 30, 40, 50, 100]
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('من $m'),
                              ))
                          .toList(),
                      onChanged: (m) async {
                        if (m != null) {
                          await settings.setRecitationMax(m);
                          ToastHelper.success(
                              'الدرجات الجديدة هتتسجّل من $m (القديمة بتفضل زي ما هي)',
                              title: 'التسميع');
                        }
                      },
                    ),
                  ])
                : const SizedBox.shrink()),
            _buildDivider(isDark),
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.emoji_emotions_rounded,
                  iconColor: Colors.deepPurple,
                  title: 'تفاعل الطالب',
                  subtitle: settings.showInteraction.value
                      ? 'ظاهر — إيموجي التفاعل في ورقة الحضور'
                      : 'مخفي — لا يظهر تسجيل التفاعل',
                  rxValue: settings.showInteraction,
                  onChanged: (v) async => await settings.setShowInteraction(v),
                )),
            _buildDivider(isDark),
            // ── الغياب التلقائي بعد انتهاء الحصة (spec 046) ──
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.event_busy_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'تسجيل الغياب تلقائيًا بعد انتهاء الحصة',
                  subtitle: settings.autoAbsentEnabled.value
                      ? 'الطلاب اللي ما اتمسحوش ومالهمش سجل بعد نهاية الحصة + المهلة يتسجّلوا "غائب" (للمجموعات اللي جدولها فيه وقت نهاية)'
                      : 'معطّل — الغياب بيتسجّل يدويًا',
                  rxValue: settings.autoAbsentEnabled,
                  onChanged: (v) async =>
                      await settings.setAutoAbsentEnabled(v),
                )),
            Obx(() => settings.autoAbsentEnabled.value
                ? Column(children: [
                    _buildDivider(isDark),
                    _buildDropdownTile<int>(
                      context,
                      isDark,
                      icon: Icons.hourglass_bottom_rounded,
                      iconColor: const Color(0xFFEF4444),
                      title: 'مهلة بعد نهاية الحصة',
                      value: settings.autoAbsentGraceMinutes.value,
                      items: const [0, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180]
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                    m == 0 ? 'فورًا بعد النهاية' : '$m دقيقة'),
                              ))
                          .toList(),
                      onChanged: (m) async {
                        if (m != null) {
                          await settings.setAutoAbsentGraceMinutes(m);
                          ToastHelper.success('تم التغيير',
                              title: 'مهلة الغياب التلقائي');
                        }
                      },
                    ),
                  ])
                : const SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 14),
        _buildSection(
          context,
          isDark,
          title: 'ماسح QR',
          icon: Icons.qr_code_scanner_rounded,
          color: const Color(0xFF0EA5E9),
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
                  onChanged: (v) async => await settings.setHideQrInPayment(v),
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
            // ── قارئ باركود خارجي (HID) — spec 027 ──
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.barcode_reader,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'قارئ باركود خارجي',
                  subtitle: settings.hardwareScannerEnabled.value
                      ? 'امسح كروت الطلاب بجهاز قارئ باركود موصول بالموبايل (سلكي/بلوتوث)'
                      : 'الجهاز لازم يقرا QR ويشتغل كلوحة مفاتيح — والتطبيق مفتوح على شاشة الحضور/الدفع وقت المسح',
                  rxValue: settings.hardwareScannerEnabled,
                  onChanged: (v) async =>
                      await settings.setHardwareScannerEnabled(v),
                )),
            Obx(() => settings.hardwareScannerEnabled.value
                ? const HardwareScannerTestTile()
                : const SizedBox.shrink()),
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
                                child: Text(
                                    m == 0 ? 'فورًا بعد البداية' : '$m دقيقة'),
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
      ],
    );
  }
}

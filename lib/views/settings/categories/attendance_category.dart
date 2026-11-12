part of '../settings_page.dart';

// spec 051 — فئة «الحضور والحصص» بتصميم السبورة والكروت:
// سبورة بحالة الأدوات، كروت تشغيل/إيقاف، وإعدادات فرعية بتظهر لما الأصل يشتغل.

class _AttendanceCategoryPage extends StatelessWidget {
  const _AttendanceCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _tk(isDark);
    final SettingsController settings = Get.find();
    const blue = Color(0xFF3B82F6);
    const sky = Color(0xFF0EA5E9);
    const amber = Color(0xFFF59E0B);
    const red = Color(0xFFEF4444);
    const gap = SizedBox(height: AppSpace.lg);
    String shown(bool v) => v ? 'ظاهر' : 'مخفي';
    return _CategoryScaffold(
      title: 'الحضور والحصص',
      highlightId: highlightId,
      children: [
        // ── السبورة: حالة أدوات الحصة ──
        Obx(() => _boardSummary(
              t,
              icon: Icons.fact_check_rounded,
              title: 'الحضور والحصص',
              subtitle: 'اللي بيظهر في ورقة حضور اليوم',
              stats: [
                (label: 'الواجب', value: shown(settings.showHomework.value)),
                (
                  label: 'التسميع',
                  value: settings.showRecitation.value
                      ? 'ظاهر (من ${settings.recitationMax.value})'
                      : 'مخفي'
                ),
                (
                  label: 'التفاعل',
                  value: shown(settings.showInteraction.value)
                ),
                (
                  label: 'الغياب التلقائي',
                  value: settings.autoAbsentEnabled.value ? 'شغّال' : 'مقفول'
                ),
              ],
            )),
        gap,
        // ── ورقة الحضور: كروت تشغيل/إيقاف ──
        _plainSectionBlock(
          t,
          'ورقة الحضور',
          Icons.fact_check_rounded,
          blue,
          _cardGrid([
            // ── تنبيه المتأخر في الدفع بشاشة الحضور (spec 029) ──
            _toggleCard(
              t,
              rx: settings.attendanceOverdueWarning,
              icon: Icons.warning_amber_rounded,
              color: amber,
              title: 'تنبيه المتأخر في شاشة الحضور',
              sharedKey: SETTING_ATTENDANCE_OVERDUE_WARNING,
              onHint: 'شريط تحذير جنب اسم الطالب المتأخر وقت تسجيل حضوره',
              offHint: 'معطّل — مفيش تحذير دفع في شاشة الحضور',
              set: (v) async => await settings.setAttendanceOverdueWarning(v),
            ),
            // ── أدوات الحصة: واجب / تسميع / تفاعل ──
            _toggleCard(
              t,
              rx: settings.showHomework,
              icon: Icons.menu_book_rounded,
              color: blue,
              title: 'الواجب في حضور اليوم',
              sharedKey: SETTING_SHOW_HOMEWORK,
              onHint: 'ظاهر — تبويب الواجب في ورقة حضور اليوم',
              offHint: 'مخفي — لا يظهر تسجيل الواجب',
              set: (v) async => await settings.setShowHomework(v),
            ),
            _toggleCard(
              t,
              rx: settings.showRecitation,
              icon: Icons.record_voice_over_rounded,
              color: sky,
              title: 'درجة التسميع',
              sharedKey: SETTING_SHOW_RECITATION,
              onHint: 'ظاهرة — داخل تبويب الواجب',
              offHint: 'مخفية — لا يظهر تسجيل التسميع',
              set: (v) async => await settings.setShowRecitation(v),
            ),
            _toggleCard(
              t,
              rx: settings.showInteraction,
              icon: Icons.emoji_emotions_rounded,
              color: Colors.deepPurple,
              title: 'تفاعل الطالب',
              sharedKey: SETTING_SHOW_INTERACTION,
              onHint: 'ظاهر — إيموجي التفاعل في ورقة الحضور',
              offHint: 'مخفي — لا يظهر تسجيل التفاعل',
              set: (v) async => await settings.setShowInteraction(v),
            ),
            // ── طالب ضيف في حصة مجموعة تانية (تعويضية/بديلة) ──
            _toggleCard(
              t,
              rx: settings.allowGuestStudents,
              icon: Icons.person_add_alt_1_rounded,
              color: sky,
              title: 'إضافة طلاب ضيوف للحصة',
              sharedKey: SETTING_ALLOW_GUEST_STUDENTS,
              onHint:
                  'زر "إضافة ضيف" لطالب من مجموعة تانية بيحضر حصة تعويضية',
              offHint: 'معطّل — الحضور لطلاب المجموعة بس',
              set: (v) async => await settings.setAllowGuestStudents(v),
            ),
            // ── الغياب التلقائي بعد انتهاء الحصة (spec 046) ──
            _toggleCard(
              t,
              rx: settings.autoAbsentEnabled,
              icon: Icons.event_busy_rounded,
              color: red,
              title: 'تسجيل الغياب تلقائيًا بعد انتهاء الحصة',
              sharedKey: SETTING_AUTO_ABSENT_ENABLED,
              onHint:
                  'اللي ما اتمسحش بعد نهاية الحصة + المهلة يتسجّل "غائب" (للمجموعات اللي جدولها فيه وقت نهاية)',
              offHint: 'معطّل — الغياب بيتسجّل يدويًا',
              set: (v) async => await settings.setAutoAbsentEnabled(v),
            ),
          ]),
        ),
        // ── إعدادات فرعية: بتظهر لما الأصل يشتغل ──
        Obx(() {
          final rec = settings.showRecitation.value;
          final auto = settings.autoAbsentEnabled.value;
          if (!rec && !auto) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: _settingsCard(
              t,
              Column(children: [
                if (rec)
                  // الدرجة العظمى للتسميع (مش لازم تكون 10)
                  _buildDropdownTile<int>(
                    context,
                    isDark,
                    icon: Icons.stairs_rounded,
                    iconColor: sky,
                    title: 'الدرجة العظمى للتسميع',
                    sharedKey: SETTING_RECITATION_MAX,
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
                if (rec && auto) _buildDivider(isDark),
                if (auto)
                  _buildDropdownTile<int>(
                    context,
                    isDark,
                    icon: Icons.hourglass_bottom_rounded,
                    iconColor: red,
                    title: 'مهلة بعد نهاية الحصة',
                    sharedKey: SETTING_AUTO_ABSENT_GRACE_MINUTES,
                    value: settings.autoAbsentGraceMinutes.value,
                    items: const [0, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180]
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child:
                                  Text(m == 0 ? 'فورًا بعد النهاية' : '$m دقيقة'),
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
              ]),
            ),
          );
        }),
        gap,
        // ── ماسح QR ──
        _plainSectionBlock(
          t,
          'ماسح QR',
          Icons.qr_code_scanner_rounded,
          sky,
          _cardGrid([
            _toggleCard(
              t,
              rx: settings.hideQrInPayment,
              icon: Icons.payments_rounded,
              color: sky,
              title: 'إخفاء ماسح QR في الدفع',
              onHint: 'شاشة "تسجيل دفع" هتفتح على البحث اليدوي مباشرة',
              offHint: 'مناسب لو مش بتطبع أكواد QR للطلاب',
              set: (v) async => await settings.setHideQrInPayment(v),
            ),
            _toggleCard(
              t,
              rx: settings.hideQrInAttendance,
              icon: Icons.event_available_rounded,
              color: sky,
              title: 'إخفاء ماسح QR في الحضور',
              onHint: 'شاشة تسجيل الحضور هتفتح على البحث اليدوي مباشرة',
              offHint: 'مناسب لو مش بتطبع أكواد QR للطلاب',
              set: (v) async => await settings.setHideQrInAttendance(v),
            ),
            // ── قارئ باركود خارجي (HID) — spec 027 ──
            _toggleCard(
              t,
              rx: settings.hardwareScannerEnabled,
              icon: Icons.barcode_reader,
              color: sky,
              title: 'قارئ باركود خارجي',
              onHint: 'امسح كروت الطلاب بقارئ موصول بالموبايل (سلكي/بلوتوث)',
              offHint:
                  'الجهاز لازم يشتغل كلوحة مفاتيح والتطبيق مفتوح على الحضور/الدفع',
              set: (v) async => await settings.setHardwareScannerEnabled(v),
            ),
            // ── تسجيل "متأخر" تلقائيًا عبر QR (spec 011) ──
            _toggleCard(
              t,
              rx: settings.qrAutoLateEnabled,
              icon: Icons.schedule_rounded,
              color: amber,
              title: 'تسجيل "متأخر" تلقائيًا عبر QR',
              sharedKey: SETTING_QR_AUTO_LATE_ENABLED,
              onHint: 'اللي يتمسح بعد المهلة من بداية الحصة يتسجّل "متأخر"',
              offHint: 'معطّل — المسح يسجّل "حاضر" دايمًا',
              set: (v) async => await settings.setQrAutoLateEnabled(v),
            ),
          ]),
        ),
        Obx(() {
          final hw = settings.hardwareScannerEnabled.value;
          final late = settings.qrAutoLateEnabled.value;
          if (!hw && !late) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: _settingsCard(
              t,
              Column(children: [
                if (hw) const HardwareScannerTestTile(),
                if (hw && late) _buildDivider(isDark),
                if (late)
                  _buildDropdownTile<int>(
                    context,
                    isDark,
                    icon: Icons.hourglass_bottom_rounded,
                    iconColor: amber,
                    title: 'مهلة التأخير (دقائق)',
                    sharedKey: SETTING_LATE_GRACE_MINUTES,
                    value: settings.lateGraceMinutes.value,
                    items: const [0, 5, 10, 15, 20, 30, 45, 60]
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child:
                                  Text(m == 0 ? 'فورًا بعد البداية' : '$m دقيقة'),
                            ))
                        .toList(),
                    onChanged: (m) async {
                      if (m != null) {
                        await settings.setLateGraceMinutes(m);
                        ToastHelper.success('تم التغيير', title: 'مهلة التأخير');
                      }
                    },
                  ),
              ]),
            ),
          );
        }),
      ],
    );
  }
}

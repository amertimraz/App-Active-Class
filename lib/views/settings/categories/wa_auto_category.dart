part of '../settings_page.dart';

// spec 056 — صفحة «إرسال تلقائي» الكاملة: التفعيل، الموافقات، الحصة، آخر الرسايل.

const _kWaFailReasonsAr = <String, String>{
  'no_consent': 'مفيش موافقة من ولي الأمر',
  'stopped': 'ولي الأمر أوقف الرسايل',
  'no_quota': 'خلصت حصة الرسايل',
  'invalid_number': 'رقم ولي الأمر غير صالح',
  'not_on_whatsapp': 'الرقم مش على واتساب',
  'recipient_not_allowed': 'الرقم غير مسموح له بالاستلام',
  'template_error': 'مشكلة في قالب الرسالة',
  'template_vars': 'بيانات الرسالة ناقصة',
  'provider_error': 'تعذّر الإرسال، حاول لاحقًا',
  'provider_auth': 'الخدمة متوقفة مؤقتًا',
  'network': 'مشكلة اتصال',
  'cancelled': 'اتلغت',
  'disabled': 'الإرسال التلقائي مقفول',
};

const _kWaStatusAr = <String, (String, Color, IconData)>{
  'pending': ('في الانتظار', Color(0xFFF59E0B), Icons.schedule_rounded),
  'sending': ('بيتبعت', Color(0xFFF59E0B), Icons.schedule_rounded),
  'sent': ('اتبعتت', Color(0xFF3B82F6), Icons.done_rounded),
  'delivered': ('وصلت', Color(0xFF16A34A), Icons.done_all_rounded),
  'read': ('اتقرأت', Color(0xFF16A34A), Icons.done_all_rounded),
  'failed': ('فشلت', Color(0xFFEF4444), Icons.error_outline_rounded),
  'blocked': ('ما اتبعتتش', Color(0xFF9CA3AF), Icons.block_rounded),
};

const _kWaKindAr = <String, String>{
  'absence': 'تنبيه غياب',
  'late_payment': 'تذكير دفع',
  'receipt': 'إيصال دفعة',
  'test': 'رسالة اختبار',
};

class _WaAutoCategoryPage extends StatefulWidget {
  const _WaAutoCategoryPage();

  @override
  State<_WaAutoCategoryPage> createState() => _WaAutoCategoryPageState();
}

class _WaAutoCategoryPageState extends State<_WaAutoCategoryPage> {
  late Future<({int remaining, int limit})?> _quota;
  late Future<List<Map<String, dynamic>>> _recent;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _quota = WhatsAppAutoService.instance.loadQuota().catchError((_) => null);
    _recent = WhatsAppAutoService.instance
        .loadRecent()
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> _toggleEnabled(SettingsController settings, bool v) async {
    if (v) {
      final ok = await Get.dialog<bool>(AlertDialog(
        title: const Text('تفعيل الإرسال التلقائي'),
        content: const Text(
            'الرسايل هتتبعت لأولياء الأمور من رقم واتساب الأكاديمية '
            '(مش من رقمك). لازم تسجّل موافقة ولي الأمر الأول، '
            'وفيه حصة رسايل شهرية، ولو ولي الأمر رد بكلمة «إيقاف» '
            'الإرسال له بيقف فورًا. أزرار واتساب اليدوية هتفضل زي ما هي.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Get.back(result: true),
              child: const Text('فعّل')),
        ],
      ));
      if (ok != true) return;
    }
    await settings.setWaAutoEnabled(v);
    final synced = await WhatsAppAutoService.instance.syncSettings();
    if (!synced) {
      ToastHelper.error(
          'اتحفظ على جهازك بس — اتأكد من الإنترنت وتسجيل الدخول عشان يشتغل');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final SettingsController settings = Get.find();
    const green = Color(0xFF25D366);
    return _CategoryScaffold(
      title: 'إرسال تلقائي',
      children: [
        _buildSection(
          context,
          isDark,
          title: 'التفعيل',
          icon: Icons.bolt_rounded,
          color: green,
          children: [
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.send_rounded,
                  iconColor: green,
                  title: 'إرسال واتساب تلقائي',
                  subtitle: settings.waAutoEnabled.value
                      ? 'مفعّل — الرسايل بتتبعت من رقم الأكاديمية بدون ما تفتح واتساب'
                      : 'مقفول — بتبعت يدويًا من أزرار واتساب زي قبل',
                  rxValue: settings.waAutoEnabled,
                  onChanged: (v) => _toggleEnabled(settings, v),
                )),
            _buildDivider(isDark),
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.event_busy_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'تنبيه الغياب تلقائيًا',
                  subtitle: settings.waAutoAbsence.value
                      ? 'مفعّل — يوصل ولي الأمر رسالة أول ما الطالب يتسجّل غايب'
                      : 'مقفول — مفيش رسالة غياب تلقائية',
                  rxValue: settings.waAutoAbsence,
                  onChanged: (v) async {
                    await settings.setWaAutoAbsence(v);
                    await WhatsAppAutoService.instance.syncSettings();
                  },
                )),
          ],
        ),
        _buildSection(
          context,
          isDark,
          title: 'أولياء الأمور',
          icon: Icons.how_to_reg_rounded,
          color: const Color(0xFF16A34A),
          children: [
            _buildNavTile(
              context,
              isDark,
              icon: Icons.how_to_reg_rounded,
              iconColor: const Color(0xFF16A34A),
              title: 'موافقات أولياء الأمور',
              subtitle: 'سجّل موافقة أولياء الأمور — بدونها مفيش رسالة بتتبعت',
              onTap: () async {
                await Get.to(() => const WaConsentPage());
                if (mounted) setState(_reload);
              },
            ),
          ],
        ),
        _buildSection(
          context,
          isDark,
          title: 'الحصة الشهرية',
          icon: Icons.data_usage_rounded,
          color: const Color(0xFF3B82F6),
          children: [
            FutureBuilder<({int remaining, int limit})?>(
              future: _quota,
              builder: (context, snap) {
                final q = snap.data;
                final low = q != null && q.remaining < q.limit * 0.2;
                return _buildInfoLine(
                  context,
                  isDark,
                  icon: Icons.mark_chat_read_rounded,
                  color: low ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                  title: q == null
                      ? 'هتظهر بعد أول رسالة تلقائية'
                      : 'المتبقي ${q.remaining} من ${q.limit} رسالة',
                  subtitle: low
                      ? 'الحصة قربت تخلص — بعدها بترجع للإرسال اليدوي'
                      : 'بتتجدد أول كل شهر',
                );
              },
            ),
          ],
        ),
        _buildSection(
          context,
          isDark,
          title: 'آخر الرسايل',
          icon: Icons.history_rounded,
          color: const Color(0xFF8B5CF6),
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _recent,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return _buildInfoLine(
                    context,
                    isDark,
                    icon: Icons.inbox_rounded,
                    color: const Color(0xFF9CA3AF),
                    title: 'مفيش رسايل لسه',
                    subtitle: 'أول ما تتبعت رسالة تلقائية هتظهر هنا بحالتها',
                  );
                }
                return Column(children: [
                  for (final r in rows) _recentRow(context, isDark, r),
                ]);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _recentRow(BuildContext context, bool isDark, Map<String, dynamic> r) {
    final st = _kWaStatusAr[r['status']] ??
        ('—', const Color(0xFF9CA3AF), Icons.help_outline_rounded);
    final reason = _kWaFailReasonsAr[r['fail_reason']];
    final when = DateTime.tryParse('${r['created_at']}')?.toLocal();
    final whenStr = when == null
        ? ''
        : '${when.day}/${when.month} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return _buildInfoLine(
      context,
      isDark,
      icon: st.$3,
      color: st.$2,
      title:
          '${_kWaKindAr[r['kind']] ?? r['kind']} — ${r['student_name'] ?? ''}',
      subtitle: '${st.$1}${reason != null ? ' · $reason' : ''}  ·  $whenStr',
    );
  }
}

/// سطر معلومات بسيط (أيقونة + عنوان + وصف) بنفس شكل صفوف الإعدادات.
Widget _buildInfoLine(
  BuildContext context,
  bool isDark, {
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
}) {
  final t = _tk(isDark);
  return _tileRow(
    t,
    icon: icon,
    iconColor: color,
    title: title,
    subtitle: subtitle,
  );
}

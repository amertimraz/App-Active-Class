part of '../settings_page.dart';

// spec 051 — بلاطة متابعة أولياء الأمور (نقل حرفي)

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
    if (mounted)
      setState(() {
        _slug = slug;
        _loading = false;
      });
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
            final Color c =
                active ? const Color(0xFF10B981) : const Color(0xFFEF4444);
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
                label:
                    const Text('مشاركة', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          // طريقة دخول ولي الأمر: كود + آخر 4 أرقام (أأمن) أو كود فقط.
          Obx(() {
            final cfg = Get.find<SettingsController>();
            final codeOnly = cfg.portalCodeOnly.value;
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('الدخول بالكود فقط',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              subtitle: Text(
                  codeOnly
                      ? 'ولي الأمر بيدخل بكود الطالب بس (أسهل، لكن أي حد يعرف الكود يشوف بيانات الطالب).'
                      : 'ولي الأمر بيدخل بكود الطالب + آخر 4 أرقام من تليفونه (الأأمن).',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
              value: codeOnly,
              onChanged: (v) async {
                if (v) {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('الدخول بالكود فقط',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800)),
                      content: const Text(
                          'بدون آخر 4 أرقام، أي حد يعرف (أو يخمّن) كود الطالب يقدر يشوف حضوره ومدفوعاته ودرجاته. '
                          'لو أكواد طلابك متسلسلة (مثل 1، 2، 3) ده بيسهّل التخمين.\n\nمتأكد؟',
                          style: TextStyle(fontFamily: 'Cairo')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('تفعيل')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                }
                final done = await cfg.setPortalCodeOnly(v);
                if (done) {
                  ToastHelper.success(v
                      ? 'ولي الأمر بيدخل بالكود فقط دلوقتي'
                      : 'رجع الدخول بالكود + آخر 4 أرقام');
                } else {
                  ToastHelper.error(
                      'تعذر تغيير طريقة الدخول — تأكد من الإنترنت وحاول تاني');
                }
              },
            );
          }),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _publishing ? null : _publishAll,
              icon: _publishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
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

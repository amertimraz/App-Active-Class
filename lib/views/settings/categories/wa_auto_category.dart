part of '../settings_page.dart';

// spec 056 — صفحة «إرسال تلقائي» الكاملة بتصميم «السبورة والطباشير»:
// سبورة الجاهزية (مفتاح التفعيل + 4 خطوات)، كروت أنواع الرسايل، الموافقات،
// رقمك، عدّاد الرصيد، آخر الرسايل.

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

typedef _WaQuota = ({int remaining, int limit, int used, int extra});

// أخضر/داكن ثابتين لخطوات السبورة (فوق خلفية داكنة في الوضعين).
const _kWaDone = Color(0xFF4AD6A3);
const _kWaDoneInk = Color(0xFF062B20);

class _WaAutoCategoryPage extends StatefulWidget {
  const _WaAutoCategoryPage();

  @override
  State<_WaAutoCategoryPage> createState() => _WaAutoCategoryPageState();
}

class _WaAutoCategoryPageState extends State<_WaAutoCategoryPage> {
  late Future<_WaQuota?> _quota;
  late Future<List<Map<String, dynamic>>> _recent;
  late Future<Map<int, WaConsent>> _consents;

  /// الرصيد وعدد الموافقات للسبورة (null لو فشل التحميل).
  late Future<List<Object?>> _ready;
  late final TextEditingController _phone;
  final _phoneKey = GlobalKey();
  final _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final st = Get.find<SettingsController>();
    _phone = TextEditingController(text: st.teacherPhone.value);
    _reload();
  }

  @override
  void dispose() {
    _savePhone();
    _phone.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  /// يحفظ رقم المدرس (بيظهر في الرسايل لأولياء الأمور للتواصل).
  void _savePhone() {
    final st = Get.find<SettingsController>();
    if (st.teacherPhone.value == _phone.text.trim()) return;
    st.setTeacherPhone(_phone.text.trim());
    st.saveTeacherInfo();
  }

  void _reload() {
    _quota = WhatsAppAutoService.instance.loadQuota();
    _recent = WhatsAppAutoService.instance
        .loadRecent()
        .catchError((_) => <Map<String, dynamic>>[]);
    _consents = WhatsAppAutoService.instance.loadConsents();
    _ready = Future.wait<Object?>([
      _quota.then<Object?>((v) => v, onError: (_) => null),
      _consents.then<Object?>((v) => v, onError: (_) => null),
    ]);
  }

  Future<void> _openConsents() async {
    await Get.to(() => const WaConsentPage());
    if (mounted) setState(_reload);
  }

  Future<void> _openLogin() async {
    await Get.to(() => const AccountTeamScreen());
    if (mounted) setState(_reload);
  }

  Future<void> _goToPhone() async {
    final ctx = _phoneKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 250), alignment: 0.2);
    }
    _phoneFocus.requestFocus();
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
    if (v) WhatsAppAutoService.instance.start();
    final synced = await WhatsAppAutoService.instance.syncSettings();
    if (!synced) {
      ToastHelper.error(
          'اتحفظ على جهازك بس — اتأكد من الإنترنت وتسجيل الدخول عشان يشتغل');
    }
  }

  // ───────────────── السبورة: التفعيل + الخطوات ─────────────────

  Widget _hero(BuildContext context, bool isDark, SettingsController settings) {
    final t = _tk(isDark);
    return Material(
      color: t.board,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.board),
        side: BorderSide(color: t.boardLine),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
        child: FutureBuilder<List<Object?>>(
          future: _ready,
          builder: (context, snap) {
            final loading = snap.connectionState != ConnectionState.done;
            final quota = snap.data?[0] as _WaQuota?;
            final consents = snap.data?[1] as Map<int, WaConsent>?;
            return Obx(() {
              final enabled = settings.waAutoEnabled.value;
              final granted = consents == null
                  ? 0
                  : consents.values
                      .where((c) => c == WaConsent.granted)
                      .length;
              final phoneOk =
                  waTeacherPhoneText(_phone.text, settings.countryDial.value)
                      .isNotEmpty;
              final quotaOk = quota != null && quota.remaining > 0;
              final oks = [enabled, granted > 0, phoneOk, quotaOk];
              final done = oks.where((e) => e).length;
              final ready = done == oks.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── مفتاح التفعيل ──
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إرسال واتساب تلقائي',
                              style:
                                  AppType.title.copyWith(color: t.boardInk)),
                          Text(
                            enabled
                                ? 'شغّال — من رقم الأكاديمية بدون ما تفتح واتساب'
                                : 'مقفول — بتبعت يدويًا من أزرار واتساب',
                            style: AppType.caption
                                .copyWith(color: t.boardInkSoft),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: enabled,
                      onChanged: (v) => _toggleEnabled(settings, v),
                      thumbColor: WidgetStatePropertyAll(
                          enabled ? _kWaDoneInk : t.boardInkSoft),
                      trackColor: WidgetStateProperty.resolveWith((s) =>
                          s.contains(WidgetState.selected)
                              ? _kWaDone
                              : t.boardLine),
                      trackOutlineColor:
                          const WidgetStatePropertyAll(Colors.transparent),
                    ),
                  ]),
                  const SizedBox(height: AppSpace.lg),
                  // ── حالة الجاهزية ──
                  Row(children: [
                    Icon(
                        ready
                            ? Icons.verified_rounded
                            : Icons.pending_actions_rounded,
                        size: 18,
                        color: ready ? _kWaDone : t.chalk),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        loading
                            ? 'بنراجع الخطوات…'
                            : ready
                                ? 'جاهز — الرسايل بتتبعت لوحدها'
                                : 'فاضل ${oks.length - done} ${oks.length - done == 1 ? 'خطوة' : 'خطوات'} عشان الإرسال يشتغل',
                        style: AppType.label.copyWith(color: t.boardInk),
                      ),
                    ),
                    Text('$done/${oks.length}',
                        style:
                            AppType.label.copyWith(color: t.boardInkSoft)),
                  ]),
                  const SizedBox(height: AppSpace.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: loading ? null : done / oks.length,
                      minHeight: 8,
                      backgroundColor: t.boardLine,
                      valueColor: AlwaysStoppedAnimation(
                          ready ? _kWaDone : t.chalk),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text('جاهزية الإرسال — اضغط على أي خطوة وهتوديك لها',
                      style:
                          AppType.caption.copyWith(color: t.boardInkSoft)),
                  const SizedBox(height: AppSpace.sm),
                  // ── الخطوات الأربع ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroStep(t,
                          ok: oks[0],
                          icon: Icons.power_settings_new_rounded,
                          label: 'التفعيل',
                          sub: enabled ? 'شغّال' : 'مقفول',
                          onTap: () => _toggleEnabled(settings, !enabled)),
                      _heroStep(t,
                          ok: oks[1],
                          icon: Icons.how_to_reg_rounded,
                          label: 'الموافقات',
                          sub: consents == null
                              ? 'غير متاح'
                              : granted > 0
                                  ? '$granted طالب'
                                  : 'لسه',
                          onTap: _openConsents),
                      _heroStep(t,
                          ok: oks[2],
                          icon: Icons.phone_rounded,
                          label: 'رقمك',
                          sub: phoneOk ? 'مكتوب' : 'ناقص',
                          onTap: _goToPhone),
                      _heroStep(t,
                          ok: oks[3],
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'الرصيد',
                          sub: quota == null
                              ? 'سجّل دخول'
                              : '${quota.remaining} رسالة',
                          onTap: quota == null
                              ? _openLogin
                              : () => setState(_reload)),
                    ],
                  ),
                ],
              );
            });
          },
        ),
      ),
    );
  }

  Widget _heroStep(
    AppTokens t, {
    required bool ok,
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ok ? _kWaDone : Colors.transparent,
                border: Border.all(
                    color: ok ? _kWaDone : t.boardInkSoft.withValues(alpha: 0.7),
                    width: 1.5),
              ),
              child: Icon(ok ? Icons.check_rounded : icon,
                  size: 22, color: ok ? _kWaDoneInk : t.boardInkSoft),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(
                    color: t.boardInk, fontWeight: FontWeight.w700)),
            Text(sub,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption.copyWith(color: t.boardInkSoft)),
          ]),
        ),
      ),
    );
  }

  // ───────────────── أنواع الرسايل: 3 كروت ─────────────────

  Widget _plainSection(AppTokens t, String title, IconData icon, Color color,
      Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpace.sm),
          child: _sectionHeader(t, title, icon, color),
        ),
        child,
      ],
    );
  }

  Widget _typeCard(
    AppTokens t, {
    required RxBool rx,
    required IconData icon,
    required Color color,
    required String title,
    required Future<void> Function(bool) set,
  }) {
    return Expanded(
      child: Obx(() {
        final on = rx.value;
        return Semantics(
          button: true,
          toggled: on,
          label: title,
          child: Material(
            color: on ? color.withValues(alpha: 0.13) : t.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.panel),
              side: BorderSide(color: on ? color : t.line, width: on ? 1.6 : 1),
            ),
            child: InkWell(
              onTap: () => set(!on),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: AppSpace.md),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? color : color.withValues(alpha: 0.12),
                    ),
                    child: Icon(icon,
                        size: 22, color: on ? Colors.white : color),
                  ),
                  const SizedBox(height: 8),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: AppType.label.copyWith(color: t.ink)),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 14, color: on ? color : t.inkFaint),
                    const SizedBox(width: 4),
                    Text(on ? 'شغّال' : 'مقفول',
                        style: AppType.caption.copyWith(
                            color: on ? color : t.inkFaint)),
                  ]),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ───────────────── الموافقات ─────────────────

  Widget _consentsCard(AppTokens t) {
    return _settingsCard(
      t,
      InkWell(
        onTap: _openConsents,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: FutureBuilder<Map<int, WaConsent>>(
            future: _consents,
            builder: (context, snap) {
              final done = snap.connectionState == ConnectionState.done;
              final granted = (snap.data ?? const <int, WaConsent>{})
                  .values
                  .where((c) => c == WaConsent.granted)
                  .length;
              return Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.positiveSoft,
                    border: Border.all(color: t.positive, width: 1.5),
                  ),
                  child: Text(done && !snap.hasError ? '$granted' : '—',
                      style: AppType.title.copyWith(color: t.positive)),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('موافقات أولياء الأمور',
                          style: AppType.label.copyWith(color: t.ink)),
                      const SizedBox(height: 2),
                      Text(
                        snap.hasError
                            ? 'مش قادر أقرا الموافقات — اتأكد من تسجيل الدخول'
                            : granted > 0
                                ? '$granted طالب موافق — اضغط لتسجيل المزيد'
                                : 'سجّل موافقة أولياء الأمور — بدونها مفيش رسالة بتتبعت',
                        style: AppType.caption.copyWith(color: t.inkFaint),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: t.inkFaint),
              ]);
            },
          ),
        ),
      ),
    );
  }

  // ───────────────── رقمك ─────────────────

  Widget _phoneCard(BuildContext context, AppTokens t, SettingsController settings) {
    final shown =
        waTeacherPhoneText(_phone.text, settings.countryDial.value);
    final ok = shown.isNotEmpty;
    return _settingsCard(
      t,
      Padding(
        key: _phoneKey,
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'الرسايل بتطلع من رقم الأكاديمية، فاكتب رقم موبايلك هنا عشان يظهر لولي الأمر '
                '(📞 للتواصل) ويقدر يكلّمك.',
                style: AppType.caption.copyWith(color: t.inkSoft)),
            const SizedBox(height: AppSpace.md),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _phone,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                style: AppType.label.copyWith(color: t.ink),
                onChanged: (_) => setState(() {}),
                onEditingComplete: () {
                  _savePhone();
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  labelText: 'رقم موبايلك',
                  hintText: '01012345678',
                  prefixIcon: Icon(Icons.phone_rounded, color: t.inkFaint),
                  filled: true,
                  fillColor: t.page,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    borderSide: BorderSide(color: t.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    borderSide: BorderSide(color: t.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    borderSide: BorderSide(color: t.brand, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ok ? t.positiveSoft : t.dangerSoft,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    size: 16, color: ok ? t.positive : t.danger),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    ok
                        ? 'هيظهر في الرسايل: $shown'
                        : 'مفيش رقم صالح — هيظهر «غير متاح» في الرسايل',
                    style: AppType.caption
                        .copyWith(color: ok ? t.positive : t.danger),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────── الرصيد ─────────────────

  Widget _balanceCard(BuildContext context, AppTokens t) {
    return _settingsCard(
      t,
      Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: FutureBuilder<_WaQuota?>(
          future: _quota,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpace.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final q = snap.data;
            if (snap.hasError || q == null) {
              final err = snap.error;
              final detail = err is WaAutoException
                  ? err.message
                  : (err == null ? 'اتأكد من الإنترنت وتسجيل الدخول' : '$err');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.cloud_off_rounded, color: t.danger, size: 22),
                    const SizedBox(width: AppSpace.sm),
                    Text('مش قادر أقرا الرصيد',
                        style: AppType.label.copyWith(color: t.danger)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      detail.length > 140
                          ? '${detail.substring(0, 140)}…'
                          : detail,
                      style: AppType.caption.copyWith(color: t.inkFaint)),
                  const SizedBox(height: AppSpace.sm),
                  Wrap(spacing: 8, children: [
                    if (err is WaAutoException)
                      OutlinedButton.icon(
                        onPressed: _openLogin,
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('تسجيل الدخول'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => setState(_reload),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ]),
                ],
              );
            }
            final low = q.remaining <= (q.limit * 0.2).ceil();
            final color = low ? t.danger : t.brand;
            final frac = q.limit == 0 ? 1.0 : (q.used / q.limit).clamp(0.0, 1.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${q.remaining}',
                        style: AppType.figure
                            .copyWith(fontSize: 34, color: color)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('رسالة متبقية',
                          style: AppType.label.copyWith(color: t.inkSoft)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 10,
                    backgroundColor: t.line,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Row(children: [
                  Expanded(
                    child: Text('المجاني: ${q.used} من ${q.limit} · بيتجدد أول كل شهر',
                        style: AppType.caption.copyWith(color: t.inkFaint)),
                  ),
                ]),
                if (q.extra > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('رصيد إضافي: ${q.extra} رسالة — بيتخصم بعد ما المجاني يخلص',
                        style: AppType.caption.copyWith(color: t.positive)),
                  ),
                if (low)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('الرصيد قرّب يخلص — بعدها الإرسال التلقائي بيقف',
                        style: AppType.caption.copyWith(color: t.danger)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _tk(isDark);
    final SettingsController settings = Get.find();
    const gap = SizedBox(height: AppSpace.lg);
    return _CategoryScaffold(
      title: 'إرسال تلقائي',
      children: [
        _hero(context, isDark, settings),
        gap,
        _plainSection(
          t,
          'أنواع الرسايل التلقائية',
          Icons.tune_rounded,
          const Color(0xFF8B5CF6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _typeCard(t,
                    rx: settings.waAutoAbsence,
                    icon: Icons.event_busy_rounded,
                    color: const Color(0xFFEF4444),
                    title: 'تنبيه الغياب',
                    set: (v) async {
                      await settings.setWaAutoAbsence(v);
                      await WhatsAppAutoService.instance.syncSettings();
                    }),
                const SizedBox(width: AppSpace.sm),
                _typeCard(t,
                    rx: settings.waAutoReceipt,
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF16A34A),
                    title: 'إيصال الدفعة',
                    set: (v) async {
                      await settings.setWaAutoReceipt(v);
                      await WhatsAppAutoService.instance.syncSettings();
                    }),
                const SizedBox(width: AppSpace.sm),
                _typeCard(t,
                    rx: settings.waAutoLate,
                    icon: Icons.payments_rounded,
                    color: const Color(0xFFF59E0B),
                    title: 'تذكير تأخر الدفع',
                    set: (v) async {
                      await settings.setWaAutoLate(v);
                      await WhatsAppAutoService.instance.syncSettings();
                    }),
              ],
            ),
          ),
        ),
        gap,
        _plainSection(t, 'أولياء الأمور', Icons.how_to_reg_rounded,
            const Color(0xFF16A34A), _consentsCard(t)),
        gap,
        _plainSection(t, 'رقمك على الرسايل', Icons.phone_in_talk_rounded,
            const Color(0xFF0EA5E9), _phoneCard(context, t, settings)),
        gap,
        _plainSection(t, 'رصيد الرسايل', Icons.account_balance_wallet_rounded,
            const Color(0xFF3B82F6), _balanceCard(context, t)),
        gap,
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

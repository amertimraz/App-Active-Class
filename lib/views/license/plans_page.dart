// lib/views/license/plans_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/models/plan_config_model.dart';
import 'package:active_class/views/license/activation_page.dart';
import 'package:active_class/views/auth/login_screen.dart';

const String _kSupportPhone = '201096066818';

Future<void> _openPlanWhatsApp(PlanConfigModel plan) async {
  final message =
      'مرحبًا، أنا مدرس بستخدم تطبيق Active Class وعايز أستفسر عن باقة ${plan.nameAr}.';
  final uri = Uri.parse(
      'https://wa.me/$_kSupportPhone?text=${Uri.encodeComponent(message)}');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});
  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  String _selectedPlan = 'pro';
  bool _showForm = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  String _paymentMethod = 'نقدي';
  bool _loading = false;
  String? _error;
  bool _sent = false;

  static Stream<List<PlanConfigModel>> get _plansStream =>
      FirebaseFirestore.instance
          .collection('plans_config')
          .orderBy('order')
          .snapshots()
          .map((s) => s.docs.isEmpty
              ? PlanConfigModel.defaults
              : s.docs
                  .map(PlanConfigModel.fromDoc)
                  .where((p) => p.isVisible)
                  .toList());

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await LicenseController.to.submitUpgradeRequest(
      name: _name.text,
      phone: _phone.text,
      planId: _selectedPlan,
      message: _message.text,
      paymentMethod: _paymentMethod,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null)
      setState(() => _sent = true);
    else
      setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<PlanConfigModel>>(
      stream: _plansStream,
      builder: (ctx, snap) {
        final plans = snap.data ??
            PlanConfigModel.defaults.where((p) => p.isVisible).toList();

        if (plans.isNotEmpty && !plans.any((p) => p.id == _selectedPlan)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedPlan = plans.first.id);
          });
        }

        final selectedModel =
            plans.firstWhereOrNull((p) => p.id == _selectedPlan);

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF4F6FC),
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Trial Banner ────────────────────────────
                      Obx(() {
                        final lc = LicenseController.to;
                        if (lc.state.value == LicenseState.trial) {
                          return _TrialBanner(
                              days: lc.trialDaysLeft.value,
                              total: lc.trialDaysTotal.value,
                              state: lc.state.value);
                        }
                        if (lc.state.value == LicenseState.trialExpired ||
                            lc.state.value == LicenseState.expired ||
                            lc.state.value == LicenseState.suspended) {
                          return _TrialBanner(
                              days: 0,
                              total: lc.trialDaysTotal.value,
                              state: lc.state.value);
                        }
                        return const SizedBox.shrink();
                      }),

                      // ── العنوان ─────────────────────────────────
                      _SectionTitle(
                        title: 'اختر خطتك',
                        subtitle: 'خطط مرنة تناسب احتياجاتك',
                      ),
                      const SizedBox(height: 14),

                      // ── البطاقات (بأنيميشن دخول متتابع) ─────────
                      ...plans.asMap().entries.map((e) => _AnimatedEntry(
                            delay: e.key * 90,
                            child: _PlanCard(
                              plan: e.value,
                              selected: _selectedPlan == e.value.id,
                              onTap: () =>
                                  setState(() => _selectedPlan = e.value.id),
                            ),
                          )),
                      const SizedBox(height: 8),

                      // ── صف الثقة ────────────────────────────────
                      const _TrustRow(),
                      const SizedBox(height: 20),

                      // ── عندك كود ────────────────────────────────
                      _ActivationCodeCard(),
                      const SizedBox(height: 12),

                      // ── مساعد لدى مدرّس ─────────────────────────
                      _AssistantLoginCard(),
                      const SizedBox(height: 20),

                      // ── Pending / Form / Success ────────────────
                      Obx(() {
                        if (LicenseController.to.hasRequest.value && !_sent) {
                          return _PendingRequestCard();
                        }
                        return const SizedBox.shrink();
                      }),

                      if (_sent)
                        _SuccessCard(onBack: () => Navigator.of(context).pop())
                      else
                        Obx(() {
                          if (LicenseController.to.hasRequest.value ||
                              !_showForm) {
                            return const SizedBox.shrink();
                          }
                          return _RequestForm(
                            planName: selectedModel?.nameAr ?? _selectedPlan,
                            nameCtrl: _name,
                            phoneCtrl: _phone,
                            messageCtrl: _message,
                            paymentMethod: _paymentMethod,
                            loading: _loading,
                            error: _error,
                            onPaymentChanged: (m) =>
                                setState(() => _paymentMethod = m),
                            onCancel: () => setState(() => _showForm = false),
                            onSubmit: _submit,
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── شريط CTA ثابت بالأسفل ──────────────────────────────
          bottomSheet: (_sent || _showForm || selectedModel == null)
              ? null
              : Obx(() {
                  if (LicenseController.to.hasRequest.value) {
                    return const SizedBox.shrink();
                  }
                  return _BottomCTABar(
                    plan: selectedModel,
                    isDark: isDark,
                    onTap: selectedModel.price.isEmpty
                        ? () => _openPlanWhatsApp(selectedModel)
                        : () => setState(() => _showForm = true),
                  );
                }),
        );
      },
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 190,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: () => Navigator.pop(context))
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4F46E5),
                Color(0xFF6D28D9),
                Color(0xFF9333EA),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Stack(
            children: [
              // زخارف هندسية
              Positioned(
                top: -40,
                right: -40,
                child: _circle(150, Colors.white.withValues(alpha: 0.07)),
              ),
              Positioned(
                top: 60,
                left: -25,
                child: _circle(80, Colors.white.withValues(alpha: 0.05)),
              ),
              Positioned(
                bottom: -35,
                right: 60,
                child: _circle(110, Colors.white.withValues(alpha: 0.06)),
              ),
              Positioned(
                top: 40,
                left: 80,
                child: Icon(Icons.auto_awesome,
                    size: 16, color: Colors.white.withValues(alpha: 0.35)),
              ),
              Positioned(
                bottom: 60,
                left: 40,
                child: Icon(Icons.auto_awesome,
                    size: 11, color: Colors.white.withValues(alpha: 0.25)),
              ),

              // المحتوى
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 36),
                    // أيقونة التاج في دائرة زجاجية
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                          child: Text('👑', style: TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(height: 12),
                    const Text('ارتقِ بتجربتك',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('كل المميزات بانتظارك — اختر خطتك وانطلق',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.75))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// أنيميشن دخول متتابع
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedEntry extends StatelessWidget {
  final Widget child;
  final int delay;
  const _AnimatedEntry({required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// عنوان قسم
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title, subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87)),
            Text(subtitle,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45)),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trial Banner — مع شريط تقدم
// ─────────────────────────────────────────────────────────────────────────────
class _TrialBanner extends StatelessWidget {
  final int days;
  final int total;
  final LicenseState state;
  const _TrialBanner(
      {required this.days, required this.total, required this.state});

  @override
  Widget build(BuildContext context) {
    final isExpired = state != LicenseState.trial;
    final color = isExpired ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final msg = switch (state) {
      LicenseState.trialExpired => 'انتهت فترة التجربة المجانية — اطلب ترقية للاستمرار',
      LicenseState.expired      => 'انتهت صلاحية اشتراكك — جدد الآن للاستمرار في استخدام التطبيق',
      LicenseState.suspended    => 'تم إيقاف ترخيصك — تواصل مع الدعم لمعرفة السبب',
      _                         => 'باقي لك $days ${days == 1 ? "يوم" : "أيام"} من التجربة المجانية',
    };
    final icon = state == LicenseState.suspended ? '🚫' : '🔒';
    final progress = isExpired ? 0.0 : (days / total).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Center(
                  child: Text(isExpired ? icon : '⏳',
                      style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(msg,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ]),
          if (!isExpired) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Card
// ─────────────────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final PlanConfigModel plan;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(plan.colorValue);
    final hasDiscount = plan.hasDiscount;
    final isPopular = plan.recommended;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.98,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark
                ? (selected
                    ? Color.lerp(const Color(0xFF141B2D), color, 0.12)
                    : const Color(0xFF141B2D))
                : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? color
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.06)),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? color.withValues(alpha: isDark ? 0.35 : 0.22)
                    : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: selected ? 24 : 12,
                offset: Offset(0, selected ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Column(
              children: [
                // ── شريط "الأكثر شهرة" ─────────────────────────
                if (isPopular)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, Color.lerp(color, Colors.purple, 0.4)!],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 5),
                        Text('الأكثر اختياراً',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── الاسم + مؤشر الاختيار ──────────────────
                      Row(
                        children: [
                          // أيقونة الخطة
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              gradient: LinearGradient(
                                colors: [
                                  color.withValues(alpha: 0.2),
                                  color.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                            ),
                            child: Icon(
                              isPopular
                                  ? Icons.workspace_premium_rounded
                                  : Icons.layers_rounded,
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plan.nameAr,
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87)),
                                if (plan.period.isNotEmpty)
                                  Text(plan.period,
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38)),
                              ],
                            ),
                          ),
                          // مؤشر دائري
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected ? color : Colors.transparent,
                              border: Border.all(
                                  color: selected
                                      ? color
                                      : Colors.grey.withValues(alpha: 0.35),
                                  width: 2),
                            ),
                            child: selected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 15)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── السعر ─────────────────────────────────
                      if (plan.price.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.chat_rounded, size: 18, color: color),
                              const SizedBox(width: 8),
                              Text('السعر بالتواصل مع الدعم على واتساب',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8F9FE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                plan.price
                                    .replaceAll(' جنيه', '')
                                    .replaceAll(' EGP', ''),
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: color,
                                    height: 1.0),
                              ),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('جنيه',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black45)),
                              ),
                              const Spacer(),
                              if (hasDiscount)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(plan.originalPrice,
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white30
                                                : Colors.black26,
                                            decoration:
                                                TextDecoration.lineThrough)),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [
                                          Color(0xFFEF4444),
                                          Color(0xFFF97316),
                                        ]),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Text(
                                        'خصم ${_discountPct(plan)}',
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),

                      // ── المميزات ──────────────────────────────
                      if (plan.features.isNotEmpty)
                        ...plan.features.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 17,
                                    height: 17,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color.withValues(alpha: 0.13),
                                    ),
                                    child: Icon(Icons.check_rounded,
                                        size: 11, color: color),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(f,
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12.5,
                                            height: 1.4,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54)),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _discountPct(PlanConfigModel plan) {
    final orig =
        double.tryParse(plan.originalPrice.replaceAll(RegExp(r'[^\d.]'), ''));
    final curr = double.tryParse(plan.price.replaceAll(RegExp(r'[^\d.]'), ''));
    if (orig == null || curr == null || orig == 0) return '';
    return '${((orig - curr) / orig * 100).round()}%';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// صف الثقة
// ─────────────────────────────────────────────────────────────────────────────
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (Icons.flash_on_rounded, 'تفعيل فوري', const Color(0xFFF59E0B)),
      (Icons.support_agent_rounded, 'دعم مباشر', const Color(0xFF10B981)),
      (Icons.verified_user_rounded, 'تفعيل موثوق', const Color(0xFF3B82F6)),
    ];

    return Row(
      children: items
          .map((i) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141B2D) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: i.$3.withValues(alpha: 0.2)),
                  ),
                  child: Column(children: [
                    Icon(i.$1, size: 20, color: i.$3),
                    const SizedBox(height: 5),
                    Text(i.$2,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white60 : Colors.black54)),
                  ]),
                ),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// شريط CTA السفلي الثابت
// ─────────────────────────────────────────────────────────────────────────────
class _BottomCTABar extends StatelessWidget {
  final PlanConfigModel plan;
  final bool isDark;
  final VoidCallback onTap;
  const _BottomCTABar({
    required this.plan,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priceNum = plan.price.replaceAll(' جنيه', '').replaceAll(' EGP', '');
    // بعض التابلت الرخيصة ما بتبلّغش المساحة الحقيقية لشريط التنقل السفلي
    // (MediaQuery.padding.bottom بيرجع صفر أو رقم أقل من الحقيقي)، فبنضمن
    // حد أدنى للـ padding عشان الزر ميتقطعش تحت الشريط.
    final bottomInset =
        MediaQuery.of(context).padding.bottom.clamp(16.0, double.infinity);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101729) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // معلومات الخطة المختارة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(plan.nameAr,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87)),
                if (plan.price.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(priceNum,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryColor,
                              height: 1.1)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('جنيه ${plan.period}',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                color:
                                    isDark ? Colors.white38 : Colors.black38)),
                      ),
                    ],
                  )
                else
                  Text('السعر بالتواصل مع الدعم',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
          ),
          // زر الاشتراك / التواصل
          Builder(builder: (context) {
            final isContact = plan.price.isEmpty;
            final colors = isContact
                ? const [Color(0xFF25D366), Color(0xFF128C7E)]
                : const [Color(0xFF4F46E5), Color(0xFF9333EA)];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isContact ? 'تواصل واتساب' : 'اطلب الترقية',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                        const SizedBox(width: 8),
                        Icon(
                            isContact
                                ? Icons.chat_rounded
                                : Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activation Code Card
// ─────────────────────────────────────────────────────────────────────────────
class _ActivationCodeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.18),
                AppTheme.primaryColor.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: const Icon(Icons.vpn_key_rounded,
              color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('عندك كود تفعيل؟',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87)),
              Text('أدخل الكود لتفعيل اشتراكك فوراً',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45)),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => Get.to(() => const ActivationPage()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('أدخل الكود',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assistant Login Card — مساعد مرتبط بفريق مدرّس، وصل هنا لأن ترخيصه
// الشخصي (تجربة منتهية غالبًا) مش المرجع؛ لازم مسار يوصله لتسجيل
// الدخول حتى لو الشاشة دي مفتوحة كبديل كامل (pushReplacement) بلا
// أي طريقة رجوع.
// ─────────────────────────────────────────────────────────────────────────────
class _AssistantLoginCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.18),
                AppTheme.primaryColor.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: const Icon(Icons.groups_2_rounded,
              color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مساعد لدى مدرّس؟',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87)),
              Text('سجّل دخولك بحسابك عشان تكمّل على ترخيص المدرّس',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45)),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () =>
              Get.to(() => const LoginScreen(onSuccessGoHome: true)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('تسجيل الدخول',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request Form
// ─────────────────────────────────────────────────────────────────────────────
class _RequestForm extends StatelessWidget {
  final String planName;
  final TextEditingController nameCtrl, phoneCtrl, messageCtrl;
  final String paymentMethod;
  final bool loading;
  final String? error;
  final void Function(String) onPaymentChanged;
  final VoidCallback onCancel, onSubmit;

  const _RequestForm({
    required this.planName,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.messageCtrl,
    required this.paymentMethod,
    required this.loading,
    required this.error,
    required this.onPaymentChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  static const _payIcons = {
    'نقدي': Icons.payments_rounded,
    'Vodafone Cash': Icons.phone_android_rounded,
    'InstaPay': Icons.account_balance_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _AnimatedEntry(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141B2D) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
              ),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('طلب اشتراك — $planName',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      Text('أرسل طلبك وسنتواصل معك فوراً',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.75))),
                    ],
                  ),
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormField(
                      ctrl: nameCtrl,
                      hint: 'اسمك الكريم',
                      icon: Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _FormField(
                      ctrl: phoneCtrl,
                      hint: 'رقم واتساب',
                      icon: Icons.phone_rounded,
                      type: TextInputType.phone),
                  const SizedBox(height: 12),
                  _FormField(
                      ctrl: messageCtrl,
                      hint: 'رسالة للمطور (اختياري)',
                      icon: Icons.message_outlined,
                      maxLines: 3),
                  const SizedBox(height: 18),

                  // طريقة التحويل
                  _SectionLabel(
                      label: 'طريقة التحويل', icon: Icons.payment_rounded),
                  const SizedBox(height: 10),
                  Row(
                    children: ['نقدي', 'Vodafone Cash', 'InstaPay'].map((m) {
                      final sel = paymentMethod == m;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onPaymentChanged(m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppTheme.primaryColor
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel
                                    ? AppTheme.primaryColor
                                    : Colors.grey.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Column(children: [
                              Icon(_payIcons[m],
                                  size: 18,
                                  color: sel
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white54
                                          : Colors.black45)),
                              const SizedBox(height: 4),
                              Text(m,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: sel
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black54))),
                            ]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(error!,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.red)),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13)),
                          side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.4)),
                        ),
                        child: const Text('إلغاء',
                            style: TextStyle(
                                fontFamily: 'Cairo', color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: loading ? null : onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13)),
                          elevation: 0,
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text('إرسال الطلب',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success Card
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessCard extends StatelessWidget {
  final VoidCallback onBack;
  const _SuccessCard({required this.onBack});

  @override
  Widget build(BuildContext context) => _AnimatedEntry(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.withValues(alpha: 0.12),
                Colors.green.withValues(alpha: 0.03),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
          ),
          child: Column(children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.13),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.green, size: 44),
            ),
            const SizedBox(height: 16),
            const Text('تم إرسال طلبك بنجاح! 🎉',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.green)),
            const SizedBox(height: 10),
            const Text(
              'سيتم مراجعة طلبك والتواصل معك عبر واتساب\nعند الموافقة سيتفعل الترخيص تلقائياً',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.6),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('العودة للرئيسية',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Card
// ─────────────────────────────────────────────────────────────────────────────
class _PendingRequestCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF59E0B).withValues(alpha: 0.12),
              const Color(0xFFF59E0B).withValues(alpha: 0.03),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFFF59E0B), size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('طلبك قيد المراجعة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF59E0B))),
                SizedBox(height: 4),
                Text(
                  'سيتم التواصل معك عبر واتساب قريباً\nوسيتفعل ترخيصك تلقائياً عند الموافقة 🎉',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]);
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData? icon;
  final TextInputType? type;
  final int maxLines;
  const _FormField({
    required this.ctrl,
    required this.hint,
    this.icon,
    this.type,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: TextStyle(
          fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Cairo',
            color: isDark ? Colors.white30 : Colors.black38,
            fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: AppTheme.primaryColor)
            : null,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide:
                const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

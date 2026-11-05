// lib/views/license/free_month_banner.dart
//
// بنر حملة «شهر مجانًا» في الصفحة الرئيسية (تحت بنر التجربة/الترقية). الضغط
// عليه بيفتح ورقة بالاسم والرقم، وبعدها بيوصل الطلب لصفحة طلبات الترقية في
// الأدمن، اللي بيفعّل الشهر بضغطة (والتفعيل بيوصل جهاز المدرس تلقائيًا).
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/free_month_promo.dart';
import 'package:active_class/utils/helpers.dart';

class FreeMonthBanner extends StatelessWidget {
  const FreeMonthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lc = LicenseController.to;
      // قراءات تفاعلية عشان الـObx يتحدّث لما أي شرط يتغيّر.
      // ignore: unnecessary_statements
      lc.state.value;
      // ignore: unnecessary_statements
      lc.hasRequest.value;
      // ignore: unnecessary_statements
      lc.promoUsed.value;
      final p = lc.promo.value;
      if (p == null || !lc.showFreeMonthPromo) return const SizedBox.shrink();
      final t = context.tokens;
      return Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
        child: Semantics(
          button: true,
          label: '${p.title}. ${p.subtitle}',
          excludeSemantics: true,
          child: Material(
            color: t.chalk,
            borderRadius: BorderRadius.circular(AppRadius.panel),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openRequestSheet(context, p),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md + 2, vertical: AppSpace.sm + 2),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: t.onChalk.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Icon(Icons.card_giftcard_rounded,
                          color: t.onChalk, size: 24),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              style: AppType.title.copyWith(color: t.onChalk)),
                          Text(p.subtitle,
                              style: AppType.caption.copyWith(
                                  color: t.onChalk.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: t.onChalk),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _openRequestSheet(BuildContext context, FreeMonthPromo p) {
    final t = context.tokens;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: t.surface,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _RequestSheet(promo: p),
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  final FreeMonthPromo promo;
  const _RequestSheet({required this.promo});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : null;
    _name = TextEditingController(text: s?.teacherFullName.value.trim() ?? '');
    _phone = TextEditingController(text: s?.teacherPhone.value.trim() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await LicenseController.to
        .submitFreeMonthRequest(name: _name.text, phone: _phone.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _sending = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pop();
    ToastHelper.success('وصل طلبك — هنفعّل لك الشهر المجاني قريبًا');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = widget.promo;
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: t.chalk,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child:
                  Icon(Icons.card_giftcard_rounded, color: t.onChalk, size: 26),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: AppType.title.copyWith(color: t.ink)),
                  Text('${p.days} يوم بكل المميزات',
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: AppSpace.lg),
          Text('اكتب اسمك ورقمك وهنفعّل لك الشهر ونتواصل معاك.',
              style: AppType.body.copyWith(color: t.inkSoft)),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'الاسم', prefixIcon: Icon(Icons.person_rounded)),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'رقم الموبايل',
                prefixIcon: Icon(Icons.phone_rounded)),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(_error!, style: AppType.body.copyWith(color: t.danger)),
          ],
          const SizedBox(height: AppSpace.lg),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'جاري الإرسال...' : 'اطلب الشهر المجاني'),
          ),
        ],
      ),
    );
  }
}

/// يفتح ورقة طلب الشهر المجاني (من الإشعار) لو الحملة شغّالة والمدرس مستهدف.
void openFreeMonthRequest() {
  final ctx = Get.context;
  if (ctx == null || !Get.isRegistered<LicenseController>()) return;
  final lc = LicenseController.to;
  final p = lc.promo.value;
  if (p == null || !lc.showFreeMonthPromo) return;
  const FreeMonthBanner()._openRequestSheet(ctx, p);
}

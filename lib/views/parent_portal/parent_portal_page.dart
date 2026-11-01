// lib/views/parent_portal/parent_portal_page.dart
//
// القسم الرئيسي "بوابة أولياء الأمور" في تطبيق المدرس: حالة الإضافة، رابط
// المتابعة (نسخ/مشاركة/QR)، نشر البيانات، طلاب البوابة، وطريقة دخول ولي
// الأمر. الصفحة العامة نفسها على active-class.online/track — هنا مركز التحكم.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/parent_portal_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/parent_portal_helper.dart';
import 'package:active_class/views/license/trial_banner.dart'
    show openRenewalWhatsApp;
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

class ParentPortalPage extends StatefulWidget {
  const ParentPortalPage({super.key});

  @override
  State<ParentPortalPage> createState() => _ParentPortalPageState();
}

class _ParentPortalPageState extends State<ParentPortalPage> {
  late final ParentPortalController _ctrl = Get.isRegistered<
          ParentPortalController>()
      ? Get.find<ParentPortalController>()
      : Get.put(ParentPortalController());
  late final StudentController _students = Get.isRegistered<StudentController>()
      ? Get.find<StudentController>()
      : Get.put(StudentController());

  Future<void> _publish() async {
    try {
      final n = await _ctrl.publishAll();
      if (!mounted) return;
      ToastHelper.success('اتنشرت بيانات $n طالب');
    } catch (e) {
      // لو النشر فشل (اتصال ضعيف، أو صف واحد بس رفضته قاعدة الأمان)
      // Firestore بترجع الـ batch كله بالفشل — لازم رسالة واضحة.
      debugPrint('ParentPortalPage: publishAll failed — $e');
      if (!mounted) return;
      ToastHelper.error('فشل النشر — تأكد من الاتصال بالإنترنت وحاول تاني');
    }
  }

  Future<void> _toggleCodeOnly(bool v) async {
    final cfg = Get.find<SettingsController>();
    if (v) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('الدخول بالكود فقط'),
          content: const Text(
              'بدون آخر 4 أرقام، أي حد يعرف (أو يخمّن) كود الطالب يقدر يشوف حضوره ومدفوعاته ودرجاته. '
              'لو أكواد طلابك متسلسلة (مثل 1، 2، 3) ده بيسهّل التخمين.\n\nمتأكد؟'),
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
      ToastHelper.error('تعذر تغيير طريقة الدخول — تأكد من الإنترنت وحاول تاني');
    }
  }

  void _showQr() {
    final url = _ctrl.url;
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final t = ctx.tokens;
        return Dialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.board)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('امسح الكود لفتح صفحة المتابعة',
                    textAlign: TextAlign.center,
                    style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.md),
                // خلفية بيضا دايمًا: الـQR محتاج تباين عالي حتى في الوضع الداكن.
                Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.panel),
                    border: Border.all(color: t.line),
                  ),
                  child: QrImageView(
                    data: url,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(url,
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                ),
                const SizedBox(height: AppSpace.md),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                      minimumSize: const Size(48, 44)),
                  child: const Text('تمام'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lic = Get.find<LicenseController>();
    final settings = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(
        context,
        title: 'بوابة أولياء الأمور',
        actions: [
          IconButton(
            tooltip: 'تحديث الرابط',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _ctrl.load,
          ),
        ],
      ),
      body: Obx(() {
        // تبعيات الحالة: الإضافة + مؤقّتات إعادة التقييم + عدّاد الطلاب.
        // ignore: unnecessary_statements
        lic.parentPortalRecheckTick.value;
        // ignore: unnecessary_statements
        lic.licenseVerifiedTick.value;
        final status = portalStatus(
          enabled: lic.parentPortalEnabled.value,
          expiresAt: lic.parentPortalExpiresAt.value,
          now: DateTime.now(),
        );
        final codeOnly = settings.portalCodeOnly.value;
        final counts = portalCounts(_students.students, codeOnly: codeOnly);

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _Board(status: status, counts: counts, ctrl: _ctrl),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: status.isActive
                  ? _ActiveBody(
                      ctrl: _ctrl,
                      counts: counts,
                      codeOnly: codeOnly,
                      onPublish: _publish,
                      onQr: _showQr,
                      onToggleCodeOnly: _toggleCodeOnly,
                    )
                  : _LockedBody(status: status),
            ),
          ],
        );
      }),
    );
  }
}

/// سبورة القسم: حالة الإضافة + أرقام الطلاب.
class _Board extends StatelessWidget {
  final PortalStatus status;
  final PortalCounts counts;
  final ParentPortalController ctrl;

  const _Board({required this.status, required this.counts, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // ألوان الحالات فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;

    final (IconData icon, Color tone, String text) = switch (status.kind) {
      PortalStatusKind.lifetime => (
          Icons.check_circle_rounded,
          on.positive,
          'الإضافة مفعّلة — مدى الحياة'
        ),
      PortalStatusKind.active => (
          Icons.check_circle_rounded,
          on.positive,
          'الإضافة مفعّلة — تنتهي في ${FormatHelper.formatFullDate(status.expiresAt)}'
        ),
      PortalStatusKind.expiringSoon => (
          Icons.schedule_rounded,
          t.chalk,
          status.daysLeft <= 0
              ? 'الإضافة بتنتهي خلال 24 ساعة'
              : 'الإضافة بتنتهي بعد ${status.daysLeft} يوم'
        ),
      PortalStatusKind.expired => (
          Icons.error_rounded,
          on.danger,
          'انتهت الإضافة في ${FormatHelper.formatFullDate(status.expiresAt)}'
        ),
      PortalStatusKind.off => (
          Icons.error_rounded,
          on.danger,
          'الإضافة غير مفعّلة'
        ),
    };
    final needsRenewal = status.kind == PortalStatusKind.expiringSoon ||
        status.kind == PortalStatusKind.expired ||
        status.kind == PortalStatusKind.off;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
      decoration: BoxDecoration(
        color: t.board,
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.board)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.sm),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(children: [
              Icon(icon, size: 20, color: tone),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(text,
                    style: AppType.body.copyWith(
                        fontWeight: FontWeight.w700, color: t.boardInk)),
              ),
              if (needsRenewal)
                TextButton(
                  onPressed: () => openRenewalWhatsApp(portalAddon: true),
                  style: TextButton.styleFrom(
                    foregroundColor: t.chalk,
                    minimumSize: const Size(48, 40),
                  ),
                  child: Text(
                      status.kind == PortalStatusKind.off ? 'فعّلها' : 'جدّد',
                      style: AppType.body.copyWith(
                          fontWeight: FontWeight.w700, color: t.chalk)),
                ),
            ]),
          ),
          if (status.isActive) ...[
            const SizedBox(height: AppSpace.lg),
            Row(children: [
              Expanded(
                  child: BoardStat(
                      label: 'ظاهر لأولياء الأمور',
                      value: '${counts.ready}',
                      color: on.positive)),
              Expanded(
                  child: BoardStat(
                      label: 'مش ظاهر',
                      value: '${counts.hidden}',
                      color: counts.hidden > 0 ? t.chalk : t.boardInkSoft)),
              Expanded(
                  child: BoardStat(
                      label: 'الطلاب',
                      value: '${counts.total}',
                      color: t.boardInk)),
            ]),
          ],
        ],
      ),
    );
  }
}

/// الإضافة مقفولة: شرح + زرار التفعيل/التجديد.
class _LockedBody extends StatelessWidget {
  final PortalStatus status;
  const _LockedBody({required this.status});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final expired = status.kind == PortalStatusKind.expired;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.dangerSoft,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(Icons.lock_rounded, color: t.danger),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text('بوابة أولياء الأمور مقفولة',
                  style: AppType.title.copyWith(color: t.ink)),
            ),
          ]),
          const SizedBox(height: AppSpace.md),
          Text(
            expired
                ? 'صفحة المتابعة مقفولة على أولياء الأمور لحد ما تجدّد الاشتراك. بياناتك وطلابك زي ما هم.'
                : 'أولياء الأمور بيتابعوا حضور ومدفوعات وواجب ودرجات أولادهم من رابط واحد، من غير ما يحمّلوا تطبيق. الإضافة دي مش مفعّلة على حسابك لسه.',
            style: AppType.body.copyWith(color: t.inkSoft, height: 1.6),
          ),
          const SizedBox(height: AppSpace.lg),
          FilledButton.icon(
            onPressed: () => openRenewalWhatsApp(portalAddon: true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: t.positive,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.chat_rounded),
            label: Text(expired ? 'جدّد عن طريق واتساب' : 'فعّلها عن طريق واتساب',
                style: AppType.label.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// المحتوى لما الإضافة شغّالة.
class _ActiveBody extends StatelessWidget {
  final ParentPortalController ctrl;
  final PortalCounts counts;
  final bool codeOnly;
  final VoidCallback onPublish;
  final VoidCallback onQr;
  final ValueChanged<bool> onToggleCodeOnly;

  const _ActiveBody({
    required this.ctrl,
    required this.counts,
    required this.codeOnly,
    required this.onPublish,
    required this.onQr,
    required this.onToggleCodeOnly,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── رابط المتابعة ──
        AppPanel(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Obx(() {
            final url = ctrl.url;
            final loading = ctrl.loading.value && url.isEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('رابط المتابعة',
                    style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.xs),
                Text(
                  codeOnly
                      ? 'ابعت الرابط ده لأولياء الأمور — بيدخلوا بكود الطالب.'
                      : 'ابعت الرابط ده لأولياء الأمور — بيدخلوا بكود الطالب وآخر 4 أرقام من تليفونهم.',
                  style: AppType.caption.copyWith(color: t.inkSoft),
                ),
                const SizedBox(height: AppSpace.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md, vertical: AppSpace.md),
                  decoration: BoxDecoration(
                    color: t.page,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: t.line),
                  ),
                  child: loading
                      ? const Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)))
                      : Directionality(
                          textDirection: TextDirection.ltr,
                          child: SelectableText(
                              url.isEmpty ? '—' : url,
                              style: AppType.caption
                                  .copyWith(color: t.ink)),
                        ),
                ),
                const SizedBox(height: AppSpace.md),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: url.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: url));
                              ToastHelper.success('تم نسخ الرابط');
                            },
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm),
                          side: BorderSide(color: t.line),
                          foregroundColor: t.brand),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const FittedBox(
                          fit: BoxFit.scaleDown, child: Text('نسخ')),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: url.isEmpty ? null : onQr,
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm),
                          side: BorderSide(color: t.line),
                          foregroundColor: t.brand),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                      label: const FittedBox(
                          fit: BoxFit.scaleDown, child: Text('QR')),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          url.isEmpty ? null : () => Share.share(url),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm)),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const FittedBox(
                          fit: BoxFit.scaleDown, child: Text('مشاركة')),
                    ),
                  ),
                ]),
              ],
            );
          }),
        ),
        const SizedBox(height: AppSpace.md),

        // ── طلاب البوابة ──
        AppPanel(
          onTap: () => Get.toNamed(ROUTE_PARENT_PORTAL_STUDENTS),
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.lg, AppSpace.md, AppSpace.sm, AppSpace.md),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(Icons.groups_rounded, color: t.brand),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('طلاب البوابة',
                      style: AppType.label.copyWith(color: t.ink)),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${counts.ready} ظاهر',
                          style: AppType.caption.copyWith(color: t.inkSoft)),
                      if (counts.hidden > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm, vertical: 1),
                          decoration: BoxDecoration(
                            color: t.cautionSoft,
                            borderRadius:
                                BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Text('${counts.hidden} مش ظاهرين',
                              style: AppType.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: t.caution)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: t.inkFaint),
          ]),
        ),
        const SizedBox(height: AppSpace.md),

        // ── نشر البيانات ──
        AppPanel(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Obx(() {
            final publishing = ctrl.publishing.value;
            final at = ctrl.lastPublishedAt.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('نشر البيانات',
                    style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'بيحدّث الصفحة اللي بيشوفها أولياء الأمور بآخر حضور ومدفوعات وواجب ودرجات.',
                  style: AppType.caption.copyWith(color: t.inkSoft),
                ),
                const SizedBox(height: AppSpace.md),
                FilledButton.icon(
                  onPressed: publishing ? null : onPublish,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  icon: publishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded),
                  label: Text(publishing ? 'جاري النشر...' : 'انشر الآن',
                      style: AppType.label.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  at == null
                      ? 'لسه ما نشرتش من الشاشة دي'
                      : 'آخر نشر ${DateFormat('h:mm a', 'ar').format(at)} — ${ctrl.lastPublishedCount.value ?? 0} طالب',
                  style: AppType.caption.copyWith(color: t.inkFaint),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: AppSpace.md),

        // ── طريقة دخول ولي الأمر ──
        AppPanel(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.sm),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('الدخول بالكود فقط',
                style: AppType.label.copyWith(color: t.ink)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(
                codeOnly
                    ? 'ولي الأمر بيدخل بكود الطالب بس (أسهل، لكن أي حد يعرف الكود يشوف بيانات الطالب).'
                    : 'ولي الأمر بيدخل بكود الطالب + آخر 4 أرقام من تليفونه (الأأمن).',
                style: AppType.caption.copyWith(color: t.inkSoft),
              ),
            ),
            value: codeOnly,
            onChanged: onToggleCodeOnly,
          ),
        ),
      ],
    );
  }
}

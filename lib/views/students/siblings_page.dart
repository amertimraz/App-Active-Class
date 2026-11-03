// lib/views/students/siblings_page.dart
//
// spec 042 — شاشة الإخوة: كل عيلة كارت (الأعضاء + الماليات + الحضور +
// أرقام ولي الأمر + رسالة واتساب واحدة للعيلة). عرض فقط، بيتحدّث تلقائيًا.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/phone_helper.dart';
import 'package:active_class/utils/siblings_overview.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/views/booklets/booklet_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/custom_widgets.dart';

class SiblingsPage extends StatefulWidget {
  const SiblingsPage({super.key});

  @override
  State<SiblingsPage> createState() => _SiblingsPageState();
}

class _SiblingsPageState extends State<SiblingsPage> {
  final _search = TextEditingController();
  final bool _fin = TeamModeService().canSeeFinancials;
  String _q = '';
  bool _owingOnly = false;

  StudentController get _students => Get.isRegistered<StudentController>()
      ? Get.find<StudentController>()
      : Get.put(StudentController());
  GroupController get _groups => Get.isRegistered<GroupController>()
      ? Get.find<GroupController>()
      : Get.put(GroupController());
  AttendanceController get _att => Get.isRegistered<AttendanceController>()
      ? Get.find<AttendanceController>()
      : Get.put(AttendanceController());
  PaymentController get _pay => Get.isRegistered<PaymentController>()
      ? Get.find<PaymentController>()
      : Get.put(PaymentController());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // ألوان الأرقام فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'الإخوة'),
      body: Obx(() {
        final now = DateTime.now();
        // قراءة الـRxLists هنا عشان الشاشة تتحدّث مع أي تغيير (منها المزامنة).
        final all = buildSiblingFamilies(
          activeStudents: _students.students.toList(),
          groups: _groups.groups.toList(),
          attendance: _att.attendance.toList(),
          payments: _fin ? _pay.payments.toList() : const [],
          now: now,
        );
        final families =
            filterFamilies(all, query: _q, owingOnly: _fin && _owingOnly);
        final members = all.fold<int>(0, (n, f) => n + f.members.length);
        final remaining = all.fold<double>(0, (n, f) => n + f.totalRemaining);
        return Column(children: [
          // السبورة: عيلات / طلاب / متبقي
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
            decoration: BoxDecoration(
              color: t.board,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.board)),
            ),
            child: Row(children: [
              Expanded(
                  child: BoardStat(
                      label: 'عيلة', value: '${all.length}', color: t.boardInk)),
              Expanded(
                  child: BoardStat(
                      label: 'طالب', value: '$members', color: on.positive)),
              if (_fin)
                Expanded(
                    child: BoardStat(
                        label: 'متبقي',
                        value: FormatHelper.formatCurrencyCompact(remaining),
                        color: remaining > 0.005 ? t.chalk : t.boardInkSoft)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xs),
            child: CustomSearchBar(
              controller: _search,
              hintText: 'ابحث باسم الطالب أو الكود',
              onChanged: (v) => setState(() => _q = v),
              onClear: () => setState(() {
                _q = '';
                _search.clear();
              }),
            ),
          ),
          if (_fin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppFilterChip(
                  label: 'عليها متبقي',
                  selected: _owingOnly,
                  color: t.danger,
                  onTap: () => setState(() => _owingOnly = !_owingOnly),
                ),
              ),
            ),
          Expanded(
            child: all.isEmpty
                ? const EmptyState(
                    icon: Icons.family_restroom_rounded,
                    title: 'مفيش إخوة مسجّلين',
                    subtitle:
                        'اربط طالبين أو تلاتة ببعض من شاشة إضافة/تعديل الطالب (خانة "أخ/أخت") وهيظهروا هنا')
                : families.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'مفيش عيلات مطابقة',
                        subtitle: 'غيّر البحث أو الفلتر')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
                        itemCount: families.length,
                        itemBuilder: (_, i) =>
                            _FamilyCard(family: families[i], fin: _fin, now: now),
                      ),
          ),
        ]);
      }),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  final SiblingFamily family;
  final bool fin;
  final DateTime now;
  const _FamilyCard(
      {required this.family, required this.fin, required this.now});

  Future<void> _send(BuildContext context, SiblingContact? contact) async {
    final settings = Get.find<SettingsController>();
    final msg = buildFamilyMessage(family, withFinance: fin, month: now);
    await launchGuardianWhatsapp(
      context: context,
      phone: contact?.phone,
      whatsapp: contact?.whatsapp,
      message: msg,
      dialCode: settings.countryDial.value,
    );
  }

  Future<void> _onSendTap(BuildContext context) async {
    final contacts = family.contacts;
    if (contacts.length <= 1) {
      return _send(context, contacts.isEmpty ? null : contacts.first);
    }
    final dial = Get.find<SettingsController>().countryDial.value;
    final picked = await showModalBottomSheet<SiblingContact>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          const SheetHandle(),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('الإخوة أرقامهم مختلفة — ابعت لأنهي رقم؟',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          for (final c in contacts)
            ListTile(
              leading: const Icon(Icons.phone_rounded),
              title: Text(
                  c.phone.isNotEmpty
                      ? PhoneHelper.displayIntl(c.phone, dial)
                      : c.label,
                  textDirection: TextDirection.ltr),
              onTap: () => Navigator.pop(ctx, c),
            ),
        ]),
      ),
    );
    if (picked != null && context.mounted) await _send(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = family.totalPaid + family.totalRemaining;
    final settings = Get.find<SettingsController>();
    final groupNames = family.members
        .map((m) => m.group?.name)
        .whereType<String>()
        .toSet()
        .join('، ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpace.md),
        lineColor: fin && family.hasBalance
            ? t.danger.withValues(alpha: 0.45)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── الرأس ────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(Icons.family_restroom_rounded, color: t.brand),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.members.map((m) => m.student.name).join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label.copyWith(color: t.ink),
                    ),
                    if (groupNames.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(groupNames,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text('${family.members.length} إخوة',
                    style: AppType.caption
                        .copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              ),
            ]),

            // ── الماليات (صواني محايدة، اللون على الرقم بس) ───────────────
            if (fin) ...[
              const SizedBox(height: AppSpace.md),
              IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (family.sharedTotal != null) ...[
                        _stat(t, 'إجمالي مشترك', family.sharedTotal!, t.brand),
                        const SizedBox(width: AppSpace.sm),
                      ],
                      _stat(t, 'مدفوع', family.totalPaid, t.positive),
                      const SizedBox(width: AppSpace.sm),
                      _stat(t, 'متبقي', family.totalRemaining,
                          family.hasBalance ? t.danger : t.positive),
                    ]),
              ),
              const SizedBox(height: AppSpace.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: LinearProgressIndicator(
                  value: total <= 0
                      ? 1
                      : (family.totalPaid / total).clamp(0.0, 1.0),
                  minHeight: 6,
                  color: family.hasBalance ? t.cautionBar : t.positive,
                  backgroundColor: t.line,
                ),
              ),
            ],

            // ── الإخوة ───────────────────────────────────────────────
            const SizedBox(height: AppSpace.md),
            Container(
              decoration: BoxDecoration(
                color: t.page,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Column(children: [
                for (var i = 0; i < family.members.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1, indent: 12, endIndent: 12, color: t.line),
                  _memberTile(t, family.members[i]),
                ],
              ]),
            ),

            // ── ولي الأمر ────────────────────────────────────────────
            const SizedBox(height: AppSpace.md),
            Row(children: [
              Icon(Icons.phone_rounded, size: 15, color: t.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  family.contacts.isEmpty
                      ? 'مفيش رقم ولي أمر مسجّل'
                      : family.contacts
                          .map((c) => c.phone.isNotEmpty
                              ? PhoneHelper.displayIntl(
                                  c.phone, settings.countryDial.value)
                              : c.label)
                          .join('  •  '),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: AppType.caption.copyWith(color: t.inkSoft),
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _onSendTap(context),
                icon: Icon(Icons.chat_rounded, size: 18, color: t.positive),
                label: const Text('رسالة واتساب للعيلة'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: t.ink,
                    side: BorderSide(color: t.line),
                    minimumSize: const Size(44, 46)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberTile(AppTokens t, SiblingMember m) {
    final r = m.monthRate;
    final attColor = r == null
        ? t.inkSoft
        : r >= 80
            ? t.positive
            : r >= 60
                ? t.caution
                : t.danger;
    final name = m.student.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: () => Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: m.student),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.md),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: t.brand.withValues(alpha: 0.14),
            child: Text(initial,
                style: AppType.label.copyWith(color: t.brand)),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.student.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Text('${m.group?.name ?? '—'} • ${m.student.code}',
                    style: AppType.caption.copyWith(color: t.inkSoft)),
                const SizedBox(height: 5),
                Wrap(spacing: AppSpace.sm, runSpacing: 4, children: [
                  StatusPill(
                      r == null
                          ? 'لا سجلات حضور'
                          : 'حضور ${r.round()}% (${m.monthPresent}/${m.monthPresent + m.monthAbsent})',
                      attColor,
                      icon: Icons.how_to_reg_rounded),
                  if (fin)
                    m.remaining > 0.005
                        ? StatusPill(
                            'متبقي ${FormatHelper.formatCurrencyCompact(m.remaining)}',
                            t.danger)
                        : StatusPill('مسدّد', t.positive,
                            icon: Icons.check_rounded),
                ]),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: t.inkSoft),
        ]),
      ),
    );
  }

  Widget _stat(AppTokens t, String label, double amount, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpace.sm, horizontal: AppSpace.xs),
          decoration: BoxDecoration(
            color: t.page,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Column(children: [
            CurrencyText(amount,
                stacked: true,
                textAlign: TextAlign.center,
                style: AppType.label.copyWith(color: color)),
            const SizedBox(height: 3),
            Text(label, style: AppType.caption.copyWith(color: t.inkSoft)),
          ]),
        ),
      );
}

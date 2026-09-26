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
    return Scaffold(
      appBar: AppBar(title: const Text('الإخوة')),
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
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ChoiceChip(
                  label: const Text('عليها متبقي', style: TextStyle(fontSize: 12)),
                  selected: _owingOnly,
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) => setState(() => _owingOnly = v),
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
    final dark = isDarkOf(context);
    final total = family.totalPaid + family.totalRemaining;
    final settings = Get.find<SettingsController>();
    final groupNames = family.members
        .map((m) => m.group?.name)
        .whereType<String>()
        .toSet()
        .join('، ');
    final subtle = dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: bookletCardDecoration(context,
          accent: fin && family.hasBalance ? AppTheme.errorColor : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── الرأس ────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.family_restroom_rounded,
                  color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    family.members.map((m) => m.student.name).join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  if (groupNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(groupNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill('${family.members.length} إخوة', AppTheme.primaryColor),
          ]),

          // ── الماليات ─────────────────────────────────────────────
          if (fin) ...[
            const SizedBox(height: 14),
            IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              if (family.sharedTotal != null) ...[
                _stat('إجمالي مشترك', family.sharedTotal!,
                    AppTheme.primaryColor),
                const SizedBox(width: 8),
              ],
              _stat('مدفوع', family.totalPaid, AppTheme.successColor),
              const SizedBox(width: 8),
              _stat(
                  'متبقي',
                  family.totalRemaining,
                  family.hasBalance
                      ? AppTheme.errorColor
                      : AppTheme.successColor),
            ])),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total <= 0 ? 1 : (family.totalPaid / total).clamp(0.0, 1.0),
                minHeight: 6,
                color: family.hasBalance
                    ? AppTheme.warningColor
                    : AppTheme.successColor,
                backgroundColor:
                    dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ],

          // ── الإخوة ───────────────────────────────────────────────
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: subtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              for (var i = 0; i < family.members.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: Colors.grey.withValues(alpha: 0.25)),
                _memberTile(family.members[i]),
              ],
            ]),
          ),

          // ── ولي الأمر ────────────────────────────────────────────
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.phone_rounded, size: 15, color: Colors.grey.shade600),
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _onSendTap(context),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('رسالة واتساب للعيلة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberTile(SiblingMember m) {
    final r = m.monthRate;
    final attColor = r == null
        ? Colors.grey
        : r >= 80
            ? AppTheme.successColor
            : r >= 60
                ? AppTheme.warningColor
                : AppTheme.errorColor;
    final name = m.student.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: m.student),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            child: Text(initial,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${m.group?.name ?? '—'} • ${m.student.code}',
                    style:
                        TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
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
                            AppTheme.errorColor)
                        : const StatusPill('مسدّد', AppTheme.successColor,
                            icon: Icons.check_rounded),
                ]),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _stat(String label, double amount, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            CurrencyText(amount,
                stacked: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ]),
        ),
      );
}

// lib/views/students/at_risk_students_page.dart
//
// spec 021 — شاشة "طلاب محتاجين متابعة": قائمة الطلاب المرصودين
// (غياب متتالي / واجب ناقص متكرر / هبوط درجات / تأخّر دفع) مع تواصل
// مباشر (اتصال/واتساب/فتح صفحة الطالب) و"تمّت المتابعة".
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/at_risk_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/at_risk_model.dart';
import 'package:active_class/models/student_follow_up_model.dart';
import 'package:active_class/utils/phone_format.dart';

class AtRiskStudentsPage extends StatefulWidget {
  const AtRiskStudentsPage({super.key});

  @override
  State<AtRiskStudentsPage> createState() => _AtRiskStudentsPageState();
}

class _AtRiskStudentsPageState extends State<AtRiskStudentsPage> {
  final AtRiskController controller = Get.isRegistered<AtRiskController>()
      ? Get.find<AtRiskController>()
      : Get.put(AtRiskController());

  bool _showSnoozed = false;

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(AtRiskStudent e) async {
    final phone = e.guardianPhone;
    if (phone == null || phone.trim().isEmpty) return;
    final settings =
        Get.isRegistered<SettingsController>() ? Get.find<SettingsController>() : null;
    final dial = settings?.countryDial.value ?? '20';
    final normalized = normalizeWhatsappPhone(phone, dial);
    final uri = Uri.parse(
        'https://wa.me/$normalized?text=${Uri.encodeComponent(_riskMessage(e, settings))}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// رسالة واتساب جاهزة لولي الأمر بناءً على أسباب رصد الطالب.
  String _riskMessage(AtRiskStudent e, SettingsController? settings) {
    final b = StringBuffer();
    b.writeln('السلام عليكم ورحمة الله،');
    final groupPart = e.group != null ? ' (${e.group!.name})' : '';
    b.writeln('حابين نلفت انتباه حضرتكم بخصوص الطالب/ة ${e.student.name}$groupPart:');
    for (final s in e.signals) {
      b.writeln('• ${s.reasonText}');
    }
    b.writeln('');
    b.writeln('نرجو التواصل معنا لمتابعة الموضوع. شكرًا لتعاونكم.');
    final teacher = settings?.teacherFullName.value.trim() ?? '';
    if (teacher.isNotEmpty) b.write('\n$teacher');
    return b.toString().trim();
  }

  void _openStudent(AtRiskStudent e) {
    Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: e.student);
  }

  Future<void> _acknowledge(AtRiskStudent e) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تمّت متابعة ${e.student.name}؟',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: TextField(
          controller: noteController,
          maxLines: 2,
          style: const TextStyle(fontFamily: 'Cairo'),
          decoration: const InputDecoration(
            hintText: 'ملاحظة (اختياري)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تمّت المتابعة', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (confirmed != true || e.student.id == null) return;
    final note = noteController.text.trim();
    await controller.acknowledge(e.student.id!, note: note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_showSnoozed ? 'تمّت متابعتهم' : 'محتاجين متابعة',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15)),
        actions: [
          Obx(() => IconButton(
                tooltip: _showSnoozed ? 'القائمة الرئيسية' : 'تمّت متابعتهم',
                icon: Badge(
                  label: Text('${controller.snoozed.length}'),
                  isLabelVisible:
                      !_showSnoozed && controller.snoozed.isNotEmpty,
                  child: Icon(_showSnoozed
                      ? Icons.warning_amber_rounded
                      : Icons.history_rounded),
                ),
                onPressed: () => setState(() => _showSnoozed = !_showSnoozed),
              )),
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.items.isEmpty &&
            controller.snoozed.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = _showSnoozed ? controller.snoozed : controller.items;
        return Column(
          children: [
            if (!_showSnoozed) _filters(cs),
            Expanded(
              child: list.isEmpty
                  ? _emptyState(cs)
                  : RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _card(cs, list[i],
                            followUp: _showSnoozed
                                ? controller.snoozedFollowUps[list[i].student.id]
                                : null),
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _filters(ColorScheme cs) => Obx(() {
        final groups = controller.groupsWithAtRiskStudents;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              _filterChip(cs, label: 'الكل', selected: controller.reasonFilter.value == null,
                  onTap: () => controller.setReasonFilter(null)),
              const SizedBox(width: 6),
              for (final t in RiskSignalType.values) ...[
                _filterChip(cs,
                    label: t.label,
                    selected: controller.reasonFilter.value == t,
                    onTap: () => controller.setReasonFilter(
                        controller.reasonFilter.value == t ? null : t)),
                const SizedBox(width: 6),
              ],
              if (groups.isNotEmpty) ...[
                Container(
                    width: 1,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: cs.onSurface.withValues(alpha: 0.15)),
                for (final g in groups) ...[
                  _filterChip(cs,
                      label: g.name,
                      selected: controller.groupFilter.value == g.id,
                      onTap: () => controller.setGroupFilter(
                          controller.groupFilter.value == g.id ? null : g.id)),
                  const SizedBox(width: 6),
                ],
              ],
            ],
          ),
        );
      });

  Widget _filterChip(ColorScheme cs,
          {required String label,
          required bool selected,
          required VoidCallback onTap}) =>
      ChoiceChip(
        label: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : cs.onSurface)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.primaryColor,
        backgroundColor: cs.onSurface.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.onSurface.withValues(alpha: 0.12))),
      );

  Widget _emptyState(ColorScheme cs) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_showSnoozed ? '📭' : '🎉', style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text(
                _showSnoozed
                    ? 'مفيش طلاب مؤجَّلين دلوقتي'
                    : 'مفيش طلاب محتاجين متابعة دلوقتي',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.55))),
          ]),
        ),
      );

  Widget _card(ColorScheme cs, AtRiskStudent e, {StudentFollowUp? followUp}) {
    final phone = e.guardianPhone;
    final hasPhone = phone != null && phone.trim().isNotEmpty;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.onSurface.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(e.student.name,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
                if (e.group != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(e.group!.name,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.7))),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final sig in e.signals)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                    ),
                    child: Text(sig.reasonText,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB91C1C))),
                  ),
              ],
            ),
            if (followUp != null) ...[
              const SizedBox(height: 6),
              Text(
                'آخر متابعة: ${DateFormat('yyyy/MM/dd').format(followUp.acknowledgedAt)}'
                '${(followUp.note?.trim().isNotEmpty ?? false) ? " — ${followUp.note!.trim()}" : ""}',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (_showSnoozed)
                  TextButton.icon(
                    onPressed: () => e.student.id == null
                        ? null
                        : controller.unacknowledge(e.student.id!),
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('رجّعه للقائمة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _acknowledge(e),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('تمّت المتابعة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'اتصال',
                  icon: const Icon(Icons.phone_rounded, size: 19),
                  color: hasPhone ? Colors.blue : cs.onSurface.withValues(alpha: 0.25),
                  onPressed: hasPhone ? () => _call(phone) : null,
                ),
                IconButton(
                  tooltip: 'واتساب',
                  icon: const Icon(Icons.chat_rounded, size: 19),
                  color: hasPhone ? const Color(0xFF25D366) : cs.onSurface.withValues(alpha: 0.25),
                  onPressed: hasPhone ? () => _whatsapp(e) : null,
                ),
                IconButton(
                  tooltip: 'فتح صفحة الطالب',
                  icon: const Icon(Icons.person_rounded, size: 19),
                  color: AppTheme.primaryColor,
                  onPressed: () => _openStudent(e),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

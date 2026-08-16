// lib/views/team/manage_members_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/custom_dialogs.dart';

class ManageMembersScreen extends StatefulWidget {
  const ManageMembersScreen({super.key});
  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  final _team = TeamModeService();
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _team.listMembers();
    });
  }

  Future<void> _generateInvite() async {
    LoadingDialog.show(context, message: 'جاري التحقق...');
    final (current, max) = await _team.getAssistantCapacity();
    if (!mounted) return;
    LoadingDialog.hide();
    if (current >= max) {
      await _showLimitReachedDialog(max);
      return;
    }
    if (!mounted) return;

    LoadingDialog.show(context, message: 'جاري توليد الكود...');
    final (code, error) = await _team.createInvite();
    if (!mounted) return;
    LoadingDialog.hide();
    if (code == null) {
      ToastHelper.error(error ?? 'تعذر توليد كود الدعوة');
      return;
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('كود الدعوة',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ابعت الكود ده للمساعد — هيدخل بيه من "الانضمام لفريق" بعد ما يسجّل حسابه.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black45),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor,
                        letterSpacing: 3)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ToastHelper.success('تم نسخ الكود');
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('نسخ', style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLimitReachedDialog(int max) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('وصلت للحد الأقصى',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          content: Text(
            'باقتك الحالية بتسمح بـ $max ${max == 1 ? 'مساعد' : 'مساعدين'} بس. '
            'لو عايز تضيف مساعدين أكتر، تواصل مع الدعم.',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openSupportWhatsApp(max);
              },
              icon: const Icon(Icons.chat_rounded, size: 16),
              label: const Text('تواصل عبر واتساب',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSupportWhatsApp(int max) async {
    const supportPhone = '201096066818';
    final message = 'مرحبًا، أنا مدرس بستخدم تطبيق Active Class وعايز أزوّد '
        'عدد المساعدين المسموح لي (وصلت للحد الأقصى الحالي: $max).';
    final uri = Uri.parse(
        'https://wa.me/$supportPhone?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ToastHelper.error('تعذر فتح واتساب');
    }
  }

  Future<void> _removeMember(Map<String, dynamic> m) async {
    final name = (m['display_name'] as String?)?.isNotEmpty == true
        ? m['display_name'] as String
        : (m['phone'] as String? ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إزالة العضو',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text('هل أنت متأكد من إزالة "$name" من الفريق؟',
            style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إزالة', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await _team.removeMember(m['user_id'] as String);
    if (!mounted) return;
    if (error != null) {
      ToastHelper.error(error);
      return;
    }
    ToastHelper.success('تم إزالة العضو');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('إدارة الأعضاء',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'دعوة مساعد جديد',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _generateInvite,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snap.data ?? [];
          if (members.isEmpty) {
            return Center(
              child: Text('لسه مفيش أعضاء',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isDark ? Colors.white38 : Colors.black38)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _MemberCard(
              member: members[i],
              isDark: isDark,
              onChangedPermission: (field, value) async {
                final error = await _team.updateMemberPermission(
                    members[i]['user_id'] as String, field, value);
                if (!mounted) return;
                if (error != null) {
                  ToastHelper.error(error);
                  return;
                }
                _load();
              },
              onRemove: () => _removeMember(members[i]),
            ),
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool isDark;
  final void Function(String field, bool value) onChangedPermission;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.isDark,
    required this.onChangedPermission,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = member['is_owner'] as bool? ?? false;
    final name = (member['display_name'] as String?)?.isNotEmpty == true
        ? member['display_name'] as String
        : 'بدون اسم';
    final phone = member['phone'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                child: Text(name.characters.first,
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87)),
                    Text(phone,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black45)),
                  ],
                ),
              ),
              if (isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('المدرس',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor)),
                )
              else
                IconButton(
                  tooltip: 'إزالة',
                  icon: const Icon(Icons.person_remove_rounded,
                      color: Colors.red, size: 20),
                  onPressed: onRemove,
                ),
            ],
          ),
          if (!isOwner) ...[
            const Divider(height: 24),
            _PermSwitch(
              label: 'حذف سجلات الحضور',
              value: member['can_delete_attendance'] as bool? ?? false,
              onChanged: (v) => onChangedPermission('can_delete_attendance', v),
              isDark: isDark,
            ),
            _PermSwitch(
              label: 'حذف الدفعات',
              value: member['can_delete_payments'] as bool? ?? false,
              onChanged: (v) => onChangedPermission('can_delete_payments', v),
              isDark: isDark,
            ),
            _PermSwitch(
              label: 'حذف الطلاب/المجموعات',
              value: member['can_delete_students'] as bool? ?? false,
              onChanged: (v) => onChangedPermission('can_delete_students', v),
              isDark: isDark,
            ),
            _PermSwitch(
              label: 'إدارة الأعضاء',
              value: member['can_manage_members'] as bool? ?? false,
              onChanged: (v) => onChangedPermission('can_manage_members', v),
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _PermSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final bool isDark;
  final void Function(bool) onChanged;
  const _PermSwitch({
    required this.label,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87)),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppTheme.primaryColor),
      ],
    );
  }
}

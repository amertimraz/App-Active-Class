// lib/views/team/member_visibility_sheet.dart
//
// spec 058 / P4 — المالك بيحدّد المساعد يشوف إيه: كل المجموعات، أو سناتر/مجموعات معيّنة.
// السنتر ديناميكي: أي مجموعة تتضاف لسنتر ممنوح بتظهر للمساعد تلقائيًا. التطبيق بيبعت
// الاختيار للسيرفر بـRPC ذرّي (set_member_visibility)، والسيرفر هو اللي بيعزل فعليًا.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/sync_visibility.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/widgets/chalk_dialog.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/custom_dialogs.dart';

/// بيفتح نافذة تحديد الرؤية. بيرجّع true لو اتحفظ فعلًا.
Future<bool> showMemberVisibilityDialog(
  BuildContext context, {
  required String userId,
  required String memberName,
  required bool restricted,
}) async {
  final team = TeamModeService();
  final groups = Get.isRegistered<GroupController>()
      ? Get.find<GroupController>().groups.toList()
      : <Group>[];
  final remoteIds = await DatabaseService().getGroupRemoteIds();
  final current = await team.memberVisibility(userId, restricted: restricted);
  if (!context.mounted) return false;
  if (current == null) {
    ToastHelper.error('تعذّر تحميل الصلاحيات الحالية — تأكد من الإنترنت');
    return false;
  }
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _MemberVisibilityDialog(
      userId: userId,
      memberName: memberName,
      groups: groups,
      remoteIds: remoteIds,
      initial: current,
    ),
  );
  return saved == true;
}

class _MemberVisibilityDialog extends StatefulWidget {
  final String userId;
  final String memberName;
  final List<Group> groups;
  final Map<int, String> remoteIds;
  final MemberVisibility initial;
  const _MemberVisibilityDialog({
    required this.userId,
    required this.memberName,
    required this.groups,
    required this.remoteIds,
    required this.initial,
  });

  @override
  State<_MemberVisibilityDialog> createState() =>
      _MemberVisibilityDialogState();
}

class _MemberVisibilityDialogState extends State<_MemberVisibilityDialog> {
  late bool _restricted = widget.initial.restricted;
  late final Set<String> _centers = {...widget.initial.centers};
  late final Set<String> _groupIds = {...widget.initial.groupRemoteIds};
  bool _saving = false;

  List<String> get _allCenters => GroupController.centersOf(widget.groups);

  String? _remoteOf(Group g) => g.id == null ? null : widget.remoteIds[g.id];

  bool _coveredByCenter(Group g) {
    final c = GroupController.normalizeCenter(g.center);
    return c != null && _centers.contains(c);
  }

  MemberVisibility get _value => MemberVisibility(
        restricted: _restricted,
        centers: _restricted ? _centers : const {},
        groupRemoteIds: _restricted ? _groupIds : const {},
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await TeamModeService().setMemberVisibility(widget.userId, _value);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ToastHelper.error(err);
      return;
    }
    ToastHelper.success('اتحفظت صلاحيات ${widget.memberName}');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final centers = _allCenters;
    final v = _value;
    return ChalkDialog(
      icon: Icons.visibility_rounded,
      title: 'المجموعات المسموحة',
      subtitle: widget.memberName,
      body: [
        RadioListTile<bool>(
          contentPadding: EdgeInsets.zero,
          value: false,
          groupValue: _restricted,
          onChanged: (x) => setState(() => _restricted = x ?? false),
          title: Text('كل المجموعات', style: AppType.body.copyWith(color: t.ink)),
          subtitle: Text('يشوف كل الطلاب والمجموعات (زي الوضع الحالي).',
              style: AppType.caption.copyWith(color: t.inkSoft)),
        ),
        RadioListTile<bool>(
          contentPadding: EdgeInsets.zero,
          value: true,
          groupValue: _restricted,
          onChanged: (x) => setState(() => _restricted = x ?? true),
          title: Text('سناتر أو مجموعات معيّنة',
              style: AppType.body.copyWith(color: t.ink)),
          subtitle: Text(
              'بياناتهم بس هي اللي بتنزل على جهازه، والباقي ما بيوصلوش له أصلًا.',
              style: AppType.caption.copyWith(color: t.inkSoft)),
        ),
        if (_restricted) ...[
          const SizedBox(height: AppSpace.sm),
          if (centers.isNotEmpty) ...[
            Text('السناتر (أي مجموعة تتضاف للسنتر تظهر له تلقائيًا)',
                style: AppType.label.copyWith(color: t.ink)),
            for (final c in centers)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _centers.contains(c),
                onChanged: (x) => setState(() {
                  x == true ? _centers.add(c) : _centers.remove(c);
                }),
                title: Text(c, style: AppType.body.copyWith(color: t.ink)),
              ),
            const SizedBox(height: AppSpace.sm),
          ],
          Text('مجموعات بعينها', style: AppType.label.copyWith(color: t.ink)),
          if (widget.groups.isEmpty)
            Text('مفيش مجموعات لسه.',
                style: AppType.caption.copyWith(color: t.inkSoft)),
          for (final g in widget.groups)
            Builder(builder: (_) {
              final remote = _remoteOf(g);
              final covered = _coveredByCenter(g);
              final enabled = remote != null && !covered;
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: covered || (remote != null && _groupIds.contains(remote)),
                onChanged: enabled
                    ? (x) => setState(() {
                          x == true ? _groupIds.add(remote) : _groupIds.remove(remote);
                        })
                    : null,
                title: Text(g.name, style: AppType.body.copyWith(color: t.ink)),
                subtitle: covered
                    ? Text('ظاهرة من السنتر',
                        style: AppType.caption.copyWith(color: t.inkSoft))
                    : remote == null
                        ? Text('لسه ما اترفعتش للفريق — استنى المزامنة',
                            style: AppType.caption.copyWith(color: t.caution))
                        : null,
              );
            }),
          if (v.empty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: ChalkRule(
                icon: Icons.block_rounded,
                color: t.caution,
                text: 'ما اخترتش أي سنتر أو مجموعة: المساعد هيتمنع من الدخول '
                    'لحد ما تحدد له مجموعات.',
              ),
            ),
        ],
        const SizedBox(height: AppSpace.sm),
        ChalkRule(
          icon: Icons.info_outline_rounded,
          text: 'اللي نزل على جهازه قبل التقييد بيتمسح من التطبيق عنده، لكن '
              'ما نقدرش نسحب نسخة كان خدها من قبل. التقييد بيحمي من هنا ورايح.',
        ),
      ],
      actions: [
        ChalkAction(
            label: _saving ? 'جاري الحفظ...' : 'حفظ',
            icon: Icons.check_rounded,
            onPressed: () {
              if (!_saving) _save();
            }),
        ChalkAction(
            label: 'إلغاء',
            kind: ChalkActionKind.text,
            onPressed: () => Navigator.pop(context, false)),
      ],
    );
  }
}

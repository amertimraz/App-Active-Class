// lib/views/parent_portal/parent_portal_students_page.dart
//
// طلاب بوابة أولياء الأمور: مين ظاهر لولي أمره ومين لأ (وليه)، وإرسال الرابط
// والكود لولي الأمر بواتساب — لطالب واحد أو لمجموعة محدّدة.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/parent_portal_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/parent_portal_helper.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/edit_student_sheet.dart';

enum _Filter { all, ready, hidden }

class ParentPortalStudentsPage extends StatefulWidget {
  const ParentPortalStudentsPage({super.key});

  @override
  State<ParentPortalStudentsPage> createState() =>
      _ParentPortalStudentsPageState();
}

class _ParentPortalStudentsPageState extends State<ParentPortalStudentsPage> {
  late final StudentController _students = Get.isRegistered<StudentController>()
      ? Get.find<StudentController>()
      : Get.put(StudentController());
  late final GroupController _groups = Get.isRegistered<GroupController>()
      ? Get.find<GroupController>()
      : Get.put(GroupController());
  late final ParentPortalController _portal =
      Get.isRegistered<ParentPortalController>()
          ? Get.find<ParentPortalController>()
          : Get.put(ParentPortalController());

  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  String _query = '';
  final Set<int> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<bool?> _confirmSend(Student s, int i, int total) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('إرسال $i من $total'),
          content: Text('إرسال رابط البوابة وكود ${s.name} لولي أمره؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('إلغاء الكل')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('تخطي')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إرسال')),
          ],
        ),
      );

  Future<void> _sendOne(Student s) async {
    final url = _portal.url;
    if (url.isEmpty) {
      ToastHelper.error('الرابط لسه بيتحمّل — جرّب كمان لحظة');
      return;
    }
    final settings = Get.find<SettingsController>();
    await launchGuardianWhatsapp(
      context: context,
      phone: s.guardianPhone,
      whatsapp: s.guardianWhatsapp,
      message: buildPortalInviteMessage(
        studentName: s.name,
        studentCode: s.code,
        url: url,
        codeOnly: settings.portalCodeOnly.value,
      ),
      dialCode: settings.countryDial.value,
    );
  }

  Future<void> _sendSelected(List<Student> all) async {
    final queue = all.where((s) => _selected.contains(s.id)).toList();
    if (queue.isEmpty) return;
    final withContact = queue.where(portalHasContact).toList();
    final skipped = queue.length - withContact.length;
    if (withContact.isEmpty) {
      ToastHelper.error('لا يوجد أرقام أولياء أمور للطلاب المحددين');
      return;
    }
    for (var i = 0; i < withContact.length; i++) {
      final proceed = await _confirmSend(withContact[i], i + 1, withContact.length);
      if (proceed == null) break;
      if (proceed) {
        if (!mounted) return;
        await _sendOne(withContact[i]);
      }
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(_selected.clear);
    ToastHelper.success(skipped > 0
        ? 'تم الإرسال — $skipped طالب بدون رقم ولي أمر اتخطّى'
        : 'تم الإرسال');
  }

  void _addPhone(Student s) {
    showEditStudentSheet(
      context,
      student: s,
      accentColor: context.tokens.brand,
      controller: _students,
      groups: _groups.groups.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final on = AppTokens.dark;
    final settings = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'طلاب البوابة'),
      body: Obx(() {
        final codeOnly = settings.portalCodeOnly.value;
        final all = _students.students.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final counts = portalCounts(all, codeOnly: codeOnly);
        final groupById = {
          for (final g in _groups.groups)
            if (g.id != null) g.id!: g.name
        };
        final q = _query.trim().toLowerCase();
        bool isReady(Student s) =>
            portalStudentState(s, codeOnly: codeOnly) ==
            PortalStudentState.ready;
        final shown = all.where((s) {
          if (_filter == _Filter.ready && !isReady(s)) return false;
          if (_filter == _Filter.hidden && isReady(s)) return false;
          if (q.isNotEmpty &&
              !s.name.toLowerCase().contains(q) &&
              !s.code.toLowerCase().contains(q)) {
            return false;
          }
          return true;
        }).toList();
        // اللي ينفع نبعتلهم: ظاهرين وعندهم وسيلة تواصل.
        final sendable = shown.where((s) => isReady(s) && portalHasContact(s)).toList();
        final sendableIds = [for (final s in sendable) s.id!];
        final allSelected =
            sendableIds.isNotEmpty && sendableIds.every(_selected.contains);
        final selectedCount =
            sendable.where((s) => _selected.contains(s.id)).length;

        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
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
                        label: 'ظاهر',
                        value: '${counts.ready}',
                        color: on.positive)),
                Expanded(
                    child: BoardStat(
                        label: 'مش ظاهر',
                        value: '${counts.hidden}',
                        color: counts.hidden > 0 ? t.chalk : t.boardInkSoft)),
                Expanded(
                    child: BoardStat(
                        label: 'الكل',
                        value: '${counts.total}',
                        color: t.boardInk)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xs),
              child: CustomSearchBar(
                controller: _search,
                hintText: 'ابحث باسم الطالب أو الكود',
                onChanged: (v) => setState(() => _query = v),
                onClear: () => setState(() {
                  _query = '';
                  _search.clear();
                }),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xs),
              child: Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                AppFilterChip(
                    label: 'الكل (${counts.total})',
                    selected: _filter == _Filter.all,
                    color: t.brand,
                    onTap: () => setState(() {
                          _filter = _Filter.all;
                          _selected.clear();
                        })),
                AppFilterChip(
                    label: 'ظاهر (${counts.ready})',
                    selected: _filter == _Filter.ready,
                    color: t.positive,
                    onTap: () => setState(() {
                          _filter = _Filter.ready;
                          _selected.clear();
                        })),
                AppFilterChip(
                    label: 'مش ظاهر (${counts.hidden})',
                    selected: _filter == _Filter.hidden,
                    color: t.caution,
                    onTap: () => setState(() {
                          _filter = _Filter.hidden;
                          _selected.clear();
                        })),
              ]),
            ),
          ),
          if (sendable.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.xs, AppSpace.lg, 0),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: AppSpace.sm,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() {
                        if (allSelected) {
                          _selected.removeAll(sendableIds);
                        } else {
                          _selected.addAll(sendableIds);
                        }
                      }),
                      style: TextButton.styleFrom(
                          foregroundColor: t.brand,
                          minimumSize: const Size(48, 44)),
                      icon: Icon(
                          allSelected
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 20),
                      label: Text(allSelected ? 'إلغاء التحديد' : 'تحديد الكل',
                          style: AppType.body
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                    FilledButton.icon(
                      onPressed: selectedCount == 0
                          ? null
                          : () => _sendSelected(sendable),
                      style: FilledButton.styleFrom(
                        backgroundColor: t.positive,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: Text('ابعت الرابط والكود ($selectedCount)',
                          style: AppType.label),
                    ),
                  ],
                ),
              ),
            ),
          if (shown.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                  icon: Icons.groups_rounded,
                  title: all.isEmpty ? 'مفيش طلاب' : 'مفيش طلاب مطابقين',
                  subtitle: all.isEmpty
                      ? 'أضف طلابك الأول عشان يظهروا لأولياء الأمور'
                      : 'غيّر التصفية أو البحث'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.lg),
              sliver: SliverList.separated(
                itemCount: shown.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
                itemBuilder: (_, i) {
                  final s = shown[i];
                  return _StudentRow(
                    student: s,
                    groupName: groupById[s.groupId],
                    state: portalStudentState(s, codeOnly: codeOnly),
                    selectable: isReady(s) && portalHasContact(s),
                    selected: _selected.contains(s.id),
                    onSelect: (v) => setState(() {
                      if (v == true) {
                        _selected.add(s.id!);
                      } else {
                        _selected.remove(s.id);
                      }
                    }),
                    onSend: () => _sendOne(s),
                    onAddPhone: () => _addPhone(s),
                  );
                },
              ),
            ),
        ]);
      }),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final Student student;
  final String? groupName;
  final PortalStudentState state;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool?> onSelect;
  final VoidCallback onSend;
  final VoidCallback onAddPhone;

  const _StudentRow({
    required this.student,
    required this.groupName,
    required this.state,
    required this.selectable,
    required this.selected,
    required this.onSelect,
    required this.onSend,
    required this.onAddPhone,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ready = state == PortalStudentState.ready;
    final hasContact = portalHasContact(student);
    final ink = ready ? t.positive : t.caution;
    final soft = ready ? t.positiveSoft : t.cautionSoft;
    final label = switch (state) {
      PortalStudentState.ready => 'ظاهر',
      PortalStudentState.noPhone => 'بلا رقم ولي أمر',
      PortalStudentState.noCode => 'بلا كود',
    };

    return AppPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpace.sm, AppSpace.md, AppSpace.sm, AppSpace.md),
      child: Row(children: [
        if (selectable)
          Checkbox(
            value: selected,
            activeColor: t.brand,
            checkColor: Colors.white,
            onChanged: onSelect,
          )
        else
          const SizedBox(width: AppSpace.sm),
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(student.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(color: t.ink)),
              const SizedBox(height: 2),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (groupName != null)
                    Text(groupName!,
                        style: AppType.caption.copyWith(color: t.inkSoft)),
                  Text('الكود ${student.code}',
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm, vertical: 1),
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(label,
                        style: AppType.caption.copyWith(
                            fontWeight: FontWeight.w700, color: ink)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (ready && hasContact)
          IconButton(
            tooltip: 'ابعت الرابط والكود لولي الأمر',
            icon: const Icon(Icons.chat_rounded),
            color: t.positive,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onSend,
          )
        else if (state != PortalStudentState.noCode)
          // مفيش رقم نبعت عليه (أو مش ظاهر بسببه): نفتح تعديل الطالب يضيفه.
          TextButton(
            onPressed: onAddPhone,
            style: TextButton.styleFrom(
                foregroundColor: t.brand, minimumSize: const Size(48, 44)),
            child: Text('أضف رقم',
                style: AppType.body.copyWith(fontWeight: FontWeight.w700)),
          )
        else
          IconButton(
            tooltip: 'عدّل بيانات الطالب',
            icon: const Icon(Icons.edit_rounded),
            color: t.inkSoft,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onAddPhone,
          ),
      ]),
    );
  }
}

// lib/widgets/session_override_widgets.dart
//
// spec 032 — عناصر واجهة إلغاء/تعويض الحصة: قائمة إجراءات في رأس موديل
// الحضور + بانر الحالة. المنطق كله في SessionOverrideController.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/session_override_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/session_override_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/widgets/app_toast.dart';

SessionOverrideController get _so => Get.find<SessionOverrideController>();

String _ar(DateTime d) => DateFormat('EEEE، d MMMM', 'ar').format(d);

/// زر قائمة (⋮) بإجراءات إلغاء/تعويض الحصة لمجموعة في يوم معيّن.
class SessionOverrideMenuButton extends StatelessWidget {
  final Group group;
  final DateTime day;
  final AttendanceController attCtrl;
  const SessionOverrideMenuButton({
    super.key,
    required this.group,
    required this.day,
    required this.attCtrl,
  });

  bool get _scheduleHasSession {
    // نتحقّق من الجدول فقط (قبل الاستثناء) — لو مفيش جدول أصلًا نعتبرها
    // "فيها حصة" زي groupHasSessionOnDay القديمة.
    final s = group.schedule?.trim() ?? '';
    if (s.isEmpty) return true;
    return attCtrl.groupHasSessionOnDayScheduleOnly(group, day);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final override =
          group.id == null ? null : _so.overrideFor(group.id!, day);
      final canDelete = TeamModeService().canDeleteAttendanceNow;
      final items = <PopupMenuEntry<String>>[];

      if (override == null) {
        if (_scheduleHasSession && canDelete) {
          items.add(const PopupMenuItem(
              value: 'cancel', child: Text('إلغاء حصة اليوم')));
        }
      } else if (override.type == SessionOverrideType.cancelled) {
        if (canDelete) {
          items.add(const PopupMenuItem(
              value: 'undo', child: Text('تراجع عن الإلغاء')));
        }
      } else {
        items.add(const PopupMenuItem(
            value: 'undo', child: Text('حذف الحصة الاستثنائية')));
      }

      if (items.isEmpty) return const SizedBox.shrink();

      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded),
        tooltip: 'إجراءات الحصة',
        itemBuilder: (_) => items,
        onSelected: (v) => _handle(context, v, override),
      );
    });
  }

  Future<void> _handle(
      BuildContext context, String action, SessionOverride? override) async {
    switch (action) {
      case 'cancel':
        await _doCancel(context);
        break;
      case 'undo':
        if (override != null) {
          if (override.type == SessionOverrideType.cancelled) {
            final done = await confirmUndoSessionCancel(context, override);
            if (context.mounted && done) _toast(context, 'رجعت الحصة');
          } else {
            final err = await _so.removeOverride(override);
            if (context.mounted) {
              _toast(context, err ?? 'اتحذفت الحصة الاستثنائية');
            }
          }
          await attCtrl.loadAttendance();
        }
        break;
    }
  }

  Future<void> _doCancel(BuildContext context) async {
    final n =
        await DatabaseService().countAttendanceForGroupOnDay(group.id!, day);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء حصة اليوم'),
        content: Text(n > 0
            ? 'فيه $n سجل حضور مسجّل النهارده — الإلغاء هيمسحهم، ومش هيرجعوا لو '
                'تراجعت بعد كده. تمام؟'
            : 'الحصة هتختفي من حضور اليوم ومن العدّ المتوقّع. تمام؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لأ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(n > 0 ? 'إلغاء الحصة ومسح الحضور' : 'إلغاء الحصة')),
        ],
      ),
    );
    if (ok != true) return;
    if (n > 0) {
      await DatabaseService().deleteAttendanceForGroupOnDay(group.id!, day);
      await attCtrl.loadAttendance();
    }
    if (!context.mounted) return;
    final err = await _so.cancelToday(
        group: group, day: day, scheduleHasSession: _scheduleHasSession);
    await attCtrl.loadAttendance();
    if (context.mounted) _toast(context, err ?? 'تم إلغاء حصة اليوم');
  }

  void _toast(BuildContext context, String msg) => AppToast.info(context, msg);
}

/// يؤكّد التراجع عن إلغاء حصة (بتحذير إن الحضور اللي كان مسجّل قبل
/// الإلغاء مش هيرجع)، ثم يحذف استثناء الإلغاء. يرجّع true لو اتعمل.
Future<bool> confirmUndoSessionCancel(
    BuildContext context, SessionOverride cancelled) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('ترجّع الحصة؟'),
      content: const Text(
          'الحصة هتتفتح تاني وتقدر تسجّل حضورها.\n\n'
          'لو كان فيه حضور مسجّل قبل الإلغاء — مش هيرجع، هتحتاج تسجّله من الأول.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لأ')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رجّع الحصة')),
      ],
    ),
  );
  if (ok != true) return false;
  final err = await _so.removeOverride(cancelled);
  if (context.mounted && err != null) {
    AppToast.error(context, err);
    return false;
  }
  return true;
}

/// فورم واحد لإضافة حصة استثنائية (تعويضية/إضافية) — بدل سلسلة حوارات.
Future<void> showAddSessionOverrideFlow(
  BuildContext context, {
  required List<Group> groups,
  required DateTime day,
}) async {
  if (groups.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddSessionOverrideSheet(groups: groups, initialDay: day),
  );
}

class _AddSessionOverrideSheet extends StatefulWidget {
  final List<Group> groups;
  final DateTime initialDay;
  const _AddSessionOverrideSheet(
      {required this.groups, required this.initialDay});

  @override
  State<_AddSessionOverrideSheet> createState() =>
      _AddSessionOverrideSheetState();
}

class _AddSessionOverrideSheetState extends State<_AddSessionOverrideSheet> {
  Group? _group;
  SessionOverrideType _type = SessionOverrideType.makeup;
  DateTime? _sessionDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _compensates;
  bool _saving = false;

  static const _primary = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    if (widget.groups.length == 1) _group = widget.groups.first;
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    _sessionDate =
        widget.initialDay.isBefore(t0) ? t0 : widget.initialDay;
  }

  bool get _valid =>
      _group != null &&
      _sessionDate != null &&
      _startTime != null &&
      _endTime != null &&
      (_type == SessionOverrideType.extra || _compensates != null);

  Future<void> _pickSessionDate() async {
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final p = await showDatePicker(
      context: context,
      initialDate: _sessionDate ?? t0,
      firstDate: t0,
      lastDate: t0.add(const Duration(days: 120)),
      helpText: 'تاريخ الحصة',
    );
    if (p != null) setState(() => _sessionDate = p);
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 16, minute: 0),
      helpText: 'بداية الحصة',
    );
    if (t == null) return;
    setState(() {
      _startTime = t;
      // نهاية افتراضية بعد ساعة — إلا لو المدرّس عدّلها بنفسه.
      final end = TimeOfDay(hour: (t.hour + 1) % 24, minute: t.minute);
      if (_endTime == null || !_endAfterStart(_startTime!, _endTime!)) {
        _endTime = end;
      }
    });
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _endTime ??
          TimeOfDay(
              hour: ((_startTime?.hour ?? 16) + 1) % 24,
              minute: _startTime?.minute ?? 0),
      helpText: 'نهاية الحصة',
    );
    if (t != null) setState(() => _endTime = t);
  }

  bool _endAfterStart(TimeOfDay s, TimeOfDay e) =>
      e.hour * 60 + e.minute > s.hour * 60 + s.minute;

  Future<void> _pickCompensates() async {
    final anchor = _sessionDate ?? DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: _compensates ?? anchor.subtract(const Duration(days: 1)),
      firstDate: DateTime(anchor.year - 1),
      lastDate: anchor,
      helpText: 'يوم الحصة الملغاة',
    );
    if (p != null) setState(() => _compensates = p);
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String? get _timeStr => (_startTime == null || _endTime == null)
      ? null
      : '${_hhmm(_startTime!)}-${_hhmm(_endTime!)}';

  Future<void> _submit() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final String? err;
    if (_type == SessionOverrideType.extra) {
      err = await _so.addExtra(
          group: _group!, day: _sessionDate!, sessionTime: _timeStr);
    } else {
      err = await _so.addMakeup(
          group: _group!,
          day: _sessionDate!,
          compensatesDate: _compensates!,
          sessionTime: _timeStr);
    }
    if (!mounted) return;
    Navigator.pop(context);
    AppToast.info(
        context,
        err ??
            (_type == SessionOverrideType.extra
                ? 'اتضافت حصة إضافية ${_ar(_sessionDate!)}'
                : 'اتضافت حصة تعويضية ${_ar(_sessionDate!)}'));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('إضافة حصة استثنائية',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 16),

            // المجموعة
            DropdownButtonFormField<Group>(
              initialValue: _group,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المجموعة',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final g in widget.groups)
                  DropdownMenuItem(value: g, child: Text(g.name)),
              ],
              onChanged: (g) => setState(() => _group = g),
            ),
            const SizedBox(height: 14),

            // النوع
            SegmentedButton<SessionOverrideType>(
              segments: const [
                ButtonSegment(
                    value: SessionOverrideType.makeup,
                    label: Text('تعويضية عن حصة اتلغت',
                        style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: SessionOverrideType.extra,
                    label: Text('إضافية', style: TextStyle(fontSize: 12))),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 14),

            _DateRow(
              label: 'تاريخ الحصة',
              value: _sessionDate,
              onTap: _pickSessionDate,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _TimeRow(
                  label: 'من',
                  value: _startTime,
                  onTap: _pickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeRow(
                  label: 'إلى',
                  value: _endTime,
                  onTap: _pickEnd,
                ),
              ),
            ]),
            if (_type == SessionOverrideType.makeup) ...[
              const SizedBox(height: 10),
              _DateRow(
                label: 'بتعوّض عن يوم',
                value: _compensates,
                hint: 'اختر يوم الحصة اللي اتلغت',
                onTap: _pickCompensates,
              ),
            ],
            const SizedBox(height: 20),

            SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _primary),
                onPressed: _valid && !_saving ? _submit : null,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إضافة الحصة',
                        style: TextStyle(
                            fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;
  const _TimeRow(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, size: 16),
          const SizedBox(width: 6),
          Text('$label ',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          Expanded(
            child: Text(
              value != null ? value!.format(context) : '--:--',
              style: TextStyle(
                  fontSize: 12.5,
                  color: value != null ? null : Colors.grey.shade500),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String? hint;
  final VoidCallback onTap;
  const _DateRow(
      {required this.label, required this.value, required this.onTap, this.hint});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE d MMMM', 'ar');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(children: [
          const Icon(Icons.event_rounded, size: 18),
          const SizedBox(width: 10),
          Text('$label:',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value != null ? df.format(value!) : (hint ?? 'اختر'),
              style: TextStyle(
                  fontSize: 12.5,
                  color: value != null ? null : Colors.grey.shade500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

/// بانر يوضّح حالة الاستثناء أعلى موديل الحضور.
class SessionOverrideBanner extends StatelessWidget {
  final SessionOverride ovr;
  const SessionOverrideBanner({super.key, required this.ovr});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;
    switch (ovr.type) {
      case SessionOverrideType.cancelled:
        color = const Color(0xFFEF4444);
        icon = Icons.event_busy_rounded;
        text = 'الحصة اتلغت النهارده';
        break;
      case SessionOverrideType.makeup:
        color = const Color(0xFF10B981);
        icon = Icons.event_available_rounded;
        text = ovr.compensatesDate != null
            ? 'حصة تعويضية عن ${_ar(ovr.compensatesDate!)}'
            : 'حصة تعويضية';
        break;
      case SessionOverrideType.extra:
        color = const Color(0xFF6366F1);
        icon = Icons.add_circle_outline_rounded;
        text = 'حصة إضافية';
        break;
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ]),
    );
  }
}

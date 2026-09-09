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
        items.add(const PopupMenuItem(
            value: 'makeup', child: Text('حصة تعويضية عن يوم')));
        items.add(const PopupMenuItem(
            value: 'extra', child: Text('حصة إضافية')));
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
      case 'makeup':
        await _doMakeup(context);
        break;
      case 'extra':
        final err = await _so.addExtra(group: group, day: day);
        if (context.mounted) _toast(context, err ?? 'تمت إضافة حصة إضافية');
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

  Future<void> _doMakeup(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day.subtract(const Duration(days: 1)),
      firstDate: DateTime(day.year - 1),
      lastDate: day,
      helpText: 'الحصة الملغاة اللي بنعوّضها',
    );
    if (picked == null || !context.mounted) return;
    final err = await _so.addMakeup(
        group: group, day: day, compensatesDate: picked);
    if (context.mounted) {
      _toast(context, err ?? 'تمت إضافة حصة تعويضية عن ${_ar(picked)}');
    }
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

/// تدفّق إضافة حصة استثنائية (تعويضية/إضافية):
/// المجموعة → النوع → تاريخ الحصة (يقبل أيام مستقبلية) → (للتعويضية)
/// تاريخ الحصة الملغاة اللي بنعوّضها.
Future<void> showAddSessionOverrideFlow(
  BuildContext context, {
  required List<Group> groups,
  required DateTime day,
}) async {
  if (groups.isEmpty) return;
  final group = await showDialog<Group>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('اختر المجموعة'),
      children: [
        for (final g in groups)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, g),
            child: Text(g.name),
          ),
      ],
    ),
  );
  if (group == null || !context.mounted) return;

  final type = await showDialog<SessionOverrideType>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('نوع الحصة'),
      children: [
        SimpleDialogOption(
          onPressed: () =>
              Navigator.pop(context, SessionOverrideType.makeup),
          child: const Text('تعويضية عن حصة اتلغت'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, SessionOverrideType.extra),
          child: const Text('إضافية'),
        ),
      ],
    ),
  );
  if (type == null || !context.mounted) return;

  // تاريخ الحصة نفسها — يقبل أيام مستقبلية (زي ما اتفقت مع الطلاب على
  // الواتس إنهم ييجوا يوم كذا).
  final today = DateTime.now();
  final sessionDate = await showDatePicker(
    context: context,
    initialDate: day.isBefore(DateTime(today.year, today.month, today.day))
        ? DateTime(today.year, today.month, today.day)
        : day,
    firstDate: DateTime(today.year, today.month, today.day),
    lastDate: today.add(const Duration(days: 120)),
    helpText: type == SessionOverrideType.makeup
        ? 'امتى الحصة التعويضية؟'
        : 'امتى الحصة الإضافية؟',
  );
  if (sessionDate == null || !context.mounted) return;

  if (type == SessionOverrideType.extra) {
    final err = await _so.addExtra(group: group, day: sessionDate);
    if (context.mounted) {
      AppToast.info(context, err ?? 'اتضافت حصة إضافية ${_ar(sessionDate)}');
    }
    return;
  }

  final compensates = await showDatePicker(
    context: context,
    initialDate: sessionDate.subtract(const Duration(days: 1)),
    firstDate: DateTime(sessionDate.year - 1),
    lastDate: sessionDate,
    helpText: 'الحصة الملغاة اللي بنعوّضها',
  );
  if (compensates == null || !context.mounted) return;
  final err = await _so.addMakeup(
      group: group, day: sessionDate, compensatesDate: compensates);
  if (context.mounted) {
    AppToast.info(context,
        err ?? 'اتضافت حصة تعويضية ${_ar(sessionDate)} عن ${_ar(compensates)}');
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

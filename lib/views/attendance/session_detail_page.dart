// lib/views/attendance/session_detail_page.dart
//
// spec 053 — تفاصيل الحصة (مجموعة + تاريخ): ملخص حاضر/متأخر/غائب/لم يُسجَّل،
// تبويبات تصفية وبحث، الغايبون في خانة لوحدهم مع إرسال واتساب، وتسجيل/
// تعديل الحضور. بدون أي بيانات أو مزامنة جديدة — نفس AttendanceController.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/session_override_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/absence_message.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/session_attendance.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/views/attendance/attendance_page.dart'
    show showAttendanceSheet;
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/widgets/custom_widgets.dart';

const _kPresentColor = Color(0xFF10B981);
const _kLateColor = Color(0xFFF59E0B);
const _kAbsentColor = Color(0xFFEF4444);
const _kUnrecordedColor = Color(0xFF6B7280);

// ألوان الخلفية للزرار المختار — أغمق عشان النص الأبيض يعدّي تباين 4.5:1
// (الأصفر بنص غامق بدل الأبيض).
const _kPresentFill = Color(0xFF047857);
const _kLateFill = Color(0xFFF59E0B);
const _kAbsentFill = Color(0xFFDC2626);

T _find<T extends GetxController>(T Function() create) =>
    Get.isRegistered<T>() ? Get.find<T>() : Get.put(create());

class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({super.key, required this.group, required this.day});

  final Group group;
  final DateTime day;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late final AttendanceController _att = _find(() => AttendanceController());
  late final StudentController _students = _find(() => StudentController());

  final _search = TextEditingController();
  SessionFilter _filter = SessionFilter.all;
  String _query = '';
  final Set<int> _selected = {};
  bool _loading = true;

  DateTime get _day =>
      DateTime(widget.day.year, widget.day.month, widget.day.day);

  bool get _isFuture {
    final n = DateTime.now();
    return _day.isAfter(DateTime(n.year, n.month, n.day));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _students.loadAllStudents();
    await _att.loadAttendance();
    if (mounted) setState(() => _loading = false);
  }

  List<SessionRow> _allRows() => buildSessionRows(
        students: [..._students.students, ..._students.archivedStudents]
            .where((s) => s.groupId == widget.group.id),
        records: _att.attendance,
        day: _day,
      );

  SessionOverrideType? get _overrideType =>
      _att.sessionOverrideFor(widget.group, _day)?.type;

  Future<void> _setStatus(Student s, String? current, String target) async {
    if (s.id == null) return;
    try {
      // الضغط على الحالة المختارة تاني بيلغي السجل → "لم يُسجَّل".
      await _att.setAttendanceStatus(
          s.id!, _day, current == target ? null : target);
    } catch (_) {
      ToastHelper.error('تعذّر حفظ الحضور');
    }
  }

  Future<void> _markUnrecorded(List<SessionRow> unrecorded) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحضير غير المسجَّلين'),
        content: Text(
            'هيتسجّل ${unrecorded.length} طالب "حاضر". اللي اتسجّل قبل كده مش هيتغيّر.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تحضير')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _att.markGroupAllPresent(
          [for (final r in unrecorded) r.student.id!], _day);
    } catch (_) {
      ToastHelper.error('تعذّر التحضير');
    }
  }

  bool _hasContact(Student s) =>
      (s.guardianPhone ?? '').trim().isNotEmpty ||
      (s.guardianWhatsapp ?? '').trim().isNotEmpty;

  Future<bool?> _confirmSend(Student s, int i, int total) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('إرسال $i من $total'),
          content: Text('إرسال رسالة غياب لولي أمر ${s.name}؟'),
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

  Future<void> _sendAbsences(List<SessionRow> absent) async {
    final queue = absent.where((r) => _selected.contains(r.student.id)).toList();
    if (queue.isEmpty) return;
    final withContact = queue.where((r) => _hasContact(r.student)).toList();
    final skipped = queue.length - withContact.length;
    if (withContact.isEmpty) {
      AppToast.warning(context, 'لا يوجد أرقام أولياء أمور للطلاب المحددين');
      return;
    }
    final settings = Get.find<SettingsController>();
    for (var i = 0; i < withContact.length; i++) {
      final s = withContact[i].student;
      final proceed = await _confirmSend(s, i + 1, withContact.length);
      if (proceed == null) break;
      if (proceed) {
        if (!mounted) return;
        await launchGuardianWhatsapp(
          context: context,
          phone: s.guardianPhone,
          whatsapp: s.guardianWhatsapp,
          message: buildAbsenceMessage(
            studentName: s.name,
            studentCode: s.code,
            groupName: widget.group.name,
            date: _day,
            teacherName: settings.teacherFullName.value.trim(),
            teacherSpecialization: settings.teacherSpecialization.value.trim(),
          ),
          dialCode: settings.countryDial.value,
        );
      }
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(_selected.clear);
    AppToast.success(context, 'تم الإرسال',
        subtitle: skipped > 0 ? '$skipped طالب بدون رقم ولي أمر تم تخطيه' : null);
  }

  void _openFullSheet() {
    showAttendanceSheet(
      context,
      group: widget.group,
      selectedDay: _day,
      studentCtrl: _students,
      controller: _att,
      homeworkCtrl: _find(() => HomeworkController()),
      alreadySentReport: false,
      onReportSent: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateLabel = DateFormat('EEEE d MMMM yyyy', 'ar').format(_day);
    final time = _att.sessionTimeForGroupOnDay(widget.group, _day);
    return Scaffold(
      appBar: buildGradientAppBar(
        title: widget.group.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _load,
          ),
        ],
      ),
      body: buildSoftBackground(
        context: context,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Obx(() {
                // تبعيات Obx: السجلات + الطلاب (تحديث فوري بعد كل ضغطة).
                final rows = _allRows();
                final cancelled = _overrideType == SessionOverrideType.cancelled;
                final summary = summarizeSession(rows);
                final shown =
                    filterSessionRows(rows, _filter, query: _query);
                final editable = !_isFuture && !cancelled;
                final unrecorded =
                    rows.where((r) => r.status == null).toList();
                final absentShown = _filter == SessionFilter.absent;

                return Column(children: [
                  _header(dateLabel, time, _overrideType, isDark),
                  if (cancelled)
                    _banner('الحصة دي ملغاة — مفيش حضور ليها', _kAbsentColor)
                  else if (_isFuture)
                    _banner('لسه ما بدأتش — للعرض فقط', _kUnrecordedColor)
                  else
                    _summaryCard(summary, isDark),
                  if (!cancelled) _filters(summary),
                  if (!cancelled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
                  if (absentShown && shown.isNotEmpty) _absentBar(shown),
                  Expanded(
                    child: cancelled
                        ? const SizedBox.shrink()
                        : shown.isEmpty
                            ? EmptyState(
                                icon: Icons.groups_rounded,
                                title: rows.isEmpty
                                    ? 'مفيش طلاب'
                                    : 'مفيش طلاب مطابقين',
                                subtitle: rows.isEmpty
                                    ? 'المجموعة دي مفيهاش طلاب في الحصة دي'
                                    : 'غيّر التصفية أو البحث')
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 100),
                                itemCount: shown.length,
                                itemBuilder: (_, i) =>
                                    _row(shown[i], editable, absentShown),
                              ),
                  ),
                  if (editable) _bottomBar(unrecorded),
                ]);
              }),
      ),
    );
  }

  Widget _header(String date, String? time, SessionOverrideType? o, bool dark) {
    String? tag;
    Color tagColor = _kUnrecordedColor;
    switch (o) {
      case SessionOverrideType.cancelled:
        tag = 'ملغاة';
        tagColor = _kAbsentColor;
      case SessionOverrideType.makeup:
        tag = 'تعويضية';
        tagColor = _kPresentColor;
      case SessionOverrideType.extra:
        tag = 'إضافية';
        tagColor = const Color(0xFF6366F1);
      case null:
        break;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        const Icon(Icons.event_rounded, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(time == null ? date : '$date • $time',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        if (tag != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(tag,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: tagColor)),
          ),
      ]),
    );
  }

  Widget _banner(String text, Color color) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text,
            style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      );

  Widget _summaryCard(SessionSummary s, bool dark) {
    Widget stat(String label, int n, Color c) => Expanded(
          child: Column(children: [
            Text('$n',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: c)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        );
    final rate = s.total == 0 ? 0.0 : s.attended / s.total;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Row(children: [
          stat('حاضر', s.present, _kPresentColor),
          stat('متأخر', s.late, _kLateColor),
          stat('غائب', s.absent, _kAbsentColor),
          stat('لم يُسجَّل', s.unrecorded, _kUnrecordedColor),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 6,
                    backgroundColor: _kAbsentColor.withValues(alpha: 0.2),
                    color: _kPresentColor),
              ),
            ),
            const SizedBox(width: 8),
            Text('${s.attended}/${s.total}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _filters(SessionSummary s) {
    Widget chip(String label, int n, SessionFilter f, Color c) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: ChoiceChip(
            label: Text('$label ($n)',
                style: const TextStyle(fontSize: 12.5)),
            selected: _filter == f,
            selectedColor: c.withValues(alpha: 0.2),
            onSelected: (_) => setState(() {
              _filter = f;
              _selected.clear();
            }),
          ),
        );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('الكل', s.total, SessionFilter.all, AppTheme.primaryColor),
          chip('غائب', s.absent, SessionFilter.absent, _kAbsentColor),
          chip('لم يُسجَّل', s.unrecorded, SessionFilter.unrecorded,
              _kUnrecordedColor),
          chip('حاضر', s.present, SessionFilter.present, _kPresentColor),
          chip('متأخر', s.late, SessionFilter.late, _kLateColor),
        ],
      ),
    );
  }

  Widget _absentBar(List<SessionRow> shown) {
    final ids = [for (final r in shown) r.student.id!];
    final all = ids.isNotEmpty && ids.every(_selected.contains);
    final n = shown.where((r) => _selected.contains(r.student.id)).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(children: [
        TextButton.icon(
          onPressed: () => setState(() {
            if (all) {
              _selected.removeAll(ids);
            } else {
              _selected.addAll(ids);
            }
          }),
          icon: Icon(
              all ? Icons.deselect_rounded : Icons.select_all_rounded,
              size: 18),
          label: Text(all ? 'إلغاء التحديد' : 'تحديد الكل'),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: n == 0 ? null : () => _sendAbsences(shown),
          icon: const Icon(Icons.chat_rounded, size: 18),
          label: Text('واتساب للغايبين ($n)'),
        ),
      ]),
    );
  }

  Widget _row(SessionRow r, bool editable, bool selectable) {
    final s = r.student;
    Widget seg(String label, String target, Color c) {
      final on = r.status == target;
      final fg = !on
          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
          : (target == ATTENDANCE_LATE ? Colors.black87 : Colors.white);
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: '$label — ${s.name}',
          excludeSemantics: true,
          child: InkWell(
            onTap: editable ? () => _setStatus(s, r.status, target) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              // ارتفاع ≥ 44 عشان هدف اللمس
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: on ? c : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: on ? c : Colors.grey.withValues(alpha: 0.5)),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: fg)),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
            color: switch (r.status) {
          ATTENDANCE_PRESENT => _kPresentColor.withValues(alpha: 0.4),
          ATTENDANCE_LATE => _kLateColor.withValues(alpha: 0.5),
          ATTENDANCE_ABSENT => _kAbsentColor.withValues(alpha: 0.5),
          _ => Colors.grey.withValues(alpha: 0.2),
        }),
      ),
      child: Column(children: [
        Row(children: [
          if (selectable)
            Checkbox(
              value: _selected.contains(s.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(s.id!);
                } else {
                  _selected.remove(s.id);
                }
              }),
            ),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(s.code,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ]),
          ),
          if (r.status == null)
            Text('لم يُسجَّل',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
        if (editable) ...[
          const SizedBox(height: 8),
          Row(children: [
            seg('حاضر', ATTENDANCE_PRESENT, _kPresentFill),
            const SizedBox(width: 8),
            seg('متأخر', ATTENDANCE_LATE, _kLateFill),
            const SizedBox(width: 8),
            seg('غائب', ATTENDANCE_ABSENT, _kAbsentFill),
          ]),
        ],
      ]),
    );
  }

  Widget _bottomBar(List<SessionRow> unrecorded) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    unrecorded.isEmpty ? null : () => _markUnrecorded(unrecorded),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text('تحضير غير المسجَّلين (${unrecorded.length})'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _openFullSheet,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('الورقة الكاملة'),
            ),
          ]),
        ),
      );
}

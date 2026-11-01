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
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/widgets/custom_widgets.dart';

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
    final t = context.tokens;
    final dateLabel = DateFormat('EEEE d MMMM yyyy', 'ar').format(_day);
    final time = _att.sessionTimeForGroupOnDay(widget.group, _day);
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(
        context,
        title: widget.group.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Obx(() {
              // تبعيات Obx: السجلات + الطلاب (تحديث فوري بعد كل ضغطة).
              final rows = _allRows();
              final cancelled = _overrideType == SessionOverrideType.cancelled;
              final summary = summarizeSession(rows);
              final shown = filterSessionRows(rows, _filter, query: _query);
              final editable = !_isFuture && !cancelled;
              final unrecorded = rows.where((r) => r.status == null).toList();
              final absentShown = _filter == SessionFilter.absent;

              // كل حاجة فوق القايمة بتتحرك معاها (CustomScrollView): على
              // الشاشة الصغيرة مع الخط الكبير الأدوات مش بتاكل مكان القايمة.
              // شريط الأسفل بس هو الثابت.
              return Column(children: [
                Expanded(
                  child: CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                      child: Column(children: [
                        _board(dateLabel, time, _overrideType, summary,
                            showSummary: !cancelled && !_isFuture),
                        if (cancelled)
                          _banner('الحصة دي ملغاة — مفيش حضور ليها',
                              Icons.event_busy_rounded, t.danger, t.dangerSoft)
                        else if (_isFuture)
                          _banner('لسه ما بدأتش — للعرض فقط',
                              Icons.schedule_rounded, t.inkSoft, t.line),
                        if (!cancelled) _filters(summary),
                        if (!cancelled)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpace.lg,
                                AppSpace.sm, AppSpace.lg, AppSpace.xs),
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
                      ]),
                    ),
                    if (cancelled)
                      const SliverToBoxAdapter(child: SizedBox.shrink())
                    else if (shown.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                            icon: Icons.groups_rounded,
                            title: rows.isEmpty
                                ? 'مفيش طلاب'
                                : 'مفيش طلاب مطابقين',
                            subtitle: rows.isEmpty
                                ? 'المجموعة دي مفيهاش طلاب في الحصة دي'
                                : 'غيّر التصفية أو البحث'),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.lg,
                            AppSpace.sm, AppSpace.lg, AppSpace.lg),
                        sliver: SliverList.builder(
                          itemCount: shown.length,
                          itemBuilder: (_, i) =>
                              _row(shown[i], editable, absentShown),
                        ),
                      ),
                  ]),
                ),
                if (editable) _bottomBar(unrecorded),
              ]);
            }),
    );
  }

  /// سبورة الصفحة: التاريخ والميعاد ووسم الحصة، وتحتها شريط الحضور
  /// والأرقام (نفس سبورة تبويب التسجيل).
  Widget _board(String date, String? time, SessionOverrideType? o,
      SessionSummary s,
      {required bool showSummary}) {
    final t = context.tokens;
    // ألوان الحالات فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;
    String? tag;
    Color tagInk = t.inkSoft;
    Color tagSoft = t.line;
    switch (o) {
      case SessionOverrideType.cancelled:
        tag = 'ملغاة';
        tagInk = t.danger;
        tagSoft = t.dangerSoft;
      case SessionOverrideType.makeup:
        tag = 'تعويضية';
        tagInk = t.positive;
        tagSoft = t.positiveSoft;
      case SessionOverrideType.extra:
        tag = 'إضافية';
        tagInk = t.brand;
        tagSoft = t.brand.withValues(alpha: 0.12);
      case null:
        break;
    }
    final rate = s.total == 0 ? 0.0 : s.attended / s.total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
      decoration: BoxDecoration(
        color: t.board,
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.board)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.event_rounded, size: 20, color: t.boardInkSoft),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(date, style: AppType.label.copyWith(color: t.boardInk)),
                if (time != null)
                  Text(time,
                      style: AppType.caption.copyWith(color: t.boardInkSoft)),
              ],
            ),
          ),
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm, vertical: 2),
              decoration: BoxDecoration(
                color: tagSoft,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(tag,
                  style: AppType.caption
                      .copyWith(fontWeight: FontWeight.w700, color: tagInk)),
            ),
        ]),
        if (showSummary) ...[
          const SizedBox(height: AppSpace.lg),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 6,
                    backgroundColor: t.boardLine,
                    color: on.positive),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text('${s.attended}/${s.total}',
                style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w700, color: t.boardInk)),
          ]),
          const SizedBox(height: AppSpace.md),
          Row(children: [
            Expanded(
                child: BoardStat(
                    label: 'حاضر', value: '${s.present}', color: on.positive)),
            Expanded(
                child: BoardStat(
                    label: 'متأخر', value: '${s.late}', color: t.chalk)),
            Expanded(
                child: BoardStat(
                    label: 'غائب', value: '${s.absent}', color: on.danger)),
            Expanded(
                child: BoardStat(
                    label: 'لم يُسجَّل',
                    value: '${s.unrecorded}',
                    color: t.boardInkSoft)),
          ]),
        ],
      ]),
    );
  }

  Widget _banner(String text, IconData icon, Color ink, Color soft) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xs),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: ink),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(text,
                  style: AppType.label.copyWith(color: ink)),
            ),
          ]),
        ),
      );

  Widget _filters(SessionSummary s) {
    final t = context.tokens;
    Widget chip(String label, int n, SessionFilter f, Color c) => _FilterChip(
          label: '$label ($n)',
          selected: _filter == f,
          color: c,
          onTap: () => setState(() {
            _filter = f;
            _selected.clear();
          }),
        );
    // Wrap بدل قائمة أفقية: كل الشرائح باينة، وتنزل سطر تاني لو مفيش مكان.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xs),
      child: Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: [
          chip('الكل', s.total, SessionFilter.all, t.brand),
          chip('غائب', s.absent, SessionFilter.absent, t.danger),
          chip('لم يُسجَّل', s.unrecorded, SessionFilter.unrecorded,
              t.inkSoft),
          chip('حاضر', s.present, SessionFilter.present, t.positive),
          chip('متأخر', s.late, SessionFilter.late, t.caution),
        ],
      ),
    );
  }

  Widget _absentBar(List<SessionRow> shown) {
    final t = context.tokens;
    final ids = [for (final r in shown) r.student.id!];
    final all = ids.isNotEmpty && ids.every(_selected.contains);
    final n = shown.where((r) => _selected.contains(r.student.id)).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xs),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: AppSpace.sm,
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              if (all) {
                _selected.removeAll(ids);
              } else {
                _selected.addAll(ids);
              }
            }),
            style: TextButton.styleFrom(
                foregroundColor: t.brand, minimumSize: const Size(48, 44)),
            icon: Icon(
                all ? Icons.deselect_rounded : Icons.select_all_rounded,
                size: 20),
            label: Text(all ? 'إلغاء التحديد' : 'تحديد الكل',
                style: AppType.body.copyWith(fontWeight: FontWeight.w700)),
          ),
          FilledButton.icon(
            onPressed: n == 0 ? null : () => _sendAbsences(shown),
            style: FilledButton.styleFrom(
              backgroundColor: t.positive,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.chat_rounded, size: 20),
            label: Text('واتساب للغايبين ($n)', style: AppType.label),
          ),
        ],
      ),
    );
  }

  Widget _row(SessionRow r, bool editable, bool selectable) {
    final t = context.tokens;
    final s = r.student;
    final norm = r.status;
    final ink = switch (norm) {
      ATTENDANCE_PRESENT => t.positive,
      ATTENDANCE_LATE => t.caution,
      ATTENDANCE_ABSENT => t.danger,
      _ => t.inkFaint,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.control),
          color: t.surface,
          border: Border.all(
              color: norm == null ? t.line : ink, width: norm == null ? 1 : 1.5),
        ),
        child: Column(children: [
          Row(children: [
            if (selectable)
              Checkbox(
                value: _selected.contains(s.id),
                activeColor: t.danger,
                checkColor: Colors.white,
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
                        style: AppType.label.copyWith(color: t.ink)),
                    Text(s.code,
                        style: AppType.caption.copyWith(color: t.inkSoft)),
                  ]),
            ),
            if (norm == null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: t.line,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text('لم يُسجَّل',
                    style: AppType.caption.copyWith(color: t.inkSoft)),
              ),
          ]),
          if (editable) ...[
            const SizedBox(height: AppSpace.sm),
            AppSegmented(
              dense: true,
              value: norm,
              subject: s.name,
              // الضغط على المختار تاني بيرجّع null → نلغي السجل.
              onSelect: (v) => _setStatus(s, norm, v ?? norm ?? ''),
              items: [
                AppSegmentItem(ATTENDANCE_PRESENT, 'حاضر', Icons.check_rounded,
                    t.positive),
                AppSegmentItem(ATTENDANCE_LATE, 'متأخر', Icons.schedule_rounded,
                    t.caution),
                AppSegmentItem(ATTENDANCE_ABSENT, 'غائب', Icons.close_rounded,
                    t.danger),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  Widget _bottomBar(List<SessionRow> unrecorded) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
          child: Row(children: [
            Expanded(
              flex: 5,
              child: FilledButton.icon(
                onPressed:
                    unrecorded.isEmpty ? null : () => _markUnrecorded(unrecorded),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md)),
                icon: const Icon(Icons.done_all_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('تحضير غير المسجَّلين (${unrecorded.length})'),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                onPressed: _openFullSheet,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                    foregroundColor: t.brand,
                    side: BorderSide(color: t.line)),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('الورقة الكاملة'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// شريحة تصفية بلون الحالة (المختارة بإطار ولون خفيف).
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: selected ? color : t.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            // Row مش Center: Center كان بيمطّ الشريحة جوه الـWrap.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: AppType.body.copyWith(
                        color: selected ? color : t.inkSoft,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

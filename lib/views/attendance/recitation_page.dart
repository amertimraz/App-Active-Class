// lib/views/attendance/recitation_page.dart
//
// قائمة التسميع: مجموعات اليوم (أو أي يوم) كل واحدة بدرجتها العظمى (+/−)،
// درجة لكل طالب حضر، تنبيه تراجع (أقل من النص) ونجمة تميّز، وحفظ واحد
// لكل الدرجات. من الشاشة: تقرير PDF أو نص واتساب، وشهادات التميّز، ورسالة
// لولي الأمر. الدرجة بتتحفظ على سجل الحضور (attendance.recitation +
// recitation_max) فبتتزامن زي أي تعديل حضور — مفيش جدول جديد.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:share_plus/share_plus.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/certificate_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/recitation.dart';
import 'package:active_class/utils/recitation_session.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/views/exams/certificates_sheet.dart';
import 'package:active_class/views/help/help_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

String _maxKey(int groupId) => recitationGroupMaxKey(groupId);

class RecitationPage extends StatefulWidget {
  const RecitationPage({super.key});
  @override
  State<RecitationPage> createState() => _RecitationPageState();
}

class _RecitationPageState extends State<RecitationPage> {
  final _att = Get.find<AttendanceController>();
  final _groups = Get.find<GroupController>();
  final _students = Get.find<StudentController>();
  final _db = DatabaseService();

  DateTime _day = _today();
  bool _showAll = false; // كل المجموعات بدل مجموعات اليوم بس
  int? _focusGroup; // فتحناها من حضور اليوم لمجموعة معيّنة
  bool _saving = false;

  /// الدرجة العظمى لكل مجموعة (اللي المدرّس ظبطها في الجلسة دي).
  final Map<int, int> _maxByGroup = {};
  final Map<int, int> _savedMaxByGroup = {}; // من الإعدادات المحلية
  /// تعديلات لسه ما اتحفظتش: groupId → (studentId → درجة أو null=مسح).
  final Map<int, Map<int, int?>> _draft = {};
  final Set<int> _invalid = {}; // طلاب كتبوا رقم خارج النطاق
  final Map<int, TextEditingController> _ctrls = {};
  final Set<int> _collapsed = {};

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      final d = args['day'];
      if (d is DateTime) _day = DateTime(d.year, d.month, d.day);
      final g = args['groupId'];
      if (g is int) _focusGroup = g;
    }
    _att.loadAttendance();
    _loadSavedMax();
  }

  Future<void> _loadSavedMax() async {
    try {
      for (final g in _groups.groups) {
        if (g.id == null) continue;
        final v = int.tryParse(await _db.getSetting(_maxKey(g.id!)) ?? '');
        if (v != null) _savedMaxByGroup[g.id!] = v;
      }
    } catch (_) {
      // الإعداد المحلي اختياري — نكمل بالدرجة العظمى الافتراضية.
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── بيانات ──────────────────────────────────────────────────────
  bool get _hasDraft => _draft.values.any((m) => m.isNotEmpty);

  Attendance? _recordOf(int studentId) {
    final s = DateTime(_day.year, _day.month, _day.day);
    final e = DateTime(_day.year, _day.month, _day.day, 23, 59, 59);
    return _att.attendance.firstWhereOrNull((a) =>
        a.studentId == studentId && !a.date.isBefore(s) && !a.date.isAfter(e));
  }

  List<Student> _studentsOf(Group g) => _students.students
      .where((s) => s.groupId == g.id)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  int _maxOf(Group g) {
    final id = g.id!;
    final chosen = _maxByGroup[id];
    if (chosen != null) return chosen;
    int? recordMax;
    for (final s in _studentsOf(g)) {
      final r = _recordOf(s.id!);
      if (r?.recitation != null) {
        recordMax = recitationMaxOf(r!);
        break;
      }
    }
    return resolveGroupRecitationMax(
        recordMax: recordMax,
        savedMax: _savedMaxByGroup[id],
        settingsMax: Get.find<SettingsController>().recitationMax.value);
  }

  /// الدرجة المعروضة للطالب: المسودة أولاً ثم المحفوظة (لو بنفس المقياس).
  int? _gradeOf(Group g, Student s) {
    final d = _draft[g.id!];
    if (d != null && d.containsKey(s.id)) return d[s.id];
    final r = _recordOf(s.id!);
    if (r == null) return null;
    return recitationMaxOf(r) == _maxOf(g) ? recitationGradeOf(r) : null;
  }

  List<Group> get _visibleGroups {
    final all = _groups.groups.where((g) => g.id != null).toList();
    if (_focusGroup != null) {
      return all.where((g) => g.id == _focusGroup).toList();
    }
    if (_showAll) return all;
    return _att.groupsForDay(all, _day).where((g) => g.id != null).toList();
  }

  String _attLabel(Student s) {
    final r = _recordOf(s.id!);
    if (r == null) return 'لسه ماتسجّلش حضوره';
    // بدون إيموجي (التقرير PDF والخط ما بيدعمهمش).
    switch (normalizeAttendanceStatus(r.status)) {
      case ATTENDANCE_PRESENT:
        return 'حاضر';
      case ATTENDANCE_LATE:
        return 'متأخر';
      case ATTENDANCE_ABSENT:
        return 'غائب';
      default:
        return 'لسه ماتسجّلش حضوره';
    }
  }

  // ─── تحرير ───────────────────────────────────────────────────────
  TextEditingController _ctrlFor(Group g, Student s) {
    return _ctrls.putIfAbsent(s.id!, () {
      final v = _gradeOf(g, s);
      return TextEditingController(text: v?.toString() ?? '');
    });
  }

  void _onGrade(Group g, Student s, String raw) {
    final max = _maxOf(g);
    final m = _draft.putIfAbsent(g.id!, () => {});
    if (raw.trim().isEmpty) {
      m[s.id!] = null;
      _invalid.remove(s.id);
    } else {
      final v = parseRecitationInput(raw, max);
      if (v == null) {
        _invalid.add(s.id!);
        m.remove(s.id);
      } else {
        _invalid.remove(s.id);
        m[s.id!] = v;
      }
    }
    setState(() {});
  }

  void _setMax(Group g, int value) {
    final old = _maxOf(g);
    if (value == old) return;
    setState(() {
      _maxByGroup[g.id!] = value;
      // درجات المسودة اللي بقت أكبر من المقياس الجديد تتعلّم غلط بدل ما تتمسح بصمت.
      for (final s in _studentsOf(g)) {
        final c = _ctrls[s.id!];
        if (c == null) continue;
        final v = parseRecitationInput(c.text, value);
        if (c.text.trim().isNotEmpty && v == null) {
          _invalid.add(s.id!);
          _draft[g.id!]?.remove(s.id);
        } else {
          _invalid.remove(s.id);
          if (c.text.trim().isNotEmpty) {
            (_draft.putIfAbsent(g.id!, () => {}))[s.id!] = v;
          }
        }
      }
    });
  }

  Future<void> _askMax(Group g) async {
    final c = TextEditingController(text: '${_maxOf(g)}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('الدرجة العظمى لـ ${g.name}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              hintText: 'مثلاً 10 أو 15 أو 20 (حتى $kRecitationMaxCap)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, parseRecitationInput(c.text, kRecitationMaxCap)),
              child: const Text('تم')),
        ],
      ),
    );
    c.dispose();
    if (v != null) _setMax(g, v);
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) _changeDay(DateTime(d.year, d.month, d.day));
  }

  Future<void> _changeDay(DateTime d) async {
    if (_hasDraft && !await _confirmDiscard()) return;
    for (final c in _ctrls.values) {
      c.dispose();
    }
    setState(() {
      _day = d;
      _ctrls.clear();
      _draft.clear();
      _invalid.clear();
      _maxByGroup.clear();
    });
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('درجات لم تُحفظ',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: const Text('عندك درجات اتكتبت ولسه ما اتحفظتش. تتجاهلها؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ارجع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تجاهل')),
        ],
      ),
    );
    return ok ?? false;
  }

  // ─── حفظ ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_invalid.isNotEmpty) {
      ToastHelper.error('فيه درجات خارج الدرجة العظمى — صلّحها الأول');
      return;
    }
    if (!_hasDraft) {
      ToastHelper.info('مفيش تعديلات للحفظ');
      return;
    }
    setState(() => _saving = true);
    try {
      var saved = 0;
      for (final g in _groups.groups) {
        if (g.id == null) continue;
        final d = _draft[g.id!];
        if (d == null || d.isEmpty) continue;
        final max = _maxOf(g);
        saved += await _att.saveRecitationGrades(_day, d, max);
        await _db.setSetting(_maxKey(g.id!), '$max');
        _savedMaxByGroup[g.id!] = max;
      }
      if (!mounted) return;
      setState(_draft.clear);
      ToastHelper.success(saved == 0
          ? 'اتحدّثت الدرجات (من غير تغيير)'
          : 'اتحفظت درجات $saved طالب وبتتزامن تلقائيًا');
    } catch (e) {
      ToastHelper.error('تعذّر الحفظ — حاول تاني');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── تقارير ──────────────────────────────────────────────────────
  List<RecitationReportGroup> _reportGroups() {
    final out = <RecitationReportGroup>[];
    for (final g in _visibleGroups) {
      final students = _studentsOf(g);
      if (students.isEmpty) continue;
      out.add(RecitationReportGroup(
        groupName: g.name,
        max: _maxOf(g),
        rows: [
          for (final s in students)
            RecitationReportRow(
              studentName: s.name,
              attendanceLabel: _attLabel(s),
              grade: _gradeOf(g, s),
            ),
        ],
      ));
    }
    return out;
  }

  Future<void> _exportPdf() async {
    final groups = _reportGroups();
    if (groups.isEmpty) {
      ToastHelper.info('مفيش مجموعات للتقرير');
      return;
    }
    final res = await ExportService().exportRecitationPDF(date: _day, groups: groups);
    if (!mounted) return;
    if (res.success && res.path != null) {
      await ExportService().sharePDF(res.path!);
    } else {
      ToastHelper.error(res.error ?? 'تعذّر إنشاء التقرير');
    }
  }

  Future<void> _shareText() async {
    final groups = _reportGroups();
    if (groups.isEmpty) {
      ToastHelper.info('مفيش مجموعات للتقرير');
      return;
    }
    await Share.share(buildRecitationReportText(_day, groups),
        subject: 'تقرير التسميع');
  }

  void _openCertificates() {
    final settings = Get.find<SettingsController>();
    final dateText = DateFormat('EEEE d MMMM yyyy', 'ar').format(_day);
    final items = <CertificateData>[];
    for (final g in _visibleGroups) {
      final max = _maxOf(g);
      for (final s in _studentsOf(g)) {
        final v = _gradeOf(g, s);
        if (recitationLevelOf(v, max) != RecitationLevel.star) continue;
        items.add(CertificateData(
          studentName: s.name,
          kind: CertKind.appreciation,
          achievementText: 'تقديرًا لتميّزه في التسميع',
          gradeText: 'الدرجة: $v من $max',
          dateText: dateText,
          teacherName: settings.teacherFullName.value,
          teacherSpecialization: settings.teacherSpecialization.value,
          teacherTitle: settings.teacherTitle,
        ));
      }
    }
    if (items.isEmpty) {
      ToastHelper.info('مفيش طلاب حاصلين على نجمة (90% فأكثر) لسه');
      return;
    }
    Get.to(() => CertificatesSheet(
          title: 'شهادات التميّز في التسميع',
          fileName: 'recitation_certificates_${DateFormat('yyyyMMdd').format(_day)}',
          items: items,
        ));
  }

  void _showReportSheet() {
    final t = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.picture_as_pdf_rounded, color: t.brand),
            title: const Text('تقرير PDF', style: AppType.label),
            subtitle: const Text('صفحة لكل مجموعة — يتشارك أو يتحفظ'),
            onTap: () {
              Navigator.pop(ctx);
              _exportPdf();
            },
          ),
          ListTile(
            leading: Icon(Icons.chat_rounded, color: t.positive),
            title: const Text('تقرير مكتوب (واتساب)', style: AppType.label),
            subtitle: const Text('نص جاهز تشاركه على واتساب أو غيره'),
            onTap: () {
              Navigator.pop(ctx);
              _shareText();
            },
          ),
          ListTile(
            leading: Icon(Icons.workspace_premium_rounded, color: t.caution),
            title: const Text('شهادات تقدير للمتميّزين', style: AppType.label),
            subtitle: const Text('للطلاب الحاصلين على نجمة (90% فأكثر)'),
            onTap: () {
              Navigator.pop(ctx);
              _openCertificates();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _notifyGuardian(Group g, Student s, int grade, bool star) async {
    final max = _maxOf(g);
    final msg = star
        ? buildRecitationStarMessage(
            studentName: s.name, grade: grade, max: max, date: _day)
        : buildRecitationLowAlertMessage(
            studentName: s.name,
            grade: grade,
            max: max,
            date: _day,
            groupName: g.name);
    await launchGuardianWhatsapp(
      context: context,
      phone: s.guardianPhone,
      whatsapp: s.guardianWhatsapp,
      message: msg,
      dialCode: Get.find<SettingsController>().countryDial.value,
    );
  }

  // ─── واجهة ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopScope(
      canPop: !_hasDraft,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: t.page,
        appBar: buildBoardAppBar(context, title: 'قائمة التسميع', actions: const [
          HelpButton(topicId: 'recitation'),
        ]),
        bottomNavigationBar: _bottomBar(t),
        body: Obx(() {
          // اعتماد على القوائم الـRx عشان الصفحة تتحدّث لما الحضور يتحمّل.
          _att.attendance.length;
          _students.students.length;
          _groups.groups.length;
          final groups = _visibleGroups;
          return Column(children: [
            _DayBar(
              day: _day,
              onPrev: () => _changeDay(_day.subtract(const Duration(days: 1))),
              onNext: () => _changeDay(_day.add(const Duration(days: 1))),
              onPick: _pickDay,
              onToday: _day == _today() ? null : () => _changeDay(_today()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
              child: Row(children: [
                Expanded(
                  child: Text(
                      _focusGroup != null
                          ? (groups.isEmpty ? 'المجموعة' : groups.first.name)
                          : _showAll
                              ? 'كل المجموعات (${groups.length})'
                              : 'مجموعات اليوم (${groups.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label.copyWith(color: t.ink)),
                ),
                AppFilterChip(
                  label: 'كل المجموعات',
                  selected: _showAll && _focusGroup == null,
                  color: t.brand,
                  onTap: () => setState(() {
                    if (_focusGroup != null) {
                      _focusGroup = null;
                      _showAll = true;
                    } else {
                      _showAll = !_showAll;
                    }
                  }),
                ),
              ]),
            ),
            Expanded(
              child: groups.isEmpty
                  ? _empty(t)
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      itemCount: groups.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpace.md),
                      itemBuilder: (_, i) => _groupCard(t, groups[i]),
                    ),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _empty(AppTokens t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_busy_rounded, size: 48, color: t.inkFaint),
            const SizedBox(height: AppSpace.md),
            Text('مفيش حصص في اليوم ده',
                style: AppType.title.copyWith(color: t.ink)),
            const SizedBox(height: AppSpace.xs),
            Text('اضغط "كل المجموعات" لو بتسمّع في يوم مش في الجدول.',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: t.inkSoft)),
          ]),
        ),
      );

  Widget _bottomBar(AppTokens t) => Material(
        color: t.surface,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: _showReportSheet,
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                label: const Text('تقرير'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 48),
                    foregroundColor: t.ink,
                    side: BorderSide(color: t.line)),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label: Text('حفظ درجات التسميع',
                      style: AppType.label.copyWith(color: t.onChalk)),
                  style: FilledButton.styleFrom(
                      backgroundColor: t.chalk,
                      foregroundColor: t.onChalk,
                      minimumSize: const Size(44, 48)),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _groupCard(AppTokens t, Group g) {
    final max = _maxOf(g);
    final students = _studentsOf(g);
    final open = !_collapsed.contains(g.id);
    var graded = 0, low = 0, star = 0;
    for (final s in students) {
      final lvl = recitationLevelOf(_gradeOf(g, s), max);
      if (lvl != RecitationLevel.none) graded++;
      if (lvl == RecitationLevel.low) low++;
      if (lvl == RecitationLevel.star) star++;
    }

    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.board),
          onTap: () => setState(
              () => open ? _collapsed.add(g.id!) : _collapsed.remove(g.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.title.copyWith(color: t.ink)),
                      const SizedBox(height: 2),
                      Wrap(spacing: AppSpace.sm, children: [
                        Text('سمّع $graded من ${students.length}',
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                        if (low > 0)
                          Text('$low تراجع',
                              style: AppType.caption.copyWith(
                                  color: t.danger, fontWeight: FontWeight.w700)),
                        if (star > 0)
                          Text('$star نجمة',
                              style: AppType.caption.copyWith(
                                  color: t.caution, fontWeight: FontWeight.w700)),
                      ]),
                    ]),
              ),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: t.inkSoft),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.md, 0, AppSpace.md, AppSpace.md),
          child: _MaxStepper(
            value: max,
            onMinus: () => _setMax(g, stepRecitationMax(max, -1)),
            onPlus: () => _setMax(g, stepRecitationMax(max, 1)),
            onTapValue: () => _askMax(g),
          ),
        ),
        if (open) ...[
          Divider(height: 1, color: t.line),
          if (students.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Text('مفيش طلاب في المجموعة دي',
                  style: AppType.body.copyWith(color: t.inkSoft)),
            )
          else
            for (var i = 0; i < students.length; i++) ...[
              if (i > 0) Divider(height: 1, color: t.line),
              _studentRow(t, g, students[i], max),
            ],
        ],
      ]),
    );
  }

  Widget _studentRow(AppTokens t, Group g, Student s, int max) {
    final r = _recordOf(s.id!);
    final canRecord = r != null && canRecordRecitation(r.status);
    final grade = _gradeOf(g, s);
    final lvl = recitationLevelOf(grade, max);
    final invalid = _invalid.contains(s.id);
    final otherScale = r != null &&
        recitationGradeOf(r) != null &&
        recitationMaxOf(r) != max &&
        !(_draft[g.id!]?.containsKey(s.id) ?? false);

    final Color? stripe = lvl == RecitationLevel.low
        ? t.danger
        : lvl == RecitationLevel.star
            ? t.cautionBar
            : null;

    return Container(
      decoration: BoxDecoration(
        border: stripe == null
            ? null
            : BorderDirectional(start: BorderSide(color: stripe, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md, vertical: AppSpace.sm),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(color: t.ink)),
            const SizedBox(height: 2),
            if (!canRecord)
              Text(_attLabel(s),
                  style: AppType.caption.copyWith(color: t.inkSoft))
            else if (lvl == RecitationLevel.low)
              _chip(t, 'تراجع مستوى', Icons.trending_down_rounded, t.danger,
                  t.dangerSoft)
            else if (lvl == RecitationLevel.star)
              _chip(t, 'نجمة تميّز', Icons.star_rounded, t.caution, t.cautionSoft)
            else if (otherScale)
              Text(
                  'سُجّلت ${recitationGradeOf(r)}/${recitationMaxOf(r)} — اكتب درجة جديدة للاستبدال',
                  style: AppType.caption.copyWith(color: t.inkSoft))
            else
              Text(r.status == ATTENDANCE_LATE ? 'متأخر' : 'حاضر',
                  style: AppType.caption.copyWith(color: t.inkSoft)),
          ]),
        ),
        if (canRecord && (lvl == RecitationLevel.low || lvl == RecitationLevel.star))
          IconButton(
            tooltip: lvl == RecitationLevel.low
                ? 'إرسال تنبيه لولي الأمر'
                : 'إرسال تهنئة لولي الأمر',
            onPressed: () =>
                _notifyGuardian(g, s, grade!, lvl == RecitationLevel.star),
            icon: Icon(Icons.chat_rounded,
                color: lvl == RecitationLevel.low ? t.danger : t.positive),
            style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
          ),
        SizedBox(
          width: 84,
          child: TextField(
            enabled: canRecord,
            controller: _ctrlFor(g, s),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (v) => _onGrade(g, s, v),
            style: AppType.title.copyWith(color: t.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: canRecord ? '—' : '',
              errorText: invalid ? 'أقصى $max' : null,
              errorStyle: const TextStyle(fontSize: 10),
              filled: true,
              fillColor: canRecord ? t.page : t.page.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  borderSide: BorderSide(color: t.line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  borderSide: BorderSide(color: invalid ? t.danger : t.line)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(AppTokens t, String label, IconData icon, Color ink, Color bg) =>
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(AppRadius.chip)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 4),
            Text(label,
                style: AppType.caption
                    .copyWith(color: ink, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

/// شريط اليوم فوق القائمة (على السبورة).
class _DayBar extends StatelessWidget {
  final DateTime day;
  final VoidCallback onPrev, onNext, onPick;
  final VoidCallback? onToday;
  const _DayBar(
      {required this.day,
      required this.onPrev,
      required this.onNext,
      required this.onPick,
      required this.onToday});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = DateFormat('EEEE d MMMM yyyy', 'ar').format(day);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
      decoration: BoxDecoration(
        color: t.board,
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.board)),
      ),
      child: Row(children: [
        BoardIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'اليوم السابق',
            onPressed: onPrev),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.calendar_month_rounded,
                    color: t.boardInkSoft, size: 18),
                const SizedBox(width: AppSpace.sm),
                Flexible(
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: AppType.label.copyWith(color: t.boardInk)),
                ),
              ]),
            ),
          ),
        ),
        if (onToday != null)
          BoardIconButton(
              icon: Icons.today_rounded,
              tooltip: 'وصول سريع لليوم',
              onPressed: onToday),
        BoardIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'اليوم التالي',
            onPressed: onNext),
      ]),
    );
  }
}

/// مؤشر الدرجة العظمى للمجموعة: (−) رقم (+). ضغطة على الرقم لإدخال قيمة دقيقة.
class _MaxStepper extends StatelessWidget {
  final int value;
  final VoidCallback onMinus, onPlus, onTapValue;
  const _MaxStepper(
      {required this.value,
      required this.onMinus,
      required this.onPlus,
      required this.onTapValue});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget btn(IconData icon, String tip, VoidCallback f) => IconButton(
          tooltip: tip,
          onPressed: f,
          icon: Icon(icon, color: t.brand),
          style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              side: BorderSide(color: t.line)),
        );
    return Row(children: [
      Text('الدرجة من', style: AppType.body.copyWith(color: t.inkSoft)),
      const Spacer(),
      btn(Icons.remove_rounded, 'تقليل الدرجة العظمى', onMinus),
      InkWell(
        onTap: onTapValue,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 44),
          alignment: Alignment.center,
          child: Text('$value',
              style: AppType.figure.copyWith(color: t.ink, fontSize: 22)),
        ),
      ),
      btn(Icons.add_rounded, 'زيادة الدرجة العظمى', onPlus),
    ]);
  }
}

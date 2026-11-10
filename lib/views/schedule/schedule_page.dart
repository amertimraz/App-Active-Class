// lib/views/schedule/schedule_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/session_override_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/session_override_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/schedule_week.dart';
import 'package:active_class/views/attendance/session_detail_page.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/clock_text.dart';

// ─── أيام الأسبوع (تبدأ السبت) ────────────────────────────────────────────────
const List<String> _kDays = [
  'السبت',
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
];

// تحويل DateTime.weekday → فهرس اليوم العربي (السبت=0)
int _todayIndex() => (DateTime.now().weekday + 1) % 7;

// ─── حصة واحدة في الجدول ──────────────────────────────────────────────────────
class _ClassSlot {
  final Group group;
  final int dayIndex; // 0=السبت
  final TimeOfDay from;
  final TimeOfDay to;
  final int studentCount;
  // spec 053 — استثناء الحصة في التاريخ المعروض (ملغاة/تعويضية/إضافية).
  final SessionOverrideType? override;

  _ClassSlot({
    required this.group,
    required this.dayIndex,
    required this.from,
    required this.to,
    required this.studentCount,
    this.override,
  });

  _ClassSlot withOverride(SessionOverrideType? o) => _ClassSlot(
      group: group,
      dayIndex: dayIndex,
      from: from,
      to: to,
      studentCount: studentCount,
      override: o);

  int get fromMinutes => from.hour * 60 + from.minute;
  int get toMinutes => to.hour * 60 + to.minute;
  int get durationMin => toMinutes - fromMinutes;

  Color get color =>
      group.color != null ? Color(group.color!) : AppTheme.primaryColor;
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _db = DatabaseService();
  late int _selectedDay;
  // spec 053 — إزاحة الأسبوع عن الأسبوع الحالي (0 = الحالي، -1 = اللي فات).
  int _weekOffset = 0;
  List<_ClassSlot> _slots = [];
  List<Group> _groups = [];
  Map<int, int> _countByGroup = {};
  SessionOverrideController? _so;
  bool _loading = true;
  // مفاتيح شرايح الأيام عشان نحرّك اليوم المختار لنص الشريط.
  final List<GlobalKey> _chipKeys = List.generate(7, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _selectedDay = _todayIndex();
    _load();
  }

  void _scrollSelectedIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _chipKeys[_selectedDay].currentContext;
      if (c == null) return;
      Scrollable.ensureVisible(c,
          alignment: 0.5,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    });
  }

  Future<void> _load() async {
    final groups = await _db.getAllGroups();
    // عدد الطلاب هنا "حجم الفصل الحالي" — الطلاب المؤرشفين مستبعدين.
    final students =
        (await _db.getAllStudents()).where((s) => !s.isArchived).toList();

    final countByGroup = <int, int>{};
    for (final Student s in students) {
      countByGroup.update(s.groupId, (v) => v + 1, ifAbsent: () => 1);
    }

    _groups = groups;
    _countByGroup = countByGroup;
    _so = Get.isRegistered<SessionOverrideController>()
        ? Get.find<SessionOverrideController>()
        : Get.put(SessionOverrideController());
    await _so!.load();

    final slots = <_ClassSlot>[];
    for (final g in groups) {
      final raw = g.schedule?.trim() ?? '';
      if (raw.isEmpty) continue;
      for (final part in raw.split(',')) {
        final slot = _parseSlot(part.trim(), g, countByGroup[g.id] ?? 0);
        if (slot != null) slots.add(slot);
      }
    }
    if (mounted) {
      setState(() {
        _slots = slots;
        _loading = false;
      });
      _scrollSelectedIntoView();
    }
  }

  _ClassSlot? _parseSlot(String txt, Group g, int count) {
    if (txt.isEmpty) return null;
    final sp = txt.split(' ');
    if (sp.isEmpty) return null;
    final day = sp.first;
    final dayIndex = _kDays.indexOf(day);
    if (dayIndex < 0) return null;

    final rest = txt.substring(day.length).trim();
    final range = rest.split('-');
    if (range.length != 2) return null;

    TimeOfDay? parse(String v) {
      final p = v.trim().split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0].trim()), m = int.tryParse(p[1].trim());
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    final from = parse(range[0]);
    final to = parse(range[1]);
    if (from == null || to == null) return null;

    return _ClassSlot(
        group: g, dayIndex: dayIndex, from: from, to: to, studentCount: count);
  }

  String _fmtTime(TimeOfDay t) => FormatHelper.formatClock(t);

  List<_ClassSlot> _slotsForDay(int day) {
    final list = _slots.where((s) => s.dayIndex == day).toList()
      ..sort((a, b) => a.fromMinutes.compareTo(b.fromMinutes));
    return list;
  }

  // ── spec 053: التاريخ الفعلي لكل يوم في الأسبوع المعروض ──
  DateTime _dateOf(int dayIndex) =>
      dateForDayIndex(DateTime.now(), _weekOffset, dayIndex);

  DateTime get _selectedDate => _dateOf(_selectedDay);

  void _goToDate(DateTime d) {
    setState(() {
      _weekOffset = weekOffsetFor(DateTime.now(), d);
      _selectedDay = dayIndexOf(d);
    });
    _scrollSelectedIntoView();
  }

  static TimeOfDay? _parseHm(String v) {
    final p = v.trim().split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0].trim()), m = int.tryParse(p[1].trim());
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// حصص تاريخ معيّن: حصص اليوم الأسبوعي (الملغاة بعلامة) + الحصص
  /// التعويضية/الإضافية اللي في التاريخ ده بموعدها الخاص.
  List<_ClassSlot> _slotsForDate(DateTime date) {
    final so = _so;
    final base = _slotsForDay(dayIndexOf(date));
    if (so == null) return base;
    final result = <_ClassSlot>[];
    final covered = <int?>{};
    for (final sl in base) {
      final ov =
          sl.group.id == null ? null : so.overrideFor(sl.group.id!, date);
      covered.add(sl.group.id);
      result.add(ov != null && ov.type == SessionOverrideType.cancelled
          ? sl.withOverride(SessionOverrideType.cancelled)
          : ov != null
              ? sl.withOverride(ov.type)
              : sl);
    }
    for (final g in _groups) {
      if (g.id == null || covered.contains(g.id)) continue;
      final ov = so.overrideFor(g.id!, date);
      if (ov == null || ov.type == SessionOverrideType.cancelled) continue;
      // موعد التعويضية/الإضافية (اختياري): "HH:mm-HH:mm" أو "HH:mm".
      final parts = (ov.sessionTime ?? '').split('-');
      final from = parts.isNotEmpty ? _parseHm(parts[0]) : null;
      final to = parts.length > 1 ? _parseHm(parts[1]) : null;
      final f = from ?? const TimeOfDay(hour: 0, minute: 0);
      result.add(_ClassSlot(
        group: g,
        dayIndex: dayIndexOf(date),
        from: f,
        to: to ?? f,
        studentCount: _countByGroup[g.id] ?? 0,
        override: ov.type,
      ));
    }
    result.sort((a, b) => a.fromMinutes.compareTo(b.fromMinutes));
    return result;
  }

  int _cmpToday(DateTime d) {
    final n = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .compareTo(DateTime(n.year, n.month, n.day));
  }

  // هل الحصة جارية الآن؟ (فقط لو التاريخ المعروض = النهاردة)
  bool _isNow(_ClassSlot s, DateTime date) {
    if (_cmpToday(date) != 0 || s.override == SessionOverrideType.cancelled) {
      return false;
    }
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= s.fromMinutes && nowMin < s.toMinutes;
  }

  bool _isPast(_ClassSlot s, DateTime date) {
    final c = _cmpToday(date);
    if (c < 0) return true;
    if (c > 0) return false;
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= s.toMinutes;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
    );
    if (d != null) _goToDate(d);
  }

  // ── كتلة السبورة: التنقل بين التواريخ + ملخص الأسبوع + شريط الأيام ──────────
  Widget _board(BuildContext context, AppTokens t) {
    final d = _selectedDate;
    final fmt = DateFormat('EEEE d MMMM yyyy', 'ar');
    final showBack = _weekOffset != 0 || _selectedDay != _todayIndex();
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
      decoration: BoxDecoration(
        color: t.board,
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.board)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            BoardIconButton(
                icon: Icons.keyboard_double_arrow_right_rounded,
                tooltip: 'شهر قبل',
                onPressed: () =>
                    _goToDate(DateTime(d.year, d.month - 1, d.day))),
            BoardIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'أسبوع قبل',
                onPressed: () => setState(() => _weekOffset -= 1)),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: _pickDate,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: Text(fmt.format(d),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: AppType.title
                            .copyWith(fontSize: 16, color: t.boardInk)),
                  ),
                ),
              ),
            ),
            BoardIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'أسبوع بعد',
                onPressed: () => setState(() => _weekOffset += 1)),
            BoardIconButton(
                icon: Icons.keyboard_double_arrow_left_rounded,
                tooltip: 'شهر بعد',
                onPressed: () =>
                    _goToDate(DateTime(d.year, d.month + 1, d.day))),
          ]),
          if (showBack)
            Center(
              child: TextButton(
                onPressed: () => _goToDate(DateTime.now()),
                style: TextButton.styleFrom(
                    foregroundColor: t.chalk, minimumSize: const Size(44, 44)),
                child: Text('الرجوع لليوم',
                    style: AppType.label.copyWith(color: t.chalk)),
              ),
            ),
          const SizedBox(height: AppSpace.sm),
          _WeekSummary(slots: _slots),
          const SizedBox(height: AppSpace.md),
          // شريط الأيام: Row جوه تمرير أفقي (من غير ارتفاع ثابت) عشان الخط
          // الكبير يكبّر الشرائح بدل ما يعمل overflow.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
            child: Row(children: [
              for (var i = 0; i < _kDays.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpace.sm),
                Builder(builder: (_) {
                  final dayDate = _dateOf(i);
                  final count = _slotsForDate(dayDate)
                      .where((x) => x.override != SessionOverrideType.cancelled)
                      .length;
                  return _DayChip(
                    key: _chipKeys[i],
                    label: _kDays[i],
                    dateText: '${dayDate.day}/${dayDate.month}',
                    count: count,
                    isToday: _cmpToday(dayDate) == 0,
                    selected: i == _selectedDay,
                    onTap: () {
                      setState(() => _selectedDay = i);
                      _scrollSelectedIntoView();
                    },
                  );
                }),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selectedDate = _selectedDate;
    final daySlots = _slotsForDate(selectedDate);

    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(
        context,
        title: 'جدول الحصص',
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _board(context, t),

                // ── حصص اليوم المختار ─────────────────────────────
                Expanded(
                  child: daySlots.isEmpty
                      ? _EmptyDay(day: _kDays[_selectedDay])
                      : ClockBuilder(builder: (_) {
                          // إعادة بناء القائمة عند تغيير نظام الساعة 12/24
                          // من الإعدادات (الصفحة دي مش GetX-reactive أصلًا).
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpace.lg, AppSpace.lg, AppSpace.lg, 24),
                            itemCount: daySlots.length,
                            itemBuilder: (_, i) {
                              final s = daySlots[i];
                              return _ClassCard(
                                slot: s,
                                isNow: _isNow(s, selectedDate),
                                isPast: _isPast(s, selectedDate),
                                isLast: i == daySlots.length - 1,
                                timeFrom: _fmtTime(s.from),
                                timeTo: _fmtTime(s.to),
                                // spec 053: تفاصيل الحصة بتاريخها، والضغط
                                // المطوّل لتفاصيل المجموعة (السلوك القديم).
                                onTap: () => Get.to(() => SessionDetailPage(
                                    group: s.group, day: selectedDate)),
                                onLongPress: () => Get.toNamed(
                                    ROUTE_GROUP_DETAILS,
                                    arguments: s.group),
                              );
                            },
                          );
                        }),
                ),
              ],
            ),
    );
  }
}

// ─── ملخص الأسبوع (فوق السبورة) ───────────────────────────────────────────────
class _WeekSummary extends StatelessWidget {
  final List<_ClassSlot> slots;
  const _WeekSummary({required this.slots});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final totalClasses = slots.length;
    final totalMinutes = slots.fold<int>(0, (s, c) => s + c.durationMin);
    final hours = totalMinutes / 60;
    final groupsCount = slots.map((s) => s.group.id).toSet().length;

    Widget cell(Widget c) => Expanded(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
            child: c));
    return Row(children: [
      cell(BoardStat(
          label: 'حصة أسبوعياً', value: '$totalClasses', color: t.boardInk)),
      cell(BoardStat(
          label: 'ساعة تدريس',
          value: hours == hours.toInt()
              ? '${hours.toInt()}'
              : hours.toStringAsFixed(1),
          color: t.boardInk)),
      cell(BoardStat(
          label: 'مجموعة نشطة', value: '$groupsCount', color: t.chalk)),
    ]);
  }
}

// ─── شريحة اليوم (فوق السبورة): المختار بالطباشير الأصفر ───────────────────────
class _DayChip extends StatelessWidget {
  final String label;
  final String dateText;
  final int count;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip({
    super.key,
    required this.label,
    required this.dateText,
    required this.count,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.onChalk : t.boardInk;
    final soft = selected ? t.onChalk : t.boardInkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $dateText، $count حصة${isToday ? '، اليوم' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? t.chalk : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(
            color: selected ? t.chalk : (isToday ? t.chalk : t.boardLine),
            width: isToday && !selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm, vertical: AppSpace.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isToday)
                    Text('اليوم',
                        style: AppType.caption.copyWith(
                            color: selected ? t.onChalk : t.chalk,
                            fontWeight: FontWeight.w700)),
                  Text(label, style: AppType.label.copyWith(color: fg)),
                  Text(dateText, style: AppType.caption.copyWith(color: soft)),
                  const SizedBox(height: AppSpace.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected
                          ? t.onChalk.withValues(alpha: 0.12)
                          : (count > 0
                              ? t.chalk.withValues(alpha: 0.16)
                              : t.boardLine),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text('$count',
                        style: AppType.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? t.onChalk
                                : (count > 0 ? t.chalk : t.boardInkSoft))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── بطاقة الحصة (timeline) ───────────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final _ClassSlot slot;
  final bool isNow, isPast, isLast;
  final String timeFrom, timeTo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ClassCard({
    required this.slot,
    required this.isNow,
    required this.isPast,
    required this.isLast,
    required this.timeFrom,
    required this.timeTo,
    required this.onTap,
    this.onLongPress,
  });

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(label,
            style: AppType.caption
                .copyWith(fontWeight: FontWeight.w700, color: fg)),
      );

  Widget? _overrideBadge(AppTokens t) {
    final o = slot.override;
    if (o == null) return null;
    return switch (o) {
      SessionOverrideType.cancelled => _badge('ملغاة', t.dangerSoft, t.danger),
      SessionOverrideType.makeup =>
        _badge('تعويضية', t.positiveSoft, t.positive),
      SessionOverrideType.extra => _badge('إضافية', t.rosterTint, t.rosterInk),
    };
  }

  Widget _info(AppTokens t, IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: t.inkFaint),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: AppType.body.copyWith(color: t.inkSoft)),
        ),
      ]);

  String _durationLabel(int min) {
    if (min <= 0) return '—';
    final h = min ~/ 60;
    final m = min % 60;
    if (h > 0 && m > 0) return '$h س $m د';
    if (h > 0) return '$h ساعة';
    return '$m دقيقة';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = slot.color;
    final badge = _overrideBadge(t);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── عمود الوقت + خط الـ timeline ──────────────────────
          SizedBox(
            width: 64,
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(timeFrom,
                      style: AppType.label
                          .copyWith(color: isNow ? t.ink : t.inkSoft)),
                ),
                const SizedBox(height: AppSpace.xs),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isNow ? color : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: t.line)),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),

          // ── بطاقة المجموعة ────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: Material(
                color: t.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  side: BorderSide(
                      color: isNow ? color : t.line, width: isNow ? 2 : 1),
                ),
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // شريط لون المجموعة على حافة البطاقة
                        Container(width: 6, color: color),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(slot.group.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.title.copyWith(
                                        color: isPast ? t.inkSoft : t.ink)),
                                if (badge != null || isNow || isPast) ...[
                                  const SizedBox(height: AppSpace.xs),
                                  Wrap(
                                    spacing: AppSpace.sm,
                                    runSpacing: AppSpace.xs,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (badge != null) badge,
                                      if (isNow)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpace.sm,
                                              vertical: 2),
                                          decoration: BoxDecoration(
                                            color: t.positive,
                                            borderRadius: BorderRadius.circular(
                                                AppRadius.chip),
                                          ),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const _PulseDot(),
                                                const SizedBox(
                                                    width: AppSpace.xs),
                                                Text('الآن',
                                                    style: AppType.caption
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                Colors.white)),
                                              ]),
                                        )
                                      else if (isPast)
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded,
                                                  size: 16, color: t.positive),
                                              const SizedBox(
                                                  width: AppSpace.xs),
                                              Text('انتهت',
                                                  style: AppType.caption
                                                      .copyWith(
                                                          color: t.inkFaint)),
                                            ]),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: AppSpace.sm),
                                Wrap(
                                  spacing: AppSpace.md,
                                  runSpacing: AppSpace.xs,
                                  children: [
                                    _info(t, Icons.access_time_rounded,
                                        '$timeFrom - $timeTo'),
                                    _info(t, Icons.hourglass_bottom_rounded,
                                        _durationLabel(slot.durationMin)),
                                    if (slot.studentCount > 0)
                                      _info(t, Icons.person_rounded,
                                          '${slot.studentCount} طالب'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                              end: AppSpace.md),
                          child: Center(
                            child: Icon(Icons.arrow_forward_ios_rounded,
                                size: 16, color: t.inkFaint),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// نقطة نابضة لشارة "الآن" (بتقف لو المستخدم مفعّل "تقليل الحركة")
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
        child: Container(
          width: 8,
          height: 8,
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
      );
}

// ─── يوم فارغ ─────────────────────────────────────────────────────────────────
class _EmptyDay extends StatelessWidget {
  final String day;
  const _EmptyDay({required this.day});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: t.rosterTint),
            child: Icon(Icons.event_available_rounded,
                size: 40, color: t.rosterInk),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('لا توجد حصص يوم $day',
              textAlign: TextAlign.center,
              style: AppType.title.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.xs),
          Text('أضف مواعيد للمجموعات من صفحة تفاصيل المجموعة',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: t.inkSoft)),
        ]),
      ),
    );
  }
}

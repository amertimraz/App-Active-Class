// lib/views/schedule/schedule_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';

// ─── أيام الأسبوع (تبدأ السبت) ────────────────────────────────────────────────
const List<String> _kDays = [
  'السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة',
];

// تحويل DateTime.weekday → فهرس اليوم العربي (السبت=0)
int _todayIndex() => (DateTime.now().weekday + 1) % 7;

// ─── حصة واحدة في الجدول ──────────────────────────────────────────────────────
class _ClassSlot {
  final Group     group;
  final int       dayIndex;   // 0=السبت
  final TimeOfDay from;
  final TimeOfDay to;
  final int       studentCount;

  _ClassSlot({
    required this.group,
    required this.dayIndex,
    required this.from,
    required this.to,
    required this.studentCount,
  });

  int get fromMinutes => from.hour * 60 + from.minute;
  int get toMinutes   => to.hour * 60 + to.minute;
  int get durationMin => toMinutes - fromMinutes;

  Color get color => group.color != null ? Color(group.color!) : AppTheme.primaryColor;
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _db = DatabaseService();
  late int _selectedDay;
  List<_ClassSlot> _slots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _todayIndex();
    _load();
  }

  Future<void> _load() async {
    final groups   = await _db.getAllGroups();
    final students = await _db.getAllStudents();

    final countByGroup = <int, int>{};
    for (final Student s in students) {
      countByGroup.update(s.groupId, (v) => v + 1, ifAbsent: () => 1);
    }

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
    final to   = parse(range[1]);
    if (from == null || to == null) return null;

    return _ClassSlot(
        group: g, dayIndex: dayIndex, from: from, to: to, studentCount: count);
  }

  String _fmtTime(TimeOfDay t) {
    final settings = Get.find<SettingsController>();
    if (settings.use24hFormat.value) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return DateFormat('hh:mm a', 'ar')
        .format(DateTime(2000, 1, 1, t.hour, t.minute));
  }

  List<_ClassSlot> _slotsForDay(int day) {
    final list = _slots.where((s) => s.dayIndex == day).toList()
      ..sort((a, b) => a.fromMinutes.compareTo(b.fromMinutes));
    return list;
  }

  // هل الحصة جارية الآن؟ (فقط لو اليوم المختار = اليوم الحالي)
  bool _isNow(_ClassSlot s) {
    if (s.dayIndex != _todayIndex()) return false;
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= s.fromMinutes && nowMin < s.toMinutes;
  }

  bool _isPast(_ClassSlot s) {
    if (s.dayIndex != _todayIndex()) return false;
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= s.toMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daySlots = _slotsForDay(_selectedDay);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFF4F6FC),
      appBar: AppBar(
        title: const Text('جدول الحصص',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
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
                // ── لوحة ملخص أسبوعي ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _WeekSummary(slots: _slots),
                ),

                // ── شريط الأيام ───────────────────────────────────
                SizedBox(
                  height: 108,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _kDays.length,
                    itemBuilder: (_, i) {
                      final count = _slotsForDay(i).length;
                      return _DayChip(
                        label:     _kDays[i],
                        count:     count,
                        isToday:   i == _todayIndex(),
                        selected:  i == _selectedDay,
                        onTap:     () => setState(() => _selectedDay = i),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),

                // ── حصص اليوم المختار ─────────────────────────────
                Expanded(
                  child: daySlots.isEmpty
                      ? _EmptyDay(
                          day: _kDays[_selectedDay], isDark: isDark, cs: cs)
                      : Obx(() {
                          // قراءة مباشرة هنا عشان القائمة تتحدّث لما نظام
                          // الساعة 12/24 يتغيّر من الإعدادات — الصفحة دي
                          // مش GetX-reactive أصلًا فمن غير ده الأوقات
                          // مبتتحدثش غير لو الصفحة اتفتحت من جديد.
                          Get.find<SettingsController>().use24hFormat.value;
                          return ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: daySlots.length,
                            itemBuilder: (_, i) {
                              final s = daySlots[i];
                              return _ClassCard(
                                slot:      s,
                                isNow:     _isNow(s),
                                isPast:    _isPast(s),
                                isLast:    i == daySlots.length - 1,
                                timeFrom:  _fmtTime(s.from),
                                timeTo:    _fmtTime(s.to),
                                onTap: () => Get.toNamed(
                                    ROUTE_GROUP_DETAILS, arguments: s.group),
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

// ─── ملخص الأسبوع ─────────────────────────────────────────────────────────────
class _WeekSummary extends StatelessWidget {
  final List<_ClassSlot> slots;
  const _WeekSummary({required this.slots});

  @override
  Widget build(BuildContext context) {
    final totalClasses = slots.length;
    final totalMinutes = slots.fold<int>(0, (s, c) => s + c.durationMin);
    final hours        = (totalMinutes / 60);
    final groupsCount  = slots.map((s) => s.group.id).toSet().length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          _summaryStat(
              '$totalClasses', 'حصة أسبوعياً', Icons.event_note_rounded),
          _divider(),
          _summaryStat(
              hours == hours.toInt()
                  ? '${hours.toInt()}'
                  : hours.toStringAsFixed(1),
              'ساعة تدريس', Icons.schedule_rounded),
          _divider(),
          _summaryStat(
              '$groupsCount', 'مجموعة نشطة', Icons.groups_rounded),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 38, color: Colors.white.withValues(alpha: 0.2));

  Widget _summaryStat(String value, String label, IconData icon) => Expanded(
        child: Column(children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 5),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 20,
                  fontWeight: FontWeight.w900, color: Colors.white,
                  height: 1.1)),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.75))),
        ]),
      );
}

// ─── شريحة اليوم ──────────────────────────────────────────────────────────────
class _DayChip extends StatelessWidget {
  final String label;
  final int    count;
  final bool   isToday;
  final bool   selected;
  final VoidCallback onTap;
  const _DayChip({
    required this.label,
    required this.count,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 64,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)
              : null,
          color: selected
              ? null
              : (isDark ? const Color(0xFF141B2D) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday && !selected
                ? AppTheme.primaryColor
                : cs.onSurface.withValues(alpha: 0.08),
            width: isToday && !selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isToday)
              Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('اليوم',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Colors.white
                            : AppTheme.primaryColor)),
              ),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? Colors.white
                        : cs.onSurface.withValues(alpha: 0.8))),
            const SizedBox(height: 3),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : (count > 0
                        ? AppTheme.primaryColor.withValues(alpha: 0.12)
                        : cs.onSurface.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? Colors.white
                          : (count > 0
                              ? AppTheme.primaryColor
                              : cs.onSurface.withValues(alpha: 0.4)))),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── بطاقة الحصة (بتصميم timeline) ────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final _ClassSlot slot;
  final bool   isNow, isPast, isLast;
  final String timeFrom, timeTo;
  final VoidCallback onTap;
  const _ClassCard({
    required this.slot,
    required this.isNow,
    required this.isPast,
    required this.isLast,
    required this.timeFrom,
    required this.timeTo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = slot.color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── عمود الوقت + خط الـ timeline ──────────────────────
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(timeFrom,
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isNow
                            ? color
                            : cs.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 2),
                // نقطة + خط
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isNow ? color : Colors.transparent,
                          border: Border.all(color: color, width: 2),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: color.withValues(alpha: 0.25),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── بطاقة المجموعة ────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Opacity(
                opacity: isPast ? 0.55 : 1.0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF141B2D)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isNow
                              ? color
                              : color.withValues(alpha: 0.18),
                          width: isNow ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isNow
                                ? color.withValues(alpha: 0.2)
                                : Colors.black.withValues(
                                    alpha: isDark ? 0.2 : 0.04),
                            blurRadius: isNow ? 14 : 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // أيقونة ملوّنة
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color,
                                  Color.lerp(color, Colors.black, 0.2)!,
                                ],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(Icons.groups_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          // التفاصيل
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(slot.group.name,
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: cs.onSurface),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (isNow)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _PulseDot(),
                                            SizedBox(width: 4),
                                            Text('الآن',
                                                style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w900,
                                                    color: Colors.white)),
                                          ]),
                                    )
                                  else if (isPast)
                                    Icon(Icons.check_circle_rounded,
                                        size: 16,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.3)),
                                ]),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Flexible(
                                    child: _miniInfo(
                                        Icons.access_time_rounded,
                                        '$timeFrom - $timeTo',
                                        color, cs),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: _miniInfo(
                                        Icons.hourglass_bottom_rounded,
                                        _durationLabel(slot.durationMin),
                                        color, cs),
                                  ),
                                ]),
                                if (slot.studentCount > 0) ...[
                                  const SizedBox(height: 6),
                                  _miniInfo(
                                      Icons.person_rounded,
                                      '${slot.studentCount} طالب',
                                      color, cs),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: cs.onSurface.withValues(alpha: 0.3)),
                        ],
                      ),
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

  Widget _miniInfo(IconData icon, String text, Color color, ColorScheme cs) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.6))),
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
}

// نقطة نابضة لشارة "الآن"
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
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
          width: 6, height: 6,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Colors.white),
        ),
      );
}

// ─── يوم فارغ ─────────────────────────────────────────────────────────────────
class _EmptyDay extends StatelessWidget {
  final String day;
  final bool   isDark;
  final ColorScheme cs;
  const _EmptyDay(
      {required this.day, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.event_available_rounded,
                size: 44,
                color: AppTheme.primaryColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text('لا توجد حصص يوم $day',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          Text('أضف مواعيد للمجموعات من صفحة تفاصيل المجموعة',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.35))),
        ]),
      );
}

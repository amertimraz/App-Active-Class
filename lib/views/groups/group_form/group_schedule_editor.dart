// lib/views/groups/group_form/group_schedule_editor.dart
import 'package:flutter/material.dart';
import 'package:active_class/utils/helpers.dart';

/// محرر المواعيد الأسبوعية للمجموعة — موحَّد بين groups_page.dart
/// وgroup_details_page.dart (كانا فيهم نسختان منفصلتان (_ScheduleEditor
/// وَ_GDScheduleEditor) متطابقتان منطقيًا 100%، راجع
/// specs/039-ui-forms-refactor/research.md #3).
class GroupScheduleEditor extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  const GroupScheduleEditor({super.key, required this.controller, this.onChanged});

  @override
  State<GroupScheduleEditor> createState() => _GroupScheduleEditorState();
}

class _GroupScheduleEditorState extends State<GroupScheduleEditor> {
  static const List<String> _days = [
    'السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'
  ];

  final List<_ScheduleEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _parseFromText();
  }

  void _parseFromText() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    for (final raw in text.split(',')) {
      final s = raw.trim();
      final day = _days.firstWhere((d) => s.startsWith(d), orElse: () => '');
      if (day.isEmpty) continue;
      final times = s.replaceFirst(day, '').trim().split('-');
      if (times.length == 2) {
        final from = _parseTime(times[0].trim());
        final to = _parseTime(times[1].trim());
        if (from != null) {
          _entries.add(_ScheduleEntry(day: day, from: from, to: to ?? _addHour(from)));
        }
      }
    }
    _syncToText();
  }

  TimeOfDay? _parseTime(String v) {
    final p = v.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  void _syncToText() {
    widget.controller.text = _entries
        .map((e) => '${e.day} ${_fmt(e.from)}-${_fmt(e.to)}')
        .join(', ');
    widget.onChanged?.call();
    setState(() {});
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmt(TimeOfDay t) => '${_pad(t.hour)}:${_pad(t.minute)}';
  String _fmtDisplay(TimeOfDay t) => FormatHelper.formatClock(t);

  TimeOfDay _addHour(TimeOfDay t) => TimeOfDay(hour: (t.hour + 1) % 24, minute: t.minute);

  Future<void> _pickTime(int index, bool isFrom) async {
    final cur = isFrom ? _entries[index].from : _entries[index].to;
    // نظام 12/24 ساعة للـpicker متضبوط على مستوى التطبيق كله في main.dart
    // (MediaQuery.alwaysUse24HourFormat) وفق إعداد المستخدم.
    final picked = await showTimePicker(context: context, initialTime: cur);
    if (picked != null) {
      if (isFrom) {
        // بنحافظ على مدة الحصة الحالية بدل ما نفرض ساعة تابتة — لو
        // الموعد كان ساعة ونص مثلاً، لسه هيفضل ساعة ونص بعد تحريك البداية.
        final e = _entries[index];
        final oldDur = (e.to.hour * 60 + e.to.minute) - (e.from.hour * 60 + e.from.minute);
        final durMins = oldDur > 0 ? oldDur : 60;
        final endTotal = (picked.hour * 60 + picked.minute + durMins) % (24 * 60);
        _entries[index] = e.copyWith(
          from: picked,
          to: TimeOfDay(hour: endTotal ~/ 60, minute: endTotal % 60),
        );
      } else {
        // تعديل النهاية فقط — البداية لا تتغير، عشان تقدر تخلي الحصة
        // ساعة ونص بدل ساعة (أو أي مدة تانية) من غير ما تحرك وقت البداية.
        _entries[index] = _entries[index].copyWith(to: picked);
      }
      _syncToText();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('المواعيد الأسبوعية (حد أدنى موعد واحد)',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        ...List.generate(_entries.length, (i) {
          final e = _entries[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: e.day,
                    items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      _entries[i] = e.copyWith(day: val);
                      _syncToText();
                    },
                    decoration: const InputDecoration(labelText: 'اليوم'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(i, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'من'),
                      child: Text(_fmtDisplay(e.from)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(i, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'إلى'),
                      child: Text(_fmtDisplay(e.to)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    _entries.removeAt(i);
                    _syncToText();
                  },
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              _entries.add(_ScheduleEntry(
                day: _days[_entries.isEmpty ? 0 : (_entries.length % _days.length)],
                from: const TimeOfDay(hour: 18, minute: 0),
                to: const TimeOfDay(hour: 19, minute: 0),
              ));
              _syncToText();
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة موعد'),
          ),
        ),
      ],
    );
  }
}

class _ScheduleEntry {
  final String day;
  final TimeOfDay from;
  final TimeOfDay to;
  const _ScheduleEntry({required this.day, required this.from, required this.to});
  _ScheduleEntry copyWith({String? day, TimeOfDay? from, TimeOfDay? to}) =>
      _ScheduleEntry(day: day ?? this.day, from: from ?? this.from, to: to ?? this.to);
}

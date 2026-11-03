// lib/views/groups/group_form/group_schedule_editor.dart
import 'package:flutter/material.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/student_form/form_sections.dart';

/// محرر المواعيد الأسبوعية للمجموعة — موحَّد بين groups_page.dart
/// وgroup_details_page.dart (كانا فيهم نسختان منفصلتان (_ScheduleEditor
/// وَ_GDScheduleEditor) متطابقتان منطقيًا 100%، راجع
/// specs/039-ui-forms-refactor/research.md #3).
class GroupScheduleEditor extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  const GroupScheduleEditor(
      {super.key, required this.controller, this.onChanged});

  @override
  State<GroupScheduleEditor> createState() => _GroupScheduleEditorState();
}

class _GroupScheduleEditorState extends State<GroupScheduleEditor> {
  static const List<String> _days = [
    'السبت',
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة'
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
          _entries.add(
              _ScheduleEntry(day: day, from: from, to: to ?? _addHour(from)));
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

  TimeOfDay _addHour(TimeOfDay t) =>
      TimeOfDay(hour: (t.hour + 1) % 24, minute: t.minute);

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
        final oldDur =
            (e.to.hour * 60 + e.to.minute) - (e.from.hour * 60 + e.from.minute);
        final durMins = oldDur > 0 ? oldDur : 60;
        final endTotal =
            (picked.hour * 60 + picked.minute + durMins) % (24 * 60);
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

  InputDecoration _dec(BuildContext context, String label) => InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: BorderSide(color: context.tokens.line)),
      );

  Widget _timeField(
      BuildContext context, String label, TimeOfDay v, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(context, label),
        child: Text(_fmtDisplay(v),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: context.tokens.ink)),
      ),
    );
  }

  Widget _entryRow(BuildContext context, int i, bool stacked) {
    final t = context.tokens;
    final e = _entries[i];
    final day = DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: e.day,
      style: TextStyle(fontSize: 14, color: t.ink, fontFamily: 'Cairo'),
      items:
          _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
      onChanged: (val) {
        if (val == null) return;
        _entries[i] = e.copyWith(day: val);
        _syncToText();
      },
      decoration: _dec(context, 'اليوم'),
    );
    final from = _timeField(context, 'من', e.from, () => _pickTime(i, true));
    final to = _timeField(context, 'إلى', e.to, () => _pickTime(i, false));
    final del = IconButton(
      tooltip: 'حذف الموعد',
      visualDensity: VisualDensity.compact,
      onPressed: () {
        _entries.removeAt(i);
        _syncToText();
      },
      icon: Icon(Icons.delete_outline_rounded, color: t.danger),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: BoxDecoration(
        color: t.page,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: t.line),
      ),
      child: stacked
          ? Column(children: [
              Row(children: [
                Expanded(child: day),
                const SizedBox(width: 4),
                del
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Row(children: [
                  Expanded(child: from),
                  const SizedBox(width: 8),
                  Expanded(child: to),
                ]),
              ),
            ])
          : Row(children: [
              Expanded(flex: 3, child: day),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: from),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: to),
              del,
            ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(builder: (context, c) {
      // شاشة ضيقة أو خط كبير: كل موعد على سطرين بدل ما الحقول تتزنق.
      final stacked =
          c.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.15;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle('المواعيد الأسبوعية',
              icon: Icons.event_repeat_rounded),
          if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('أضف موعد واحد على الأقل',
                  style: AppType.caption.copyWith(color: t.inkSoft)),
            ),
          for (var i = 0; i < _entries.length; i++)
            _entryRow(context, i, stacked),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                _entries.add(_ScheduleEntry(
                  day: _days[
                      _entries.isEmpty ? 0 : (_entries.length % _days.length)],
                  from: const TimeOfDay(hour: 18, minute: 0),
                  to: const TimeOfDay(hour: 19, minute: 0),
                ));
                _syncToText();
              },
              style: TextButton.styleFrom(foregroundColor: t.brand),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة موعد'),
            ),
          ),
        ],
      );
    });
  }
}

class _ScheduleEntry {
  final String day;
  final TimeOfDay from;
  final TimeOfDay to;
  const _ScheduleEntry(
      {required this.day, required this.from, required this.to});
  _ScheduleEntry copyWith({String? day, TimeOfDay? from, TimeOfDay? to}) =>
      _ScheduleEntry(
          day: day ?? this.day, from: from ?? this.from, to: to ?? this.to);
}

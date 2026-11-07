// lib/widgets/points_rules_sheet.dart
//
// قواعد احتساب النقاط: المعلم يظبط كام نقطة لكل حاجة بأزرار + و−. التغيير
// بيعيد حساب نقاط كل الطلاب فورًا (النقاط مشتقّة من البيانات، مش مخزّنة).
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/student_points.dart';
import 'package:active_class/widgets/app_panel.dart';

/// بيرجّع القواعد الجديدة لو المعلم داس «حفظ»، وإلا null.
Future<PointsRules?> showPointsRulesSheet(
    BuildContext context, PointsRules current) {
  return showModalBottomSheet<PointsRules>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PointsRulesSheet(initial: current),
  );
}

class PointsRulesSheet extends StatefulWidget {
  final PointsRules initial;
  const PointsRulesSheet({super.key, required this.initial});

  @override
  State<PointsRulesSheet> createState() => _PointsRulesSheetState();
}

class _PointsRulesSheetState extends State<PointsRulesSheet> {
  late PointsRules _r = widget.initial;

  Widget _row(AppTokens t, String label, String hint, int value, int min,
      int max, ValueChanged<int> onChanged,
      {int step = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.body.copyWith(color: t.ink)),
                Text(hint, style: AppType.caption.copyWith(color: t.inkSoft)),
              ]),
        ),
        IconButton(
          tooltip: 'نقّص',
          onPressed:
              value > min ? () => onChanged((value - step).clamp(min, max)) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 36,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: AppType.label.copyWith(color: t.ink)),
        ),
        IconButton(
          tooltip: 'زوّد',
          onPressed:
              value < max ? () => onChanged((value + step).clamp(min, max)) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: t.page,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: t.line, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xs),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: t.rosterTint,
                    borderRadius: BorderRadius.circular(AppRadius.control)),
                child: Icon(Icons.tune_rounded, color: t.rosterInk, size: 22),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text('قواعد النقاط',
                    style: AppType.title.copyWith(color: t.ink)),
              ),
            ]),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
              children: [
                Text(
                    'النقاط بتتحسب تلقائيًا من الحضور والامتحانات والواجب '
                    'والتسميع والتفاعل. أي تغيير هنا بيعيد حساب نقاط كل '
                    'الطلاب فورًا.',
                    style: AppType.caption.copyWith(color: t.inkSoft)),
                const SizedBox(height: AppSpace.md),
                _group(t, 'الحضور', [
                  _row(t, 'حضور', 'نقاط كل حصة حضور', _r.present, 0, 50,
                      (v) => setState(() => _r = _r.copyWith(present: v))),
                  _row(t, 'حضور متأخر', 'نقاط الحصة اللي اتأخر فيها', _r.late, 0,
                      50, (v) => setState(() => _r = _r.copyWith(late: v))),
                  _row(
                      t,
                      'مكافأة الانتظام',
                      'تتضاف كل ${_r.streakEvery} حصص حضور متتالية',
                      _r.streakBonus,
                      0,
                      100,
                      (v) => setState(() => _r = _r.copyWith(streakBonus: v)),
                      step: 5),
                  _row(
                      t,
                      'كل كام حصة متتالية',
                      'عدد الحصص المطلوبة للمكافأة',
                      _r.streakEvery,
                      2,
                      20,
                      (v) => setState(() => _r = _r.copyWith(streakEvery: v))),
                ]),
                _group(t, 'الامتحانات', [
                  _row(
                      t,
                      'امتحان بنسبة 100%',
                      'النقاط بتقل بنسبة الدرجة',
                      _r.examFull,
                      0,
                      200,
                      (v) => setState(() => _r = _r.copyWith(examFull: v)),
                      step: 5),
                  _row(
                      t,
                      'مكافأة التفوّق',
                      'امتحان بنسبة 90% أو أكتر',
                      _r.excellenceBonus,
                      0,
                      100,
                      (v) =>
                          setState(() => _r = _r.copyWith(excellenceBonus: v)),
                      step: 5),
                ]),
                _group(t, 'الواجب والتسميع والتفاعل', [
                  _row(
                      t,
                      'واجب كامل',
                      'نقاط الواجب اللي اتعمل',
                      _r.homeworkDone,
                      0,
                      50,
                      (v) => setState(() => _r = _r.copyWith(homeworkDone: v))),
                  _row(
                      t,
                      'واجب ناقص',
                      'نقاط الواجب الناقص',
                      _r.homeworkPartial,
                      0,
                      50,
                      (v) => setState(
                          () => _r = _r.copyWith(homeworkPartial: v))),
                  _row(
                      t,
                      'تسميع بالدرجة الكاملة',
                      'النقاط بتقل بنسبة الدرجة',
                      _r.recitationFull,
                      0,
                      50,
                      (v) =>
                          setState(() => _r = _r.copyWith(recitationFull: v))),
                  _row(
                      t,
                      'تفاعل «نشيط»',
                      'نقاط الحصة اللي كان فيها نشيط',
                      _r.interactionActive,
                      0,
                      50,
                      (v) => setState(
                          () => _r = _r.copyWith(interactionActive: v))),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_r),
                style: FilledButton.styleFrom(
                    backgroundColor: t.brand,
                    minimumSize: const Size(double.infinity, 52)),
                icon: const Icon(Icons.check_rounded),
                label: const Text('حفظ'),
              ),
              const SizedBox(height: AppSpace.xs),
              TextButton(
                onPressed: () => setState(() => _r = PointsRules.defaults),
                style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48)),
                child: const Text('استرجاع القواعد الافتراضية'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _group(AppTokens t, String title, List<Widget> rows) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: Text(title, style: AppType.label.copyWith(color: t.ink)),
          ),
          AppPanel(child: Column(children: rows)),
        ]),
      );
}

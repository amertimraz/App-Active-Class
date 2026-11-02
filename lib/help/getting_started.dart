// lib/help/getting_started.dart
//
// قايمة "ابدأ من هنا" في الرئيسية: خطوات المدرس الجديد. حالة كل خطوة بتتحسب
// من أعداد بياناته الفعلية (بدون تخزين)، فبتتعلّم لوحدها لما يعمل الخطوة.
import 'package:flutter/material.dart';

import 'package:active_class/config/constants.dart';

class GettingStartedStep {
  final String id;
  final String title; // الإجراء: "ضيف أول مجموعة"
  final String hint; // سطر توضيح
  final IconData icon;
  final String route;
  final bool done;
  const GettingStartedStep({
    required this.id,
    required this.title,
    required this.hint,
    required this.icon,
    required this.route,
    required this.done,
  });
}

/// خطوات البداية حسب أعداد البيانات.
List<GettingStartedStep> gettingStartedSteps({
  required int groups,
  required int students,
  required int attendanceRecords,
  required int payments,
}) =>
    [
      GettingStartedStep(
          id: 'group',
          title: 'ضيف أول مجموعة',
          hint: 'الاسم وسعر الاشتراك ومواعيد الحصص',
          icon: Icons.groups_rounded,
          route: ROUTE_GROUPS,
          done: groups > 0),
      GettingStartedStep(
          id: 'students',
          title: 'ضيف طلابك',
          hint: 'واحد واحد أو استيراد من إكسل',
          icon: Icons.person_add_alt_1_rounded,
          route: ROUTE_STUDENTS,
          done: students > 0),
      GettingStartedStep(
          id: 'attendance',
          title: 'سجّل أول حضور',
          hint: 'حاضر أو متأخر أو غائب لكل طالب',
          icon: Icons.how_to_reg_rounded,
          route: ROUTE_ATTENDANCE,
          done: attendanceRecords > 0),
      GettingStartedStep(
          id: 'payment',
          title: 'سجّل أول دفعة',
          hint: 'اختار الطالب واكتب المبلغ',
          icon: Icons.payments_rounded,
          route: ROUTE_PAYMENTS,
          done: payments > 0),
    ];

int gettingStartedDoneCount(List<GettingStartedStep> steps) =>
    steps.where((s) => s.done).length;

/// أول خطوة لسه ما اتعملتش (أو null لو خلّص الكل).
GettingStartedStep? gettingStartedNext(List<GettingStartedStep> steps) {
  for (final s in steps) {
    if (!s.done) return s;
  }
  return null;
}

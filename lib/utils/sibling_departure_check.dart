// lib/utils/sibling_departure_check.dart
//
// spec 035 — فحص مشترك (يُستدعى من شاشة تفاصيل المجموعة وشاشة تفاصيل
// الطالب) لاكتشاف وعرض تنبيه "قرار معلّق" بعد خروج عضو من مجموعة
// إخوة. بيفحص مجموعة إخوة واحدة بس لكل نداء (أول واحدة فيها تنبيه)
// عشان مايحصلش تكديس حوارات فوق بعض.
import 'package:flutter/material.dart';

import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/widgets/sibling_departure_dialog.dart';

/// [activeStudents] لازم تكون قائمة الطلاب النشطين (غير المؤرشفين) —
/// نفس القائمة اللي بتتبعت لـPricingHelper عادةً. بتفحص وتعرض أول
/// تنبيه "خروج عضو" تلاقيه، لو موجود.
Future<void> checkAndShowSiblingDepartureAlert(
  BuildContext context,
  List<Student> activeStudents,
) async {
  for (final student in activeStudents) {
    if (student.siblingGroupId == null) continue;
    final alert =
        PricingHelper.siblingGroupDepartureAlert(student, activeStudents);
    if (alert == null) continue;
    final remaining = activeStudents
        .where((s) => s.siblingGroupId == student.siblingGroupId)
        .toList();
    if (!context.mounted) return;
    await showSiblingDepartureDialogIfNeeded(
      context,
      student: student,
      remainingMembers: remaining,
      oldCount: alert.oldCount,
      newCount: alert.newCount,
    );
    return; // تنبيه واحد بس في المرة — الباقي (لو موجود) في الفتحة الجاية
  }
}

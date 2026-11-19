// lib/utils/report_scope.dart
//
// نطاق شاشة التقارير: كل المجموعات (null) أو مجموعة واحدة أو كل مجموعات سنتر. صرف (بلا شبكة/DB).
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/group_model.dart';

/// مجموعة الـids اللي التقرير بيتحسب عليها، أو null = كل المجموعات.
/// [groupId] ليه الأولوية (اختيار مجموعة بعينها جوّه السنتر). [center]: اسم سنتر أو
/// [GroupController.kNoCenterFilter] لـ«بدون سنتر».
Set<int>? reportScope({
  int? groupId,
  String? center,
  required Iterable<Group> groups,
}) {
  if (groupId != null) return {groupId};
  if (center == null) return null;
  return {
    for (final g in groups)
      if (g.id != null && GroupController.matchesCenter(g, center)) g.id!
  };
}

/// هل [g] (groupId للطالب) داخل النطاق؟ null نطاق = الكل.
bool inReportScope(int? g, Set<int>? scope) =>
    scope == null || (g != null && scope.contains(g));

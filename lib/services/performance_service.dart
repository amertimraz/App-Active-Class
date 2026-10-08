// lib/services/performance_service.dart
//
// spec 050 — جلب بيانات تقرير الأداء (طالب أو مجموعة) وبناءه بالنواة الصرفة.
// بتقرأ من قاعدة البيانات المحلية بس، ومفيهاش أي بيانات مالية.
import 'package:get/get.dart';

import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/performance.dart';

class PerformanceService {
  PerformanceService._();

  /// المؤشرات المفعّلة حسب سويتشات الإعدادات (الواجب/التسميع). الامتحانات
  /// والحضور دايمًا متاحين.
  static Set<PerfKind> enabledKinds() {
    final all = <PerfKind>{PerfKind.exams, PerfKind.attendance};
    if (!Get.isRegistered<SettingsController>()) {
      return {...all, PerfKind.homework, PerfKind.recitation};
    }
    final cfg = Get.find<SettingsController>();
    if (cfg.showHomework.value) all.add(PerfKind.homework);
    if (cfg.showRecitation.value) all.add(PerfKind.recitation);
    return all;
  }

  static Future<StudentPerformance> forStudent(
    Student s,
    DateTime month, {
    String? groupName,
  }) async {
    final db = DatabaseService();
    final attendance = await db.getAttendanceByStudent(s.id!);
    final homework = await db.getHomeworkByStudent(s.id!);
    final exams = await db.getStudentExamHistory(s.id!);
    var gName = groupName;
    if (gName == null) {
      final g = await db.getGroup(s.groupId);
      gName = g?.name ?? '-';
    }
    return buildPerformance(
      student: s,
      groupName: gName,
      month: month,
      attendance: attendance,
      homework: homework,
      exams: exams,
      enabled: enabledKinds(),
    );
  }

  /// أداء كل الطلاب النشطين (غير المؤرشفين) في مجموعة.
  static Future<List<StudentPerformance>> forGroup(
      int groupId, DateTime month) async {
    final db = DatabaseService();
    final g = await db.getGroup(groupId);
    final students = (await db.getStudentsByGroup(groupId))
        .where((s) => !s.isArchived && s.id != null)
        .toList();
    final out = <StudentPerformance>[];
    for (final s in students) {
      out.add(await forStudent(s, month, groupName: g?.name ?? '-'));
    }
    return out;
  }

  /// الشهر الافتراضي للعرض: الحالي لو فيه بيانات، وإلا السابق لو فيه.
  static Future<StudentPerformance> forStudentDefaultMonth(
    Student s, {
    String? groupName,
  }) async {
    final now = DateTime.now();
    final cur = await forStudent(s, now, groupName: groupName);
    if (cur.hasData) return cur;
    final prev = await forStudent(s, DateTime(now.year, now.month - 1, 1),
        groupName: groupName);
    return prev.hasData ? prev : cur;
  }
}

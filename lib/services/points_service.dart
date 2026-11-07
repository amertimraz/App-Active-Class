// lib/services/points_service.dart
//
// تحميل بيانات نقاط الطلاب من القاعدة المحلية (طلاب نشطين + حضور + واجب +
// سجل الامتحانات) وقواعد النقاط المحفوظة على الجهاز، وحسابها بالنواة الصرفة.
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/student_points.dart';

class PointsData {
  final List<Student> students;
  final List<Group> groups;
  final Map<int, List<Attendance>> attendance;
  final Map<int, List<Homework>> homework;
  final Map<int, List<StudentExamRecord>> exams;
  const PointsData({
    required this.students,
    required this.groups,
    required this.attendance,
    required this.homework,
    required this.exams,
  });

  List<RankedPoints> rank({
    required PointsRules rules,
    DateTime? month,
    int? groupId,
  }) =>
      computeLeaderboardPoints(
        students: students,
        attendanceByStudent: attendance,
        homeworkByStudent: homework,
        examsByStudent: exams,
        rules: rules,
        month: month,
        groupId: groupId,
      );
}

class PointsService {
  PointsService._();

  static Future<PointsData> load() async {
    final db = DatabaseService();
    final students =
        (await db.getAllStudents()).where((s) => !s.isArchived).toList();
    final groups = await db.getAllGroups();
    final attendance = <int, List<Attendance>>{};
    for (final a in await db.getAllAttendance()) {
      attendance.putIfAbsent(a.studentId, () => []).add(a);
    }
    final homework = <int, List<Homework>>{};
    for (final h in await db.getAllHomework()) {
      homework.putIfAbsent(h.studentId, () => []).add(h);
    }
    final exams = await db.getAllStudentExamHistories();
    return PointsData(
      students: students,
      groups: groups,
      attendance: attendance,
      homework: homework,
      exams: exams,
    );
  }

  static Future<PointsRules> loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PointsRules.decode(prefs.getString(kPointsRulesPrefsKey));
    } catch (_) {
      return PointsRules.defaults;
    }
  }

  static Future<void> saveRules(PointsRules rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPointsRulesPrefsKey, rules.encode());
  }
}

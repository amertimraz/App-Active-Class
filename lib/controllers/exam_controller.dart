// lib/controllers/exam_controller.dart
import 'package:get/get.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/services/database_service.dart';

class ExamController extends GetxController {
  static ExamController get to => Get.find();

  final _db = DatabaseService();

  final exams     = <Exam>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadExams();
  }

  // ── Exams ─────────────────────────────────────────────────────────────────

  Future<void> loadExams() async {
    isLoading.value = true;
    try {
      exams.value = await _db.getAllExams();
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<Exam>> getExamsForGroup(int groupId) =>
      _db.getExamsForGroup(groupId);

  Future<String?> addExam({
    required String   name,
    required DateTime date,
    required double   maxGrade,
    required double   passingGrade,
    required List<int> groupIds,
  }) async {
    if (name.trim().isEmpty)       return 'أدخل اسم الامتحان';
    if (groupIds.isEmpty)          return 'اختر مجموعة على الأقل';
    if (maxGrade <= 0)             return 'الدرجة الكاملة يجب أن تكون أكبر من صفر';
    if (passingGrade > maxGrade)   return 'درجة النجاح لا تتجاوز الدرجة الكاملة';
    try {
      await _db.insertExam(
        Exam(name: name.trim(), date: date,
            maxGrade: maxGrade, passingGrade: passingGrade),
        groupIds,
      );
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل الحفظ: $e';
    }
  }

  Future<String?> editExam(Exam exam, List<int> groupIds) async {
    if (exam.name.trim().isEmpty) return 'أدخل اسم الامتحان';
    if (groupIds.isEmpty)         return 'اختر مجموعة على الأقل';
    try {
      await _db.updateExam(exam, groupIds);
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل التعديل: $e';
    }
  }

  Future<void> deleteExam(int examId) async {
    await _db.deleteExam(examId);
    await loadExams();
  }

  // ── Grades ────────────────────────────────────────────────────────────────

  Future<List<ExamGrade>> getGradesForExamGroup(
          int examId, int groupId) =>
      _db.getGradesForExamGroup(examId, groupId);

  Future<void> saveGrade({
    required int    examId,
    required int    studentId,
    required double? grade,
    String? notes,
    bool isAbsent = false,
  }) =>
      _db.upsertGrade(
          examId:    examId,
          studentId: studentId,
          grade:     grade,
          notes:     notes,
          isAbsent:  isAbsent);

  Future<ExamGroupStats> getStats(
          int examId, int groupId, String groupName) =>
      _db.getExamGroupStats(examId, groupId, groupName);

  Future<ExamProgress> getExamProgress(int examId) =>
      _db.getExamProgress(examId);

  // ── Student History ───────────────────────────────────────────────────────

  Future<List<StudentExamRecord>> getStudentHistory(int studentId) =>
      _db.getStudentExamHistory(studentId);

  // ── Leaderboard ───────────────────────────────────────────────────────────

  Future<List<LeaderboardEntry>> getLeaderboard({
    int? examId,
    int? groupId,
  }) =>
      _db.getLeaderboard(examId: examId, groupId: groupId);
}

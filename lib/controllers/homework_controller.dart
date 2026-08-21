// lib/controllers/homework_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/config/constants.dart';

class HomeworkController extends GetxController {
  final DatabaseService _dbService = DatabaseService();
  final RxList<Homework> homework = <Homework>[].obs;
  final RxBool isLoading = false.obs;

  Future<void> loadHomework() async {
    isLoading(true);
    try {
      homework.assignAll(await _dbService.getAllHomework());
    } finally {
      isLoading(false);
    }
  }

  /// نفس منطق تبديل الحضور بالظبط: لا يوجد سجل → عمل → لم يعمل → حذف
  /// (رجوع لحالة "غير مسجّل").
  Future<void> toggleHomework(int studentId, DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final existing = homework.firstWhereOrNull((h) =>
        h.studentId == studentId &&
        !h.date.isBefore(dayStart) &&
        !h.date.isAfter(dayEnd));
    try {
      if (existing == null) {
        await _dbService.insertHomework(Homework(
          studentId: studentId,
          date: DateTime(day.year, day.month, day.day,
              DateTime.now().hour, DateTime.now().minute),
          status: HOMEWORK_DONE,
        ));
      } else if (existing.status == HOMEWORK_DONE) {
        await _dbService.updateHomework(existing.copyWith(status: HOMEWORK_NOT_DONE));
      } else {
        await _dbService.deleteHomework(existing.id!);
      }
      await loadHomework();
      unawaited(ParentPortalService().pushStudentSummary(studentId));
    } catch (_) {}
  }

  String? statusFor(int studentId, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final existing = homework.firstWhereOrNull((h) =>
        h.studentId == studentId &&
        !h.date.isBefore(dayStart) &&
        !h.date.isAfter(dayEnd));
    return existing?.status;
  }
}

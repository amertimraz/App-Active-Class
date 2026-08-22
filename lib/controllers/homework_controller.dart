// lib/controllers/homework_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/helpers.dart';

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

  /// نفس منطق "حضر الكل" بالظبط: لو كله متعمَّل بالفعل، الضغطة بتلغي
  /// التسجيل عن الكل؛ غير كده بتسجّل "عمل" للكل. المدرس بعدها يقدر
  /// يستثني طالب أو اتنين بالضغط على أيقونة الواجب بتاعتهم لوحدهم
  /// (تتحول لـ"لم يعمل").
  Future<void> markGroupAllHomeworkDone(
      List<int> studentIds, DateTime day) async {
    if (studentIds.isEmpty) return;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final recordsByStudent = <int, Homework>{
      for (final h in homework)
        if (!h.date.isBefore(dayStart) && !h.date.isAfter(dayEnd))
          h.studentId: h,
    };

    final allAlreadyDone = studentIds
        .every((id) => recordsByStudent[id]?.status == HOMEWORK_DONE);

    var succeeded = 0;
    var failed = 0;
    if (allAlreadyDone) {
      for (final id in studentIds) {
        final record = recordsByStudent[id];
        if (record == null) continue;
        try {
          await _dbService.deleteHomework(record.id!);
          succeeded++;
        } catch (e) {
          failed++;
        }
      }
    } else {
      for (final id in studentIds) {
        final record = recordsByStudent[id];
        try {
          if (record == null) {
            await _dbService.insertHomework(Homework(
              studentId: id,
              date: DateTime(day.year, day.month, day.day,
                  DateTime.now().hour, DateTime.now().minute),
              status: HOMEWORK_DONE,
            ));
          } else if (record.status != HOMEWORK_DONE) {
            await _dbService.updateHomework(
                record.copyWith(status: HOMEWORK_DONE));
          }
          succeeded++;
        } catch (e) {
          failed++;
        }
      }
    }

    await loadHomework();
    for (final id in studentIds) {
      unawaited(ParentPortalService().pushStudentSummary(id));
    }
    if (failed == 0) {
      ToastHelper.success(
          allAlreadyDone ? 'تم إلغاء تسجيل الواجب للكل' : 'تم تسجيل الواجب للكل');
    } else if (succeeded == 0) {
      ToastHelper.error('فشل تسجيل الواجب — حاول تاني');
    } else {
      ToastHelper.error('اتسجّل لـ $succeeded طالب — فشل $failed');
    }
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

// spec 025 — منطق "نسخة جديدة" من امتحان (ما يُنسخ / ما لا يُنسخ).
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = Exam(
    id: 7,
    name: 'امتحان الوحدة 3',
    date: DateTime(2026, 5, 1),
    maxGrade: 20,
    passingGrade: 10,
    reportMonth: '2026-5',
    isOnline: true,
    onlineStatus: OnlineExamStatus.published,
    opensAt: DateTime(2026, 5, 2, 9),
    closesAt: DateTime(2026, 5, 2, 11),
    durationMinutes: 45,
    groupIds: const [1, 2],
  );

  test('يُنسخ: الاسم+(نسخة)، الدرجات، المدة', () {
    final d = ExamController.duplicatedExamMeta(src);
    expect(d.name, 'امتحان الوحدة 3 (نسخة)');
    expect(d.maxGrade, 20);
    expect(d.passingGrade, 10);
    expect(d.durationMinutes, 45);
    expect(d.isOnline, isTrue);
  });

  test('لا يُنسخ: المجموعات، المواعيد، الشهر، حالة النشر', () {
    final d = ExamController.duplicatedExamMeta(src);
    expect(d.groupIds, isEmpty);
    expect(d.opensAt, isNull);
    expect(d.closesAt, isNull);
    expect(d.reportMonth, isNull); // نسخة = امتحان جديد لشهر تاريخه
    expect(d.onlineStatus, OnlineExamStatus.draft);
    expect(d.id, isNull);
  });
}

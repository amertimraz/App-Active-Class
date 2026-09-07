// lib/models/deletable_record_type.dart
//
// أنواع السجلّات القابلة للحذف بمدى تواريخ (spec 028). الطلاب
// والمجموعات (الروستر) مستثناة عمدًا.
import 'package:active_class/config/constants.dart';

enum DeletableRecordType {
  attendance,
  payments,
  examGrades,
  exams,
  homework,
  reportLogs,
}

/// عتبة عدد السجلّات اللي فوقها بيتطلب كتابة كلمة تأكيد قبل الحذف.
const int kBulkDeleteThreshold = 100;

/// الكلمة اللي المدرّس بيكتبها للتأكيد على الحذف الكبير.
const String kDeleteConfirmWord = 'حذف';

extension DeletableRecordTypeX on DeletableRecordType {
  /// اسم يعرضه للمدرّس.
  String get label => switch (this) {
        DeletableRecordType.attendance => 'سجل الحضور',
        DeletableRecordType.payments => 'الدفعات',
        DeletableRecordType.examGrades => 'درجات الامتحانات',
        DeletableRecordType.exams => 'الامتحانات (بدرجاتها)',
        DeletableRecordType.homework => 'الواجبات',
        DeletableRecordType.reportLogs => 'سجلّات تقارير واتساب',
      };

  /// الجدول الأساسي اللي بيتحذف منه.
  String get mainTable => switch (this) {
        DeletableRecordType.attendance => TABLE_ATTENDANCE,
        DeletableRecordType.payments => TABLE_PAYMENTS,
        DeletableRecordType.examGrades => TABLE_EXAM_GRADES,
        DeletableRecordType.exams => TABLE_EXAMS,
        DeletableRecordType.homework => TABLE_HOMEWORK,
        DeletableRecordType.reportLogs => TABLE_REPORT_LOGS,
      };

  /// عمود المفتاح الأساسي (كلها 'id' فعليًا لكن نصرّح للوضوح).
  String get pkColumn => switch (this) {
        DeletableRecordType.attendance => COL_ATTENDANCE_ID,
        DeletableRecordType.payments => COL_PAYMENT_ID,
        DeletableRecordType.examGrades => COL_GRADE_ID,
        DeletableRecordType.exams => COL_EXAM_ID,
        DeletableRecordType.homework => COL_HOMEWORK_ID,
        DeletableRecordType.reportLogs => COL_REPORT_ID,
      };

  /// عمود التاريخ اللي بيتفلتر بيه المدى مباشرةً. `null` لـ examGrades —
  /// دي بتتفلتر بتاريخ الامتحان الأب (exams.date عبر exam_id).
  String? get dateColumn => switch (this) {
        DeletableRecordType.attendance => COL_ATTENDANCE_DATE,
        DeletableRecordType.payments => COL_PAYMENT_DATE,
        DeletableRecordType.homework => COL_HOMEWORK_DATE,
        DeletableRecordType.exams => COL_EXAM_DATE,
        DeletableRecordType.reportLogs => COL_REPORT_SENT_AT,
        DeletableRecordType.examGrades => null,
      };

  /// هل النوع ده مشمول بمزامنة الفريق؟ (report_logs غير مُزامَن — حذفه
  /// محلي فقط، ولا يمرّ على _queueDelete اللي بترمي لجدول غير مُزامَن.)
  bool get isTeamSynced => this != DeletableRecordType.reportLogs;
}

/// حدود المدى للاستعلام: [fromIso, toIso) — يوم البداية 00:00:00 حتى
/// نهاية يوم النهاية (باستثناء أول لحظة من اليوم التالي)، مستقلّ عن
/// جزء الوقت المخزَّن في الصف.
({String fromIso, String toIso}) rangeIsoBounds(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  final endExclusive =
      DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
  return (
    fromIso: start.toIso8601String(),
    toIso: endExclusive.toIso8601String(),
  );
}

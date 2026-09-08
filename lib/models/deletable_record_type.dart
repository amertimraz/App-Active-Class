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

/// حدود المدى للاستعلام كنصّ **تاريخ فقط** (`YYYY-MM-DD`): `[fromIso, toIso)`
/// — يوم البداية شامل، أول لحظة من اليوم التالي للنهاية غير شاملة.
///
/// نستخدم تاريخ فقط (لا وقت) عشان المقارنة النصّية تشتغل صح سواء العمود
/// مخزَّن تاريخ فقط (`"2025-09-01"`) أو ISO كامل (`"2025-09-01T08:00:00.000"`):
/// - `"2025-09-01"` مقابل `fromIso "2025-09-01"` → `>=` ✓ (لو استخدمنا وقت
///   كامل في fromIso كان صف التاريخ-فقط في يوم البداية بالظبط هيتستبعد
///   لأنه "أقصر" وبالتالي أصغر معجميًا).
/// - أي وقت في نفس اليوم `"...T08:00"` أطول ونفس البادئة → أكبر ✓.
({String fromIso, String toIso}) rangeIsoBounds(DateTime from, DateTime to) {
  String d(DateTime x) => x.toIso8601String().substring(0, 10);
  return (
    fromIso: d(DateTime(from.year, from.month, from.day)),
    toIso: d(DateTime(to.year, to.month, to.day).add(const Duration(days: 1))),
  );
}

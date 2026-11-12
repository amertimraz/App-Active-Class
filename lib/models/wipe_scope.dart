// lib/models/wipe_scope.dart
//
// أقسام «حذف بيانات مختارة» (بديل «حذف جميع البيانات» القديم): كل قسم له
// جداوله، وبعض الأقسام بتسحب معاها أقسام تانية (مثلًا حذف الطلاب بيحذف
// حضورهم ودفعاتهم) عشان ما تفضلش بيانات يتيمة. الإعدادات والترخيص وحساب
// الدخول مش داخلين هنا أبدًا.
import 'package:active_class/config/constants.dart';

/// عتبة التأكيد: الحذف دايمًا بيتطلب كتابة الكلمة (الحذف نهائي).
const String kWipeConfirmWord = 'حذف';

enum WipeScope {
  attendance,
  payments,
  expenses,
  homework,
  examResults,
  exams,
  questionBank,
  booklets,
  sessionOverrides,
  reportLogs,
  followUps,
  students,
  groups,
}

/// جدول داخل قسم: اسمه، وهل هو متزامن في وضع الفريق (بنطابور له حذف).
class WipeTable {
  final String name;
  final bool synced;
  const WipeTable(this.name, {this.synced = true});
}

extension WipeScopeX on WipeScope {
  String get label => switch (this) {
        WipeScope.attendance => 'سجل الحضور',
        WipeScope.payments => 'الدفعات',
        WipeScope.expenses => 'المصروفات',
        WipeScope.homework => 'الواجبات',
        WipeScope.examResults => 'درجات ونتايج الامتحانات',
        WipeScope.exams => 'الامتحانات',
        WipeScope.questionBank => 'بنك الأسئلة',
        WipeScope.booklets => 'الكراسات',
        WipeScope.sessionOverrides => 'إلغاء وتعويض الحصص',
        WipeScope.reportLogs => 'سجلّات تقارير واتساب',
        WipeScope.followUps => 'متابعات الطلاب',
        WipeScope.students => 'الطلاب',
        WipeScope.groups => 'المجموعات',
      };

  /// سطر توضيح تحت الاسم.
  String get hint => switch (this) {
        WipeScope.attendance => 'كل حضور وغياب وتسميع وتفاعل',
        WipeScope.payments => 'كل الدفعات والإيصالات المسجّلة',
        WipeScope.expenses => 'مصروفاتك المسجّلة',
        WipeScope.homework => 'تسجيل الواجب لكل الطلاب',
        WipeScope.examResults =>
          'الدرجات ونتايج الامتحان الإلكتروني (الامتحانات نفسها تفضل)',
        WipeScope.exams => 'الامتحانات بأسئلتها ودرجاتها ونتايجها',
        WipeScope.questionBank => 'الأسئلة المحفوظة للاستخدام في الامتحانات',
        WipeScope.booklets => 'الكراسات وتسليمها ومدفوعاتها',
        WipeScope.sessionOverrides => 'الحصص الملغية والتعويضية والإضافية',
        WipeScope.reportLogs => 'سجل التقارير اللي اتبعتت',
        WipeScope.followUps => 'ملاحظات ومتابعات الطلاب المحتاجين متابعة',
        WipeScope.students =>
          'كل الطلاب وسجل أرشفتهم — وبيحذف معاهم حضورهم ودفعاتهم وواجباتهم ودرجاتهم',
        WipeScope.groups =>
          'كل المجموعات وجدولها — وبيحذف معاها الطلاب وكل بياناتهم',
      };

  /// أقسام بتتحذف تلقائيًا مع القسم ده (بيانات تابعة له).
  Set<WipeScope> get requires => switch (this) {
        WipeScope.exams => {WipeScope.examResults},
        WipeScope.students => {
            WipeScope.attendance,
            WipeScope.payments,
            WipeScope.homework,
            WipeScope.examResults,
            WipeScope.followUps,
          },
        WipeScope.groups => {WipeScope.students, WipeScope.sessionOverrides},
        _ => const {},
      };

  /// الجداول بالترتيب الصح للحذف (الأبناء قبل الآباء).
  List<WipeTable> get tables => switch (this) {
        WipeScope.attendance => const [WipeTable(TABLE_ATTENDANCE)],
        WipeScope.payments => const [WipeTable(TABLE_PAYMENTS)],
        WipeScope.expenses => const [WipeTable(TABLE_EXPENSES, synced: false)],
        WipeScope.homework => const [WipeTable(TABLE_HOMEWORK)],
        WipeScope.examResults => const [
            WipeTable(TABLE_EXAM_SUBMISSIONS),
            WipeTable(TABLE_EXAM_GRADES),
          ],
        WipeScope.exams => const [
            WipeTable(TABLE_EXAM_QUESTIONS),
            WipeTable(TABLE_EXAM_GROUPS),
            WipeTable(TABLE_EXAMS),
          ],
        WipeScope.questionBank => const [WipeTable(TABLE_BANK_QUESTIONS)],
        WipeScope.booklets => const [
            WipeTable(TABLE_BOOKLET_PAYMENTS),
            WipeTable(TABLE_BOOKLET_RECORDS),
            WipeTable(TABLE_BOOKLET_GROUPS),
            WipeTable(TABLE_BOOKLETS),
          ],
        WipeScope.sessionOverrides =>
          const [WipeTable(TABLE_SESSION_OVERRIDES)],
        WipeScope.reportLogs =>
          const [WipeTable(TABLE_REPORT_LOGS, synced: false)],
        WipeScope.followUps =>
          const [WipeTable(TABLE_STUDENT_FOLLOW_UPS, synced: false)],
        WipeScope.students => const [
            WipeTable(TABLE_STUDENT_ARCHIVE_EVENTS),
            WipeTable(TABLE_BOOKLET_PAYMENTS),
            WipeTable(TABLE_BOOKLET_RECORDS),
            WipeTable(TABLE_STUDENTS),
          ],
        WipeScope.groups => const [
            WipeTable(TABLE_EXAM_GROUPS),
            WipeTable(TABLE_BOOKLET_GROUPS),
            WipeTable(TABLE_GROUPS),
          ],
      };
}

/// القسم + كل اللي بيسحبه معاه (بشكل متكرر).
Set<WipeScope> wipeClosure(Iterable<WipeScope> selected) {
  final out = <WipeScope>{};
  void add(WipeScope s) {
    if (!out.add(s)) return;
    for (final r in s.requires) {
      add(r);
    }
  }

  for (final s in selected) {
    add(s);
  }
  return out;
}

/// ترتيب حذف آمن للأقسام (الأبناء قبل الآباء) — ثابت.
const List<WipeScope> kWipeOrder = [
  WipeScope.examResults,
  WipeScope.exams,
  WipeScope.booklets,
  WipeScope.attendance,
  WipeScope.payments,
  WipeScope.homework,
  WipeScope.expenses,
  WipeScope.reportLogs,
  WipeScope.followUps,
  WipeScope.sessionOverrides,
  WipeScope.questionBank,
  WipeScope.students,
  WipeScope.groups,
];

/// تجميع العرض في الشاشة: (عنوان المجموعة، أقسامها).
const List<(String, List<WipeScope>)> kWipeGroups = [
  (
    'السجلّات اليومية',
    [
      WipeScope.attendance,
      WipeScope.payments,
      WipeScope.expenses,
      WipeScope.homework,
      WipeScope.sessionOverrides,
      WipeScope.followUps,
      WipeScope.reportLogs,
    ]
  ),
  (
    'الامتحانات والأسئلة',
    [
      WipeScope.examResults,
      WipeScope.exams,
      WipeScope.questionBank,
    ]
  ),
  (
    'الكراسات',
    [WipeScope.booklets],
  ),
  (
    'الأساسيات (بتسحب بياناتها معاها)',
    [
      WipeScope.students,
      WipeScope.groups,
    ]
  ),
];

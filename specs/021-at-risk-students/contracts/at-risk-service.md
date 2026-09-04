# Contract — `AtRiskService` + `AtRiskController`

## `lib/services/at_risk_service.dart` (Dart نقي — صفر Flutter/DB imports)

```dart
class AtRiskSettings {
  final bool absenceEnabled;      final int absenceThreshold;      // K
  final bool homeworkEnabled;     final int homeworkM;  final int homeworkW;
  final bool gradeEnabled;        final int gradeDropPoints;        // P
  final bool paymentEnabled;      final int paymentGraceDays;       // من SettingsController، مش مستقل
  final int cooldownDays;
}

/// يحسب قائمة الطلاب المحتاجين متابعة من بيانات محمّلة بالفعل — قراءة فقط،
/// صفر كتابة، صفر side effects. Caller مسؤول عن تحميل البيانات (الشاشة/
/// الكارت/الإشعار كلهم بينادوها بنفس الشكل).
List<AtRiskStudent> computeAtRiskStudents({
  required List<Student> students,        // غير مؤرشفين فقط (فلترة على الـcaller أو جوّاها)
  required List<Group> groups,
  required List<Attendance> attendance,
  required List<Homework> homework,
  required List<ExamGrade> examGrades,
  required List<Payment> payments,
  required List<StudentFollowUp> recentFollowUps,  // كل الوقائع خلال آخر cooldownDays يوم كحد أقصى
  required AtRiskSettings settings,
  DateTime? now,                          // للاختبار — افتراضي DateTime.now()
});
```

### دوال فرعية خاصة (تفاصيل تنفيذ، للتوجيه فقط)

- `RiskSignal? _checkConsecutiveAbsence(Student, List<Attendance> forStudent, int threshold)` — يفرز حضور الطالب بالتاريخ تنازليًا، يعدّ `ATTENDANCE_ABSENT` المتتالية من الأحدث؛ يتوقف عند أول `ATTENDANCE_PRESENT`/`ATTENDANCE_LATE`.
- `RiskSignal? _checkMissingHomework(Student, List<Homework> forStudent, int m, int w)` — آخر W صف (بالتاريخ)، يعدّ `HOMEWORK_NOT_DONE`/`HOMEWORK_PARTIAL` (عبر `normalizeHomeworkStatus`)؛ لو العدد < w يرجع null (مش كفاية بيانات).
- `RiskSignal? _checkGradeDrop(Student, List<ExamGrade> forStudent, int dropPoints)` — يستبعد الدرجات الفاضية (`isAbsent`/بدون قيمة)، يفرز بتاريخ الامتحان، يقارن نسبة آخر درجة (`grade.percentage`) بمتوسط نسب الباقي **أو** بـ`passingPct` بتاعتها هي (أيهما تحقّق أولاً)؛ يحتاج ≥ 2 درجة إجمالاً.
- `RiskSignal? _checkLatePayment(Student, Group?, List<Attendance> all, List<Payment> forStudent, int graceDays, List<Student> siblingMembers)` — نداء مباشر لـ`PricingHelper.accumulatedDebt` + `PricingHelper.isOverdue` الموجودتين، بدون أي منطق مالي جديد؛ يتخطّى `student.isFullyExempt`/`isExempt`.
- `bool _isAcknowledged(Student, List<RiskSignalType> currentTypes, List<StudentFollowUp> recentFollowUps, int cooldownDays, DateTime now)` — آخر واقعة للطالب (لو فيه) خلال `cooldownDays`: مؤجَّل فقط لو `currentTypes ⊆ lastFollowUp.reasonTypes`.

## `lib/controllers/at_risk_controller.dart` (GetX)

```dart
class AtRiskController extends GetxController {
  final RxList<AtRiskStudent> items = <AtRiskStudent>[].obs;   // بعد استبعاد المؤجَّلين، مرتّبة
  final RxList<AtRiskStudent> snoozed = <AtRiskStudent>[].obs; // المؤجَّلين حاليًا (لتبويب "تمّت متابعتهم")
  final RxInt count = 0.obs;                                    // = items.length، للكارت

  final Rxn<RiskSignalType> reasonFilter = Rxn<RiskSignalType>();
  final RxnInt groupFilter = RxnInt();

  Future<void> refresh();                                        // يعيد التحميل والحساب من الصفر
  Future<void> acknowledge(int studentId, {String? note});        // يكتب صف جديد + refresh()
  Future<void> unacknowledge(int studentId);                      // يحذف آخر صف نشط للطالب + refresh()
}
```

`refresh()` بيحمّل من `DatabaseService`/الـcontrollers الموجودة (زي ما `dashboard_controller._computePaymentCard` بيعمل) بدل ما يكرّر تحميل — لو `AttendanceController`/`ExamController`/... متاحين ومحمّلين، يستخدمهم؛ وإلا يقرا من `DatabaseService` مباشرة.

## `lib/services/notification_service.dart` (إضافات)

```dart
Future<bool> isAtRiskEnabled();
Future<void> setAtRiskEnabled(bool v);

/// يحسب من الـDB مباشرة (نفس نمط scheduleLatePaymentReminder) ويجدول
/// إشعار أسبوعي متكرر. count == 0 → يلغي أي إشعار قديم مجدوَل.
Future<void> scheduleWeeklyAtRiskDigest();
```

يتنادى من نفس نقطة استدعاء `scheduleLatePaymentReminder()` (دورة `syncAllScheduledNotifications` + بعد تغييرات ذات صلة)، وإضافيًا بعد أي تغيير في إعدادات المتابعة (يوم/وقت/تفعيل).

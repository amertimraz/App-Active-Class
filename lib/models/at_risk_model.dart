// lib/models/at_risk_model.dart
//
// spec 021 — كيانات محسوبة وقت العرض (مش مخزَّنة) لميزة "طلاب محتاجين
// متابعة". راجع contracts/at-risk-service.md لتفاصيل الحساب.
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';

enum RiskSignalType { consecutiveAbsence, missingHomework, gradeDrop, latePayment }

/// المفتاح المخزَّن في `student_follow_ups.reason_types` لكل نوع — ثابت
/// عبر الزمن حتى لو تغيّر اسم الـenum لاحقًا.
extension RiskSignalTypeKey on RiskSignalType {
  String get storageKey => switch (this) {
        RiskSignalType.consecutiveAbsence => 'consecutive_absence',
        RiskSignalType.missingHomework => 'missing_homework',
        RiskSignalType.gradeDrop => 'grade_drop',
        RiskSignalType.latePayment => 'late_payment',
      };

  static RiskSignalType? fromStorageKey(String key) => switch (key) {
        'consecutive_absence' => RiskSignalType.consecutiveAbsence,
        'missing_homework' => RiskSignalType.missingHomework,
        'grade_drop' => RiskSignalType.gradeDrop,
        'late_payment' => RiskSignalType.latePayment,
        _ => null,
      };

  String get label => switch (this) {
        RiskSignalType.consecutiveAbsence => 'غياب متتالي',
        RiskSignalType.missingHomework => 'واجب ناقص',
        RiskSignalType.gradeDrop => 'هبوط الدرجات',
        RiskSignalType.latePayment => 'تأخّر الدفع',
      };
}

/// إشارة رصد واحدة على طالب معيّن — [reasonText] نص جاهز للعرض بالأرقام.
class RiskSignal {
  final RiskSignalType type;
  final String reasonText;
  final int severityWeight;

  const RiskSignal({
    required this.type,
    required this.reasonText,
    required this.severityWeight,
  });
}

/// عنصر قائمة "محتاجين متابعة" — طالب واحد بكل إشاراته المتحقّقة.
class AtRiskStudent {
  final Student student;
  final Group? group;
  final List<RiskSignal> signals;

  const AtRiskStudent({
    required this.student,
    required this.group,
    required this.signals,
  });

  int get severityScore =>
      signals.fold(0, (sum, s) => sum + s.severityWeight);

  String? get guardianPhone => student.guardianPhone;

  bool get hasSignal => signals.isNotEmpty;
}

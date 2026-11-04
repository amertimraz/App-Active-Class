// lib/utils/parent_portal_helper.dart
//
// منطق صرف (بلا GetX/DB) لقسم "بوابة أولياء الأمور" في تطبيق المدرس: رابط
// الصفحة، أهلية نشر كل طالب، حالة الإضافة، ورسالة واتساب اللي بتوصّل الرابط
// والكود لولي الأمر. القواعد هنا نفس اللي في ParentPortalService بالظبط
// (آخر 4 أرقام، والكود المطلوب) عشان اللي المدرس بيشوفه في القسم هو اللي
// بيتنشر فعلًا.
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/phone_helper.dart';

/// أساس رابط صفحة المتابعة العامة.
const String kPortalBaseUrl = 'https://active-class.online/track';

String portalUrl(String slug) => '$kPortalBaseUrl/$slug';

/// آخر 4 أرقام من رقم ولي الأمر — null لو الرقم فاضي أو أقل من 4 أرقام.
/// (بتحوّل الأرقام العربية-الهندية لأن أرقام قديمة ممكن تكون مخزّنة بيها.)
String? portalLast4(String? phone) {
  final digits = PhoneHelper.toLatinDigits(phone ?? '')
      .replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 4) return null;
  return digits.substring(digits.length - 4);
}

/// ليه الطالب ظاهر أو مش ظاهر لولي أمره.
enum PortalStudentState {
  /// بيتنشر وولي أمره يقدر يدخل.
  ready,

  /// مش بيتنشر: مفيش رقم ولي أمر صالح (والدخول بالكود + آخر 4 أرقام).
  noPhone,

  /// مش بيتنشر: الطالب بلا كود.
  noCode,
}

/// نفس شروط `_buildSummaryData` في ParentPortalService.
PortalStudentState portalStudentState(Student s, {required bool codeOnly}) {
  if (s.code.trim().isEmpty) return PortalStudentState.noCode;
  if (!codeOnly && portalLast4(s.guardianPhone) == null) {
    return PortalStudentState.noPhone;
  }
  return PortalStudentState.ready;
}

/// عنده وسيلة تواصل (رقم أو واتساب) نبعتله عليها الرابط.
bool portalHasContact(Student s) =>
    (s.guardianPhone ?? '').trim().isNotEmpty ||
    (s.guardianWhatsapp ?? '').trim().isNotEmpty;

class PortalCounts {
  final int ready;
  final int noPhone;
  final int noCode;
  const PortalCounts(this.ready, this.noPhone, this.noCode);

  int get total => ready + noPhone + noCode;
  int get hidden => noPhone + noCode;
}

PortalCounts portalCounts(Iterable<Student> students,
    {required bool codeOnly}) {
  var ready = 0, noPhone = 0, noCode = 0;
  for (final s in students) {
    switch (portalStudentState(s, codeOnly: codeOnly)) {
      case PortalStudentState.ready:
        ready++;
      case PortalStudentState.noPhone:
        noPhone++;
      case PortalStudentState.noCode:
        noCode++;
    }
  }
  return PortalCounts(ready, noPhone, noCode);
}

/// حالة إضافة البوابة (مدّتها).
enum PortalStatusKind { off, lifetime, active, expiringSoon, expired }

class PortalStatus {
  final PortalStatusKind kind;

  /// الأيام المتبقية (للـ active/expiringSoon).
  final int daysLeft;
  final DateTime? expiresAt;
  const PortalStatus(this.kind, {this.daysLeft = 0, this.expiresAt});

  /// شغّالة دلوقتي (أولياء الأمور يقدروا يدخلوا).
  bool get isActive =>
      kind == PortalStatusKind.lifetime ||
      kind == PortalStatusKind.active ||
      kind == PortalStatusKind.expiringSoon;
}

const int kPortalSoonDays = 7;

PortalStatus portalStatus({
  required bool enabled,
  required DateTime? expiresAt,
  required DateTime now,
}) {
  if (!enabled) {
    // مفعّلة سابقًا وانتهت → "منتهية"، ولا اتفعّلت أصلًا → "غير مفعّلة".
    return expiresAt != null
        ? PortalStatus(PortalStatusKind.expired, expiresAt: expiresAt)
        : const PortalStatus(PortalStatusKind.off);
  }
  if (expiresAt == null) return const PortalStatus(PortalStatusKind.lifetime);
  if (!expiresAt.isAfter(now)) {
    return PortalStatus(PortalStatusKind.expired, expiresAt: expiresAt);
  }
  final days = expiresAt.difference(now).inDays;
  return PortalStatus(
    days <= kPortalSoonDays
        ? PortalStatusKind.expiringSoon
        : PortalStatusKind.active,
    daysLeft: days,
    expiresAt: expiresAt,
  );
}

/// رسالة واتساب لولي الأمر بالرابط وكود الطالب. اسم المدرس وتخصصه بيتضافوا
/// تلقائيًا في launchGuardianWhatsapp (withTeacherSignature) فمش بنكرّرهم هنا.
String buildPortalInviteMessage({
  required String studentName,
  required String studentCode,
  required String url,
  required bool codeOnly,
}) {
  final b = StringBuffer()
    ..writeln('📲 *متابعة $studentName*')
    ..writeln('تقدر تتابع حضوره ومدفوعاته وواجبه ودرجاته من الرابط ده:')
    ..writeln(url)
    ..writeln('🔑 كود الطالب: ${studentCode.trim().toUpperCase()}');
  if (!codeOnly) {
    b.writeln('🔒 وبعدين اكتب آخر 4 أرقام من رقم تليفونك المسجّل عندنا.');
  }
  return b.toString().trimRight();
}

/// الدفعات اللي بتظهر لولي الأمر وبتتحسب في "المدفوع": الفلوس اللي اتدفعت
/// فعلًا بس. صفوف "إسقاط مديونية" (المدرس بيمسح بيها دين قديم) مش دفعة —
/// ولي الأمر ماكنش بيفهم ليه "دفع ٤٬٥٠٠" وهو ما دفعهاش. الإسقاط بيفضل
/// محسوب في "المتبقي" (accumulatedDebt بياخد كل الصفوف).
List<Payment> portalVisiblePayments(Iterable<Payment> payments) =>
    payments.where((p) => p.note != kDebtWriteOffNote).toList();

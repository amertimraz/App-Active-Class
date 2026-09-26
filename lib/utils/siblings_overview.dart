// lib/utils/siblings_overview.dart
//
// spec 042 — منطق صرف لشاشة الإخوة: تجميع العيلات + الأرقام المالية/الحضور
// + رسالة واتساب للعيلة. بلا GetX ولا DB. الأرقام المالية من PricingHelper
// حرفيًا (مطابقة تفاصيل الطالب)، والمدفوع بيستبعد إسقاط المديونية (spec 038).
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/phone_helper.dart';
import 'package:active_class/utils/pricing_helper.dart';

class SiblingContact {
  final String phone; // قد يكون فاضي
  final String whatsapp; // قد يكون فاضي
  final String label; // للعرض
  const SiblingContact(this.phone, this.whatsapp, this.label);
}

class SiblingMember {
  final Student student;
  final Group? group;
  final double totalDue;
  final double paid;
  final double remaining;
  final int monthPresent;
  final int monthAbsent;

  const SiblingMember({
    required this.student,
    required this.group,
    required this.totalDue,
    required this.paid,
    required this.remaining,
    required this.monthPresent,
    required this.monthAbsent,
  });

  /// نسبة حضور الشهر، أو null لو مفيش سجلات (حاضر + غائب = 0).
  double? get monthRate {
    final t = monthPresent + monthAbsent;
    return t == 0 ? null : monthPresent / t * 100;
  }
}

class SiblingFamily {
  final int key;
  final List<SiblingMember> members;
  final double? sharedTotal;
  final List<SiblingContact> contacts;

  const SiblingFamily({
    required this.key,
    required this.members,
    required this.sharedTotal,
    required this.contacts,
  });

  double get totalPaid => members.fold(0.0, (s, m) => s + m.paid);
  double get totalRemaining => members.fold(0.0, (s, m) => s + m.remaining);
  double get totalDue => members.fold(0.0, (s, m) => s + m.totalDue);
  bool get hasBalance => totalRemaining > 0.005;
}

/// يبني العيلات من الطلاب النشطين: عيلة = ≥2 نشط بنفس siblingGroupId.
/// مرتّبة: عليها متبقي أولًا ثم بالاسم.
List<SiblingFamily> buildSiblingFamilies({
  required List<Student> activeStudents,
  required List<Group> groups,
  required List<Attendance> attendance,
  required List<Payment> payments,
  required DateTime now,
}) {
  final active = activeStudents.where((s) => !s.isArchived).toList();
  final byKey = <int, List<Student>>{};
  for (final s in active) {
    final k = s.siblingGroupId;
    if (k == null) continue;
    byKey.putIfAbsent(k, () => []).add(s);
  }

  final groupById = {for (final g in groups) g.id: g};
  final attByStudent = <int, List<Attendance>>{};
  for (final a in attendance) {
    attByStudent.putIfAbsent(a.studentId, () => []).add(a);
  }
  final payByStudent = <int, List<Payment>>{};
  for (final p in payments) {
    payByStudent.putIfAbsent(p.studentId, () => []).add(p);
  }

  final families = <SiblingFamily>[];
  byKey.forEach((key, list) {
    if (list.length < 2) return;
    list.sort((a, b) => a.name.compareTo(b.name));

    final members = <SiblingMember>[];
    for (final s in list) {
      final atts = attByStudent[s.id] ?? const <Attendance>[];
      final pays = payByStudent[s.id] ?? const <Payment>[];
      final group = groupById[s.groupId];
      final due = PricingHelper.totalDueThrough(
        student: s,
        group: group,
        allAttendance: atts,
        month: now,
        siblingGroupMembers: active,
      );
      final remaining = PricingHelper.accumulatedDebt(
        student: s,
        group: group,
        allAttendance: atts,
        payments: pays,
        siblingGroupMembers: active,
      );
      final paid = pays
          .where((p) => p.note != kDebtWriteOffNote)
          .fold<double>(0, (t, p) => t + p.amount);
      final inMonth = atts.where(
          (a) => a.date.year == now.year && a.date.month == now.month);
      members.add(SiblingMember(
        student: s,
        group: group,
        totalDue: due,
        paid: paid,
        remaining: remaining < 0 ? 0 : remaining,
        monthPresent:
            inMonth.where((a) => attendanceCountsAsPresent(a.status)).length,
        monthAbsent: inMonth
            .where((a) =>
                normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT)
            .length,
      ));
    }

    double? shared;
    for (final s in list) {
      if (s.siblingsTotal != null) {
        shared = s.siblingsTotal;
        break;
      }
    }

    // أرقام ولي الأمر بدون تكرار (بعد تنظيف الرقم).
    final seen = <String>{};
    final contacts = <SiblingContact>[];
    for (final s in list) {
      final phone = PhoneHelper.cleanForStorage(s.guardianPhone ?? '');
      final wa = (s.guardianWhatsapp ?? '').trim();
      final dedupeKey = phone.isNotEmpty ? phone : wa;
      if (dedupeKey.isEmpty || !seen.add(dedupeKey)) continue;
      contacts.add(SiblingContact(phone, wa, wa.isNotEmpty && phone.isEmpty ? wa : phone));
    }

    families.add(SiblingFamily(
      key: key,
      members: members,
      sharedTotal: shared,
      contacts: contacts,
    ));
  });

  families.sort((a, b) {
    if (a.hasBalance != b.hasBalance) return a.hasBalance ? -1 : 1;
    return a.members.first.student.name
        .compareTo(b.members.first.student.name);
  });
  return families;
}

/// بحث بالاسم/الكود + فلتر "عليها متبقي".
List<SiblingFamily> filterFamilies(List<SiblingFamily> families,
    {String query = '', bool owingOnly = false}) {
  final q = query.trim().toLowerCase();
  return families.where((f) {
    if (owingOnly && !f.hasBalance) return false;
    if (q.isEmpty) return true;
    return f.members.any((m) =>
        m.student.name.toLowerCase().contains(q) ||
        m.student.code.toLowerCase().contains(q));
  }).toList();
}

/// رسالة واتساب واحدة للعيلة. [withFinance] false ⇒ بلا أي رقم مالي.
/// بدون توقيع المعلم (launchGuardianWhatsapp بيضيفه).
String buildFamilyMessage(SiblingFamily f,
    {required bool withFinance, required DateTime month}) {
  final b = StringBuffer()
    ..writeln('السلام عليكم ورحمة الله')
    ..writeln('ملخص أبنائكم — ${_monthLabel(month)}:');
  for (final m in f.members) {
    b.writeln('\n👤 ${m.student.name}${m.group != null ? ' (${m.group!.name})' : ''}');
    final r = m.monthRate;
    b.writeln(r == null
        ? '• الحضور: لا توجد سجلات هذا الشهر'
        : '• الحضور: ${m.monthPresent} حاضر / ${m.monthAbsent} غائب (${r.round()}%)');
    if (withFinance) {
      b.writeln(m.remaining > 0.005
          ? '• المتبقي: ${FormatHelper.formatCurrency(m.remaining)}'
          : '• الحساب مسدّد ✅');
    }
  }
  if (withFinance && f.hasBalance) {
    b.writeln(
        '\n💰 إجمالي المتبقي على العيلة: ${FormatHelper.formatCurrency(f.totalRemaining)}');
  }
  return b.toString();
}

String _monthLabel(DateTime d) {
  const names = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];
  return '${names[d.month - 1]} ${d.year}';
}

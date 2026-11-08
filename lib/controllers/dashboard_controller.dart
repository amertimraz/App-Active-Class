// lib/controllers/dashboard_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/billing_day.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/utils/billing_period.dart';
import 'package:active_class/utils/single_flight.dart';
import 'package:active_class/utils/next_session.dart';

enum ActivityType { attendance, payment }

class UnpaidStudentEntry {
  final Student student;
  final double amountDue; // المديونية المتراكمة الفعلية، مش سعر حصة/شهر واحد بس
  const UnpaidStudentEntry({required this.student, required this.amountDue});
}

// spec 036 — صف مجموعة واحدة في شيت "ملخص دفعات الشهر" (تفصيل حسب
// المجموعة). محسوب من نفس حلقة _computePaymentCardBody — مش مصدر بيانات
// مستقل — عشان مجموع remaining لكل المجموعات يطابق paymentCardRemaining
// الإجمالي بالضبط (SC-002).
// تفصيل طالب واحد داخل مجموعة في شهر معيّن (للتابين متأخر/مدفوع).
class StudentMonthLine {
  final Student student;
  final double due; // مستحق الشهر ده
  final double paid; // فلوس حقيقية اتحسبت على الشهر ده
  final double writtenOff; // اتسقط من المديونية (مش فلوس دخلت)
  final bool unpaid; // ما غطّاش المستحق (متأخر)
  // كل الدفعات الحقيقية للطالب (أي تاريخ) — بتتوزّع FIFO على الشهور، فدفعة
  // مؤرَّخة في شهر تاني ممكن تتحسب على الشهر ده.
  final List<Payment> payments;
  final double dueBefore; // مستحق الشهور اللي قبل الشهر ده
  const StudentMonthLine({
    required this.student,
    required this.due,
    required this.paid,
    required this.writtenOff,
    required this.unpaid,
    this.payments = const [],
    this.dueBefore = 0,
  });
  double get shortfall =>
      (due - paid - writtenOff).clamp(0.0, double.infinity).toDouble();
}

class GroupPaymentSummaryEntry {
  final int? groupId; // null = طلاب بلا مجموعة
  final String groupName;
  final double expected;
  final double collected;
  // مبلغ اتمسح بإسقاط مديونية (مش فلوس دخلت) — بيتخصم من الباقي.
  final double writtenOff;
  final int unpaidStudentsCount;
  final List<StudentMonthLine> lines;

  const GroupPaymentSummaryEntry({
    required this.groupId,
    required this.groupName,
    required this.expected,
    required this.collected,
    this.writtenOff = 0,
    required this.unpaidStudentsCount,
    this.lines = const [],
  });

  double get remaining =>
      (expected - collected - writtenOff).clamp(0.0, double.infinity).toDouble();
}

// spec 036 — نتيجة computeMonthlyBreakdown (راجع أسفل).
class MonthlyPaymentBreakdown {
  final double expected;
  final double collected;
  final double writtenOff;
  final List<UnpaidStudentEntry> unpaidEntries;
  final List<GroupPaymentSummaryEntry> groupBreakdown;

  const MonthlyPaymentBreakdown({
    required this.expected,
    required this.collected,
    this.writtenOff = 0,
    required this.unpaidEntries,
    required this.groupBreakdown,
  });
}

// spec 036 — دالة صرفة (بلا DB/GetX) مستخرَجة من _computePaymentCardBody
// عشان تفضل مصدر حقيقة واحد لحساب "مستحق/محصّل/متأخرين" للشهر المختار،
// سواء إجمالي أو مجمَّع حسب المجموعة — وقابلة للاختبار المباشر (راجع
// research.md #1 وdata-model.md).
MonthlyPaymentBreakdown computeMonthlyBreakdown({
  required List<Student> students,
  required Map<int, List<Payment>> paymentsByStudent,
  required Map<int?, Group> groupById,
  required List<Attendance> allAttendance,
  required DateTime month,
  required DateTime prevMonth,
  // spec 045 — شهر لسه ما نزلش (الجاري قبل يوم نزول المديونية): المستحق
  // والمحصّل بيتعرضوا زي الأول، لكن مفيش حد بيتحسب "لم يدفع/متأخر" فيه.
  bool monthLanded = true,
}) {
  double expected = 0;
  double collected = 0;
  double writtenOff = 0;
  final unpaidEntries = <UnpaidStudentEntry>[];
  final groupTotals = <int?, GroupPaymentSummaryEntry>{};

  for (final s in students.where((s) => !s.isFullyExempt)) {
    final group = groupById[s.groupId];
    final studentPayments = paymentsByStudent[s.id] ?? const <Payment>[];

    // اتسجّل بعد الشهر ده؟ → مايتحسبش فيه.
    final start = s.attendanceStart ?? s.createdAt;
    if (start == null) continue;
    if (DateTime(start.year, start.month, 1).isAfter(month)) continue;

    // مستحق الشهر ده = سعره لهذا الشهر (كامل، أو نسبي لشهر الانضمام،
    // أو بعدد الحصص للمجموعات بالحصة). أول ما الشهر يبدأ بيتحسب كامل
    // — مش مرتبط بوضع "التحصيل المؤخّر" اللي بيخص تنبيه "متأخر" بس.
    final dueThisMonth = PricingHelper.monthlyDue(
      student: s,
      group: group,
      month: month,
      allAttendance: allAttendance,
      siblingGroupMembers: students,
    );
    if (dueThisMonth <= 0) continue;

    // كام من دفعات الطالب راح للشهور اللي قبل ده (FIFO) — الباقي هو
    // اللي اتحسب للشهر ده. القائمة الكاملة (شاملة إسقاط المديونية لو
    // فيه) هي اللي بتحدد "لم يدفع/متأخرين"، عشان الإسقاط يصفّر المتبقي
    // فعليًا زي أي دفعة عادية (راجع research.md § تفصيل تقني مهم، spec 038).
    final dueBefore = PricingHelper.totalDueThrough(
      student: s,
      group: group,
      allAttendance: allAttendance,
      month: prevMonth,
      siblingGroupMembers: students,
    );
    final totalPaid =
        studentPayments.fold<double>(0, (sum, p) => sum + p.amount);
    final paidThisMonth = (totalPaid - dueBefore).clamp(0.0, dueThisMonth);

    // spec 038 — "محصَّل" المعروض في الكارت لازم يستبعد صفوف إسقاط
    // المديونية (مش فلوس حقيقية دخلت) — بيُحسب من نسخة مفلترة منفصلة
    // بنفس منطق FIFO، عشان الرقمين (الحقيقي مقابل "لم يدفع") يفضلوا
    // متسقين مع بعض لنفس الطالب.
    final realPayments = studentPayments
        .where((p) => p.isCollection)
        .toList();
    final realTotalPaid =
        realPayments.fold<double>(0, (sum, p) => sum + p.amount);
    final realPaidThisMonth =
        (realTotalPaid - dueBefore).clamp(0.0, dueThisMonth);

    final writtenOffThisMonth =
        (paidThisMonth - realPaidThisMonth).clamp(0.0, dueThisMonth).toDouble();
    expected += dueThisMonth;
    collected += realPaidThisMonth;
    writtenOff += writtenOffThisMonth;

    // "لم يدفع [الشهر]" = ما غطّاش مستحق الشهر ده تحديدًا (بيختلف من
    // شهر لشهر — الشهر الجاري بدري بيبقى الرقم شبه كامل). مفيش مهلة
    // سماح هنا: الكارت بيعرض واقع، مش تنبيه "متأخر". هنا بنستخدم
    // paidThisMonth الكامل (شامل الإسقاط) عشان طالب اتسقطت مديونيته
    // ميفضلش ظاهر كـ"متأخر".
    final shortfall = dueThisMonth - paidThisMonth;
    final isUnpaid = monthLanded && shortfall > 0.5;
    if (isUnpaid) {
      unpaidEntries.add(UnpaidStudentEntry(student: s, amountDue: shortfall));
    }

    // spec 036 — تجميع نفس dueThisMonth/paidThisMonth على مستوى المجموعة.
    final gKey = s.groupId;
    final existing = groupTotals[gKey];
    groupTotals[gKey] = GroupPaymentSummaryEntry(
      groupId: gKey,
      groupName: group?.name ?? 'بلا مجموعة',
      expected: (existing?.expected ?? 0) + dueThisMonth,
      collected: (existing?.collected ?? 0) + realPaidThisMonth,
      writtenOff: (existing?.writtenOff ?? 0) + writtenOffThisMonth,
      unpaidStudentsCount:
          (existing?.unpaidStudentsCount ?? 0) + (isUnpaid ? 1 : 0),
      lines: [
        ...?existing?.lines,
        StudentMonthLine(
          student: s,
          due: dueThisMonth,
          paid: realPaidThisMonth,
          writtenOff: writtenOffThisMonth,
          unpaid: isUnpaid,
          payments: realPayments,
          dueBefore: dueBefore,
        ),
      ],
    );
  }
  unpaidEntries.sort((a, b) => b.amountDue.compareTo(a.amountDue));

  // FR-006: استبعد أي مجموعة مستحقها صفر (كلهم معفيين/لسه ما انضموش).
  // FR-005: رتّب تنازليًا حسب الباقي.
  final groupBreakdown = groupTotals.values.where((e) => e.expected > 0).toList()
    ..sort((a, b) => b.remaining.compareTo(a.remaining));

  return MonthlyPaymentBreakdown(
    expected: expected,
    collected: collected,
    writtenOff: writtenOff,
    unpaidEntries: unpaidEntries,
    groupBreakdown: groupBreakdown,
  );
}

class TodayPaymentEntry {
  final String studentName;
  final String studentCode;
  final String groupName;
  final double amount;
  final DateTime date;

  const TodayPaymentEntry({
    required this.studentName,
    required this.studentCode,
    required this.groupName,
    required this.amount,
    required this.date,
  });
}

class DashboardController extends GetxController {
  final DatabaseService _db = DatabaseService();

  // ── إحصائيات عامة ────────────────────────────────────────────────────────
  final RxInt totalGroups = 0.obs;
  final RxInt totalStudents = 0.obs;
  final RxInt exemptStudents = 0.obs;

  // ── إحصائيات الشهر الحالي ────────────────────────────────────────────────
  final RxDouble monthExpected = 0.0.obs;
  final RxDouble monthPaid = 0.0.obs;
  final RxDouble monthRemaining = 0.0.obs;
  final RxDouble monthPaymentRate = 0.0.obs;
  final RxInt paidStudentsCount = 0.obs;
  final RxInt unpaidStudentsCount = 0.obs;

  // ── كارت "دفعات [الشهر]" — شهر التحصيل + تنقّل (spec 013 US4) ────────────
  // الأرقام مشتقّة من المديونية المتراكمة (PricingHelper) لحد الشهر
  // المختار، مش "دفعات مؤرَّخة في الشهر ÷ مستحق الشهر".
  final Rx<DateTime> paymentCardMonth = defaultCollectionMonth().obs;
  // أقدم شهر عليه مستحق فعلاً (أقدم تسجيل بين الطلاب النشطين) — الحد
  // الأدنى للتنقّل، عشان مايظهرش شهر مالوش أي مستحق ولا محصّل.
  final Rx<DateTime> paymentCardMinMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1).obs;
  final RxDouble paymentCardExpected = 0.0.obs;
  final RxDouble paymentCardCollected = 0.0.obs;
  final RxDouble paymentCardRemaining = 0.0.obs;
  final RxDouble paymentCardWrittenOff = 0.0.obs;
  final RxDouble paymentCardRate = 0.0.obs;
  final RxInt paymentCardUnpaid = 0.obs;
  // الطلاب اللي ما غطّوش مستحق الشهر المعروض (لكل شهر قائمته) — بالمبلغ
  // الناقص على الشهر ده تحديدًا، مرتّبين تنازليًا.
  final RxList<UnpaidStudentEntry> paymentCardUnpaidList =
      <UnpaidStudentEntry>[].obs;
  // spec 036 — تفصيل نفس المستحق/المحصّل فوق مجمَّع حسب المجموعة، مرتّب
  // تنازليًا حسب الباقي. مجموعات بلا مستحق (expected<=0) مُستبعدة.
  final RxList<GroupPaymentSummaryEntry> paymentCardGroupBreakdown =
      <GroupPaymentSummaryEntry>[].obs;

  // ── إحصائيات اليوم ───────────────────────────────────────────────────────
  final RxInt todayPresent = 0.obs;
  final RxInt todayAbsent = 0.obs;
  final RxInt todayLate = 0.obs; // spec 011 — فئة منفصلة
  final RxInt todayExpected = 0.obs;
  final RxDouble todayAttendanceRate = 0.0.obs;

  // ── مدفوعات اليوم (كل الدفعات، أي مجموعة) ───────────────────────────────
  final RxDouble todayPaymentsTotal = 0.0.obs;
  final RxInt todayPaymentsCount = 0.obs;
  RxList<TodayPaymentEntry> get todayPaymentsList => _todayPaymentsList;
  final RxList<TodayPaymentEntry> _todayPaymentsList =
      <TodayPaymentEntry>[].obs;

  // ── إيراد اليوم من المجموعات المسعّرة بالحصة ────────────────────────────
  // فعلي: من سجلات الحضور "حاضر" اللي اتسجلت النهاردة بالفعل.
  final RxDouble todaySessionRevenue = 0.0.obs;
  final RxInt todaySessionRevenueCount = 0.obs;
  // متوقع: كل طلاب المجموعات المسعّرة بالحصة اللي ليها حصة مجدولة النهاردة
  // (حسب جدول المجموعة الأسبوعي)، بغض النظر عن تسجيل الحضور من عدمه.
  final RxDouble todaySessionRevenueExpected = 0.0.obs;
  final RxInt todaySessionRevenueExpectedCount = 0.obs;

  // ── حالة ─────────────────────────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final Rx<DateTime> lastUpdated = DateTime.now().obs;

  // ── النشاط الأخير ─────────────────────────────────────────────────────────
  final RxList<RecentActivity> recentActivities = <RecentActivity>[].obs;

  // ── الحصة الجاية/الشغالة النهاردة (كارت الرئيسية) ──────────────────────
  final Rx<NextSessionInfo?> nextSession = Rx<NextSessionInfo?>(null);

  // ── قائمة غير المدفوعين (للشيت) ─────────────────────────────────────────
  RxList<UnpaidStudentEntry> get unpaidList => _unpaidList;
  final RxList<UnpaidStudentEntry> _unpaidList = <UnpaidStudentEntry>[].obs;

  // ── للتوافق مع الكود القديم ───────────────────────────────────────────────
  RxInt get totalPaymentsInt => paidStudentsCount;
  RxInt get todayAttendance => todayPresent;
  RxDouble get attendanceRate => todayAttendanceRate;
  RxInt get paidStudents => paidStudentsCount;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  // تجميع الاستدعاءات: كل حدث realtime وارد (وضع الفريق) كان بيعمل إعادة
  // حساب كاملة من أول وجديد، فمع مساعد شغّال كانت النُسخ بتتراكم ومؤشر
  // التحميل يفضل دايمًا على جهاز المالك. دلوقتي نسخة واحدة شغّالة + إعادة
  // واحدة بعدها تغطي كل الأحداث اللي وصلت في الأثناء.
  late final SingleFlight _loader = SingleFlight(_loadDashboardOnce);

  Future<void> loadDashboardData() => _loader.run();

  Future<void> _loadDashboardOnce() async {
    isLoading(true);
    try {
      // كل قسم مستقل بـ try/catch بتاعه (بدل Future.wait اللي كان بيوقف
      // عند أول خطأ ويسيب باقي الأقسام من غير تحديث بصمت) — لو قسم واحد
      // فشل (مثلاً استثناء عابر وقت قراءة DB)، باقي الأقسام (ومنها
      // "مدفوعات اليوم") لازم تتحدّث بالأرقام الصحيحة برضو. الخطأ بيتسجّل
      // بـdebugPrint بدل ما يتبلع بصمت تمامًا، عشان أي تشخيص مستقبلي.
      await Future.wait([
        _guard('عام', _loadGeneralStats),
        _guard('الشهر', _loadMonthStats),
        _guard('كارت الدفعات', _computePaymentCard),
        _guard('اليوم', _loadTodayStats),
        _guard('النشاط الأخير', _loadRecentActivities),
      ]);
      // بعد الباقي لأنها بتعتمد على قايمة المتأخرين في الدفع.
      await _guard('الحصة الجاية', _loadNextSession);
      lastUpdated.value = DateTime.now();
    } finally {
      isLoading(false);
    }
  }

  // ── الحصة الجاية: الشغالة دلوقتي وإلا أقرب حصة لسه ما بدأتش ─────────────
  Future<void> _loadNextSession() async {
    final now = DateTime.now();
    final groups = await _db.getAllGroups();
    final students =
        (await _db.getAllStudents()).where((s) => !s.isArchived).toList();
    final att = Get.isRegistered<AttendanceController>()
        ? Get.find<AttendanceController>()
        : Get.put(AttendanceController());
    final slots = <SessionSlot>[];
    for (final g in att.groupsForDay(groups, now)) {
      final r = parseSessionRange(att.sessionTimeForGroupOnDay(g, now), now);
      if (r != null) slots.add(SessionSlot(g, r.start, r.end));
    }
    _todaySlots = slots;
    _studentCountByGroup = {
      for (final g in groups)
        g.id: students.where((s) => s.groupId == g.id).length
    };
    _overdueByGroup = {
      for (final g in groups)
        g.id: _unpaidList.where((u) => u.student.groupId == g.id).length
    };
    refreshNextSessionClock();
  }

  List<SessionSlot> _todaySlots = const [];
  Map<int?, int> _studentCountByGroup = const {};
  Map<int?, int> _overdueByGroup = const {};
  String _slotsDay = '';

  /// بيعيد اختيار الحصة الجاية/الشغالة بالوقت الحالي من غير قراءة القاعدة —
  /// بتتنادى كل نص دقيقة، فالكارت ما يفضلش يقول «شغالة» بعد ما الحصة تخلص.
  void refreshNextSessionClock() {
    final now = DateTime.now();
    // عدّى يوم جديد: الحصص القديمة مالهاش لازمة لحد التحميل الجاي.
    final today = '${now.year}-${now.month}-${now.day}';
    if (_slotsDay.isNotEmpty && _slotsDay != today) {
      _todaySlots = const [];
    }
    _slotsDay = today;
    final pick = pickNextSlot(_todaySlots, now);
    if (pick == null) {
      nextSession.value = null;
      return;
    }
    final gid = pick.group.id;
    nextSession.value = NextSessionInfo(
      group: pick.group,
      start: pick.start,
      end: pick.end,
      isLive: !now.isBefore(pick.start),
      studentCount: _studentCountByGroup[gid] ?? 0,
      overdueCount: _overdueByGroup[gid] ?? 0,
    );
  }

  Future<void> _guard(String label, Future<void> Function() loader) async {
    try {
      await loader();
    } catch (e) {
      debugPrint('DashboardController: فشل تحميل قسم "$label" — $e');
    }
  }

  @override
  void refresh() => loadDashboardData();

  // ── تحميل الإحصائيات العامة ──────────────────────────────────────────────
  Future<void> _loadGeneralStats() async {
    final groups = await _db.getAllGroups();
    // الطلاب المؤرشفين مستبعدين من كل إحصائيات الداشبورد — دول شغل يومي
    // نشط بس، مش سجل تاريخي.
    final students =
        (await _db.getAllStudents()).where((s) => !s.isArchived).toList();

    totalGroups.value = groups.length;
    totalStudents.value = students.length;
    exemptStudents.value = students.where((s) => s.isFullyExempt).length;
  }

  // ── تحميل إحصائيات الشهر ────────────────────────────────────────────────
  Future<void> _loadMonthStats() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(seconds: 1));

    // الطلاب المؤرشفين مستبعدين — مش من ضمن "المستحق الحالي" (FR-*)
    final students =
        (await _db.getAllStudents()).where((s) => !s.isArchived).toList();
    final payments = await _db.getAllPayments();
    final groups = await _db.getAllGroups();
    final groupById = {for (final g in groups) g.id: g};

    final att = Get.isRegistered<AttendanceController>()
        ? Get.find<AttendanceController>()
        : Get.put(AttendanceController());
    if (att.attendance.isEmpty) await att.loadAttendance();

    final activeStudents = students.where((s) => !s.isFullyExempt).toList();

    // المدفوعات هذا الشهر فقط
    final monthPayments = payments
        .where((p) => !p.date.isBefore(monthStart) && !p.date.isAfter(monthEnd))
        .toList();

    // كل مدفوعات كل طالب (بغض النظر عن تاريخها) — عشان قائمة "لم يدفعوا"
    // تعتمد على المديونية المتراكمة الفعلية (PricingHelper.isOverdue)
    // بدل مقارنة مدفوعات الشهر ده بس بمستحق الشهر ده بس، اللي كان بيوهم
    // إن طالب دافع مقدَّمًا الشهر اللي فات "لسه مايدفعش".
    final paymentsByStudent = <int, List<Payment>>{};
    for (final p in payments) {
      paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }

    // مهلة السماح — بتأخّر ظهور الطالب في قائمة "لم يدفعوا هذا الشهر"
    // بس (مش حساب الإجمالي المتوقع/المحصّل، اللي المفروض يفضل دقيق).
    final graceDays = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>().paymentGraceDays.value
        : 0;

    double expected = 0;
    double paid = 0;
    final unpaidStudents = <UnpaidStudentEntry>[];
    for (final s in activeStudents) {
      final group = groupById[s.groupId];
      final due = PricingHelper.monthlyDue(
        student: s,
        group: group,
        month: monthStart,
        allAttendance: att.attendance,
        siblingGroupMembers: students,
      );
      expected += due;
      final studentPayments = paymentsByStudent[s.id] ?? const [];
      final isOverdue = PricingHelper.isOverdue(
        student: s,
        group: group,
        allAttendance: att.attendance,
        payments: studentPayments,
        graceDays: graceDays,
        siblingGroupMembers: students,
      );
      if (isOverdue) {
        // المديونية المتراكمة الفعلية (كل الشهور غير المدفوعة)، مش سعر
        // حصة/شهر واحد بس — طالب عليه حصتين أو تلاتة كان بيظهر بنفس
        // مبلغ طالب عليه حصة واحدة بس.
        final accumulatedDebt = PricingHelper.accumulatedDebt(
          student: s,
          group: group,
          allAttendance: att.attendance,
          payments: studentPayments,
          siblingGroupMembers: students,
        );
        unpaidStudents
            .add(UnpaidStudentEntry(student: s, amountDue: accumulatedDebt));
      }
    }
    for (final p in monthPayments) {
      paid += p.amount;
    }

    monthExpected.value = expected;
    monthPaid.value = paid;
    monthRemaining.value = (expected - paid).clamp(0, double.infinity);
    monthPaymentRate.value = expected > 0 ? (paid / expected).clamp(0, 1) : 0;

    paidStudentsCount.value = activeStudents.length - unpaidStudents.length;
    unpaidStudentsCount.value = unpaidStudents.length;

    _unpaidList.assignAll(unpaidStudents);
  }

  // ── كارت "دفعات [الشهر]" (spec 013 US4) ────────────────────────────────
  /// تنقّل بين الشهور (سحب أفقي) — محصور في
  /// [paymentCardMinMonth .. الشهر الحالي].
  Future<void> shiftPaymentCardMonth(int delta) async {
    final m = paymentCardMonth.value;
    final next = DateTime(m.year, m.month + delta, 1);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    if (next.isAfter(currentMonth) ||
        next.isBefore(paymentCardMinMonth.value)) {
      return;
    }
    // بنبدّل الاسم فورًا (عشان السحب المتتالي السريع يزبط)، والأرقام
    // تتعتّم لحد ما الحساب يخلّص (paymentCardBusy).
    paymentCardMonth.value = next;
    await _computePaymentCard();
  }

  // توكن تسلسلي — لو المدرس سحب بسرعة مرتين، أكتر من حساب بيشتغل
  // بالتوازي؛ الأقدم مايكتبش نتيجته فوق الأحدث.
  int _payCardToken = 0;
  final RxBool paymentCardBusy = false.obs;

  Future<void> _computePaymentCard() async {
    final token = ++_payCardToken;
    paymentCardBusy.value = true;
    try {
      await _computePaymentCardBody(token);
    } finally {
      if (token == _payCardToken) paymentCardBusy.value = false;
    }
  }

  Future<void> _computePaymentCardBody(int token) async {
    // الكارت بيعرض **الشهر المختار وحده** — "دفعات سبتمبر" = مستحق
    // سبتمبر × المحصّل لسبتمبر، مش إجمالي تراكمي من بداية تسجيل الطالب.
    // المحصّل بيتوزّع FIFO: الدفعات بتغطّي الشهور الأقدم الأول، فطالب
    // دفع مقدَّمًا يبان الشهر ده "محصّل" حتى لو الدفعة مؤرَّخة قبله.
    final students =
        (await _db.getAllStudents()).where((s) => !s.isArchived).toList();
    final payments = await _db.getAllPayments();
    final groups = await _db.getAllGroups();
    final groupById = {for (final g in groups) g.id: g};

    final att = Get.isRegistered<AttendanceController>()
        ? Get.find<AttendanceController>()
        : Get.put(AttendanceController());
    if (att.attendance.isEmpty) await att.loadAttendance();

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    // الكارت بيوصل لحد الشهر الحالي دايمًا — أول ما الشهر يبدأ بيبقى
    // "المتوقع" = مجموع أسعار كل الطلاب المسجّلين، و"المحصّل" 0 وبيزيد
    // مع الدفع. (مش بيتأثر بوضع "التحصيل المؤخّر" — ده بيخص تنبيه
    // "متأخر"، مش تقدّم التحصيل.)

    // أقدم شهر عليه مستحق (أقدم تسجيل بين الطلاب النشطين غير المُعفيين)
    DateTime? earliest;
    for (final s in students.where((s) => !s.isFullyExempt)) {
      final st = s.attendanceStart ?? s.createdAt;
      if (st == null) continue;
      final m = DateTime(st.year, st.month, 1);
      final e = earliest;
      if (e == null || m.isBefore(e)) earliest = m;
    }
    final minMonth = (earliest != null && earliest.isBefore(currentMonth))
        ? earliest
        : currentMonth;

    // ثبّت الشهر المعروض داخل [minMonth .. الشهر الحالي]
    var month =
        DateTime(paymentCardMonth.value.year, paymentCardMonth.value.month, 1);
    if (month.isBefore(minMonth)) month = minMonth;
    if (month.isAfter(currentMonth)) month = currentMonth;

    final prevMonth = DateTime(month.year, month.month - 1, 1);

    final paymentsByStudent = <int, List<Payment>>{};
    for (final p in payments) {
      paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }

    final breakdown = computeMonthlyBreakdown(
      students: students,
      paymentsByStudent: paymentsByStudent,
      groupById: groupById,
      allAttendance: att.attendance,
      month: month,
      prevMonth: prevMonth,
      // المؤخّر ما بيغيّرش الكارت (قرار spec 036)، فاليوم بيأثر في المقدّم بس.
      monthLanded: PricingHelper.billingArrears ||
          monthHasLanded(
            month: month,
            now: DateTime.now(),
            arrears: false,
            billingDay: PricingHelper.billingDay,
          ),
    );
    final expected = breakdown.expected;
    final collected = breakdown.collected;

    // سحبة أحدث سبقتنا → مانكتبش نتيجة قديمة
    if (token != _payCardToken) return;

    final writtenOff = breakdown.writtenOff;
    final remaining = (expected - collected - writtenOff)
        .clamp(0.0, double.infinity)
        .toDouble();
    paymentCardMinMonth.value = minMonth;
    if (month != paymentCardMonth.value) paymentCardMonth.value = month;
    paymentCardUnpaidList.assignAll(breakdown.unpaidEntries);
    paymentCardGroupBreakdown.assignAll(breakdown.groupBreakdown);
    paymentCardExpected.value = expected;
    paymentCardCollected.value = collected;
    paymentCardRemaining.value = remaining;
    paymentCardWrittenOff.value = writtenOff;
    paymentCardRate.value =
        expected > 0 ? (collected / expected).clamp(0.0, 1.0).toDouble() : 0.0;
    paymentCardUnpaid.value = breakdown.unpaidEntries.length;
  }

  // ── تحميل إحصائيات اليوم ────────────────────────────────────────────────
  Future<void> _loadTodayStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final allAtt = await _db.getAllAttendance();
    final todayRecords = allAtt
        .where((a) => !a.date.isBefore(todayStart) && !a.date.isAfter(todayEnd))
        .toList();

    // "متأخر" يُحتسب حضورًا (spec 011)
    final present =
        todayRecords.where((a) => attendanceCountsAsPresent(a.status)).length;
    final absent = todayRecords
        .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT)
        .length;
    final late = todayRecords
        .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_LATE)
        .length;

    // المتوقع = كل طلاب المجموعات اللي ليها حصة مجدولة النهاردة (بصرف النظر
    // عن سجلات الحضور اللي اتسجلت لحد دلوقتي)، مش عدد السجلات المُدخَلة.
    // ملحوظة: الإعفاء (isFullyExempt) خاص بالرسوم بس ومالوش دعوة بالحضور.
    final groups = await _db.getAllGroups();
    final students =
        (await _db.getAllStudents()).where((s) => !s.isArchived).toList();
    final att = Get.isRegistered<AttendanceController>()
        ? Get.find<AttendanceController>()
        : Get.put(AttendanceController());
    final scheduledTodayIds =
        att.groupsForDay(groups, now).map((g) => g.id).toSet();
    final total = scheduledTodayIds.isEmpty
        ? 0
        : students.where((s) => scheduledTodayIds.contains(s.groupId)).length;

    todayPresent.value = present;
    todayAbsent.value = absent;
    todayLate.value = late;
    todayExpected.value = total;
    todayAttendanceRate.value = total > 0 ? present / total : 0;

    // مدفوعات اليوم — كل الدفعات المسجَّلة النهاردة بصرف النظر عن نوع
    // تسعير مجموعة الطالب (شهري أو بالحصة). عمليات إسقاط المديونية
    // (spec 038) مُستبعدة بالكامل هنا — مش فلوس دخلت فعليًا، فمالهاش
    // مكان في قائمة/عدّاد/إجمالي "دفعوا اليوم".
    final payments = await _db.getAllPayments();
    final todayPayments = payments
        .where((p) =>
            !p.date.isBefore(todayStart) &&
            !p.date.isAfter(todayEnd) &&
            p.isCollection)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    todayPaymentsTotal.value =
        todayPayments.fold(0.0, (sum, p) => sum + p.amount);
    todayPaymentsCount.value = todayPayments.length;

    final studentsById = {for (final s in students) s.id: s};
    final groupById = {for (final g in groups) g.id: g};
    _todayPaymentsList.assignAll(todayPayments.map((p) {
      final s = studentsById[p.studentId];
      final g = s != null ? groupById[s.groupId] : null;
      return TodayPaymentEntry(
        studentName: s?.name ?? 'طالب محذوف',
        studentCode: s?.code ?? '-',
        groupName: g?.name ?? '-',
        amount: p.amount,
        date: p.date,
      );
    }));

    // إيراد اليوم من المجموعات بالحصة — فعلي (من الدفعات المحصّلة فعلاً
    // النهاردة) ومتوقع (من كل طلاب المجموعات اللي ليها حصة مجدولة النهاردة).
    final perSessionGroups = groups.where((g) => g.isPerSession).toList();
    final perSessionGroupIds = perSessionGroups.map((g) => g.id).toSet();

    double actualRevenue = 0;
    int actualCount = 0;
    double expectedRevenue = 0;
    int expectedCount = 0;

    if (perSessionGroupIds.isNotEmpty) {
      // فعلي: مجموع الدفعات المسجَّلة النهاردة لطلاب المجموعات بالحصة —
      // ده "المحصّل" الحقيقي (كاش دخل)، مش استحقاق نظري من الحضور بس.
      for (final p in todayPayments) {
        final s = studentsById[p.studentId];
        if (s == null || !perSessionGroupIds.contains(s.groupId)) continue;
        actualRevenue += p.amount;
        actualCount += 1;
      }

      final scheduledTodayPerSessionIds =
          scheduledTodayIds.intersection(perSessionGroupIds);
      if (scheduledTodayPerSessionIds.isNotEmpty) {
        for (final s in students) {
          if (!scheduledTodayPerSessionIds.contains(s.groupId)) continue;
          if (s.isFullyExempt) continue;
          expectedRevenue += s.effectivePrice;
          expectedCount += 1;
        }
      }
    }

    todaySessionRevenue.value = actualRevenue;
    todaySessionRevenueCount.value = actualCount;
    todaySessionRevenueExpected.value = expectedRevenue;
    todaySessionRevenueExpectedCount.value = expectedCount;
  }

  // ── تحميل النشاط الأخير ─────────────────────────────────────────────────
  Future<void> _loadRecentActivities() async {
    final activities = <RecentActivity>[];

    // آخر 5 دفعات
    final payments = await _db.getAllPayments();
    final sortedPayments = payments.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final p in sortedPayments.take(5)) {
      final student = await _db.getStudent(p.studentId);
      if (student != null) {
        activities.add(RecentActivity(
          type: ActivityType.payment,
          title: student.name,
          subtitle: 'دفع ${p.amount.toStringAsFixed(0)}',
          date: p.date,
          icon: Icons.payments_rounded,
          color: AppTheme.primaryColor,
          amount: p.amount,
        ));
      }
    }

    // آخر 5 سجلات حضور
    final attendance = await _db.getAllAttendance();
    final sortedAtt = attendance.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final a in sortedAtt.take(5)) {
      final student = await _db.getStudent(a.studentId);
      if (student != null) {
        final norm = normalizeAttendanceStatus(a.status);
        final isLate = norm == ATTENDANCE_LATE;
        final counts = attendanceCountsAsPresent(a.status);
        activities.add(RecentActivity(
          type: ActivityType.attendance,
          title: student.name,
          subtitle: isLate ? 'متأخر' : (counts ? 'حضر' : 'غاب'),
          date: a.date,
          icon: isLate
              ? Icons.schedule_rounded
              : counts
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
          color: isLate
              ? const Color(0xFFF59E0B)
              : counts
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
        ));
      }
    }

    // ترتيب حسب التاريخ الفعلي
    activities.sort((a, b) => b.date.compareTo(a.date));
    recentActivities.assignAll(activities.take(10));
  }

  // ── للتوافق مع الكود القديم ───────────────────────────────────────────────
  Future<Map<String, int>> getStudentsPerGroup() async {
    final groups = await _db.getAllGroups();
    final Map<String, int> result = {};
    for (final g in groups) {
      result[g.name] = await _db.getGroupStudentCount(g.id!);
    }
    return result;
  }
}

// ══════════════════════════════════════════════════════════════════
//  RecentActivity model
// ══════════════════════════════════════════════════════════════════
class RecentActivity {
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime date;
  final IconData icon;
  final Color color;
  final double? amount;

  RecentActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.color,
    this.amount,
  });

  /// وقت نسبي مقروء
  String get timeLabel {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${date.day}/${date.month}/${date.year}';
  }
}

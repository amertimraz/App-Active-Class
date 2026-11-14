import 'package:get/get.dart';
import 'package:printing/printing.dart';
import 'package:active_class/utils/debtors_report.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/utils/billing_period.dart';
import 'package:active_class/utils/billing_day.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/config/constants.dart';

class ReportController extends GetxController {
  final DatabaseService _dbService = DatabaseService();

  // ─── Raw data ───────────────────────────────────────────────────────────────
  final RxList<Payment> allPayments = <Payment>[].obs;
  final RxList<Attendance> allAttendance = <Attendance>[].obs;
  final RxList<Homework> allHomework = <Homework>[].obs;
  final RxList<Student> allStudents = <Student>[].obs;
  final RxList<Group> allGroups = <Group>[].obs;
  // المؤرشفين: مستبعدين من الطلاب والمستحقات والمتأخرات، لكن دفعاتهم الفعلية
  // لازم تفضل محسوبة في «المحصّل» (الفلوس دخلت فعلًا في شهرها).
  final RxList<Student> archivedStudents = <Student>[].obs;
  // الامتحانات ودرجاتها (طلاب غير مؤرشفين) — لتبويب «الامتحانات».
  final RxList<Exam> allExams = <Exam>[].obs;
  final RxList<ExamGrade> allExamGrades = <ExamGrade>[].obs;

  // ─── Selected month ─────────────────────────────────────────────────────────
  // يفتح على "شهر التحصيل الافتراضي" (آخر شهر مكتمل لو أول الشهر أو
  // التحصيل المؤخّر مفعّل) — نفس منطق باقي الشاشات الشهرية (spec 013).
  final Rx<DateTime> selectedMonth = Rx<DateTime>(defaultCollectionMonth());

  final RxBool isLoading = false.obs;

  // التحميل بتعمله الصفحة (initState) — كان بيتكرر مرتين عند أول فتح.
  // رقم بيزيد مع كل تحميل عشان كاش الحسابات يتجدد.
  int _dataVersion = 0;

  Future<void> loadReports() async {
    isLoading(true);
    try {
      final payments = await _dbService.getAllPayments();
      final attendance = await _dbService.getAllAttendance();
      final homework = await _dbService.getAllHomework();
      final students = await _dbService.getAllStudents();
      final groups = await _dbService.getAllGroups();
      allExams.assignAll(await _dbService.getAllExams());
      allExamGrades.assignAll(await _dbService.getAllExamGradesWithExamInfo());
      allPayments.assignAll(payments);
      allAttendance.assignAll(attendance);
      allHomework.assignAll(homework);
      // الطلاب المؤرشفين مستبعدين من كل حسابات وقوائم التقارير — زي
      // الداشبورد والإشعارات و StudentController (spec 013).
      allStudents.assignAll(students.where((s) => !s.isArchived).toList());
      archivedStudents.assignAll(students.where((s) => s.isArchived).toList());
      allGroups.assignAll(groups);
      _dataVersion++;
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل التقارير');
    } finally {
      isLoading(false);
    }
  }

  void setMonth(DateTime month) {
    selectedMonth.value = DateTime(month.year, month.month, 1);
  }

  // ─── Month-scoped helpers ───────────────────────────────────────────────────

  List<Payment> get monthPayments {
    final m = selectedMonth.value;
    return allPayments
        .where((p) => p.date.year == m.year && p.date.month == m.month)
        .toList();
  }

  List<Attendance> get monthAttendance => attendanceIn(selectedMonth.value);

  List<Attendance> attendanceIn(DateTime m) {
    final start = DateTime(m.year, m.month, 1);
    final end = DateTime(m.year, m.month + 1, 1)
        .subtract(const Duration(microseconds: 1));
    return allAttendance
        .where((a) => !a.date.isBefore(start) && !a.date.isAfter(end))
        .toList();
  }

  // spec 038 — "المحصَّل" هنا رقم مالي حقيقي (فلوس دخلت فعليًا)، فلازم
  // يستبعد صفوف إسقاط المديونية (راجع research.md § تفصيل تقني مهم).
  // ─── أرقام الشهر المالية: نفس حساب كارت «دفعات» في الرئيسية ─────────────
  // المحصّل لشهر ما = اللي اتوزّع عليه من فلوس الطالب بالأقدم أولًا (FIFO)
  // بغض النظر عن تاريخ الدفعة — فدفعة مؤرّخة في شهر تاني ممكن تغطّي الشهر ده.
  // (كان بيتحسب بتاريخ الدفعة فقط، فشهر مدفوع بالكامل في الرئيسية كان يطلع
  // «نسبة تحصيل 26%» هنا.)
  double get monthTotalCollected => _snapshot.collected;

  /// المتوقع للشهر (مجموع مستحقات الطلاب) — نفس رقم الرئيسية.
  double get monthExpected => _snapshot.expected;

  /// الباقي على الطلاب لشهر معيّن (المتوقع − المحصّل − المُسقَط) — نفس رقم
  /// الرئيسية، وبيطابق مجموع قايمة «غير المسددين».
  double get totalOverdue => _snapshot.remaining;

  /// اللي دفعه طلاب مؤرشفين وداخل في المتوقع والمحصّل (للتنويه في الشاشة).
  double get archivedPaidIncluded => _snapshot.archivedPaid;

  // "متأخر" يُحتسب حضورًا (spec 011)
  int get monthPresentCount =>
      monthAttendance.where((a) => attendanceCountsAsPresent(a.status)).length;

  int get monthAbsentCount => monthAttendance
      .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT)
      .length;

  int get monthLateCount => monthAttendance
      .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_LATE)
      .length;

  List<Homework> get monthHomework => homeworkIn(selectedMonth.value);

  List<Homework> homeworkIn(DateTime m) {
    final start = DateTime(m.year, m.month, 1);
    final end = DateTime(m.year, m.month + 1, 1)
        .subtract(const Duration(microseconds: 1));
    return allHomework
        .where((h) => !h.date.isBefore(start) && !h.date.isAfter(end))
        .toList();
  }

  // ─── Per-group summary for selected month ──────────────────────────────────

  // الطلاب الذين كانوا مسجّلين قبل نهاية الشهر المحدد
  List<Student> get _studentsActiveInMonth =>
      _studentsActiveIn(selectedMonth.value);

  List<Student> _studentsActiveIn(DateTime m) {
    final monthEnd = DateTime(m.year, m.month + 1, 1)
        .subtract(const Duration(microseconds: 1));
    return allStudents.where((s) {
      if (s.createdAt == null) return true; // بدون تاريخ → نعدّه دائمًا نشطًا
      return !s.createdAt!.isAfter(monthEnd);
    }).toList();
  }

  // ─── حساب واحد مُخزَّن لكل (شهر + بيانات) ─────────────────────────────────
  // كان كل طالب بيتحسب مستحقه 4–5 مرات وبيتمسح كل الحضور في كل مرة (4.8 ثانية
  // على 400 طالب و20 ألف حضور). دلوقتي: حضور ودفعات كل طالب بتتجمّع مرة، والمستحق
  // بيتحسب مرة واحدة، والنتيجة بتتخزّن لحد ما الشهر أو البيانات تتغيّر.
  _ReportSnapshot? _snap;
  String? _snapKey;

  _ReportSnapshot get _snapshot {
    // لمس الـRx عشان Obx يتابع التغيير.
    final m = selectedMonth.value;
    final key = '${m.year}-${m.month}|${allStudents.length}|${allGroups.length}|'
        '${allPayments.length}|${allAttendance.length}|${allHomework.length}|'
        '${archivedStudents.length}|$_dataVersion';
    if (_snap != null && _snapKey == key) return _snap!;
    _snap = _computeSnapshot(m);
    _snapKey = key;
    return _snap!;
  }

  _ReportSnapshot _computeSnapshot(DateTime m) {
    final prevMonth = DateTime(m.year, m.month - 1, 1);
    final activeStudents = _studentsActiveIn(m);
    final studentsByGroup = <int, List<Student>>{};
    for (final s in activeStudents) {
      studentsByGroup.putIfAbsent(s.groupId, () => []).add(s);
    }

    final presentByStudent = <int, int>{};
    final lateByStudent = <int, int>{};
    for (final a in attendanceIn(m)) {
      if (attendanceCountsAsPresent(a.status)) {
        presentByStudent.update(a.studentId, (v) => v + 1, ifAbsent: () => 1);
      }
      if (normalizeAttendanceStatus(a.status) == ATTENDANCE_LATE) {
        lateByStudent.update(a.studentId, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    final homeworkDoneByStudent = <int, int>{};
    final homeworkPartialByStudent = <int, int>{};
    final homeworkNotDoneByStudent = <int, int>{};
    for (final h in homeworkIn(m)) {
      switch (normalizeHomeworkStatus(h.status)) {
        case HOMEWORK_DONE:
          homeworkDoneByStudent.update(h.studentId, (v) => v + 1,
              ifAbsent: () => 1);
        case HOMEWORK_PARTIAL:
          homeworkPartialByStudent.update(h.studentId, (v) => v + 1,
              ifAbsent: () => 1);
        case HOMEWORK_NOT_DONE:
          homeworkNotDoneByStudent.update(h.studentId, (v) => v + 1,
              ifAbsent: () => 1);
        default:
          break;
      }
    }

    // حضور ودفعات كل طالب (مرة واحدة) — الدوال بتفلتر بالطالب أصلًا، فتمرير
    // سجلاته بس نتيجته نفس الشيء وأسرع بكتير.
    final attByStudent = <int, List<Attendance>>{};
    for (final a in allAttendance) {
      attByStudent.putIfAbsent(a.studentId, () => []).add(a);
    }
    final payByStudent = <int, List<Payment>>{};
    for (final p in allPayments) {
      payByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }

    // الأرقام الأساسية (المتوقع/المحصّل/المتأخر/قايمة غير المسددين) على الطلاب
    // النشطين بس — نفس استدعاء الداشبورد بالظبط (مصدر حقيقة واحد)، فتطابق
    // كارت «دفعات» في الرئيسية.
    final groupById = <int?, Group>{for (final g in allGroups) g.id: g};
    final monthLanded = PricingHelper.billingArrears ||
        monthHasLanded(
          month: m,
          now: DateTime.now(),
          arrears: false,
          billingDay: PricingHelper.billingDay,
        );
    MonthlyPaymentBreakdown breakdownFor(List<Student> students) =>
        computeMonthlyBreakdown(
          students: students,
          paymentsByStudent: payByStudent,
          groupById: groupById,
          allAttendance: allAttendance,
          month: m,
          prevMonth: prevMonth,
          monthLanded: monthLanded,
        );
    final breakdown = breakdownFor(allStudents.toList());

    // طلاب اتأرشفوا بعد كده بس كانوا شغالين في الشهر ده: فلوسهم اللي دخلت
    // وقتها ما تختفيش من تقريره. بنضيف **اللي دفعوه بس**: يزيد المحصّل
    // والمتوقع بنفس المبلغ، من غير ما نحمّلهم مديونية أو نعرضهم في «غير
    // المسددين» (مش طلاب حاليين). الشهور اللي كانوا مؤرشفين فيها بتتستبعد.
    final archivedInMonth = archivedStudents
        .where((a) => !PricingHelper.isPausedMonth(a, m))
        .toList();
    final archivedPaidByGroup = <int?, double>{};
    var archivedPaid = 0.0;
    if (archivedInMonth.isNotEmpty) {
      // الحساب مع المؤرشفين عشان توزيع الدفعات (FIFO) والخصومات يفضلوا نفس
      // منطق الشهور اللي فاتت؛ بنقرا منه سطور المؤرشفين بس.
      final full = breakdownFor([...allStudents, ...archivedInMonth]);
      for (final e in full.groupBreakdown) {
        for (final l in e.lines) {
          if (!l.student.isArchived || l.paid <= 0) continue;
          archivedPaidByGroup[l.student.groupId] =
              (archivedPaidByGroup[l.student.groupId] ?? 0) + l.paid;
          archivedPaid += l.paid;
        }
      }
    }

    final entryByGroup = <int?, GroupPaymentSummaryEntry>{
      for (final e in breakdown.groupBreakdown) e.groupId: e
    };

    final groups = allGroups.map((g) {
      final students = studentsByGroup[g.id] ?? [];
      final entry = entryByGroup[g.id];
      final lines = entry?.lines ?? const <StudentMonthLine>[];
      final totalPresent =
          students.fold<int>(0, (s, st) => s + (presentByStudent[st.id] ?? 0));
      final totalLate =
          students.fold<int>(0, (s, st) => s + (lateByStudent[st.id] ?? 0));
      // "الناقص" يُحسب ضمن "عمل الواجب" في ملخّص المجموعة (محاولة تُحتسب).
      final totalHomeworkDone = students.fold<int>(
          0,
          (s, st) =>
              s +
              (homeworkDoneByStudent[st.id] ?? 0) +
              (homeworkPartialByStudent[st.id] ?? 0));
      final totalHomeworkNotDone = students.fold<int>(
          0, (s, st) => s + (homeworkNotDoneByStudent[st.id] ?? 0));
      return GroupMonthSummary(
        group: g,
        studentCount: students.length,
        expectedIncome:
            (entry?.expected ?? 0) + (archivedPaidByGroup[g.id] ?? 0),
        collectedIncome:
            (entry?.collected ?? 0) + (archivedPaidByGroup[g.id] ?? 0),
        // «دافع بالكامل» = غطّى مستحق الشهر ده (نفس منطق الرئيسية).
        fullyPaidCount: lines.where((l) => !l.unpaid).length,
        dueStudentCount: lines.length,
        totalPresentSessions: totalPresent,
        totalLateSessions: totalLate,
        totalHomeworkDone: totalHomeworkDone,
        totalHomeworkNotDone: totalHomeworkNotDone,
      );
    }).toList();

    // غير المسددين لهذا الشهر: نفس قايمة الرئيسية (المتبقي على مستحق الشهر).
    final unpaid = <AtRiskStudent>[
      for (final e in breakdown.groupBreakdown)
        for (final l in e.lines)
          if (l.unpaid)
            AtRiskStudent(
              student: l.student,
              group: groupById[l.student.groupId],
              paid: l.due - l.shortfall,
              due: l.due,
              month: m,
              monthDue: l.due,
            ),
    ]..sort((a, b) {
        final c = b.remaining.compareTo(a.remaining);
        return c != 0 ? c : a.student.name.compareTo(b.student.name);
      });

    final remaining = (breakdown.expected -
            breakdown.collected -
            breakdown.writtenOff)
        .clamp(0.0, double.infinity)
        .toDouble();
    return _ReportSnapshot(
      groups: groups,
      unpaid: unpaid,
      expected: breakdown.expected + archivedPaid,
      collected: breakdown.collected + archivedPaid,
      remaining: remaining,
      archivedPaid: archivedPaid,
    );
  }

  List<GroupMonthSummary> get groupSummaries => _snapshot.groups;

  // ─── أرقام شهر تاني (للمقارنة والاتجاه) ───────────────────────────────────
  // نفس حساب الشهر المختار بالظبط، مخزّن لكل شهر لحد ما البيانات تتغيّر.
  final Map<String, _ReportSnapshot> _otherMonths = {};
  int _otherVersion = -1;

  /// مجموعات شهر [m] (متوقع/محصّل/واجب لكل مجموعة) — لمقارنة الشهور.
  List<GroupMonthSummary> groupSummariesFor(DateTime m) {
    final month = DateTime(m.year, m.month, 1);
    final sel = selectedMonth.value;
    if (month.year == sel.year && month.month == sel.month) {
      return _snapshot.groups;
    }
    final ver = _dataVersion * 1000003 +
        allPayments.length * 31 +
        allAttendance.length * 17 +
        allStudents.length;
    if (_otherVersion != ver) {
      _otherMonths.clear();
      _otherVersion = ver;
    }
    return _otherMonths
        .putIfAbsent('${month.year}-${month.month}', () => _computeSnapshot(month))
        .groups;
  }

  // ─── تفصيل الحصص (بس للمجموعات "بالحصة") ────────────────────────────────────
  /// كل تاريخ حضور فيه الشهر ده لطلاب المجموعة دي — سطر لكل حصة، بعدد
  /// الحاضرين والمتوقع منها (سعر كل طالب حاضر × نسبة إعفائه)، عشان
  /// المدرس يتابع أول بأول بدل ما يستنى رقم شهري مجمّع في آخر الشهر.
  List<SessionDay> sessionBreakdownForGroup(int groupId) {
    final group = allGroups.firstWhereOrNull((g) => g.id == groupId);
    if (group == null || !group.isPerSession) return [];

    final students =
        _studentsActiveInMonth.where((s) => s.groupId == groupId).toList();
    final studentById = {for (final s in students) s.id: s};

    final byDate = <DateTime, List<Attendance>>{};
    for (final a in monthAttendance) {
      // "متأخر" حصة محضورة كاملة زي "حاضر" (spec 011)
      if (!attendanceCountsAsPresent(a.status)) continue;
      if (!studentById.containsKey(a.studentId)) continue;
      final d = DateTime(a.date.year, a.date.month, a.date.day);
      byDate.putIfAbsent(d, () => []).add(a);
    }

    final result = byDate.entries.map((e) {
      final amount = e.value.fold<double>(0, (s, a) {
        final st = studentById[a.studentId];
        if (st == null) return s;
        return s + st.price * (1 - st.exemptPercent / 100);
      });
      return SessionDay(
          date: e.key, presentCount: e.value.length, expectedAmount: amount);
    }).toList();
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  // ─── At-risk students (مديونية متراكمة لحد الشهر ده) ────────────────────────

  /// بيعتمد على المديونية المتراكمة (كل الشهور لحد الشهر المختار مطروح
  /// منها كل المدفوعات) بدل مدفوعات الشهر ده بس — نفس منطق PricingHelper
  /// المستخدم في باقي التطبيق (الداشبورد، تفاصيل المجموعة/الطالب، الـQR).
  /// وإلا طالب دفع مقدَّمًا شهر سابق كان هيظهر هنا "متأخر" غلط.
  /// غير المسددين للشهر المختار (المتبقي على مستحق الشهر ده) — نفس قايمة
  /// الرئيسية.
  List<AtRiskStudent> get unpaidStudents => _snapshot.unpaid;

  // ─── Legacy ─────────────────────────────────────────────────────────────────

  Future<void> generateReport() async => loadReports();

  // ── تصدير PDF ─────────────────────────────────────────────────────────────

  final RxBool isExporting = false.obs;
  final _exportSvc = ExportService();

  /// طباعة قائمة الطلاب اللي عليهم مديونية (حتى الشهر المختار).
  /// [groupId] null = كل المجموعات. بتفتح معاينة الطباعة/المشاركة.
  Future<void> printDebtors({int? groupId}) async {
    if (isExporting.value) return;
    final rows = prepareDebtorRows(
      unpaidStudents.map((u) => DebtorRow(
            name: u.student.name,
            code: u.student.code,
            groupId: u.group?.id,
            groupName: u.group?.name ?? '—',
            guardianPhone: (u.student.guardianPhone ?? '').trim(),
            due: u.due,
            remaining: u.remaining,
          )),
      groupId: groupId,
    );
    if (rows.isEmpty) {
      ToastHelper.info('مفيش طلاب عليهم مديونية');
      return;
    }
    isExporting(true);
    try {
      final groupName = groupId == null
          ? null
          : allGroups.firstWhereOrNull((g) => g.id == groupId)?.name;
      final bytes = await _exportSvc.buildDebtorsPdf(
        month: selectedMonth.value,
        rows: rows,
        groupLabel: groupName,
      );
      await Printing.layoutPdf(
        name: 'مديونيات_${groupName ?? 'الكل'}',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      ToastHelper.error('خطأ: $e');
    } finally {
      isExporting(false);
    }
  }

  /// تصدير تقرير الدفعات PDF
  Future<void> exportPaymentsPDF() async {
    if (isExporting.value) return;
    isExporting(true);
    ToastHelper.info('جاري إنشاء تقرير الدفعات...');
    try {
      final result = await _exportSvc.exportPaymentsPDF(
        month: selectedMonth.value,
        students: allStudents,
        payments: allPayments,
        groups: allGroups,
        attendance: allAttendance,
      );
      if (result.success && result.path != null) {
        ToastHelper.success('تم إنشاء التقرير بنجاح');
        await _exportSvc.sharePDF(result.path!);
      } else {
        ToastHelper.error(result.error ?? 'فشل إنشاء التقرير');
      }
    } catch (e) {
      ToastHelper.error('خطأ: $e');
    } finally {
      isExporting(false);
    }
  }

  /// تصدير تقرير الحضور PDF — لو `from`/`to` اتمرّروا يبقى تقرير فترة
  /// مخصصة [from, to] بدل الشهر المختار (spec 014).
  Future<void> exportAttendancePDF({DateTime? from, DateTime? to}) async {
    if (isExporting.value) return;
    isExporting(true);
    ToastHelper.info('جاري إنشاء تقرير الحضور...');
    try {
      final isRange = from != null && to != null;
      // الخدمة بتفلتر بالتاريخ داخليًا — بنبعت القايمة كاملة.
      final result = await _exportSvc.exportAttendancePDF(
        month: isRange
            ? DateTime(from.year, from.month, from.day)
            : selectedMonth.value,
        periodEnd: isRange ? DateTime(to.year, to.month, to.day) : null,
        students: allStudents,
        attendance: allAttendance,
        groups: allGroups,
        homework: allHomework,
      );
      if (result.success && result.path != null) {
        ToastHelper.success('تم إنشاء التقرير بنجاح');
        await _exportSvc.sharePDF(result.path!);
      } else {
        ToastHelper.error(result.error ?? 'فشل إنشاء التقرير');
      }
    } catch (e) {
      ToastHelper.error('خطأ: $e');
    } finally {
      isExporting(false);
    }
  }

  /// تصدير تقرير الواجب PDF — يدعم فترة مخصصة (spec 014).
  Future<void> exportHomeworkPDF({DateTime? from, DateTime? to}) async {
    if (isExporting.value) return;
    isExporting(true);
    ToastHelper.info('جاري إنشاء تقرير الواجب...');
    try {
      final isRange = from != null && to != null;
      final result = await _exportSvc.exportHomeworkPDF(
        month: isRange
            ? DateTime(from.year, from.month, from.day)
            : selectedMonth.value,
        periodEnd: isRange ? DateTime(to.year, to.month, to.day) : null,
        students: allStudents,
        homework: allHomework,
        groups: allGroups,
        attendance: allAttendance,
      );
      if (result.success && result.path != null) {
        ToastHelper.success('تم إنشاء التقرير بنجاح');
        await _exportSvc.sharePDF(result.path!);
      } else {
        ToastHelper.error(result.error ?? 'فشل إنشاء التقرير');
      }
    } catch (e) {
      ToastHelper.error('خطأ: $e');
    } finally {
      isExporting(false);
    }
  }

  /// تصدير ملخص المجموعات PDF
  Future<void> exportGroupsSummaryPDF() async {
    if (isExporting.value) return;
    isExporting(true);
    ToastHelper.info('جاري إنشاء ملخص المجموعات...');
    try {
      final result = await _exportSvc.exportGroupsSummaryPDF(
        month: selectedMonth.value,
        students: allStudents,
        payments: allPayments,
        attendance: allAttendance,
        groups: allGroups,
        homework: allHomework,
      );
      if (result.success && result.path != null) {
        ToastHelper.success('تم إنشاء التقرير بنجاح');
        await _exportSvc.sharePDF(result.path!);
      } else {
        ToastHelper.error(result.error ?? 'فشل إنشاء التقرير');
      }
    } catch (e) {
      ToastHelper.error('خطأ: $e');
    } finally {
      isExporting(false);
    }
  }

  /// للتوافق مع الكود القديم
  Future<void> exportPDF() => exportPaymentsPDF();

  // Keep old observables for backward compatibility
  RxInt get totalAttendance => RxInt(allAttendance.length);
  RxDouble get attendancePercentage => RxDouble(0.0);
  RxDouble get totalPayments =>
      RxDouble(allPayments
          .where((p) => p.isCollection)
          .fold(0.0, (s, p) => s + p.amount));
  RxInt get paymentCount => RxInt(allPayments.length);
  RxInt get totalStudents => RxInt(allStudents.length);
  RxInt get totalGroups => RxInt(allGroups.length);
  RxList<Payment> get recentPayments => RxList(allPayments.take(10).toList());
  RxList<Attendance> get recentAttendance =>
      RxList(allAttendance.take(10).toList());
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class GroupMonthSummary {
  final Group group;
  final int studentCount;
  final double expectedIncome;
  final double collectedIncome;
  final int fullyPaidCount;

  /// طلاب عليهم مستحق فعلًا في الشهر ده (من غير المعفيين ولا اللي لسه ما
  /// انضموش) — مقام «مدفوع بالكامل X / Y» (studentCount بيعدّ كل طلاب المجموعة).
  final int dueStudentCount;
  final int totalPresentSessions; // شامل "متأخر"
  final int totalLateSessions; // منها كام "متأخر" (spec 011)
  final int totalHomeworkDone;
  final int totalHomeworkNotDone;

  GroupMonthSummary({
    required this.group,
    required this.studentCount,
    required this.expectedIncome,
    required this.collectedIncome,
    required this.fullyPaidCount,
    required this.dueStudentCount,
    required this.totalPresentSessions,
    this.totalLateSessions = 0,
    this.totalHomeworkDone = 0,
    this.totalHomeworkNotDone = 0,
  });

  double get collectionRate =>
      expectedIncome == 0 ? 1.0 : collectedIncome / expectedIncome;
}

class SessionDay {
  final DateTime date;
  final int presentCount;
  final double expectedAmount;
  const SessionDay({
    required this.date,
    required this.presentCount,
    required this.expectedAmount,
  });
}

class AtRiskStudent {
  final Student student;
  final Group? group;
  final double paid;
  final double due;
  final DateTime month;

  /// مستحق الشهر المختار لوحده (null لو مش معروف). لو المتبقي أكبر منه يبقى
  /// على الطالب مديونية من شهور أقدم — بنستخدمه في صياغة رسالة التذكير.
  final double? monthDue;

  AtRiskStudent({
    required this.student,
    required this.group,
    required this.paid,
    required this.due,
    required this.month,
    this.monthDue,
  });

  /// هل المتبقي يتخطى مستحق الشهر ده (يعني فيه شهور أقدم)؟
  bool get includesOlderMonths =>
      monthDue != null && remaining > monthDue! + 0.005;

  double get remaining => due - paid;
}

class _ReportSnapshot {
  final List<GroupMonthSummary> groups;
  final List<AtRiskStudent> unpaid;
  final double expected;
  final double collected;
  final double remaining;

  /// فلوس طلاب مؤرشفين اتحسبت في المتوقع والمحصّل (بس اللي دفعوه).
  final double archivedPaid;
  const _ReportSnapshot({
    required this.groups,
    required this.unpaid,
    required this.expected,
    required this.collected,
    required this.remaining,
    this.archivedPaid = 0,
  });
}

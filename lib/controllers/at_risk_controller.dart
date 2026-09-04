// lib/controllers/at_risk_controller.dart
//
// spec 021 — يحمّل البيانات ويستدعي AtRiskService.computeAtRiskStudents،
// ويدير حالة الإقرار/التأجيل والفلترة للشاشة + كارت لوحة التحكم.
import 'package:get/get.dart';

import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/at_risk_model.dart';
import 'package:active_class/models/student_follow_up_model.dart';
import 'package:active_class/services/at_risk_service.dart';
import 'package:active_class/services/database_service.dart';

class AtRiskController extends GetxController {
  final DatabaseService _db = DatabaseService();

  /// بعد استبعاد المؤجَّلين وقبل تطبيق فلاتر الشاشة — المصدر للعدّاد.
  List<AtRiskStudent> _allActive = [];

  final RxList<AtRiskStudent> items = <AtRiskStudent>[].obs;
  final RxList<AtRiskStudent> snoozed = <AtRiskStudent>[].obs;
  /// آخر واقعة متابعة لكل طالب مؤجَّل — لعرض تاريخ الإقرار/الملاحظة في
  /// تبويب "تمّت متابعتهم".
  final RxMap<int, StudentFollowUp> snoozedFollowUps =
      <int, StudentFollowUp>{}.obs;
  final RxInt count = 0.obs;
  final RxBool isLoading = false.obs;

  final Rxn<RiskSignalType> reasonFilter = Rxn<RiskSignalType>();
  final RxnInt groupFilter = RxnInt();

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  AtRiskSettings _buildSettings() {
    final s = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : Get.put(SettingsController());
    return AtRiskSettings(
      absenceEnabled: s.atRiskAbsenceEnabled.value,
      absenceThreshold: s.atRiskAbsenceThreshold.value,
      homeworkEnabled: s.atRiskHomeworkEnabled.value,
      homeworkM: s.atRiskHomeworkM.value,
      homeworkW: s.atRiskHomeworkW.value,
      gradeEnabled: s.atRiskGradeEnabled.value,
      gradeDropPoints: s.atRiskGradeDropPoints.value,
      paymentEnabled: s.atRiskPaymentEnabled.value,
      paymentGraceDays: s.paymentGraceDays.value,
      cooldownDays: s.atRiskCooldownDays.value,
    );
  }

  @override
  Future<void> refresh() async {
    isLoading(true);
    try {
      final settings = _buildSettings();
      final students = await _db.getAllStudents();
      final groups = await _db.getAllGroups();
      final attendance = await _db.getAllAttendance();
      final homework = await _db.getAllHomework();
      final examGrades = await _db.getAllExamGradesWithExamInfo();
      final payments = await _db.getAllPayments();
      final followUps =
          await _db.getRecentFollowUps(sinceDays: settings.cooldownDays);

      _allActive = computeAtRiskStudents(
        students: students,
        groups: groups,
        attendance: attendance,
        homework: homework,
        examGrades: examGrades,
        payments: payments,
        recentFollowUps: followUps,
        settings: settings,
      );

      // "تمّت متابعتهم" = كل واحد كان هيظهر لولا التهدئة (لسه عنده
      // إشارة فعلية) وموجود بالفعل في _allActive بدونها.
      final withoutCooldown = computeAtRiskStudents(
        students: students,
        groups: groups,
        attendance: attendance,
        homework: homework,
        examGrades: examGrades,
        payments: payments,
        recentFollowUps: const [],
        settings: settings,
      );
      final activeIds = _allActive.map((e) => e.student.id).toSet();
      snoozed.assignAll(
        withoutCooldown.where((e) => !activeIds.contains(e.student.id)),
      );

      final latestByStudent = <int, StudentFollowUp>{};
      for (final f in followUps) {
        final existing = latestByStudent[f.studentId];
        if (existing == null || f.acknowledgedAt.isAfter(existing.acknowledgedAt)) {
          latestByStudent[f.studentId] = f;
        }
      }
      snoozedFollowUps.assignAll(latestByStudent);

      _applyFilters();
    } finally {
      isLoading(false);
    }
  }

  void _applyFilters() {
    var filtered = _allActive;
    final reason = reasonFilter.value;
    if (reason != null) {
      filtered =
          filtered.where((e) => e.signals.any((s) => s.type == reason)).toList();
    }
    final gid = groupFilter.value;
    if (gid != null) {
      filtered = filtered.where((e) => e.student.groupId == gid).toList();
    }
    items.assignAll(filtered);
    count.value = _allActive.length;
  }

  /// المجموعات اللي فيها طالب واحد على الأقل محتاج متابعة (بغضّ النظر
  /// عن فلتر السبب الحالي) — لبناء قائمة فلتر المجموعة في الشاشة.
  List<({int id, String name})> get groupsWithAtRiskStudents {
    final seen = <int, String>{};
    for (final e in _allActive) {
      final g = e.group;
      if (g?.id != null) seen[g!.id!] = g.name;
    }
    return [
      for (final entry in seen.entries) (id: entry.key, name: entry.value)
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  void setReasonFilter(RiskSignalType? type) {
    reasonFilter.value = type;
    _applyFilters();
  }

  void setGroupFilter(int? groupId) {
    groupFilter.value = groupId;
    _applyFilters();
  }

  /// يقرّ "تمّت المتابعة" لطالب — بيسجّل الأسباب الحالية بتاعته وقت
  /// الضغطة، فيختفي من القائمة الرئيسية لحد ما التهدئة تخلص أو يظهر
  /// سبب من نوع جديد (FR-014).
  Future<void> acknowledge(int studentId, {String? note}) async {
    final entry =
        _allActive.firstWhereOrNull((e) => e.student.id == studentId);
    final types =
        (entry?.signals ?? const []).map((s) => s.type.storageKey).toList();
    await _db.insertFollowUpAcknowledgement(StudentFollowUp(
      studentId: studentId,
      reasonTypes: types,
      acknowledgedAt: DateTime.now(),
      note: note,
    ));
    await refresh();
  }

  /// يرجّع طالب مؤجَّل للقائمة الرئيسية يدويًا (بيحذف آخر إقرار نشط له).
  Future<void> unacknowledge(int studentId) async {
    final f = await _db.getLatestFollowUpForStudent(studentId);
    if (f?.id != null) {
      await _db.deleteFollowUp(f!.id!);
    }
    await refresh();
  }
}

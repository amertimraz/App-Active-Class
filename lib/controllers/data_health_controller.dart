// lib/controllers/data_health_controller.dart
//
// spec 052 — حالة شاشة "صحة البيانات": فحص ← اختيار ← معاينة ← تنفيذ.
import 'package:get/get.dart';

import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/services/data_health_service.dart';
import 'package:active_class/utils/duplicate_detection.dart';
import 'package:active_class/utils/merge_plan.dart';

class DataHealthController extends GetxController {
  final DataHealthService _svc = DataHealthService();

  final RxBool scanning = false.obs;
  final RxBool working = false.obs;
  final Rxn<ScanResult> result = Rxn<ScanResult>();
  final RxList<DuplicateCase> groupCases = <DuplicateCase>[].obs;
  final RxList<DuplicateCase> studentCases = <DuplicateCase>[].obs;
  final RxSet<String> selected = <String>{}.obs;
  final RxList<MergeLogEntry> history = <MergeLogEntry>[].obs;
  final RxnString error = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  static String keyOf(DuplicateCase c) {
    final ids = c.copies.map((x) => x.id).toList()..sort();
    return '${c.kind.name}:${ids.join(',')}';
  }

  Future<void> loadHistory() async {
    history.assignAll(await _svc.history());
  }

  Future<void> scan() async {
    scanning.value = true;
    error.value = null;
    try {
      final r = await _svc.scan();
      result.value = r;
      groupCases.assignAll(r.groupCases);
      studentCases.assignAll(r.studentCases);
      selected
        ..clear()
        ..addAll([
          for (final c in [...r.groupCases, ...r.studentCases])
            if (c.selectedByDefault) keyOf(c)
        ]);
    } catch (e) {
      error.value = '$e';
    } finally {
      scanning.value = false;
    }
  }

  bool isSelected(DuplicateCase c) => selected.contains(keyOf(c));

  void toggle(DuplicateCase c) {
    final k = keyOf(c);
    if (!selected.remove(k)) selected.add(k);
  }

  /// تغيير الأساسي لحالة (اختيار المدرس).
  void setCanonical(DuplicateCase c, int copyId) {
    final list = c.kind == DuplicateKind.group ? groupCases : studentCases;
    final i = list.indexWhere((x) => keyOf(x) == keyOf(c));
    if (i < 0) return;
    list[i] = c.withCanonical(copyId);
  }

  List<DuplicateCase> get _selectedGroups =>
      groupCases.where(isSelected).toList();
  List<DuplicateCase> get _selectedStudents =>
      studentCases.where(isSelected).toList();

  int get selectedCount => _selectedGroups.length + _selectedStudents.length;

  Future<MergePlan> buildPreview() => _svc.buildPlan(
        groupCases: _selectedGroups,
        studentCases: _selectedStudents,
      );

  Future<MergeBlocked?> preflight(MergePlan plan,
          {bool ignorePending = false}) =>
      _svc.preflight(plan, ignorePending: ignorePending);

  /// أسماء مختصرة للمدموج (للتقرير).
  List<String> _labels() => [
        for (final c in [..._selectedGroups, ..._selectedStudents])
          () {
            final canon = c.copies.firstWhere((x) => x.id == c.canonicalId);
            final dups = c.copies
                .where((x) => x.id != c.canonicalId)
                .map((x) => x.code.isEmpty ? x.name : '${x.name} (${x.code})')
                .join('، ');
            return '${canon.name} ← $dups';
          }()
      ];

  Future<MergeOutcome> execute(MergePlan plan,
      {bool ignorePending = false}) async {
    working.value = true;
    try {
      final out = await _svc.execute(plan,
          ignorePending: ignorePending, itemLabels: _labels());
      if (out is MergeSuccess) {
        await _reloadControllers();
        await loadHistory();
        await scan(); // حدّث الحالات بعد الدمج
      }
      return out;
    } finally {
      working.value = false;
    }
  }

  Future<void> _reloadControllers() async {
    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
      } catch (_) {}
    }

    if (Get.isRegistered<GroupController>()) {
      await run(() => Get.find<GroupController>().loadGroups());
    }
    if (Get.isRegistered<StudentController>()) {
      await run(() => Get.find<StudentController>().loadAllStudents());
    }
    if (Get.isRegistered<AttendanceController>()) {
      await run(() => Get.find<AttendanceController>().loadAttendance());
    }
    if (Get.isRegistered<PaymentController>()) {
      await run(() => Get.find<PaymentController>().loadPayments());
    }
    if (Get.isRegistered<HomeworkController>()) {
      await run(() => Get.find<HomeworkController>().loadHomework());
    }
    if (Get.isRegistered<ExamController>()) {
      await run(() => Get.find<ExamController>().loadExams());
    }
    if (Get.isRegistered<DashboardController>()) {
      await run(() => Get.find<DashboardController>().loadDashboardData());
    }
  }
}

// lib/controllers/wipe_data_controller.dart
//
// حالة شاشة «حذف جميع البيانات» (حذف مرن بالأقسام): الاختيار، الأقسام
// التابعة، المعاينة، ونسخة احتياطية إجبارية قبل التنفيذ.
import 'package:get/get.dart';

import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/wipe_scope.dart';
import 'package:active_class/services/backup_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';

sealed class WipeOutcome {
  const WipeOutcome();
}

class WipeSuccess extends WipeOutcome {
  const WipeSuccess(this.deleted);
  final Map<WipeScope, int> deleted;
  int get total => deleted.values.fold(0, (s, n) => s + n);
}

class WipeBackupFailed extends WipeOutcome {
  const WipeBackupFailed(this.reason);
  final String? reason;
}

class WipeError extends WipeOutcome {
  const WipeError(this.error);
  final Object error;
}

class WipeDataController extends GetxController {
  /// اللي المدرس اختاره بإيده.
  final RxSet<WipeScope> selected = <WipeScope>{}.obs;

  /// معاينة الأعداد (للأقسام الفعلية بعد إضافة التابعة). null = ما اتعملتش.
  final Rxn<Map<WipeScope, int>> preview = Rxn<Map<WipeScope, int>>();
  final RxBool isRunning = false.obs;
  final RxBool isCounting = false.obs;

  /// الأقسام الفعلية اللي هتتحذف (المختارة + التابعة).
  Set<WipeScope> get effective => wipeClosure(selected);

  /// القسم ده متعلّم لأنه تابع لقسم تاني مختار (مش اختيار مباشر).
  bool isImplied(WipeScope s) =>
      selected.any((o) => o != s && wipeClosure({o}).contains(s));

  int get total => preview.value?.values.fold<int>(0, (a, n) => a + n) ?? 0;

  bool get hasSelection => selected.isNotEmpty;

  /// في وضع الفريق: الحذف ده للمدرس (صاحب الفريق) بس.
  bool get allowed {
    final tm = TeamModeService();
    return !tm.isEnabled.value || tm.isOwner.value;
  }

  bool get canDelete =>
      allowed && hasSelection && !isRunning.value && !isCounting.value;

  void toggle(WipeScope s) {
    // القسم التابع لقسم مختار ما بيتشالش لوحده.
    if (isImplied(s)) return;
    if (selected.contains(s)) {
      selected.remove(s);
    } else {
      selected.add(s);
    }
    _recount();
  }

  void selectAll() {
    selected.assignAll(WipeScope.values);
    _recount();
  }

  void clear() {
    selected.clear();
    _recount();
  }

  Future<void> _recount() async {
    if (selected.isEmpty) {
      preview.value = null;
      return;
    }
    isCounting.value = true;
    try {
      preview.value = await DatabaseService().countWipeScopes(effective);
    } finally {
      isCounting.value = false;
    }
  }

  Future<WipeOutcome> run() async {
    if (!canDelete) return const WipeError('لا يوجد ما يُحذف');
    isRunning.value = true;
    try {
      final backup = await BackupService().createBackup();
      if (!backup.success) return WipeBackupFailed(backup.error);

      final deleted = await DatabaseService().wipeScopes(effective);
      await _reloadControllers();
      selected.clear();
      preview.value = null;
      return WipeSuccess(deleted);
    } catch (e) {
      return WipeError(e);
    } finally {
      isRunning.value = false;
    }
  }

  Future<void> _reloadControllers() async {
    Future<void> tryReload(bool registered, Future<void> Function() fn) async {
      if (!registered) return;
      try {
        await fn();
      } catch (_) {}
    }

    await tryReload(Get.isRegistered<GroupController>(),
        () => Get.find<GroupController>().loadGroups());
    await tryReload(Get.isRegistered<StudentController>(),
        () => Get.find<StudentController>().loadAllStudents());
    await tryReload(Get.isRegistered<ExamController>(),
        () => Get.find<ExamController>().loadExams());
    await tryReload(Get.isRegistered<AttendanceController>(),
        () => Get.find<AttendanceController>().loadAttendance());
    await tryReload(Get.isRegistered<PaymentController>(),
        () => Get.find<PaymentController>().loadPayments());
    await tryReload(Get.isRegistered<HomeworkController>(),
        () => Get.find<HomeworkController>().loadHomework());
    await tryReload(Get.isRegistered<DashboardController>(),
        () async => Get.find<DashboardController>().refresh());
  }
}

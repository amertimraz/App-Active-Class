// lib/controllers/delete_records_controller.dart
//
// حالة شاشة "حذف سجلّات بمدى تواريخ" (spec 028): المدى، الأنواع
// المختارة، المعاينة، وتنفيذ الحذف مع نسخة احتياطية إجبارية.
import 'package:get/get.dart';

import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/models/deletable_record_type.dart';
import 'package:active_class/services/backup_service.dart';
import 'package:active_class/services/database_service.dart';

/// نتيجة محاولة الحذف.
sealed class DeleteOutcome {
  const DeleteOutcome();
}

class DeleteSuccess extends DeleteOutcome {
  const DeleteSuccess(this.deleted);
  final Map<DeletableRecordType, int> deleted;
  int get total => deleted.values.fold(0, (s, n) => s + n);
}

class DeleteBackupFailed extends DeleteOutcome {
  const DeleteBackupFailed(this.reason);
  final String? reason;
}

class DeleteError extends DeleteOutcome {
  const DeleteError(this.error);
  final Object error;
}

class DeleteRecordsController extends GetxController {
  final Rxn<DateTime> fromDate = Rxn<DateTime>();
  final Rxn<DateTime> toDate = Rxn<DateTime>();
  final RxSet<DeletableRecordType> selectedTypes = <DeletableRecordType>{}.obs;
  final Rxn<Map<DeletableRecordType, int>> preview =
      Rxn<Map<DeletableRecordType, int>>();
  final RxBool isRunning = false.obs;

  // ── مشتقّات ──────────────────────────────────────────────────────
  bool get rangeValid {
    final f = fromDate.value, t = toDate.value;
    return f != null && t != null && !f.isAfter(t);
  }

  int get previewTotal =>
      preview.value?.values.fold<int>(0, (s, n) => s + n) ?? 0;

  bool get needsTypeConfirm => previewTotal > kBulkDeleteThreshold;
  bool get canPreview => rangeValid && selectedTypes.isNotEmpty;
  bool get canDelete =>
      preview.value != null && previewTotal > 0 && !isRunning.value;

  // ── إجراءات ──────────────────────────────────────────────────────
  void setFrom(DateTime d) {
    fromDate.value = DateTime(d.year, d.month, d.day);
    preview.value = null;
  }

  void setTo(DateTime d) {
    toDate.value = DateTime(d.year, d.month, d.day);
    preview.value = null;
  }

  void toggleType(DeletableRecordType t) {
    if (selectedTypes.contains(t)) {
      selectedTypes.remove(t);
    } else {
      selectedTypes.add(t);
    }
    preview.value = null;
  }

  Future<void> runPreview() async {
    if (!canPreview) return;
    preview.value = await DatabaseService().countDeletableRecordsInRange(
      from: fromDate.value!,
      to: toDate.value!,
      types: selectedTypes.toSet(),
    );
  }

  Future<DeleteOutcome> runDelete() async {
    if (!canDelete) return const DeleteError('لا يوجد ما يُحذف');
    isRunning.value = true;
    try {
      final backup = await BackupService().createBackup();
      if (!backup.success) {
        return DeleteBackupFailed(backup.error);
      }

      final deleted = await DatabaseService().deleteRecordsInRange(
        from: fromDate.value!,
        to: toDate.value!,
        types: selectedTypes.toSet(),
      );

      _refreshOpenControllers();

      preview.value = null;
      selectedTypes.clear();
      return DeleteSuccess(deleted);
    } catch (e) {
      return DeleteError(e);
    } finally {
      isRunning.value = false;
    }
  }

  void _refreshOpenControllers() {
    if (Get.isRegistered<AttendanceController>()) {
      Get.find<AttendanceController>().loadAttendance();
    }
    if (Get.isRegistered<PaymentController>()) {
      Get.find<PaymentController>().loadPayments();
    }
    if (Get.isRegistered<ExamController>()) {
      Get.find<ExamController>().loadExams();
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().loadDashboardData();
    }
  }
}

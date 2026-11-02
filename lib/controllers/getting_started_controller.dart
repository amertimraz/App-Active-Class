// lib/controllers/getting_started_controller.dart
//
// حالة قايمة "ابدأ من هنا": أعداد البيانات من القاعدة (استعلام COUNT خفيف)
// وإعداد "إخفاء القايمة" المحلي.
import 'package:get/get.dart';

import 'package:active_class/help/getting_started.dart';
import 'package:active_class/services/database_service.dart';

const kGettingStartedDismissedKey = 'getting_started_dismissed';

class GettingStartedController extends GetxController {
  final RxBool loaded = false.obs;
  final RxBool dismissed = false.obs;
  final RxList<GettingStartedStep> steps = <GettingStartedStep>[].obs;

  /// تظهر لو اتحمّلت، ما اتخفتش، ولسه فيه خطوة ما اتعملتش.
  bool get visible =>
      loaded.value &&
      !dismissed.value &&
      gettingStartedNext(steps) != null;

  @override
  void onInit() {
    super.onInit();
    refreshState();
  }

  Future<void> refreshState() async {
    try {
      final db = DatabaseService();
      dismissed.value = (await db.getSetting(kGettingStartedDismissedKey)) == '1';
      if (dismissed.value) {
        loaded.value = true;
        return;
      }
      final s = await db.getDataSummary();
      steps.assignAll(gettingStartedSteps(
        groups: s.groups,
        students: s.students,
        attendanceRecords: s.attendanceRecords,
        payments: s.payments,
      ));
    } catch (_) {
      // لو القاعدة مش جاهزة مانعرضش القايمة بدل ما نعرض غلط.
      steps.clear();
    } finally {
      loaded.value = true;
    }
  }

  Future<void> dismiss() async {
    dismissed.value = true;
    try {
      await DatabaseService().setSetting(kGettingStartedDismissedKey, '1');
    } catch (_) {}
  }
}

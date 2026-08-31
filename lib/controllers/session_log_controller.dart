// lib/controllers/session_log_controller.dart
import 'package:get/get.dart';

class SessionEntry {
  final String studentName;
  final double amount;
  // عدد الشهور المدفوعة، أو عدد الحصص لو isPerSession — نفس الحقل
  // بمعنيين مختلفين حسب نوع تسعير مجموعة الطالب وقت الدفع.
  final int monthCount;
  final bool isPerSession;
  final DateTime time;
  final String? guardianPhone;

  SessionEntry({
    required this.studentName,
    required this.amount,
    required this.monthCount,
    this.isPerSession = false,
    required this.time,
    this.guardianPhone,
  });
}

/// سجل جلسة الدفع — يبقى حياً طوال اليوم الحالي.
/// عند أول إضافة في يوم جديد يُصفَّر تلقائياً.
class SessionLogController extends GetxController {
  static SessionLogController get to => Get.find();

  final RxList<SessionEntry> entries = <SessionEntry>[].obs;

  // تاريخ آخر دفعة مسجَّلة (لمعرفة إذا تغيّر اليوم)
  DateTime? _lastEntryDate;

  double get total => entries.fold(0, (s, e) => s + e.amount);
  int get count => entries.length;

  bool _hydratedThisRun = false;

  /// يملأ السجل مرة واحدة كل تشغيل من دفعات النهاردة الفعلية في القاعدة —
  /// عشان عدّاد "دفعوا اليوم" ما يرجعش صفر بعد قفل وفتح التطبيق. لو
  /// المدرس سجّل دفعات في نفس الجلسة بالفعل، مبنعملش حاجة.
  void hydrateOnce(List<SessionEntry> todayEntries) {
    if (_hydratedThisRun) return;
    _hydratedThisRun = true;
    if (entries.isNotEmpty) return;
    entries.assignAll(todayEntries);
    if (todayEntries.isNotEmpty) _lastEntryDate = DateTime.now();
  }

  void add(SessionEntry entry) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // لو اليوم تغيّر منذ آخر دفعة → صفّر السجل
    if (_lastEntryDate != null) {
      final lastDay = DateTime(
          _lastEntryDate!.year, _lastEntryDate!.month, _lastEntryDate!.day);
      if (lastDay.isBefore(today)) {
        entries.clear();
      }
    }

    entries.insert(0, entry);
    _lastEntryDate = now;
  }

  void clear() {
    entries.clear();
    _lastEntryDate = null;
  }
}

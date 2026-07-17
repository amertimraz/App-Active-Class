// lib/controllers/session_log_controller.dart
import 'package:get/get.dart';

class SessionEntry {
  final String studentName;
  final double amount;
  final int monthCount;
  final DateTime time;
  final String? guardianPhone;

  SessionEntry({
    required this.studentName,
    required this.amount,
    required this.monthCount,
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

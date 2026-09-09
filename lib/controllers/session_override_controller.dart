// lib/controllers/session_override_controller.dart
//
// spec 032 — حالة استثناءات الحصص (إلغاء / تعويض / إضافية) + CRUD +
// قواعد التحقّق. متزامن عبر الفريق (SyncEngine._refreshUiForTable بينادي
// load عند وصول تغيير). دوال الجدولة في AttendanceController بتقرا
// overrideFor(...) عشان تبقى override-aware.
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/session_override_model.dart';
import 'package:active_class/services/database_service.dart';

class SessionOverrideController extends GetxController {
  final DatabaseService _db = DatabaseService();

  final RxList<SessionOverride> overrides = <SessionOverride>[].obs;
  final RxBool loadedOnce = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await _db.getAllSessionOverrides();
      overrides.assignAll(rows);
    } catch (e) {
      debugPrint('SessionOverrideController.load فشل: $e');
    } finally {
      loadedOnce.value = true;
    }
  }

  static String _ymd(DateTime d) => SessionOverride.ymd(d);

  /// استثناء (المجموعة، اليوم) لو موجود.
  SessionOverride? overrideFor(int groupId, DateTime day) {
    final key = _ymd(day);
    for (final o in overrides.toList()) {
      if (o.groupId == groupId && _ymd(o.date) == key) return o;
    }
    return null;
  }

  List<SessionOverride> overridesForGroupInRange(
      int groupId, DateTime from, DateTime to) {
    final f = _ymd(from);
    final t = _ymd(to);
    return overrides
        .toList()
        .where((o) =>
            o.groupId == groupId && _ymd(o.date).compareTo(f) >= 0 &&
            _ymd(o.date).compareTo(t) <= 0)
        .toList();
  }

  List<SessionOverride> cancelledForGroup(int groupId) => overrides
      .toList()
      .where((o) =>
          o.groupId == groupId && o.type == SessionOverrideType.cancelled)
      .toList();

  /// حصص ملغاة للمجموعة **لسه مالهاش تعويض** — دي اللي المدرّس يقدر
  /// يختارها كـ"بتعوّض عن يوم" عند إضافة حصة تعويضية.
  List<SessionOverride> uncompensatedCancelledForGroup(int groupId) {
    final all = overrides.toList();
    final compensatedDays = all
        .where((o) =>
            o.groupId == groupId &&
            o.type == SessionOverrideType.makeup &&
            o.compensatesDate != null)
        .map((o) => _ymd(o.compensatesDate!))
        .toSet();
    return all
        .where((o) =>
            o.groupId == groupId &&
            o.type == SessionOverrideType.cancelled &&
            !compensatedDays.contains(_ymd(o.date)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// ألغِ حصة اليوم. لازم [scheduleHasSession] = true (الجدول يقول فيه
  /// حصة) — وإلا الإلغاء بلا معنى. مسح صفوف الحضور مسؤولية الشاشة (حوار
  /// "هيتمسح N") قبل استدعاء الدالة دي.
  /// يرجع null عند النجاح، أو رسالة خطأ للعرض.
  Future<String?> cancelToday({
    required Group group,
    required DateTime day,
    required bool scheduleHasSession,
    String? note,
  }) async {
    if (group.id == null) return 'المجموعة غير محفوظة';
    if (!scheduleHasSession) return 'مفيش حصة مجدولة النهارده للمجموعة دي';
    if (overrideFor(group.id!, day) != null) {
      return 'فيه استثناء بالفعل لليوم ده';
    }
    await _db.insertSessionOverride(SessionOverride(
      groupId: group.id!,
      date: DateTime(day.year, day.month, day.day),
      type: SessionOverrideType.cancelled,
      note: note,
    ));
    await load();
    return null;
  }

  /// حصة تعويضية عن يوم [compensatesDate] اتلغى قبل كده.
  Future<String?> addMakeup({
    required Group group,
    required DateTime day,
    required DateTime compensatesDate,
    String? note,
    String? sessionTime,
  }) async {
    if (group.id == null) return 'المجموعة غير محفوظة';
    final existing = overrideFor(group.id!, day);
    if (existing != null) {
      return existing.type == SessionOverrideType.cancelled
          ? 'اليوم ده متلغّي — احذف الإلغاء الأول'
          : 'فيه استثناء بالفعل لليوم ده';
    }
    // التعويضية لازم تكون عن حصة ملغاة فعليًا لنفس المجموعة.
    final cKey = _ymd(compensatesDate);
    final hasCancel = cancelledForGroup(group.id!)
        .any((o) => _ymd(o.date) == cKey);
    if (!hasCancel) {
      return 'اليوم اللي بتعوّض عنه مش ملغي — الغِ الحصة الأول أو اختار «إضافية»';
    }
    await _db.insertSessionOverride(SessionOverride(
      groupId: group.id!,
      date: DateTime(day.year, day.month, day.day),
      type: SessionOverrideType.makeup,
      compensatesDate: DateTime(
          compensatesDate.year, compensatesDate.month, compensatesDate.day),
      note: note,
      sessionTime: sessionTime,
    ));
    await load();
    return null;
  }

  /// حصة إضافية (مش تعويض عن يوم معيّن).
  Future<String?> addExtra({
    required Group group,
    required DateTime day,
    String? note,
    String? sessionTime,
  }) async {
    if (group.id == null) return 'المجموعة غير محفوظة';
    final existing = overrideFor(group.id!, day);
    if (existing != null) {
      return existing.type == SessionOverrideType.cancelled
          ? 'اليوم ده متلغّي — احذف الإلغاء الأول'
          : 'فيه استثناء بالفعل لليوم ده';
    }
    await _db.insertSessionOverride(SessionOverride(
      groupId: group.id!,
      date: DateTime(day.year, day.month, day.day),
      type: SessionOverrideType.extra,
      note: note,
      sessionTime: sessionTime,
    ));
    await load();
    return null;
  }

  /// احذف استثناء. لو الاستثناء `cancelled` وله `makeup` قائم لنفس
  /// المجموعة → يُرفض (احذف التعويض الأول).
  Future<String?> removeOverride(SessionOverride o) async {
    if (o.id == null) return 'استثناء غير محفوظ';
    if (o.type == SessionOverrideType.cancelled) {
      final hasMakeup = overrides.toList().any((m) =>
          m.groupId == o.groupId &&
          m.type == SessionOverrideType.makeup &&
          m.compensatesDate != null &&
          _ymd(m.compensatesDate!) == _ymd(o.date));
      if (hasMakeup) return 'فيه حصة تعويضية مرتبطة — احذفها الأول';
    }
    await _db.deleteSessionOverride(o.id!);
    await load();
    return null;
  }
}

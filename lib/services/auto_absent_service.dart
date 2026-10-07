// lib/services/auto_absent_service.dart
//
// spec 046 — الغياب التلقائي بعد انتهاء الحصة. بيفحص كل دقيقة (وعند
// الفتح/الاستئناف) حصص آخر 3 أيام اللي قفلت (نهاية + مهلة) ويسجّل "غائب"
// للطلاب النشطين اللي مالهمش أي سجل حضور في اليوم. كل حصة (مجموعة+تاريخ)
// بتتعالج مرة واحدة بس. مفيش رسايل واتساب ولا تغيير في الـDB.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/session_override_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/utils/auto_absent.dart';

class AutoAbsentService {
  AutoAbsentService._();
  static final AutoAbsentService instance = AutoAbsentService._();

  Timer? _timer;
  bool _running = false;

  /// يبدأ الفحص الدوري (كل دقيقة) + فحص فوري. آمن لو اتنادى أكتر من مرة.
  void start() {
    _timer ??=
        Timer.periodic(const Duration(minutes: 1), (_) => unawaited(runOnce()));
    unawaited(runOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// يرجّع عدد سجلات الغياب اللي اتضافت. idempotent، وبيرجع 0 بصمت لو
  /// الإعداد مطفي أو الـcontrollers مش جاهزة أو فيه فحص شغّال بالفعل.
  Future<int> runOnce({DateTime? now}) async {
    if (_running) return 0;
    if (!Get.isRegistered<SettingsController>() ||
        !Get.isRegistered<SessionOverrideController>()) {
      return 0;
    }
    final settings = Get.find<SettingsController>();
    if (!settings.autoAbsentEnabled.value) return 0;

    _running = true;
    try {
      final clock = now ?? DateTime.now();
      final enabledAt = await settings.autoAbsentEnabledAt();
      if (enabledAt == null) return 0;
      final grace = settings.autoAbsentGraceMinutes.value;

      final att = Get.isRegistered<AttendanceController>()
          ? Get.find<AttendanceController>()
          : Get.put(AttendanceController());
      final db = DatabaseService();

      var processed = pruneProcessed(await settings.loadAutoAbsentProcessed(), clock);
      final before = processed.length;

      // أولًا: الحصص المرشّحة بس من الجدول (قراءة المجموعات خفيفة)، قبل ما
      // نقرأ الطلاب والحضور — الفحص كل دقيقة فلازم يكون رخيص في الغالب.
      final groups = await db.getAllGroups();
      final soCtrl = Get.find<SessionOverrideController>();

      List<({Group group, DateTime day, DateTime end, String key})>
          findCandidates() {
        final out = <({Group group, DateTime day, DateTime end, String key})>[];
        for (final day in lookbackDays(clock)) {
          for (final g in groups) {
            if (g.id == null) continue;
            final key = autoAbsentKey(g.id!, day);
            if (processed.contains(key)) continue;
            if (!att.groupHasSessionOnDay(g, day)) continue;
            final end =
                sessionEndFor(day, att.sessionTimeForGroupOnDay(g, day));
            if (end == null) continue;
            if (!sessionEligible(
              end: end,
              now: clock,
              graceMinutes: grace,
              enabledAt: enabledAt,
              key: key,
              processed: processed,
            )) {
              continue;
            }
            out.add((group: g, day: day, end: end, key: key));
          }
        }
        return out;
      }

      var candidates = findCandidates();
      if (candidates.isNotEmpty) {
        // الاستثناءات (إلغاء/تعويض) لازم تكون محدّثة قبل ما نحكم إن الحصة
        // موجودة — غلطة هنا = غياب وهمي على حصة ملغاة. بنحمّلها بس لما فيه
        // حصة فعلًا هتتسجّل (مش كل دقيقة، عشان ما نعيدش رسم الشاشات).
        await soCtrl.load();
        candidates = findCandidates();
      }

      var added = 0;
      final touched = <int>{};
      if (candidates.isNotEmpty) {
        final students = await db.getAllStudents();
        final windowStart = lookbackDays(clock).first;
        final raw = await (await db.database).query(
          TABLE_ATTENDANCE,
          columns: [COL_ATTENDANCE_STUDENT_ID, COL_ATTENDANCE_DATE],
          where: '$COL_ATTENDANCE_DATE >= ?',
          whereArgs: [windowStart.toIso8601String()],
        );
        // مفتاح "studentId|yyyy-MM-dd" لكل سجل حضور في النافذة
        final recorded = <String>{
          for (final r in raw)
            '${r[COL_ATTENDANCE_STUDENT_ID]}|'
                '${(r[COL_ATTENDANCE_DATE] as String).substring(0, 10)}'
        };
        for (final c in candidates) {
          final dayStr = autoAbsentKey(0, c.day).substring(2);
          final withRecord = <int>{
            for (final s in students)
              if (s.id != null && recorded.contains('${s.id}|$dayStr')) s.id!
          };
          final targets = studentsToMarkAbsent(
            groupStudents:
                students.where((s) => s.groupId == c.group.id).toList(),
            day: c.day,
            studentIdsWithRecord: withRecord,
          );
          final closeAt = c.end.add(Duration(minutes: grace));
          for (final s in targets) {
            try {
              await db.insertAttendance(Attendance(
                studentId: s.id!,
                // تاريخ اليوم الأصلي للحصة (مش يوم الفحص) بساعة الإغلاق
                date: DateTime(c.day.year, c.day.month, c.day.day,
                    closeAt.hour, closeAt.minute),
                status: ATTENDANCE_ABSENT,
                notes: kAutoAbsentNote,
              ));
              touched.add(s.id!);
              added++;
            } catch (e) {
              // UNIQUE (طالب+يوم): اتسجّل من جهاز/مسار تاني — عادي.
              debugPrint('auto-absent skip ${s.id}: $e');
            }
          }
          processed = {...processed, c.key};
        }
      }

      if (processed.length != before || added > 0) {
        await settings.saveAutoAbsentProcessed(processed);
      }
      if (added > 0) {
        await att.loadAttendance();
        for (final id in touched) {
          unawaited(ParentPortalService().pushStudentSummary(id));
        }
        unawaited(NotificationService().scheduleLatePaymentReminder());
      }
      return added;
    } catch (e) {
      debugPrint('auto-absent failed: $e');
      return 0;
    } finally {
      _running = false;
    }
  }
}

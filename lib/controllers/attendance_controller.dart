// lib/controllers/attendance_controller.dart

import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceController extends GetxController {
  final DatabaseService _dbService = DatabaseService();
  final RxList<Attendance> attendance = <Attendance>[].obs;
  final RxList<Attendance> filteredAttendance = <Attendance>[].obs;
  final RxBool isLoading = false.obs;

  // نطاق التاريخ الحالي للإحصائيات والتصفية
  final Rx<DateTimeRange?> dateRange = Rx<DateTimeRange?>(null);

  // فلاتر إضافية
  final Rx<int?> groupFilter = Rx<int?>(null); // groupId أو null
  final RxString statusFilter = RxString(''); // '' | ATTENDANCE_PRESENT | ATTENDANCE_ABSENT

  // ترتيب
  // name|date
  final RxString sortBy = RxString('date');
  final RxBool sortAsc = RxBool(false);

  // خرائط مساعدة للاسم والمجموعة لكل طالب
  final Map<int, int> _studentGroupMap = {};
  final Map<int, String> _studentNameMap = {};

  // تحميل كل السجلات
  Future<void> loadAttendance() async {
    isLoading(true);
    try {
      final loadedAttendance = await _dbService.getAllAttendance();
      attendance.assignAll(loadedAttendance);
      _applyFilter();
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل سجلات الحضور');
    } finally {
      isLoading(false);
    }
  }

  // إضافة حضور مع منع التكرار في اليوم نفسه لنفس الطالب
  Future<void> addAttendance(Attendance att) async {
    try {
      // تحقق محلي سريع لمنع التكرار بنفس اليوم (حتى لو القاعدة بها UNIQUE على التاريخ الكامل)
      final sameDayExists = attendance.any((a) =>
        a.studentId == att.studentId &&
        a.date.year == att.date.year &&
        a.date.month == att.date.month &&
        a.date.day == att.date.day
      );
      if (sameDayExists) {
        ToastHelper.info('تم تسجيل حضور لهذا الطالب اليوم مسبقًا');
        return;
      }

      await _dbService.insertAttendance(att);
      await loadAttendance();
      unawaited(ParentPortalService().pushStudentSummary(att.studentId));
      ToastHelper.success('تم تسجيل الحضور بنجاح');
    } catch (e) {
      // في حال خالف UNIQUE في القاعدة بسبب فرق الثواني
      final err = e.toString();
      if (err.contains('UNIQUE') || err.contains('unique')) {
        ToastHelper.info('تم تسجيل حضور لهذا الطالب اليوم مسبقًا');
      } else {
        ToastHelper.error('حدث خطأ في تسجيل الحضور');
      }
    }
  }

  // حذف سجل
  Future<void> deleteAttendance(int id) async {
    try {
      final studentId = attendance.firstWhereOrNull((a) => a.id == id)?.studentId;
      await _dbService.deleteAttendance(id);
      await loadAttendance();
      if (studentId != null) {
        unawaited(ParentPortalService().pushStudentSummary(studentId));
      }
      ToastHelper.success('تم حذف السجل بنجاح');
    } catch (e) {
      ToastHelper.error('حدث خطأ في حذف السجل');
    }
  }

  /// تعديل تاريخ سجل حضور موجود (عملية ذرية واحدة، بدل حذف يدوي + إضافة
  /// يدوية في تبويبين مختلفين، وده كان بيخلي المدرّس ينسى يحذف السجل
  /// القديم فيفضل الطالب "مستحق عليه" شهر اتصحّح أصلاً).
  /// بيرجع رسالة خطأ لو فيه سجل تاني للطالب في نفس اليوم الجديد، أو null
  /// لو التعديل نجح.
  Future<String?> editAttendanceDate(Attendance att, DateTime newDate) async {
    final dayStart = DateTime(newDate.year, newDate.month, newDate.day);
    final dayEnd = DateTime(newDate.year, newDate.month, newDate.day, 23, 59, 59);
    final duplicate = attendance.firstWhereOrNull((a) =>
        a.id != att.id &&
        a.studentId == att.studentId &&
        !a.date.isBefore(dayStart) &&
        !a.date.isAfter(dayEnd));
    if (duplicate != null) {
      return 'فيه سجل حضور تاني للطالب في نفس اليوم المطلوب — احذف السجل ده أولاً';
    }
    try {
      final updated = att.copyWith(
        date: DateTime(newDate.year, newDate.month, newDate.day,
            att.date.hour, att.date.minute),
      );
      await _dbService.updateAttendance(updated);
      await loadAttendance();
      unawaited(ParentPortalService().pushStudentSummary(att.studentId));
      ToastHelper.success('تم تعديل تاريخ السجل بنجاح');
      return null;
    } catch (e) {
      return 'حدث خطأ في تعديل تاريخ السجل';
    }
  }

  /// لو الشهر القديم لسجل الحضور مرتبط فعلاً بدفعة مسجّلة (موجود في
  /// Payment.note بصيغة months=YYYY-MM)، بنرجّع تحذير للمدرّس قبل التعديل
  /// عشان يعرف إن فيه فاتورة قديمة اتسجلت على أساس الشهر الغلط ومحتاجة
  /// مراجعة يدوية — التعديل هنا مش هيغيّر الدفعة القديمة تلقائيًا.
  Future<String?> paidMonthWarning(int studentId, DateTime oldDate) async {
    final monthKey =
        '${oldDate.year.toString().padLeft(4, '0')}-${oldDate.month.toString().padLeft(2, '0')}';
    try {
      final payments = await _dbService.getPaymentsByStudent(studentId);
      final matched = payments.any((p) {
        final note = p.note ?? '';
        final monthsPart = note.split(';').first;
        if (!monthsPart.startsWith('months=')) return false;
        final months = monthsPart.substring('months='.length).split(',');
        return months.contains(monthKey);
      });
      if (matched) {
        final label = DateFormat('MMMM yyyy', 'ar').format(oldDate);
        return 'فيه دفعة مسجّلة بالفعل على شهر $label — تعديل تاريخ الحضور مش هيغيّر الفاتورة القديمة تلقائيًا، لازم تراجعها يدويًا';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // تبديل حالة حضور طالب في يوم معين:
  // لا يوجد سجل → حاضر | حاضر → غائب | غائب → حذف السجل
  Future<void> toggleAttendance(int studentId, DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final existing = attendance.firstWhereOrNull((a) =>
        a.studentId == studentId &&
        !a.date.isBefore(dayStart) &&
        !a.date.isAfter(dayEnd));
    try {
      if (existing == null) {
        await _dbService.insertAttendance(Attendance(
          studentId: studentId,
          date: DateTime(day.year, day.month, day.day,
              DateTime.now().hour, DateTime.now().minute),
          status: ATTENDANCE_PRESENT,
        ));
      } else if (existing.status == ATTENDANCE_PRESENT) {
        await _dbService.updateAttendance(
            existing.copyWith(status: ATTENDANCE_ABSENT));
      } else {
        await _dbService.deleteAttendance(existing.id!);
      }
      await loadAttendance();
      unawaited(ParentPortalService().pushStudentSummary(studentId));
    } catch (e) {
      ToastHelper.error('حدث خطأ');
    }
  }

  /// يحدّد حالة الحضور مباشرة (بدل الاعتماد على استدعاء toggleAttendance
  /// مرتين للقفز لحالة معيّنة — لو الاستدعاء التاني فشل، الطالب كان
  /// بيفضل "حاضر" بالخطأ رغم إن الشاشة بتفترض إنه اتسجّل "غائب").
  /// بيرمي الخطأ للمتصل (بدل ما يبتلعه) عشان يقدر يتصرف بناءً عليه.
  Future<void> setAttendanceStatus(
      int studentId, DateTime day, String status) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final existing = attendance.firstWhereOrNull((a) =>
        a.studentId == studentId &&
        !a.date.isBefore(dayStart) &&
        !a.date.isAfter(dayEnd));

    if (existing == null) {
      await _dbService.insertAttendance(Attendance(
        studentId: studentId,
        date: DateTime(day.year, day.month, day.day,
            DateTime.now().hour, DateTime.now().minute),
        status: status,
      ));
    } else {
      await _dbService.updateAttendance(existing.copyWith(status: status));
    }
    await loadAttendance();
    unawaited(ParentPortalService().pushStudentSummary(studentId));
  }

  // تحضير جميع طلاب المجموعة الغير مسجلين في يوم معين — بيتابع كل
  // طالب لوحده عشان لو فشل واحد في النص متوقفش الباقي، وبيبلّغ
  // بعدد الفشل الفعلي بدل رسالة نجاح عامة تخفي الفشل الجزئي.
  //
  // لو كل الطلاب متحضّرين بالفعل، الضغطة دي بتتعامل كـ"تراجع" وبتمسح
  // سجلات الحضور بتاعتهم (رجوع لحالة "لم يُسجَّل") بدل ما تفضل عالقة
  // على "حاضر" ومفيش وسيلة تلغيها غير واحد واحد.
  Future<void> markGroupAllPresent(
      List<int> studentIds, DateTime day) async {
    if (studentIds.isEmpty) return;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final recordsByStudent = <int, Attendance>{
      for (final a in attendance)
        if (!a.date.isBefore(dayStart) && !a.date.isAfter(dayEnd))
          a.studentId: a,
    };

    final allAlreadyPresent = studentIds.every((id) =>
        recordsByStudent[id]?.status == ATTENDANCE_PRESENT);

    if (allAlreadyPresent) {
      var succeeded = 0;
      var failed = 0;
      for (final id in studentIds) {
        final record = recordsByStudent[id];
        if (record == null) continue;
        try {
          await _dbService.deleteAttendance(record.id!);
          succeeded++;
        } catch (e) {
          failed++;
        }
      }
      await loadAttendance();
      for (final id in studentIds) {
        unawaited(ParentPortalService().pushStudentSummary(id));
      }
      if (failed == 0) {
        ToastHelper.success('تم إلغاء تحضير جميع الطلاب');
      } else if (succeeded == 0) {
        ToastHelper.error('فشل إلغاء التحضير — حاول تاني');
      } else {
        ToastHelper.error('اتلغى تحضير $succeeded طالب — فشل $failed');
      }
      return;
    }

    var succeeded = 0;
    var failed = 0;
    for (final id in studentIds) {
      if (recordsByStudent.containsKey(id)) continue;
      try {
        await _dbService.insertAttendance(Attendance(
          studentId: id,
          date: DateTime(day.year, day.month, day.day,
              DateTime.now().hour, DateTime.now().minute),
          status: ATTENDANCE_PRESENT,
        ));
        succeeded++;
      } catch (e) {
        failed++;
      }
    }
    await loadAttendance();
    for (final id in studentIds) {
      unawaited(ParentPortalService().pushStudentSummary(id));
    }
    if (failed == 0) {
      ToastHelper.success('تم تحضير جميع الطلاب');
    } else if (succeeded == 0) {
      ToastHelper.error('فشل تحضير الطلاب — حاول تاني');
    } else {
      ToastHelper.error('اتحضّر $succeeded طالب — فشل $failed');
    }
  }

  // ضبط نطاق التاريخ
  void setDateRange(DateTimeRange? range) async {
    dateRange.value = range;
    _applyFilter();
    // حفظ النطاق في التخزين المحلي
    try {
      final prefs = await SharedPreferences.getInstance();
      if (range == null) {
        await prefs.remove('att_range_start');
        await prefs.remove('att_range_end');
      } else {
        await prefs.setString('att_range_start', range.start.toIso8601String());
        await prefs.setString('att_range_end', range.end.toIso8601String());
      }
    } catch (_) {}
  }

  // ضمان تحديد اليوم كنطاق افتراضي مرة واحدة
  void ensureTodayDefault() async {
    if (dateRange.value != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('att_range_start');
      final e = prefs.getString('att_range_end');
      if (s != null && e != null) {
        final start = DateTime.parse(s);
        final end = DateTime.parse(e);
        setDateRange(DateTimeRange(start: start, end: end));
        return;
      }
    } catch (_) {}
    // افتراضيًا اليوم
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    setDateRange(DateTimeRange(start: start, end: end));
  }

  // تصفية حسب النطاق الحالي
  void _applyFilter() {
    final range = dateRange.value;
    Iterable<Attendance> data = attendance;

    // نطاق التاريخ
    if (range != null) {
      data = data.where((att) => _inRange(att.date, range));
    }

    // فلتر المجموعة عبر خريطة الطالب → مجموعة (تُبنى عند الاستدعاء من الواجهة)
    final gf = groupFilter.value;
    if (gf != null) {
      data = data.where((att) => _studentGroupMap[att.studentId] == gf);
    }

    // فلتر الحالة
    final sf = statusFilter.value;
    if (sf.isNotEmpty) {
      data = data.where((att) => att.status == sf);
    }

    // ترتيب
    final order = sortBy.value;
    final asc = sortAsc.value;
    List<Attendance> list = data.toList();
    if (order == 'date') {
      list.sort((a, b) => a.date.compareTo(b.date));
    } else if (order == 'name') {
      list.sort((a, b) {
        final an = _studentNameMap[a.studentId] ?? '';
        final bn = _studentNameMap[b.studentId] ?? '';
        return an.compareTo(bn);
      });
    }
    if (!asc) list = list.reversed.toList();

    filteredAttendance.assignAll(list);
  }

  bool _inRange(DateTime date, DateTimeRange range) {
    final d = DateTime(date.year, date.month, date.day, date.hour, date.minute, date.second);
    return !d.isBefore(range.start) && !d.isAfter(range.end);
  }

  // تصفية بسيطة بتاريخ نصي (حفاظًا على التوافق إن لزم)
  void filterByDate(String dateStr) {
    if (dateStr.isEmpty) {
      _applyFilter();
      return;
    }
    filteredAttendance.assignAll(
      attendance.where((att) => att.date.toIso8601String().startsWith(dateStr)).toList(),
    );
  }

  Future<String> getStudentName(int studentId) async {
    final student = await _dbService.getStudent(studentId);
    return student?.name ?? 'طالب غير معروف';
  }

  // تُستدعى من الواجهة لتهيئة خرائط الاسم/المجموعة لتمكين الفرز والفلترة دون استعلامات إضافية
  void buildStudentMaps(List<Student> students) {
    _studentGroupMap.clear();
    _studentNameMap.clear();
    for (final s in students) {
      if (s.id != null) {
        _studentGroupMap[s.id!] = s.groupId;
        _studentNameMap[s.id!] = s.name;
      }
    }
    _applyFilter();
  }

  void setGroupFilter(int? groupId) {
    groupFilter.value = groupId;
    _applyFilter();
  }

  void setStatusFilter(String status) {
    statusFilter.value = status;
    _applyFilter();
  }

  void setSorting({required String by, required bool asc}) {
    sortBy.value = by;
    sortAsc.value = asc;
    _applyFilter();
  }

  // ========== إحصائيات ==========

  // عدّ الحضور "حاضر" لكل طالب ضمن النطاق
  Map<int, int> getPresentCountByStudent({DateTimeRange? range}) {
    final r = range ?? dateRange.value;
    final Map<int, int> map = {};
    for (final att in attendance) {
      if (att.status == ATTENDANCE_PRESENT && (r == null || _inRange(att.date, r))) {
        map.update(att.studentId, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    return map;
  }

  // حساب الجلسات المتوقعة لكل مجموعة ضمن النطاق (حسب schedule JSON)
  Map<int, int> getExpectedSessionsPerGroup({required List<Group> groups, DateTimeRange? range}) {
    final r = range ?? dateRange.value;
    final Map<int, int> map = {};
    if (r == null) return map;
    for (final g in groups) {
      map[g.id!] = _countExpectedForGroup(g, r);
    }
    return map;
  }

  int _countExpectedForGroup(Group group, DateTimeRange range) {
    if (group.schedule == null || group.schedule!.isEmpty) return 0;

    final Set<int> weekdays = {};
    final raw = group.schedule!.trim();

    // المحاولة 1: JSON بصيغة [{"day":1,...}]
    try {
      final parsed = json.decode(raw);
      if (parsed is List) {
        for (final item in parsed) {
          final day = (item is Map && item['day'] is num) ? (item['day'] as num).toInt() : null;
          if (day != null && day >= 1 && day <= 7) weekdays.add(day);
        }
      }
    } catch (_) {
      // تجاهل خطأ JSON — سنحاول نص حر
    }

    // المحاولة 2: نص حر مثل "السبت 18:00-19:00, الاثنين 19:00-20:00"
    if (weekdays.isEmpty) {
      const Map<String, int> mapArDays = {
        'الاثنين': 1,
        'الثلاثاء': 2,
        'الأربعاء': 3,
        'الخميس': 4,
        'الجمعة': 5,
        'السبت': 6,
        'الأحد': 7,
      };
      final parts = raw.split(',');
      for (final p in parts) {
        final s = p.trim();
        for (final name in mapArDays.keys) {
          if (s.startsWith(name)) {
            weekdays.add(mapArDays[name]!);
            break;
          }
        }
      }
    }

    if (weekdays.isEmpty) return 0;

    int count = 0;
    DateTime cursor = DateTime(range.start.year, range.start.month, range.start.day);
    final DateTime end = DateTime(range.end.year, range.end.month, range.end.day);
    while (!cursor.isAfter(end)) {
      if (weekdays.contains(cursor.weekday)) count += 1;
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  // المجموعات التي لها حصة في يوم معين (حسب الجدول الأسبوعي)
  List<Group> groupsForDay(List<Group> groups, DateTime day) {
    final singleDay = DateTimeRange(
      start: DateTime(day.year, day.month, day.day),
      end: DateTime(day.year, day.month, day.day, 23, 59, 59),
    );
    return groups
        .where((g) => _countExpectedForGroup(g, singleDay) > 0)
        .toList();
  }

  // هل عند المجموعة دي حصة في يوم معين حسب جدولها الأسبوعي؟
  // لو المجموعة لسه محددتش جدول أصلاً، بنرجّع true (منسمحش نمنع تسجيل
  // الحضور لمجموعات ملهاش جدول مُدخَل، عشان الميزة دي اختيارية).
  bool groupHasSessionOnDay(Group group, DateTime day) {
    if (group.schedule == null || group.schedule!.trim().isEmpty) return true;
    final singleDay = DateTimeRange(
      start: DateTime(day.year, day.month, day.day),
      end: DateTime(day.year, day.month, day.day, 23, 59, 59),
    );
    return _countExpectedForGroup(group, singleDay) > 0;
  }

  // وقت الحصة لمجموعة في يوم معين (للعرض في الواجهة)
  // يُرجع مثلاً "10:00 - 11:00"
  String? sessionTimeForGroupOnDay(Group group, DateTime day) {
    final schedule = group.schedule?.trim();
    if (schedule == null || schedule.isEmpty) return null;
    const Map<String, int> mapArDays = {
      'الاثنين': 1, 'الثلاثاء': 2, 'الأربعاء': 3, 'الخميس': 4,
      'الجمعة': 5, 'السبت': 6, 'الأحد': 7,
    };
    final parts = schedule.split(',');
    for (final p in parts) {
      final s = p.trim();
      for (final entry in mapArDays.entries) {
        if (s.startsWith(entry.key) && entry.value == day.weekday) {
          final times = s.replaceFirst(entry.key, '').trim();
          return times.isNotEmpty ? times : null;
        }
      }
    }
    return null;
  }

  // الوقت المتبقي لحصة المجموعة الحالية، لو فيه حصة شغالة فعلاً دلوقتي
  // — بيرجّع null لو مفيش حصة شغالة (قبل الميعاد، أو بعد النهاية، أو
  // مفيش جدول أصلاً). صيغة الجدول القياسية "اليوم HH:mm-HH:mm" (زي ما
  // بيفرضها محرر الجدول في شاشة تفاصيل المجموعة) فيها نهاية صريحة
  // دايمًا، لكن بيانات قديمة/غير قياسية ممكن يكون فيها بداية بس —
  // في الحالة دي بنستخدم DEFAULT_SESSION_MINUTES كنهاية افتراضية.
  Duration? remainingSessionTime(Group group, DateTime now) {
    final timesText = sessionTimeForGroupOnDay(group, now);
    if (timesText == null) return null;

    TimeOfDay? parseTime(String v) {
      final p = v.trim().split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    final range = timesText.split('-');
    final startTod = parseTime(range.first);
    if (startTod == null) return null;

    final start =
        DateTime(now.year, now.month, now.day, startTod.hour, startTod.minute);
    final endTod = range.length == 2 ? parseTime(range[1]) : null;
    final end = endTod != null
        ? DateTime(now.year, now.month, now.day, endTod.hour, endTod.minute)
        : start.add(const Duration(minutes: DEFAULT_SESSION_MINUTES));

    if (now.isBefore(start) || !now.isBefore(end)) return null;
    return end.difference(now);
  }

  // هل كل طلاب المجموعة دي ليهم حالة حضور مسجّلة (حاضر أو غايب)
  // اليوم؟ بيُستخدم عشان نعرف نظهر زرار "إرسال تقرير واتساب" بس لما
  // التحضير يكون مكتمل، مش وسط التسجيل.
  bool isAttendanceCompleteForGroupToday(
      Group group, List<Student> groupStudents) {
    if (groupStudents.isEmpty) return false;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final markedIds = attendance
        .where((a) => !a.date.isBefore(dayStart) && !a.date.isAfter(dayEnd))
        .map((a) => a.studentId)
        .toSet();
    return groupStudents.every((s) => markedIds.contains(s.id));
  }

  // رسالة تقرير ولي الأمر — حضور وواجب النهاردة لطالب واحد. نفس نمط
  // الرسائل التانية اللي التطبيق بيبعتها للأهالي (student_details_page.dart،
  // settings_page.dart) عشان تفضل متسقة.
  String buildGuardianReportMessage({
    required Student student,
    required String attendanceStatus,
    String? homeworkStatus,
    String? teacherName,
    String? teacherSpecialization,
  }) {
    final dateLabel = DateFormat('d MMMM yyyy', 'ar').format(DateTime.now());
    final attLabel =
        attendanceStatus == ATTENDANCE_PRESENT ? '✅ حاضر' : '❌ غائب';
    final hwLabel = homeworkStatus == null
        ? 'لم يُسجَّل'
        : (homeworkStatus == HOMEWORK_DONE ? '📗 عمل' : '📙 لم يعمل');

    final buffer = StringBuffer()
      ..writeln('🧾 تقرير اليوم — $dateLabel')
      ..writeln('👤 الطالب: ${student.name}')
      ..writeln('')
      ..writeln('📊 الحضور: $attLabel')
      ..writeln('📖 الواجب: $hwLabel');

    final tName = teacherName?.trim() ?? '';
    final tSpec = teacherSpecialization?.trim() ?? '';
    if (tName.isNotEmpty || tSpec.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('👨‍🏫 المعلم: ${tName.isNotEmpty ? tName : '-'}')
        ..writeln('📘 التخصص: ${tSpec.isNotEmpty ? tSpec : '-'}');
    }
    buffer
      ..writeln('')
      ..writeln('تم الإرسال من تطبيق Active Class');
    return buffer.toString();
  }

  // ملخص حضور طالب واحد لشهر معيّن: عدد أيام الحضور وتواريخ الغياب
  StudentMonthAttendance getStudentMonthAttendance(int studentId, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    int present = 0;
    final absentDates = <DateTime>[];
    for (final a in attendance) {
      if (a.studentId != studentId) continue;
      if (a.date.isBefore(start) || a.date.isAfter(end)) continue;
      if (a.status == ATTENDANCE_PRESENT) {
        present++;
      } else if (a.status == ATTENDANCE_ABSENT) {
        absentDates.add(a.date);
      }
    }
    absentDates.sort();
    return StudentMonthAttendance(presentCount: present, absentDates: absentDates);
  }

  // إحصاء ملخص شامل للنطاق: إجمالي حاضر/متوقع ونسبة الحضور
  AttendanceSummary getSummary({required List<Student> students, required List<Group> groups, DateTimeRange? range}) {
    final r = range ?? dateRange.value;
    if (r == null) return const AttendanceSummary(totalPresent: 0, totalExpected: 0);

    final presentByStudent = getPresentCountByStudent(range: r);
    final expectedPerGroup = getExpectedSessionsPerGroup(groups: groups, range: r);

    int totalPresent = 0;
    int totalExpected = 0;

    for (final s in students) {
      totalPresent += presentByStudent[s.id ?? -1] ?? 0;
      final gExpected = expectedPerGroup[s.groupId] ?? 0;
      totalExpected += gExpected;
    }

    return AttendanceSummary(totalPresent: totalPresent, totalExpected: totalExpected);
  }
}

class StudentMonthAttendance {
  final int presentCount;
  final List<DateTime> absentDates;
  const StudentMonthAttendance({required this.presentCount, required this.absentDates});
}

class AttendanceSummary {
  final int totalPresent;
  final int totalExpected;
  const AttendanceSummary({required this.totalPresent, required this.totalExpected});

  double get percentage {
    if (totalExpected == 0) return 0;
    return (totalPresent / totalExpected) * 100.0;
  }

  int get totalAbsent {
    final diff = totalExpected - totalPresent;
    return diff < 0 ? 0 : diff;
  }
}

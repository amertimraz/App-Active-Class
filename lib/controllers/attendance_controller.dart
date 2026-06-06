// lib/controllers/attendance_controller.dart

import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
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
      await _dbService.deleteAttendance(id);
      await loadAttendance();
      ToastHelper.success('تم حذف السجل بنجاح');
    } catch (e) {
      ToastHelper.error('حدث خطأ في حذف السجل');
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

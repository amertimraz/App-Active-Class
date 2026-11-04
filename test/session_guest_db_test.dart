// test/session_guest_db_test.dart
//
// طالب ضيف في حصة مجموعة تانية: حضور على سجله هو بوسم الضيف، من غير حصة
// جديدة لمجموعته الأصلية.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/auto_absent.dart';
import 'package:active_class/utils/session_guest.dart';

class _Ctrl extends AttendanceController {
  @override
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseService db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ac_guest_');
    await databaseFactory.setDatabasesPath(dir.path);
    db = DatabaseService();
  });

  setUp(() async {
    final raw = await db.database;
    await raw.delete(TABLE_SYNC_OUTBOX);
    await raw.delete(TABLE_GROUPS);
  });

  final day = DateTime(2026, 11, 5);

  Future<({int a, int b, int s})> seed() async {
    final a = await db.insertGroup(Group(name: 'A', price: 100, code: 'A-'));
    final b = await db.insertGroup(Group(name: 'B', price: 100, code: 'B-'));
    final s = await db.insertStudent(Student(
      name: 'ضيف',
      code: 'B-01',
      groupId: b,
      price: 100,
      createdAt: DateTime(2026, 9, 1),
      attendanceStart: DateTime(2026, 9, 1),
    ));
    return (a: a, b: b, s: s);
  }

  test('addGuest يسجّل حضور بوسم الضيف على سجل الطالب نفسه', () async {
    final x = await seed();
    final c = _Ctrl();
    await c.addGuest(x.s, x.a, day);
    final rows = await db.getAttendanceByStudent(x.s);
    expect(rows, hasLength(1));
    expect(rows.single.status, ATTENDANCE_PRESENT);
    expect(isGuestOfGroup(rows.single, x.a), isTrue);
    expect(isGuestOfGroup(rows.single, x.b), isFalse);
  });

  test('إضافته مرتين ما بتكرّرش السجل (طالب واحد ويوم واحد)', () async {
    final x = await seed();
    final c = _Ctrl();
    await c.addGuest(x.s, x.a, day);
    await c.addGuest(x.s, x.a, day);
    expect(await db.getAttendanceByStudent(x.s), hasLength(1));
  });

  test('غياب تلقائي من حصة مجموعته الأصلية يتحوّل لحضور ضيف', () async {
    final x = await seed();
    await db.insertAttendance(Attendance(
      studentId: x.s,
      date: DateTime(2026, 11, 5, 20, 0),
      status: ATTENDANCE_ABSENT,
      notes: kAutoAbsentNote,
    ));
    final c = _Ctrl();
    await c.loadAttendance();
    await c.addGuest(x.s, x.a, day);
    final rows = await db.getAttendanceByStudent(x.s);
    expect(rows, hasLength(1));
    expect(rows.single.status, ATTENDANCE_PRESENT);
    expect(isGuestOfGroup(rows.single, x.a), isTrue);
  });

  test('removeGuest يمسح سجل الضيف بس لو الوسم على نفس المجموعة', () async {
    final x = await seed();
    final c = _Ctrl();
    await c.addGuest(x.s, x.a, day);
    await c.removeGuest(x.s, x.b, day); // مجموعة غلط: ما يمسحش
    expect(await db.getAttendanceByStudent(x.s), hasLength(1));
    await c.removeGuest(x.s, x.a, day);
    expect(await db.getAttendanceByStudent(x.s), isEmpty);
  });
}

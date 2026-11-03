// الكود التلقائي لازم يتجنب أي كود محجوز على مستوى كل الطلاب (مش جوّه
// المجموعة بس) — وإلا "يوجد طالب بنفس الكود بالفعل" بتتكرر مع كل محاولة.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';

class _Ctrl extends StudentController {
  @override
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseService db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ac_code_gen_');
    await databaseFactory.setDatabasesPath(dir.path);
    db = DatabaseService();
  });

  setUp(() async {
    final raw = await db.database;
    await raw.delete(TABLE_GROUPS);
  });

  Student st(String code, int g) => Student(
        name: 'طالب $code',
        code: code,
        groupId: g,
        price: 100,
        createdAt: DateTime(2026, 9, 1),
        attendanceStart: DateTime(2026, 9, 1),
      );

  test('طالب اتنقل لمجموعة تانية بيفضل كوده محجوز', () async {
    final a = await db.insertGroup(Group(name: 'A', price: 100, code: 'G1-'));
    final b = await db.insertGroup(Group(name: 'B', price: 100, code: 'G2-'));
    await db.insertStudent(st('G1-01', a));
    await db.insertStudent(st('G1-02', b)); // كوده G1 لكن في مجموعة B
    final next =
        await _Ctrl().generateNextStudentCode(groupPrefix: 'G1-', groupId: a);
    expect(next, 'G1-03');
  });
}

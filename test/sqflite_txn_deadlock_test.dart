// test/sqflite_txn_deadlock_test.dart
//
// تثبيت سبب تعليق جهاز مدرس (2026-10): نداء على الـdb الرئيسي (مش الـtxn)
// جوّه db.transaction بيعمل deadlock دائم في sqflite فكل استعلام بعده
// بيتعلّق (داشبورد بدوّامة، نسخ احتياطي بيعلّق، حفظ تلقائي يقف). كان في
// SyncEngine._noteIfSuffixed (spec 049) بينادي getSetting/setSetting على
// الـdb الرئيسي أثناء transaction السحب. الإصلاح: تمرير الـtxn (`on:`).
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active_class/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dir = await Directory.systemTemp.createTemp('ac_deadlock_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  // ملف مستقل لكل اختبار (قاعدة :memory: بتتشارك فالمعلّق بيوقّف اللي بعده).
  Future<Database> openOwn(String name) =>
      databaseFactory.openDatabase(p.join(dir.path, name));

  test('النمط القديم: استعلام على db الرئيسي جوّه transaction بيعلّق',
      () async {
    final db = await openOwn('old_pattern.db');
    await db.execute('CREATE TABLE t(k TEXT PRIMARY KEY, v TEXT)');
    final f = db.transaction((txn) async {
      await txn.insert('t', {'k': 'a', 'v': '1'});
      await db.query('t'); // ← الغلط: db بدل txn
    });
    await expectLater(f.timeout(const Duration(seconds: 1)),
        throwsA(isA<TimeoutException>()));
  });

  test('بالـtxn بيخلص عادي', () async {
    final db = await openOwn('txn_pattern.db');
    await db.execute('CREATE TABLE t(k TEXT PRIMARY KEY, v TEXT)');
    await db.transaction((txn) async {
      await txn.insert('t', {'k': 'a', 'v': '1'});
      await txn.query('t');
    }).timeout(const Duration(seconds: 3));
    expect((await db.query('t')).length, 1);
  });

  test('getSetting/setSetting(on: txn) جوّه transaction بيخلص (الإصلاح)',
      () async {
    final svc = DatabaseService();
    final raw = await svc.database;
    await raw.transaction((txn) async {
      await svc.setSetting('deadlock_probe', 'x', on: txn);
      expect(await svc.getSetting('deadlock_probe', on: txn), 'x');
      // read-modify-write زي _noteIfSuffixed
      final cur = await svc.getSetting('deadlock_probe', on: txn) ?? '';
      await svc.setSetting('deadlock_probe', '$cur,y', on: txn);
    }).timeout(const Duration(seconds: 5));
    expect(await svc.getSetting('deadlock_probe'), 'x,y');
  });
}

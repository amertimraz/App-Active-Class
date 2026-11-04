// test/sync_unsynced_rows_test.dart
//
// زر "رفع الصفوف الناقصة فقط": يرجّع للطابور الصفوف اللي عمرها ما اتزامنت
// (بلا remote_id ومش معلّقة) من غير ما يلمس أي صف متزامن.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService svc;
  late SyncEngine engine;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ac_unsynced_');
    await databaseFactory.setDatabasesPath(dir.path);
    svc = DatabaseService();
    engine = SyncEngine(
      client: SupabaseClient('http://localhost:54321', 'anon-key'),
      teamId: 'team-1',
      deviceId: 'assistant-device',
    );
  });

  setUp(() async {
    final raw = await svc.database;
    await raw.delete(TABLE_SYNC_OUTBOX);
    await raw.delete(TABLE_GROUPS);
  });

  test('يرجّع الصفوف الناقصة بس ولا يلمس المتزامن أو المعلّق', () async {
    final raw = await svc.database;
    final g = await svc.insertGroup(Group(name: 'G', price: 100, code: 'G-'));
    final s = await svc.insertStudent(Student(
      name: 'طالب',
      code: 'G-01',
      groupId: g,
      price: 100,
      createdAt: DateTime(2026, 9, 1),
      attendanceStart: DateTime(2026, 9, 1),
    ));
    // الأب (مجموعة وطالب) متزامنين.
    await raw.update(TABLE_GROUPS, {COL_SYNC_REMOTE_ID: 'g-1'},
        where: '$COL_GROUP_ID = ?', whereArgs: [g]);
    await raw.update(TABLE_STUDENTS, {COL_SYNC_REMOTE_ID: 'stu-1'},
        where: '$COL_STUDENT_ID = ?', whereArgs: [s]);

    Future<int> pay(double a) => svc.insertPayment(
        Payment(studentId: s, amount: a, date: DateTime(2026, 11, 1)));
    final synced = await pay(100); // متزامنة
    final lost = await pay(450); // ضايعة: بلا remote_id ومش في الطابور
    final pending = await pay(300); // معلّقة: بلا remote_id ولها صف في الطابور
    await raw.update(TABLE_PAYMENTS, {COL_SYNC_REMOTE_ID: 'pay-1'},
        where: '$COL_PAYMENT_ID = ?', whereArgs: [synced]);
    await raw.delete(TABLE_SYNC_OUTBOX);
    await raw.insert(TABLE_SYNC_OUTBOX, {
      COL_OUTBOX_TABLE: TABLE_PAYMENTS,
      COL_OUTBOX_ROW_ID: pending,
      COL_OUTBOX_OP: 'insert',
      COL_OUTBOX_PAYLOAD: '{}',
      COL_OUTBOX_CREATED_AT: DateTime.now().toIso8601String(),
      COL_OUTBOX_SYNCED: 0,
    });

    expect(await engine.unsyncedRowCounts(), {TABLE_PAYMENTS: 1});

    final added = await engine.enqueueUnsyncedRows(drain: false);
    expect(added, 1);

    final queued = await raw.query(TABLE_SYNC_OUTBOX,
        where: '$COL_OUTBOX_TABLE = ?', whereArgs: [TABLE_PAYMENTS]);
    final ids = queued.map((r) => r[COL_OUTBOX_ROW_ID]).toList()..sort();
    expect(ids, [lost, pending]..sort()); // الضايعة اترجعت، المعلّقة زي ما هي
    expect(ids, isNot(contains(synced))); // المتزامنة ما اتلمستش

    // مرة تانية: مفيش حاجة جديدة تتضاف (idempotent)
    expect(await engine.enqueueUnsyncedRows(drain: false), 0);
  });
}

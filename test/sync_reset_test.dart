// إعادة ضبط حالة المزامنة بعد فريق جديد (الفريق القديم اتحذف): الطابور يتفضّى
// والـremote_id المحلية تتمسح، من غير ما تتمسح أي بيانات.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseService db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ac_syncreset_');
    await databaseFactory.setDatabasesPath(dir.path);
    db = DatabaseService();
  });

  tearDownAll(() => DatabaseService.teamModeEnabled = false);

  Future<int> count(String sql) async {
    final raw = await db.database;
    final r = await raw.rawQuery(sql);
    return (r.first.values.first as int?) ?? 0;
  }

  test('بيمسح remote_id والطابور وما بيمسحش البيانات', () async {
    final raw = await db.database;
    await raw.delete(TABLE_SYNC_OUTBOX);
    final g = await db.insertGroup(Group(name: 'ج', price: 100));
    final s = await db.insertStudent(Student(
        name: 'س', code: 'R1', groupId: g, price: 100, createdAt: DateTime(2026, 9, 1)));
    // الجهاز فاكر إن الصفوف دي متزامنة مع فريق قديم.
    await raw.update(TABLE_GROUPS, {COL_SYNC_REMOTE_ID: 'old-group-uuid'});
    await raw.update(TABLE_STUDENTS, {COL_SYNC_REMOTE_ID: 'old-student-uuid'});
    await raw.insert(TABLE_SYNC_OUTBOX, {
      COL_OUTBOX_TABLE: TABLE_STUDENTS,
      COL_OUTBOX_ROW_ID: s,
      COL_OUTBOX_OP: 'insert',
      COL_OUTBOX_PAYLOAD: '{}',
      COL_OUTBOX_CREATED_AT: DateTime.now().toIso8601String(),
      COL_OUTBOX_SYNCED: 0,
    });
    expect(await db.countRowsWithRemoteId(TABLE_GROUPS), greaterThan(0));
    expect(await count('SELECT COUNT(*) FROM $TABLE_SYNC_OUTBOX'), greaterThan(0));

    await db.resetSyncStateForNewTeam();

    expect(await db.countRowsWithRemoteId(TABLE_GROUPS), 0);
    expect(await db.countRowsWithRemoteId(TABLE_STUDENTS), 0);
    expect(await count('SELECT COUNT(*) FROM $TABLE_SYNC_OUTBOX'), 0);
    // البيانات سليمة.
    expect(await count('SELECT COUNT(*) FROM $TABLE_GROUPS'), 1);
    expect(await count('SELECT COUNT(*) FROM $TABLE_STUDENTS'), 1);
  });

  test('جدول فاضي: countRowsWithRemoteId = 0', () async {
    expect(await db.countRowsWithRemoteId(TABLE_BOOKLETS), 0);
  });

  test('dedupeOutbox: يسيب أحدث عملية لكل صف، ولا يلمس الحذف ولا بلا payload', () async {
    final raw = await db.database;
    await raw.delete(TABLE_SYNC_OUTBOX);
    Future<void> add(String table, int row, String op, String? payload,
            {int synced = 0}) =>
        raw.insert(TABLE_SYNC_OUTBOX, {
          COL_OUTBOX_TABLE: table,
          COL_OUTBOX_ROW_ID: row,
          COL_OUTBOX_OP: op,
          COL_OUTBOX_PAYLOAD: payload,
          COL_OUTBOX_CREATED_AT: DateTime.now().toIso8601String(),
          COL_OUTBOX_SYNCED: synced,
        });
    // صف 1: ثلاث عمليات → تفضل الأخيرة بس.
    await add(TABLE_ATTENDANCE, 1, 'insert', '{"v":1}');
    await add(TABLE_ATTENDANCE, 1, 'update', '{"v":2}');
    await add(TABLE_ATTENDANCE, 1, 'update', '{"v":3}');
    // صف 2 في جدول تاني بنفس الرقم: مستقل.
    await add(TABLE_PAYMENTS, 1, 'insert', '{"v":1}');
    // حذف: ما بيتلمسش، وعملية بلا payload كمان.
    await add(TABLE_ATTENDANCE, 2, 'update', '{"v":1}');
    await add(TABLE_ATTENDANCE, 2, 'delete', null);
    await add(TABLE_ATTENDANCE, 3, 'update', null);
    await add(TABLE_ATTENDANCE, 3, 'update', null);
    // متزامنة بالفعل: خارج النطاق.
    await add(TABLE_ATTENDANCE, 4, 'update', '{"v":1}', synced: 1);

    final removed = await db.dedupeOutbox();
    expect(removed, 2);
    final rows = await raw.query(TABLE_SYNC_OUTBOX,
        where: '$COL_OUTBOX_TABLE = ? AND $COL_OUTBOX_ROW_ID = 1',
        whereArgs: [TABLE_ATTENDANCE]);
    expect(rows.length, 1);
    expect(rows.first[COL_OUTBOX_PAYLOAD], '{"v":3}');
    expect(
        await count('SELECT COUNT(*) FROM $TABLE_SYNC_OUTBOX'), 7); // 9 - 2
    expect(await db.dedupeOutbox(), 0); // مرة تانية: مفيش تكرار
  });
}

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
}

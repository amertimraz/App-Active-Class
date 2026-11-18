// spec 058 / P3 — عزل المساعد المقيَّد: وصول الفريق، حساب الصفوف المخفية، والمسح المحلي الآمن.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/sync_visibility.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TeamAccess.fromRpc', () {
    test('صف عادي (قائمة من PostgREST)', () {
      final a = TeamAccess.fromRpc([
        {'is_owner': false, 'restricted': true, 'visible_groups': 3}
      ])!;
      expect(a.restricted, isTrue);
      expect(a.isOwner, isFalse);
      expect(a.visibleGroups, 3);
      expect(a.restrictedWithoutGroups, isFalse);
    });

    test('مقيَّد بلا مجموعات = ممنوع الدخول (restrictedWithoutGroups)', () {
      final a = TeamAccess.fromRpc(
          {'is_owner': false, 'restricted': true, 'visible_groups': 0})!;
      expect(a.restrictedWithoutGroups, isTrue);
    });

    test('المالك وغير المقيَّد', () {
      final o = TeamAccess.fromRpc(
          [{'is_owner': true, 'restricted': false, 'visible_groups': 10}])!;
      expect(o.restricted, isFalse);
      expect(o.restrictedWithoutGroups, isFalse);
    });

    test('أشكال غير مفهومة → null (السيرفر قديم أو فشل): نعامله غير مقيَّد', () {
      expect(TeamAccess.fromRpc(null), isNull);
      expect(TeamAccess.fromRpc([]), isNull);
      expect(TeamAccess.fromRpc('x'), isNull);
      expect(TeamAccess.fromRpc([{'is_owner': true}]), isNull);
      expect(
          TeamAccess.fromRpc(
              [{'is_owner': 'yes', 'restricted': false, 'visible_groups': 1}]),
          isNull);
    });
  });

  group('hiddenCandidates / chunked', () {
    test('محلي ناقص اللي رجع في السحب', () {
      expect(
          hiddenCandidates(
              localRemoteIds: ['a', 'b', 'c'], visibleRemoteIds: {'b'}),
          ['a', 'c']);
      expect(
          hiddenCandidates(localRemoteIds: ['a'], visibleRemoteIds: {'a', 'z'}),
          isEmpty);
      expect(hiddenCandidates(localRemoteIds: [], visibleRemoteIds: {'a'}),
          isEmpty);
    });

    test('chunked بيقسّم صح', () {
      expect(chunked([1, 2, 3, 4, 5], 2).toList(), [
        [1, 2],
        [3, 4],
        [5]
      ]);
      expect(chunked(<int>[], 3).toList(), isEmpty);
    });
  });

  group('purgeSyncedRowsByRemoteId (قاعدة حقيقية)', () {
    late DatabaseService db;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('ac_purge_');
      await databaseFactory.setDatabasesPath(dir.path);
      db = DatabaseService();
    });

    tearDownAll(() => DatabaseService.teamModeEnabled = false);

    test('بيمسح الصفوف المحلية + طابورها فقط، ومن غير ما يضيف حذف للطابور', () async {
      final raw = await db.database;
      await raw.delete(TABLE_SYNC_OUTBOX);
      final g = await db.insertGroup(Group(name: 'ج', price: 100));
      final s1 = await db.insertStudent(Student(
          name: 'ظاهر', code: 'V1', groupId: g, price: 100, createdAt: DateTime(2026, 9, 1)));
      final s2 = await db.insertStudent(Student(
          name: 'مخفي', code: 'H1', groupId: g, price: 100, createdAt: DateTime(2026, 9, 1)));
      final s3 = await db.insertStudent(Student(
          name: 'جديد محلي', code: 'N1', groupId: g, price: 100, createdAt: DateTime(2026, 9, 1)));
      await raw.update(TABLE_STUDENTS, {COL_SYNC_REMOTE_ID: 'r-visible'},
          where: '$COL_STUDENT_ID = ?', whereArgs: [s1]);
      await raw.update(TABLE_STUDENTS, {COL_SYNC_REMOTE_ID: 'r-hidden'},
          where: '$COL_STUDENT_ID = ?', whereArgs: [s2]);
      // s3: لسه ما اترفعش (بلا remote_id) — ما يتلمسش أبدًا.
      await raw.delete(TABLE_SYNC_OUTBOX);
      for (final id in [s1, s2, s3]) {
        await raw.insert(TABLE_SYNC_OUTBOX, {
          COL_OUTBOX_TABLE: TABLE_STUDENTS,
          COL_OUTBOX_ROW_ID: id,
          COL_OUTBOX_OP: 'update',
          COL_OUTBOX_PAYLOAD: '{}',
          COL_OUTBOX_CREATED_AT: DateTime.now().toIso8601String(),
          COL_OUTBOX_SYNCED: 0,
        });
      }

      final n = await db.purgeSyncedRowsByRemoteId(
          TABLE_STUDENTS, COL_STUDENT_ID, ['r-hidden', 'r-nope']);
      expect(n, 1);

      final left = (await raw.query(TABLE_STUDENTS, columns: [COL_STUDENT_ID]))
          .map((r) => r[COL_STUDENT_ID])
          .toSet();
      expect(left, {s1, s3}); // المخفي اتمسح، الظاهر والمحلي الجديد لأ

      final ob = await raw.query(TABLE_SYNC_OUTBOX);
      expect(ob.map((r) => r[COL_OUTBOX_ROW_ID]).toSet(), {s1, s3});
      expect(ob.where((r) => r[COL_OUTBOX_OP] == 'delete'), isEmpty,
          reason: 'المسح المحلي ما يبعتش حذف للسيرفر');
    });

    test('قائمة فاضية = صفر وما بيعملش حاجة', () async {
      expect(await db.purgeSyncedRowsByRemoteId(TABLE_STUDENTS, COL_STUDENT_ID, []), 0);
    });

    test('دفعات أكبر من 400 id', () async {
      final raw = await db.database;
      final g = await db.insertGroup(Group(name: 'كبير', price: 100));
      final remote = <String>[];
      for (var i = 0; i < 450; i++) {
        final id = await db.insertStudent(Student(
            name: 'س$i', code: 'B$i', groupId: g, price: 1, createdAt: DateTime(2026, 9, 1)));
        await raw.update(TABLE_STUDENTS, {COL_SYNC_REMOTE_ID: 'bulk-$i'},
            where: '$COL_STUDENT_ID = ?', whereArgs: [id]);
        remote.add('bulk-$i');
      }
      expect(await db.purgeSyncedRowsByRemoteId(TABLE_STUDENTS, COL_STUDENT_ID, remote), 450);
    });
  });
}

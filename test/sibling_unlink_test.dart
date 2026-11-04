// test/sibling_unlink_test.dart
//
// بلاغ: "حذف الإخوة" مابيثبتش. فك الربط كان بيصفّر sibling_group_id بس
// ويسيب sibling_group_uuid، فالـuuid بيتبعت للمزامنة والجهاز التاني بيرجّع
// الربط بيه. لازم فك الربط يصفّر كل أثر الربط.
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
    final dir = await Directory.systemTemp.createTemp('ac_sib_unlink_');
    await databaseFactory.setDatabasesPath(dir.path);
    db = DatabaseService();
  });

  setUp(() async {
    final raw = await db.database;
    await raw.delete(TABLE_SYNC_OUTBOX);
    await raw.delete(TABLE_GROUPS);
  });

  Student st(String code, int g) => Student(
        name: 'طالب $code',
        code: code,
        groupId: g,
        price: 100,
        siblingsTotal: 150,
        createdAt: DateTime(2026, 9, 1),
        attendanceStart: DateTime(2026, 9, 1),
      );

  test('unlinkedFromSiblings يصفّر الـid والـuuid والإجمالي وعدّاد القرار', () {
    final s = Student(
      id: 1,
      name: 'x',
      code: 'c',
      groupId: 1,
      price: 100,
      siblingId: 2,
      siblingsTotal: 150,
      siblingGroupId: 1,
      siblingGroupUuid: 'uuid-1',
      siblingGroupCommittedCount: 2,
    ).unlinkedFromSiblings();
    expect(s.siblingId, isNull);
    expect(s.siblingsTotal, isNull);
    expect(s.siblingGroupId, isNull);
    expect(s.siblingGroupUuid, isNull);
    expect(s.siblingGroupCommittedCount, isNull);
  });

  test('أرشفة عضو من زوج إخوة: الاتنين يتفكّوا وuuid يتصفّر', () async {
    final g = await db.insertGroup(Group(name: 'G', price: 100, code: 'G-'));
    final a = await db.insertStudent(st('G-01', g));
    final b = await db.insertStudent(st('G-02', g));
    final sa = (await db.getStudent(a))!;
    final sb = (await db.getStudent(b))!;
    await db.linkSiblingGroup([sa, sb]);
    expect((await db.getStudent(a))!.siblingGroupUuid, isNotNull);

    await db.archiveStudent(a);

    for (final id in [a, b]) {
      final s = (await db.getStudent(id))!;
      expect(s.siblingGroupId, isNull, reason: 'id=$id');
      expect(s.siblingGroupUuid, isNull, reason: 'id=$id');
      expect(s.siblingGroupCommittedCount, isNull, reason: 'id=$id');
    }
  });

  test('أرشفة عضو من ٣ إخوة: الباقيين يفضلوا مربوطين بنفس الـuuid', () async {
    final g = await db.insertGroup(Group(name: 'G', price: 100, code: 'G-'));
    final ids = <int>[];
    for (var i = 1; i <= 3; i++) {
      ids.add(await db.insertStudent(st('G-0$i', g)));
    }
    final members = [for (final id in ids) (await db.getStudent(id))!];
    await db.linkSiblingGroup(members);
    final uuid = (await db.getStudent(ids[1]))!.siblingGroupUuid;

    await db.archiveStudent(ids[0]);

    final gone = (await db.getStudent(ids[0]))!;
    expect(gone.siblingGroupUuid, isNull);
    expect(gone.siblingGroupId, isNull);
    for (final id in [ids[1], ids[2]]) {
      final s = (await db.getStudent(id))!;
      expect(s.siblingGroupUuid, uuid);
      expect(s.siblingGroupId, isNotNull);
    }
  });
}

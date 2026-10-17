// test/sync_pull_collision_test.dart
//
// إعادة إنتاج حادثة 2026-10 (جهاز مالك فريق بدوّامات/أصفار والنت شغّال):
// سحب صف مجموعة/طالب بيتعارض اسمه/كوده مع صف محلي، جوّه transaction السحب،
// كان بيعمل deadlock دائم في SyncEngine._noteIfSuffixed. الاختبار ده
// بينفّذ نفس المسار الحقيقي (_applyRemoteRow ← _insertWithCodeRetry ←
// _noteIfSuffixed) جوّه db.transaction وبـtimeout: على الكود القديم بيفشل
// بـTimeoutException، وعلى الكود المصلّح بيخلص ويسجّل الصف باسم بديل.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/group_model.dart';
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
    final dir = await Directory.systemTemp.createTemp('ac_pull_collision_');
    await databaseFactory.setDatabasesPath(dir.path);
    svc = DatabaseService();
    engine = SyncEngine(
      client: SupabaseClient('http://localhost:54321', 'anon-key'),
      teamId: 'team-1',
      deviceId: 'owner-device',
    );
  });

  setUp(() async {
    final raw = await svc.database;
    await raw.delete(TABLE_SYNC_OUTBOX);
    await raw.delete(TABLE_GROUPS);
    await raw.delete(TABLE_APP_SETTINGS_FOR_TEST);
  });

  Future<int> localGroup(String name, String remoteId) async {
    final id = await svc.insertGroup(Group(name: name, price: 100));
    final raw = await svc.database;
    await raw.update(TABLE_GROUPS, {COL_SYNC_REMOTE_ID: remoteId},
        where: '$COL_GROUP_ID = ?', whereArgs: [id]);
    return id;
  }

  Map<String, dynamic> remoteGroup(String id, String name) => {
        'id': id,
        'name': name,
        'code': null,
        'price': 100,
        'color': null,
        'icon': null,
        'schedule': null,
        'pricing_type': 'monthly',
        'updated_at': '2026-10-10T10:00:00+00:00',
        'deleted_at': null,
        'origin_device_id': 'other-device',
        'local_id': 99,
      };

  test('مجموعة واردة باسم مكرّر جوّه transaction السحب: ما تعلّقش', () async {
    await localGroup('Grade 2', 'remote-1');
    final raw = await svc.database;

    // نفس شكل السحب: كل دفعة في transaction بتمرّر txn لـ_applyRemoteRow.
    await raw.transaction((txn) async {
      await engine.applyRemoteRowForTest(
          TABLE_GROUPS, remoteGroup('remote-2', 'Grade 2'),
          executor: txn);
    }).timeout(const Duration(seconds: 5));

    final names = (await raw.query(TABLE_GROUPS, orderBy: COL_GROUP_ID))
        .map((r) => r[COL_GROUP_NAME])
        .toList();
    expect(names, ['Grade 2', 'Grade 2 (2)']);

    // والصف اتسجّل كـ"معدّل بسبب تعارض" (spec 049).
    final noted = await svc.getSetting('sync_suffixed_remote_ids') ?? '';
    expect(noted.split(','), contains('remote-2'));

    // وقاعدة البيانات لسه شغّالة بعدها (مفيش قفل).
    expect((await raw.query(TABLE_GROUPS)).length, 2);
  });

  test('طالب وارد بكود مكرّر جوّه transaction السحب: ما يعلّقش', () async {
    final gid = await localGroup('Grade 3', 'remote-g');
    final sid = await svc.insertStudent(Student(
        name: 'منى',
        code: 'G301',
        groupId: gid,
        price: 100,
        createdAt: DateTime(2026, 9, 1)));
    final raw = await svc.database;
    await raw.update(TABLE_STUDENTS, {COL_SYNC_REMOTE_ID: 'remote-s1'},
        where: '$COL_STUDENT_ID = ?', whereArgs: [sid]);

    await raw.transaction((txn) async {
      await engine.applyRemoteRowForTest(
          TABLE_STUDENTS,
          {
            'id': 'remote-s2',
            'name': 'علي',
            'code': 'G301', // نفس الكود ← تعارض
            'group_remote_id': 'remote-g',
            'price': 100,
            'exempt_percent': 0,
            'is_archived': false,
            'updated_at': '2026-10-10T10:00:00+00:00',
            'deleted_at': null,
            'origin_device_id': 'other-device',
            'local_id': 77,
          },
          executor: txn);
    }).timeout(const Duration(seconds: 5));

    final codes = (await raw.query(TABLE_STUDENTS, orderBy: COL_STUDENT_ID))
        .map((r) => r[COL_STUDENT_CODE])
        .toList();
    expect(codes, ['G301', 'G301-2']);
    final noted = await svc.getSetting('sync_suffixed_remote_ids') ?? '';
    expect(noted.split(','), contains('remote-s2'));
  });
}

// اسم جدول الإعدادات للتنظيف بين الاختبارات (الثابت مش معرّف في constants).
const TABLE_APP_SETTINGS_FOR_TEST = TABLE_APP_SETTINGS;

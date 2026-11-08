// test/sync_attendance_flipflop_test.dart
//
// إعادة إنتاج بلاغ 2026-11-08: موبايل المدرّس وتابلت المساعد بيعرضوا حضور
// يوم مختلف للأبد. السيرفر فيه صفّين لنفس الطالب واليوم: غياب تلقائي من جهاز
// المدرّس (A) وتحضير يدوي من المساعد (B، أحدث). على جهاز المدرّس كان التوفيق
// بيحط بيانات B في الصف المحلي لكن بيسيبه مربوط بـA، فأول ما A يتسحب تاني
// (بطابع أقدم ومفيش تعديل معلّق) بيرجّع الغياب، وB بعده يرجّع الحضور… وكل
// سحب كامل بيقلب النتيجة حسب ترتيب الـid. المفروض الصف المحلي يتبنّى هوية
// الفائز (B) فيثبت الحضور مهما كان ترتيب السحب.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/sync_engine.dart';
import 'package:active_class/utils/auto_absent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService svc;
  late SyncEngine engine;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ac_att_flipflop_');
    await databaseFactory.setDatabasesPath(dir.path);
    svc = DatabaseService();
    engine = SyncEngine(
      client: SupabaseClient('http://localhost:54321', 'anon-key'),
      teamId: 'team-1',
      deviceId: 'owner-device',
    );
  });

  const day = '2026-11-08T11:00:00.000';

  Map<String, dynamic> remoteAtt(String id, String status, String? notes,
          String updatedAt, String origin) =>
      {
        'id': id,
        'student_remote_id': 's-remote',
        'date': day,
        'status': status,
        'notes': notes,
        'interaction': null,
        'recitation': null,
        'recitation_max': null,
        'updated_at': updatedAt,
        'deleted_at': null,
        'origin_device_id': origin,
        'local_id': 5,
      };

  final autoA = remoteAtt('A', 'غائب', kAutoAbsentNote,
      '2026-11-08T09:02:30+00:00', 'owner-device');
  final manualB = remoteAtt('B', 'حاضر', 'تم عبر QR',
      '2026-11-08T09:04:00+00:00', 'assistant-device');

  Future<int> setupLocalAutoAbsent() async {
    final raw = await svc.database;
    await raw.delete(TABLE_SYNC_OUTBOX);
    await raw.delete(TABLE_ATTENDANCE);
    await raw.delete(TABLE_STUDENTS);
    await raw.delete(TABLE_GROUPS);
    final gid = await svc.insertGroup(Group(name: 'ج', price: 100));
    await raw.update(TABLE_GROUPS, {COL_SYNC_REMOTE_ID: 'g-remote'},
        where: '$COL_GROUP_ID = ?', whereArgs: [gid]);
    final sid = await svc.insertStudent(Student(
        name: 'منى',
        code: 'G1',
        groupId: gid,
        price: 100,
        createdAt: DateTime(2026, 9, 1)));
    await raw.update(TABLE_STUDENTS, {COL_SYNC_REMOTE_ID: 's-remote'},
        where: '$COL_STUDENT_ID = ?', whereArgs: [sid]);
    final aid = await svc.insertAttendance(Attendance(
        studentId: sid,
        date: DateTime.parse(day),
        status: ATTENDANCE_ABSENT,
        notes: kAutoAbsentNote));
    // جهاز المدرّس رفع الغياب التلقائي: مربوط بـA وطابعه من السيرفر.
    await raw.update(
        TABLE_ATTENDANCE,
        {
          COL_SYNC_REMOTE_ID: 'A',
          COL_SYNC_UPDATED_AT: '2026-11-08T09:02:30+00:00',
        },
        where: '$COL_ATTENDANCE_ID = ?',
        whereArgs: [aid]);
    await raw.delete(TABLE_SYNC_OUTBOX); // مفيش تعديل معلّق
    return aid;
  }

  Future<String?> statusOf(int aid) async {
    final raw = await svc.database;
    final r = await raw.query(TABLE_ATTENDANCE,
        where: '$COL_ATTENDANCE_ID = ?', whereArgs: [aid]);
    return r.first[COL_ATTENDANCE_STATUS] as String?;
  }

  Future<void> pull(List<Map<String, dynamic>> rows) async {
    final raw = await svc.database;
    await raw.transaction((txn) async {
      for (final r in rows) {
        await engine.applyRemoteRowForTest(TABLE_ATTENDANCE, r, executor: txn);
      }
    });
  }

  test('B قبل A: التحضير اليدوي يثبت بعد كل سحب كامل', () async {
    final aid = await setupLocalAutoAbsent();
    for (var i = 0; i < 3; i++) {
      await pull([manualB, autoA]);
      expect(await statusOf(aid), 'حاضر', reason: 'السحب رقم ${i + 1}');
    }
  });

  test('A قبل B: نفس النتيجة (الترتيب ما يفرقش)', () async {
    final aid = await setupLocalAutoAbsent();
    for (var i = 0; i < 3; i++) {
      await pull([autoA, manualB]);
      expect(await statusOf(aid), 'حاضر', reason: 'السحب رقم ${i + 1}');
    }
  });

  test('جهاز المساعد: تحضيره اليدوي ما يتغيّرش بغياب المدرّس التلقائي',
      () async {
    final aid = await setupLocalAutoAbsent();
    final raw = await svc.database;
    // المساعد: صفه المحلي هو تحضيره اليدوي (B) المربوط بـB.
    await raw.update(
        TABLE_ATTENDANCE,
        {
          COL_ATTENDANCE_STATUS: 'حاضر',
          COL_ATTENDANCE_NOTES: 'تم عبر QR',
          COL_SYNC_REMOTE_ID: 'B',
          COL_SYNC_UPDATED_AT: '2026-11-08T09:04:00+00:00',
        },
        where: '$COL_ATTENDANCE_ID = ?',
        whereArgs: [aid]);
    for (var i = 0; i < 3; i++) {
      await pull([autoA, manualB]);
      expect(await statusOf(aid), 'حاضر');
    }
  });
}

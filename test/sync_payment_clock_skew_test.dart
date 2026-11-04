// test/sync_payment_clock_skew_test.dart
//
// بلاغ: قيمة مدفوعات المساعد أعلى من المدرس (ترخيص ACTV-2210-BJAD-LMSR).
// السبب المرجّح: بعد الـpush الطابع المحلي (sync_updated_at) بيفضل بساعة
// الجهاز، والسيرفر بيختم الصف بوقته (trg_set_updated_at). لو ساعة الجهاز
// متقدّمة على السيرفر، أي تعديل لاحق من الزميل (بطابع السيرفر الأقدم) بيتجاهله
// _applyRemoteRow للأبد → الجهازان يختلفا في المبلغ ومفيش أي خطأ ظاهر.
// القاعدة المصلّحة: لو مفيش تعديل محلي معلّق في الـoutbox لنفس الصف، نسخة
// السيرفر هي الأحدث فعليًا ويتم تطبيقها حتى لو طابعها أقدم.
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
    final dir = await Directory.systemTemp.createTemp('ac_pay_skew_');
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
    await raw.delete(TABLE_GROUPS); // CASCADE على الطلاب والمدفوعات
  });

  // دفعة متزامنة (عندها remote_id) بطابع محلي "في المستقبل" (ساعة متقدّمة).
  Future<({int paymentId, Database raw})> seed({double amount = 100}) async {
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
    await raw.update(TABLE_STUDENTS, {COL_SYNC_REMOTE_ID: 'stu-1'},
        where: '$COL_STUDENT_ID = ?', whereArgs: [s]);
    final p = await svc.insertPayment(
        Payment(studentId: s, amount: amount, date: DateTime(2026, 10, 5)));
    await raw.update(
        TABLE_PAYMENTS,
        {
          COL_SYNC_REMOTE_ID: 'pay-1',
          COL_SYNC_UPDATED_AT: '2026-10-10T12:00:00.000', // ساعة الجهاز
        },
        where: '$COL_PAYMENT_ID = ?',
        whereArgs: [p]);
    // نظّف أي صف outbox اتولّد من الإدراج (الوضع الافتراضي: team mode مقفول).
    await raw.delete(TABLE_SYNC_OUTBOX);
    return (paymentId: p, raw: raw);
  }

  // نسخة السيرفر: مبلغ مختلف وطابع أقدم من الطابع المحلي (ساعة الجهاز سابقة).
  Map<String, dynamic> remote(double amount) => {
        'id': 'pay-1',
        'student_remote_id': 'stu-1',
        'date': DateTime(2026, 10, 5).toIso8601String(),
        'amount': amount,
        'note': null,
        'updated_at': '2026-10-09T00:00:00+00:00',
        'deleted_at': null,
        'origin_device_id': 'teacher-device',
        'local_id': 7,
      };

  Future<double> amountOf(Database raw, int id) async {
    final r =
        await raw.query(TABLE_PAYMENTS, where: '$COL_PAYMENT_ID = ?', whereArgs: [id]);
    return (r.first[COL_PAYMENT_AMOUNT] as num).toDouble();
  }

  test('الصف متزامن بالكامل: تعديل السيرفر يتطبّق رغم ساعة الجهاز المتقدّمة',
      () async {
    final s = await seed(amount: 100);
    await engine.applyRemoteRowForTest(TABLE_PAYMENTS, remote(40));
    expect(await amountOf(s.raw, s.paymentId), 40);
  });

  test('تعديل محلي معلّق في الـoutbox لنفس الصف: النسخة المحلية تفضل', () async {
    final s = await seed(amount: 100);
    await s.raw.insert(TABLE_SYNC_OUTBOX, {
      COL_OUTBOX_TABLE: TABLE_PAYMENTS,
      COL_OUTBOX_ROW_ID: s.paymentId,
      COL_OUTBOX_OP: 'update',
      COL_OUTBOX_PAYLOAD: '{}',
      COL_OUTBOX_CREATED_AT: DateTime.now().toIso8601String(),
      COL_OUTBOX_SYNCED: 0,
    });
    await engine.applyRemoteRowForTest(TABLE_PAYMENTS, remote(40));
    expect(await amountOf(s.raw, s.paymentId), 100);
  });
}

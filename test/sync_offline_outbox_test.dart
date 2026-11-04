// test/sync_offline_outbox_test.dart
//
// بلاغ: دفعات المساعد بتتسجّل عنده بس ومابتوصلش للمدرس (فرق 4,500 = ١٠ دفعات
// × ٤٥٠). السبب: أي استثناء في الـpush — حتى انقطاع النت — كان بيتحسب فشلة،
// وبعد ٥ فشلات (حوالي دقيقتين أوفلاين) صف الطابور بيتمسح نهائيًا والدفعة
// تفضل على الجهاز ده بس. المطلوب: انقطاع النت مايمسحش الصف مهما طال.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/sync_engine.dart';

/// نفس الاستثناء اللي بيرميه IOClient على أندرويد لما مفيش نت.
class _ClientSocketException extends http.ClientException
    implements SocketException {
  _ClientSocketException(super.message);
  @override
  InternetAddress? get address => null;
  @override
  OSError? get osError => null;
  @override
  int? get port => null;
}

class _OfflineClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw _ClientSocketException('Failed host lookup: offline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService svc;
  late SyncEngine engine;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ac_offline_outbox_');
    await databaseFactory.setDatabasesPath(dir.path);
    svc = DatabaseService();
    engine = SyncEngine(
      client: SupabaseClient('http://localhost:54321', 'anon-key',
          httpClient: _OfflineClient()),
      teamId: 'team-1',
      deviceId: 'assistant-device',
    );
  });

  setUp(() async {
    final raw = await svc.database;
    await raw.delete(TABLE_SYNC_OUTBOX);
    await raw.delete(TABLE_GROUPS);
  });

  test('دفعة معلّقة تفضل في الطابور بعد ٦٠ جولة إرسال فاشلة (أوفلاين)',
      () async {
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
        Payment(studentId: s, amount: 450, date: DateTime(2026, 11, 1)));
    final row = (await raw.query(TABLE_PAYMENTS,
            where: '$COL_PAYMENT_ID = ?', whereArgs: [p]))
        .first;
    await raw.delete(TABLE_SYNC_OUTBOX);
    await raw.insert(TABLE_SYNC_OUTBOX, {
      COL_OUTBOX_TABLE: TABLE_PAYMENTS,
      COL_OUTBOX_ROW_ID: p,
      COL_OUTBOX_OP: 'insert',
      COL_OUTBOX_PAYLOAD: _json(row),
      COL_OUTBOX_CREATED_AT: DateTime.now().toIso8601String(),
      COL_OUTBOX_SYNCED: 0,
    });

    for (var i = 0; i < 60; i++) {
      await engine.drainOutbox();
    }

    final left = await raw.query(TABLE_SYNC_OUTBOX,
        where: '$COL_OUTBOX_TABLE = ? AND $COL_OUTBOX_ROW_ID = ?',
        whereArgs: [TABLE_PAYMENTS, p]);
    expect(left, hasLength(1), reason: 'الدفعة اتمسحت من الطابور بسبب النت');
  });
}

String _json(Map<String, Object?> row) {
  final b = StringBuffer('{');
  var first = true;
  row.forEach((k, v) {
    if (!first) b.write(',');
    first = false;
    b.write('"$k":');
    if (v == null) {
      b.write('null');
    } else if (v is num) {
      b.write(v);
    } else {
      b.write('"${v.toString().replaceAll('"', r'\"')}"');
    }
  });
  b.write('}');
  return b.toString();
}

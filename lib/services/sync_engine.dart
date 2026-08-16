// lib/services/sync_engine.dart
//
// محرك مزامنة "وضع الفريق" — SQLite المحلي يفضل هو مصدر البيانات
// الأساسي حتى مع تفعيل الميزة دي؛ الكلاس ده بس طبقة إضافية:
//   - Push: بيفرّغ sync_outbox (التغييرات المحلية) لسيرفر Supabase.
//   - Pull: مشترك في Realtime عشان يستقبل تغييرات الأجهزة التانية
//     فورًا، ويطبّقها محليًا (last-write-wins بمقارنة updated_at).
//
// كل جدول قابل للمشاركة (groups/students/attendance/payments) بيتربط
// بأبوه عن طريق remote UUID بتاعه (group_remote_id/student_remote_id)
// مش رقم محلي — لأن الـ id المحلي مش فريد عبر الأجهزة المختلفة.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/services/database_service.dart';

class SyncEngine {
  final SupabaseClient client;
  final String teamId;
  final String deviceId;

  SyncEngine({required this.client, required this.teamId, required this.deviceId});

  static const _tables = [
    TABLE_GROUPS,
    TABLE_STUDENTS,
    TABLE_ATTENDANCE,
    TABLE_PAYMENTS,
  ];

  final DatabaseService _dbService = DatabaseService();
  Timer? _pushTimer;
  RealtimeChannel? _channel;
  bool _draining = false;

  String _pkCol(String table) => switch (table) {
        TABLE_GROUPS => COL_GROUP_ID,
        TABLE_STUDENTS => COL_STUDENT_ID,
        TABLE_ATTENDANCE => COL_ATTENDANCE_ID,
        TABLE_PAYMENTS => COL_PAYMENT_ID,
        _ => throw ArgumentError('جدول غير قابل للمزامنة: $table'),
      };

  void start() {
    DatabaseService.teamModeEnabled = true;
    _pushTimer = Timer.periodic(const Duration(seconds: 3), (_) => drainOutbox());
    unawaited(drainOutbox());
    _subscribeRealtime();
  }

  Future<void> stop() async {
    DatabaseService.teamModeEnabled = false;
    _pushTimer?.cancel();
    _pushTimer = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      await client.removeChannel(ch);
    }
  }

  // ── Push: تفريغ sync_outbox ──────────────────────────────────────
  Future<void> drainOutbox() async {
    if (_draining) return;
    _draining = true;
    try {
      final db = await _dbService.database;
      final rows = await db.query(
        TABLE_SYNC_OUTBOX,
        where: '$COL_OUTBOX_SYNCED = 0',
        orderBy: '$COL_OUTBOX_ID ASC',
        limit: 50,
      );
      for (final row in rows) {
        final table = row[COL_OUTBOX_TABLE] as String;
        final rowId = row[COL_OUTBOX_ROW_ID] as int;
        final op = row[COL_OUTBOX_OP] as String;
        final payloadStr = row[COL_OUTBOX_PAYLOAD] as String?;
        final outboxId = row[COL_OUTBOX_ID] as int;
        try {
          final done = await _pushOne(table, rowId, op, payloadStr);
          if (done) {
            await db.update(TABLE_SYNC_OUTBOX, {COL_OUTBOX_SYNCED: 1},
                where: '$COL_OUTBOX_ID = ?', whereArgs: [outboxId]);
          }
          // لو مش done (أب لسه مش متزامن) — نسيبه، هيتحاول تاني الجولة الجاية
        } catch (e) {
          debugPrint('SyncEngine: فشل push لـ $table/$rowId — $e');
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<bool> _pushOne(
      String table, int rowId, String op, String? payloadStr) async {
    if (op == 'delete') {
      await client
          .from(table)
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('team_id', teamId)
          .eq('origin_device_id', deviceId)
          .eq('local_id', rowId);
      return true;
    }
    if (payloadStr == null) return true;
    final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
    final remoteRow = await _buildRemoteRow(table, rowId, payload);
    if (remoteRow == null) return false; // الأب لسه ملوش remote_id

    final res = await client
        .from(table)
        .upsert(remoteRow, onConflict: 'team_id,origin_device_id,local_id')
        .select('id')
        .single();
    final remoteId = res['id'] as String;
    final db = await _dbService.database;
    await db.update(table, {COL_SYNC_REMOTE_ID: remoteId},
        where: '${_pkCol(table)} = ?', whereArgs: [rowId]);
    return true;
  }

  Future<Map<String, dynamic>?> _buildRemoteRow(
      String table, int localId, Map<String, dynamic> payload) async {
    final base = <String, dynamic>{
      'team_id': teamId,
      'origin_device_id': deviceId,
      'local_id': localId,
      'updated_at': payload[COL_SYNC_UPDATED_AT],
    };
    switch (table) {
      case TABLE_GROUPS:
        return {
          ...base,
          'name': payload[COL_GROUP_NAME],
          'code': payload[COL_GROUP_CODE],
          'price': payload[COL_GROUP_PRICE],
          'color': payload[COL_GROUP_COLOR],
          'icon': payload[COL_GROUP_ICON],
          'schedule': payload[COL_GROUP_SCHEDULE],
          'pricing_type': payload[COL_GROUP_PRICING_TYPE],
        };
      case TABLE_STUDENTS:
        final groupLocalId = payload[COL_STUDENT_GROUP_ID] as int?;
        String? groupRemoteId;
        if (groupLocalId != null) {
          groupRemoteId =
              await _localRemoteId(TABLE_GROUPS, COL_GROUP_ID, groupLocalId);
          if (groupRemoteId == null) return null;
        }
        return {
          ...base,
          'group_remote_id': groupRemoteId,
          'name': payload[COL_STUDENT_NAME],
          'code': payload[COL_STUDENT_CODE],
          'price': payload[COL_STUDENT_PRICE],
          'guardian_phone': payload[COL_STUDENT_GUARDIAN_PHONE],
          'birth_date': payload[COL_STUDENT_BIRTH_DATE],
        };
      case TABLE_ATTENDANCE:
        final studentLocalId = payload[COL_ATTENDANCE_STUDENT_ID] as int?;
        String? studentRemoteId;
        if (studentLocalId != null) {
          studentRemoteId = await _localRemoteId(
              TABLE_STUDENTS, COL_STUDENT_ID, studentLocalId);
          if (studentRemoteId == null) return null;
        }
        return {
          ...base,
          'student_remote_id': studentRemoteId,
          'date': payload[COL_ATTENDANCE_DATE],
          'status': payload[COL_ATTENDANCE_STATUS],
          'notes': payload[COL_ATTENDANCE_NOTES],
        };
      case TABLE_PAYMENTS:
        final studentLocalId = payload[COL_PAYMENT_STUDENT_ID] as int?;
        String? studentRemoteId;
        if (studentLocalId != null) {
          studentRemoteId = await _localRemoteId(
              TABLE_STUDENTS, COL_STUDENT_ID, studentLocalId);
          if (studentRemoteId == null) return null;
        }
        return {
          ...base,
          'student_remote_id': studentRemoteId,
          'date': payload[COL_PAYMENT_DATE],
          'amount': payload[COL_PAYMENT_AMOUNT],
          'note': payload[COL_PAYMENT_NOTE],
        };
    }
    return null;
  }

  Future<String?> _localRemoteId(String table, String pkCol, int localId) async {
    final db = await _dbService.database;
    final rows = await db.query(table,
        columns: [COL_SYNC_REMOTE_ID], where: '$pkCol = ?', whereArgs: [localId]);
    if (rows.isEmpty) return null;
    return rows.first[COL_SYNC_REMOTE_ID] as String?;
  }

  Future<int?> _localIdForRemote(
      String table, String pkCol, String remoteId) async {
    final db = await _dbService.database;
    final rows = await db.query(table,
        columns: [pkCol],
        where: '$COL_SYNC_REMOTE_ID = ?',
        whereArgs: [remoteId]);
    if (rows.isEmpty) return null;
    return rows.first[pkCol] as int;
  }

  /// كل الصفوف المحلية الموجودة فعلاً وقت ما المدرس يفعّل وضع الفريق
  /// لأول مرة — نضيفهم لطابور الإرسال (بترتيب الجداول: مجموعات قبل
  /// طلاب قبل حضور/مدفوعات، عشان الآباء يتزامنوا قبل الأبناء).
  Future<void> enqueueAllExistingLocalRows() async {
    final db = await _dbService.database;
    for (final table in _tables) {
      final pkCol = _pkCol(table);
      final rows = await db.query(table);
      for (final row in rows) {
        final id = row[pkCol] as int;
        final map = Map<String, dynamic>.from(row);
        if (map[COL_SYNC_UPDATED_AT] == null) {
          map[COL_SYNC_UPDATED_AT] = DateTime.now().toIso8601String();
          await db.update(table, {COL_SYNC_UPDATED_AT: map[COL_SYNC_UPDATED_AT]},
              where: '$pkCol = ?', whereArgs: [id]);
        }
        await db.insert(TABLE_SYNC_OUTBOX, {
          COL_OUTBOX_TABLE: table,
          COL_OUTBOX_ROW_ID: id,
          COL_OUTBOX_OP: 'insert',
          COL_OUTBOX_PAYLOAD: jsonEncode(map),
          COL_OUTBOX_CREATED_AT: DateTime.now().toIso8601String(),
          COL_OUTBOX_SYNCED: 0,
        });
      }
    }
  }

  // ── Pull: أول تحميل كامل (وقت ما مساعد ينضم لفريق) ────────────────
  Future<void> initialFullPull() async {
    for (final table in _tables) {
      final rows = await client
          .from(table)
          .select()
          .eq('team_id', teamId)
          .isFilter('deleted_at', null);
      for (final r in (rows as List)) {
        await _applyRemoteRow(table, r as Map<String, dynamic>);
      }
    }
  }

  // ── Pull: اشتراك Realtime ─────────────────────────────────────────
  void _subscribeRealtime() {
    final channel = client.channel('team-$teamId');
    for (final table in _tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'team_id',
          value: teamId,
        ),
        callback: (payload) {
          final newRow = payload.newRecord;
          if (newRow.isEmpty) return; // DELETE فعلي (مش بنستخدمه — بنعمل soft-delete)
          unawaited(_applyRemoteRow(table, newRow));
        },
      );
    }
    channel.subscribe();
    _channel = channel;
  }

  Future<void> _applyRemoteRow(String table, Map<String, dynamic> remote) async {
    final db = await _dbService.database;
    final pkCol = _pkCol(table);
    final remoteId = remote['id'] as String;
    final remoteUpdatedAt = DateTime.tryParse(remote['updated_at'] as String? ?? '');
    final remoteDeleted = remote['deleted_at'] != null;
    final remoteOriginDevice = remote['origin_device_id'] as String?;
    final remoteLocalId = remote['local_id'] as int?;

    // 1) الصف ده معروف عندي محليًا (متسجّل remote_id) — طبّق آخر تعديل.
    final existing = await db.query(table,
        where: '$COL_SYNC_REMOTE_ID = ?', whereArgs: [remoteId]);
    if (existing.isNotEmpty) {
      final localRow = existing.first;
      if (remoteDeleted) {
        await db.delete(table, where: '$pkCol = ?', whereArgs: [localRow[pkCol]]);
        return;
      }
      final localUpdatedAt =
          DateTime.tryParse(localRow[COL_SYNC_UPDATED_AT] as String? ?? '');
      if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          !remoteUpdatedAt.isAfter(localUpdatedAt)) {
        return; // مش أحدث من نسختي — (وده كمان بيتجاهل صدى تعديلاتي إحنا)
      }
      final localMap = await _toLocalMap(table, remote);
      if (localMap == null) return;
      await db.update(table, localMap,
          where: '$pkCol = ?', whereArgs: [localRow[pkCol]]);
      return;
    }

    // 2) مفيش remote_id مسجّل عندي — يمكن ده صدى push بتاعي أنا لسه
    //    مستني تأكيد (سباق)، أو صف جديد من عضو تاني.
    if (remoteOriginDevice == deviceId && remoteLocalId != null) {
      final mine = await db.query(table,
          where: '$pkCol = ?', whereArgs: [remoteLocalId]);
      if (mine.isNotEmpty) {
        if (remoteDeleted) {
          await db.delete(table, where: '$pkCol = ?', whereArgs: [remoteLocalId]);
        } else {
          await db.update(table, {COL_SYNC_REMOTE_ID: remoteId},
              where: '$pkCol = ?', whereArgs: [remoteLocalId]);
        }
        return;
      }
    }

    if (remoteDeleted) return; // اتحذف قبل ما نستلمه أصلاً

    // 3) صف جديد فعليًا من عضو تاني.
    try {
      final localMap = await _toLocalMap(table, remote);
      if (localMap == null) return; // الأب لسه مش موجود محليًا — best effort
      await _insertWithCodeRetry(db, table, localMap);
    } catch (e) {
      // فشل نهائي حتى بعد محاولات تعديل الكود — نتجاهل الصف بدل ما
      // نكسر حلقة المزامنة كلها.
      debugPrint('SyncEngine: تعذر إدراج صف مستلم من $table — $e');
    }
  }

  /// كود الطالب بيتولّد محليًا على كل جهاز لوحده (بعدّ طلاب نفس
  /// المجموعة عنده هو بس)، فلو المدرس والمساعد ضافوا طالب جديد في
  /// نفس المجموعة قريب من بعض، الاتنين ممكن يولّدوا نفس الكود.
  /// عمود code عنده UNIQUE محليًا، فالـ insert العادي كان بيفشل
  /// ويتجاهل صف الطالب الجديد بصمت (يختفي عند الزميل). هنا بدل
  /// التجاهل، لو الفشل بسبب تعارض الكود، نضيف لاحقة ونعيد المحاولة
  /// كذا مرة — الطالب يفضل موجود بكود مختلف شوية بدل ما يضيع تمامًا.
  Future<void> _insertWithCodeRetry(
      DatabaseExecutor db, String table, Map<String, dynamic> localMap) async {
    try {
      await db.insert(table, localMap);
      return;
    } catch (e) {
      if (table != TABLE_STUDENTS || localMap[COL_STUDENT_CODE] == null) rethrow;
      final baseCode = localMap[COL_STUDENT_CODE] as String;
      for (var suffix = 2; suffix <= 20; suffix++) {
        final map = {...localMap, COL_STUDENT_CODE: '$baseCode-$suffix'};
        try {
          await db.insert(table, map);
          debugPrint(
              'SyncEngine: تعارض كود طالب ($baseCode) — اتسجّل بكود بديل ($baseCode-$suffix)');
          return;
        } catch (_) {
          continue;
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _toLocalMap(
      String table, Map<String, dynamic> remote) async {
    final updatedAt = remote['updated_at'] as String?;
    switch (table) {
      case TABLE_GROUPS:
        return {
          COL_GROUP_NAME: remote['name'],
          COL_GROUP_CODE: remote['code'],
          COL_GROUP_PRICE: remote['price'],
          COL_GROUP_COLOR: remote['color'],
          COL_GROUP_ICON: remote['icon'],
          COL_GROUP_SCHEDULE: remote['schedule'],
          COL_GROUP_PRICING_TYPE: remote['pricing_type'],
          COL_SYNC_UPDATED_AT: updatedAt,
          COL_SYNC_REMOTE_ID: remote['id'],
        };
      case TABLE_STUDENTS:
        final groupRemoteId = remote['group_remote_id'] as String?;
        final localGroupId = groupRemoteId != null
            ? await _localIdForRemote(TABLE_GROUPS, COL_GROUP_ID, groupRemoteId)
            : null;
        if (groupRemoteId != null && localGroupId == null) return null;
        return {
          COL_STUDENT_GROUP_ID: localGroupId,
          COL_STUDENT_NAME: remote['name'],
          COL_STUDENT_CODE: remote['code'],
          COL_STUDENT_PRICE: remote['price'],
          COL_STUDENT_GUARDIAN_PHONE: remote['guardian_phone'],
          COL_STUDENT_BIRTH_DATE: remote['birth_date'],
          COL_SYNC_UPDATED_AT: updatedAt,
          COL_SYNC_REMOTE_ID: remote['id'],
        };
      case TABLE_ATTENDANCE:
        final studentRemoteId = remote['student_remote_id'] as String?;
        final localStudentId = studentRemoteId != null
            ? await _localIdForRemote(
                TABLE_STUDENTS, COL_STUDENT_ID, studentRemoteId)
            : null;
        if (studentRemoteId != null && localStudentId == null) return null;
        return {
          COL_ATTENDANCE_STUDENT_ID: localStudentId,
          COL_ATTENDANCE_DATE: remote['date'],
          COL_ATTENDANCE_STATUS: remote['status'],
          COL_ATTENDANCE_NOTES: remote['notes'],
          COL_SYNC_UPDATED_AT: updatedAt,
          COL_SYNC_REMOTE_ID: remote['id'],
        };
      case TABLE_PAYMENTS:
        final studentRemoteId = remote['student_remote_id'] as String?;
        final localStudentId = studentRemoteId != null
            ? await _localIdForRemote(
                TABLE_STUDENTS, COL_STUDENT_ID, studentRemoteId)
            : null;
        if (studentRemoteId != null && localStudentId == null) return null;
        return {
          COL_PAYMENT_STUDENT_ID: localStudentId,
          COL_PAYMENT_DATE: remote['date'],
          COL_PAYMENT_AMOUNT: remote['amount'],
          COL_PAYMENT_NOTE: remote['note'],
          COL_SYNC_UPDATED_AT: updatedAt,
          COL_SYNC_REMOTE_ID: remote['id'],
        };
    }
    return null;
  }
}

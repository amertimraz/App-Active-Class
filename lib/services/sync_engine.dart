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
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/services/database_service.dart';

class SyncEngine {
  final SupabaseClient client;
  final String teamId;
  final String deviceId;
  /// بتتنادى لو اكتشفنا إن المستخدم بقى مش عضو في الفريق ده (المدرس
  /// شاله، أو حذف الفريق) — RLS بتقفل القراءة/الكتابة صامتة (نتيجة
  /// فاضية، مش error)، فمن غير الفحص الصريح ده الجهاز كان هيفضل شغال
  /// بصلاحيات bypass للأبد من غير ما حد يعرف إنه اتشال فعليًا.
  final VoidCallback? onRemovedFromTeam;
  /// بتتنادى لو ترخيص المدرس الحقيقي (Firebase) بقى موقوف/منتهي —
  /// RLS بتقفل السيرفر فورًا (وده شغال ومتأكد منه)، بس ده بيوقف
  /// المزامنة بس صامت في الخلفية؛ من غير الفحص ده مفيش أي حاجة كانت
  /// بتوقف الـ bypass المحلي (teamModeBypassLimits) على جهاز المساعد،
  /// فكان بيفضل يقدر يضيف بيانات محليًا من غير حدود وكأن حاجة ملحصلتش.
  final VoidCallback? onLicenseInactive;
  /// بتتنادى لو المدرس فكّ ارتباط الجهاز ده (من شاشة إدارة الأعضاء)
  /// عشان يسمح لجهاز جديد ياخد مكانه — الجهاز القديم (اللي شغال دلوقتي)
  /// لازم يتقفل فورًا بدل ما يفضل شغال وكأن حاجة ملحصلتش.
  final VoidCallback? onDeviceUnbound;
  /// بتتنادى مع كل catchUpPull (أول اتصال وكل إعادة اتصال) — team_members
  /// (صلاحيات الأعضاء) مش من ضمن الجداول المتزامنة/الـ Realtime هنا،
  /// فلو المدرس غيّر صلاحية لمساعد (زي منح/سحب حذف الطلاب) وجهاز
  /// المساعد شغال بالفعل، مكانش هياخد التحديث ده إلا لو قفل التطبيق
  /// وفتحه تاني (أول مرة بس بتتقرا الصلاحيات في _startEngine).
  final VoidCallback? onReconnected;

  SyncEngine({
    required this.client,
    required this.teamId,
    required this.deviceId,
    this.onRemovedFromTeam,
    this.onLicenseInactive,
    this.onDeviceUnbound,
    this.onReconnected,
  });

  static const _tables = [
    TABLE_GROUPS,
    TABLE_STUDENTS,
    TABLE_ATTENDANCE,
    TABLE_PAYMENTS,
    TABLE_HOMEWORK,
  ];

  final DatabaseService _dbService = DatabaseService();
  Timer? _pushTimer;
  Timer? _membershipTimer;
  RealtimeChannel? _channel;
  bool _draining = false;
  bool _pulling = false;

  String _pkCol(String table) => switch (table) {
        TABLE_GROUPS => COL_GROUP_ID,
        TABLE_STUDENTS => COL_STUDENT_ID,
        TABLE_ATTENDANCE => COL_ATTENDANCE_ID,
        TABLE_PAYMENTS => COL_PAYMENT_ID,
        TABLE_HOMEWORK => COL_HOMEWORK_ID,
        _ => throw ArgumentError('جدول غير قابل للمزامنة: $table'),
      };

  void start() {
    DatabaseService.teamModeEnabled = true;
    _pushTimer = Timer.periodic(const Duration(seconds: 3), (_) => drainOutbox());
    // Realtime بس بتوصّل أحداث الجداول المشتركة (groups/students/...)،
    // مش team_members/teams — فلو المدرس عطّل وضع الفريق أو شال المساعد
    // وهو متصل بالفعل (من غير أي قطع/إعادة اتصال)، من غير الفحص الدوري
    // ده مكناش هنعرف غير لما الاتصال يقطع ويرجع (ممكن ياخد وقت طويل).
    // مفيش داعي نشغّله على جهاز المدرس نفسه — الكولباكين التنين
    // (onRemovedFromTeam/onLicenseInactive) مستبعدين له عمدًا، فالفحص
    // هيكون طلب شبكة كل 15 ثانية للأبد من غير أي فايدة على السيرفر.
    if (onRemovedFromTeam != null ||
        onLicenseInactive != null ||
        onDeviceUnbound != null) {
      _membershipTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _checkStillAllowed());
    }
    unawaited(drainOutbox());
    _subscribeRealtime();
  }

  Future<void> stop() async {
    DatabaseService.teamModeEnabled = false;
    _pushTimer?.cancel();
    _pushTimer = null;
    _membershipTimer?.cancel();
    _membershipTimer = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      await client.removeChannel(ch);
    }
  }

  Future<void> _checkStillAllowed() async {
    if (await _wasRemovedFromTeam()) return;
    if (await _wasLicenseDeactivated()) return;
    if (await _wasDeviceUnbound()) return;
    // team_members (صلاحيات الأعضاء) مش من ضمن الجداول المتزامنة، فمن
    // غير استدعاء onReconnected هنا كمان، أي صلاحية يغيّرها المدرس
    // (زي حذف الطلاب أو رؤية الأرقام المالية) كانت مش هتوصل للمساعد
    // إلا لو قفل التطبيق وفتحه تاني — دلوقتي بتوصل خلال 15 ثانية
    // كحد أقصى زي باقي الفحوصات الدورية.
    onReconnected?.call();
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
            // مفيش حد بيقرا صفوف outbox بعد ما تتزامن — نمسحها بدل ما
            // نعلّمها بس synced=1 ونسيبها تتراكم في الداتابيز المحلية
            // للأبد (وضع الفريق شغال باستمرار، يعني آلاف الصفوف بمرور
            // الوقت من غير أي فايدة).
            await db.delete(TABLE_SYNC_OUTBOX,
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
      // لو الصف كان متزامن قبل الحذف (عنده remote_id)، لازم نستهدفه
      // بيه — مش بـ origin_device_id+local_id، اللي بيفشل صامت (0 صف
      // اتأثر، من غير أي error) لو الصف الأصلي جه من جهاز تاني (زي
      // مساعد بيحذف مجموعة أنشأها المدرس، أو العكس): كان بيتمسح محليًا
      // عند اللي حذف بس يفضل موجود بالكامل عند بقية الفريق، وبيرجع
      // "يتكاثر" تاني عند أي جهاز يعمل full pull بعد كده.
      final remoteId = payloadStr != null
          ? (jsonDecode(payloadStr) as Map<String, dynamic>)['remote_id']
              as String?
          : null;
      if (remoteId != null) {
        await client
            .from(table)
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', remoteId);
      } else {
        // الصف ده اتحذف قبل حتى ما يتزامن أصلاً — لازم يكون جه من نفس
        // الجهاز ده (مستحيل يكون عند زميل عرفه من غيرنا)، فالطريقة
        // القديمة صحيحة هنا بالظبط.
        await client
            .from(table)
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('team_id', teamId)
            .eq('origin_device_id', deviceId)
            .eq('local_id', rowId);
      }
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
        // ملحوظة: عكس group_remote_id، لو الأخ/الأخت لسه ملهوش remote_id
        // (الاتنين ممكن يتزامنوا في نفس اللحظة تقريبًا) بنسيب الحقل
        // فاضي بدل ما نمنع تزامن الطالب كله — وإلا لو الاتنين مستنيين
        // remote_id بعض، محدش هياخد remote_id أبدًا (deadlock). الربط
        // هيتزامن لاحقًا أول ما الطرفين يبقى عندهم remote_id.
        final siblingLocalId = payload[COL_STUDENT_SIBLING_ID] as int?;
        final siblingRemoteId = siblingLocalId != null
            ? await _localRemoteId(TABLE_STUDENTS, COL_STUDENT_ID, siblingLocalId)
            : null;
        return {
          ...base,
          'group_remote_id': groupRemoteId,
          'sibling_remote_id': siblingRemoteId,
          'siblings_total': payload[COL_STUDENT_SIBLINGS_TOTAL],
          'name': payload[COL_STUDENT_NAME],
          'code': payload[COL_STUDENT_CODE],
          'price': payload[COL_STUDENT_PRICE],
          'guardian_phone': payload[COL_STUDENT_GUARDIAN_PHONE],
          'birth_date': payload[COL_STUDENT_BIRTH_DATE],
          'attendance_start': payload[COL_STUDENT_ATTENDANCE_START],
          'exempt_percent': payload[COL_STUDENT_EXEMPT_PERCENT],
          'exempt_reason': payload[COL_STUDENT_EXEMPT_REASON],
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
      case TABLE_HOMEWORK:
        final studentLocalId = payload[COL_HOMEWORK_STUDENT_ID] as int?;
        String? studentRemoteId;
        if (studentLocalId != null) {
          studentRemoteId = await _localRemoteId(
              TABLE_STUDENTS, COL_STUDENT_ID, studentLocalId);
          if (studentRemoteId == null) return null;
        }
        return {
          ...base,
          'student_remote_id': studentRemoteId,
          'date': payload[COL_HOMEWORK_DATE],
          'status': payload[COL_HOMEWORK_STATUS],
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
      String table, String pkCol, String remoteId,
      {DatabaseExecutor? executor}) async {
    final db = executor ?? await _dbService.database;
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
  Future<void> initialFullPull() => _fullPull(includeDeleted: false);

  /// Realtime بس بتبعت الأحداث اللي بتحصل وهي متصلة — أي تغيير حصل
  /// من زميل وأنا offline (التطبيق مقفول/في الخلفية/النت مقطوع، وده
  /// عادي جدًا على الموبايل) هيضيع للأبد لو معتمدين على Realtime بس،
  /// لأنها مش بتعيد بث اللي فات وقت إعادة الاتصال. عشان كده بنعمل
  /// "تحميل لحاق" كامل (يشمل الصفوف المحذوفة كمان، عكس initialFullPull،
  /// عشان نعرف بحذف حصل وإحنا offline) كل ما القناة تتصل/تعيد الاتصال.
  Future<void> catchUpPull() async {
    if (await _wasRemovedFromTeam()) return;
    if (await _wasLicenseDeactivated()) return;
    if (await _wasDeviceUnbound()) return;
    onReconnected?.call();
    await _fullPull(includeDeleted: true);
  }

  /// بتتحقق من عضوية المستخدم في الفريق ده لسه موجودة على السيرفر —
  /// RLS بترفض بصمت (نتيجة فاضية) مش بترمي error، فمن غير الفحص
  /// الصريح ده محدش هيعرف إنه اتشال. بتتنادى مع catchUpPull (كل ما
  /// الاتصال يرجع) عشان نلحق الحالة دي بسرعة معقولة.
  Future<bool> _wasRemovedFromTeam() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final rows = await client
          .from('team_members')
          .select('user_id')
          .eq('team_id', teamId)
          .eq('user_id', uid)
          .limit(1);
      if ((rows as List).isEmpty) {
        onRemovedFromTeam?.call();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('SyncEngine: فشل التحقق من العضوية — $e');
      return false;
    }
  }

  /// بتتحقق من owner_license_active على الفريق ده — بيتحدّث بس من
  /// جهاز المدرس نفسه لما حالة ترخيصه الحقيقي (Firebase) تتغيّر
  /// (TeamModeService._watchOwnerLicense). لو موقوف، لازم نعطّل الـ
  /// bypass المحلي هنا كمان، مش بس نعتمد على RLS إنها تقفل السيرفر.
  Future<bool> _wasLicenseDeactivated() async {
    try {
      final row = await client
          .from('teams')
          .select('owner_license_active')
          .eq('id', teamId)
          .single();
      final active = row['owner_license_active'] as bool? ?? true;
      if (!active) {
        onLicenseInactive?.call();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('SyncEngine: فشل التحقق من حالة الترخيص — $e');
      return false;
    }
  }

  /// بتتحقق إن الجهاز ده لسه هو الجهاز المرتبط بحساب المساعد —
  /// is_device_still_bound قراءة بس (بدون ربط تلقائي، عكس claim_device)
  /// عمدًا، عشان لو المدرس فكّ الارتباط، الجهاز القديم (لو لسه شغال)
  /// مايربطش نفسه تاني تلقائيًا قبل ما جهاز جديد ياخد الفرصة.
  Future<bool> _wasDeviceUnbound() async {
    try {
      final stillBound = await client.rpc('is_device_still_bound',
          params: {'_team_id': teamId, '_device_id': deviceId}) as bool;
      if (!stillBound) {
        onDeviceUnbound?.call();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('SyncEngine: فشل التحقق من ارتباط الجهاز — $e');
      return false;
    }
  }

  /// _pulling بتمنع initialFullPull وcatchUpPull يشتغلوا في نفس
  /// اللحظة (بيحصل غالبًا لحظة أول انضمام — الاتنين بيتنادوا قريب من
  /// بعض) — لو اشتغلوا مع بعض ممكن الاتنين يحاولوا يدرجوا نفس الصف
  /// الجديد محليًا في نفس الوقت قبل ما أي حد يسجّل remote_id، فيتكرر
  /// الصف بدل ما يتوحّد.
  Future<void> _fullPull({required bool includeDeleted}) async {
    if (_pulling) return;
    _pulling = true;
    try {
      // نجيب كل الجداول بالتوازي (طلبات شبكة مستقلة عن بعض) بدل ما
      // نستنى كل جدول لوحده على التالي — كان ده بيبطّئ أول انضمام
      // لمساعد (كل الجداول بالتتابع) بدون أي داعي.
      //
      // كل جدول ليه try/catch لوحده: Future.wait الافتراضي بيرفض
      // بأول خطأ ويسيب كل الجداول التانية (اللي ممكن تكون نجحت فعلاً)
      // من غير ما تتطبّق خالص. لو جدول واحد (مثلاً الحضور لو فيه
      // آلاف السجلات وحصل timeout) فشل، مش لازم نضيّع بيانات المجموعات
      // والطلاب اللي نجحت معاه.
      final results = await Future.wait(_tables.map((table) async {
        try {
          final rows = includeDeleted
              ? await client.from(table).select().eq('team_id', teamId)
              : await client
                  .from(table)
                  .select()
                  .eq('team_id', teamId)
                  .isFilter('deleted_at', null);
          return rows;
        } catch (e) {
          debugPrint('SyncEngine: فشل تحميل جدول $table — $e');
          return null;
        }
      }));

      final db = await _dbService.database;
      for (var i = 0; i < _tables.length; i++) {
        final rows = results[i] as List?;
        if (rows == null || rows.isEmpty) continue;
        // كل صفوف الجدول ده جوه transaction واحدة بدل ما كل صف يعمل
        // commit لوحده — ده كان أكبر سبب للبطء وقت أول تحميل كامل
        // لفريق فيه بيانات كتير (مئات سجلات الحضور/المدفوعات).
        await db.transaction((txn) async {
          for (final r in rows) {
            try {
              await _applyRemoteRow(_tables[i], r as Map<String, dynamic>,
                  executor: txn);
            } catch (e) {
              // خطأ في صف واحد (زي تعارض UNIQUE وقت تحديث صف موجود)
              // ميوقفش باقي صفوف الجدول ده — لو مسيباه يطلع من غير
              // catch هنا، الـ transaction كلها بتترجع (rollback) وكل
              // صفوف الجدول ده اللي نجحت قبله بتضيع معاه.
              debugPrint(
                  'SyncEngine: تعذر تطبيق صف من ${_tables[i]} — $e');
            }
          }
        });
        _refreshUiForTable(_tables[i]);
      }
    } finally {
      _pulling = false;
    }
  }

  /// بيانات الفريق الواردة (أول تحميل كامل أو Realtime) بتتكتب في
  /// SQLite مباشرة — الكنترولرز (GroupController/StudentController/...)
  /// بتاعت الشاشات مبتعرفش إن حاجة اتغيّرت غير لو حد عمل reload صريح
  /// (زي فتح الصفحة من الأول). من غير الاستدعاء ده، بيانات المدرس
  /// كانت بتوصل فعليًا لقاعدة بيانات المساعد، بس مش بتظهر على شاشته
  /// إلا لو قفل الشاشة وفتحها تاني — وده اللي كان شكله "المزامنة مش
  /// شغالة خالص".
  void _refreshUiForTable(String table) {
    switch (table) {
      case TABLE_GROUPS:
        if (Get.isRegistered<GroupController>()) {
          Get.find<GroupController>().loadGroups();
        }
        break;
      case TABLE_STUDENTS:
        if (Get.isRegistered<StudentController>()) {
          Get.find<StudentController>().loadAllStudents();
        }
        break;
      case TABLE_ATTENDANCE:
        if (Get.isRegistered<AttendanceController>()) {
          Get.find<AttendanceController>().loadAttendance();
        }
        break;
      case TABLE_PAYMENTS:
        if (Get.isRegistered<PaymentController>()) {
          Get.find<PaymentController>().loadPayments();
        }
        break;
      case TABLE_HOMEWORK:
        if (Get.isRegistered<HomeworkController>()) {
          Get.find<HomeworkController>().loadHomework();
        }
        break;
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().loadDashboardData();
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
          unawaited(_applyRemoteRow(table, newRow)
              .then((_) => _refreshUiForTable(table)));
        },
      );
    }
    // بتتنادى وقت أول اشتراك ناجح، وكمان أوتوماتيك كل ما الـ socket
    // يعيد الاتصال بعد انقطاع (الحزمة بتعمل reconnect+rejoin لوحدها) —
    // فبتغطي بالظبط اللحظة اللي كنا محتاجين فيها تحميل لحاق.
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(catchUpPull());
      }
    });
    _channel = channel;
  }

  Future<void> _applyRemoteRow(String table, Map<String, dynamic> remote,
      {DatabaseExecutor? executor}) async {
    final db = executor ?? await _dbService.database;
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
      final localMap = await _toLocalMap(table, remote, executor: executor);
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
      final localMap = await _toLocalMap(table, remote, executor: executor);
      if (localMap == null) return; // الأب لسه مش موجود محليًا — best effort

      // حضور: ممكن جهازين (المدرس + المساعد) يسجّلوا حضور نفس الطالب
      // في نفس اليوم كل واحد من عنده قبل ما تتم المزامنة بينهم. الفهرس
      // UNIQUE على مستوى اليوم بيمنع الإدراج المباشر، لكن لازم نتأكد
      // هنا صراحة عشان نتجاهل الصف بهدوء بدل ما نعتمد على استثناء القاعدة.
      if (table == TABLE_ATTENDANCE) {
        final studentId = localMap[COL_ATTENDANCE_STUDENT_ID];
        final date = localMap[COL_ATTENDANCE_DATE] as String?;
        if (studentId != null && date != null && date.length >= 10) {
          final dayPrefix = date.substring(0, 10);
          final dup = await db.query(
            table,
            where: '$COL_ATTENDANCE_STUDENT_ID = ? AND substr($COL_ATTENDANCE_DATE, 1, 10) = ?',
            whereArgs: [studentId, dayPrefix],
            limit: 1,
          );
          if (dup.isNotEmpty) {
            debugPrint(
                'SyncEngine: تجاهل صف حضور مكرر (طالب $studentId، يوم $dayPrefix) وارد من جهاز تاني');
            return;
          }
        }
      }
      // نفس منطق التكرار اليومي بالظبط، لكن لجدول الواجب (نفس الفهرس
      // الفريد المحلي: طالب واحد + يوم واحد).
      if (table == TABLE_HOMEWORK) {
        final studentId = localMap[COL_HOMEWORK_STUDENT_ID];
        final date = localMap[COL_HOMEWORK_DATE] as String?;
        if (studentId != null && date != null && date.length >= 10) {
          final dayPrefix = date.substring(0, 10);
          final dup = await db.query(
            table,
            where: '$COL_HOMEWORK_STUDENT_ID = ? AND substr($COL_HOMEWORK_DATE, 1, 10) = ?',
            whereArgs: [studentId, dayPrefix],
            limit: 1,
          );
          if (dup.isNotEmpty) {
            debugPrint(
                'SyncEngine: تجاهل صف واجب مكرر (طالب $studentId، يوم $dayPrefix) وارد من جهاز تاني');
            return;
          }
        }
      }

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
  ///
  /// نفس المشكلة بالظبط موجودة في المجموعات: اسم المجموعة (وكودها)
  /// UNIQUE محليًا على كل جهاز. لو المساعد عنده أصلاً مجموعة بنفس
  /// اسم مجموعة عند المدرس (قبل ما يتوصلوا)، الإدراج كان بيفشل
  /// بصمت — والأخطر إن أي طالب/حضور/دفعة تابعة للمجموعة دي كانت
  /// بتضيع هي كمان لأن _toLocalMap بيرجع null لو الأب (المجموعة)
  /// مش موجود محليًا. فبنعمل نفس منطق اللاحقة على الاسم والكود.
  Future<void> _insertWithCodeRetry(
      DatabaseExecutor db, String table, Map<String, dynamic> localMap) async {
    try {
      await db.insert(table, localMap);
      return;
    } catch (e) {
      if (table == TABLE_STUDENTS && localMap[COL_STUDENT_CODE] != null) {
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
      if (table == TABLE_GROUPS) {
        final baseName = localMap[COL_GROUP_NAME] as String?;
        final baseCode = localMap[COL_GROUP_CODE] as String?;
        if (baseName == null) rethrow;
        for (var suffix = 2; suffix <= 20; suffix++) {
          final map = {
            ...localMap,
            COL_GROUP_NAME: '$baseName ($suffix)',
            if (baseCode != null) COL_GROUP_CODE: '$baseCode-$suffix',
          };
          try {
            await db.insert(table, map);
            debugPrint(
                'SyncEngine: تعارض اسم مجموعة ($baseName) — اتسجّلت باسم بديل ($baseName ($suffix))');
            return;
          } catch (_) {
            continue;
          }
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _toLocalMap(
      String table, Map<String, dynamic> remote,
      {DatabaseExecutor? executor}) async {
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
            ? await _localIdForRemote(TABLE_GROUPS, COL_GROUP_ID, groupRemoteId,
                executor: executor)
            : null;
        if (groupRemoteId != null && localGroupId == null) return null;
        // عكس المجموعة، رابط الأخ/الأخت مش شرط لإدراج الطالب — لو
        // لسه مش عندنا الطالب التاني محليًا (وصل بترتيب مختلف)، بنسيب
        // الرابط فاضي بدل ما نأجّل الطالب كله؛ هيتصحّح لما يحصل تعديل
        // تاني على أي واحد فيهم.
        final siblingRemoteId = remote['sibling_remote_id'] as String?;
        final localSiblingId = siblingRemoteId != null
            ? await _localIdForRemote(
                TABLE_STUDENTS, COL_STUDENT_ID, siblingRemoteId,
                executor: executor)
            : null;
        return {
          COL_STUDENT_GROUP_ID: localGroupId,
          COL_STUDENT_SIBLING_ID: localSiblingId,
          COL_STUDENT_SIBLINGS_TOTAL: remote['siblings_total'],
          COL_STUDENT_NAME: remote['name'],
          COL_STUDENT_CODE: remote['code'],
          COL_STUDENT_PRICE: remote['price'],
          COL_STUDENT_GUARDIAN_PHONE: remote['guardian_phone'],
          COL_STUDENT_BIRTH_DATE: remote['birth_date'],
          COL_STUDENT_ATTENDANCE_START: remote['attendance_start'],
          COL_STUDENT_EXEMPT_PERCENT: remote['exempt_percent'],
          COL_STUDENT_EXEMPT_REASON: remote['exempt_reason'],
          COL_SYNC_UPDATED_AT: updatedAt,
          COL_SYNC_REMOTE_ID: remote['id'],
        };
      case TABLE_ATTENDANCE:
        final studentRemoteId = remote['student_remote_id'] as String?;
        final localStudentId = studentRemoteId != null
            ? await _localIdForRemote(
                TABLE_STUDENTS, COL_STUDENT_ID, studentRemoteId,
                executor: executor)
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
                TABLE_STUDENTS, COL_STUDENT_ID, studentRemoteId,
                executor: executor)
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
      case TABLE_HOMEWORK:
        final studentRemoteId = remote['student_remote_id'] as String?;
        final localStudentId = studentRemoteId != null
            ? await _localIdForRemote(
                TABLE_STUDENTS, COL_STUDENT_ID, studentRemoteId,
                executor: executor)
            : null;
        if (studentRemoteId != null && localStudentId == null) return null;
        return {
          COL_HOMEWORK_STUDENT_ID: localStudentId,
          COL_HOMEWORK_DATE: remote['date'],
          COL_HOMEWORK_STATUS: remote['status'],
          COL_SYNC_UPDATED_AT: updatedAt,
          COL_SYNC_REMOTE_ID: remote['id'],
        };
    }
    return null;
  }
}

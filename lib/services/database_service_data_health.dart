part of 'database_service.dart';

// spec 052 — طبقة قاعدة البيانات لأداة "صحة البيانات": عدّادات مجمّعة،
// تحميل صفوف الطلاب/المجموعات للخطة، وتنفيذ خطة الدمج ذرّيًا + طابور المزامنة.
// (extension داخل نفس الـlibrary عشان توصل لـ_queueSync/_queueDelete الخاصة.)

class _MergeTbl {
  final String table;
  final String pk;
  final String ownerCol; // عمود الطالب/المجموعة
  final bool synced;
  final String? Function(Map<String, Object?> row)? key;
  final String? Function(Map<String, Object?> row)? status;
  const _MergeTbl(this.table, this.pk, this.ownerCol,
      {this.synced = true, this.key, this.status});
}

String _dayOf(Object? v) {
  final s = (v ?? '').toString();
  return s.length >= 10 ? s.substring(0, 10) : s;
}

final Map<String, _MergeTbl> _kStudentMergeTables = {
  'attendance': _MergeTbl(
      TABLE_ATTENDANCE, COL_ATTENDANCE_ID, COL_ATTENDANCE_STUDENT_ID,
      key: (r) => _dayOf(r[COL_ATTENDANCE_DATE]),
      status: (r) => r[COL_ATTENDANCE_STATUS]?.toString()),
  'homework': _MergeTbl(
      TABLE_HOMEWORK, COL_HOMEWORK_ID, COL_HOMEWORK_STUDENT_ID,
      key: (r) => _dayOf(r[COL_HOMEWORK_DATE])),
  'payments': _MergeTbl(TABLE_PAYMENTS, COL_PAYMENT_ID, COL_PAYMENT_STUDENT_ID,
      key: (r) => '${r[COL_PAYMENT_DATE]}|${r[COL_PAYMENT_AMOUNT]}'),
  'exam_grades': _MergeTbl(
      TABLE_EXAM_GRADES, COL_GRADE_ID, COL_GRADE_STUDENT_ID,
      key: (r) => '${r[COL_GRADE_EXAM_ID]}'),
  'exam_submissions': _MergeTbl(
      TABLE_EXAM_SUBMISSIONS, COL_ES_ID, COL_ES_STUDENT_ID,
      key: (r) => '${r[COL_ES_EXAM_ID]}'),
  'booklet_records': _MergeTbl(
      TABLE_BOOKLET_RECORDS, COL_BR_ID, COL_BR_STUDENT_ID,
      key: (r) => '${r[COL_BR_BOOKLET_ID]}'),
  'booklet_payments': _MergeTbl(
      TABLE_BOOKLET_PAYMENTS, COL_BP_ID, COL_BP_STUDENT_ID,
      key: (r) =>
          '${r[COL_BP_BOOKLET_ID]}|${r[COL_BP_DATE]}|${r[COL_BP_AMOUNT]}'),
  'student_follow_ups':
      _MergeTbl(TABLE_STUDENT_FOLLOW_UPS, COL_SFU_ID, COL_SFU_STUDENT_ID),
  'student_archive_events': _MergeTbl(
      TABLE_STUDENT_ARCHIVE_EVENTS, COL_SAE_ID, COL_SAE_STUDENT_ID,
      key: (r) => '${r[COL_SAE_TYPE]}|${r[COL_SAE_EVENT_AT]}'),
  'report_logs': _MergeTbl(
      TABLE_REPORT_LOGS, COL_REPORT_ID, COL_REPORT_STUDENT_ID,
      synced: false),
};

final Map<String, _MergeTbl> _kGroupMergeTables = {
  'exam_groups': _MergeTbl(TABLE_EXAM_GROUPS, COL_EG_ID, COL_EG_GROUP_ID,
      key: (r) => '${r[COL_EG_EXAM_ID]}'),
  'booklet_groups': _MergeTbl(TABLE_BOOKLET_GROUPS, COL_BG_ID, COL_BG_GROUP_ID,
      key: (r) => '${r[COL_BG_BOOKLET_ID]}'),
  'session_overrides':
      _MergeTbl(TABLE_SESSION_OVERRIDES, COL_SO_ID, COL_SO_GROUP_ID),
};

Iterable<List<T>> _chunksOf<T>(List<T> l, [int n = 400]) sync* {
  for (var i = 0; i < l.length; i += n) {
    yield l.sublist(i, i + n > l.length ? l.length : i + n);
  }
}

String _ph(int n) => List.filled(n, '?').join(',');

/// نتيجة تنفيذ الخطة.
class MergeApplyResult {
  final int studentsMerged;
  final int groupsMerged;
  final int studentsMovedToGroup;
  final Map<String, int> moved;
  final Map<String, int> dropped;
  const MergeApplyResult({
    required this.studentsMerged,
    required this.groupsMerged,
    required this.studentsMovedToGroup,
    required this.moved,
    required this.dropped,
  });
}

extension DataHealthDb on DatabaseService {
  /// مجموع سجلات كل طالب (حضور + دفعات + واجب + ...) بعدّات GROUP BY.
  Future<Map<int, int>> studentRecordCounts() async {
    final db = await database;
    final out = <int, int>{};
    for (final t in _kStudentMergeTables.values) {
      final rows = await db.rawQuery(
          'SELECT ${t.ownerCol} AS sid, COUNT(*) AS c FROM ${t.table} '
          'GROUP BY ${t.ownerCol}');
      for (final r in rows) {
        final sid = r['sid'] as int?;
        if (sid == null) continue;
        out[sid] = (out[sid] ?? 0) + (r['c'] as int? ?? 0);
      }
    }
    return out;
  }

  /// عدد طلاب كل مجموعة.
  Future<Map<int, int>> groupStudentCounts() async {
    final db = await database;
    final rows =
        await db.rawQuery('SELECT $COL_STUDENT_GROUP_ID AS gid, COUNT(*) AS c '
            'FROM $TABLE_STUDENTS GROUP BY $COL_STUDENT_GROUP_ID');
    return {for (final r in rows) r['gid'] as int: r['c'] as int};
  }

  /// عدد عمليات المزامنة المعلّقة (outbox).
  Future<int> pendingOutboxCount() async {
    final db = await database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $TABLE_SYNC_OUTBOX WHERE $COL_OUTBOX_SYNCED = 0');
    return (r.first['c'] as int?) ?? 0;
  }

  /// هل الطالب/المجموعة متزامنين (عندهم remote_id)؟ (وضع الفريق).
  Future<bool> hasRemoteId(String table, String pk, int id) async {
    final db = await database;
    final rid = await _remoteIdOf(db, table, pk, id);
    return rid != null && rid.isNotEmpty;
  }

  /// صفوف الطلاب المعنيين مجمّعة بالجدول مع مفاتيحها الطبيعية.
  Future<Map<int, StudentRows>> loadStudentRows(Iterable<int> ids) async {
    final db = await database;
    final list = ids.toSet().toList();
    final byStudent = <int, Map<String, List<RowRef>>>{
      for (final id in list) id: <String, List<RowRef>>{}
    };
    final remote = <int, String?>{};
    for (final chunk in _chunksOf(list)) {
      final srows = await db.query(TABLE_STUDENTS,
          columns: [COL_STUDENT_ID, COL_SYNC_REMOTE_ID],
          where: '$COL_STUDENT_ID IN (${_ph(chunk.length)})',
          whereArgs: chunk);
      for (final r in srows) {
        remote[r[COL_STUDENT_ID] as int] = r[COL_SYNC_REMOTE_ID] as String?;
      }
      for (final e in _kStudentMergeTables.entries) {
        final t = e.value;
        final rows = await db.query(t.table,
            where: '${t.ownerCol} IN (${_ph(chunk.length)})', whereArgs: chunk);
        for (final r in rows) {
          final sid = r[t.ownerCol] as int?;
          if (sid == null) continue;
          byStudent[sid]!.putIfAbsent(e.key, () => []).add(RowRef(
                id: r[t.pk] as int,
                remoteId: t.synced ? r[COL_SYNC_REMOTE_ID] as String? : null,
                key: t.key?.call(r),
                status: t.status?.call(r),
                updatedAt: DateTime.tryParse(
                    (r[COL_SYNC_UPDATED_AT] ?? '').toString()),
              ));
        }
      }
    }
    return {
      for (final id in list)
        id: StudentRows(
            studentId: id, remoteId: remote[id], byTable: byStudent[id]!)
    };
  }

  /// بيانات مجموعات (طلابها + صفوف جداولها) للدمج.
  Future<Map<int, GroupRows>> loadGroupRows(Iterable<int> ids) async {
    final db = await database;
    final out = <int, GroupRows>{};
    for (final gid in ids.toSet()) {
      final remoteId = await _remoteIdOf(db, TABLE_GROUPS, COL_GROUP_ID, gid);
      final srows = await db.query(TABLE_STUDENTS,
          columns: [COL_STUDENT_ID, COL_STUDENT_NAME, COL_SYNC_REMOTE_ID],
          where: '$COL_STUDENT_GROUP_ID = ?',
          whereArgs: [gid]);
      final students = [
        for (final r in srows)
          StudentBrief(
              id: r[COL_STUDENT_ID] as int,
              name: (r[COL_STUDENT_NAME] ?? '').toString(),
              remoteId: r[COL_SYNC_REMOTE_ID] as String?)
      ];
      final byTable = <String, List<RowRef>>{};
      for (final e in _kGroupMergeTables.entries) {
        final t = e.value;
        final rows = await db
            .query(t.table, where: '${t.ownerCol} = ?', whereArgs: [gid]);
        byTable[e.key] = [
          for (final r in rows)
            RowRef(
              id: r[t.pk] as int,
              remoteId: r[COL_SYNC_REMOTE_ID] as String?,
              key: t.key?.call(r),
              updatedAt:
                  DateTime.tryParse((r[COL_SYNC_UPDATED_AT] ?? '').toString()),
            )
        ];
      }
      out[gid] = GroupRows(
          groupId: gid,
          remoteId: remoteId,
          students: students,
          byTable: byTable);
    }
    return out;
  }

  /// ينفّذ [plan] ذرّيًا: (1) transaction محلية، (2) طابور مزامنة بالترتيب:
  /// تحديثات النقل ← حذف الصفوف المكرّرة ← حذف الطلاب ← تحديثات المجموعة ←
  /// حذف المجموعة. أي استثناء داخل الـtransaction = rollback كامل.
  Future<MergeApplyResult> applyMergePlan(MergePlan plan) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // حماية أخيرة قبل أي تعديل: الأساسي مش ممكن يبقى مكرّر ولا يكون ناقص.
    final canonIds = {for (final p in plan.students) p.canonicalId};
    final dupIds = {for (final p in plan.students) p.duplicateId};
    if (canonIds.intersection(dupIds).isNotEmpty) {
      throw StateError('خطة دمج غير صالحة: طالب أساسي ومكرّر في نفس الوقت');
    }
    for (final chunk in _chunksOf(canonIds.toList())) {
      final r = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM $TABLE_STUDENTS '
          'WHERE $COL_STUDENT_ID IN (${_ph(chunk.length)})',
          chunk);
      if ((r.first['c'] as int? ?? 0) != chunk.length) {
        throw StateError('خطة دمج غير صالحة: طالب أساسي غير موجود');
      }
    }
    final canonGroups = {for (final g in plan.groups) g.canonicalGroupId};
    final dupGroups = {for (final g in plan.groups) g.duplicateGroupId};
    if (canonGroups.intersection(dupGroups).isNotEmpty) {
      throw StateError('خطة دمج غير صالحة: مجموعة أساسية ومكرّرة معًا');
    }

    // قبل أي تعديل: remote ids للطلاب/المجموعات المكرّرة + مجموعة الإخوة.
    final dupStudentIds = [for (final p in plan.students) p.duplicateId];
    final remoteOf = <int, String?>{};
    final siblingOf = <int, int?>{};
    for (final chunk in _chunksOf(dupStudentIds)) {
      final rows = await db.query(TABLE_STUDENTS,
          columns: [
            COL_STUDENT_ID,
            COL_SYNC_REMOTE_ID,
            COL_STUDENT_SIBLING_GROUP_ID
          ],
          where: '$COL_STUDENT_ID IN (${_ph(chunk.length)})',
          whereArgs: chunk);
      for (final r in rows) {
        final id = r[COL_STUDENT_ID] as int;
        remoteOf[id] = r[COL_SYNC_REMOTE_ID] as String?;
        siblingOf[id] = r[COL_STUDENT_SIBLING_GROUP_ID] as int?;
      }
    }

    // الصفوف المنقولة (للـupsert بعد الـcommit) والمحذوفة (للـdelete).
    final movedRows = <({String table, String pk, int id})>[];
    final droppedRows = <({String table, int id, String? remoteId})>[];

    await db.transaction((txn) async {
      // ── طلاب ──
      for (final p in plan.students) {
        for (final e in p.moves.entries) {
          final t = _kStudentMergeTables[e.key];
          if (t == null) continue;
          for (final chunk in _chunksOf(e.value.map((r) => r.id).toList())) {
            await txn.update(
              t.table,
              {
                t.ownerCol: p.canonicalId,
                if (t.synced) COL_SYNC_UPDATED_AT: now,
              },
              where: '${t.pk} IN (${_ph(chunk.length)})',
              whereArgs: chunk,
            );
          }
          if (t.synced) {
            for (final r in e.value) {
              movedRows.add((table: t.table, pk: t.pk, id: r.id));
            }
          }
        }
        for (final e in p.drops.entries) {
          final t = _kStudentMergeTables[e.key];
          if (t == null) continue;
          for (final chunk in _chunksOf(e.value.map((r) => r.id).toList())) {
            await txn.delete(
              t.table,
              where: '${t.pk} IN (${_ph(chunk.length)})',
              whereArgs: chunk,
            );
          }
          if (t.synced) {
            for (final r in e.value) {
              droppedRows.add((table: t.table, id: r.id, remoteId: r.remoteId));
            }
          }
        }
        await txn.delete(TABLE_STUDENTS,
            where: '$COL_STUDENT_ID = ?', whereArgs: [p.duplicateId]);
      }

      // ── مجموعات ──
      for (final g in plan.groups) {
        for (final chunk in _chunksOf(g.studentsToMove)) {
          await txn.update(
            TABLE_STUDENTS,
            {
              COL_STUDENT_GROUP_ID: g.canonicalGroupId,
              COL_SYNC_UPDATED_AT: now,
            },
            where: '$COL_STUDENT_ID IN (${_ph(chunk.length)})',
            whereArgs: chunk,
          );
        }
        for (final e in g.moves.entries) {
          final t = _kGroupMergeTables[e.key];
          if (t == null) continue;
          for (final chunk in _chunksOf(e.value.map((r) => r.id).toList())) {
            await txn.update(
              t.table,
              {t.ownerCol: g.canonicalGroupId, COL_SYNC_UPDATED_AT: now},
              where: '${t.pk} IN (${_ph(chunk.length)})',
              whereArgs: chunk,
            );
          }
          for (final r in e.value) {
            movedRows.add((table: t.table, pk: t.pk, id: r.id));
          }
        }
        for (final e in g.drops.entries) {
          final t = _kGroupMergeTables[e.key];
          if (t == null) continue;
          for (final chunk in _chunksOf(e.value.map((r) => r.id).toList())) {
            await txn.delete(
              t.table,
              where: '${t.pk} IN (${_ph(chunk.length)})',
              whereArgs: chunk,
            );
          }
          for (final r in e.value) {
            droppedRows.add((table: t.table, id: r.id, remoteId: r.remoteId));
          }
        }
        // أي طالب وصل في الأثناء (ما كانش في الخطة) ما يتحذفش بالـCASCADE.
        await txn.update(
          TABLE_STUDENTS,
          {COL_STUDENT_GROUP_ID: g.canonicalGroupId, COL_SYNC_UPDATED_AT: now},
          where: '$COL_STUDENT_GROUP_ID = ?',
          whereArgs: [g.duplicateGroupId],
        );
        await txn.delete(TABLE_GROUPS,
            where: '$COL_GROUP_ID = ?', whereArgs: [g.duplicateGroupId]);
      }
    });
    _notifyChanged();

    // ── طابور المزامنة (بعد الـcommit) بالترتيب ──
    for (final m in movedRows) {
      await _queueRowUpsert(m.table, m.pk, m.id);
    }
    for (final d in droppedRows) {
      await _queueDelete(d.table, d.id, d.remoteId);
    }
    for (final p in plan.students) {
      await _queueDelete(
          TABLE_STUDENTS, p.duplicateId, remoteOf[p.duplicateId]);
    }
    for (final g in plan.groups) {
      for (final id in g.studentsToMove) {
        await _queueRowUpsert(TABLE_STUDENTS, COL_STUDENT_ID, id);
      }
      final rid = g.duplicateRemoteId ??
          await _remoteIdOf(db, TABLE_GROUPS, COL_GROUP_ID, g.duplicateGroupId);
      await _queueDelete(TABLE_GROUPS, g.duplicateGroupId, rid);
    }
    // لو مكرّر كان في مجموعة إخوة، نفكّ الناجي الوحيد (زي deleteStudent).
    final seenSibling = <int>{};
    for (final p in plan.students) {
      final sg = siblingOf[p.duplicateId];
      if (sg != null && seenSibling.add(sg)) {
        await _unlinkOrphanedSiblingSurvivor(sg);
      }
    }

    return MergeApplyResult(
      studentsMerged: plan.summary.studentsMerged,
      groupsMerged: plan.summary.groupsMerged,
      studentsMovedToGroup: plan.summary.studentsMovedToGroup,
      moved: plan.summary.moved,
      dropped: plan.summary.dropped,
    );
  }
}

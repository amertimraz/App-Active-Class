// lib/services/data_health_service.dart
//
// spec 052 — "صحة البيانات": فحص التكرار (قراءة فقط)، بناء الخطة، والتنفيذ
// الذرّي بنسخة احتياطية إجبارية + سجل العمليات. المنطق الصرف في
// utils/duplicate_detection.dart وutils/merge_plan.dart.
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:active_class/config/constants.dart';
import 'package:active_class/services/backup_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/duplicate_detection.dart';
import 'package:active_class/utils/merge_plan.dart';

/// نتيجة الفحص.
class ScanResult {
  final List<DuplicateCase> groupCases;
  final List<DuplicateCase> studentCases;
  final int groupsScanned;
  final int studentsScanned;
  final DateTime at;

  /// اسم المجموعة لكل id (للعرض).
  final Map<int, String> groupNames;
  const ScanResult({
    required this.groupCases,
    required this.studentCases,
    required this.groupsScanned,
    required this.studentsScanned,
    required this.at,
    required this.groupNames,
  });

  bool get isClean => groupCases.isEmpty && studentCases.isEmpty;
}

/// سبب منع التنفيذ.
enum MergeBlock { notOwner, notSynced, pendingSync, empty }

sealed class MergeOutcome {
  const MergeOutcome();
}

class MergeSuccess extends MergeOutcome {
  final MergeApplyResult result;
  final String? backupPath;
  const MergeSuccess(this.result, this.backupPath);
}

class MergeBlocked extends MergeOutcome {
  final MergeBlock reason;
  final int pending;
  const MergeBlocked(this.reason, {this.pending = 0});
}

class MergeBackupFailed extends MergeOutcome {
  final String? error;
  const MergeBackupFailed(this.error);
}

class MergeFailed extends MergeOutcome {
  final Object error;
  const MergeFailed(this.error);
}

/// سطر في سجل العمليات (محلي).
class MergeLogEntry {
  final DateTime at;
  final int studentsMerged;
  final int groupsMerged;
  final int studentsMovedToGroup;
  final Map<String, int> moved;
  final Map<String, int> dropped;
  final String? backupPath;
  final List<String> items;
  const MergeLogEntry({
    required this.at,
    required this.studentsMerged,
    required this.groupsMerged,
    required this.studentsMovedToGroup,
    required this.moved,
    required this.dropped,
    this.backupPath,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'studentsMerged': studentsMerged,
        'groupsMerged': groupsMerged,
        'studentsMovedToGroup': studentsMovedToGroup,
        'moved': moved,
        'dropped': dropped,
        'backupPath': backupPath,
        'items': items,
      };

  static MergeLogEntry fromJson(Map<String, dynamic> j) => MergeLogEntry(
        at: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
        studentsMerged: (j['studentsMerged'] as num?)?.toInt() ?? 0,
        groupsMerged: (j['groupsMerged'] as num?)?.toInt() ?? 0,
        studentsMovedToGroup: (j['studentsMovedToGroup'] as num?)?.toInt() ?? 0,
        moved: {
          for (final e in ((j['moved'] as Map?) ?? {}).entries)
            '${e.key}': (e.value as num).toInt()
        },
        dropped: {
          for (final e in ((j['dropped'] as Map?) ?? {}).entries)
            '${e.key}': (e.value as num).toInt()
        },
        backupPath: j['backupPath'] as String?,
        items: [for (final i in (j['items'] as List? ?? [])) '$i'],
      );
}

/// أسماء الجداول بالعربي للتقرير.
const Map<String, String> kMergeTableLabels = {
  'attendance': 'حضور',
  'homework': 'واجب',
  'payments': 'دفعات',
  'exam_grades': 'درجات امتحانات',
  'exam_submissions': 'تسليمات امتحان إلكتروني',
  'booklet_records': 'ملازم',
  'booklet_payments': 'دفعات ملازم',
  'student_follow_ups': 'متابعات',
  'student_archive_events': 'سجل أرشفة',
  'report_logs': 'سجل تقارير',
  'exam_groups': 'ربط امتحانات',
  'booklet_groups': 'ربط ملازم',
  'session_overrides': 'حصص مستثناة',
};

class DataHealthService {
  static const String _kLogKey = 'data_health_log';
  static const int _kLogMax = 20;

  final DatabaseService _db = DatabaseService();

  /// فحص التكرار (قراءة فقط).
  Future<ScanResult> scan() async {
    final groups = await _db.getAllGroups();
    final students = await _db.getAllStudents();
    final counts = await _db.studentRecordCounts();

    final groupStudentCount = <int, int>{};
    final groupRecordCount = <int, int>{};
    for (final s in students) {
      groupStudentCount[s.groupId] = (groupStudentCount[s.groupId] ?? 0) + 1;
      groupRecordCount[s.groupId] =
          (groupRecordCount[s.groupId] ?? 0) + (counts[s.id] ?? 0);
    }

    final groupInputs = [
      for (final g in groups)
        if (g.id != null)
          DupGroupInput(
            id: g.id!,
            name: g.name,
            createdAt: g.createdAt,
            studentCount: groupStudentCount[g.id!] ?? 0,
            recordCount: groupRecordCount[g.id!] ?? 0,
          )
    ];
    final clusters = groupClusterKeys(groupInputs);

    final studentInputs = [
      for (final s in students)
        if (s.id != null)
          DupStudentInput(
            id: s.id!,
            name: s.name,
            code: s.code,
            groupId: s.groupId,
            guardianPhone: s.guardianPhone,
            createdAt: s.createdAt,
            isArchived: s.isArchived,
            siblingGroupId: s.siblingGroupId,
            recordCount: counts[s.id!] ?? 0,
          )
    ];

    return ScanResult(
      groupCases: detectGroupDuplicates(groupInputs),
      studentCases:
          detectStudentDuplicates(studentInputs, groupClusters: clusters),
      groupsScanned: groupInputs.length,
      studentsScanned: studentInputs.length,
      at: DateTime.now(),
      groupNames: {
        for (final g in groups)
          if (g.id != null) g.id!: g.name
      },
    );
  }

  /// يبني الخطة من الحالات المحدّدة (كل حالة بأساسيها الحالي).
  Future<MergePlan> buildPlan({
    required List<DuplicateCase> groupCases,
    required List<DuplicateCase> studentCases,
  }) async {
    final groupRequests = <GroupMergeRequest>[
      for (final c in groupCases)
        for (final d in c.duplicateIds) GroupMergeRequest(c.canonicalId, d)
    ];
    final studentRequests = <StudentMergeRequest>[
      for (final c in studentCases)
        StudentMergeRequest(c.canonicalId, c.duplicateIds)
    ];

    final groupIds = <int>{
      for (final r in groupRequests) ...[r.canonicalGroupId, r.duplicateGroupId]
    };
    final groupRows = groupIds.isEmpty
        ? <int, GroupRows>{}
        : await _db.loadGroupRows(groupIds);

    final studentIds = <int>{
      for (final r in studentRequests) ...[r.canonicalId, ...r.duplicateIds],
      for (final g in groupRows.values) ...g.students.map((s) => s.id),
    };
    final studentRows = studentIds.isEmpty
        ? <int, StudentRows>{}
        : await _db.loadStudentRows(studentIds);

    return buildMergePlan(
      studentRequests: studentRequests,
      groupRequests: groupRequests,
      studentRows: studentRows,
      groupRows: groupRows,
    );
  }

  /// فحص الشروط المسبقة. null = مسموح.
  Future<MergeBlocked?> preflight(MergePlan plan,
      {bool ignorePending = false}) async {
    if (plan.isEmpty) return const MergeBlocked(MergeBlock.empty);
    final team = TeamModeService();
    if (!team.isEnabled.value) return null;
    if (!team.isOwner.value) return const MergeBlocked(MergeBlock.notOwner);

    // الأساسي لازم يكون متزامن (وإلا الـpush بيتخطّى تحديثات النقل).
    for (final p in plan.students) {
      if (!await _db.hasRemoteId(
          TABLE_STUDENTS, COL_STUDENT_ID, p.canonicalId)) {
        return const MergeBlocked(MergeBlock.notSynced);
      }
    }
    for (final g in plan.groups) {
      if (!await _db.hasRemoteId(
          TABLE_GROUPS, COL_GROUP_ID, g.canonicalGroupId)) {
        return const MergeBlocked(MergeBlock.notSynced);
      }
    }
    final pending = await _db.pendingOutboxCount();
    if (pending > 0 && !ignorePending) {
      return MergeBlocked(MergeBlock.pendingSync, pending: pending);
    }
    return null;
  }

  /// ينفّذ الخطة: preflight ← نسخة احتياطية إجبارية ← تنفيذ ذرّي ← سجل.
  Future<MergeOutcome> execute(
    MergePlan plan, {
    bool ignorePending = false,
    List<String> itemLabels = const [],
  }) async {
    final blocked = await preflight(plan, ignorePending: ignorePending);
    if (blocked != null) return blocked;

    final backup = await BackupService().createBackup();
    if (!backup.success) return MergeBackupFailed(backup.error);

    try {
      final result = await _db.applyMergePlan(plan);
      await _appendLog(MergeLogEntry(
        at: DateTime.now(),
        studentsMerged: result.studentsMerged,
        groupsMerged: result.groupsMerged,
        studentsMovedToGroup: result.studentsMovedToGroup,
        moved: result.moved,
        dropped: result.dropped,
        backupPath: backup.localPath,
        items: itemLabels,
      ));
      return MergeSuccess(result, backup.localPath);
    } catch (e) {
      debugPrint('DataHealthService: فشل الدمج — $e');
      return MergeFailed(e);
    }
  }

  Future<List<MergeLogEntry>> history() async {
    try {
      final raw = await _db.getSetting(_kLogKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          MergeLogEntry.fromJson(Map<String, dynamic>.from(e as Map))
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _appendLog(MergeLogEntry e) async {
    try {
      final cur = await history();
      final next = [e, ...cur].take(_kLogMax).map((x) => x.toJson()).toList();
      await _db.setSetting(_kLogKey, jsonEncode(next));
    } catch (_) {}
  }

  /// نص ملخص قابل للمشاركة.
  static String summaryText(MergeLogEntry e,
      {Map<String, String> labels = kMergeTableLabels}) {
    final b = StringBuffer()
      ..writeln('تقرير دمج المكرّر — Active Class')
      ..writeln(
          'التاريخ: ${e.at.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}')
      ..writeln('اتدمج: ${e.studentsMerged} طالب، ${e.groupsMerged} مجموعة');
    if (e.studentsMovedToGroup > 0) {
      b.writeln('اتنقل للمجموعة الأساسية: ${e.studentsMovedToGroup} طالب');
    }
    if (e.moved.isNotEmpty) {
      b.writeln(
          'اتنقل: ${e.moved.entries.map((x) => '${labels[x.key] ?? x.key} ${x.value}').join('، ')}');
    }
    if (e.dropped.isNotEmpty) {
      b.writeln(
          'اتشال (مكرّر): ${e.dropped.entries.map((x) => '${labels[x.key] ?? x.key} ${x.value}').join('، ')}');
    }
    for (final i in e.items) {
      b.writeln('• $i');
    }
    if (e.backupPath != null) b.writeln('النسخة الاحتياطية: ${e.backupPath}');
    return b.toString();
  }
}

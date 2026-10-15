// lib/utils/merge_plan.dart
//
// spec 052 — خطة دمج الطلاب/المجموعات المكرّرة (دوال صرفة بلا GetX/DB).
// المعاينة والتنفيذ بيستخدموا نفس الخطة (SC-002). القواعد مطابقة لسكربت
// تنظيف Grade 2 (راجع specs/052-data-health-merge/contracts/merge-rules.md):
//  • الأساسي بيكسب: لو عنده سجل بنفس المفتاح الطبيعي، سجل المكرّر بيتشال.
//  • غير كده: سجل المكرّر بيتنقل للأساسي.
//  • لو المكرّر نفسه عنده أكتر من سجل بنفس المفتاح: الأحدث بس بيفضل.
import 'package:active_class/utils/arabic_normalize.dart';

/// جداول بيانات الطالب اللي بتتنقل/بتتدمج عند دمج طالب مكرّر.
const List<String> kStudentChildTables = [
  'attendance',
  'homework',
  'payments',
  'exam_grades',
  'exam_submissions',
  'booklet_records',
  'booklet_payments',
  'student_follow_ups',
  'student_archive_events',
  'report_logs',
];

/// جداول المجموعة اللي بتتنقل عند دمج مجموعة مكرّرة.
const List<String> kGroupChildTables = [
  'exam_groups',
  'booklet_groups',
  'session_overrides',
];

/// مرجع صف (حضور/دفعة/...) بمفتاحه الطبيعي.
class RowRef {
  final int id;
  final String? remoteId;

  /// المفتاح الطبيعي (يوم/تاريخ|مبلغ/امتحان...) — null = بيتنقل دايمًا.
  final String? key;

  /// للحضور: الحالة (لعدّ التعارض).
  final String? status;
  final DateTime? updatedAt;
  const RowRef({
    required this.id,
    this.remoteId,
    this.key,
    this.status,
    this.updatedAt,
  });
}

/// صفوف طالب مجمّعة بالجدول.
class StudentRows {
  final int studentId;
  final String? remoteId;
  final Map<String, List<RowRef>> byTable;
  const StudentRows({
    required this.studentId,
    this.remoteId,
    this.byTable = const {},
  });
}

class StudentBrief {
  final int id;
  final String name;
  final String? remoteId;
  const StudentBrief({required this.id, required this.name, this.remoteId});
}

/// بيانات مجموعة للدمج: طلابها + صفوف جداولها.
class GroupRows {
  final int groupId;
  final String? remoteId;
  final List<StudentBrief> students;
  final Map<String, List<RowRef>> byTable;
  const GroupRows({
    required this.groupId,
    this.remoteId,
    this.students = const [],
    this.byTable = const {},
  });
}

class StudentMergeRequest {
  final int canonicalId;
  final List<int> duplicateIds;
  const StudentMergeRequest(this.canonicalId, this.duplicateIds);
}

class GroupMergeRequest {
  final int canonicalGroupId;
  final int duplicateGroupId;
  const GroupMergeRequest(this.canonicalGroupId, this.duplicateGroupId);
}

class AttendanceConflict {
  final int rowId;
  final String key;
  final String? duplicateStatus;
  final String? canonicalStatus;
  const AttendanceConflict(
      this.rowId, this.key, this.duplicateStatus, this.canonicalStatus);
}

/// خطة دمج طالب مكرّر واحد في الأساسي.
class StudentMergePlan {
  final int canonicalId;
  final int duplicateId;
  final String? duplicateRemoteId;
  final Map<String, List<RowRef>> moves;
  final Map<String, List<RowRef>> drops;
  final List<AttendanceConflict> conflicts;
  const StudentMergePlan({
    required this.canonicalId,
    required this.duplicateId,
    this.duplicateRemoteId,
    required this.moves,
    required this.drops,
    required this.conflicts,
  });
}

/// خطة دمج مجموعة مكرّرة في الأساسية.
class GroupMergePlan {
  final int canonicalGroupId;
  final int duplicateGroupId;
  final String? duplicateRemoteId;

  /// طلاب المجموعة المكرّرة اللي مالهمش مقابل → بيتنقلوا للأساسية.
  final List<int> studentsToMove;

  /// (طالب مكرّر ← أساسي) المتطابقين بالاسم — بيتدمجوا بقواعد الطلاب.
  final Map<int, int> matchedStudents;
  final Map<String, List<RowRef>> moves;
  final Map<String, List<RowRef>> drops;
  const GroupMergePlan({
    required this.canonicalGroupId,
    required this.duplicateGroupId,
    this.duplicateRemoteId,
    required this.studentsToMove,
    required this.matchedStudents,
    required this.moves,
    required this.drops,
  });
}

class MergeSummary {
  final int studentsMerged;
  final int groupsMerged;
  final int studentsMovedToGroup;
  final Map<String, int> moved;
  final Map<String, int> dropped;
  final int conflicts;
  const MergeSummary({
    required this.studentsMerged,
    required this.groupsMerged,
    required this.studentsMovedToGroup,
    required this.moved,
    required this.dropped,
    required this.conflicts,
  });

  int get totalMoved => moved.values.fold(0, (a, b) => a + b);
  int get totalDropped => dropped.values.fold(0, (a, b) => a + b);
}

class MergePlan {
  final List<StudentMergePlan> students;
  final List<GroupMergePlan> groups;
  final MergeSummary summary;
  const MergePlan(
      {required this.students, required this.groups, required this.summary});

  bool get isEmpty => students.isEmpty && groups.isEmpty;
}

int _byUpdatedDesc(RowRef a, RowRef b) {
  final x = a.updatedAt, y = b.updatedAt;
  if (x != null && y != null) {
    final c = y.compareTo(x);
    if (c != 0) return c;
  } else if (x != null) {
    return -1;
  } else if (y != null) {
    return 1;
  }
  return b.id.compareTo(a.id);
}

/// خطط دمج مجموعة نسخ مكرّرة في طالب أساسي. [taken] بتتراكم عبر النسخ.
List<StudentMergePlan> _planForCanonical(
    StudentRows canonical, List<StudentRows> duplicates) {
  // مفاتيح الأساسي لكل جدول (+ حالة الحضور).
  final taken = <String, Map<String, RowRef>>{};
  canonical.byTable.forEach((table, rows) {
    final m = <String, RowRef>{};
    for (final r in rows) {
      if (r.key != null) m[r.key!] = r;
    }
    taken[table] = m;
  });

  final out = <StudentMergePlan>[];
  for (final dup in duplicates) {
    final moves = <String, List<RowRef>>{};
    final drops = <String, List<RowRef>>{};
    final conflicts = <AttendanceConflict>[];

    dup.byTable.forEach((table, rows) {
      final t = taken.putIfAbsent(table, () => <String, RowRef>{});
      final sorted = [...rows]..sort(_byUpdatedDesc);
      for (final r in sorted) {
        if (r.key == null) {
          moves.putIfAbsent(table, () => []).add(r);
          continue;
        }
        final existing = t[r.key!];
        if (existing != null) {
          drops.putIfAbsent(table, () => []).add(r);
          if (table == 'attendance' &&
              (existing.status ?? '') != (r.status ?? '')) {
            conflicts.add(
                AttendanceConflict(r.id, r.key!, r.status, existing.status));
          }
        } else {
          moves.putIfAbsent(table, () => []).add(r);
          t[r.key!] = r;
        }
      }
    });

    out.add(StudentMergePlan(
      canonicalId: canonical.studentId,
      duplicateId: dup.studentId,
      duplicateRemoteId: dup.remoteId,
      moves: moves,
      drops: drops,
      conflicts: conflicts,
    ));
  }
  return out;
}

/// خطة دمج مجموعة مكرّرة (الطلاب المتطابقين بتتحسب بعدين كطلاب).
GroupMergePlan planGroupMerge(GroupRows canonical, GroupRows duplicate) {
  // طلاب الأساسية بالاسم المطبّع (أول واحد بالـid الأصغر).
  final byName = <String, StudentBrief>{};
  for (final s in [...canonical.students]
    ..sort((a, b) => a.id.compareTo(b.id))) {
    byName.putIfAbsent(normalizeArabic(s.name), () => s);
  }
  final matched = <int, int>{};
  final toMove = <int>[];
  for (final s in [...duplicate.students]
    ..sort((a, b) => a.id.compareTo(b.id))) {
    final k = normalizeArabic(s.name);
    final c = k.isEmpty ? null : byName[k];
    if (c != null) {
      matched[s.id] = c.id;
    } else {
      toMove.add(s.id);
    }
  }

  final moves = <String, List<RowRef>>{};
  final drops = <String, List<RowRef>>{};
  for (final table in kGroupChildTables) {
    final canonKeys = <String>{
      for (final r in canonical.byTable[table] ?? const <RowRef>[])
        if (r.key != null) r.key!
    };
    for (final r in duplicate.byTable[table] ?? const <RowRef>[]) {
      if (r.key != null && canonKeys.contains(r.key)) {
        drops.putIfAbsent(table, () => []).add(r);
      } else {
        moves.putIfAbsent(table, () => []).add(r);
        if (r.key != null) canonKeys.add(r.key!);
      }
    }
  }

  return GroupMergePlan(
    canonicalGroupId: canonical.groupId,
    duplicateGroupId: duplicate.groupId,
    duplicateRemoteId: duplicate.remoteId,
    studentsToMove: toMove,
    matchedStudents: matched,
    moves: moves,
    drops: drops,
  );
}

/// يبني الخطة الكاملة من الطلبات المحدّدة.
/// [studentRows]: id → صفوف الطالب (لكل الطلاب المعنيين)،
/// [groupRows]: id → بيانات المجموعة (للمجموعات المطلوب دمجها).
MergePlan buildMergePlan({
  List<StudentMergeRequest> studentRequests = const [],
  List<GroupMergeRequest> groupRequests = const [],
  required Map<int, StudentRows> studentRows,
  Map<int, GroupRows> groupRows = const {},
}) {
  // (1) الطلبات الصريحة للطلاب بتاخد أولوية (المدرس اختار الأساسي).
  final dupOf = <int, int>{}; // duplicateStudentId → canonicalStudentId
  final explicitCanon = <int>{};
  for (final req in studentRequests) {
    for (final d in req.duplicateIds) {
      if (d == req.canonicalId) continue;
      dupOf[d] = req.canonicalId;
    }
    explicitCanon.add(req.canonicalId);
  }

  // (2) مجموعات: التطابق بالاسم بيضيف أزواج دمج، لكن مش بيعكس اختيار صريح
  // (وإلا دوّارة أ↔ب ويتحذف الاتنين).
  final groupPlans = <GroupMergePlan>[];
  for (final req in groupRequests) {
    final c = groupRows[req.canonicalGroupId];
    final d = groupRows[req.duplicateGroupId];
    if (c == null || d == null || c.groupId == d.groupId) continue;
    final gp = planGroupMerge(c, d);
    final accepted = <int, int>{};
    final extraMove = <int>[];
    gp.matchedStudents.forEach((dup, canon) {
      if (dupOf.containsKey(dup)) return; // قرار صريح بيحسم مصيره
      if (explicitCanon.contains(dup)) {
        // طالب المجموعة المكرّرة هو الأساسي المختار → ينتقل بدل ما يتدمج.
        extraMove.add(dup);
        return;
      }
      accepted[dup] = canon;
      dupOf[dup] = canon;
    });
    groupPlans.add(GroupMergePlan(
      canonicalGroupId: gp.canonicalGroupId,
      duplicateGroupId: gp.duplicateGroupId,
      duplicateRemoteId: gp.duplicateRemoteId,
      studentsToMove: [...gp.studentsToMove, ...extraMove],
      matchedStudents: accepted,
      moves: gp.moves,
      drops: gp.drops,
    ));
  }

  // حلّ السلاسل (أ←ب←ج → أ←ج). أي دوّارة (قرارات متعارضة) بتتجاهل كلها —
  // ما نحذفش ولا طالب فيها (حماية من فقد بيانات).
  int? root(int id) {
    final seen = <int>{id};
    var cur = id;
    while (true) {
      final n = dupOf[cur];
      if (n == null) return cur;
      if (!seen.add(n)) return null; // دوّارة
      cur = n;
    }
  }

  final byCanonical = <int, List<int>>{};
  dupOf.forEach((dup, _) {
    final r = root(dup);
    if (r == null || r == dup) return; // دوّارة — تجاهل
    byCanonical.putIfAbsent(r, () => []).add(dup);
  });

  final studentPlans = <StudentMergePlan>[];
  byCanonical.forEach((canonId, dupIds) {
    final canon = studentRows[canonId] ?? StudentRows(studentId: canonId);
    final dups = [
      for (final id in (dupIds..sort()))
        studentRows[id] ?? StudentRows(studentId: id)
    ];
    studentPlans.addAll(_planForCanonical(canon, dups));
  });
  studentPlans.sort((a, b) => a.duplicateId.compareTo(b.duplicateId));

  // (3) ملخص.
  final moved = <String, int>{};
  final dropped = <String, int>{};
  var conflicts = 0;
  void add(Map<String, int> into, Map<String, List<RowRef>> m) {
    m.forEach((t, l) => into[t] = (into[t] ?? 0) + l.length);
  }

  for (final p in studentPlans) {
    add(moved, p.moves);
    add(dropped, p.drops);
    conflicts += p.conflicts.length;
  }
  for (final g in groupPlans) {
    add(moved, g.moves);
    add(dropped, g.drops);
  }
  final summary = MergeSummary(
    studentsMerged: studentPlans.length,
    groupsMerged: groupPlans.length,
    studentsMovedToGroup:
        groupPlans.fold(0, (a, g) => a + g.studentsToMove.length),
    moved: moved,
    dropped: dropped,
    conflicts: conflicts,
  );
  return MergePlan(
      students: studentPlans, groups: groupPlans, summary: summary);
}

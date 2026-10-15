// lib/utils/duplicate_detection.dart
//
// spec 052 — اكتشاف الطلاب والمجموعات المكرّرة (دوال صرفة بلا GetX/DB).
// الإدخال كائنات بسيطة (مش موديلات) عشان تتختبر مباشرة؛ الخدمة هي اللي
// بتحوّل بيانات الـDB لها.
import 'package:active_class/utils/arabic_normalize.dart';

enum DuplicateKind { group, student }

enum MatchReason {
  /// نفس الكود (بعد تشيل لاحقة -N) — محدّد تلقائيًا للدمج.
  sameCode,

  /// نفس الاسم المطبّع داخل نفس المجموعة أو مجموعتين مكرّرتين — يحتاج قرار.
  sameNameInGroup,

  /// مجموعتين بنفس الاسم المطبّع — محدّد تلقائيًا.
  sameGroupName,
}

/// مجموعة كما يراها الاكتشاف.
class DupGroupInput {
  final int id;
  final String name;
  final DateTime? createdAt;
  final int studentCount;
  final int recordCount;
  const DupGroupInput({
    required this.id,
    required this.name,
    this.createdAt,
    this.studentCount = 0,
    this.recordCount = 0,
  });
}

/// طالب كما يراه الاكتشاف.
class DupStudentInput {
  final int id;
  final String name;
  final String code;
  final int groupId;
  final String? guardianPhone;
  final DateTime? createdAt;
  final bool isArchived;
  final int? siblingGroupId;

  /// مجموع سجلاته (حضور + دفعات + واجب + درجات + أخرى).
  final int recordCount;
  const DupStudentInput({
    required this.id,
    required this.name,
    required this.code,
    required this.groupId,
    this.guardianPhone,
    this.createdAt,
    this.isArchived = false,
    this.siblingGroupId,
    this.recordCount = 0,
  });
}

/// نسخة مرشّحة داخل حالة تكرار.
class CandidateCopy {
  final int id;
  final String name;
  final String code;
  final int? groupId;
  final DateTime? createdAt;
  final bool isArchived;
  final bool suffixed;
  final int recordCount;
  final String? guardianPhone;
  const CandidateCopy({
    required this.id,
    required this.name,
    this.code = '',
    this.groupId,
    this.createdAt,
    this.isArchived = false,
    this.suffixed = false,
    this.recordCount = 0,
    this.guardianPhone,
  });
}

class DuplicateCase {
  final DuplicateKind kind;
  final MatchReason reason;
  final List<CandidateCopy> copies;
  final int canonicalId;

  /// محدّد للدمج افتراضيًا (الكود/اسم المجموعة: نعم، الاسم فقط: لا).
  final bool selectedByDefault;

  /// أرقام الهواتف مختلفة بوضوح (طالبين مختلفين على الأغلب) — للتنبيه فقط.
  final bool guardianMismatch;

  /// مفتاح مجموعة مكرّرة مرتبطة (طالب داخل مجموعة مكرّرة).
  final String? groupClusterKey;
  const DuplicateCase({
    required this.kind,
    required this.reason,
    required this.copies,
    required this.canonicalId,
    required this.selectedByDefault,
    this.guardianMismatch = false,
    this.groupClusterKey,
  });

  List<int> get duplicateIds =>
      copies.where((c) => c.id != canonicalId).map((c) => c.id).toList();

  /// نسخة بأساسي مختلف (اختيار المدرس).
  DuplicateCase withCanonical(int id) => DuplicateCase(
        kind: kind,
        reason: reason,
        copies: copies,
        canonicalId: id,
        selectedByDefault: selectedByDefault,
        guardianMismatch: guardianMismatch,
        groupClusterKey: groupClusterKey,
      );
}

/// تطبيع الاسم للمقارنة.
String normalizeName(String s) => normalizeArabic(s);

final RegExp _suffix = RegExp(r'-\d+$');

/// الكود بعد تشيل لاحقة `-N` (للمقارنة بس)، بحروف كبيرة.
String codeStem(String code) =>
    code.trim().toUpperCase().replaceFirst(_suffix, '');

bool _hasSuffix(String code) => _suffix.hasMatch(code.trim());

/// اختيار النسخة الأساسية: غير المؤرشف أولًا، ثم الأكتر بيانات، ثم الأقدم
/// إضافة، ثم اللي كودها بلا لاحقة، ثم الأصغر id (للثبات).
int pickCanonical(List<CandidateCopy> copies) {
  assert(copies.isNotEmpty);
  final sorted = [...copies]..sort((a, b) {
      if (a.isArchived != b.isArchived) return a.isArchived ? 1 : -1;
      final r = b.recordCount.compareTo(a.recordCount);
      if (r != 0) return r;
      final ad = a.createdAt, bd = b.createdAt;
      if (ad != null && bd != null) {
        final c = ad.compareTo(bd);
        if (c != 0) return c;
      } else if (ad != null) {
        return -1;
      } else if (bd != null) {
        return 1;
      }
      if (a.suffixed != b.suffixed) return a.suffixed ? 1 : -1;
      return a.id.compareTo(b.id);
    });
  return sorted.first.id;
}

/// مجموعات بنفس الاسم المطبّع (غير فاضي). كل مفتاح = حالة واحدة.
List<DuplicateCase> detectGroupDuplicates(List<DupGroupInput> groups) {
  final byName = <String, List<DupGroupInput>>{};
  for (final g in groups) {
    final k = normalizeName(g.name);
    if (k.isEmpty) continue;
    byName.putIfAbsent(k, () => []).add(g);
  }
  final out = <DuplicateCase>[];
  byName.forEach((k, list) {
    if (list.length < 2) return;
    final copies = [
      for (final g in list)
        CandidateCopy(
          id: g.id,
          name: g.name,
          createdAt: g.createdAt,
          recordCount: g.studentCount + g.recordCount,
        )
    ];
    out.add(DuplicateCase(
      kind: DuplicateKind.group,
      reason: MatchReason.sameGroupName,
      copies: copies,
      canonicalId: pickCanonical(copies),
      selectedByDefault: true,
      groupClusterKey: k,
    ));
  });
  out.sort((a, b) => a.copies.first.name.compareTo(b.copies.first.name));
  return out;
}

/// خريطة groupId → مفتاح العنقود (اسم مطبّع للمجموعات المكرّرة فقط).
Map<int, String> groupClusterKeys(List<DupGroupInput> groups) {
  final byName = <String, List<int>>{};
  for (final g in groups) {
    final k = normalizeName(g.name);
    if (k.isEmpty) continue;
    byName.putIfAbsent(k, () => []).add(g.id);
  }
  final out = <int, String>{};
  byName.forEach((k, ids) {
    if (ids.length < 2) return;
    for (final id in ids) {
      out[id] = k;
    }
  });
  return out;
}

CandidateCopy _copyOf(DupStudentInput s) => CandidateCopy(
      id: s.id,
      name: s.name,
      code: s.code,
      groupId: s.groupId,
      createdAt: s.createdAt,
      isArchived: s.isArchived,
      suffixed: _hasSuffix(s.code),
      recordCount: s.recordCount,
      guardianPhone: s.guardianPhone,
    );

bool _phonesDiffer(List<DupStudentInput> list) {
  final phones = list
      .map((s) => (s.guardianPhone ?? '').replaceAll(RegExp(r'\D'), ''))
      .where((p) => p.isNotEmpty)
      .toSet();
  return phones.length > 1;
}

/// طلاب مكرّرين: نفس الكود (بعد تشيل -N)، أو نفس الاسم المطبّع داخل نفس
/// المجموعة / مجموعتين مكرّرتين. الإخوة (أسماء مختلفة) مش بيتحسبوا تكرار.
List<DuplicateCase> detectStudentDuplicates(
  List<DupStudentInput> students, {
  Map<int, String> groupClusters = const {},
}) {
  final out = <DuplicateCase>[];

  // (1) نفس الكود.
  final byCode = <String, List<DupStudentInput>>{};
  for (final s in students) {
    final k = codeStem(s.code);
    if (k.isEmpty) continue;
    byCode.putIfAbsent(k, () => []).add(s);
  }
  final inCodeCluster = <int, String>{};
  byCode.forEach((k, list) {
    if (list.length < 2) return;
    for (final s in list) {
      inCodeCluster[s.id] = k;
    }
    final copies = list.map(_copyOf).toList();
    out.add(DuplicateCase(
      kind: DuplicateKind.student,
      reason: MatchReason.sameCode,
      copies: copies,
      canonicalId: pickCanonical(copies),
      selectedByDefault: true,
      groupClusterKey: _clusterOf(list, groupClusters),
    ));
  });

  // (2) نفس الاسم داخل نفس المجموعة / عنقود مجموعات مكرّرة.
  final byName = <String, List<DupStudentInput>>{};
  for (final s in students) {
    final n = normalizeName(s.name);
    if (n.isEmpty) continue;
    final scope = groupClusters[s.groupId] ?? 'g${s.groupId}';
    byName.putIfAbsent('$scope|$n', () => []).add(s);
  }
  byName.forEach((k, list) {
    if (list.length < 2) return;
    // لو كلهم أصلًا داخل عنقود كود واحد، الحالة مغطّاة.
    final codeKeys = list.map((s) => inCodeCluster[s.id]).toSet();
    if (codeKeys.length == 1 && codeKeys.first != null) return;
    // إخوة بنفس مجموعة الإخوة = مش تكرار (بالاحتياط).
    final sg = list.map((s) => s.siblingGroupId).toSet();
    if (sg.length == 1 && sg.first != null) return;
    final copies = list.map(_copyOf).toList();
    out.add(DuplicateCase(
      kind: DuplicateKind.student,
      reason: MatchReason.sameNameInGroup,
      copies: copies,
      canonicalId: pickCanonical(copies),
      selectedByDefault: false,
      guardianMismatch: _phonesDiffer(list),
      groupClusterKey: _clusterOf(list, groupClusters),
    ));
  });

  out.sort((a, b) {
    final r = a.reason.index.compareTo(b.reason.index);
    if (r != 0) return r;
    return a.copies.first.name.compareTo(b.copies.first.name);
  });
  return out;
}

String? _clusterOf(List<DupStudentInput> list, Map<int, String> clusters) {
  for (final s in list) {
    final c = clusters[s.groupId];
    if (c != null) return c;
  }
  return null;
}

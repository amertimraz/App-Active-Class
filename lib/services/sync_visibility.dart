// lib/services/sync_visibility.dart
//
// spec 058 / P3 — منطق صرف (بلا شبكة ولا قاعدة بيانات) لعزل المساعد المقيَّد: ملخّص وصوله
// (my_team_access من السيرفر) وحساب الصفوف المحلية اللي بقت مخفية عنه.

/// وصول المستخدم الحالي في الفريق، من RPC `my_team_access(team_id)` (migration P2).
class TeamAccess {
  final bool isOwner;

  /// مساعد مقيَّد بمجموعات/سناتر معيّنة (team_members.groups_restricted).
  final bool restricted;

  /// عدد المجموعات الظاهرة له (غير المحذوفة).
  final int visibleGroups;

  const TeamAccess(
      {required this.isOwner,
      required this.restricted,
      required this.visibleGroups});

  /// مقيَّد ومفيش ولا مجموعة اتمنحت له — التطبيق بيمنعه من الدخول برسالة (P4).
  bool get restrictedWithoutGroups => restricted && visibleGroups == 0;

  /// صف واحد من نتيجة الـRPC، أو null لو الشكل مش مفهوم (السيرفر قديم/فشل).
  static TeamAccess? fromRpc(Object? result) {
    final row = result is List && result.isNotEmpty ? result.first : result;
    if (row is! Map) return null;
    final owner = row['is_owner'];
    final restricted = row['restricted'];
    final visible = row['visible_groups'];
    if (owner is! bool || restricted is! bool || visible is! num) return null;
    return TeamAccess(
        isOwner: owner, restricted: restricted, visibleGroups: visible.toInt());
  }
}

/// معرّفات سيرفر لصفوف محلية **مش** ضمن اللي السيرفر رجّعه في آخر سحب كامل — مرشّحة
/// تكون اتخفّت (اتسحبت من المساعد). لازم تتأكد من السيرفر قبل المسح (سحب بالـoffset ممكن
/// يفوّت صف لو اتغيّر أثناء السحب).
List<String> hiddenCandidates({
  required Iterable<String> localRemoteIds,
  required Set<String> visibleRemoteIds,
}) =>
    [
      for (final id in localRemoteIds)
        if (!visibleRemoteIds.contains(id)) id,
    ];

/// يقسّم [items] لدفعات بحجم [size] (للاستعلامات بـ`in (...)`).
Iterable<List<T>> chunked<T>(List<T> items, int size) sync* {
  for (var i = 0; i < items.length; i += size) {
    yield items.sublist(i, i + size > items.length ? items.length : i + size);
  }
}

/// رؤية مساعد معيّن كما يحدّدها المالك: كل المجموعات، أو مجموعات/سناتر معيّنة.
class MemberVisibility {
  final bool restricted;

  /// معرّفات (remote_id) المجموعات الممنوحة صراحة.
  final Set<String> groupRemoteIds;

  /// أسماء السناتر الممنوحة (متطبّعة).
  final Set<String> centers;

  const MemberVisibility({
    required this.restricted,
    this.groupRemoteIds = const {},
    this.centers = const {},
  });

  static const unrestricted = MemberVisibility(restricted: false);

  /// مقيَّد وما اتمنحش أي حاجة → هيتمنع من الدخول.
  bool get empty => restricted && groupRemoteIds.isEmpty && centers.isEmpty;

  /// ملخّص قصير للعرض في كارت العضو.
  String get summary {
    if (!restricted) return 'كل المجموعات';
    if (empty) return 'مفيش مجموعات (ممنوع من الدخول)';
    final parts = <String>[
      if (centers.isNotEmpty) '${centers.length} سنتر',
      if (groupRemoteIds.isNotEmpty) '${groupRemoteIds.length} مجموعة',
    ];
    return parts.join(' + ');
  }
}

/// السنتر على السيرفر يختلف عن المحلي (بعد تطبيع: trim + دمج المسافات، وفاضي = null)؟
bool centerDiffers(Object? remote, Object? local) {
  String? norm(Object? v) {
    final c = '${v ?? ''}'.trim().replaceAll(RegExp(r'\s+'), ' ');
    return c.isEmpty ? null : c;
  }

  return norm(remote) != norm(local);
}


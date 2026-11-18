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

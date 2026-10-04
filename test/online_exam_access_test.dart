// test/online_exam_access_test.dart — spec 044
import 'package:active_class/utils/online_exam_access.dart';
import 'package:flutter_test/flutter_test.dart';

OnlineExamAccess a({
  bool inTeam = true,
  bool isOwner = false,
  bool canManage = false,
  bool own = false,
  bool team = false,
  bool slug = false,
}) =>
    onlineExamAccess(
      inTeam: inTeam,
      isOwner: isOwner,
      canManage: canManage,
      ownPortalActive: own,
      teamPortalActive: team,
      hasTeamSlug: slug,
    );

void main() {
  test('خارج الفريق: بوابة شغّالة → مفتوح وكتابة', () {
    final r = a(inTeam: false, own: true);
    expect([r.locked, r.readOnly, r.canCreate], [false, false, true]);
  });

  test('خارج الفريق: بوابة مش شغّالة → مقفول', () {
    final r = a(inTeam: false, own: false);
    expect(r.locked, true);
    expect(r.canCreate, false);
  });

  test('مالك: يعتمد على اشتراكه هو حتى لو الفريق مفعّل', () {
    expect(a(isOwner: true, own: true).canCreate, true);
    expect(a(isOwner: true, own: false).locked, true);
  });

  test('مساعد: اشتراك المدرس مش شغّال → مقفول حتى مع الصلاحية', () {
    final r = a(canManage: true, slug: true, team: false);
    expect(r.locked, true);
    expect(r.canCreate, false);
  });

  test('مساعد: اشتراك شغّال بلا صلاحية → قراءة فقط', () {
    final r = a(team: true, slug: true, canManage: false);
    expect([r.locked, r.readOnly, r.canCreate], [false, true, false]);
  });

  test('مساعد: اشتراك + صلاحية بلا slug → قراءة فقط', () {
    final r = a(team: true, canManage: true, slug: false);
    expect([r.locked, r.readOnly, r.canCreate], [false, true, false]);
  });

  test('مساعد: اشتراك + صلاحية + slug → كتابة كاملة', () {
    final r = a(team: true, canManage: true, slug: true);
    expect([r.locked, r.readOnly, r.canCreate], [false, false, true]);
  });

  test('ترخيص جهاز المساعد الشخصي (own) لا يؤثر عليه', () {
    expect(a(own: true, team: false).locked, true);
    expect(a(own: false, team: true, canManage: true, slug: true).canCreate,
        true);
  });

  group('teamPortalActiveAt', () {
    final now = DateTime(2026, 10, 3);
    test('مفعّل بلا تاريخ → شغّال', () {
      expect(teamPortalActiveAt(enabled: true, expiresAt: null, now: now), true);
    });
    test('مفعّل وتاريخ مستقبلي → شغّال', () {
      expect(
          teamPortalActiveAt(
              enabled: true,
              expiresAt: now.add(const Duration(days: 1)),
              now: now),
          true);
    });
    test('منتهي أو غير مفعّل → مش شغّال', () {
      expect(
          teamPortalActiveAt(
              enabled: true,
              expiresAt: now.subtract(const Duration(days: 1)),
              now: now),
          false);
      expect(teamPortalActiveAt(enabled: false, expiresAt: null, now: now),
          false);
    });
  });
}

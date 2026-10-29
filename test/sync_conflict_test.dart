// test/sync_conflict_test.dart
import 'package:active_class/utils/sync_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  autoAbsentTests();
  final t1 = DateTime(2026, 9, 8, 12, 0);
  final t2 = DateTime(2026, 9, 8, 12, 5);

  test('وارد أحدث → true', () {
    expect(
        syncConflictIncomingWins(
            localUpdatedAt: t1,
            remoteUpdatedAt: t2,
            localRemoteId: 'b',
            remoteRemoteId: 'a'),
        isTrue);
  });

  test('وارد أقدم → false', () {
    expect(
        syncConflictIncomingWins(
            localUpdatedAt: t2,
            remoteUpdatedAt: t1,
            localRemoteId: 'a',
            remoteRemoteId: 'b'),
        isFalse);
  });

  test('تعادل + الوارد أصغر معجميًا → true', () {
    expect(
        syncConflictIncomingWins(
            localUpdatedAt: t1,
            remoteUpdatedAt: t1,
            localRemoteId: 'b',
            remoteRemoteId: 'a'),
        isTrue);
  });

  test('تعادل + المحلي أصغر معجميًا → false', () {
    expect(
        syncConflictIncomingWins(
            localUpdatedAt: t1,
            remoteUpdatedAt: t1,
            localRemoteId: 'a',
            remoteRemoteId: 'b'),
        isFalse);
  });

  test('محلي بلا وقت → true', () {
    expect(
        syncConflictIncomingWins(
            localUpdatedAt: null,
            remoteUpdatedAt: t1,
            localRemoteId: 'x',
            remoteRemoteId: 'y'),
        isTrue);
  });

  test('وارد بلا وقت → false', () {
    expect(
        syncConflictIncomingWins(
            localUpdatedAt: t1,
            remoteUpdatedAt: null,
            localRemoteId: 'x',
            remoteRemoteId: 'y'),
        isFalse);
  });
}

void autoAbsentTests() {
  final older = DateTime(2026, 10, 27, 12, 0);
  final newer = DateTime(2026, 10, 27, 12, 5);
  bool wins({
    required String ls,
    String? ln,
    required String rs,
    String? rn,
    required DateTime lt,
    required DateTime rt,
  }) =>
      attendanceConflictIncomingWins(
        localStatus: ls,
        localNotes: ln,
        remoteStatus: rs,
        remoteNotes: rn,
        localUpdatedAt: lt,
        remoteUpdatedAt: rt,
        localRemoteId: 'b',
        remoteRemoteId: 'a',
      );

  group('تحضير يدوي مقابل غياب تلقائي', () {
    test('المحلي غياب تلقائي والوارد حاضر أقدم → الوارد يكسب', () {
      expect(wins(ls: 'غائب', ln: 'غياب تلقائي', rs: 'حاضر', lt: newer, rt: older),
          isTrue);
    });
    test('المحلي حاضر والوارد غياب تلقائي أحدث → المحلي يكسب', () {
      expect(wins(ls: 'حاضر', rs: 'غائب', rn: 'غياب تلقائي', lt: older, rt: newer),
          isFalse);
    });
    test('غياب يدوي (بدون الملاحظة) مش بيتعامل كتلقائي → LWW', () {
      expect(wins(ls: 'حاضر', rs: 'غائب', lt: older, rt: newer), isTrue);
      expect(wins(ls: 'غائب', rs: 'حاضر', lt: newer, rt: older), isFalse);
    });
    test('الاتنين تلقائي → الأحدث', () {
      expect(
          wins(ls: 'غائب', ln: 'غياب تلقائي', rs: 'غائب', rn: 'غياب تلقائي', lt: older, rt: newer),
          isTrue);
    });
  });
}

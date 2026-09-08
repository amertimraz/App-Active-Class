// test/sync_conflict_test.dart
import 'package:active_class/utils/sync_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

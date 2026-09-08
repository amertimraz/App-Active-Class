// test/sync_retry_policy_test.dart
import 'package:active_class/utils/sync_retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldAttemptOutboxRow', () {
    test('تحت العتبة → دايمًا true', () {
      expect(shouldAttemptOutboxRow(0, 7), isTrue);
      expect(shouldAttemptOutboxRow(4, 7), isTrue);
    });
    test('عند/فوق العتبة، جولة عادية → false', () {
      expect(shouldAttemptOutboxRow(5, 7), isFalse);
      expect(shouldAttemptOutboxRow(99, 13), isFalse);
    });
    test('عند/فوق العتبة، جولة إعادة محاولة (مضاعف 20) → true', () {
      expect(shouldAttemptOutboxRow(5, 20), isTrue);
      expect(shouldAttemptOutboxRow(99, 40), isTrue);
      expect(shouldAttemptOutboxRow(5, 0), isTrue);
    });
    test('عتبات مخصّصة', () {
      expect(shouldAttemptOutboxRow(3, 5, maxFails: 3, poisonRetryEvery: 10),
          isFalse);
      expect(shouldAttemptOutboxRow(3, 10, maxFails: 3, poisonRetryEvery: 10),
          isTrue);
    });
  });

  group('shouldFireTeamExit', () {
    test('جلسة غير صالحة → false مهما كان الـstreak', () {
      expect(shouldFireTeamExit(sessionUsable: false, emptyStreak: 9), isFalse);
      expect(shouldFireTeamExit(sessionUsable: false, emptyStreak: 0), isFalse);
    });
    test('جلسة صالحة، streak تحت العتبة → false', () {
      expect(shouldFireTeamExit(sessionUsable: true, emptyStreak: 0), isFalse);
      expect(shouldFireTeamExit(sessionUsable: true, emptyStreak: 2), isFalse);
    });
    test('جلسة صالحة، streak عند/فوق العتبة → true', () {
      expect(shouldFireTeamExit(sessionUsable: true, emptyStreak: 3), isTrue);
      expect(shouldFireTeamExit(sessionUsable: true, emptyStreak: 5), isTrue);
    });
    test('عتبة مخصّصة', () {
      expect(
          shouldFireTeamExit(
              sessionUsable: true, emptyStreak: 2, threshold: 2),
          isTrue);
    });
  });
}

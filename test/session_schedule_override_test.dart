import 'package:active_class/models/session_override_model.dart';
import 'package:active_class/utils/session_schedule_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

SessionOverride _o(SessionOverrideType t, DateTime d) =>
    SessionOverride(groupId: 1, date: d, type: t);

void main() {
  group('resolveHasSession', () {
    test('cancelled → false حتى لو الجدول يقول فيه حصة', () {
      expect(
        resolveHasSession(
            scheduleSays: true, overrideType: SessionOverrideType.cancelled),
        false,
      );
    });
    test('makeup → true حتى لو الجدول يقول لا', () {
      expect(
        resolveHasSession(
            scheduleSays: false, overrideType: SessionOverrideType.makeup),
        true,
      );
    });
    test('extra → true', () {
      expect(
        resolveHasSession(
            scheduleSays: false, overrideType: SessionOverrideType.extra),
        true,
      );
    });
    test('بلا استثناء → الجدول', () {
      expect(resolveHasSession(scheduleSays: true, overrideType: null), true);
      expect(resolveHasSession(scheduleSays: false, overrideType: null), false);
    });
  });

  group('expectedCountDelta', () {
    final sat = DateTime(2026, 9, 5); // يوم جدول
    final tue = DateTime(2026, 9, 8); // مش يوم جدول
    bool sched(DateTime d) => d == sat;

    test('cancelled على يوم جدول → -1', () {
      expect(
        expectedCountDelta(
            overridesInRange: [_o(SessionOverrideType.cancelled, sat)],
            scheduleHasDay: sched),
        -1,
      );
    });
    test('cancelled على غير يوم جدول → 0', () {
      expect(
        expectedCountDelta(
            overridesInRange: [_o(SessionOverrideType.cancelled, tue)],
            scheduleHasDay: sched),
        0,
      );
    });
    test('makeup على غير يوم جدول → +1', () {
      expect(
        expectedCountDelta(
            overridesInRange: [_o(SessionOverrideType.makeup, tue)],
            scheduleHasDay: sched),
        1,
      );
    });
    test('makeup على يوم جدول → 0', () {
      expect(
        expectedCountDelta(
            overridesInRange: [_o(SessionOverrideType.makeup, sat)],
            scheduleHasDay: sched),
        0,
      );
    });
    test('مزيج → المجموع', () {
      expect(
        expectedCountDelta(
          overridesInRange: [
            _o(SessionOverrideType.cancelled, sat),
            _o(SessionOverrideType.makeup, tue),
            _o(SessionOverrideType.extra, tue),
          ],
          scheduleHasDay: sched,
        ),
        1, // -1 + 1 + 1
      );
    });
    test('فارغ → 0', () {
      expect(
        expectedCountDelta(overridesInRange: [], scheduleHasDay: sched),
        0,
      );
    });
  });
}

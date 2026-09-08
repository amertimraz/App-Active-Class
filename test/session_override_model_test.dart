import 'package:active_class/models/session_override_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionOverride toMap/fromMap', () {
    test('round-trip cancelled', () {
      final o = SessionOverride(
        id: 3,
        groupId: 7,
        date: DateTime(2026, 9, 8, 14, 30),
        type: SessionOverrideType.cancelled,
        note: 'مريض',
        createdAt: DateTime(2026, 9, 8, 10),
      );
      final back = SessionOverride.fromMap(o.toMap());
      expect(back.groupId, 7);
      expect(back.type, SessionOverrideType.cancelled);
      expect(back.date, DateTime(2026, 9, 8)); // منزوع الوقت
      expect(back.note, 'مريض');
      expect(back.compensatesDate, isNull);
    });

    test('round-trip makeup with compensatesDate', () {
      final o = SessionOverride(
        groupId: 1,
        date: DateTime(2026, 9, 9),
        type: SessionOverrideType.makeup,
        compensatesDate: DateTime(2026, 9, 6),
      );
      final back = SessionOverride.fromMap(o.toMap());
      expect(back.type, SessionOverrideType.makeup);
      expect(back.compensatesDate, DateTime(2026, 9, 6));
    });

    test('round-trip extra', () {
      final o = SessionOverride(
        groupId: 2,
        date: DateTime(2026, 9, 10),
        type: SessionOverrideType.extra,
      );
      expect(SessionOverride.fromMap(o.toMap()).type, SessionOverrideType.extra);
    });

    test('unknown type falls back to cancelled', () {
      final map = {
        'id': 1,
        'group_id': 1,
        'date': '2026-09-08',
        'type': 'bogus',
      };
      expect(SessionOverride.fromMap(map).type, SessionOverrideType.cancelled);
    });

    test('date stored as YYYY-MM-DD', () {
      final o = SessionOverride(
        groupId: 1,
        date: DateTime(2026, 1, 5),
        type: SessionOverrideType.cancelled,
      );
      expect(o.toMap()['date'], '2026-01-05');
    });

    test('fromMap tolerates full ISO date string', () {
      final map = {
        'id': 1,
        'group_id': 4,
        'date': '2026-09-08T00:00:00.000',
        'type': 'cancelled',
      };
      expect(SessionOverride.fromMap(map).date, DateTime(2026, 9, 8));
    });
  });
}

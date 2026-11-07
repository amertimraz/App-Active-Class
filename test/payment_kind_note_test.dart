import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/utils/payment_note.dart';

Payment _p({String? note, PaymentKind? kind}) => Payment(
    studentId: 1,
    date: DateTime(2026, 10, 1),
    amount: 100,
    note: note,
    storedKind: kind);

void main() {
  group('Payment.kind', () {
    test('بيتشتق من الملاحظة لو مفيش نوع مخزّن (أجهزة قديمة)', () {
      expect(_p(note: kDebtWriteOffNote).isWriteOff, isTrue);
      expect(_p(note: 'months=2026-10').isCollection, isTrue);
      expect(_p().isCollection, isTrue);
    });
    test('النوع المخزّن يغلب الملاحظة، وبيتكتب في toMap وبيرجع في fromMap', () {
      final w = _p(note: 'x', kind: PaymentKind.writeOff);
      expect(w.isWriteOff, isTrue);
      expect(w.toMap()['kind'], 'write_off');
      final back = Payment.fromMap({...w.toMap(), 'id': 5});
      expect(back.storedKind, PaymentKind.writeOff);
      expect(_p(note: 'months=2026-10').toMap()['kind'], 'collection');
    });
  });

  group('PaymentNote', () {
    test('parse كل الحقول', () {
      final n = PaymentNote.parse(
          'months=2026-09,2026-10;custom=1;note=خصم;siblings=3;sessions=4');
      expect(n.months, [DateTime(2026, 9), DateTime(2026, 10)]);
      expect([n.custom, n.text, n.siblings, n.sessions], [true, 'خصم', 3, 4]);
      expect(n.lastMonth, DateTime(2026, 10));
      expect(n.coversMonth(DateTime(2026, 9, 15)), isTrue);
      expect(n.coversMonth(DateTime(2026, 8)), isFalse);
    });
    test('ملاحظات حرة/فاضية/تالفة', () {
      expect(PaymentNote.parse(null).months, isEmpty);
      expect(PaymentNote.parse(kDebtWriteOffNote).months, isEmpty);
      expect(PaymentNote.parse('months=2026-13,abc,2026-05').months,
          [DateTime(2026, 5)]);
    });
    test('encode ↔ parse', () {
      final s = PaymentNote.encode(
          months: [DateTime(2026, 9), DateTime(2026, 10)],
          custom: true,
          siblings: 2)!;
      expect(s, 'months=2026-09,2026-10;custom=1;siblings=2');
      expect(PaymentNote.parse(s).months.length, 2);
      expect(PaymentNote.encode(months: []), isNull);
    });
    test('منطقية الشهور', () {
      final now = DateTime(2026, 11, 6);
      expect(PaymentNote.isImplausibleMonth(DateTime(2026, 12), now), isFalse);
      expect(PaymentNote.isImplausibleMonth(DateTime(2027, 11), now), isFalse);
      expect(PaymentNote.isImplausibleMonth(DateTime(2027, 12), now), isTrue);
      expect(
          PaymentNote.isImplausibleMonth(DateTime(2024, 1), now,
              earliest: DateTime(2026, 9)),
          isTrue);
      expect(
          PaymentNote.parse('months=2028-01').implausibleMonths(now).length, 1);
    });
  });
}

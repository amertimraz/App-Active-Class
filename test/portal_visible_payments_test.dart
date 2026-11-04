// test/portal_visible_payments_test.dart
//
// "إسقاط مديونية" مش دفعة نقدية: ما يظهرش لولي الأمر ولا يدخل في "المدفوع".
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/utils/parent_portal_helper.dart';

Payment p(double amount, {String? note}) => Payment(
    studentId: 1, amount: amount, date: DateTime(2026, 11, 1), note: note);

void main() {
  test('صفوف إسقاط المديونية تتشال والباقي يفضل', () {
    final all = [
      p(450, note: 'months=2026-11'),
      p(4500, note: kDebtWriteOffNote),
      p(200),
    ];
    final shown = portalVisiblePayments(all);
    expect(shown.map((x) => x.amount), [450, 200]);
    expect(shown.fold<double>(0, (s, x) => s + x.amount), 650);
  });

  test('بلا إسقاطات: نفس القايمة', () {
    final all = [p(100), p(50, note: 'months=2026-10')];
    expect(portalVisiblePayments(all), hasLength(2));
  });
}

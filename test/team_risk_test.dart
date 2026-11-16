// تنبيهات المخاطر لعمليات وضع الفريق: كلمة تأكيد التعطيل.
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/views/team/team_risk_dialogs.dart';

void main() {
  test('تأكيد التعطيل: لازم الكلمة بالظبط (مسافات الأطراف مسموحة)', () {
    expect(isDisableTeamConfirmed('تعطيل'), isTrue);
    expect(isDisableTeamConfirmed('  تعطيل  '), isTrue);
    expect(isDisableTeamConfirmed(''), isFalse);
    expect(isDisableTeamConfirmed('تعطل'), isFalse);
    expect(isDisableTeamConfirmed('تعطيل الفريق'), isFalse);
    expect(isDisableTeamConfirmed('yes'), isFalse);
  });
}

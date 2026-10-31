import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/utils/web_login_notice.dart';

void main() {
  test('الحالة السليمة بلا رسالة', () {
    expect(webLoginNoticeFor(TeamRestoreStatus.ok), isNull);
  });
  test('مش عضو في فريق: بتوجّه لتفعيل وضع الفريق من الموبايل', () {
    final m = webLoginNoticeFor(TeamRestoreStatus.noTeam)!;
    expect(m, contains('وضع الفريق'));
    expect(m, contains('الموبايل'));
  });
  test('مساعد مربوط بجهاز تاني', () {
    expect(
        webLoginNoticeFor(TeamRestoreStatus.deviceLocked)!, contains('مساعد'));
  });
  test('أي حالة تانية = فشل تحميل عام', () {
    expect(webLoginNoticeFor(TeamRestoreStatus.failed)!, contains('تعذّر'));
    expect(webLoginNoticeFor('???')!, contains('تعذّر'));
  });
  test('التفاصيل الفنية بتظهر مع فشل التحميل بس', () {
    final m =
        webLoginNoticeFor(TeamRestoreStatus.failed, detail: 'students: x');
    expect(m, contains('تفاصيل فنية: students: x'));
    expect(webLoginNoticeFor(TeamRestoreStatus.noTeam, detail: 'x'),
        isNot(contains('تفاصيل فنية')));
  });
}

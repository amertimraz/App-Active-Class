import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/services/whatsapp_auto_service.dart';
import 'package:active_class/utils/support_contact.dart';
import 'package:active_class/utils/whatsapp_auto_rules.dart';

void main() {
  test('رسالة طلب التفعيل: فيها الاسم والرقم والحساب لما يتوفروا', () {
    final m = buildWaActivationRequest(
        teacherName: 'أ/ سعد', teacherPhone: '+201012345678', account: 'a@b.com');
    expect(m, contains('الواتساب التلقائي'));
    expect(m, contains('الباقات والأسعار'));
    expect(m, contains('الاسم: أ/ سعد'));
    expect(m, contains('رقم الهاتف: +201012345678'));
    expect(m, contains('حساب الدخول: a@b.com'));
  });

  test('الحقول الفاضية بتتشال من الرسالة', () {
    final m = buildWaActivationRequest(teacherName: ' ', teacherPhone: null);
    expect(m, isNot(contains('الاسم')));
    expect(m, isNot(contains('رقم الهاتف')));
    expect(m, isNot(contains('حساب الدخول')));
    expect(m.trim(), isNotEmpty);
  });

  test('waLowBalance: ١٠٪ من الحد وبحد أدنى ١٠ (نفس قاعدة لوحة الأدمن)', () {
    expect(waLowBalance(10, 100), isTrue);
    expect(waLowBalance(11, 100), isFalse);
    expect(waLowBalance(50, 500), isTrue);
    expect(waLowBalance(51, 500), isFalse);
    expect(waLowBalance(8, 20), isTrue);
    expect(waLowBalance(0, 0), isTrue);
  });

  test('المساعد: مفيش قراءة لحالة التفعيل ولا طلب تفعيل (ده عند المدرس)', () async {
    final team = TeamModeService();
    team.isEnabled.value = true;
    team.isOwner.value = false;
    addTearDown(() {
      team.isEnabled.value = false;
      team.isOwner.value = false;
    });
    expect(await WhatsAppAutoService.instance.loadActivation(), isNull);
    expect(await WhatsAppAutoService.instance.requestActivation(), isFalse);
  });
}

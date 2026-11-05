import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/message_templates.dart';
import 'package:active_class/utils/whatsapp_targets.dart';

Student st({String? guardian, String? wa, String? own}) => Student(
    name: 'عمر',
    code: 'A1',
    groupId: 1,
    price: 100,
    guardianPhone: guardian,
    guardianWhatsapp: wa,
    studentPhone: own);

void main() {
  group('قوالب الرسائل', () {
    test('بيعرّف المتغيّرات المعروفة بس وبدون تكرار', () {
      const body =
          'مستوى {اسم_الطالب} {المستوى} — {اسم_الطالب} {كذا} {التاريخ}';
      expect(templateVariables(body), ['اسم_الطالب', 'المستوى', 'التاريخ']);
    });

    test('اللي بيتسأل عنه: الدرجة والمستوى بس', () {
      expect(askedVariables('{اسم_الطالب} {الدرجة} {المجموعة} {المستوى}'),
          ['الدرجة', 'المستوى']);
    });

    test('بيعبّي المتغيّرات، والناقص بيفضل ظاهر', () {
      final out = renderTemplate(
          'نتيجة {اسم_الطالب}: {الدرجة} من {كذا}', {'اسم_الطالب': 'عمر'});
      expect(out, 'نتيجة عمر: {الدرجة} من {كذا}');
      expect(
          missingVariables(
              'نتيجة {اسم_الطالب}: {الدرجة}', {'اسم_الطالب': 'عمر'}),
          ['الدرجة']);
    });

    test('قيمة فاضية أو مسافات = ناقصة', () {
      expect(missingVariables('{الدرجة}', {'الدرجة': '  '}), ['الدرجة']);
      expect(renderTemplate('{الدرجة}', {'الدرجة': ' 45/50 '}), '45/50');
    });

    test('المستويات: المعرّفة وإلا الافتراضية', () {
      const a = MessageTemplate(title: 't', body: 'b', levels: ['ممتاز', ' ']);
      expect(a.effectiveLevels, ['ممتاز']);
      const b = MessageTemplate(title: 't', body: 'b');
      expect(b.effectiveLevels, kDefaultLevels);
    });

    test('الرسائل الجاهزة صالحة وفيها متغيّراتها', () {
      final s = starterTemplates();
      expect(s.every((t) => t.isValid), isTrue);
      expect(
          s.any((t) => askedVariables(t.body).contains(MsgVar.level)), isTrue);
    });
  });

  group('وجهات واتساب', () {
    test('الاختيارات حسب المتاح والإعداد', () {
      final both = st(guardian: '0100', own: '0111');
      expect(availableAudiences(both, studentMessagingEnabled: false),
          [WhatsappAudience.guardian]);
      expect(availableAudiences(both, studentMessagingEnabled: true), [
        WhatsappAudience.guardian,
        WhatsappAudience.student,
        WhatsappAudience.both,
      ]);
      expect(availableAudiences(st(own: '0111'), studentMessagingEnabled: true),
          [WhatsappAudience.student]);
      expect(availableAudiences(st(), studentMessagingEnabled: true), isEmpty);
      expect(
          availableAudiences(st(wa: 'wa.me/2010'),
              studentMessagingEnabled: false),
          [WhatsappAudience.guardian]);
    });

    test('رابط الجروب: بيقبل واتساب بس وينضّفه', () {
      expect(normalizeWhatsappGroupLink('chat.whatsapp.com/AbC123'),
          'https://chat.whatsapp.com/AbC123');
      expect(
          normalizeWhatsappGroupLink(' https://chat.whatsapp.com/AbC123?x=1 '),
          'https://chat.whatsapp.com/AbC123');
      expect(normalizeWhatsappGroupLink('https://www.whatsapp.com/channel/XyZ'),
          'https://whatsapp.com/channel/XyZ');
      expect(normalizeWhatsappGroupLink('https://evil.com/chat.whatsapp.com/x'),
          isNull);
      expect(normalizeWhatsappGroupLink('https://chat.whatsapp.com/'), isNull);
      expect(normalizeWhatsappGroupLink('مش رابط'), isNull);
      expect(normalizeWhatsappGroupLink(''), isNull);
      expect(normalizeWhatsappGroupLink(null), isNull);
    });
  });
}

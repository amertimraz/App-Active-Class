// test/help_content_test.dart — سلامة محتوى مركز المساعدة والبحث (صرف).
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/help/help_content.dart';
import 'package:active_class/help/help_coverage.dart';
import 'package:active_class/utils/help_search.dart';

void main() {
  group('المحتوى', () {
    test('معرّفات فريدة', () {
      final ids = kHelpTopics.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });
    test('كل موضوع فيه عنوان وملخص وخطوات', () {
      for (final t in kHelpTopics) {
        expect(t.title.trim(), isNotEmpty, reason: t.id);
        expect(t.summary.trim(), isNotEmpty, reason: t.id);
        expect(t.steps, isNotEmpty, reason: t.id);
        for (final s in t.steps) {
          expect(s.trim(), isNotEmpty, reason: t.id);
        }
      }
    });
    test('علامات ** متوازنة في كل نص', () {
      for (final t in kHelpTopics) {
        for (final s in [t.summary, ...t.steps, ...t.tips]) {
          expect('**'.allMatches(s).length % 2, 0, reason: '${t.id}: $s');
        }
      }
    });
    test('المواضيع المرتبطة موجودة ومش النفس', () {
      for (final t in kHelpTopics) {
        for (final r in t.related) {
          expect(helpTopicById(r), isNotNull, reason: '${t.id} → $r');
          expect(r, isNot(t.id));
        }
      }
    });
    test('زر الشاشة ليه اسم لو فيه مسار', () {
      for (final t in kHelpTopics) {
        if (t.route != null) {
          expect(t.routeLabel, isNotNull, reason: t.id);
        }
      }
    });
    test('كل اقتراح بحث بيرجّع نتيجة', () {
      for (final q in kHelpSuggestions) {
        expect(searchHelp(q), isNotEmpty, reason: q);
      }
    });
    test('الأكثر استخدامًا ومسارات الشاشات صالحة', () {
      for (final id in kHelpPopular) {
        expect(helpTopicById(id), isNotNull, reason: id);
      }
      for (final e in kHelpTopicForRoute.entries) {
        expect(helpTopicById(e.value), isNotNull, reason: e.key);
      }
    });
    test('وقت القراءة دقيقة على الأقل ومنطقي', () {
      for (final t in kHelpTopics) {
        expect(t.readMinutes, inInclusiveRange(1, 3), reason: t.id);
      }
    });
    test('كل فئة فيها موضوع', () {
      for (final c in HelpCategory.values) {
        expect(kHelpTopics.where((t) => t.category == c), isNotEmpty);
      }
    });
  });

  group('البحث', () {
    String top(String q) => searchHelp(q).first.id;

    test('بيفهم العامّي', () {
      expect(top('إزاي أسجل دفعة؟'), 'payments');
      expect(top('عايز أسجل حضور'), 'attendance');
      expect(top('درجة التسميع'), 'recitation');
      expect(top('بوابة أولياء الأمور'), 'portal');
      expect(top('نسخة احتياطية'), 'backup');
    });
    test('تطبيع الهمزات والتاء المربوطة', () {
      expect(top('اداره المجموعات'), isNotEmpty);
      expect(top('مجموعه'), 'groups');
    });
    test('مرادفات من الكلمات المفتاحية', () {
      expect(top('فلوس'), 'payments');
      expect(top('باركود'), 'qr');
      expect(top('اكسل'), 'students');
    });
    test('أرقام هندية وعلامات ترقيم لا تكسر', () {
      expect(searchHelp('؟؟؟'), hasLength(kHelpTopics.length));
      expect(searchHelp('qr!'), isNotEmpty);
    });
    test('بحث فاضي → الكل', () {
      expect(searchHelp('  '), hasLength(kHelpTopics.length));
    });
    test('كلام ملوش علاقة → فاضي', () {
      expect(searchHelp('زززززز'), isEmpty);
    });
    test('مواقف جديدة', () {
      expect(top('الحصة اتلغت'), 'cancel_session');
      expect(top('تذكير المتأخرين'), 'remind_debtors');
      expect(top('اختيار طالب عشوائي'), 'random_pick');
      expect(top('تحضير الكل'), 'mark_all');
      expect(top('إعفاء طالب'), 'exemption_siblings');
      expect(top('مهلة السماح'), 'billing_settings');
      expect(top('محتاجين متابعة'), 'at_risk');
      expect(top('تقرير واتساب لولي الأمر'), 'parent_report');
    });
    test('مشاكل: المجموعة مش ظاهرة', () {
      expect(top('المجموعة مش ظاهرة في الحضور'), 'fix_group_missing');
    });
    test('مشاكل: مش شايف البيانات', () {
      expect(top('ولي الأمر مش شايف الدرجة'), anyOf('fix_portal', 'portal'));
    });
  });
}

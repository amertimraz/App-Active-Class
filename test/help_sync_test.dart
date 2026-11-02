// test/help_sync_test.dart — بيمنع إن المساعدة تفضل بالقديم لما التطبيق يتغيّر:
//  1) كل كلمة عريضة (**...**) في الشرح لازم تكون نص موجود فعلًا في كود التطبيق.
//  2) كل شاشة (ROUTE_*) لازم ليها موضوع، أو تتعلّم صراحة كمستثناة/دين معلن.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/help/help_content.dart';
import 'package:active_class/help/help_coverage.dart';
import 'package:active_class/utils/arabic_normalize.dart';

List<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) =>
        f.path.endsWith('.dart') &&
        // محتوى المساعدة نفسه ما يتحسبش مصدر (وإلا هيطابق نفسه).
        !f.path.replaceAll(r'\', '/').endsWith('lib/help/help_content.dart'))
    .toList();

void main() {
  group('الكلمات العريضة موجودة في الواجهة', () {
    late final String source;
    setUpAll(() {
      source = normalizeArabic(
          _libFiles().map((f) => f.readAsStringSync()).join('\n'));
    });

    test('كل **كلمة** في الشرح نص حقيقي في الكود', () {
      final bold = RegExp(r'\*\*(.+?)\*\*');
      final missing = <String>[];
      for (final t in kHelpTopics) {
        final texts = [t.summary, ...t.steps, ...t.tips, if (t.warning != null) t.warning!];
        for (final text in texts) {
          for (final m in bold.allMatches(text)) {
            // مسار إعدادات "الإعدادات > الفئة" بيتفحص كل جزء لوحده.
            for (final part in m.group(1)!.split('>')) {
              final p = part.trim();
              if (p.isEmpty || kHelpDescriptiveBold.contains(p)) continue;
              if (!source.contains(normalizeArabic(p))) {
                missing.add('${t.id}: «$p»');
              }
            }
          }
        }
      }
      expect(missing, isEmpty,
          reason: 'كلمات عريضة مش موجودة في كود التطبيق (اتغيّر الاسم؟):\n'
              '${missing.join('\n')}');
    });
  });

  group('تغطية الشاشات', () {
    late final Map<String, String> routes; // الاسم → المسار
    setUpAll(() {
      final src = File('lib/config/constants.dart').readAsStringSync();
      routes = {
        for (final m in RegExp(r"const String (ROUTE_\w+)\s*=\s*'([^']+)'")
            .allMatches(src))
          m.group(1)!: m.group(2)!,
      };
    });

    test('كل ROUTE_* ليه موضوع أو مستثنى أو دين معلن', () {
      final covered = {
        ...kHelpTopicForRoute.keys,
        ...kHelpIgnoredRoutes,
        ...kHelpKnownGaps,
        for (final t in kHelpTopics)
          if (t.route != null) t.route!,
      };
      final unknown = [
        for (final e in routes.entries)
          if (!covered.contains(e.value)) '${e.key} (${e.value})',
      ];
      expect(unknown, isEmpty,
          reason: 'شاشات جديدة من غير مساعدة — حطها في help_coverage.dart:\n'
              '${unknown.join('\n')}');
    });

    test('الخريطة مفيهاش مسارات اتشالت من التطبيق', () {
      final values = routes.values.toSet();
      for (final r in [
        ...kHelpTopicForRoute.keys,
        ...kHelpIgnoredRoutes,
        ...kHelpKnownGaps,
      ]) {
        expect(values.contains(r), isTrue, reason: 'المسار $r مش موجود في constants');
      }
    });

    test('كل موضوع في الخريطة موجود', () {
      for (final e in kHelpTopicForRoute.entries) {
        expect(helpTopicById(e.value), isNotNull, reason: '${e.key} → ${e.value}');
      }
    });

    test('مسار ما يتكررش بين مغطّى ودين معلن', () {
      for (final r in kHelpKnownGaps) {
        expect(kHelpTopicForRoute.containsKey(r), isFalse,
            reason: '$r اتغطّى — شيله من kHelpKnownGaps');
      }
    });

    test('الدين المعلن مرئي: بيطلع في الاختبار كعدد', () {
      // مجرد توثيق: لو عدد الديون زاد، حد لازم ياخد القرار ده بإيده.
      expect(kHelpKnownGaps.length, lessThanOrEqualTo(7));
    });
  });
}

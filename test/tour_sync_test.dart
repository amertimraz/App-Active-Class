// test/tour_sync_test.dart — جولات «جرّبها بنفسك» لازم تفضل متزامنة مع الواجهة:
//  1) كل خطوة بتشاور على TourTarget موجود فعلًا في كود الشاشات.
//  2) كل **كلمة** في نص الخطوة نص حقيقي في التطبيق.
//  3) كل tourId في المساعدة جولة موجودة.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/help/help_content.dart';
import 'package:active_class/tour/tour.dart';
import 'package:active_class/utils/arabic_normalize.dart';

void main() {
  late final String source;
  setUpAll(() {
    source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
          final p = f.path.replaceAll(r'\', '/');
          return p.endsWith('.dart') &&
              !p.endsWith('lib/tour/tour.dart') &&
              !p.endsWith('lib/help/help_content.dart');
        })
        .map((f) => f.readAsStringSync())
        .join('\n');
  });

  test('كل خطوة ليها TourTarget في الواجهة', () {
    final missing = <String>[
      for (final t in kTours)
        for (final s in t.steps)
          if (s.target.isNotEmpty && !source.contains("'${s.target}'"))
            '${t.id}: ${s.target}',
    ];
    expect(missing, isEmpty, reason: 'عناصر الجولة مش موجودة:\n${missing.join('\n')}');
  });

  test('الكلمات العريضة في الجولات نصوص حقيقية', () {
    final norm = normalizeArabic(source);
    final bold = RegExp(r'\*\*(.+?)\*\*');
    final missing = <String>[
      for (final t in kTours)
        for (final s in t.steps)
          for (final m in bold.allMatches(s.text))
            if (!norm.contains(normalizeArabic(m.group(1)!.trim())))
              '${t.id}: «${m.group(1)}»',
    ];
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('كل tourId في المساعدة جولة موجودة', () {
    for (final h in kHelpTopics) {
      if (h.tourId != null) expect(tourById(h.tourId!), isNotNull, reason: h.id);
    }
  });

  test('الجولة بتمشي للآخر وبتخلص', () {
    final c = TourController.instance;
    c.start('add_student');
    expect(c.active, isTrue);
    final n = tourById('add_student')!.steps.length;
    for (var i = 0; i < n; i++) {
      c.next();
    }
    expect(c.finished, isTrue);
    c.stop();
    expect(c.active, isFalse);
  });
}

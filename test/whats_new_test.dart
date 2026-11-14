import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/utils/whats_new.dart';

const _notes = [
  ReleaseNote('1.3.0', [ReleaseItem('c', 'c')]),
  ReleaseNote('1.2.88', [ReleaseItem('b', 'b')]),
  ReleaseNote('1.2.87', [ReleaseItem('a', 'a')]),
];

List<String> v(List<ReleaseNote> l) => l.map((n) => n.version).toList();

void main() {
  test('parse/compare: رقم البناء مايأثرش، والترتيب رقمي مش نصي', () {
    expect(parseVersion('1.2.87+4110'), [1, 2, 87]);
    expect(parseVersion('1.2'), isNull);
    expect(compareVersions('1.2.9', '1.2.10'), -1); // نصيًا كانت تطلع العكس
    expect(compareVersions('1.2.87+1', '1.2.87+999'), 0);
    expect(compareVersions('2.0.0', '1.99.99'), 1);
  });

  test('أول تثبيت (lastSeen=null) → مفيش نافذة', () {
    expect(notesToShow(lastSeen: null, current: '1.2.87', notes: _notes),
        isEmpty);
  });

  test('تحديث واحد → ملاحظاته بس', () {
    expect(
        v(notesToShow(lastSeen: '1.2.86', current: '1.2.87', notes: _notes)),
        ['1.2.87']);
  });

  test('قفز كذا إصدار → كلهم الأحدث أولًا، وبحد أقصى', () {
    expect(
        v(notesToShow(lastSeen: '1.2.0', current: '1.3.0', notes: _notes)),
        ['1.3.0', '1.2.88', '1.2.87']);
    expect(
        v(notesToShow(
            lastSeen: '1.2.0', current: '1.3.0', notes: _notes, max: 2)),
        ['1.3.0', '1.2.88']);
  });

  test('إصدار أحدث من الحالي ما يتعرضش (ملاحظات جاهزة قبل رفع الإصدار)', () {
    expect(
        v(notesToShow(lastSeen: '1.2.86', current: '1.2.86', notes: _notes)),
        isEmpty);
    expect(
        v(notesToShow(lastSeen: '1.2.86', current: '1.2.87', notes: _notes)),
        ['1.2.87']);
  });

  test('اتشاف قبل كده (lastSeen == current) → مفيش تكرار', () {
    expect(
        notesToShow(lastSeen: '1.3.0', current: '1.3.0', notes: _notes),
        isEmpty);
  });

  test('رجوع لإصدار أقدم → مفيش نافذة', () {
    expect(
        notesToShow(lastSeen: '1.3.0', current: '1.2.87', notes: _notes),
        isEmpty);
  });

  test('الملاحظات الحقيقية: عنوان قصير وشرح أقل من ١٢٠ حرف', () {
    for (final n in kReleaseNotes) {
      expect(parseVersion(n.version), isNotNull, reason: n.version);
      expect(n.items, isNotEmpty);
      for (final i in n.items) {
        expect(i.title.trim(), isNotEmpty);
        expect(i.title.length, lessThan(30), reason: i.title);
        expect(i.body.trim(), isNotEmpty);
        expect(i.body.length, lessThan(120), reason: i.body);
      }
    }
  });
}

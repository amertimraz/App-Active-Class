// test/booklet_portal_test.dart
//
// مذكرات الطالب في بوابة ولي الأمر: نفس قواعد شاشة المذكرات في التطبيق.
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/booklet_portal.dart';

Student st({int id = 1, int group = 10, bool archived = false}) => Student(
      id: id,
      name: 'طالب',
      code: 'c$id',
      groupId: group,
      price: 100,
      isArchived: archived,
    );

final b1 = Booklet(id: 1, name: 'الأولى', price: 80);
final b2 = Booklet(id: 2, name: 'الثانية', price: 120);
const linkB1G10 = BookletGroupLink(id: 1, bookletId: 1, groupId: 10);
const linkB2G10 = BookletGroupLink(id: 2, bookletId: 2, groupId: 10);
const linkB2G99 = BookletGroupLink(id: 3, bookletId: 2, groupId: 99);

BookletPayment pay(int booklet, double amount, {int student = 1}) =>
    BookletPayment(
        bookletId: booklet,
        studentId: student,
        amount: amount,
        date: DateTime(2026, 11, 1));

void main() {
  test('ملزمة مربوطة بمجموعة الطالب: السعر والمدفوع والمتبقي والتسليم', () {
    final lines = studentBookletPortalLines(
      student: st(),
      booklets: [b1, b2],
      links: [linkB1G10, linkB2G10],
      records: [
        const BookletRecord(bookletId: 1, studentId: 1, delivered: true),
      ],
      payments: [pay(1, 80), pay(2, 50)],
    );
    expect(lines.map((l) => l.name), ['الأولى', 'الثانية']);
    expect(lines[0].remaining, 0);
    expect(lines[0].delivered, isTrue);
    expect(lines[1].paid, 50);
    expect(lines[1].remaining, 70);
    expect(lines[1].delivered, isFalse);
    expect(bookletPortalFields(lines)['bookletsRemaining'], 70);
  });

  test('ملزمة مربوطة بمجموعة تانية ما تظهرش', () {
    final lines = studentBookletPortalLines(
      student: st(),
      booklets: [b2],
      links: [linkB2G99],
      records: const [],
      payments: const [],
    );
    expect(lines, isEmpty);
    expect(bookletPortalFields(lines), isEmpty);
  });

  test('طالب مؤرشف بلا تسليم ولا دفعات: ما يظهرش. ومعاه دفعة: يظهر بمتبقي صفر',
      () {
    final none = studentBookletPortalLines(
      student: st(archived: true),
      booklets: [b1],
      links: [linkB1G10],
      records: const [],
      payments: const [],
    );
    expect(none, isEmpty);
    final withPay = studentBookletPortalLines(
      student: st(archived: true),
      booklets: [b1],
      links: [linkB1G10],
      records: const [],
      payments: [pay(1, 30)],
    );
    expect(withPay, hasLength(1));
    expect(withPay.single.remaining, 0);
  });

  test('طالب مستثنى: ما عليهوش متبقي', () {
    final lines = studentBookletPortalLines(
      student: st(),
      booklets: [b1],
      links: [linkB1G10],
      records: [
        const BookletRecord(
            bookletId: 1, studentId: 1, delivered: true, excluded: true),
      ],
      payments: const [],
    );
    expect(lines.single.remaining, 0);
  });

  test('دفعات طالب تاني ما بتتحسبش', () {
    final lines = studentBookletPortalLines(
      student: st(id: 1),
      booklets: [b1],
      links: [linkB1G10],
      records: const [],
      payments: [pay(1, 80, student: 2)],
    );
    expect(lines.single.paid, 0);
    expect(lines.single.remaining, 80);
  });
}

// test/session_guest_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/utils/session_guest.dart';

Attendance att({String? notes}) => Attendance(
    studentId: 1, date: DateTime(2026, 11, 5), status: 'حاضر', notes: notes);

void main() {
  test('الوسم بيتكتب ويتقرا', () {
    expect(guestNote(12), 'guest=12');
    expect(guestGroupIdOf(att(notes: guestNote(12))), 12);
    expect(isGuestOfGroup(att(notes: guestNote(12)), 12), isTrue);
    expect(isGuestOfGroup(att(notes: guestNote(12)), 13), isFalse);
  });

  test('سجل عادي أو بملاحظة تانية مش ضيف', () {
    expect(guestGroupIdOf(att()), isNull);
    expect(guestGroupIdOf(att(notes: '')), isNull);
    expect(guestGroupIdOf(att(notes: 'غياب تلقائي')), isNull);
    expect(guestGroupIdOf(att(notes: 'guest=abc')), isNull);
  });
}

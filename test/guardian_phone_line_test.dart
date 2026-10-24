import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/widgets/guardian_phone_line.dart';

Student st({String? phone, String? wa}) => Student(
    id: 1,
    name: 'س',
    code: 'c',
    groupId: 1,
    price: 0,
    guardianPhone: phone,
    guardianWhatsapp: wa);

void main() {
  test('رقم ولي الأمر هو الأساس', () {
    expect(guardianPhoneForDisplay(st(phone: ' 01012345678 ')), '01012345678');
  });
  test('بدون رقم: واتساب لو رقم فقط', () {
    expect(guardianPhoneForDisplay(st(wa: '+20 101 234 5678')), '+20 101 234 5678');
    expect(guardianPhoneForDisplay(st(wa: '@teacher_user')), isNull);
    expect(guardianPhoneForDisplay(st(wa: 'https://wa.me/201012345678')), isNull);
  });
  test('مفيش رقم → null', () {
    expect(guardianPhoneForDisplay(st()), isNull);
    expect(guardianPhoneForDisplay(st(phone: '  ')), isNull);
  });
}

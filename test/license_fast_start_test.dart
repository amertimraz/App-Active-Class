import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/controllers/license_controller.dart';

// فتح سريع بالترخيص المحفوظ: بس لو التحقق الناجح الأخير جوه المهلة والترخيص سارٍ.
void main() {
  final now = DateTime(2026, 11, 7, 12);
  int ms(DateTime d) => d.millisecondsSinceEpoch;

  bool can({int? last, DateTime? exp}) => canStartFromCachedLicense(
      lastVerifiedMs: last, expiresAt: exp, now: now, graceDays: 3);

  test('مفيش تحقق ناجح قبل كده: ماينفعش', () {
    expect(can(last: null), isFalse);
  });

  test('تحقق من يومين: ينفع (مدى الحياة)', () {
    expect(can(last: ms(now.subtract(const Duration(days: 2)))), isTrue);
  });

  test('تحقق من أكتر من 3 أيام: ماينفعش', () {
    expect(can(last: ms(now.subtract(const Duration(days: 4)))), isFalse);
  });

  test('الترخيص انتهى محليًا: ماينفعش حتى لو التحقق حديث', () {
    expect(
        can(
            last: ms(now.subtract(const Duration(hours: 1))),
            exp: now.subtract(const Duration(days: 1))),
        isFalse);
  });

  test('ترخيص لسه سارٍ: ينفع', () {
    expect(
        can(
            last: ms(now.subtract(const Duration(hours: 1))),
            exp: now.add(const Duration(days: 30))),
        isTrue);
  });
}

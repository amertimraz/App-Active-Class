// test/cloud_backup_retry_policy_test.dart
//
// وحدة لـ shouldAttemptCloudUpload (spec 037) — منطق قرار إعادة محاولة
// الرفع السحابي الصرف.
import 'package:active_class/utils/cloud_backup_retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('تحت الحد → دايمًا true', () {
    expect(shouldAttemptCloudUpload(pendingRetries: 0), isTrue);
    expect(shouldAttemptCloudUpload(pendingRetries: 4), isTrue);
  });

  test('عند الحد بالظبط → false', () {
    expect(shouldAttemptCloudUpload(pendingRetries: 5), isFalse);
  });

  test('فوق الحد → false', () {
    expect(shouldAttemptCloudUpload(pendingRetries: 10), isFalse);
  });

  test('حد مخصّص', () {
    expect(
        shouldAttemptCloudUpload(pendingRetries: 2, maxRetries: 3), isTrue);
    expect(
        shouldAttemptCloudUpload(pendingRetries: 3, maxRetries: 3), isFalse);
  });
}

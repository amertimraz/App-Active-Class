import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/utils/web_owner_license.dart';

void main() {
  final now = DateTime(2026, 10, 31, 12);

  test('مدى الحياة (بلا تاريخ انتهاء) = active', () {
    expect(webOwnerLicenseStatus(status: 'active', expiresAt: null, now: now),
        'active');
  });
  test('ساري لحد تاريخ مستقبلي = active', () {
    expect(
        webOwnerLicenseStatus(
            status: 'active',
            expiresAt: now.add(const Duration(days: 1)),
            now: now),
        'active');
  });
  test('انتهى = expired', () {
    expect(
        webOwnerLicenseStatus(
            status: 'active',
            expiresAt: now.subtract(const Duration(seconds: 1)),
            now: now),
        'expired');
  });
  test('موقوف يغلب أي حاجة', () {
    expect(
        webOwnerLicenseStatus(status: 'suspended', expiresAt: null, now: now),
        'suspended');
    expect(
        webOwnerLicenseStatus(
            status: 'suspended',
            expiresAt: now.subtract(const Duration(days: 3)),
            now: now),
        'suspended');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/config/constants.dart';

void main() {
  test('App constants are configured', () {
    expect(APP_NAME, isNotEmpty);
    expect(DATABASE_NAME, endsWith('.db'));
  });
}

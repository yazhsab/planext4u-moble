import 'package:planext4u_core/planext4u_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roles expose stable accessible labels', () {
    expect(AppRole.customer.label, 'Customer');
    expect(AppRole.vendor.description, contains('catalog'));
    expect(AppRole.rider.description, contains('assignments'));
  });

  test('platform locale codes expose the approved deterministic order', () {
    expect(planext4uDefaultLocaleCode, 'en');
    expect(planext4uSupportedLocaleCodes, [
      'en',
      'ta',
      'hi',
      'te',
      'kn',
      'ml',
      'mr',
      'bn',
      'gu',
    ]);
    expect(isPlanext4uLocaleCode('bn'), isTrue);
    expect(isPlanext4uLocaleCode('fr'), isFalse);
  });
}

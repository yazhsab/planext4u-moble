import 'package:planext4u_core/planext4u_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roles expose stable accessible labels', () {
    expect(AppRole.customer.label, 'Customer');
    expect(AppRole.vendor.description, contains('catalog'));
    expect(AppRole.rider.description, contains('assignments'));
  });
}

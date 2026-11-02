import 'package:flutter_test/flutter_test.dart';

import '../../../tool/validate_release_inputs.dart';

Map<String, String> validInputs() => {
  for (final key in protectedReleaseKeys) key: 'synthetic-protected-value',
  'RELEASE_APP': 'customer',
  'RELEASE_VERSION': '1.2.3',
  'RELEASE_BUILD_NUMBER': '42',
  'RELEASE_API_BASE_URL': 'https://api.planext4u.net',
  'RELEASE_BANK_LINK_LAUNCH_ORIGIN': 'https://bank.planext4u.net',
  'IOS_DEVELOPMENT_TEAM': 'ABCDEFGHIJ',
  'MOBILE_SIGNING_ROTATION_APPROVED': 'true',
};

void main() {
  test(
    'vendor and rider releases require an approved bank origin without exposing values',
    () {
      for (final role in ['vendor', 'rider']) {
        for (final origin in [
          '',
          'http://bank.planext4u.net',
          'https://bank.example.test',
          'https://secret@bank.planext4u.net',
          'https://bank.planext4u.net/path',
          'https://bank.planext4u.net?secret=private',
        ]) {
          final errors = validateReleaseInputs(
            validInputs()
              ..['RELEASE_APP'] = role
              ..['RELEASE_BANK_LINK_LAUNCH_ORIGIN'] = origin,
          );
          expect(errors.join(), contains('RELEASE_BANK_LINK_LAUNCH_ORIGIN'));
          expect(errors.join(), isNot(contains('secret=private')));
        }
      }
      expect(
        validateReleaseInputs(
          validInputs()..remove('RELEASE_BANK_LINK_LAUNCH_ORIGIN'),
        ),
        isEmpty,
      );
    },
  );
  test('all roles accept structurally valid protected inputs', () {
    for (final role in ['customer', 'vendor', 'rider']) {
      expect(
        validateReleaseInputs(validInputs()..['RELEASE_APP'] = role),
        isEmpty,
      );
    }
  });
  test('every missing signing/provider input is named without values', () {
    for (final key in protectedReleaseKeys) {
      final errors = validateReleaseInputs(validInputs()..remove(key));
      expect(errors.join(), contains(key));
      expect(errors.join(), isNot(contains('synthetic-protected-value')));
    }
  });
  test('unsafe versions and invalid Android build numbers are rejected', () {
    for (final version in [
      '1.0.0\$(touch /tmp/injected)',
      '01.0.0',
      '1.0.0-beta',
      '1.0',
    ]) {
      expect(
        validateReleaseInputs(validInputs()..['RELEASE_VERSION'] = version),
        isNotEmpty,
      );
    }
    for (final build in ['0', '-1', '2100000001', '1\n2', '1;exit 0']) {
      expect(
        validateReleaseInputs(validInputs()..['RELEASE_BUILD_NUMBER'] = build),
        isNotEmpty,
      );
    }
  });
  test(
    'absent, local, credentialed and placeholder API endpoints fail closed',
    () {
      for (final url in [
        '',
        'http://api.planext4u.net',
        'https://localhost',
        'https://127.0.0.1',
        'https://api.example.com',
        'https://a:b@api.planext4u.net',
        'https://api.planext4u.net?token=secret',
      ]) {
        final errors = validateReleaseInputs(
          validInputs()..['RELEASE_API_BASE_URL'] = url,
        );
        expect(errors, isNotEmpty);
        expect(errors.join(), isNot(contains('token=secret')));
      }
    },
  );
  test('unrecorded historical signing rotation blocks signing', () {
    expect(
      validateReleaseInputs(
        validInputs()..remove('MOBILE_SIGNING_ROTATION_APPROVED'),
      ),
      isNotEmpty,
    );
  });
}

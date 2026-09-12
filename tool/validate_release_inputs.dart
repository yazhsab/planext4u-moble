import 'dart:io';

const protectedReleaseKeys = [
  'ANDROID_KEYSTORE_B64',
  'ANDROID_KEYSTORE_PASSWORD',
  'ANDROID_KEY_ALIAS',
  'ANDROID_KEY_PASSWORD',
  'IOS_DISTRIBUTION_CERTIFICATE_B64',
  'IOS_CERTIFICATE_PASSWORD',
  'IOS_PROVISIONING_PROFILE_B64',
  'IOS_EXPORT_OPTIONS_PLIST_B64',
  'IOS_DEVELOPMENT_TEAM',
  'MOBILE_ANDROID_FIREBASE_CONFIG_B64',
  'MOBILE_IOS_FIREBASE_CONFIG_B64',
];

List<String> validateReleaseInputs(Map<String, String> values) {
  final errors = <String>[];
  if (!['customer', 'vendor', 'rider'].contains(values['RELEASE_APP'])) {
    errors.add('RELEASE_APP must select customer, vendor or rider.');
  }
  if (!RegExp(
    r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$',
  ).hasMatch(values['RELEASE_VERSION'] ?? '')) {
    errors.add(
      'RELEASE_VERSION must be a numeric store version such as 1.0.0.',
    );
  }
  final build = values['RELEASE_BUILD_NUMBER'] ?? '';
  if (!RegExp(r'^[1-9][0-9]{0,9}$').hasMatch(build) ||
      (int.tryParse(build) ?? 0) > 2100000000) {
    errors.add('RELEASE_BUILD_NUMBER must be between 1 and 2100000000.');
  }
  try {
    final raw = values['RELEASE_API_BASE_URL'] ?? '';
    final uri = Uri.parse(raw);
    final host = uri.host.toLowerCase();
    if (raw.trim() != raw ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !RegExp(
          r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
        ).hasMatch(host) ||
        RegExp(
          r'(?:^|\.)(?:localhost|local|internal|test|invalid|example|example\.(?:com|net|org))$',
        ).hasMatch(host)) {
      errors.add('RELEASE_API_BASE_URL must be a public HTTPS origin.');
    }
  } on FormatException {
    errors.add('RELEASE_API_BASE_URL must be a public HTTPS origin.');
  }
  if (values['MOBILE_SIGNING_ROTATION_APPROVED'] != 'true') {
    errors.add('Signing owner must record legacy credential retirement first.');
  }
  for (final key in protectedReleaseKeys) {
    if ((values[key] ?? '').trim().isEmpty) {
      errors.add('Protected role environment is missing $key.');
    }
  }
  if (!RegExp(
    r'^[A-Z0-9]{10}$',
  ).hasMatch(values['IOS_DEVELOPMENT_TEAM'] ?? '')) {
    errors.add('IOS_DEVELOPMENT_TEAM must be a ten-character team identifier.');
  }
  return errors;
}

void main() {
  final errors = validateReleaseInputs(Platform.environment);
  if (errors.isNotEmpty) {
    errors.forEach(stderr.writeln);
    exitCode = 1;
  } else {
    stdout.writeln('Protected mobile release input structure passed.');
  }
}

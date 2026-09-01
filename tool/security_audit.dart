import 'dart:io';

const _applications = ['customer', 'vendor', 'rider'];
const _textExtensions = {
  '.dart',
  '.gradle',
  '.kts',
  '.md',
  '.plist',
  '.json',
  '.toml',
  '.xml',
  '.xcconfig',
  '.xcscheme',
  '.yaml',
  '.yml',
};

void main() {
  final failures = <String>[];
  _checkSensitiveFiles(failures);
  _checkHighConfidenceSecrets(failures);
  for (final application in _applications) {
    _checkAndroid(application, failures);
    _checkIos(application, failures);
  }
  _checkProductionEndpoints(failures);

  if (failures.isNotEmpty) {
    failures.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Security audit passed: secrets, transport, backup, signing and privacy '
    'boundaries are fail-closed for customer, vendor and rider.',
  );
}

void _checkSensitiveFiles(List<String> failures) {
  const prohibitedNames = {'google-services.json', 'GoogleService-Info.plist'};
  const prohibitedExtensions = {
    '.jks',
    '.keystore',
    '.p8',
    '.p12',
    '.mobileprovision',
  };
  for (final path in _repositoryFiles()) {
    final name = path.split(Platform.pathSeparator).last;
    final extension = _extension(path);
    if (prohibitedNames.contains(name) ||
        prohibitedExtensions.contains(extension)) {
      failures.add(
        'Protected credential/signing file must not be committed: $path',
      );
    }
  }
}

void _checkHighConfidenceSecrets(List<String> failures) {
  const policySourceFiles = {
    'tool/security_audit.dart',
    'tool/validate_ci.dart',
    'tool/validate_phase2_integrations.dart',
  };
  final privateKeyHeader = ['BEGIN', 'PRIVATE', 'KEY'].join(' ');
  final patterns = <String, RegExp>{
    'private key': RegExp(privateKeyHeader),
    'AWS access key': RegExp(r'AKIA[0-9A-Z]{16}'),
    'Google API key': RegExp(r'AIza[0-9A-Za-z_-]{35}'),
    'GitHub token': RegExp(r'ghp_[0-9A-Za-z]{36}'),
    'Stripe live secret': RegExp(r'sk_live_[0-9A-Za-z]{16,}'),
  };
  for (final path in _repositoryFiles()) {
    if (!_textExtensions.contains(_extension(path)) ||
        policySourceFiles.contains(path)) {
      continue;
    }
    final file = File(path);
    if (file.lengthSync() > 5 * 1024 * 1024) continue;
    final content = file.readAsStringSync();
    for (final entry in patterns.entries) {
      if (entry.value.hasMatch(content)) {
        failures.add('Possible ${entry.key} found in $path');
      }
    }
  }
}

void _checkAndroid(String application, List<String> failures) {
  final manifest = _read(
    'apps/$application/android/app/src/main/AndroidManifest.xml',
  );
  final gradle = _read('apps/$application/android/app/build.gradle.kts');
  for (final marker in [
    'android:allowBackup="false"',
    'android:fullBackupContent="false"',
    r'android:usesCleartextTraffic="${usesCleartextTraffic}"',
  ]) {
    _expect(failures, manifest, marker, '$application Android manifest');
  }
  for (final marker in [
    'ANDROID_KEYSTORE_PATH',
    'ANDROID_KEYSTORE_PASSWORD',
    'ANDROID_KEY_ALIAS',
    'ANDROID_KEY_PASSWORD',
    'protectedAndroidSigningPresent',
    'Production release signing must be supplied by the protected CI environment.',
    'manifestPlaceholders["usesCleartextTraffic"] = "false"',
  ]) {
    _expect(failures, gradle, marker, '$application Android release boundary');
  }
  if (gradle.contains('storePassword = "') ||
      gradle.contains('keyPassword = "')) {
    failures.add(
      '$application Android signing contains a hard-coded password.',
    );
  }
}

void _checkIos(String application, List<String> failures) {
  final privacy = _read('apps/$application/ios/Runner/PrivacyInfo.xcprivacy');
  final project = _read(
    'apps/$application/ios/Runner.xcodeproj/project.pbxproj',
  );
  for (final marker in [
    '<key>NSPrivacyTracking</key>',
    '<false/>',
    '<key>NSPrivacyCollectedDataTypes</key>',
  ]) {
    _expect(failures, privacy, marker, '$application iOS privacy manifest');
  }
  _expect(
    failures,
    project,
    'PrivacyInfo.xcprivacy in Resources',
    '$application iOS resource build phase',
  );
  if (privacy.contains('<key>NSPrivacyTracking</key>\n\t<true/>')) {
    failures.add(
      '$application iOS privacy manifest unexpectedly enables tracking.',
    );
  }
}

void _checkProductionEndpoints(List<String> failures) {
  for (final path in [
    'packages/config/lib/src/app_config.dart',
    '.github/workflows/mobile-ci.yml',
    '.github/workflows/staging-smoke.yml',
  ]) {
    final content = _read(path);
    for (final line in content.split('\n')) {
      if (!line.contains('http://')) continue;
      if (line.contains('localhost') ||
          line.contains('127.0.0.1') ||
          line.contains('10.0.2.2')) {
        continue;
      }
      failures.add('Non-local cleartext endpoint in $path: ${line.trim()}');
    }
  }
}

Iterable<String> _repositoryFiles() sync* {
  final result = Process.runSync('git', [
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
  ], stdoutEncoding: SystemEncoding());
  if (result.exitCode != 0) {
    throw StateError('Unable to enumerate repository files.');
  }
  for (final path in (result.stdout as String).split('\n')) {
    if (path.isEmpty || path.startsWith('.understand-anything/')) continue;
    final entity = File(path);
    if (entity.existsSync()) yield path;
  }
}

String _extension(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final index = name.lastIndexOf('.');
  return index < 0 ? '' : name.substring(index);
}

String _read(String path) =>
    File(path).existsSync() ? File(path).readAsStringSync() : '';

void _expect(
  List<String> failures,
  String content,
  String marker,
  String context,
) {
  if (!content.contains(marker)) failures.add('$context missing: $marker');
}

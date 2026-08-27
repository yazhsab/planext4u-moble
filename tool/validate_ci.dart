import 'dart:io';

void main() {
  final failures = <String>[];
  final mobile = _read('.github/workflows/mobile-ci.yml');
  final smoke = _read('.github/workflows/staging-smoke.yml');
  final integration = _read(
    'apps/customer/integration_test/customer_vertical_slice_test.dart',
  );
  final root = _read('pubspec.yaml');

  for (final required in [
    'FLUTTER_VERSION: 3.41.4',
    'dart run melos run verify',
    'app: [customer, vendor, rider]',
    '--flavor development',
    '--flavor staging',
    '--flavor production',
    'flutter clean',
    'app-production-debug.apk',
    'MOB-E2E-001 Android emulator',
    'Enable KVM acceleration',
    'test -r /dev/kvm && test -w /dev/kvm',
    'customer_vertical_slice_test.dart',
  ]) {
    _expect(failures, mobile, required, 'mobile CI');
  }
  for (final required in [
    'environment: staging',
    'complete synthetic customer journey',
    'tool/staging_smoke.dart',
    'https://staging-api.planext4u.net',
  ]) {
    _expect(failures, smoke, required, 'staging smoke');
  }
  for (final stage in ['consent', 'login', 'location', 'home', 'catalog']) {
    _expect(failures, integration, stage, 'MOB-E2E-001');
  }
  _expect(failures, root, 'dart run tool/validate_ci.dart', 'root gate');

  for (final workflow in {
    'mobile CI': mobile,
    'staging smoke': smoke,
  }.entries) {
    for (final line in workflow.value.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('- uses:') && !trimmed.startsWith('uses:')) {
        continue;
      }
      final reference = trimmed
          .substring(trimmed.indexOf('uses:') + 'uses:'.length)
          .trim()
          .split(RegExp(r'\s+'))
          .first;
      final revision = reference.split('@').last;
      if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(revision)) {
        failures.add('${workflow.key} action is not commit-pinned: $reference');
      }
    }
  }

  final combined = '$mobile\n$smoke';
  for (final prohibited in [
    'admin@planext4u.com',
    'Planext@2026',
    'BEGIN PRIVATE KEY',
  ]) {
    if (combined.contains(prohibited)) {
      failures.add('CI contains prohibited credential material.');
    }
  }
  if (failures.isNotEmpty) {
    failures.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln('Validated clean-checkout mobile CI and staging smoke gates.');
}

String _read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : '';
}

void _expect(
  List<String> failures,
  String content,
  String expected,
  String context,
) {
  if (!content.contains(expected)) failures.add('$context missing: $expected');
}

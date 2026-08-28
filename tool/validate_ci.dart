import 'dart:io';

void main() {
  final failures = <String>[];
  final mobile = _read('.github/workflows/mobile-ci.yml');
  final smoke = _read('.github/workflows/staging-smoke.yml');
  final integration = _read(
    'apps/customer/integration_test/customer_vertical_slice_test.dart',
  );
  final vendorIntegration = _read(
    'apps/vendor/integration_test/vendor_phase4_test.dart',
  );
  final riderIntegration = _read(
    'apps/rider/integration_test/rider_phase4_test.dart',
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
    'runs-on: macos-26',
    'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1',
    'MOB-E2E-001/002/003/004/005/006/007 Android emulator (2 GB)',
    'Enable KVM acceleration',
    'test -r /dev/kvm && test -w /dev/kvm',
    'customer_vertical_slice_test.dart',
    'vendor_phase4_test.dart',
    'rider_phase4_test.dart',
    '-memory 2048',
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
  for (final required in [
    'MOB-E2E-002',
    'MOB-E2E-003',
    'successes / 100',
    'walletValue.reconciles',
  ]) {
    _expect(failures, integration, required, 'Phase 3 mobile E2E');
  }
  for (final required in [
    'MOB-E2E-004',
    'slot_lock',
    'payment',
    'reschedule',
    'START_OTP_REQUIRED',
    'completion_evidence',
    'confirm_completion',
  ]) {
    _expect(failures, integration, required, 'Phase 4 service booking E2E');
  }
  for (final required in [
    'MOB-E2E-005',
    'server_price',
    'restaurant_READY',
    'dispatch_RIDER_ASSIGNED',
    'timeout_refund',
    'chatExpiresAfterDelivery',
  ]) {
    _expect(failures, integration, required, 'Phase 4 food E2E');
  }
  for (final required in [
    'MOB-E2E-006',
    'private_documents',
    'field_visit_passed',
    'admin_approval',
    'inventory_revision',
    'settlement-v1',
  ]) {
    _expect(failures, vendorIntegration, required, 'Phase 4 vendor E2E');
  }
  for (final required in [
    'MOB-E2E-007',
    'atomic_accept_conflict',
    'pickup_offline',
    'ordered_recovery',
    'pod_photo_otp',
    'chat_redaction',
    'rider-commission-v1',
  ]) {
    _expect(failures, riderIntegration, required, 'Phase 4 rider E2E');
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

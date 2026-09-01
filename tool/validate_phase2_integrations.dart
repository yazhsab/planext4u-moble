import 'dart:convert';
import 'dart:io';

const _apps = <String, String>{
  'customer': 'net.planext4u.customer',
  'vendor': 'net.planext4u.vendor',
  'rider': 'net.planext4u.rider',
};

const _suffixes = <String, String>{
  'development': '.dev',
  'staging': '.staging',
  'production': '',
};

void main(List<String> arguments) {
  final failures = <String>[];
  final customerMain = _read('apps/customer/lib/main.dart');
  final vendorMain = _read('apps/vendor/lib/main.dart');
  final riderMain = _read('apps/rider/lib/main.dart');
  final roleRuntime = _read('packages/experience/lib/src/role_runtime.dart');
  final rolePush = _read('packages/experience/lib/src/role_push.dart');
  final customerPush = _read('apps/customer/lib/push_registration.dart');
  final transactions = _read('packages/experience/lib/src/transactions.dart');
  final roleOperations = _read(
    'packages/experience/lib/src/role_operations.dart',
  );
  final rtc = _read('packages/experience/lib/src/phase5_screens.dart');

  _containsAll(failures, roleRuntime, [
    'PlatformInstallIdStore',
    'diagnostics: widget.apiDiagnostics',
  ], 'shared role runtime');
  for (final entry in {
    'customer runtime': customerMain,
    'vendor runtime': vendorMain,
    'rider runtime': riderMain,
  }.entries) {
    _containsAll(failures, entry.value, [
      'MobileObservability',
      'apiDiagnostics: observability.apiDiagnostics',
    ], entry.key);
  }
  _containsAll(
    failures,
    _read('packages/observability/lib/src/runtime_metrics.dart'),
    ['ApiTelemetryDiagnostics(telemetry)', 'StructuredTelemetry('],
    'shared mobile observability',
  );
  _containsAll(failures, customerPush, [
    'PushRegistrationStatus',
    'Future<void> retry()',
    'uri.host.toLowerCase() == allowedHost.toLowerCase()',
    'uri.scheme == allowedScheme',
  ], 'customer push');
  _containsAll(failures, rolePush, [
    'RolePushRegistrationStatus',
    'Future<void> retry()',
    'allowedHost:',
    'allowedScheme:',
  ], 'role push');
  _containsAll(failures, transactions, [
    "'CAPTURED', 'RECONCILED'",
    '_statusForPayment',
    'Payment was not completed',
  ], 'webhook-authoritative payments');
  _containsAll(failures, roleOperations, [
    'RiderCommandQueuePolicy.maxCommands',
    'command.validate()',
    'navigationDestination',
    'RiderRegistrationDraft',
    'requiredDocumentKinds',
    'Select an approved rider service zone.',
    'Vendor business and owner identity documents are required.',
  ], 'rider reliability');
  _containsAll(failures, riderMain, [
    'RiderMapsLauncher.open',
    'LaunchMode.externalApplication',
  ], 'rider navigation provider');
  _containsAll(failures, rtc, [
    'SocialRtcOfferProvider',
    'Secure calling is unavailable',
  ], 'WebRTC fail-closed boundary');

  for (final app in _apps.keys) {
    _containsAll(
      failures,
      _read('apps/$app/android/settings.gradle.kts'),
      ['com.google.gms.google-services', '4.5.0'],
      '$app Android Firebase plugin',
    );
    _containsAll(
      failures,
      _read('apps/$app/android/app/build.gradle.kts'),
      [
        'protectedFirebaseConfigPresent',
        'apply(plugin = "com.google.gms.google-services")',
      ],
      '$app protected Firebase boundary',
    );
    _containsAll(
      failures,
      _read('apps/$app/ios/Runner/Runner.entitlements'),
      ['aps-environment'],
      '$app APNS entitlement',
    );
  }

  final contractRequirements = <String, List<String>>{
    'packages/api_client/contracts/transaction.openapi.json': [
      '/v1/checkout/orders',
      '/v1/payments/{payment_id}',
    ],
    'packages/api_client/contracts/supply.openapi.json': [
      '/v1/vendor/work',
      '/v1/vendor/work/{work_id}/transition',
    ],
    'packages/api_client/contracts/fulfillment.openapi.json': [
      '/v1/rider/offline-recovery',
      '/v1/rider/tasks/{task_id}/completion',
    ],
    'packages/api_client/contracts/social.openapi.json': [
      '/v1/social/media',
      '/v1/social/calls/{call_id}/signals',
    ],
  };
  for (final entry in contractRequirements.entries) {
    _containsAll(failures, _read(entry.key), entry.value, entry.key);
  }

  final combinedRuntime =
      '$customerMain\n$vendorMain\n$riderMain\n$roleOperations\n$rtc';
  for (final forbidden in [
    'device-rider-mobile-runtime-001',
    'device-vendor-mobile-runtime-001',
    'mobile-webrtc-offer-v1',
    'asset-private-rider',
    'asset-private-business',
    "'phone_masked': '******1234'",
    'BEGIN PRIVATE KEY',
  ]) {
    if (combinedRuntime.contains(forbidden)) {
      failures.add('Runtime contains forbidden Phase 2 material: $forbidden');
    }
  }

  final configRoot = _argument(arguments, '--provider-config-root=');
  if (configRoot != null) {
    _validateProtectedFirebaseConfigs(failures, Directory(configRoot));
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Phase 2 integration validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    configRoot == null
        ? 'Validated Phase 2 source boundaries for customer, vendor and rider; protected provider configs were not requested.'
        : 'Validated Phase 2 source boundaries and all 18 protected Firebase app/platform configs.',
  );
}

void _validateProtectedFirebaseConfigs(List<String> failures, Directory root) {
  if (!root.isAbsolute || !root.existsSync()) {
    failures.add(
      'Provider config root must be an existing absolute directory.',
    );
    return;
  }
  for (final app in _apps.entries) {
    for (final flavor in _suffixes.entries) {
      final expectedId = '${app.value}${flavor.value}';
      final directory = '${root.path}/${app.key}/${flavor.key}';
      final android = File('$directory/google-services.json');
      final ios = File('$directory/GoogleService-Info.plist');
      if (!android.existsSync()) {
        failures.add(
          'Missing protected Android config: ${app.key}/${flavor.key}',
        );
      } else {
        try {
          final json = jsonDecode(android.readAsStringSync());
          final clients = json is Map<String, Object?> ? json['client'] : null;
          final ids = clients is List<Object?>
              ? clients
                    .whereType<Map<String, Object?>>()
                    .map((client) => client['client_info'])
                    .whereType<Map<String, Object?>>()
                    .map((info) => info['android_client_info'])
                    .whereType<Map<String, Object?>>()
                    .map((info) => info['package_name'])
                    .whereType<String>()
                    .toSet()
              : const <String>{};
          if (!ids.contains(expectedId)) {
            failures.add(
              'Android Firebase package mismatch for ${app.key}/${flavor.key}.',
            );
          }
        } catch (_) {
          failures.add(
            'Invalid Android Firebase JSON for ${app.key}/${flavor.key}.',
          );
        }
      }
      if (!ios.existsSync()) {
        failures.add('Missing protected iOS config: ${app.key}/${flavor.key}');
      } else {
        final plist = ios.readAsStringSync();
        if (!_plistValue(plist, 'BUNDLE_ID').contains(expectedId) ||
            _plistValue(plist, 'GOOGLE_APP_ID').isEmpty) {
          failures.add(
            'iOS Firebase bundle mismatch for ${app.key}/${flavor.key}.',
          );
        }
      }
    }
  }
}

String _plistValue(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>',
  ).firstMatch(plist);
  return match?.group(1)?.trim() ?? '';
}

void _containsAll(
  List<String> failures,
  String contents,
  List<String> required,
  String context,
) {
  for (final value in required) {
    if (!contents.contains(value)) failures.add('$context missing `$value`.');
  }
}

String _read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : '';
}

String? _argument(List<String> arguments, String prefix) => arguments
    .where((value) => value.startsWith(prefix))
    .firstOrNull
    ?.substring(prefix.length);

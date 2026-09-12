import 'dart:convert';
import 'dart:io';

const _applications = ['customer', 'vendor', 'rider'];
const _locales = ['en', 'ta', 'hi', 'te', 'kn', 'ml', 'mr', 'bn', 'gu'];

void main() {
  final failures = <String>[];
  _validateApplications(failures);
  _validateReleasePolicy(failures);
  _validatePrivacyAndStore(failures);
  _validateAutomation(failures);
  _validateDocumentation(failures);

  if (failures.isNotEmpty) {
    failures.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Validated Phase 3 source controls for customer, vendor and rider: '
    'accessibility, locale wiring, observability, privacy, signing, security, '
    'release provenance and progressive rollout.',
  );
}

void _validateApplications(List<String> failures) {
  for (final application in _applications) {
    final main = _read('apps/$application/lib/main.dart');
    for (final marker in [
      'Planext4uLocalizations.supportedLocales',
      'Planext4uLocalizations.localizationsDelegates',
      'Planext4uAdaptiveAppBuilder',
      'MobileObservability',
      '_installRuntimeErrorBoundary',
      'runtimeMetrics.firstFrame',
    ]) {
      _expect(failures, main, marker, '$application runtime');
    }

    final gradle = _read('apps/$application/android/app/build.gradle.kts');
    for (final marker in [
      'protectedAndroidSigningPresent',
      'ANDROID_KEYSTORE_PATH',
      'Production release signing must be supplied by the protected CI environment.',
    ]) {
      _expect(
        failures,
        gradle,
        marker,
        '$application protected Android signing',
      );
    }

    final privacy = _read('apps/$application/ios/Runner/PrivacyInfo.xcprivacy');
    _expect(
      failures,
      privacy,
      'NSPrivacyCollectedDataTypes',
      '$application privacy manifest',
    );
    _expect(
      failures,
      privacy,
      'NSPrivacyTracking',
      '$application privacy manifest',
    );
    final project = _read(
      'apps/$application/ios/Runner.xcodeproj/project.pbxproj',
    );
    _expect(
      failures,
      project,
      'PrivacyInfo.xcprivacy in Resources',
      '$application iOS resources',
    );
  }

  final localization = _read('packages/experience/lib/src/localization.dart');
  for (final locale in _locales) {
    _expect(failures, localization, "Locale('$locale')", 'locale catalogue');
    _expect(failures, localization, "'$locale':", 'locale translations');
  }
  final adaptive = _read(
    'packages/design_system/lib/src/adaptive_experience.dart',
  );
  for (final marker in [
    'disableAnimations',
    'accessibleNavigation',
    'ReadingOrderTraversalPolicy',
    'Planext4uExperiencePolicy.dataSaverOf',
    'cacheWidth',
  ]) {
    _expect(failures, adaptive, marker, 'adaptive experience');
  }
}

void _validateReleasePolicy(List<String> failures) {
  final policy = _jsonObject('release/rollout/policy.json', failures);
  final expectedStages = [
    'internal',
    'cityPilot',
    'percent5',
    'percent25',
    'percent50',
    'percent100',
  ];
  if (!_sameStrings(policy['stages'], expectedStages)) {
    failures.add(
      'Rollout policy must contain the ordered six-stage progression.',
    );
  }
  final minimum = policy['minimum_sample'];
  if (minimum is! Map ||
      minimum['sessions'] != 1000 ||
      minimum['checkout_attempts'] != 100) {
    failures.add(
      'Rollout policy minimum sample does not match source guardrails.',
    );
  }
  final rolloutSource = _read(
    'packages/observability/lib/src/release_health.dart',
  );
  for (final marker in [
    'rollbackCrashFreeSessionPercent = 99.5',
    'rollbackPaymentFailurePercent = 3',
    'rollbackOrderFailurePercent = 3',
    'rollbackNotificationLossPercent = 5',
    'rollbackBackendAvailabilityPercent = 99',
    'maximumApiP95Milliseconds = 400',
  ]) {
    _expect(failures, rolloutSource, marker, 'release guardrail source');
  }
  _expect(
    failures,
    _read('pubspec.yaml'),
    'dart run tool/validate_phase3_release.dart',
    'workspace verification gate',
  );
}

void _validatePrivacyAndStore(List<String> failures) {
  final safety = _jsonObject(
    'release/privacy/android-data-safety.json',
    failures,
  );
  final metadata = _jsonObject('release/store/metadata.json', failures);
  final safetyApps = safety['applications'];
  final storeApps = metadata['applications'];
  for (final application in _applications) {
    if (safetyApps is! Map || safetyApps[application] is! Map) {
      failures.add('Android data-safety declaration missing $application.');
    }
    if (storeApps is! Map || storeApps[application] is! Map) {
      failures.add('Store metadata missing $application.');
    }
  }
  if (safety['review_status'] != 'privacy_and_legal_review_required') {
    failures.add(
      'Android data-safety declaration must retain its external review gate.',
    );
  }
  if (metadata['review_status'] != 'store_owner_and_legal_review_required') {
    failures.add('Store metadata must retain its external review gate.');
  }
  final notes = metadata['localized_release_notes'];
  if (notes is! Map ||
      !_locales.every(
        (locale) => (notes[locale] as String?)?.trim().isNotEmpty ?? false,
      )) {
    failures.add('Store release notes must cover all nine supported locales.');
  }
}

void _validateAutomation(List<String> failures) {
  final security = _read('.github/workflows/mobile-security.yml');
  for (final marker in [
    'tool/security_audit.dart',
    'tool/validate_phase3_release.dart',
    'google/osv-scanner-action/osv-scanner-action@baa4139e56d6312335d899e6ba045fa16d1d3d0b',
    'gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e',
  ]) {
    _expect(failures, security, marker, 'mobile security workflow');
  }

  final release = _read('.github/workflows/mobile-release.yml');
  for (final marker in [
    r'environment: production-${{ inputs.app }}',
    'dart run tool/validate_release_inputs.dart',
    'MOBILE_SIGNING_ROTATION_APPROVED',
    'persist-credentials: false',
    r'--build-name="$RELEASE_VERSION"',
    r'--build-number="$RELEASE_BUILD_NUMBER"',
    r'--dart-define="API_BASE_URL=$RELEASE_API_BASE_URL"',
    'ANDROID_KEYSTORE_B64',
    'IOS_DISTRIBUTION_CERTIFICATE_B64',
    'MOBILE_ANDROID_FIREBASE_CONFIG_B64',
    'MOBILE_IOS_FIREBASE_CONFIG_B64',
    'flutter build appbundle',
    'flutter build ipa',
    '--split-debug-info',
    'actions/attest-build-provenance@977bb373ede98d70efdf65b84cb5f73e068dcc2a',
    'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
    'Store promotion is deliberately manual',
  ]) {
    _expect(failures, release, marker, 'protected mobile release workflow');
  }
  for (final workflow in [security, release]) {
    for (final line in workflow.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('- uses:') && !trimmed.startsWith('uses:'))
        continue;
      final reference = trimmed
          .substring(trimmed.indexOf('uses:') + 5)
          .trim()
          .split(RegExp(r'\s+'))
          .first;
      final revision = reference.split('@').last;
      if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(revision)) {
        failures.add('Phase 3 action is not commit-pinned: $reference');
      }
    }
  }
}

void _validateDocumentation(List<String> failures) {
  for (final path in [
    'docs/phase-3/PRODUCTION_HARDENING_EXIT_REVIEW.md',
    'docs/phase-3/RELEASE_AND_ROLLBACK_RUNBOOK.md',
    'docs/phase-3/STORE_PRIVACY_CHECKLIST.md',
    'docs/phase-3/SECURITY_AND_PERFORMANCE_RUNBOOK.md',
  ]) {
    final content = _read(path);
    if (content.isEmpty) failures.add('Missing Phase 3 evidence: $path');
    if (RegExp(r'\b(TODO|TBD)\b').hasMatch(content)) {
      failures.add(
        'Phase 3 evidence contains an unresolved placeholder: $path',
      );
    }
  }
}

Map<String, Object?> _jsonObject(String path, List<String> failures) {
  try {
    final decoded = jsonDecode(_read(path));
    if (decoded is Map<String, Object?>) return decoded;
  } on FormatException catch (error) {
    failures.add('$path is invalid JSON: ${error.message}');
    return const {};
  }
  failures.add('$path must be a JSON object.');
  return const {};
}

bool _sameStrings(Object? value, List<String> expected) =>
    value is List &&
    value.length == expected.length &&
    Iterable.generate(
      expected.length,
    ).every((index) => value[index] == expected[index]);

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

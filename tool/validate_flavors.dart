import 'dart:io';

const applications = <String, ({String identifier, String path})>{
  'customer': (identifier: 'net.planext4u.customer', path: '/app'),
  'vendor': (identifier: 'net.planext4u.vendor', path: '/vendor'),
  'rider': (identifier: 'net.planext4u.rider', path: '/rider'),
};

const flavors =
    <String, ({String identifierSuffix, String host, String schemeSuffix})>{
      'development': (
        identifierSuffix: '.dev',
        host: 'dev.planext4u.net',
        schemeSuffix: '-dev',
      ),
      'staging': (
        identifierSuffix: '.staging',
        host: 'staging.planext4u.net',
        schemeSuffix: '-staging',
      ),
      'production': (
        identifierSuffix: '',
        host: 'planext4u.net',
        schemeSuffix: '',
      ),
    };

void main() {
  final failures = <String>[];
  for (final MapEntry(key: appName, value: app) in applications.entries) {
    final appRoot = Directory('apps/$appName');
    if (!appRoot.existsSync()) {
      failures.add('Missing application directory: ${appRoot.path}');
      continue;
    }

    final gradle = read('apps/$appName/android/app/build.gradle.kts');
    expectContains(
      failures,
      gradle,
      'applicationId = "${app.identifier}"',
      '$appName Android base identifier',
    );
    expectAbsent(
      failures,
      gradle,
      'signingConfigs.getByName("debug")',
      '$appName release signing boundary',
    );

    final manifest = read(
      'apps/$appName/android/app/src/main/AndroidManifest.xml',
    );
    for (final token in [
      r'${deepLinkHost}',
      r'${deepLinkScheme}',
      r'${deepLinkPathPrefix}',
      'android:autoVerify="true"',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_FINE_LOCATION',
    ]) {
      expectContains(
        failures,
        manifest,
        token,
        '$appName Android deep-link manifest',
      );
    }
    expectAbsent(
      failures,
      manifest,
      'android.permission.ACCESS_BACKGROUND_LOCATION',
      '$appName foreground-only location boundary',
    );

    final infoPlist = read('apps/$appName/ios/Runner/Info.plist');
    final entitlements = read('apps/$appName/ios/Runner/Runner.entitlements');
    final podfile = read('apps/$appName/ios/Podfile');
    final xcodeProject = read(
      'apps/$appName/ios/Runner.xcodeproj/project.pbxproj',
    );
    expectContains(
      failures,
      podfile,
      "platform :ios, '13.0'",
      '$appName iOS deployment target',
    );
    expectContains(
      failures,
      infoPlist,
      r'$(DEEPLINK_SCHEME)',
      '$appName iOS custom scheme',
    );
    expectContains(
      failures,
      infoPlist,
      'NSLocationWhenInUseUsageDescription',
      '$appName iOS location purpose',
    );
    expectAbsent(
      failures,
      infoPlist,
      'NSLocationAlwaysUsageDescription',
      '$appName foreground-only location boundary',
    );
    expectContains(
      failures,
      entitlements,
      r'applinks:$(DEEPLINK_HOST)',
      '$appName iOS associated domain',
    );

    for (final MapEntry(key: flavorName, value: flavor) in flavors.entries) {
      expectContains(
        failures,
        gradle,
        'create("$flavorName")',
        '$appName Android $flavorName flavor',
      );
      expectContains(
        failures,
        gradle,
        '"${flavor.host}"',
        '$appName Android $flavorName host',
      );

      final schemePath =
          'apps/$appName/ios/Runner.xcodeproj/xcshareddata/xcschemes/'
          '$flavorName.xcscheme';
      final scheme = read(schemePath);
      for (final configuration in [
        'Debug-$flavorName',
        'Profile-$flavorName',
        'Release-$flavorName',
      ]) {
        expectContains(
          failures,
          scheme,
          configuration,
          '$appName iOS $flavorName scheme',
        );
      }
      expectContains(
        failures,
        scheme,
        'buildConfiguration = "Debug-$flavorName"',
        '$appName iOS $flavorName test action',
      );
      expectContains(
        failures,
        scheme,
        'BuildableName = "RunnerTests.xctest"',
        '$appName iOS $flavorName test target',
      );
      expectContains(
        failures,
        podfile,
        "'Debug-$flavorName' => :debug",
        '$appName CocoaPods $flavorName mapping',
      );
      expectContains(
        failures,
        xcodeProject,
        '/* Debug-$flavorName */',
        '$appName Xcode test configuration',
      );

      for (final mode in ['Debug', 'Profile', 'Release']) {
        final configPath =
            'apps/$appName/ios/Flutter/$mode-$flavorName.xcconfig';
        final config = read(configPath);
        final expectedIdentifier =
            '${app.identifier}${flavor.identifierSuffix}';
        for (final expected in [
          'APP_ENV = $flavorName',
          'PRODUCT_BUNDLE_IDENTIFIER = $expectedIdentifier',
          'DEEPLINK_HOST = ${flavor.host}',
          'DEEPLINK_SCHEME = planext4u-$appName${flavor.schemeSuffix}',
          'DEEPLINK_PATH_PREFIX = ${app.path}',
        ]) {
          expectContains(
            failures,
            config,
            expected,
            '$appName iOS $mode-$flavorName configuration',
          );
        }
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Flavor validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Validated 3 apps × 3 environments on Android and iOS.');
}

String read(String path) {
  final file = File(path);
  if (!file.existsSync()) return '';
  return file.readAsStringSync();
}

void expectContains(
  List<String> failures,
  String contents,
  String expected,
  String context,
) {
  if (!contents.contains(expected)) {
    failures.add('$context is missing `$expected`');
  }
}

void expectAbsent(
  List<String> failures,
  String contents,
  String forbidden,
  String context,
) {
  if (contents.contains(forbidden)) {
    failures.add('$context contains forbidden `$forbidden`');
  }
}

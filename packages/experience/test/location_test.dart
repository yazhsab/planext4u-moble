import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  final current = ServiceLocation(
    latitude: 13.08,
    longitude: 80.27,
    accuracyMetres: 12,
    capturedAt: DateTime.utc(2026, 8, 27, 10),
    label: 'Current location',
  );

  test('consent is required before platform location access', () async {
    final platform = FakeLocationPlatform(current);
    final controller = LocationController(
      platform: platform,
      remote: FakeServiceabilityRemote(),
      hasConsent: () => false,
    );

    await controller.useCurrentLocation();

    expect(controller.state.status, LocationStatus.consentRequired);
    expect(platform.serviceChecks, 0);
  });

  test('permission deny, retry and permanent deny are explicit', () async {
    final platform = FakeLocationPlatform(current)
      ..checkedPermission = LocationPermissionState.denied
      ..requestedPermission = LocationPermissionState.denied;
    final controller = LocationController(
      platform: platform,
      remote: FakeServiceabilityRemote(),
      hasConsent: () => true,
    );

    await controller.useCurrentLocation();
    expect(controller.state.status, LocationStatus.permissionDenied);

    controller.retry();
    platform.requestedPermission = LocationPermissionState.deniedForever;
    await controller.useCurrentLocation();
    expect(controller.state.status, LocationStatus.permissionDeniedForever);
    await controller.openAppSettings();
    expect(platform.appSettingsCalls, 1);
  });

  test(
    'disabled GPS routes to settings without requesting permission',
    () async {
      final platform = FakeLocationPlatform(current)..enabled = false;
      final controller = LocationController(
        platform: platform,
        remote: FakeServiceabilityRemote(),
        hasConsent: () => true,
      );

      await controller.useCurrentLocation();
      await controller.openLocationSettings();

      expect(controller.state.status, LocationStatus.serviceDisabled);
      expect(platform.permissionChecks, 0);
      expect(platform.locationSettingsCalls, 1);
    },
  );

  test('GPS and manual locations both require server serviceability', () async {
    final remote = FakeServiceabilityRemote();
    final controller = LocationController(
      platform: FakeLocationPlatform(current),
      remote: remote,
      hasConsent: () => true,
    );

    await controller.useCurrentLocation();
    expect(controller.state.status, LocationStatus.selected);
    expect(controller.state.decision?.zoneId, 'zone-chennai');

    remote.serviceable = false;
    await controller.selectManual(
      ServiceLocation(
        latitude: 11,
        longitude: 78,
        accuracyMetres: 0,
        capturedAt: DateTime.utc(2026, 8, 27, 11),
        label: 'Manual area',
      ),
    );
    expect(controller.state.status, LocationStatus.unserviceable);
    expect(remote.calls, 2);
  });

  test('manual geocoding candidate preserves server coordinates and label', () {
    final candidate = GeocodeCandidate.fromJson({
      'id': 'zone-chennai-0',
      'label': 'Chennai · 600001',
      'locality': 'Chennai',
      'postal_code': '600001',
      'latitude': 13.05,
      'longitude': 80.20,
    });
    final location = candidate.toServiceLocation(DateTime.utc(2026, 8, 28));
    expect(candidate.postalCode, '600001');
    expect(location.label, 'Chennai · 600001');
    expect(location.latitude, 13.05);
  });

  test(
    'offline serviceability never treats an unchecked area as selected',
    () async {
      final remote = FakeServiceabilityRemote()..offline = true;
      final controller = LocationController(
        platform: FakeLocationPlatform(current),
        remote: remote,
        hasConsent: () => true,
      );

      await controller.selectManual(current);

      expect(controller.state.status, LocationStatus.offline);
      expect(controller.state.canContinue, isFalse);
    },
  );

  testWidgets('permanent denial offers settings and manual fallback shell', (
    tester,
  ) async {
    var settings = 0;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: Planext4uLocalizations.supportedLocales,
        localizationsDelegates: const [
          Planext4uLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: LocationGateView(
            state: const LocationState(
              status: LocationStatus.permissionDeniedForever,
            ),
            onUseCurrent: () {},
            onChooseManual: () {},
            onRetry: () {},
            onOpenSettings: () => settings++,
            child: const Text('home-content'),
          ),
        ),
      ),
    );

    expect(find.text('home-content'), findsNothing);
    await tester.tap(find.text('Open settings'));
    expect(settings, 1);
  });
}

final class FakeLocationPlatform implements DeviceLocationPlatform {
  FakeLocationPlatform(this.location);
  final ServiceLocation location;
  bool enabled = true;
  LocationPermissionState checkedPermission = LocationPermissionState.granted;
  LocationPermissionState requestedPermission = LocationPermissionState.granted;
  int serviceChecks = 0;
  int permissionChecks = 0;
  int appSettingsCalls = 0;
  int locationSettingsCalls = 0;

  @override
  Future<LocationPermissionState> checkPermission() async {
    permissionChecks++;
    return checkedPermission;
  }

  @override
  Future<ServiceLocation> currentLocation() async => location;

  @override
  Future<bool> openAppSettings() async {
    appSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsCalls++;
    return true;
  }

  @override
  Future<LocationPermissionState> requestPermission() async =>
      requestedPermission;

  @override
  Future<bool> serviceEnabled() async {
    serviceChecks++;
    return enabled;
  }
}

final class FakeServiceabilityRemote implements ServiceabilityRemote {
  bool serviceable = true;
  bool offline = false;
  int calls = 0;

  @override
  Future<ServiceabilityDecision> check(ServiceLocation location) async {
    calls++;
    if (offline) {
      throw const ApiTransportFailure(correlationId: 'corr-location-test');
    }
    return ServiceabilityDecision(
      serviceable: serviceable,
      reasonCode: serviceable ? 'SERVICEABLE' : 'OUTSIDE_SERVICE_AREA',
      zoneId: serviceable ? 'zone-chennai' : null,
      locality: serviceable ? 'Chennai' : null,
    );
  }
}

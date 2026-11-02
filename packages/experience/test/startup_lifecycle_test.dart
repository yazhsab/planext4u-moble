import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test(
    'disposed bootstrap cannot publish or persist an old account response',
    () async {
      final remote = _Bootstrap();
      final cache = _Cache();
      final controller = BootstrapController(
        remote: remote,
        cache: cache,
        platform: MobilePlatform.android,
        appVersion: '0.1.0',
        locale: 'en',
      );
      final load = controller.load();
      controller.dispose();
      remote.response.complete(
        BootstrapConfig.fromJson({
          ...BootstrapConfig.safeOffline().toJson(),
          'revision': 1,
        }),
      );
      await expectLater(load, completes);
      expect(cache.writes, 0);
    },
  );
  test('disposed consent load cannot notify or write later grants', () async {
    final remote = _Consent();
    final controller = ConsentController(remote);
    final load = controller.load();
    controller.dispose();
    remote.response.complete([]);
    await expectLater(load, completes);
    await controller.setConsent(
      purpose: ConsentPurpose.locationServiceability,
      granted: true,
      policyVersion: 'v1',
    );
    expect(remote.writes, 0);
    expect(controller.evidence, isEmpty);
  });
  test(
    'logout or consent withdrawal during device checks stops permission and GPS access',
    () async {
      for (final logout in [true, false]) {
        var consent = true;
        final platform = _Location();
        final remote = _Serviceability();
        final controller = LocationController(
          platform: platform,
          remote: remote,
          hasConsent: () => consent,
        );
        final locate = controller.useCurrentLocation();
        if (logout) {
          controller.dispose();
        } else {
          consent = false;
        }
        platform.enabled.complete(true);
        await expectLater(locate, completes);
        expect(platform.permissionChecks, 0);
        expect(platform.gpsCalls, 0);
        expect(remote.calls, 0);
        if (!logout) {
          expect(controller.state.status, LocationStatus.consentRequired);
          controller.dispose();
        }
      }
    },
  );
}

final class _Bootstrap implements BootstrapRemote {
  final response = Completer<BootstrapConfig>();
  @override
  Future<BootstrapConfig> fetch({
    required MobilePlatform platform,
    required String appVersion,
    required String locale,
  }) => response.future;
}

final class _Cache implements BootstrapCache {
  int writes = 0;
  @override
  Future<BootstrapConfig?> read() async => null;
  @override
  Future<void> write(BootstrapConfig config) async {
    writes++;
  }
}

final class _Consent implements ConsentRemote {
  final response = Completer<List<ConsentEvidence>>();
  int writes = 0;
  @override
  Future<List<ConsentEvidence>> list() => response.future;
  @override
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    writes++;
    throw StateError('A disposed account cannot write consent.');
  }
}

final class _Location implements DeviceLocationPlatform {
  final enabled = Completer<bool>();
  int permissionChecks = 0;
  int gpsCalls = 0;
  @override
  Future<bool> serviceEnabled() => enabled.future;
  @override
  Future<LocationPermissionState> checkPermission() async {
    permissionChecks++;
    return LocationPermissionState.denied;
  }

  @override
  Future<LocationPermissionState> requestPermission() async {
    throw StateError('Stale permission prompt');
  }

  @override
  Future<ServiceLocation> currentLocation() async {
    gpsCalls++;
    throw StateError('Stale GPS read');
  }

  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

final class _Serviceability implements ServiceabilityRemote {
  int calls = 0;
  @override
  Future<ServiceabilityDecision> check(ServiceLocation location) async {
    calls++;
    throw StateError('Stale location upload');
  }
}

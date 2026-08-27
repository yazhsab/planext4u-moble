import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'localization.dart';

enum LocationPermissionState { denied, deniedForever, granted }

final class ServiceLocation {
  ServiceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMetres,
    required this.capturedAt,
    required this.label,
  }) {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        accuracyMetres < 0 ||
        !capturedAt.isUtc ||
        label.trim().isEmpty) {
      throw const FormatException('Location is invalid.');
    }
  }

  final double latitude;
  final double longitude;
  final double accuracyMetres;
  final DateTime capturedAt;
  final String label;
}

final class ServiceabilityDecision {
  const ServiceabilityDecision({
    required this.serviceable,
    required this.reasonCode,
    this.zoneId,
    this.locality,
  });

  factory ServiceabilityDecision.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        value['serviceable'] is! bool ||
        value['reason_code'] is! String) {
      throw const FormatException('Serviceability contract is invalid.');
    }
    return ServiceabilityDecision(
      serviceable: value['serviceable']! as bool,
      reasonCode: value['reason_code']! as String,
      zoneId: value['zone_id'] as String?,
      locality: value['locality'] as String?,
    );
  }

  final bool serviceable;
  final String reasonCode;
  final String? zoneId;
  final String? locality;
}

abstract interface class DeviceLocationPlatform {
  Future<bool> serviceEnabled();
  Future<LocationPermissionState> checkPermission();
  Future<LocationPermissionState> requestPermission();
  Future<ServiceLocation> currentLocation();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

final class GeolocatorDeviceLocation implements DeviceLocationPlatform {
  const GeolocatorDeviceLocation();

  @override
  Future<bool> serviceEnabled() => geo.Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionState> checkPermission() async =>
      _mapPermission(await geo.Geolocator.checkPermission());

  @override
  Future<LocationPermissionState> requestPermission() async =>
      _mapPermission(await geo.Geolocator.requestPermission());

  @override
  Future<ServiceLocation> currentLocation() async {
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return ServiceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMetres: position.accuracy,
      capturedAt: position.timestamp.toUtc(),
      label: 'Current location',
    );
  }

  @override
  Future<bool> openAppSettings() => geo.Geolocator.openAppSettings();
  @override
  Future<bool> openLocationSettings() => geo.Geolocator.openLocationSettings();
}

LocationPermissionState _mapPermission(geo.LocationPermission permission) =>
    switch (permission) {
      geo.LocationPermission.always ||
      geo.LocationPermission.whileInUse => LocationPermissionState.granted,
      geo.LocationPermission.deniedForever =>
        LocationPermissionState.deniedForever,
      _ => LocationPermissionState.denied,
    };

abstract interface class ServiceabilityRemote {
  Future<ServiceabilityDecision> check(ServiceLocation location);
}

final class ServiceabilityApi implements ServiceabilityRemote {
  const ServiceabilityApi(this._client);
  final ApiClient _client;

  @override
  Future<ServiceabilityDecision> check(ServiceLocation location) async {
    final response = await _client.send(
      ApiRequest(
        operation: 'catalog.check_serviceability',
        method: 'POST',
        path: '/v1/serviceability/check',
        body: {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy_metres': location.accuracyMetres,
          'captured_at': location.capturedAt.toIso8601String(),
          'purpose': 'LOCATION_SERVICEABILITY',
        },
      ),
      ServiceabilityDecision.fromJson,
    );
    return response.value;
  }
}

enum LocationStatus {
  education,
  consentRequired,
  requestingPermission,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  locating,
  checkingServiceability,
  selected,
  unserviceable,
  offline,
  failure,
}

final class LocationState {
  const LocationState({required this.status, this.location, this.decision});
  final LocationStatus status;
  final ServiceLocation? location;
  final ServiceabilityDecision? decision;
  bool get canContinue => status == LocationStatus.selected;
}

typedef LocationConsentCheck = bool Function();

final class LocationController extends ChangeNotifier {
  LocationController({
    required DeviceLocationPlatform platform,
    required ServiceabilityRemote remote,
    required LocationConsentCheck hasConsent,
  }) : _platform = platform,
       _remote = remote,
       _hasConsent = hasConsent;

  final DeviceLocationPlatform _platform;
  final ServiceabilityRemote _remote;
  final LocationConsentCheck _hasConsent;
  LocationState _state = const LocationState(status: LocationStatus.education);

  LocationState get state => _state;

  Future<void> useCurrentLocation() async {
    if (!_hasConsent()) {
      _set(const LocationState(status: LocationStatus.consentRequired));
      return;
    }
    if (!await _platform.serviceEnabled()) {
      _set(const LocationState(status: LocationStatus.serviceDisabled));
      return;
    }
    var permission = await _platform.checkPermission();
    if (permission == LocationPermissionState.denied) {
      _set(const LocationState(status: LocationStatus.requestingPermission));
      permission = await _platform.requestPermission();
    }
    if (permission == LocationPermissionState.deniedForever) {
      _set(const LocationState(status: LocationStatus.permissionDeniedForever));
      return;
    }
    if (permission != LocationPermissionState.granted) {
      _set(const LocationState(status: LocationStatus.permissionDenied));
      return;
    }
    _set(const LocationState(status: LocationStatus.locating));
    try {
      await _resolve(await _platform.currentLocation());
    } catch (_) {
      _set(const LocationState(status: LocationStatus.failure));
    }
  }

  Future<void> selectManual(ServiceLocation location) async {
    if (!_hasConsent()) {
      _set(const LocationState(status: LocationStatus.consentRequired));
      return;
    }
    await _resolve(location);
  }

  Future<void> _resolve(ServiceLocation location) async {
    _set(
      LocationState(
        status: LocationStatus.checkingServiceability,
        location: location,
      ),
    );
    try {
      final decision = await _remote.check(location);
      _set(
        LocationState(
          status: decision.serviceable
              ? LocationStatus.selected
              : LocationStatus.unserviceable,
          location: location,
          decision: decision,
        ),
      );
    } on ApiTransportFailure {
      _set(LocationState(status: LocationStatus.offline, location: location));
    } catch (_) {
      _set(LocationState(status: LocationStatus.failure, location: location));
    }
  }

  Future<void> openAppSettings() => _platform.openAppSettings();
  Future<void> openLocationSettings() => _platform.openLocationSettings();

  void retry() => _set(const LocationState(status: LocationStatus.education));

  void _set(LocationState value) {
    _state = value;
    notifyListeners();
  }
}

final class LocationGateView extends StatelessWidget {
  const LocationGateView({
    required this.state,
    required this.onUseCurrent,
    required this.onChooseManual,
    required this.onRetry,
    required this.onOpenSettings,
    required this.child,
    super.key,
  });

  final LocationState state;
  final VoidCallback onUseCurrent;
  final VoidCallback onChooseManual;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final strings = Planext4uLocalizations.of(context);
    if (state.canContinue) return child;
    if ({
      LocationStatus.requestingPermission,
      LocationStatus.locating,
      LocationStatus.checkingServiceability,
    }.contains(state.status)) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Checking your area',
        message: 'This takes only a moment.',
      );
    }
    if (state.status == LocationStatus.permissionDeniedForever) {
      return Planext4uStatePanel(
        state: Planext4uViewState.permissionDenied,
        title: 'Location permission is off',
        message: 'Enable location permission in Settings, or choose manually.',
        actionLabel: 'Open settings',
        onAction: onOpenSettings,
      );
    }
    if (state.status == LocationStatus.serviceDisabled) {
      return Planext4uStatePanel(
        state: Planext4uViewState.permissionDenied,
        title: 'Turn on location services',
        message: 'Turn on GPS, or choose your area manually.',
        actionLabel: 'Open location settings',
        onAction: onOpenSettings,
      );
    }
    if (state.status == LocationStatus.offline) {
      return Planext4uStatePanel(
        state: Planext4uViewState.offline,
        title: 'Can’t check this area offline',
        message: 'Reconnect to confirm service availability.',
        actionLabel: strings.retry,
        onAction: onRetry,
      );
    }
    if (state.status == LocationStatus.unserviceable) {
      return Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: 'We’re not in this area yet',
        message: 'Choose another location to see available services.',
        actionLabel: strings.chooseManually,
        onAction: onChooseManual,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(Planext4uSpacing.x5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on_outlined, size: 56),
          const SizedBox(height: Planext4uSpacing.x4),
          Text(
            strings.locationTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Planext4uSpacing.x5),
          Planext4uButton(
            label: strings.allowLocation,
            onPressed: onUseCurrent,
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          Planext4uButton(
            label: strings.chooseManually,
            kind: Planext4uButtonKind.secondary,
            onPressed: onChooseManual,
          ),
        ],
      ),
    );
  }
}

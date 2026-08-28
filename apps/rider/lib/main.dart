import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseAuth? auth;
  try {
    await Firebase.initializeApp();
    auth = FirebaseAuth.instance;
  } catch (_) {
    // The runtime shows an actionable configuration state outside development.
  }
  final config = AppConfig.fromCompileTime();
  final commands = _EncryptedRiderCommandStore();
  final push = auth == null
      ? null
      : RolePushLifecycle.firebase(role: AppRole.rider);
  runApp(
    RoleApplicationRuntime<RiderOperationsController>(
      apiBaseUrl: config.apiBaseUrl,
      applicationRole: AppRole.rider,
      environmentLabel: config.environmentLabel,
      development: config.environment == AppEnvironment.development,
      developmentProviderToken: 'synthetic-rider',
      emailProvider: auth == null ? null : _FirebaseEmailProvider(auth),
      onAuthenticatedSession: push?.start,
      onSessionEnded: push?.end,
      controllerFactory: (client) => RiderOperationsController(
        RiderOperationsApi(client),
        commandStore: commands,
        locationTracker: GeolocatorRiderLocationTracker(),
      ),
      authenticatedBuilder: (context, controller, roles, signOut) => RiderApp(
        config: config,
        controller: controller,
        grantedRoles: roles,
        onSignOut: signOut,
      ),
    ),
  );
}

final class GeolocatorRiderLocationTracker implements RiderLocationTracker {
  StreamSubscription<Position>? _positions;

  @override
  Future<void> start(
    Future<void> Function(RiderTrackedPosition position) onPosition,
  ) async {
    if (_positions != null) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError(
        'Location services must be enabled before going online.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Rider location permission is required while on duty.');
    }

    final settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
            intervalDuration: const Duration(seconds: 15),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Planext4u rider is on duty',
              notificationText:
                  'Location is shared for assignments and delivery safety.',
              notificationChannelName: 'Rider duty location',
              setOngoing: true,
              enableWakeLock: false,
              enableWifiLock: false,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.otherNavigation,
            distanceFilter: 25,
            pauseLocationUpdatesAutomatically: true,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );
    _positions = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (position) => unawaited(
            onPosition(
              RiderTrackedPosition(
                latitude: position.latitude,
                longitude: position.longitude,
                accuracyMeters: position.accuracy,
                capturedAt: position.timestamp,
              ),
            ).catchError((_) {}),
          ),
          onError: (_) {},
        );
  }

  @override
  Future<void> stop() async {
    await _positions?.cancel();
    _positions = null;
  }
}

class RiderApp extends StatelessWidget {
  const RiderApp({
    required this.config,
    this.controller,
    this.grantedRoles = const {AppRole.rider},
    this.capabilities = const {
      RoleCapability.riderDuty,
      RoleCapability.riderAssignments,
      RoleCapability.riderEarnings,
      RoleCapability.riderEmergency,
      RoleCapability.profile,
    },
    this.featureFlags = const {
      'rider_assignments': true,
      'rider_earnings': true,
      'rider_emergency': true,
    },
    this.onSignOut,
    super.key,
  });

  final AppConfig config;
  final RiderOperationsController? controller;
  final Set<AppRole> grantedRoles;
  final Set<RoleCapability> capabilities;
  final Map<String, bool> featureFlags;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Planext4u Rider',
    theme: Planext4uTheme.light,
    darkTheme: Planext4uTheme.dark,
    home: AuthenticatedRoleShell(
      applicationRole: AppRole.rider,
      grantedRoles: grantedRoles,
      capabilities: capabilities,
      featureFlags: featureFlags,
      environmentLabel: config.environmentLabel,
      onSignOut: onSignOut,
      destinationBuilder: controller == null
          ? null
          : (context, destination) => RiderOperationsView(
              controller: controller!,
              destination: destination,
            ),
    ),
  );
}

final class _EncryptedRiderCommandStore implements RiderCommandStore {
  _EncryptedRiderCommandStore()
    : _store = EncryptedRecordStore(
        records: FileBinaryRecordStore(namespace: 'rider-offline-v1'),
        keyProvider: PlatformCacheKeyProvider(
          namespace: 'planext4u.rider.offline.v1',
        ),
        namespace: 'rider-offline-v1',
      );

  static const _key = 'commands';
  final EncryptedRecordStore _store;

  @override
  Future<void> enqueue(RiderOfflineCommand command) async {
    final commands = await pending();
    if (commands.any((value) => value.commandId == command.commandId)) return;
    await replace([...commands, command]);
  }

  @override
  Future<List<RiderOfflineCommand>> pending() async {
    final result = await _store.get<List<RiderOfflineCommand>>(_key, (value) {
      if (value is! List<Object?>) {
        throw const FormatException('Rider command queue is invalid.');
      }
      return value
          .map((item) {
            if (item is! Map<String, Object?>) {
              throw const FormatException('Rider command is invalid.');
            }
            return RiderOfflineCommand(
              deviceSequence: item['device_sequence']! as int,
              commandId: item['command_id']! as String,
              kind: item['kind']! as String,
              taskId: item['task_id']! as String,
              revision: item['revision']! as int,
              payload: Map<String, Object?>.unmodifiable(
                item['payload'] as Map<String, Object?>? ?? const {},
              ),
            );
          })
          .toList(growable: false);
    });
    return result.value ?? const [];
  }

  @override
  Future<void> replace(List<RiderOfflineCommand> commands) async {
    if (commands.isEmpty) {
      await _store.delete(_key);
      return;
    }
    final now = DateTime.now().toUtc();
    final ordered = [...commands]
      ..sort((a, b) => a.deviceSequence.compareTo(b.deviceSequence));
    await _store.put(
      _key,
      ordered.map((value) => value.toJson()).toList(),
      expiresAt: now.add(const Duration(days: 14)),
      staleUntil: now.add(const Duration(days: 30)),
    );
  }
}

final class _FirebaseEmailProvider implements EmailIdentityProvider {
  const _FirebaseEmailProvider(this._auth);
  final FirebaseAuth _auth;
  @override
  Future<ProviderAssertion> authenticate({
    required String email,
    required String secret,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: secret,
    );
    final token = await result.user?.getIdToken(true);
    if (token == null || token.length < 8) {
      throw const FormatException('Firebase token is unavailable.');
    }
    return ProviderAssertion(
      provider: IdentityProviderKind.firebase,
      token: token,
    );
  }
}

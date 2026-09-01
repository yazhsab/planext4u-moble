import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';
import 'package:planext4u_observability/planext4u_observability.dart';
import 'package:planext4u_storage/planext4u_storage.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseAuth? auth;
  try {
    await Firebase.initializeApp();
    auth = FirebaseAuth.instance;
  } catch (_) {
    // The runtime shows an actionable configuration state outside development.
  }
  final config = AppConfig.fromCompileTime();
  final identity = AppIdentity.forBuild(
    application: Planext4uApplication.rider,
    environment: config.environment,
  );
  final observability = _observability(config.environment);
  _installRuntimeErrorBoundary(observability.runtimeMetrics);
  final commands = _EncryptedRiderCommandStore();
  final push = auth == null
      ? null
      : RolePushLifecycle.firebase(
          role: AppRole.rider,
          allowedHost: config.deepLinkHost,
          allowedScheme: identity.customScheme,
        );
  runApp(
    RoleApplicationRuntime<RiderOperationsController>(
      apiBaseUrl: config.apiBaseUrl,
      applicationRole: AppRole.rider,
      environmentLabel: config.environmentLabel,
      development: config.environment == AppEnvironment.development,
      developmentProviderToken: 'synthetic-rider',
      apiDiagnostics: observability.apiDiagnostics,
      emailProvider: auth == null ? null : _FirebaseEmailProvider(auth),
      phoneProvider: auth == null ? null : _FirebasePhoneProvider(auth),
      onAuthenticatedSession: push?.start,
      onSessionEnded: push?.end,
      controllerFactory: (client) => RiderOperationsController(
        RiderOperationsApi(client),
        commandStore: commands,
        locationTracker: GeolocatorRiderLocationTracker(),
      ),
      authenticatedBuilder:
          (
            context,
            controller,
            roles,
            signOut,
            sessionManagement,
            notificationPreferences,
            appearancePreferences,
            accountPrivacy,
          ) => RiderApp(
            config: config,
            controller: controller,
            grantedRoles: roles,
            sessionManagementController: sessionManagement,
            notificationPreferencesController: notificationPreferences,
            appearancePreferencesController: appearancePreferences,
            accountPrivacyController: accountPrivacy,
            onNavigate: RiderMapsLauncher.open,
            onSignOut: signOut,
          ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => observability.runtimeMetrics.firstFrame(
      startup.elapsed,
      application: 'rider',
    ),
  );
}

abstract final class RiderMapsLauncher {
  static Future<void> open(RiderTask task) async {
    final destination = task.navigationDestination;
    if (destination == null) {
      throw const FormatException(
        'The server did not provide a safe navigation destination.',
      );
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('No supported navigation application is available.');
    }
  }
}

MobileObservability _observability(AppEnvironment environment) =>
    MobileObservability(
      deployment: switch (environment) {
        AppEnvironment.development => TelemetryDeployment.development,
        AppEnvironment.staging => TelemetryDeployment.staging,
        AppEnvironment.production => TelemetryDeployment.production,
      },
      sink: JsonLineTelemetrySink(debugPrint),
    );

void _installRuntimeErrorBoundary(MobileRuntimeMetrics metrics) {
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    metrics.runtimeError(details.exception, fatal: false);
    previousFlutterHandler?.call(details);
  };
  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    metrics.runtimeError(error, fatal: true);
    return previousPlatformHandler?.call(error, stack) ?? false;
  };
}

final class GeolocatorRiderLocationTracker implements RiderLocationTracker {
  StreamSubscription<Position>? _positions;

  @override
  Future<void> start(
    Future<void> Function(RiderTrackedPosition position) onPosition,
  ) async {
    if (_positions != null) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const RiderLocationException(
        RiderLocationIssue.serviceDisabled,
        'Location services must be enabled before going online.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const RiderLocationException(
        RiderLocationIssue.permissionPermanentlyDenied,
        'Location permission is blocked. Open settings to go on duty.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const RiderLocationException(
        RiderLocationIssue.permissionDenied,
        'Rider location permission is required while on duty.',
      );
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

  @override
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  Future<void> openServiceSettings() async {
    await Geolocator.openLocationSettings();
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
    this.onNavigate,
    this.onCapturePhoto,
    this.onCaptureSignature,
    this.locale,
    this.sessionManagementController,
    this.notificationPreferencesController,
    this.appearancePreferencesController,
    this.accountPrivacyController,
    this.onSignOut,
    super.key,
  });

  final AppConfig config;
  final RiderOperationsController? controller;
  final Set<AppRole> grantedRoles;
  final Set<RoleCapability> capabilities;
  final Map<String, bool> featureFlags;
  final RiderNavigationAction? onNavigate;
  final RiderEvidenceCapture? onCapturePhoto;
  final RiderEvidenceCapture? onCaptureSignature;
  final Locale? locale;
  final IdentitySessionManagementController? sessionManagementController;
  final NotificationPreferencesController? notificationPreferencesController;
  final AppearancePreferencesController? appearancePreferencesController;
  final AccountPrivacyController? accountPrivacyController;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final appearance =
        appearancePreferencesController?.state.preferences ??
        AppearancePreferences.defaults();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Planext4u Rider',
      locale: locale ?? appearance.locale,
      theme: Planext4uTheme.light,
      darkTheme: Planext4uTheme.dark,
      themeMode: appearance.themeMode,
      supportedLocales: Planext4uLocalizations.supportedLocales,
      localizationsDelegates: Planext4uLocalizations.localizationsDelegates,
      builder: (context, child) => Planext4uAdaptiveAppBuilder(
        dataSaver: appearance.dataSaver,
        forceReducedMotion: appearance.reduceMotion,
        minimumTextScale: appearance.textScale.minimumScale,
        child: child ?? const SizedBox.shrink(),
      ),
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
                onNavigate: onNavigate,
                onCapturePhoto: onCapturePhoto,
                onCaptureSignature: onCaptureSignature,
                sessionManagementController: sessionManagementController,
                notificationPreferencesController:
                    notificationPreferencesController,
                appearancePreferencesController:
                    appearancePreferencesController,
                accountPrivacyController: accountPrivacyController,
              ),
      ),
    );
  }
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
            final command = RiderOfflineCommand(
              deviceSequence: item['device_sequence']! as int,
              commandId: item['command_id']! as String,
              kind: item['kind']! as String,
              taskId: item['task_id']! as String,
              revision: item['revision']! as int,
              payload: Map<String, Object?>.unmodifiable(
                item['payload'] as Map<String, Object?>? ?? const {},
              ),
            );
            command.validate();
            return command;
          })
          .toList(growable: false);
    });
    return result.value ?? const [];
  }

  @override
  Future<void> replace(List<RiderOfflineCommand> commands) async {
    if (commands.length > RiderCommandQueuePolicy.maxCommands) {
      throw StateError('Rider offline command queue is full.');
    }
    for (final command in commands) {
      command.validate();
    }
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

final class _FirebaseEmailProvider
    implements EmailIdentityProvider, PasswordRecoveryProvider {
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

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}

final class _FirebasePhoneProvider implements PhoneOtpProvider {
  _FirebasePhoneProvider(this._auth);

  final FirebaseAuth _auth;
  final Map<String, String> _verificationIds = {};

  @override
  Future<String> requestCode({required String phoneNumber}) async {
    if (!PhoneOtpPolicy.isValidPhoneNumber(phoneNumber)) {
      throw const FormatException('The phone number is invalid.');
    }
    final result = Completer<String>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          final authenticated = await _auth.signInWithCredential(credential);
          final assertion = await _firebaseAssertion(authenticated.user);
          final challenge =
              'automatic-${DateTime.now().microsecondsSinceEpoch}';
          _verificationIds[challenge] = 'assertion:${assertion.token}';
          if (!result.isCompleted) result.complete(challenge);
        } catch (error, stackTrace) {
          if (!result.isCompleted) result.completeError(error, stackTrace);
        }
      },
      verificationFailed: (error) {
        if (!result.isCompleted) result.completeError(error);
      },
      codeSent: (verificationId, _) {
        final challenge = 'phone-${DateTime.now().microsecondsSinceEpoch}';
        _verificationIds[challenge] = verificationId;
        if (!result.isCompleted) result.complete(challenge);
      },
      codeAutoRetrievalTimeout: (_) {
        if (!result.isCompleted) {
          result.completeError(
            TimeoutException('The verification code timed out.'),
          );
        }
      },
    );
    return result.future.timeout(const Duration(seconds: 75));
  }

  @override
  Future<ProviderAssertion> verifyCode({
    required String challengeId,
    required String code,
  }) async {
    if (!PhoneOtpPolicy.isValidCode(code)) {
      throw const FormatException('The verification code is invalid.');
    }
    final verification = _verificationIds.remove(challengeId);
    if (verification == null) {
      throw const FormatException('The phone verification has expired.');
    }
    if (verification.startsWith('assertion:')) {
      return ProviderAssertion(
        provider: IdentityProviderKind.firebase,
        token: verification.substring('assertion:'.length),
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verification,
      smsCode: code.trim(),
    );
    final authenticated = await _auth.signInWithCredential(credential);
    return _firebaseAssertion(authenticated.user);
  }
}

Future<ProviderAssertion> _firebaseAssertion(User? user) async {
  final token = await user?.getIdToken(true);
  if (token == null || token.length < 8) {
    throw const FormatException('Firebase token is unavailable.');
  }
  return ProviderAssertion(
    provider: IdentityProviderKind.firebase,
    token: token,
  );
}

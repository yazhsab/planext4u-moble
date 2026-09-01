import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';
import 'package:planext4u_observability/planext4u_observability.dart';

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
    application: Planext4uApplication.vendor,
    environment: config.environment,
  );
  final observability = _observability(config.environment);
  _installRuntimeErrorBoundary(observability.runtimeMetrics);
  final push = auth == null
      ? null
      : RolePushLifecycle.firebase(
          role: AppRole.vendor,
          allowedHost: config.deepLinkHost,
          allowedScheme: identity.customScheme,
        );
  runApp(
    RoleApplicationRuntime<VendorOperationsController>(
      apiBaseUrl: config.apiBaseUrl,
      applicationRole: AppRole.vendor,
      environmentLabel: config.environmentLabel,
      development: config.environment == AppEnvironment.development,
      developmentProviderToken: 'synthetic-vendor',
      apiDiagnostics: observability.apiDiagnostics,
      emailProvider: auth == null ? null : _FirebaseEmailProvider(auth),
      phoneProvider: auth == null ? null : _FirebasePhoneProvider(auth),
      onAuthenticatedSession: push?.start,
      onSessionEnded: push?.end,
      controllerFactory: (client) =>
          VendorOperationsController(VendorOperationsApi(client)),
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
          ) => VendorApp(
            config: config,
            controller: controller,
            grantedRoles: roles,
            sessionManagementController: sessionManagement,
            notificationPreferencesController: notificationPreferences,
            appearancePreferencesController: appearancePreferences,
            accountPrivacyController: accountPrivacy,
            onSignOut: signOut,
          ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => observability.runtimeMetrics.firstFrame(
      startup.elapsed,
      application: 'vendor',
    ),
  );
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

class VendorApp extends StatelessWidget {
  const VendorApp({
    required this.config,
    this.controller,
    this.grantedRoles = const {AppRole.vendor},
    this.capabilities = const {
      RoleCapability.vendorOverview,
      RoleCapability.vendorOrders,
      RoleCapability.vendorBookings,
      RoleCapability.vendorCatalog,
      RoleCapability.vendorPromotions,
      RoleCapability.vendorEarnings,
      RoleCapability.profile,
    },
    this.featureFlags = const {
      'vendor_orders': true,
      'vendor_catalog': true,
      'vendor_bookings': true,
      'vendor_promotions': true,
      'vendor_earnings': true,
    },
    this.locale,
    this.sessionManagementController,
    this.notificationPreferencesController,
    this.appearancePreferencesController,
    this.accountPrivacyController,
    this.onSignOut,
    super.key,
  });

  final AppConfig config;
  final VendorOperationsController? controller;
  final Set<AppRole> grantedRoles;
  final Set<RoleCapability> capabilities;
  final Map<String, bool> featureFlags;
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
      title: 'Planext4u Vendor',
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
        applicationRole: AppRole.vendor,
        grantedRoles: grantedRoles,
        capabilities: capabilities,
        featureFlags: featureFlags,
        environmentLabel: config.environmentLabel,
        onSignOut: onSignOut,
        destinationBuilder: controller == null
            ? null
            : (context, destination) => VendorOperationsView(
                controller: controller!,
                destination: destination,
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

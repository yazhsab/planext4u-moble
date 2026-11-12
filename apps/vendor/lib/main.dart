import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';
import 'package:planext4u_observability/planext4u_observability.dart';
import 'package:url_launcher/url_launcher.dart';

import 'private_onboarding.dart';

Future<void> main() async {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromCompileTime();
  final observability = _observability(config.environment);
  _installRuntimeErrorBoundary(observability.runtimeMetrics);
  runApp(
    PublicStartupGate(
      apiBaseUrl: config.apiBaseUrl,
      role: 'vendor',
      country: config.countryCode,
      initialize: () => _initializeVendorRuntime(config, observability),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => observability.runtimeMetrics.firstFrame(
      startup.elapsed,
      application: 'vendor',
    ),
  );
}

Future<Widget> _initializeVendorRuntime(
  AppConfig config,
  MobileObservability observability,
) async {
  FirebaseAuth? auth;
  try {
    await Firebase.initializeApp();
    auth = FirebaseAuth.instance;
  } catch (_) {
    // The runtime shows an actionable configuration state outside development.
  }
  final identity = AppIdentity.forBuild(
    application: Planext4uApplication.vendor,
    environment: config.environment,
  );
  PrivateMediaUploader? privateUploader;
  HostedBankLinkClient? bankLinks;
  final push = auth == null
      ? null
      : RolePushLifecycle.firebase(
          role: AppRole.vendor,
          allowedHost: config.deepLinkHost,
          allowedScheme: identity.customScheme,
        );
  return RoleApplicationRuntime<VendorOperationsController>(
    apiBaseUrl: config.apiBaseUrl,
    country: config.countryCode,
    applicationRole: AppRole.vendor,
    environmentLabel: config.environmentLabel,
    development: config.environment == AppEnvironment.development,
    developmentProviderToken: 'synthetic-vendor',
    apiDiagnostics: observability.apiDiagnostics,
    emailProvider: auth == null ? null : _FirebaseEmailProvider(auth),
    phoneProvider: auth == null ? null : _FirebasePhoneProvider(auth),
    accountLinkingProvider: auth == null
        ? null
        : FirebaseAccountLinkingProvider(auth),
    onAuthenticatedSession: push?.start,
    onDeviceSettingsReturn: push?.refreshAuthorization,
    onSessionEnded: (unregister) async {
      bankLinks?.dispose();
      bankLinks = null;
      privateUploader?.dispose();
      privateUploader = null;
      await push?.end(unregister);
    },
    controllerFactory: (client) {
      bankLinks?.dispose();
      final bankOrigin = config.bankLinkLaunchOrigin;
      bankLinks = bankOrigin == null
          ? null
          : HostedBankLinkClient(
              client: client,
              applicationRole: 'vendor',
              allowedOrigins: {bankOrigin},
              allowDevelopmentHttp:
                  config.environment == AppEnvironment.development,
            );
      privateUploader?.dispose();
      final origin = config.privateUploadOrigin;
      privateUploader = origin == null
          ? null
          : PrivateMediaUploader(
              client: client,
              allowedOrigins: {origin},
              allowDevelopmentHttp:
                  config.environment == AppEnvironment.development,
            );
      return VendorOperationsController(VendorOperationsApi(client))
        ..bankLinks = bankLinks;
    },
    onAccountScopeReady: (controller, tenantId, country, identityId) {
      controller.documentProgress = EncryptedPrivateOnboardingProgressStore(
        tenantId: tenantId,
        country: country,
        identityId: identityId,
        applicationRole: 'vendor',
      );
      controller.onboardingProgress = EncryptedVendorOnboardingProgressStore(
        tenantId: tenantId,
        country: country,
        identityId: identityId,
      );
    },
    authenticatedBuilder:
        (
          context,
          controller,
          roles,
          signOut,
          identityProfile,
          sessionManagement,
          notificationPreferences,
          support,
          appearancePreferences,
          accountPrivacy,
        ) => VendorApp(
          config: config,
          controller: controller,
          privateMediaUploader: privateUploader,
          grantedRoles: roles,
          identityProfileController: identityProfile,
          sessionManagementController: sessionManagement,
          notificationPreferencesController: notificationPreferences,
          supportController: support,
          appearancePreferencesController: appearancePreferences,
          accountPrivacyController: accountPrivacy,
          onSignOut: signOut,
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
    this.onboardingProvider,
    this.privateMediaUploader,
    this.identityProfileController,
    this.sessionManagementController,
    this.notificationPreferencesController,
    this.supportController,
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
  final VendorOnboardingProvider? onboardingProvider;
  final PrivateMediaUploader? privateMediaUploader;
  final IdentityProfileController? identityProfileController;
  final IdentitySessionManagementController? sessionManagementController;
  final NotificationPreferencesController? notificationPreferencesController;
  final SupportController? supportController;
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
        child: LocalAppLockGate(
          controller: accountPrivacyController?.appLock,
          child: PublishedEducationGate(
            controller: identityProfileController?.education,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
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
                onboardingProvider:
                    onboardingProvider ??
                    (privateMediaUploader == null
                        ? null
                        : NativeVendorOnboardingProvider(
                            uploader: privateMediaUploader!,
                            progress: controller!.documentProgress,
                            bankLinks: controller!.bankLinks,
                            verifyBank: controller!.bankLinks == null
                                ? null
                                : () => showHostedBankLinkDialog(
                                    context,
                                    client: controller!.bankLinks!,
                                    launch: (url) => launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  ),
                            capture: (kind) => captureNativeVendorDocument(
                              context,
                              kind,
                              isActive: () => privateMediaUploader!.isActive,
                            ),
                          )),
                identityProfileController: identityProfileController,
                sessionManagementController: sessionManagementController,
                notificationPreferencesController:
                    notificationPreferencesController,
                supportController: supportController,
                appearancePreferencesController:
                    appearancePreferencesController,
                accountPrivacyController: accountPrivacyController,
              ),
      ),
    );
  }
}

final class _FirebaseEmailProvider
    implements
        EmailIdentityProvider,
        PasswordRecoveryProvider,
        EmailRegistrationProvider {
  const _FirebaseEmailProvider(this._auth);
  final FirebaseAuth _auth;
  @override
  Future<ProviderAssertion> register({
    required String email,
    required String secret,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: secret,
    );
    await result.user?.sendEmailVerification();
    return _firebaseAssertion(result.user);
  }

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

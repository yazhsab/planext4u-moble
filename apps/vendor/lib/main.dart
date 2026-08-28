import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

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
  final push = auth == null
      ? null
      : RolePushLifecycle.firebase(role: AppRole.vendor);
  runApp(
    RoleApplicationRuntime<VendorOperationsController>(
      apiBaseUrl: config.apiBaseUrl,
      applicationRole: AppRole.vendor,
      environmentLabel: config.environmentLabel,
      development: config.environment == AppEnvironment.development,
      developmentProviderToken: 'synthetic-vendor',
      emailProvider: auth == null ? null : _FirebaseEmailProvider(auth),
      onAuthenticatedSession: push?.start,
      onSessionEnded: push?.end,
      controllerFactory: (client) =>
          VendorOperationsController(VendorOperationsApi(client)),
      authenticatedBuilder: (context, controller, roles, signOut) => VendorApp(
        config: config,
        controller: controller,
        grantedRoles: roles,
        onSignOut: signOut,
      ),
    ),
  );
}

class VendorApp extends StatelessWidget {
  const VendorApp({
    required this.config,
    this.controller,
    this.grantedRoles = const {AppRole.vendor},
    this.capabilities = const {
      RoleCapability.vendorOverview,
      RoleCapability.vendorOrders,
      RoleCapability.vendorCatalog,
      RoleCapability.vendorEarnings,
      RoleCapability.profile,
    },
    this.featureFlags = const {
      'vendor_orders': true,
      'vendor_catalog': true,
      'vendor_earnings': true,
    },
    this.onSignOut,
    super.key,
  });

  final AppConfig config;
  final VendorOperationsController? controller;
  final Set<AppRole> grantedRoles;
  final Set<RoleCapability> capabilities;
  final Map<String, bool> featureFlags;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Planext4u Vendor',
    theme: Planext4uTheme.light,
    darkTheme: Planext4uTheme.dark,
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
            ),
    ),
  );
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

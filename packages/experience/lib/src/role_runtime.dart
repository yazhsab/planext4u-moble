import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

import 'account_privacy.dart';
import 'appearance_preferences.dart';
import 'identity_profile.dart';
import 'localization.dart';
import 'notification_preferences.dart';
import 'phase5.dart';
import 'support.dart';

typedef AuthenticatedRoleBuilder<T extends ChangeNotifier> =
    Widget Function(
      BuildContext context,
      T controller,
      Set<AppRole> roles,
      Future<void> Function() signOut,
      IdentityProfileController identityProfile,
      IdentitySessionManagementController sessionManagement,
      NotificationPreferencesController notificationPreferences,
      SupportController support,
      AppearancePreferencesController appearancePreferences,
      AccountPrivacyController accountPrivacy,
    );

final class RoleApplicationRuntime<T extends ChangeNotifier>
    extends StatefulWidget {
  const RoleApplicationRuntime({
    required this.apiBaseUrl,
    required this.applicationRole,
    required this.environmentLabel,
    required this.development,
    required this.developmentProviderToken,
    required this.controllerFactory,
    required this.authenticatedBuilder,
    this.apiDiagnostics = const NoopApiDiagnostics(),
    this.emailProvider,
    this.phoneProvider,
    this.installIdStore,
    this.onAuthenticatedSession,
    this.onSessionEnded,
    super.key,
  });

  final Uri apiBaseUrl;
  final AppRole applicationRole;
  final String environmentLabel;
  final bool development;
  final String developmentProviderToken;
  final T Function(ApiClient client) controllerFactory;
  final AuthenticatedRoleBuilder<T> authenticatedBuilder;
  final ApiDiagnostics apiDiagnostics;
  final EmailIdentityProvider? emailProvider;
  final PhoneOtpProvider? phoneProvider;
  final InstallIdStore? installIdStore;
  final Future<void> Function(ApiClient client)? onAuthenticatedSession;
  final Future<void> Function(bool unregister)? onSessionEnded;

  @override
  State<RoleApplicationRuntime<T>> createState() =>
      _RoleApplicationRuntimeState<T>();
}

class _RoleApplicationRuntimeState<T extends ChangeNotifier>
    extends State<RoleApplicationRuntime<T>> {
  final IoApiTransport _transport = IoApiTransport();
  IdentitySessionController? _session;
  StreamSubscription<IdentitySessionState>? _subscription;
  T? _controller;
  IdentityProfileController? _identityProfile;
  IdentitySessionManagementController? _sessionManagement;
  NotificationPreferencesController? _notificationPreferences;
  SupportController? _support;
  AppearancePreferencesController? _appearancePreferences;
  AccountPrivacyController? _accountPrivacy;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final appearance = AppearancePreferencesController.platform(
        namespace: 'planext4u.${widget.applicationRole.name}.appearance.v1',
      );
      _appearancePreferences = appearance;
      appearance.addListener(_appearanceChanged);
      await appearance.load();
      final client = ApiClient(
        baseUrl: widget.apiBaseUrl,
        transport: _transport,
        diagnostics: widget.apiDiagnostics,
      );
      final deviceId =
          await (widget.installIdStore ??
                  PlatformInstallIdStore(
                    namespace: 'planext4u.${widget.applicationRole.name}',
                  ))
              .readOrCreate();
      final session = IdentitySessionController(
        remote: IdentityApi(client),
        store: PlatformSecureSessionStore(
          namespace: 'planext4u.${widget.applicationRole.name}.identity.v1',
        ),
        applicationRole: widget.applicationRole,
        deviceId: deviceId,
        country: 'IN',
      );
      _session = session;
      _subscription = session.states.listen((_) {
        if (mounted) setState(() {});
      });
      await session.initialize();
      if (session.state.authentication != null) _buildController(session);
    } catch (error) {
      _failure = error;
    }
    if (mounted) setState(() {});
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  void _buildController(IdentitySessionController session) {
    if (_controller != null) return;
    final client = ApiClient(
      baseUrl: widget.apiBaseUrl,
      transport: _transport,
      authSession: session,
      diagnostics: widget.apiDiagnostics,
    );
    _controller = widget.controllerFactory(client);
    _identityProfile = IdentityProfileController(
      expectedRole: widget.applicationRole,
      remote: IdentityProfileApi(client),
    );
    _sessionManagement = IdentitySessionManagementController(
      IdentitySessionManagementApi(client),
    );
    _notificationPreferences = NotificationPreferencesController(
      NotificationPreferencesApi(client),
    );
    _support = SupportController(
      role: widget.applicationRole,
      remote: SupportApi(client),
    );
    _accountPrivacy = AccountPrivacyController(Phase5Api(client));
    final hook = widget.onAuthenticatedSession;
    if (hook != null) unawaited(hook(client));
  }

  Future<void> _authenticated() async {
    final session = _session;
    if (session?.state.authentication != null) {
      _buildController(session!);
      if (mounted) setState(() {});
    }
  }

  Future<void> _signOut() async {
    await widget.onSessionEnded?.call(true);
    await _session?.signOut();
    _controller?.dispose();
    _identityProfile?.dispose();
    _sessionManagement?.dispose();
    _notificationPreferences?.dispose();
    _support?.dispose();
    _accountPrivacy?.dispose();
    _controller = null;
    _identityProfile = null;
    _sessionManagement = null;
    _notificationPreferences = null;
    _support = null;
    _accountPrivacy = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final endSession = widget.onSessionEnded;
    if (endSession != null) unawaited(endSession(false));
    unawaited(_subscription?.cancel());
    unawaited(_session?.dispose());
    _controller?.dispose();
    _identityProfile?.dispose();
    _sessionManagement?.dispose();
    _notificationPreferences?.dispose();
    _support?.dispose();
    _accountPrivacy?.dispose();
    _appearancePreferences?.dispose();
    _transport.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final authentication = session?.state.authentication;
    final appearance =
        _appearancePreferences?.state.preferences ??
        AppearancePreferences.defaults();
    if (authentication != null) {
      _buildController(session!);
      return widget.authenticatedBuilder(
        context,
        _controller!,
        authentication.roles,
        _signOut,
        _identityProfile!,
        _sessionManagement!,
        _notificationPreferences!,
        _support!,
        _appearancePreferences!,
        _accountPrivacy!,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: appearance.locale,
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
      home: session == null
          ? _RoleRuntimeState(failure: _failure)
          : _RoleSignInScreen(
              session: session,
              role: widget.applicationRole,
              development: widget.development,
              developmentProviderToken: widget.developmentProviderToken,
              emailProvider: widget.emailProvider,
              phoneProvider: widget.phoneProvider,
              onAuthenticated: _authenticated,
            ),
    );
  }
}

final class _RoleRuntimeState extends StatelessWidget {
  const _RoleRuntimeState({this.failure});
  final Object? failure;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Planext4uStatePanel(
        state: failure == null
            ? Planext4uViewState.loading
            : Planext4uViewState.error,
        title: failure == null ? 'Restoring secure session' : 'Startup failed',
        message: failure == null
            ? 'Checking your encrypted role and permissions.'
            : 'The secure role session could not be initialized.',
      ),
    ),
  );
}

final class _RoleSignInScreen extends StatefulWidget {
  const _RoleSignInScreen({
    required this.session,
    required this.role,
    required this.development,
    required this.developmentProviderToken,
    required this.onAuthenticated,
    this.emailProvider,
    this.phoneProvider,
  });
  final IdentitySessionController session;
  final AppRole role;
  final bool development;
  final String developmentProviderToken;
  final EmailIdentityProvider? emailProvider;
  final PhoneOtpProvider? phoneProvider;
  final Future<void> Function() onAuthenticated;
  @override
  State<_RoleSignInScreen> createState() => _RoleSignInScreenState();
}

class _RoleSignInScreenState extends State<_RoleSignInScreen> {
  final _email = TextEditingController();
  final _secret = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _run(
    EmailIdentityProvider provider,
    String email,
    String secret,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.session.signInWithEmail(
        provider: provider,
        email: email,
        secret: secret,
      );
      await widget.onAuthenticated();
    } catch (_) {
      if (mounted) {
        setState(() {
          _message =
              'Sign-in failed or this account does not have the ${widget.role.label} role.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Planext4u ${widget.role.label} sign in')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Planext4uSpacing.x5),
        children: [
          Text(
            'Secure ${widget.role.label.toLowerCase()} workspace',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Planext4uSpacing.x4),
          if (widget.emailProvider != null) ...[
            TextField(
              key: const ValueKey('role-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            TextField(
              key: const ValueKey('role-secret'),
              controller: _secret,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      widget.emailProvider!,
                      _email.text.trim(),
                      _secret.text,
                    ),
              child: const Text('Sign in'),
            ),
            if (widget.emailProvider
                case final PasswordRecoveryProvider provider)
              PasswordRecoveryButton(
                emailController: _email,
                provider: provider,
              ),
          ] else
            const Planext4uStatePanel(
              state: Planext4uViewState.error,
              title: 'Identity provider unavailable',
              message:
                  'This build is missing its Firebase environment configuration.',
            ),
          if (widget.phoneProvider != null) ...[
            const Divider(height: Planext4uSpacing.x6),
            PhoneOtpSignInControl(
              provider: widget.phoneProvider!,
              onVerify: (challengeId, code) async {
                await widget.session.signInWithPhoneOtp(
                  provider: widget.phoneProvider!,
                  challengeId: challengeId,
                  code: code,
                );
                await widget.onAuthenticated();
              },
            ),
          ],
          if (widget.development) ...[
            const Divider(height: Planext4uSpacing.x6),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      _LocalRoleProvider(widget.developmentProviderToken),
                      'synthetic@local.invalid',
                      'development-only',
                    ),
              icon: const Icon(Icons.science_outlined),
              label: const Text('Continue with local development account'),
            ),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: Planext4uSpacing.x3),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}

/// Shared, enumeration-safe recovery control for email-authenticated apps.
final class PasswordRecoveryButton extends StatefulWidget {
  const PasswordRecoveryButton({
    required this.emailController,
    required this.provider,
    super.key,
  });

  final TextEditingController emailController;
  final PasswordRecoveryProvider provider;

  @override
  State<PasswordRecoveryButton> createState() => _PasswordRecoveryButtonState();
}

class _PasswordRecoveryButtonState extends State<PasswordRecoveryButton> {
  bool _busy = false;
  String? _message;

  Future<void> _request() async {
    if (_busy) return;
    final email = widget.emailController.text.trim();
    if (!PasswordRecoveryPolicy.isValidEmail(email)) {
      setState(() => _message = 'Enter a valid email address first.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.provider.requestPasswordReset(email: email);
      if (mounted) {
        setState(
          () => _message =
              'If an account exists for that email, recovery instructions have been sent.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Password recovery is temporarily unavailable. Try again shortly.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton(
        key: const ValueKey('forgot-password'),
        onPressed: _busy ? null : _request,
        child: const Text('Forgot password?'),
      ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Planext4uSpacing.x2),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              key: const ValueKey('password-recovery-message'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      if (_busy) const LinearProgressIndicator(),
    ],
  );
}

typedef PhoneOtpVerification =
    Future<void> Function(String challengeId, String code);

/// Shared phone-OTP control used by vendor and rider role runtimes.
final class PhoneOtpSignInControl extends StatefulWidget {
  const PhoneOtpSignInControl({
    required this.provider,
    required this.onVerify,
    super.key,
  });

  final PhoneOtpProvider provider;
  final PhoneOtpVerification onVerify;

  @override
  State<PhoneOtpSignInControl> createState() => _PhoneOtpSignInControlState();
}

class _PhoneOtpSignInControlState extends State<PhoneOtpSignInControl> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _challengeId;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy) return;
    final phone = _phone.text.trim();
    if (!PhoneOtpPolicy.isValidPhoneNumber(phone)) {
      setState(
        () =>
            _message = 'Enter a valid phone number including the country code.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final challenge = await widget.provider.requestCode(phoneNumber: phone);
      if (mounted) {
        setState(() {
          _challengeId = challenge;
          _message = 'Verification code sent.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'A verification code could not be sent. Try again shortly.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    final challenge = _challengeId;
    final code = _code.text.trim();
    if (challenge == null || !PhoneOtpPolicy.isValidCode(code)) {
      setState(() => _message = 'Enter the 4–8 digit verification code.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onVerify(challenge, code);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Verification failed or this account does not have access.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Sign in with phone',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: Planext4uSpacing.x3),
      TextField(
        key: const ValueKey('role-phone'),
        controller: _phone,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: const InputDecoration(
          labelText: 'Phone number with country code',
          hintText: '+919876543210',
        ),
      ),
      OutlinedButton(
        key: const ValueKey('role-request-otp'),
        onPressed: _busy ? null : _request,
        child: Text(
          _challengeId == null ? 'Send verification code' : 'Resend code',
        ),
      ),
      if (_challengeId != null) ...[
        const SizedBox(height: Planext4uSpacing.x2),
        TextField(
          key: const ValueKey('role-otp'),
          controller: _code,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 8,
          decoration: const InputDecoration(labelText: 'Verification code'),
          onSubmitted: (_) => _verify(),
        ),
        FilledButton(
          key: const ValueKey('role-verify-otp'),
          onPressed: _busy ? null : _verify,
          child: const Text('Verify and sign in'),
        ),
      ],
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: Planext4uSpacing.x2),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              key: const ValueKey('phone-otp-message'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      if (_busy) const LinearProgressIndicator(),
    ],
  );
}

final class _LocalRoleProvider implements EmailIdentityProvider {
  const _LocalRoleProvider(this.token);
  final String token;
  @override
  Future<ProviderAssertion> authenticate({
    required String email,
    required String secret,
  }) async =>
      ProviderAssertion(provider: IdentityProviderKind.local, token: token);
}

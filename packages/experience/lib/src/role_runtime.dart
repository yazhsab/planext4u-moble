import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

typedef AuthenticatedRoleBuilder<T extends ChangeNotifier> =
    Widget Function(
      BuildContext context,
      T controller,
      Set<AppRole> roles,
      Future<void> Function() signOut,
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
    this.emailProvider,
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
  final EmailIdentityProvider? emailProvider;
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
  Object? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final client = ApiClient(
        baseUrl: widget.apiBaseUrl,
        transport: _transport,
      );
      final session = IdentitySessionController(
        remote: IdentityApi(client),
        store: PlatformSecureSessionStore(
          namespace: 'planext4u.${widget.applicationRole.name}.identity.v1',
        ),
        applicationRole: widget.applicationRole,
        deviceId: 'device-${widget.applicationRole.name}-mobile-runtime-001',
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

  void _buildController(IdentitySessionController session) {
    if (_controller != null) return;
    final client = ApiClient(
      baseUrl: widget.apiBaseUrl,
      transport: _transport,
      authSession: session,
    );
    _controller = widget.controllerFactory(client);
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
    _controller = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final endSession = widget.onSessionEnded;
    if (endSession != null) unawaited(endSession(false));
    unawaited(_subscription?.cancel());
    unawaited(_session?.dispose());
    _controller?.dispose();
    _transport.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final authentication = session?.state.authentication;
    if (authentication != null) {
      _buildController(session!);
      return widget.authenticatedBuilder(
        context,
        _controller!,
        authentication.roles,
        _signOut,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Planext4uTheme.light,
      darkTheme: Planext4uTheme.dark,
      home: session == null
          ? _RoleRuntimeState(failure: _failure)
          : _RoleSignInScreen(
              session: session,
              role: widget.applicationRole,
              development: widget.development,
              developmentProviderToken: widget.developmentProviderToken,
              emailProvider: widget.emailProvider,
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
  });
  final IdentitySessionController session;
  final AppRole role;
  final bool development;
  final String developmentProviderToken;
  final EmailIdentityProvider? emailProvider;
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
          ] else
            const Planext4uStatePanel(
              state: Planext4uViewState.error,
              title: 'Identity provider unavailable',
              message:
                  'This build is missing its Firebase environment configuration.',
            ),
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

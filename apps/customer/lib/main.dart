import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';
import 'package:planext4u_observability/planext4u_observability.dart';

import 'community_capture.dart';
import 'firebase_identity_providers.dart';
import 'payment_provider_launcher.dart';
import 'push_registration.dart';
import 'account_stores.dart';

export 'account_stores.dart' show CustomerLocationStore;

Future<void> main() async {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromCompileTime();
  final observability = _observability(config.environment);
  _installRuntimeErrorBoundary(observability.runtimeMetrics);
  runApp(
    PublicStartupGate(
      apiBaseUrl: config.apiBaseUrl,
      role: 'customer',
      country: config.countryCode,
      initialize: () => _initializeCustomerRuntime(config, observability),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => observability.runtimeMetrics.firstFrame(
      startup.elapsed,
      application: 'customer',
    ),
  );
}

Future<Widget> _initializeCustomerRuntime(
  AppConfig config,
  MobileObservability observability,
) async {
  FirebaseAuth? firebaseAuth;
  FirebaseMessaging? firebaseMessaging;
  Object? firebaseFailure;
  try {
    await Firebase.initializeApp();
    firebaseAuth = FirebaseAuth.instance;
    firebaseMessaging = FirebaseMessaging.instance;
  } catch (error) {
    firebaseFailure = error;
  }
  return CustomerRuntime(
    config: config,
    apiDiagnostics: observability.apiDiagnostics,
    firebaseAuth: firebaseAuth,
    firebaseMessaging: firebaseMessaging,
    firebaseFailure: firebaseFailure,
  );
}

class CustomerRuntime extends StatefulWidget {
  const CustomerRuntime({
    required this.config,
    this.firebaseAuth,
    this.firebaseMessaging,
    this.firebaseFailure,
    this.communityMediaUploader,
    this.socialRtcProviderFactory,
    this.apiDiagnostics = const NoopApiDiagnostics(),
    super.key,
  });

  final AppConfig config;
  final FirebaseAuth? firebaseAuth;
  final FirebaseMessaging? firebaseMessaging;
  final Object? firebaseFailure;
  final CommunityMediaUploader? communityMediaUploader;
  final SocialRtcOfferProviderFactory? socialRtcProviderFactory;
  final ApiDiagnostics apiDiagnostics;

  @override
  State<CustomerRuntime> createState() => _CustomerRuntimeState();
}

class _CustomerRuntimeState extends State<CustomerRuntime>
    with WidgetsBindingObserver {
  final IoApiTransport _transport = IoApiTransport();
  IdentitySessionController? _session;
  StreamSubscription<IdentitySessionState>? _sessionSubscription;
  CatalogController? _catalog;
  MarketplaceController? _marketplace;
  CartController? _cart;
  TransactionController? _transactions;
  ServiceBookingController? _serviceBookings;
  FoodController? _food;
  SocialController? _social;
  Phase5Controller? _phase5;
  CommunityMediaCoordinator? _communityMediaCoordinator;
  AccountPrivacyController? _accountPrivacy;
  IdentityProfileController? _identityProfile;
  IdentitySessionManagementController? _sessionManagement;
  NotificationPreferencesController? _notificationPreferences;
  SupportController? _support;
  AppearancePreferencesController? _appearancePreferences;
  BootstrapController? _bootstrap;
  ConsentController? _consent;
  LocationController? _location;
  GeocodingRemote? _geocoding;
  CustomerLocationStoreEncrypted? _locationStore;
  Object? _startupFailure;
  String? _controllerScope;
  CustomerPushRegistration? _pushRegistration;
  Uri? _notificationUri;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final appearance = AppearancePreferencesController.platform(
        namespace: 'planext4u.customer.appearance.v1',
      );
      _appearancePreferences = appearance;
      appearance.addListener(_appearanceChanged);
      await appearance.load();
      final identityClient = ApiClient(
        baseUrl: widget.config.apiBaseUrl,
        transport: _transport,
        diagnostics: widget.apiDiagnostics,
      );
      final deviceId = await PlatformInstallIdStore(
        namespace: 'planext4u.customer',
      ).readOrCreate();
      final session = IdentitySessionController(
        remote: IdentityApi(identityClient),
        store: PlatformSecureSessionStore(
          namespace: 'planext4u.customer.identity.v1',
        ),
        applicationRole: AppRole.customer,
        deviceId: deviceId,
        country: widget.config.countryCode,
      );
      _session = session;
      _sessionSubscription = session.states.listen((state) {
        if (state.authentication == null &&
            const {
              IdentitySessionStatus.signedOut,
              IdentitySessionStatus.expired,
              IdentitySessionStatus.roleDenied,
            }.contains(state.status)) {
          _disposeControllers();
          final push = _pushRegistration;
          _pushRegistration = null;
          unawaited(push?.dispose());
        }
        if (mounted) setState(() {});
      });
      await session.initialize();
      if (session.state.authentication != null) _buildControllers(session);
    } catch (error) {
      _startupFailure = error;
    }
    if (mounted) setState(() {});
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  void _buildControllers(IdentitySessionController session) {
    String? scope() {
      final auth = session.state.authentication;
      return auth == null
          ? null
          : '${auth.tenantId}:${auth.country}:${auth.identityId}:${auth.session.id}';
    }

    final controllerScope = scope();
    if (controllerScope == null) return;
    if (_catalog != null && _controllerScope == controllerScope) return;
    _disposeControllers();
    _controllerScope = controllerScope;
    final authentication = session.state.authentication!;
    final cacheScope = CustomerCacheScope(
      tenantId: authentication.tenantId,
      country: authentication.country,
      identityId: authentication.identityId,
    );
    _locationStore = CustomerLocationStoreEncrypted.platform(cacheScope);
    final client = ApiClient(
      baseUrl: widget.config.apiBaseUrl,
      transport: _transport,
      authSession: RoleBoundApiSession(
        delegate: session,
        expectedScope: controllerScope,
        currentScope: scope,
      ),
      diagnostics: widget.apiDiagnostics,
    );
    final catalogApi = CatalogApi(
      client,
      postalCodeProvider: () => _location?.state.location?.postalCode,
    );
    _catalog = CatalogController(
      remote: catalogApi,
      cache: MemoryCustomerHomeCache(),
    );
    _marketplace = MarketplaceController(remote: catalogApi);
    _cart = CartController(remote: CartApi(client));
    _transactions = TransactionController(
      remote: TransactionApi(client),
      recoveryStore: CustomerPaymentRecoveryStore.platform(cacheScope),
      geography: GeographyApi(client, country: authentication.country),
      addressCountry: authentication.country,
      scopeIsCurrent: () => mounted && scope() == controllerScope,
    );
    _serviceBookings = ServiceBookingController(
      remote: ServiceBookingApi(client),
    );
    _food = FoodController(remote: FoodApi(client));
    _social = SocialController(remote: SocialApi(client));
    final phase5Api = Phase5Api(client);
    _phase5 = Phase5Controller(remote: phase5Api);
    final communityMediaUploader = widget.communityMediaUploader;
    if (communityMediaUploader != null) {
      _communityMediaCoordinator = createDeviceCommunityMediaCoordinator(
        uploader: communityMediaUploader,
      );
    }
    _consent = ConsentController(
      ConsentApi(client),
      journal: SecureConsentJournal(
        tenantId: authentication.tenantId,
        country: authentication.country,
        identityId: authentication.identityId,
      ),
    );
    _accountPrivacy = AccountPrivacyController(
      phase5Api,
      contacts: ContactMatchingController(
        api: ContactMatchingApi(client),
        consent: _consent!,
        policyVersion: () {
          for (final policy
              in _bootstrap?.state.config.consentPolicies ??
                  const <ConsentPolicy>[]) {
            if (policy.purpose == ConsentPurpose.contactMatching.wireValue) {
              return policy.policyVersion;
            }
          }
          return null;
        },
        freshProviderToken: () async {
          final auth = widget.firebaseAuth;
          final user = auth?.currentUser;
          if (user == null || !mounted || scope() != controllerScope) {
            throw StateError('Provider sign-in is unavailable.');
          }
          await user.reload();
          if (auth?.currentUser?.uid != user.uid ||
              scope() != controllerScope) {
            throw StateError('Provider account changed.');
          }
          final token = await user.getIdToken(true);
          if (token == null ||
              token.length < 8 ||
              auth?.currentUser?.uid != user.uid ||
              scope() != controllerScope) {
            throw StateError('Fresh provider proof is unavailable.');
          }
          return token;
        },
        scopeIsCurrent: () => mounted && scope() == controllerScope,
      ),
      appLock: LocalAppLockController(
        store: SecureLocalAppLockStore(
          tenantId: authentication.tenantId,
          country: authentication.country,
          identityId: authentication.identityId,
        ),
        signInAgain: _signOut,
        freshServerSignIn: session.hasFreshInteractiveAuthentication,
      ),
      consents: _consent,
      ownsConsents: false,
      lifecycle: AccountLifecycleController(
        AccountLifecycleApi(client),
        onDeactivated: _signOut,
      ),
    );
    _identityProfile = IdentityProfileController(
      expectedRole: AppRole.customer,
      remote: IdentityProfileApi(client),
      occupations: ProfileOccupationController(
        ProfileOccupationApi(client, country: authentication.country),
        scopeIsCurrent: () => mounted && scope() == controllerScope,
      ),
      education: PublishedEducationController(
        remote: PublishedEducationApi(client),
        role: 'customer',
        scope: jsonEncode([
          authentication.tenantId,
          authentication.country,
          authentication.identityId,
        ]),
        scopeIsCurrent: () => mounted && scope() == controllerScope,
      ),
      accountSecurity: widget.firebaseAuth == null
          ? null
          : AccountSecurityController(
              remote: AccountSecurityApi(client),
              provider: FirebaseAccountLinkingProvider(widget.firebaseAuth!),
              scopeIsCurrent: () => mounted && scope() == controllerScope,
            ),
    );
    _sessionManagement = IdentitySessionManagementController(
      IdentitySessionManagementApi(client),
    );
    _notificationPreferences = NotificationPreferencesController(
      NotificationPreferencesApi(client),
    );
    _support = SupportController(
      role: AppRole.customer,
      remote: SupportApi(client),
    );
    final messaging = widget.firebaseMessaging;
    if (messaging != null && _pushRegistration == null) {
      final identity = AppIdentity.forBuild(
        application: Planext4uApplication.customer,
        environment: widget.config.environment,
      );
      _pushRegistration = CustomerPushRegistration(
        messaging: FirebasePushMessaging(messaging),
        remote: PushDeviceApi(client),
        platform: Platform.isIOS ? 'IOS' : 'ANDROID',
        locale: Platform.localeName.replaceAll('_', '-').split('.').first,
        allowedHost: widget.config.deepLinkHost,
        allowedScheme: identity.customScheme,
        onDeepLink: (uri) {
          _notificationUri = uri;
          if (mounted) setState(() {});
        },
      );
      unawaited(_pushRegistration!.start());
    }
    _bootstrap = BootstrapController(
      remote: BootstrapApi(client),
      cache: CustomerBootstrapCache.platform(cacheScope),
      platform: Platform.isIOS ? MobilePlatform.ios : MobilePlatform.android,
      appVersion: const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '0.1.0',
      ),
      locale: Platform.localeName.split(RegExp('[-_]')).first,
    );
    _location = LocationController(
      platform: const GeolocatorDeviceLocation(),
      remote: ServiceabilityApi(client),
      hasConsent: _hasLocationConsent,
    );
    _geocoding = GeocodingApi(client);
    unawaited(
      _loadCustomerBootstrap(
        controllerScope,
        _bootstrap!,
        _consent!,
        _location!,
        _locationStore!,
      ),
    );
  }

  bool _hasLocationConsent() {
    final policies = _bootstrap?.state.config.consentPolicies ?? const [];
    for (final policy in policies) {
      if (policy.purpose == ConsentPurpose.locationServiceability.wireValue) {
        return _consent?.granted(
              ConsentPurpose.locationServiceability,
              policy.policyVersion,
            ) ??
            false;
      }
    }
    return false;
  }

  Future<void> _loadCustomerBootstrap(
    String scope,
    BootstrapController bootstrap,
    ConsentController consent,
    LocationController location,
    CustomerLocationStore store,
  ) async {
    try {
      await Future.wait([bootstrap.load(), consent.load()]);
      if (!mounted || _controllerScope != scope) return;
      final selected = await store.read();
      if (!mounted || _controllerScope != scope) return;
      if (selected != null && _hasLocationConsent()) {
        await location.selectManual(selected);
      }
    } catch (_) {
      // Each controller exposes a retryable UI state; startup remains available.
    }
  }

  Future<void> _authenticated() async {
    final session = _session;
    if (session != null && session.state.authentication != null) {
      _buildControllers(session);
      if (mounted) setState(() {});
    }
  }

  Future<void> _signOut() async {
    try {
      await _pushRegistration?.dispose(unregister: true);
    } catch (_) {
      // Session revocation still proceeds if a provider token is unavailable.
    }
    _pushRegistration = null;
    await _session?.signOut();
    _disposeControllers();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pushRegistration?.refreshAuthorization());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeControllers();
    unawaited(_sessionSubscription?.cancel());
    unawaited(_session?.dispose());
    unawaited(_pushRegistration?.dispose());
    _appearancePreferences?.dispose();
    _transport.close(force: true);
    super.dispose();
  }

  void _disposeControllers() {
    _controllerScope = null;
    _catalog?.dispose();
    _marketplace?.dispose();
    _cart?.dispose();
    _transactions?.dispose();
    _serviceBookings?.dispose();
    _food?.dispose();
    _social?.dispose();
    _phase5?.dispose();
    unawaited(_communityMediaCoordinator?.dispose());
    _accountPrivacy?.dispose();
    _identityProfile?.dispose();
    _sessionManagement?.dispose();
    _notificationPreferences?.dispose();
    _support?.dispose();
    _bootstrap?.dispose();
    _consent?.dispose();
    _location?.dispose();
    _catalog = null;
    _marketplace = null;
    _cart = null;
    _transactions = null;
    _serviceBookings = null;
    _food = null;
    _social = null;
    _phase5 = null;
    _communityMediaCoordinator = null;
    _accountPrivacy = null;
    _identityProfile = null;
    _sessionManagement = null;
    _notificationPreferences = null;
    _support = null;
    _bootstrap = null;
    _consent = null;
    _location = null;
    _geocoding = null;
    _locationStore = null;
    _notificationUri = null;
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final authentication = session?.state.authentication;
    final appearance =
        _appearancePreferences?.state.preferences ??
        AppearancePreferences.defaults();
    if (authentication != null) {
      _buildControllers(session!);
      return CustomerApp(
        key: ValueKey('${authentication.session.id}:${_notificationUri ?? ''}'),
        config: widget.config,
        catalogController: _catalog,
        marketplaceController: _marketplace,
        cartController: _cart,
        transactionController: _transactions,
        serviceBookingController: _serviceBookings,
        foodController: _food,
        socialController: _social,
        phase5Controller: _phase5,
        communityMediaCoordinator: _communityMediaCoordinator,
        socialRtcProviderFactory: widget.socialRtcProviderFactory,
        accountPrivacyController: _accountPrivacy,
        identityProfileController: _identityProfile,
        sessionManagementController: _sessionManagement,
        notificationPreferencesController: _notificationPreferences,
        supportController: _support,
        appearancePreferencesController: _appearancePreferences,
        bootstrapController: _bootstrap,
        consentController: _consent,
        locationController: _location,
        geocodingRemote: _geocoding,
        locationStore: _locationStore,
        initialUri: _notificationUri,
        profileDisplayName: authentication.profile.displayName,
        onSignOut: _signOut,
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
          ? _RuntimeStateScreen(failure: _startupFailure)
          : FirstRunGate(
              config: FirstRunConfig.forRole('customer'),
              store: EncryptedFirstRunStore.platform('customer'),
              child: CustomerSignInScreen(
                session: session,
                firebaseAuth: widget.firebaseAuth,
                firebaseFailure: widget.firebaseFailure,
                development:
                    widget.config.environment == AppEnvironment.development,
                onAuthenticated: _authenticated,
              ),
            ),
    );
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

class _RuntimeStateScreen extends StatelessWidget {
  const _RuntimeStateScreen({this.failure});
  final Object? failure;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Planext4uStatePanel(
          state: failure == null
              ? Planext4uViewState.loading
              : Planext4uViewState.error,
          title: failure == null
              ? 'Starting Planext4u'
              : 'Secure startup failed',
          message: failure == null
              ? 'Restoring your encrypted session.'
              : 'The secure session could not be initialized. Restart the app.',
        ),
      ),
    ),
  );
}

class CustomerSignInScreen extends StatefulWidget {
  const CustomerSignInScreen({
    required this.session,
    required this.development,
    required this.onAuthenticated,
    this.firebaseAuth,
    this.firebaseFailure,
    super.key,
  });
  final IdentitySessionController session;
  final FirebaseAuth? firebaseAuth;
  final Object? firebaseFailure;
  final bool development;
  final Future<void> Function() onAuthenticated;
  @override
  State<CustomerSignInScreen> createState() => _CustomerSignInScreenState();
}

class _CustomerSignInScreenState extends State<CustomerSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  String? _phoneChallenge;
  String? _message;
  bool _busy = false;
  bool _recoverAccount = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      await widget.onAuthenticated();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Sign-in could not be completed. Check your details and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailSignIn() async {
    final auth = widget.firebaseAuth;
    if (auth == null) return;
    await _run(() async {
      await widget.session.signInWithEmail(
        provider: FirebaseEmailProvider(auth),
        email: _email.text,
        secret: _password.text,
        recoverAccount: _recoverAccount,
      );
    });
  }

  Future<void> _emailRegister() async {
    final auth = widget.firebaseAuth;
    if (auth == null) return;
    await _run(() async {
      await widget.session.registerWithEmail(
        provider: FirebaseEmailProvider(auth),
        email: _email.text,
        secret: _password.text,
      );
    });
  }

  Future<void> _googleSignIn() async {
    final auth = widget.firebaseAuth;
    if (auth == null) return;
    await _run(() async {
      await widget.session.signInWithOAuth(
        provider: FirebaseOAuthProvider(auth),
        vendor: OAuthVendor.google,
        recoverAccount: _recoverAccount,
      );
    });
  }

  Future<void> _appleSignIn() async {
    final auth = widget.firebaseAuth;
    if (auth == null) return;
    await _run(() async {
      await widget.session.signInWithOAuth(
        provider: FirebaseOAuthProvider(auth),
        vendor: OAuthVendor.apple,
        recoverAccount: _recoverAccount,
      );
    });
  }

  Future<void> _requestOtp() async {
    final auth = widget.firebaseAuth;
    if (auth == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final provider = FirebasePhoneProvider(auth);
      final challenge = await provider.requestCode(phoneNumber: _phone.text);
      _phoneProvider = provider;
      if (mounted) {
        setState(() {
          _phoneChallenge = challenge;
          _message = 'Verification code sent.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not send a verification code.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  FirebasePhoneProvider? _phoneProvider;

  Future<void> _verifyOtp() async {
    final provider = _phoneProvider;
    final challenge = _phoneChallenge;
    if (provider == null || challenge == null) return;
    await _run(() async {
      await widget.session.signInWithPhoneOtp(
        provider: provider,
        challengeId: challenge,
        code: _otp.text,
        recoverAccount: _recoverAccount,
      );
    });
  }

  Future<void> _developmentSignIn() => _run(() async {
    await widget.session.signInWithEmail(
      provider: const _DevelopmentIdentityProvider(),
      email: 'synthetic@local.invalid',
      secret: 'development-only',
    );
  });

  @override
  Widget build(BuildContext context) {
    final firebaseAvailable = widget.firebaseAuth != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in to Planext4u')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Planext4uSpacing.x5),
          children: [
            Text(
              'Your neighbourhood, in one place',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Planext4uSpacing.x4),
            if (!firebaseAvailable)
              const Planext4uStatePanel(
                state: Planext4uViewState.error,
                title: 'Sign-in configuration unavailable',
                message:
                    'This build is missing its Firebase environment configuration.',
              )
            else ...[
              CheckboxListTile(
                value: _recoverAccount,
                onChanged: _busy
                    ? null
                    : (value) =>
                          setState(() => _recoverAccount = value ?? false),
                title: const Text('Recover my deactivated account'),
              ),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => _emailSignIn(),
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              FilledButton(
                onPressed: _busy ? null : _emailSignIn,
                child: const Text('Sign in with email'),
              ),
              PasswordRecoveryButton(
                emailController: _email,
                provider: FirebaseEmailProvider(widget.firebaseAuth!),
              ),
              OutlinedButton(
                onPressed: _busy || _recoverAccount ? null : _emailRegister,
                child: const Text('Create customer account'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _googleSignIn,
                child: const Text('Continue with Google'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _appleSignIn,
                child: const Text('Continue with Apple'),
              ),
              const Divider(height: Planext4uSpacing.x6),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Phone number with country code',
                ),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _requestOtp,
                child: const Text('Send verification code'),
              ),
              if (_phoneChallenge != null) ...[
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : _verifyOtp,
                  child: const Text('Verify and sign in'),
                ),
              ],
            ],
            if (widget.development) ...[
              const Divider(height: Planext4uSpacing.x6),
              OutlinedButton.icon(
                onPressed: _busy ? null : _developmentSignIn,
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
}

final class _DevelopmentIdentityProvider implements EmailIdentityProvider {
  const _DevelopmentIdentityProvider();
  @override
  Future<ProviderAssertion> authenticate({
    required String email,
    required String secret,
  }) async => ProviderAssertion(
    provider: IdentityProviderKind.local,
    token: 'synthetic-customer',
  );
}

class CustomerApp extends StatefulWidget {
  const CustomerApp({
    required this.config,
    this.catalogController,
    this.marketplaceController,
    this.cartController,
    this.transactionController,
    this.serviceBookingController,
    this.foodController,
    this.socialController,
    this.phase5Controller,
    this.communityMediaCoordinator,
    this.socialRtcProviderFactory,
    this.accountPrivacyController,
    this.identityProfileController,
    this.sessionManagementController,
    this.notificationPreferencesController,
    this.supportController,
    this.appearancePreferencesController,
    this.paymentRecoveryStore,
    this.bootstrapController,
    this.consentController,
    this.locationController,
    this.geocodingRemote,
    this.locationStore,
    this.initialUri,
    this.profileDisplayName,
    this.locale,
    this.onSignOut,
    super.key,
  });

  final AppConfig config;
  final CatalogController? catalogController;
  final MarketplaceController? marketplaceController;
  final CartController? cartController;
  final TransactionController? transactionController;
  final ServiceBookingController? serviceBookingController;
  final FoodController? foodController;
  final SocialController? socialController;
  final Phase5Controller? phase5Controller;
  final CommunityMediaCoordinator? communityMediaCoordinator;
  final SocialRtcOfferProviderFactory? socialRtcProviderFactory;
  final AccountPrivacyController? accountPrivacyController;
  final IdentityProfileController? identityProfileController;
  final IdentitySessionManagementController? sessionManagementController;
  final NotificationPreferencesController? notificationPreferencesController;
  final SupportController? supportController;
  final AppearancePreferencesController? appearancePreferencesController;
  final PaymentRecoveryStore? paymentRecoveryStore;
  final BootstrapController? bootstrapController;
  final ConsentController? consentController;
  final LocationController? locationController;
  final GeocodingRemote? geocodingRemote;
  final CustomerLocationStore? locationStore;
  final Uri? initialUri;
  final String? profileDisplayName;
  final Locale? locale;
  final Future<void> Function()? onSignOut;

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  late final NativePaymentProviderLauncher _paymentLauncher =
      NativePaymentProviderLauncher();
  late final _AuthenticatedSessionRequiredRemote _requiredRemote =
      _AuthenticatedSessionRequiredRemote();
  late final bool _ownsController = widget.catalogController == null;
  late final CatalogController _catalog =
      widget.catalogController ??
      CatalogController(
        remote: _requiredRemote,
        cache: MemoryCustomerHomeCache(),
      );
  late final bool _ownsMarketplace = widget.marketplaceController == null;
  late final MarketplaceController _marketplace =
      widget.marketplaceController ??
      MarketplaceController(remote: _requiredRemote);
  late final bool _ownsCart = widget.cartController == null;
  late final CartController _cart =
      widget.cartController ?? CartController(remote: _requiredRemote);
  late final bool _ownsTransactions = widget.transactionController == null;
  late final TransactionController _transactions =
      widget.transactionController ??
      TransactionController(
        remote: _requiredRemote,
        recoveryStore:
            widget.paymentRecoveryStore ?? MemoryPaymentRecoveryStore(),
      );
  late final bool _ownsServiceBookings =
      widget.serviceBookingController == null;
  late final ServiceBookingController _serviceBookings =
      widget.serviceBookingController ??
      ServiceBookingController(
        remote: _AuthenticatedServiceBookingRequiredRemote(),
      );
  late final bool _ownsFood = widget.foodController == null;
  late final FoodController _food =
      widget.foodController ??
      FoodController(remote: _AuthenticatedFoodRequiredRemote());
  late final bool _ownsSocial = widget.socialController == null;
  late final SocialController _social =
      widget.socialController ??
      SocialController(remote: _AuthenticatedSocialRequiredRemote());

  @override
  void dispose() {
    if (_ownsController) _catalog.dispose();
    if (_ownsMarketplace) _marketplace.dispose();
    if (_ownsCart) _cart.dispose();
    if (_ownsTransactions) _transactions.dispose();
    if (_ownsServiceBookings) _serviceBookings.dispose();
    if (_ownsFood) _food.dispose();
    if (_ownsSocial) _social.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance =
        widget.appearancePreferencesController?.state.preferences ??
        AppearancePreferences.defaults();
    final link = widget.initialUri == null
        ? null
        : CustomerDeepLink.parse(widget.initialUri!);
    final destination = link is CustomerCatalogLink || link is CustomerItemLink
        ? CustomerDestination.explore
        : link is CustomerOrderLink
        ? CustomerDestination.activity
        : CustomerDestination.home;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Planext4u Customer',
      locale: widget.locale ?? appearance.locale,
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
          controller: widget.accountPrivacyController?.appLock,
          child: PublishedEducationGate(
            controller: widget.identityProfileController?.education,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: Listenable.merge([
          if (widget.bootstrapController != null) widget.bootstrapController!,
          if (widget.consentController != null) widget.consentController!,
          if (widget.locationController != null) widget.locationController!,
        ]),
        builder: (context, _) {
          final content = Semantics(
            label:
                'Planext4u ${widget.config.environmentLabel} customer application',
            child: CustomerHomeScreen(
              controller: _catalog,
              initialDestination: destination,
              initialItemId: link is CustomerItemLink ? link.itemId : null,
              marketplaceController: _marketplace,
              cartController: _cart,
              transactionController: _transactions,
              serviceBookingController: _serviceBookings,
              foodController: _food,
              socialController: _social,
              phase5Controller: widget.phase5Controller,
              communityMediaCoordinator: widget.communityMediaCoordinator,
              socialRtcProviderFactory: widget.socialRtcProviderFactory,
              accountPrivacyController: widget.accountPrivacyController,
              identityProfileController: widget.identityProfileController,
              sessionManagementController: widget.sessionManagementController,
              notificationPreferencesController:
                  widget.notificationPreferencesController,
              supportController: widget.supportController,
              appearancePreferencesController:
                  widget.appearancePreferencesController,
              openCommunityInitially: link is CustomerCommunityLink,
              initialCommunityTab: link is CustomerCommunityLink ? link.tab : 0,
              openSocialInitially: link is CustomerSocialLink,
              initialSocialPostId: link is CustomerSocialLink
                  ? link.postId
                  : null,
              paymentLauncher: _paymentLauncher,
              profileDisplayName: widget.profileDisplayName,
              onSignOut: widget.onSignOut,
              homeSections:
                  widget.bootstrapController?.state.config.homeSections ??
                  const [],
            ),
          );
          final bootstrap = widget.bootstrapController;
          if (bootstrap == null) return content;
          final consent = widget.consentController;
          final location = widget.locationController;
          final geocoding = widget.geocodingRemote;
          Widget gated = content;
          if (consent != null && location != null && geocoding != null) {
            gated = _CustomerFtuxGate(
              bootstrap: bootstrap.state.config,
              consent: consent,
              location: location,
              geocoding: geocoding,
              locationStore: widget.locationStore,
              child: content,
            );
          }
          return BootstrapGateView(
            state: bootstrap.state,
            onRetry: bootstrap.load,
            child: gated,
          );
        },
      ),
    );
  }
}

class _CustomerFtuxGate extends StatefulWidget {
  const _CustomerFtuxGate({
    required this.bootstrap,
    required this.consent,
    required this.location,
    required this.geocoding,
    required this.child,
    this.locationStore,
  });

  final BootstrapConfig bootstrap;
  final ConsentController consent;
  final LocationController location;
  final GeocodingRemote geocoding;
  final CustomerLocationStore? locationStore;
  final Widget child;

  @override
  State<_CustomerFtuxGate> createState() => _CustomerFtuxGateState();
}

class _CustomerFtuxGateState extends State<_CustomerFtuxGate> {
  bool _busy = false;
  String? _error;

  ConsentPolicy? get _locationPolicy {
    for (final policy in widget.bootstrap.consentPolicies) {
      if (policy.purpose == ConsentPurpose.locationServiceability.wireValue) {
        return policy;
      }
    }
    return null;
  }

  Future<void> _grantLocationConsent() async {
    final policy = _locationPolicy;
    if (policy == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.consent.setConsent(
        purpose: ConsentPurpose.locationServiceability,
        granted: true,
        policyVersion: policy.policyVersion,
      );
    } catch (_) {
      if (mounted) {
        _error =
            'Consent could not be saved. Check your connection and try again.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    await widget.location.useCurrentLocation();
    await _saveSelectedLocation();
  }

  Future<void> _chooseManualLocation() async {
    final candidate = await showModalBottomSheet<GeocodeCandidate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ManualLocationSheet(remote: widget.geocoding),
    );
    if (candidate == null || !mounted) return;
    await widget.location.selectManual(
      candidate.toServiceLocation(DateTime.now()),
    );
    await _saveSelectedLocation();
  }

  Future<void> _saveSelectedLocation() async {
    final state = widget.location.state;
    if (state.canContinue && state.location != null) {
      await widget.locationStore?.write(state.location!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = _locationPolicy;
    if (policy == null) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.error,
        title: 'Location policy unavailable',
        message:
            'Planext4u cannot request your location until the privacy policy is available.',
      );
    }
    if (widget.consent.loading) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Loading privacy choices',
        message: 'Checking your saved consent preferences.',
      );
    }
    if (!widget.consent.granted(
      ConsentPurpose.locationServiceability,
      policy.policyVersion,
    )) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Planext4uSpacing.x5),
          children: [
            const Icon(Icons.location_city_outlined, size: 64),
            const SizedBox(height: Planext4uSpacing.x4),
            Text(
              'Find what is available nearby',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            const Text(
              'With your permission, Planext4u uses a location you select only to check serviceability and show local sellers. You can choose GPS or search by locality/pincode.',
            ),
            const SizedBox(height: Planext4uSpacing.x5),
            FilledButton.icon(
              onPressed: _busy ? null : _grantLocationConsent,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Allow serviceability check'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Planext4uSpacing.x3),
                child: Semantics(liveRegion: true, child: Text(_error!)),
              ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      );
    }
    return LocationGateView(
      state: widget.location.state,
      onUseCurrent: () => unawaited(_useCurrentLocation()),
      onChooseManual: () => unawaited(_chooseManualLocation()),
      onRetry: widget.location.retry,
      onOpenSettings: () => unawaited(
        widget.location.state.status == LocationStatus.serviceDisabled
            ? widget.location.openLocationSettings()
            : widget.location.openAppSettings(),
      ),
      child: widget.child,
    );
  }
}

class _ManualLocationSheet extends StatefulWidget {
  const _ManualLocationSheet({required this.remote});
  final GeocodingRemote remote;

  @override
  State<_ManualLocationSheet> createState() => _ManualLocationSheetState();
}

class _ManualLocationSheetState extends State<_ManualLocationSheet> {
  final _query = TextEditingController();
  List<GeocodeCandidate> _items = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().length < 2 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await widget.remote.search(_query.text);
      if (mounted) setState(() => _items = values);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Locations could not be loaded. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        Planext4uSpacing.x4,
        Planext4uSpacing.x2,
        Planext4uSpacing.x4,
        MediaQuery.viewInsetsOf(context).bottom + Planext4uSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose locality or pincode',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Locality or pincode',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _search(),
          ),
          FilledButton(
            onPressed: _loading ? null : _search,
            child: const Text('Search'),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          if (!_loading &&
              _error == null &&
              _items.isEmpty &&
              _query.text.trim().length >= 2)
            const Text('No serviceable locations matched that search.'),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _items.length,
              itemBuilder: (context, index) => ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(_items[index].label),
                onTap: () => Navigator.of(context).pop(_items[index]),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _AuthenticatedSocialRequiredRemote implements SocialRemote {
  Never _required() => throw const ApiAuthenticationFailure(
    code: 'AUTHENTICATION_REQUIRED',
    message: 'Sign in to continue.',
    correlationId: 'local-auth-boundary',
  );

  @override
  Future<SocialFeedPage> feed({String? cursor, int limit = 20}) async =>
      _required();
  @override
  Future<SocialPost> post(String id) async => _required();
  @override
  Future<SocialPost> createPost(String body) async => _required();
  @override
  Future<SocialPost> setLike(SocialPost post, bool active) async => _required();
  @override
  Future<SocialPost> setSave(SocialPost post, bool active) async => _required();
  @override
  Future<List<SocialComment>> comments(String postId) async => _required();
  @override
  Future<SocialComment> createComment(
    String postId,
    String body, {
    String? parentId,
  }) async => _required();
  @override
  Future<void> report(
    String postId,
    String reason, {
    String details = '',
  }) async => _required();
}

final class _AuthenticatedServiceBookingRequiredRemote
    implements ServiceBookingRemote {
  Never _required() => throw const ApiAuthenticationFailure(
    code: 'AUTHENTICATION_REQUIRED',
    message: 'Sign in to continue.',
    correlationId: 'local-auth-boundary',
  );

  @override
  Future<List<ServiceOffering>> offerings({
    required String postalCode,
    String? categoryId,
  }) async => _required();
  @override
  Future<ServiceOffering> offering(
    String id, {
    required String postalCode,
  }) async => _required();
  @override
  Future<List<ServiceSlot>> slots(
    String offeringId, {
    DateTime? from,
    DateTime? to,
  }) async => _required();
  @override
  Future<ServiceSlotHold> hold({
    required String slotId,
    required String postalCode,
  }) async => _required();
  @override
  Future<void> releaseHold(String id) async => _required();
  @override
  Future<List<ServiceBooking>> bookings() async => _required();
  @override
  Future<ServiceBooking> booking(String id) async => _required();
  @override
  Future<ServiceBooking> create({
    required String holdId,
    required ServicePaymentMethod paymentMethod,
  }) async => _required();
  @override
  Future<ServiceBooking> confirmPayment(ServiceBooking booking) async =>
      _required();
  @override
  Future<ServiceBooking> reschedule({
    required ServiceBooking booking,
    required String holdId,
    required String reason,
  }) async => _required();
  @override
  Future<ServiceBooking> cancel({
    required ServiceBooking booking,
    required String reason,
  }) async => _required();
  @override
  Future<ServiceBooking> providerTransition({
    required ServiceBooking booking,
    required String status,
    String reason = '',
  }) async => _required();
  @override
  Future<ServiceBooking> start({
    required ServiceBooking booking,
    required String otp,
  }) async => _required();
  @override
  Future<ServiceBooking> complete({
    required ServiceBooking booking,
    required String photoAssetId,
  }) async => _required();
  @override
  Future<ServiceBooking> confirmCompletion(ServiceBooking booking) async =>
      _required();
  @override
  Future<ServiceBooking> noShow({
    required ServiceBooking booking,
    required String reason,
  }) async => _required();
  @override
  Future<ServiceBooking> dispute({
    required ServiceBooking booking,
    required String reason,
  }) async => _required();
}

final class _AuthenticatedFoodRequiredRemote implements FoodRemote {
  Never _required() => throw const ApiAuthenticationFailure(
    code: 'AUTHENTICATION_REQUIRED',
    message: 'Sign in to continue.',
    correlationId: 'local-auth-boundary',
  );

  @override
  Future<List<FoodRestaurant>> restaurants(String postalCode) async =>
      _required();
  @override
  Future<List<FoodMenuItem>> menu(String restaurantId) async => _required();
  @override
  Future<FoodCart> priceCart({
    required String restaurantId,
    required String postalCode,
    required List<FoodCartLineRequest> lines,
  }) async => _required();
  @override
  Future<FoodOrder> placeOrder(String cartId, String paymentMethod) async =>
      _required();
  @override
  Future<List<FoodOrder>> orders() async => _required();
  @override
  Future<FoodOrder> order(String id) async => _required();
}

final class _AuthenticatedSessionRequiredRemote
    implements CatalogRemote, CartRemote, TransactionRemote {
  Never _required() => throw const ApiAuthenticationFailure(
    code: 'AUTHENTICATION_REQUIRED',
    message: 'Sign in to continue.',
    correlationId: 'local-auth-boundary',
  );

  @override
  Future<CatalogPage<CatalogCategory>> categories() async => _required();

  @override
  Future<CustomerHomeProjection> home() async => _required();

  @override
  Future<CatalogItem> item(String id) async => _required();

  @override
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => _required();

  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => _required();

  @override
  Future<CustomerCart> getCart() async => _required();

  @override
  Future<CustomerCart> removeItem({
    required String variantId,
    required int expectedRevision,
    String? idempotencyKey,
  }) async => _required();

  @override
  Future<CustomerCart> setItem({
    required String variantId,
    required int quantity,
    required int expectedRevision,
    String? idempotencyKey,
  }) async => _required();

  @override
  Future<List<CustomerAddress>> addresses() async => _required();
  @override
  Future<CustomerAddress> createAddress(
    CustomerAddressDraft value, {
    String? idempotencyKey,
  }) async => _required();
  @override
  Future<CustomerAddress> updateAddress(
    CustomerAddress current,
    CustomerAddressDraft value, {
    String? idempotencyKey,
  }) async => _required();
  @override
  Future<void> deleteAddress(
    CustomerAddress value, {
    String? idempotencyKey,
  }) async => _required();
  @override
  Future<List<CustomerDeliverySlot>> deliverySlots() async => _required();
  @override
  Future<CheckoutQuote> quote({
    required int cartRevision,
    required String addressId,
    required String deliverySlotId,
    required String promotionCode,
    required int walletPoints,
    String? idempotencyKey,
  }) async => _required();
  @override
  Future<PlaceOrderResult> place({
    required String quoteId,
    required CustomerPaymentMethod method,
    String? idempotencyKey,
  }) async => _required();
  @override
  Future<CustomerPayment> payment(String id) async => _required();
  @override
  Future<CustomerPayment> retryPayment(
    String id, {
    String? idempotencyKey,
  }) async => _required();
  @override
  Future<List<CustomerOrder>> orders() async => _required();
  @override
  Future<CustomerOrder> order(String id) async => _required();
  @override
  Future<CustomerOrder> cancel({
    required CustomerOrder order,
    required String reason,
  }) async => _required();
  @override
  Future<CustomerOrder> confirmDelivery(CustomerOrder order) async =>
      _required();
  @override
  Future<CustomerOrder> requestReturn({
    required CustomerOrder order,
    required List<Map<String, Object?>> lines,
    required String reason,
  }) async => _required();
  @override
  Future<CustomerOrder> rate({
    required CustomerOrder order,
    required int score,
    required String comment,
  }) async => _required();
  @override
  Future<WalletAccount> wallet() async => _required();
  @override
  Future<WalletExperience> walletExperience() async => _required();
  @override
  Future<ReferralProfile> applyReferral(String code) async => _required();
  @override
  Future<WalletRefillResult> createWalletRefill({
    required String offerId,
    required CustomerPaymentMethod method,
  }) async => _required();
}

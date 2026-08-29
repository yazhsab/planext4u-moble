import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

import 'firebase_identity_providers.dart';
import 'payment_provider_launcher.dart';
import 'push_registration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(
    CustomerRuntime(
      config: AppConfig.fromCompileTime(),
      firebaseAuth: firebaseAuth,
      firebaseMessaging: firebaseMessaging,
      firebaseFailure: firebaseFailure,
    ),
  );
}

class CustomerRuntime extends StatefulWidget {
  const CustomerRuntime({
    required this.config,
    this.firebaseAuth,
    this.firebaseMessaging,
    this.firebaseFailure,
    super.key,
  });

  final AppConfig config;
  final FirebaseAuth? firebaseAuth;
  final FirebaseMessaging? firebaseMessaging;
  final Object? firebaseFailure;

  @override
  State<CustomerRuntime> createState() => _CustomerRuntimeState();
}

class _CustomerRuntimeState extends State<CustomerRuntime> {
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
  BootstrapController? _bootstrap;
  ConsentController? _consent;
  LocationController? _location;
  GeocodingRemote? _geocoding;
  final _EncryptedLocationStore _locationStore = _EncryptedLocationStore();
  Object? _startupFailure;
  CustomerPushRegistration? _pushRegistration;
  Uri? _notificationUri;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final identityClient = ApiClient(
        baseUrl: widget.config.apiBaseUrl,
        transport: _transport,
      );
      final deviceId = await _deviceId();
      final session = IdentitySessionController(
        remote: IdentityApi(identityClient),
        store: PlatformSecureSessionStore(
          namespace: 'planext4u.customer.identity.v1',
        ),
        applicationRole: AppRole.customer,
        deviceId: deviceId,
        country: 'IN',
      );
      _session = session;
      _sessionSubscription = session.states.listen((_) {
        if (mounted) setState(() {});
      });
      await session.initialize();
      if (session.state.authentication != null) _buildControllers(session);
    } catch (error) {
      _startupFailure = error;
    }
    if (mounted) setState(() {});
  }

  void _buildControllers(IdentitySessionController session) {
    if (_catalog != null) return;
    final client = ApiClient(
      baseUrl: widget.config.apiBaseUrl,
      transport: _transport,
      authSession: session,
    );
    _catalog = CatalogController(
      remote: CatalogApi(client),
      cache: MemoryCustomerHomeCache(),
    );
    _marketplace = MarketplaceController(remote: CatalogApi(client));
    _cart = CartController(remote: CartApi(client));
    _transactions = TransactionController(
      remote: TransactionApi(client),
      recoveryStore: _EncryptedPaymentRecoveryStore(),
    );
    _serviceBookings = ServiceBookingController(
      remote: ServiceBookingApi(client),
    );
    _food = FoodController(remote: FoodApi(client));
    _social = SocialController(remote: SocialApi(client));
    _phase5 = Phase5Controller(remote: Phase5Api(client));
    final messaging = widget.firebaseMessaging;
    if (messaging != null && _pushRegistration == null) {
      _pushRegistration = CustomerPushRegistration(
        messaging: FirebasePushMessaging(messaging),
        remote: PushDeviceApi(client),
        platform: Platform.isIOS ? 'IOS' : 'ANDROID',
        locale: Platform.localeName.replaceAll('_', '-').split('.').first,
        onDeepLink: (uri) {
          _notificationUri = uri;
          if (mounted) setState(() {});
        },
      );
      unawaited(_pushRegistration!.start());
    }
    _bootstrap = BootstrapController(
      remote: BootstrapApi(client),
      cache: _EncryptedBootstrapCache(),
      platform: Platform.isIOS ? MobilePlatform.ios : MobilePlatform.android,
      appVersion: const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '0.1.0',
      ),
      locale: Platform.localeName.split(RegExp('[-_]')).first,
    );
    _consent = ConsentController(ConsentApi(client));
    _location = LocationController(
      platform: const GeolocatorDeviceLocation(),
      remote: ServiceabilityApi(client),
      hasConsent: _hasLocationConsent,
    );
    _geocoding = GeocodingApi(client);
    unawaited(_loadCustomerBootstrap());
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

  Future<void> _loadCustomerBootstrap() async {
    try {
      await Future.wait([_bootstrap!.load(), _consent!.load()]);
      final selected = await _locationStore.read();
      if (selected != null && _hasLocationConsent()) {
        await _location!.selectManual(selected);
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
  void dispose() {
    _disposeControllers();
    unawaited(_sessionSubscription?.cancel());
    unawaited(_session?.dispose());
    unawaited(_pushRegistration?.dispose());
    _transport.close(force: true);
    super.dispose();
  }

  void _disposeControllers() {
    _catalog?.dispose();
    _marketplace?.dispose();
    _cart?.dispose();
    _transactions?.dispose();
    _serviceBookings?.dispose();
    _food?.dispose();
    _social?.dispose();
    _phase5?.dispose();
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
    _bootstrap = null;
    _consent = null;
    _location = null;
    _geocoding = null;
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final authentication = session?.state.authentication;
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
      theme: Planext4uTheme.light,
      darkTheme: Planext4uTheme.dark,
      home: session == null
          ? _RuntimeStateScreen(failure: _startupFailure)
          : CustomerSignInScreen(
              session: session,
              firebaseAuth: widget.firebaseAuth,
              firebaseFailure: widget.firebaseFailure,
              development:
                  widget.config.environment == AppEnvironment.development,
              onAuthenticated: _authenticated,
            ),
    );
  }
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

Future<String> _deviceId() async {
  const storage = FlutterSecureStorage();
  const key = 'planext4u.customer.device-id.v1';
  final existing = await storage.read(key: key);
  if (existing != null && RegExp(r'^device-[a-f0-9]{32}$').hasMatch(existing)) {
    return existing;
  }
  final random = Random.secure();
  final value = List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  final generated = 'device-$value';
  await storage.write(key: key, value: generated);
  return generated;
}

abstract interface class CustomerLocationStore {
  Future<ServiceLocation?> read();
  Future<void> write(ServiceLocation value);
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
    this.paymentRecoveryStore,
    this.bootstrapController,
    this.consentController,
    this.locationController,
    this.geocodingRemote,
    this.locationStore,
    this.initialUri,
    this.profileDisplayName,
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
  final PaymentRecoveryStore? paymentRecoveryStore;
  final BootstrapController? bootstrapController;
  final ConsentController? consentController;
  final LocationController? locationController;
  final GeocodingRemote? geocodingRemote;
  final CustomerLocationStore? locationStore;
  final Uri? initialUri;
  final String? profileDisplayName;
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
            widget.paymentRecoveryStore ?? _EncryptedPaymentRecoveryStore(),
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
      theme: Planext4uTheme.light,
      darkTheme: Planext4uTheme.dark,
      themeMode: ThemeMode.system,
      supportedLocales: Planext4uLocalizations.supportedLocales,
      localizationsDelegates: const [
        Planext4uLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

final class _EncryptedPaymentRecoveryStore implements PaymentRecoveryStore {
  _EncryptedPaymentRecoveryStore()
    : _store = EncryptedRecordStore(
        records: FileBinaryRecordStore(namespace: 'customer-payment-recovery'),
        keyProvider: PlatformCacheKeyProvider(
          namespace: 'planext4u.payment.recovery.v1',
        ),
        namespace: 'customer-payment-recovery',
      );

  static const _key = 'pending.payment';
  final EncryptedRecordStore _store;

  @override
  Future<void> clear() => _store.delete(_key);

  @override
  Future<String?> read() async =>
      (await _store.get<String>(_key, (value) => value! as String)).value;

  @override
  Future<void> save(String paymentId) {
    final now = DateTime.now().toUtc();
    return _store.put(
      _key,
      paymentId,
      expiresAt: now.add(const Duration(days: 7)),
      staleUntil: now.add(const Duration(days: 7)),
    );
  }
}

final class _EncryptedBootstrapCache implements BootstrapCache {
  _EncryptedBootstrapCache()
    : _store = EncryptedRecordStore(
        records: FileBinaryRecordStore(namespace: 'customer-bootstrap'),
        keyProvider: PlatformCacheKeyProvider(
          namespace: 'planext4u.bootstrap.v1',
        ),
        namespace: 'customer-bootstrap',
      );

  static const _key = 'configuration';
  final EncryptedRecordStore _store;

  @override
  Future<BootstrapConfig?> read() async => (await _store.get<BootstrapConfig>(
    _key,
    (value) => BootstrapConfig.fromJson(value),
  )).value;

  @override
  Future<void> write(BootstrapConfig value) {
    final now = DateTime.now().toUtc();
    return _store.put(
      _key,
      value.toJson(),
      expiresAt: now.add(const Duration(hours: 24)),
      staleUntil: now.add(const Duration(days: 7)),
    );
  }
}

final class _EncryptedLocationStore implements CustomerLocationStore {
  _EncryptedLocationStore()
    : _store = EncryptedRecordStore(
        records: FileBinaryRecordStore(namespace: 'customer-selected-location'),
        keyProvider: PlatformCacheKeyProvider(
          namespace: 'planext4u.location.v1',
        ),
        namespace: 'customer-selected-location',
      );

  static const _key = 'serviceability.location';
  final EncryptedRecordStore _store;

  @override
  Future<ServiceLocation?> read() async =>
      (await _store.get<ServiceLocation>(_key, (value) {
        if (value is! Map<String, Object?> ||
            value['latitude'] is! num ||
            value['longitude'] is! num ||
            value['accuracy_metres'] is! num ||
            value['captured_at'] is! String ||
            value['label'] is! String) {
          throw const FormatException('Stored location is invalid.');
        }
        final capturedAt = DateTime.tryParse(value['captured_at']! as String);
        if (capturedAt == null) {
          throw const FormatException('Stored location time is invalid.');
        }
        return ServiceLocation(
          latitude: (value['latitude']! as num).toDouble(),
          longitude: (value['longitude']! as num).toDouble(),
          accuracyMetres: (value['accuracy_metres']! as num).toDouble(),
          capturedAt: capturedAt.toUtc(),
          label: value['label']! as String,
        );
      })).value;

  @override
  Future<void> write(ServiceLocation value) {
    final now = DateTime.now().toUtc();
    return _store.put(
      _key,
      {
        'latitude': value.latitude,
        'longitude': value.longitude,
        'accuracy_metres': value.accuracyMetres,
        'captured_at': value.capturedAt.toIso8601String(),
        'label': value.label,
      },
      expiresAt: now.add(const Duration(days: 30)),
      staleUntil: now.add(const Duration(days: 30)),
    );
  }
}

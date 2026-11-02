import 'dart:async';
import 'package:flutter/material.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'localization.dart';
import 'startup_splash.dart';

/// Draws the first frame before provider initialization. The normal runtime
/// starts concurrently and stays mounted behind the bounded public splash.
/// Startup content never controls identity, permission prompts or navigation.
final class PublicStartupGate extends StatefulWidget {
  const PublicStartupGate({
    required this.apiBaseUrl,
    required this.role,
    required this.initialize,
    this.country = 'IN',
    this.controller,
    super.key,
  });
  final Uri apiBaseUrl;
  final String role, country;
  final Future<Widget> Function() initialize;
  final PublicStartupController? controller;
  static const displayBudget = Duration(milliseconds: 1200);
  @override
  State<PublicStartupGate> createState() => _PublicStartupGateState();
}

class _PublicStartupGateState extends State<PublicStartupGate> {
  late PublicStartupController _controller;
  IoApiTransport? _transport;
  bool _ownsController = false;
  Widget? _runtime;
  bool _showSplash = true, _failed = false;
  int _generation = 0;
  Timer? _timer;
  Timer? _runtimeTimer;
  String get _locale {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return isPlanext4uLocaleCode(code) ? code : 'en';
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _showSplash = true;
    _failed = false;
    _runtime = null;
    final supplied = widget.controller;
    _ownsController = supplied == null;
    if (supplied != null) {
      if (supplied.country != widget.country || supplied.role != widget.role) {
        throw const FormatException(
          'Public startup controller scope does not match this app.',
        );
      }
      _controller = supplied;
    } else {
      final transport = IoApiTransport(maxResponseBytes: 16384);
      _transport = transport;
      _controller = PublicStartupController(
        remote: PublicStartupApi(
          ApiClient(
            baseUrl: widget.apiBaseUrl,
            transport: transport,
            retryBudget: const ApiRetryBudget(maxAttempts: 1),
            attemptTimeout: const Duration(seconds: 1),
          ),
        ),
        store: EncryptedPublicStartupStore(
          endpoint: widget.apiBaseUrl,
          country: widget.country,
          role: widget.role,
          locale: _locale,
        ),
        country: widget.country,
        role: widget.role,
        locale: _locale,
      );
    }
    _controller.addListener(_changed);
    unawaited(_controller.load());
    _timer = Timer(PublicStartupGate.displayBudget, _finish);
    unawaited(_initializeRuntime());
  }

  Future<void> _initializeRuntime() async {
    final generation = ++_generation;
    _runtimeTimer?.cancel();
    final timeout = Timer(const Duration(seconds: 5), () {
      if (mounted && generation == _generation) {
        _generation++;
        setState(() => _failed = true);
      }
    });
    _runtimeTimer = timeout;
    if (mounted) setState(() => _failed = false);
    try {
      final runtime = await Future<Widget>.sync(widget.initialize);
      if (mounted && generation == _generation) {
        setState(() => _runtime = runtime);
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      timeout.cancel();
      if (identical(_runtimeTimer, timeout)) _runtimeTimer = null;
    }
  }

  void _changed() {
    if (mounted && _showSplash) setState(() {});
  }

  void _finish() {
    if (!mounted || !_showSplash) return;
    _timer?.cancel();
    _controller.stop();
    _transport?.close(force: true);
    setState(() => _showSplash = false);
  }

  void _release() {
    _timer?.cancel();
    _runtimeTimer?.cancel();
    _controller.removeListener(_changed);
    _controller.stop();
    if (_ownsController) _controller.dispose();
    _transport?.close(force: true);
    _transport = null;
  }

  @override
  void didUpdateWidget(covariant PublicStartupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiBaseUrl != widget.apiBaseUrl ||
        oldWidget.role != widget.role ||
        oldWidget.country != widget.country ||
        oldWidget.controller != widget.controller) {
      _generation++;
      _release();
      _start();
    }
  }

  @override
  void dispose() {
    _generation++;
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = _showSplash ? _controller.document : null;
    final overlay = _showSplash || _runtime == null;
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: overlay,
          child: ExcludeFocus(
            excluding: overlay,
            child: ExcludeSemantics(
              excluding: overlay,
              child: _runtime ?? const SizedBox.shrink(),
            ),
          ),
        ),
        if (overlay)
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Planext4uTheme.light,
            darkTheme: Planext4uTheme.dark,
            supportedLocales: Planext4uLocalizations.supportedLocales,
            localizationsDelegates:
                Planext4uLocalizations.localizationsDelegates,
            locale: Locale(_locale),
            home: Scaffold(
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hub_outlined, size: 56),
                                const SizedBox(height: 20),
                                Text(
                                  document?.title ?? 'Planext4u',
                                  key: const ValueKey('public-startup-title'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                  textAlign: TextAlign.center,
                                ),
                                if (document?.message
                                    case final String message) ...[
                                  const SizedBox(height: 16),
                                  Text(message, textAlign: TextAlign.center),
                                ],
                                const SizedBox(height: 24),
                                if (_failed) ...[
                                  const Text(
                                    'The app could not start. Try again.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    key: const ValueKey(
                                      'retry-startup-runtime',
                                    ),
                                    onPressed: _initializeRuntime,
                                    child: Text(
                                      Planext4uLocalizations.of(context).retry,
                                    ),
                                  ),
                                ] else if (!_showSplash)
                                  const CircularProgressIndicator(),
                                if (_showSplash) ...[
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : PublicStartupGate.displayBudget,
                                    builder: (context, value, child) =>
                                        LinearProgressIndicator(value: value),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    key: const ValueKey('skip-public-startup'),
                                    onPressed: _finish,
                                    child: Text(_skipLabel(_locale)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _skipLabel(String locale) =>
    const {
      'en': 'Skip',
      'ta': 'தவிர்',
      'hi': 'छोड़ें',
      'te': 'దాటవేయండి',
      'kn': 'ಬಿಟ್ಟುಬಿಡಿ',
      'ml': 'ഒഴിവാക്കുക',
      'mr': 'वगळा',
      'bn': 'এড়িয়ে যান',
      'gu': 'છોડો',
    }[locale] ??
    'Skip';

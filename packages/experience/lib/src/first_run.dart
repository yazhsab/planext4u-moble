import 'package:flutter/material.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

final class OnboardingStep {
  const OnboardingStep({required this.title, required this.message});
  final String title;
  final String message;
}

final class FirstRunConfig {
  FirstRunConfig({required this.version, required List<OnboardingStep> steps})
    : steps = List.unmodifiable(steps) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(version) ||
        steps.isEmpty ||
        steps.length > 8 ||
        steps.any(
          (step) =>
              step.title.isEmpty ||
              step.title.length > 120 ||
              step.message.isEmpty ||
              step.message.length > 1000,
        )) {
      throw const FormatException('Onboarding configuration is invalid.');
    }
  }
  final String version;
  final List<OnboardingStep> steps;
  factory FirstRunConfig.forRole(String role) => FirstRunConfig(
    version: const String.fromEnvironment(
      'ONBOARDING_VERSION',
      defaultValue: '1',
    ),
    steps: [
      OnboardingStep(
        title: 'Welcome to Planext4u $role',
        message:
            'Create an account or sign in to continue. Your account and approved role determine the services you can use.',
      ),
      const OnboardingStep(
        title: 'You control device permissions',
        message:
            'Location and notification access are requested when needed. You can decline and return to device settings later. Riders need delivery location consent before going on duty.',
      ),
      const OnboardingStep(
        title: 'Private evidence and account controls',
        message:
            'Identity documents and delivery evidence stay private. Review your sessions, consent preferences and account data from your profile.',
      ),
    ],
  );
}

abstract interface class FirstRunStore {
  Future<bool> completed(String version);
  Future<void> complete(String version);
}

final class EncryptedFirstRunStore implements FirstRunStore {
  EncryptedFirstRunStore(this._records);
  factory EncryptedFirstRunStore.platform(String role) {
    final namespace = 'planext4u.$role.onboarding.v1';
    return EncryptedFirstRunStore(
      EncryptedRecordStore(
        records: FileBinaryRecordStore(namespace: namespace),
        keyProvider: PlatformCacheKeyProvider(namespace: namespace),
        namespace: namespace,
        maxPlaintextBytes: 4096,
      ),
    );
  }
  final EncryptedRecordStore _records;
  @override
  Future<bool> completed(String version) async {
    final result = await _records.get('first.run', (value) => value);
    final value = result.value;
    return value is Map<String, Object?> &&
        value['version'] == version &&
        value['completed'] == true;
  }

  @override
  Future<void> complete(String version) {
    final expiry = DateTime.now().toUtc().add(const Duration(days: 3650));
    return _records.put(
      'first.run',
      {'version': version, 'completed': true},
      expiresAt: expiry,
      staleUntil: expiry,
    );
  }
}

final class FirstRunGate extends StatefulWidget {
  const FirstRunGate({
    required this.config,
    required this.store,
    required this.child,
    super.key,
  });
  final FirstRunConfig config;
  final FirstRunStore store;
  final Widget child;
  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  bool? _completed;
  bool _saving = false;
  String? _error;
  int _index = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final done = await widget.store.completed(widget.config.version);
      if (mounted) {
        setState(() {
          _completed = done;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'First-run preferences could not be loaded. Try again.',
        );
      }
    }
  }

  Future<void> _next() async {
    if (_saving) return;
    if (_index < widget.config.steps.length - 1) {
      setState(() => _index++);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.complete(widget.config.version);
      if (mounted) setState(() => _completed = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your onboarding progress could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed == true) return widget.child;
    if (_completed == null) {
      return Scaffold(
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
        ),
      );
    }
    final step = widget.config.steps[_index];
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          step.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        Text(step.message),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${_index + 1} / ${widget.config.steps.length}',
                            textAlign: TextAlign.center,
                          ),
                          if (_error != null)
                            Text(_error!, semanticsLabel: _error),
                          FilledButton(
                            onPressed: _saving ? null : _next,
                            child: Text(
                              _index == widget.config.steps.length - 1
                                  ? 'Get started'
                                  : 'Continue',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

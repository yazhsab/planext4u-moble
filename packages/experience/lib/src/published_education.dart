import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';

import 'first_run.dart';

abstract interface class PublishedEducationRemote {
  Future<Map<String, Object?>?> fetch(String role, String locale);
}

final class PublishedEducationApi implements PublishedEducationRemote {
  const PublishedEducationApi(this._client);
  final ApiClient _client;
  @override
  Future<Map<String, Object?>?> fetch(String role, String locale) async {
    try {
      return (await _client.send(
        ApiRequest.get(
          operation: 'configuration.get_mobile_education',
          path: '/v1/pages/mobile-onboarding-$role-$locale',
          query: {
            'locale': [locale],
          },
        ),
        (value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Invalid education page.');
          }
          return value;
        },
      )).value;
    } on ApiFailure catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }
}

final class PublishedEducationController extends ChangeNotifier {
  PublishedEducationController({
    required PublishedEducationRemote remote,
    required this.role,
    required this.scope,
    required bool Function() scopeIsCurrent,
    FirstRunStore? store,
  }) : _remote = remote,
       _scopeIsCurrent = scopeIsCurrent,
       store = store ?? EncryptedFirstRunStore.platform('$role.published');
  final PublishedEducationRemote _remote;
  final bool Function() _scopeIsCurrent;
  final String role;
  final String scope;
  final FirstRunStore store;
  bool loading = true;
  bool failed = false;
  FirstRunConfig? config;
  String? _locale;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load(String locale, {bool retry = false}) async {
    if (_disposed || !_scopeIsCurrent() || _locale == locale && !retry) return;
    _locale = locale;
    final generation = ++_generation;
    loading = true;
    failed = false;
    config = null;
    notifyListeners();
    try {
      final selected = isPlanext4uLocaleCode(locale) ? locale : 'en';
      var page = await _remote.fetch(role, selected);
      if (!_current(generation)) return;
      var language = selected;
      if (page == null && selected != 'en') {
        page = await _remote.fetch(role, 'en');
        language = 'en';
      }
      if (!_current(generation)) return;
      if (page != null) config = _parse(page, language);
    } catch (_) {
      if (!_current(generation)) return;
      failed = true;
    } finally {
      if (_current(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _current(int generation) =>
      !_disposed && generation == _generation && _scopeIsCurrent();

  FirstRunConfig _parse(Map<String, Object?> document, String locale) {
    final page = document['page'];
    final expected = 'mobile-onboarding-$role-$locale';
    if (document['revision'] is! int ||
        (document['revision']! as int) < 1 ||
        page is! Map<String, Object?> ||
        page['id'] != expected ||
        page['enabled'] != true ||
        page['audience'] is! List ||
        !(page['audience']! as List).contains(role.toUpperCase()) ||
        page['blocks'] is! List) {
      throw const FormatException('Education audience or page is invalid.');
    }
    final blocks = page['blocks']! as List;
    if (blocks.isEmpty || blocks.length > 8) {
      throw const FormatException('Education length is invalid.');
    }
    final steps = <OnboardingStep>[];
    String? version;
    for (final block in blocks) {
      if (block is! Map<String, Object?> ||
          block['kind'] != 'ONBOARDING' ||
          block['enabled'] != true ||
          block['content'] is! Map<String, Object?>) {
        throw const FormatException('Education block is invalid.');
      }
      final content = block['content']! as Map<String, Object?>;
      if (content['version'] is! String ||
          !RegExp(
            r'^[A-Za-z0-9._-]{1,32}$',
          ).hasMatch(content['version']! as String) ||
          version != null && version != content['version'] ||
          content['title'] is! String ||
          content['message'] is! String) {
        throw const FormatException('Education content is invalid.');
      }
      version = content['version']! as String;
      steps.add(
        OnboardingStep(
          title: content['title']! as String,
          message: content['message']! as String,
        ),
      );
    }
    // Content changes, account, tenant, country and language all invalidate the
    // completion marker, even when an editor forgets to advance the edition.
    final digest = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              scope,
              expected,
              version,
              for (final step in steps) [step.title, step.message],
            ]),
          ),
        )
        .toString()
        .substring(0, 24);
    return FirstRunConfig(version: '$version-$digest', steps: steps);
  }

  void useStandardEducation() {
    if (_disposed || !_scopeIsCurrent()) return;
    config = FirstRunConfig.forRole(role);
    failed = false;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    config = null;
    super.dispose();
  }
}

/// Uses the existing authenticated CMS publication flow. The signed-out native
/// splash/introduction stays available before any provider has been configured.
final class PublishedEducationGate extends StatefulWidget {
  const PublishedEducationGate({
    required this.controller,
    required this.child,
    super.key,
  });
  final PublishedEducationController? controller;
  final Widget child;
  @override
  State<PublishedEducationGate> createState() => _PublishedEducationGateState();
}

class _PublishedEducationGateState extends State<PublishedEducationGate> {
  String _locale = 'en';
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locale = Localizations.localeOf(context).languageCode;
    // Defer notification until the ancestor builder has finished.
    unawaited(Future<void>.microtask(() => widget.controller?.load(_locale)));
  }

  @override
  void didUpdateWidget(PublishedEducationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_changed);
      widget.controller?.addListener(_changed);
      unawaited(Future<void>.microtask(() => widget.controller?.load(_locale)));
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) return widget.child;
    if (controller.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (controller.failed) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Your introduction could not be loaded.'),
                    TextButton(
                      onPressed: () => controller.load(_locale, retry: true),
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      onPressed: controller.useStandardEducation,
                      child: const Text('Use standard introduction'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final config = controller.config;
    if (config == null) return widget.child;
    return FirstRunGate(
      key: ValueKey(config.version),
      config: config,
      store: controller.store,
      child: widget.child,
    );
  }
}

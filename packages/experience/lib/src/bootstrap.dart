import 'package:flutter/material.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'localization.dart';

enum MobilePlatform {
  android('ANDROID'),
  ios('IOS');

  const MobilePlatform(this.wireValue);
  final String wireValue;
}

enum UpdateGate { none, optional, required }

final class ConsentPolicy {
  const ConsentPolicy({
    required this.purpose,
    required this.policyVersion,
    required this.required,
  });

  factory ConsentPolicy.fromJson(Object? value) {
    final json = _object(value, 'consent policy');
    return ConsentPolicy(
      purpose: _string(json, 'purpose'),
      policyVersion: _string(json, 'policy_version'),
      required: _boolean(json, 'required'),
    );
  }

  final String purpose;
  final String policyVersion;
  final bool required;
}

final class HomeSectionConfig {
  const HomeSectionConfig({
    required this.id,
    required this.kind,
    required this.titleKey,
    required this.enabled,
    required this.priority,
  });

  factory HomeSectionConfig.fromJson(Object? value) {
    final json = _object(value, 'home section');
    return HomeSectionConfig(
      id: _string(json, 'id'),
      kind: _string(json, 'kind'),
      titleKey: _string(json, 'title_key'),
      enabled: _boolean(json, 'enabled'),
      priority: _integer(json, 'priority'),
    );
  }

  final String id;
  final String kind;
  final String titleKey;
  final bool enabled;
  final int priority;
}

final class BootstrapConfig {
  const BootstrapConfig({
    required this.revision,
    required this.publishedAt,
    required this.updateGate,
    required this.latestVersion,
    required this.maintenance,
    required this.locale,
    required this.supportedLocales,
    required this.consentPolicies,
    required this.flags,
    required this.homeSections,
    this.maintenanceUntil,
    this.maintenanceText = '',
  });

  factory BootstrapConfig.safeOffline() => BootstrapConfig(
    revision: 0,
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updateGate: UpdateGate.none,
    latestVersion: '0.0.0',
    maintenance: false,
    locale: 'en',
    supportedLocales: const ['en', 'ta'],
    consentPolicies: const [],
    flags: const {},
    homeSections: const [],
  );

  factory BootstrapConfig.fromJson(Object? value) {
    final json = _object(value, 'bootstrap');
    final supported = _list(
      json,
      'supported_locales',
    ).map((item) => item as String).toList(growable: false);
    final locale = _string(json, 'locale');
    if (!supported.contains(locale) ||
        supported.any(
          (value) => !{
            'en',
            'ta',
            'hi',
            'te',
            'kn',
            'ml',
            'mr',
            'bn',
            'gu',
          }.contains(value),
        )) {
      throw const FormatException('Bootstrap locale contract is invalid.');
    }
    final rawFlags = _object(json['flags'], 'flags');
    final flags = <String, bool>{};
    for (final entry in rawFlags.entries) {
      if (entry.value is! bool) {
        throw const FormatException('Feature flag must be boolean.');
      }
      flags[entry.key] = entry.value! as bool;
    }
    final result = BootstrapConfig(
      revision: _integer(json, 'revision'),
      publishedAt: _instant(json, 'published_at'),
      updateGate: switch (_string(json, 'update_gate')) {
        'NONE' => UpdateGate.none,
        'OPTIONAL' => UpdateGate.optional,
        'REQUIRED' => UpdateGate.required,
        _ => throw const FormatException('Unknown update gate.'),
      },
      latestVersion: _string(json, 'latest_version'),
      maintenance: _boolean(json, 'maintenance'),
      maintenanceUntil: json['maintenance_until'] == null
          ? null
          : _instant(json, 'maintenance_until'),
      maintenanceText: json['maintenance_text'] is String
          ? json['maintenance_text']! as String
          : '',
      locale: locale,
      supportedLocales: List.unmodifiable(supported),
      consentPolicies: List.unmodifiable(
        _list(json, 'consent_policies').map(ConsentPolicy.fromJson),
      ),
      flags: Map.unmodifiable(flags),
      homeSections: List.unmodifiable(
        _list(json, 'home_sections').map(HomeSectionConfig.fromJson),
      ),
    );
    if (result.revision < 1) {
      throw const FormatException('Bootstrap revision is invalid.');
    }
    return result;
  }

  final int revision;
  final DateTime publishedAt;
  final UpdateGate updateGate;
  final String latestVersion;
  final bool maintenance;
  final DateTime? maintenanceUntil;
  final String maintenanceText;
  final String locale;
  final List<String> supportedLocales;
  final List<ConsentPolicy> consentPolicies;
  final Map<String, bool> flags;
  final List<HomeSectionConfig> homeSections;

  bool flag(String name) => flags[name] ?? false;
}

abstract interface class BootstrapRemote {
  Future<BootstrapConfig> fetch({
    required MobilePlatform platform,
    required String appVersion,
    required String locale,
  });
}

final class BootstrapApi implements BootstrapRemote {
  const BootstrapApi(this._client);
  final ApiClient _client;

  @override
  Future<BootstrapConfig> fetch({
    required MobilePlatform platform,
    required String appVersion,
    required String locale,
  }) async {
    final response = await _client.send(
      ApiRequest.get(
        operation: 'configuration.get_bootstrap',
        path: '/v1/bootstrap',
        query: {
          'platform': [platform.wireValue],
          'app_version': [appVersion],
          'locale': [locale],
        },
      ),
      BootstrapConfig.fromJson,
    );
    return response.value;
  }
}

abstract interface class BootstrapCache {
  Future<BootstrapConfig?> read();
  Future<void> write(BootstrapConfig value);
}

final class MemoryBootstrapCache implements BootstrapCache {
  BootstrapConfig? value;
  @override
  Future<BootstrapConfig?> read() async => value;
  @override
  Future<void> write(BootstrapConfig value) async => this.value = value;
}

enum BootstrapStatus { loading, ready, offline, failure }

final class BootstrapState {
  const BootstrapState({required this.status, required this.config});
  final BootstrapStatus status;
  final BootstrapConfig config;
  bool get isBlocking =>
      config.maintenance || config.updateGate == UpdateGate.required;
}

final class BootstrapController extends ChangeNotifier {
  BootstrapController({
    required BootstrapRemote remote,
    required BootstrapCache cache,
    required MobilePlatform platform,
    required String appVersion,
    required String locale,
  }) : _remote = remote,
       _cache = cache,
       _platform = platform,
       _appVersion = appVersion,
       _locale = locale,
       _state = BootstrapState(
         status: BootstrapStatus.loading,
         config: BootstrapConfig.safeOffline(),
       );

  final BootstrapRemote _remote;
  final BootstrapCache _cache;
  final MobilePlatform _platform;
  final String _appVersion;
  final String _locale;
  BootstrapState _state;

  BootstrapState get state => _state;

  Future<void> load() async {
    _set(
      BootstrapState(status: BootstrapStatus.loading, config: _state.config),
    );
    try {
      final config = await _remote.fetch(
        platform: _platform,
        appVersion: _appVersion,
        locale: _locale,
      );
      await _cache.write(config);
      _set(BootstrapState(status: BootstrapStatus.ready, config: config));
    } catch (_) {
      final cached = await _cache.read();
      _set(
        BootstrapState(
          status: cached == null
              ? BootstrapStatus.failure
              : BootstrapStatus.offline,
          config: cached ?? BootstrapConfig.safeOffline(),
        ),
      );
    }
  }

  void _set(BootstrapState value) {
    _state = value;
    notifyListeners();
  }
}

final class BootstrapGateView extends StatelessWidget {
  const BootstrapGateView({
    required this.state,
    required this.onRetry,
    required this.child,
    super.key,
  });

  final BootstrapState state;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final strings = Planext4uLocalizations.of(context);
    if (state.status == BootstrapStatus.loading) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Loading Planext4u',
        message: 'Preparing your experience.',
      );
    }
    if (state.config.updateGate == UpdateGate.required) {
      return Planext4uStatePanel(
        state: Planext4uViewState.error,
        title: strings.updateRequired,
        message: strings.updateRequiredMessage,
      );
    }
    if (state.config.maintenance) {
      return Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: strings.maintenanceTitle,
        message: state.config.maintenanceText.isEmpty
            ? strings.maintenanceMessage
            : state.config.maintenanceText,
      );
    }
    if (state.status == BootstrapStatus.failure) {
      return Planext4uStatePanel(
        state: Planext4uViewState.offline,
        title: 'You’re offline',
        message: 'Connect to the internet to finish setting up Planext4u.',
        actionLabel: strings.retry,
        onAction: onRetry,
      );
    }
    return child;
  }
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key must be a list.');
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

DateTime _instant(Map<String, Object?> json, String key) {
  final result = DateTime.tryParse(_string(json, key));
  if (result == null || !result.isUtc) {
    throw FormatException('$key must be a UTC date-time.');
  }
  return result;
}

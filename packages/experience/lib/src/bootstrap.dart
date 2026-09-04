import 'package:flutter/material.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
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
    this.displayTitle = '',
    this.displaySubtitle = '',
    this.actionLabel = '',
    this.actionRoute = '',
    this.collectionId = '',
    this.maximumItems = 8,
    this.items = const [],
  });

  factory HomeSectionConfig.fromJson(Object? value) {
    final json = _object(value, 'home section');
    final id = _string(json, 'id');
    final kind = _string(json, 'kind');
    final titleKey = _string(json, 'title_key');
    if (id.length > 80 || kind.length > 48 || titleKey.length > 96) {
      throw const FormatException('Home section identifier is invalid.');
    }
    final actionRoute = _optionalText(json, 'action_route', maxLength: 96);
    if (actionRoute.isNotEmpty &&
        !supportedCustomerHomeRoutes.contains(actionRoute)) {
      throw const FormatException('Home section action route is invalid.');
    }
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List<Object?>) {
      throw const FormatException('Home section items must be a list.');
    }
    final items = rawItems as List<Object?>? ?? const [];
    if (items.length > 8) {
      throw const FormatException('Home section has too many items.');
    }
    final maximumItems = json['maximum_items'] as int? ?? 8;
    if (maximumItems < 1 || maximumItems > 24) {
      throw const FormatException('Home section item limit is invalid.');
    }
    return HomeSectionConfig(
      id: id,
      kind: kind,
      titleKey: titleKey,
      enabled: _boolean(json, 'enabled'),
      priority: _integer(json, 'priority'),
      displayTitle: _optionalText(json, 'display_title', maxLength: 120),
      displaySubtitle: _optionalText(json, 'display_subtitle', maxLength: 240),
      actionLabel: _optionalText(json, 'action_label', maxLength: 40),
      actionRoute: actionRoute,
      collectionId: _optionalText(json, 'collection_id', maxLength: 128),
      maximumItems: maximumItems,
      items: List.unmodifiable(items.map(HomeSectionItemConfig.fromJson)),
    );
  }

  final String id;
  final String kind;
  final String titleKey;
  final bool enabled;
  final int priority;
  final String displayTitle;
  final String displaySubtitle;
  final String actionLabel;
  final String actionRoute;
  final String collectionId;
  final int maximumItems;
  final List<HomeSectionItemConfig> items;
}

final class HomeSectionItemConfig {
  const HomeSectionItemConfig({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.icon = 'default',
    this.actionRoute = '',
  });

  factory HomeSectionItemConfig.fromJson(Object? value) {
    final json = _object(value, 'home section item');
    final id = _string(json, 'id');
    final title = _string(json, 'title');
    if (id.length > 80 || title.length > 120) {
      throw const FormatException('Home section item text is invalid.');
    }
    final actionRoute = _optionalText(json, 'action_route', maxLength: 96);
    if (actionRoute.isNotEmpty &&
        !supportedCustomerHomeRoutes.contains(actionRoute)) {
      throw const FormatException('Home section item action route is invalid.');
    }
    return HomeSectionItemConfig(
      id: id,
      title: title,
      subtitle: _optionalText(json, 'subtitle', maxLength: 160),
      icon: _optionalText(json, 'icon', maxLength: 32, fallback: 'default'),
      actionRoute: actionRoute,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String actionRoute;
}

const supportedCustomerHomeRoutes = <String>{
  '/app/catalog',
  '/app/orders',
  '/app/services',
  '/app/food',
  '/app/social',
  '/app/community',
  '/app/homes',
  '/app/classifieds',
  '/app/emergency',
};

const supportedCustomerHomeSectionKinds = <String>{
  'HERO',
  'TRUST_BENEFITS',
  'CATEGORY_GRID',
  'FEATURED_ITEMS',
  'BESTSELLERS',
  'RECOMMENDATIONS',
  'SERVICE_DISCOVERY',
  'SERVICE_RAIL',
  'LEADERBOARD',
  'HELP_SHORTCUTS',
};

/// Returns the presentation-safe subset of the server-owned home composition.
///
/// The lowest-priority entry wins when a bootstrap response accidentally
/// publishes the same section kind more than once. Unknown kinds are ignored so
/// a newer backend configuration cannot break an older mobile binary.
List<HomeSectionConfig> normalizeCustomerHomeSections(
  Iterable<HomeSectionConfig> sections,
) {
  final ordered =
      sections
          .where(
            (section) =>
                section.enabled &&
                supportedCustomerHomeSectionKinds.contains(section.kind),
          )
          .toList(growable: false)
        ..sort((left, right) {
          final priority = left.priority.compareTo(right.priority);
          return priority == 0 ? left.id.compareTo(right.id) : priority;
        });
  final seenKinds = <String>{};
  return List.unmodifiable([
    for (final section in ordered)
      if (seenKinds.add(_canonicalCustomerHomeSectionKind(section.kind)))
        section,
  ]);
}

String _canonicalCustomerHomeSectionKind(String kind) => switch (kind) {
  'BESTSELLERS' => 'FEATURED_ITEMS',
  'SERVICE_DISCOVERY' => 'SERVICE_RAIL',
  _ => kind,
};

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
    locale: planext4uDefaultLocaleCode,
    supportedLocales: planext4uSupportedLocaleCodes,
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
        supported.toSet().length != supported.length ||
        supported.any((value) => !isPlanext4uLocaleCode(value))) {
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
      homeSections: _homeSections(json),
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

  Map<String, Object?> toJson() => {
    'revision': revision,
    'published_at': publishedAt.toIso8601String(),
    'update_gate': switch (updateGate) {
      UpdateGate.none => 'NONE',
      UpdateGate.optional => 'OPTIONAL',
      UpdateGate.required => 'REQUIRED',
    },
    'latest_version': latestVersion,
    'maintenance': maintenance,
    if (maintenanceUntil != null)
      'maintenance_until': maintenanceUntil!.toIso8601String(),
    if (maintenanceText.isNotEmpty) 'maintenance_text': maintenanceText,
    'locale': locale,
    'supported_locales': supportedLocales,
    'consent_policies': [
      for (final value in consentPolicies)
        {
          'purpose': value.purpose,
          'policy_version': value.policyVersion,
          'required': value.required,
        },
    ],
    'flags': flags,
    'home_sections': [
      for (final value in homeSections)
        {
          'id': value.id,
          'kind': value.kind,
          'title_key': value.titleKey,
          'enabled': value.enabled,
          'priority': value.priority,
          if (value.displayTitle.isNotEmpty)
            'display_title': value.displayTitle,
          if (value.displaySubtitle.isNotEmpty)
            'display_subtitle': value.displaySubtitle,
          if (value.actionLabel.isNotEmpty) 'action_label': value.actionLabel,
          if (value.actionRoute.isNotEmpty) 'action_route': value.actionRoute,
          if (value.collectionId.isNotEmpty)
            'collection_id': value.collectionId,
          'maximum_items': value.maximumItems,
          if (value.items.isNotEmpty)
            'items': [
              for (final item in value.items)
                {
                  'id': item.id,
                  'title': item.title,
                  if (item.subtitle.isNotEmpty) 'subtitle': item.subtitle,
                  if (item.icon.isNotEmpty) 'icon': item.icon,
                  if (item.actionRoute.isNotEmpty)
                    'action_route': item.actionRoute,
                },
            ],
        },
    ],
  };
}

List<HomeSectionConfig> _homeSections(Map<String, Object?> json) {
  final sections = _list(
    json,
    'home_sections',
  ).map(HomeSectionConfig.fromJson).toList(growable: true);
  final rawPages = json['pages'];
  if (rawPages == null) return List.unmodifiable(sections);
  if (rawPages is! List<Object?>) {
    throw const FormatException('Bootstrap pages must be a list.');
  }
  for (final rawPage in rawPages) {
    final page = _object(rawPage, 'bootstrap page');
    if (page['id'] != 'customer-home' || page['enabled'] != true) continue;
    final rawBlocks = page['blocks'];
    if (rawBlocks is! List<Object?>) {
      throw const FormatException('Customer home blocks must be a list.');
    }
    for (final rawBlock in rawBlocks) {
      final block = _object(rawBlock, 'customer home block');
      if (block['kind'] != 'SERVICE_RAIL') continue;
      final content = _object(block['content'], 'service rail content');
      final collectionId = _string(content, 'collection_id');
      final maximumItems = content['maximum_items'] as int? ?? 8;
      if (collectionId.length > 128 || maximumItems < 1 || maximumItems > 24) {
        throw const FormatException('CMS service rail is invalid.');
      }
      final id = _string(block, 'id');
      if (sections.any(
        (section) =>
            section.kind == 'SERVICE_RAIL' &&
            section.collectionId == collectionId,
      )) {
        continue;
      }
      sections.add(
        HomeSectionConfig(
          id: id,
          kind: 'SERVICE_RAIL',
          titleKey: block['title_key'] is String
              ? block['title_key']! as String
              : 'home.services',
          displayTitle: content['title'] is String
              ? content['title']! as String
              : '',
          actionLabel: 'View all',
          actionRoute: '/app/services',
          collectionId: collectionId,
          maximumItems: maximumItems,
          enabled: block['enabled'] == true,
          priority: _integer(block, 'priority'),
        ),
      );
    }
  }
  return List.unmodifiable(sections);
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

String _optionalText(
  Map<String, Object?> json,
  String key, {
  required int maxLength,
  String fallback = '',
}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is! String) throw FormatException('$key must be a string.');
  final normalized = value.trim();
  if (normalized.length > maxLength) {
    throw FormatException('$key is too long.');
  }
  return normalized.isEmpty ? fallback : normalized;
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

import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

enum NotificationPreferencePurpose {
  security('SECURITY', 'Security'),
  transactional('TRANSACTIONAL', 'Orders and account activity'),
  marketing('MARKETING', 'Offers and recommendations');

  const NotificationPreferencePurpose(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

enum NotificationPreferenceChannel {
  push('PUSH', 'Push notifications'),
  inApp('IN_APP', 'In-app notifications'),
  email('EMAIL', 'Email'),
  whatsApp('WHATSAPP', 'WhatsApp');

  const NotificationPreferenceChannel(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

final class NotificationPreferenceKey {
  const NotificationPreferenceKey({
    required this.purpose,
    required this.channel,
  });

  final NotificationPreferencePurpose purpose;
  final NotificationPreferenceChannel channel;

  String get value => '${purpose.wireValue}:${channel.wireValue}';

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferenceKey &&
      other.purpose == purpose &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(purpose, channel);
}

final class NotificationPreference {
  const NotificationPreference({
    required this.subjectId,
    required this.purpose,
    required this.channel,
    required this.enabled,
    required this.version,
    required this.updatedAt,
  });

  factory NotificationPreference.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Notification preference must be an object.');
    }
    final purpose = NotificationPreferencePurpose.values.where(
      (item) => item.wireValue == value['purpose'],
    );
    final channel = NotificationPreferenceChannel.values.where(
      (item) => item.wireValue == value['channel'],
    );
    final subjectId = value['subject_id'];
    final enabled = value['enabled'];
    final version = value['version'];
    final updatedAt = DateTime.tryParse(value['updated_at'] as String? ?? '');
    if (purpose.length != 1 ||
        channel.length != 1 ||
        subjectId is! String ||
        subjectId.isEmpty ||
        enabled is! bool ||
        version is! int ||
        version < 1 ||
        updatedAt == null ||
        !updatedAt.isUtc) {
      throw const FormatException(
        'Notification preference contract is invalid.',
      );
    }
    return NotificationPreference(
      subjectId: subjectId,
      purpose: purpose.single,
      channel: channel.single,
      enabled: enabled,
      version: version,
      updatedAt: updatedAt,
    );
  }

  final String subjectId;
  final NotificationPreferencePurpose purpose;
  final NotificationPreferenceChannel channel;
  final bool enabled;
  final int version;
  final DateTime updatedAt;

  NotificationPreferenceKey get key =>
      NotificationPreferenceKey(purpose: purpose, channel: channel);
}

abstract interface class NotificationPreferencesRemote {
  Future<NotificationPreference> preference(NotificationPreferenceKey key);

  Future<NotificationPreference> update({
    required NotificationPreference current,
    required bool enabled,
  });
}

final class NotificationPreferencesApi
    implements NotificationPreferencesRemote {
  const NotificationPreferencesApi(this._client);

  final ApiClient _client;

  @override
  Future<NotificationPreference> preference(
    NotificationPreferenceKey key,
  ) async => (await _client.send(
    ApiRequest.get(
      operation: 'notification.get_preference',
      path:
          '/v1/notification/preferences/${key.purpose.wireValue}/${key.channel.wireValue}',
    ),
    NotificationPreference.fromJson,
  )).value;

  @override
  Future<NotificationPreference> update({
    required NotificationPreference current,
    required bool enabled,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'notification.put_preference',
      method: 'PUT',
      path:
          '/v1/notification/preferences/${current.purpose.wireValue}/${current.channel.wireValue}',
      body: {'enabled': enabled, 'expected_version': current.version},
    ),
    NotificationPreference.fromJson,
  )).value;
}

enum NotificationPreferencesStatus {
  idle,
  loading,
  ready,
  saving,
  offline,
  failure,
}

final class NotificationPreferencesState {
  const NotificationPreferencesState({
    this.status = NotificationPreferencesStatus.idle,
    this.preferences = const {},
    this.savingKey,
    this.message,
  });

  final NotificationPreferencesStatus status;
  final Map<NotificationPreferenceKey, NotificationPreference> preferences;
  final NotificationPreferenceKey? savingKey;
  final String? message;

  bool get busy =>
      status == NotificationPreferencesStatus.loading ||
      status == NotificationPreferencesStatus.saving;
}

final class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController(this._remote);

  final NotificationPreferencesRemote _remote;
  NotificationPreferencesState _state = const NotificationPreferencesState();

  NotificationPreferencesState get state => _state;

  static final List<NotificationPreferenceKey> configurableKeys =
      List.unmodifiable([
        for (final purpose in const [
          NotificationPreferencePurpose.transactional,
          NotificationPreferencePurpose.marketing,
        ])
          for (final channel in NotificationPreferenceChannel.values)
            NotificationPreferenceKey(purpose: purpose, channel: channel),
      ]);

  Future<void> load() async {
    if (_state.busy) return;
    _set(
      NotificationPreferencesState(
        status: NotificationPreferencesStatus.loading,
        preferences: _state.preferences,
      ),
    );
    try {
      final values = await Future.wait(
        configurableKeys.map(_remote.preference),
      );
      if (values.map((value) => value.subjectId).toSet().length != 1 ||
          values.any((value) => !configurableKeys.contains(value.key))) {
        throw const FormatException(
          'Notification preferences belong to an invalid account scope.',
        );
      }
      _set(
        NotificationPreferencesState(
          status: NotificationPreferencesStatus.ready,
          preferences: Map.unmodifiable({
            for (final value in values) value.key: value,
          }),
        ),
      );
    } on ApiTransportFailure {
      _unavailable(
        NotificationPreferencesStatus.offline,
        'Reconnect to review notification preferences.',
      );
    } on ApiTimeoutFailure {
      _unavailable(
        NotificationPreferencesStatus.offline,
        'The preference service timed out. Check your connection.',
      );
    } catch (_) {
      _unavailable(
        NotificationPreferencesStatus.failure,
        'Notification preferences could not be loaded safely.',
      );
    }
  }

  Future<void> setEnabled(NotificationPreferenceKey key, bool enabled) async {
    if (key.purpose == NotificationPreferencePurpose.security ||
        !configurableKeys.contains(key)) {
      throw const FormatException(
        'Mandatory security notifications cannot be changed.',
      );
    }
    final current = _state.preferences[key];
    if (current == null || _state.busy || current.enabled == enabled) return;
    _set(
      NotificationPreferencesState(
        status: NotificationPreferencesStatus.saving,
        preferences: _state.preferences,
        savingKey: key,
      ),
    );
    try {
      final updated = await _remote.update(current: current, enabled: enabled);
      if (updated.key != key ||
          updated.subjectId != current.subjectId ||
          updated.version <= current.version ||
          updated.enabled != enabled) {
        throw const FormatException(
          'Updated notification preference contract is invalid.',
        );
      }
      _set(
        NotificationPreferencesState(
          status: NotificationPreferencesStatus.ready,
          preferences: Map.unmodifiable({..._state.preferences, key: updated}),
          message: '${key.channel.label} preference saved.',
        ),
      );
    } on ApiConflictFailure {
      _set(
        NotificationPreferencesState(
          status: NotificationPreferencesStatus.ready,
          preferences: _state.preferences,
          message:
              'Preferences changed on another device. Refresh before trying again.',
        ),
      );
    } on ApiTransportFailure {
      _unavailable(
        NotificationPreferencesStatus.offline,
        'Reconnect before changing notification preferences.',
      );
    } on ApiTimeoutFailure {
      _unavailable(
        NotificationPreferencesStatus.offline,
        'The preference update timed out. Refresh before trying again.',
      );
    } catch (_) {
      _unavailable(
        NotificationPreferencesStatus.failure,
        'The preference was not changed. Refresh before trying again.',
      );
    }
  }

  void clearMessage() {
    if (_state.message == null) return;
    _set(
      NotificationPreferencesState(
        status: _state.status,
        preferences: _state.preferences,
        savingKey: _state.savingKey,
      ),
    );
  }

  void _unavailable(NotificationPreferencesStatus status, String message) {
    _set(
      NotificationPreferencesState(
        status: status,
        preferences: _state.preferences,
        message: message,
      ),
    );
  }

  void _set(NotificationPreferencesState value) {
    _state = value;
    notifyListeners();
  }
}

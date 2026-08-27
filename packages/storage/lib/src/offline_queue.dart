import 'dart:convert';

import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'encrypted_store.dart';

final class OfflineCommand {
  OfflineCommand({
    required this.id,
    required this.operation,
    required this.idempotencyKey,
    required this.payload,
    required this.createdAt,
    required this.expiresAt,
  }) {
    if (!_safeIdentifier.hasMatch(id) ||
        !_safeOperation.hasMatch(operation) ||
        !IdempotencyKey.isValid(idempotencyKey) ||
        !createdAt.isUtc ||
        !expiresAt.isUtc ||
        !expiresAt.isAfter(createdAt) ||
        _containsSensitiveKey(payload)) {
      throw const FormatException('Offline command is invalid.');
    }
  }

  factory OfflineCommand.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        value['payload'] is! Map<String, Object?>) {
      throw const FormatException('Offline command contract is invalid.');
    }
    return OfflineCommand(
      id: value['id']! as String,
      operation: value['operation']! as String,
      idempotencyKey: value['idempotency_key']! as String,
      payload: Map.unmodifiable(value['payload']! as Map<String, Object?>),
      createdAt: DateTime.parse(value['created_at']! as String),
      expiresAt: DateTime.parse(value['expires_at']! as String),
    );
  }

  final String id;
  final String operation;
  final String idempotencyKey;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'operation': operation,
    'idempotency_key': idempotencyKey,
    'payload': payload,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
  };
}

enum CommandDispatchResult { success, retryableFailure, permanentFailure }

abstract interface class OfflineCommandDispatcher {
  Future<CommandDispatchResult> dispatch(OfflineCommand command);
}

enum QueueDiagnosticOutcome { enqueued, delivered, retryDeferred, discarded }

abstract interface class QueueDiagnostics {
  void event({
    required String commandId,
    required String operation,
    required QueueDiagnosticOutcome outcome,
  });
}

final class NoopQueueDiagnostics implements QueueDiagnostics {
  const NoopQueueDiagnostics();
  @override
  void event({
    required String commandId,
    required String operation,
    required QueueDiagnosticOutcome outcome,
  }) {}
}

final class OfflineCommandQueue {
  OfflineCommandQueue({
    required EncryptedRecordStore store,
    required Set<String> allowedOperations,
    StorageClock clock = _utcNow,
    QueueDiagnostics diagnostics = const NoopQueueDiagnostics(),
    this.maxCommands = 100,
    this.maxEncodedBytes = 512 * 1024,
  }) : _store = store,
       _allowedOperations = Set.unmodifiable(allowedOperations),
       _clock = clock,
       _diagnostics = diagnostics {
    if (allowedOperations.isEmpty ||
        allowedOperations.any((value) => !_safeOperation.hasMatch(value)) ||
        maxCommands < 1 ||
        maxCommands > 1000 ||
        maxEncodedBytes < 1024 ||
        maxEncodedBytes > 8 << 20) {
      throw const FormatException('Offline queue configuration is invalid.');
    }
  }

  static const _recordKey = 'offline.command_queue';
  final EncryptedRecordStore _store;
  final Set<String> _allowedOperations;
  final StorageClock _clock;
  final QueueDiagnostics _diagnostics;
  final int maxCommands;
  final int maxEncodedBytes;
  Future<void> _serial = Future.value();

  Future<void> enqueue(OfflineCommand command) => _synchronized(() async {
    if (!_allowedOperations.contains(command.operation)) {
      throw const FormatException('Offline operation is not allowed.');
    }
    final commands = await _read();
    if (commands.any(
      (value) =>
          value.id == command.id ||
          value.idempotencyKey == command.idempotencyKey,
    )) {
      return;
    }
    if (commands.length >= maxCommands) {
      throw StateError('Offline queue capacity reached.');
    }
    final next = [...commands, command];
    if (utf8
            .encode(jsonEncode(next.map((item) => item.toJson()).toList()))
            .length >
        maxEncodedBytes) {
      throw StateError('Offline queue byte capacity reached.');
    }
    await _write(next);
    _diagnose(command, QueueDiagnosticOutcome.enqueued);
  });

  Future<int> drain(OfflineCommandDispatcher dispatcher) =>
      _synchronized(() async {
        final now = _clock().toUtc();
        final commands = await _read();
        final remaining = <OfflineCommand>[];
        var delivered = 0;
        for (final command in commands) {
          if (!command.expiresAt.isAfter(now)) {
            _diagnose(command, QueueDiagnosticOutcome.discarded);
            continue;
          }
          final result = await dispatcher.dispatch(command);
          switch (result) {
            case CommandDispatchResult.success:
              delivered++;
              _diagnose(command, QueueDiagnosticOutcome.delivered);
            case CommandDispatchResult.retryableFailure:
              remaining.add(command);
              _diagnose(command, QueueDiagnosticOutcome.retryDeferred);
            case CommandDispatchResult.permanentFailure:
              _diagnose(command, QueueDiagnosticOutcome.discarded);
          }
          if (result == CommandDispatchResult.retryableFailure) {
            remaining.addAll(commands.skip(commands.indexOf(command) + 1));
            break;
          }
        }
        await _write(remaining);
        return delivered;
      });

  Future<List<OfflineCommand>> pending() =>
      _synchronized(() async => List.unmodifiable(await _read()));

  Future<void> purge() => _synchronized(() => _store.delete(_recordKey));

  Future<List<OfflineCommand>> _read() async {
    final result = await _store.get<List<OfflineCommand>>(_recordKey, (value) {
      if (value is! List<Object?>) {
        throw const FormatException('Queue record is invalid.');
      }
      return value.map(OfflineCommand.fromJson).toList(growable: false);
    });
    return result.value ?? <OfflineCommand>[];
  }

  Future<void> _write(List<OfflineCommand> commands) {
    if (commands.isEmpty) return _store.delete(_recordKey);
    final now = _clock().toUtc();
    return _store.put(
      _recordKey,
      commands.map((item) => item.toJson()).toList(growable: false),
      expiresAt: now.add(const Duration(days: 31)),
      staleUntil: now.add(const Duration(days: 31)),
    );
  }

  Future<T> _synchronized<T>(Future<T> Function() operation) {
    final completer = _serial.then((_) => operation());
    _serial = completer.then<void>((_) {}, onError: (_) {});
    return completer;
  }

  void _diagnose(OfflineCommand command, QueueDiagnosticOutcome outcome) {
    try {
      _diagnostics.event(
        commandId: command.id,
        operation: command.operation,
        outcome: outcome,
      );
    } catch (_) {
      // Diagnostics cannot affect durable queue semantics.
    }
  }
}

bool _containsSensitiveKey(Object? value) {
  if (value is Map<String, Object?>) {
    for (final entry in value.entries) {
      final key = entry.key.toLowerCase();
      if (_sensitiveFragments.any(key.contains) ||
          _containsSensitiveKey(entry.value)) {
        return true;
      }
    }
  } else if (value is List<Object?>) {
    return value.any(_containsSensitiveKey);
  }
  return false;
}

const _sensitiveFragments = [
  'authorization',
  'cookie',
  'email',
  'password',
  'phone',
  'secret',
  'token',
];
final _safeIdentifier = RegExp(r'^[A-Za-z0-9._:-]{8,128}$');
final _safeOperation = RegExp(r'^[a-z][a-z0-9_.-]{2,79}$');
DateTime _utcNow() => DateTime.now().toUtc();

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 10);

  test('queue deduplicates idempotency keys and drains in order', () async {
    final diagnostics = RecordingDiagnostics();
    final queue = testQueue(now, diagnostics: diagnostics);
    final first = command(now, 'command-0001', 'idempotency-key-0001');
    final duplicate = command(now, 'command-0002', 'idempotency-key-0001');
    await Future.wait([queue.enqueue(first), queue.enqueue(duplicate)]);

    final dispatcher = RecordingDispatcher();
    expect(await queue.drain(dispatcher), 1);
    expect(dispatcher.ids, ['command-0001']);
    expect(await queue.pending(), isEmpty);
    expect(diagnostics.toString(), isNot(contains('private-value')));
  });

  test('retryable failure stops ordering and resumes on reconnect', () async {
    final queue = testQueue(now);
    await queue.enqueue(command(now, 'command-0001', 'idempotency-key-0001'));
    await queue.enqueue(command(now, 'command-0002', 'idempotency-key-0002'));
    final offline = RecordingDispatcher(
      result: CommandDispatchResult.retryableFailure,
    );

    expect(await queue.drain(offline), 0);
    expect(offline.ids, ['command-0001']);
    expect(await queue.pending(), hasLength(2));

    final online = RecordingDispatcher();
    expect(await queue.drain(online), 2);
    expect(online.ids, ['command-0001', 'command-0002']);
  });

  test('expired and permanently invalid commands are discarded', () async {
    var clock = now;
    final queue = testQueue(now, clock: () => clock);
    await queue.enqueue(command(now, 'command-0001', 'idempotency-key-0001'));
    clock = now.add(const Duration(days: 2));

    expect(await queue.drain(RecordingDispatcher()), 0);
    expect(await queue.pending(), isEmpty);

    clock = now;
    await queue.enqueue(command(now, 'command-0002', 'idempotency-key-0002'));
    await queue.drain(
      RecordingDispatcher(result: CommandDispatchResult.permanentFailure),
    );
    expect(await queue.pending(), isEmpty);
  });

  test('commands reject credentials and unapproved operations', () async {
    expect(
      () => OfflineCommand(
        id: 'command-0001',
        operation: 'profile.update',
        idempotencyKey: 'idempotency-key-0001',
        payload: const {'access_token': 'secret'},
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      ),
      throwsFormatException,
    );
    final queue = testQueue(now);
    await expectLater(
      queue.enqueue(
        OfflineCommand(
          id: 'command-0001',
          operation: 'unapproved.command',
          idempotencyKey: 'idempotency-key-0001',
          payload: const {'value': 'private-value'},
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      ),
      throwsFormatException,
    );
  });
}

OfflineCommandQueue testQueue(
  DateTime now, {
  StorageClock? clock,
  QueueDiagnostics diagnostics = const NoopQueueDiagnostics(),
}) => OfflineCommandQueue(
  store: EncryptedRecordStore(
    records: MemoryBinaryRecordStore(),
    keyProvider: MemoryCacheKeyProvider(),
    clock: clock ?? () => now,
  ),
  allowedOperations: const {'profile.update'},
  clock: clock ?? () => now,
  diagnostics: diagnostics,
);

OfflineCommand command(DateTime now, String id, String idempotencyKey) =>
    OfflineCommand(
      id: id,
      operation: 'profile.update',
      idempotencyKey: idempotencyKey,
      payload: const {'display_name': 'private-value'},
      createdAt: now,
      expiresAt: now.add(const Duration(days: 1)),
    );

final class RecordingDispatcher implements OfflineCommandDispatcher {
  RecordingDispatcher({this.result = CommandDispatchResult.success});
  final CommandDispatchResult result;
  final List<String> ids = [];

  @override
  Future<CommandDispatchResult> dispatch(OfflineCommand command) async {
    ids.add(command.id);
    return result;
  }
}

final class RecordingDiagnostics implements QueueDiagnostics {
  final List<String> events = [];
  @override
  void event({
    required String commandId,
    required String operation,
    required QueueDiagnosticOutcome outcome,
  }) => events.add('$commandId:$operation:${outcome.name}');
  @override
  String toString() => events.join(',');
}

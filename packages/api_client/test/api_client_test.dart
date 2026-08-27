import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

void main() {
  test(
    'success adds auth and correlation without logging request data',
    () async {
      final transport = ScriptedTransport([
        response(
          200,
          {'status': 'ok', 'service': 'gateway', 'version': 'synthetic'},
          headers: {'X-Correlation-ID': 'corr-server-001'},
        ),
      ]);
      final auth = MutableAuthSession('access-token-secret');
      final diagnostics = RecordingDiagnostics();
      final client = testClient(
        transport,
        authSession: auth,
        diagnostics: diagnostics,
      );

      final result = await client.send(
        ApiRequest.get(operation: 'test.get_health', path: '/healthz'),
        HealthResponse.fromJson,
      );

      expect(result.value.service, 'gateway');
      expect(result.correlationId, 'corr-server-001');
      expect(
        transport.requests.single.headers['Authorization'],
        'Bearer access-token-secret',
      );
      expect(
        transport.requests.single.headers['X-Correlation-ID'],
        fixedCorrelation,
      );
      expect(diagnostics.operations, ['test.get_health']);
      expect(diagnostics.toString(), isNot(contains('access-token-secret')));
    },
  );

  test('missing access token denies before transport', () async {
    final transport = ScriptedTransport([]);
    final client = testClient(transport, authSession: MutableAuthSession(null));

    await expectLater(
      client.send(
        ApiRequest.get(operation: 'test.private_read', path: '/v1/private'),
        (json) => json,
      ),
      throwsA(isA<ApiAuthenticationFailure>()),
    );
    expect(transport.requests, isEmpty);
  });

  test('safe request refreshes once and replays with the new token', () async {
    final transport = ScriptedTransport([
      problem(401, code: 'AUTHENTICATION_EXPIRED'),
      response(200, {'ok': true}),
    ]);
    final auth = MutableAuthSession(
      'expired-token',
      refreshedToken: 'fresh-token',
    );
    final client = testClient(transport, authSession: auth);

    final result = await client.send(
      ApiRequest.get(operation: 'test.refresh_read', path: '/v1/private'),
      (json) => (json as Map<String, Object?>)['ok'] as bool,
    );

    expect(result.value, isTrue);
    expect(auth.refreshCalls, 1);
    expect(transport.requests, hasLength(2));
    expect(
      transport.requests[0].headers['Authorization'],
      'Bearer expired-token',
    );
    expect(
      transport.requests[1].headers['Authorization'],
      'Bearer fresh-token',
    );
    expect(
      transport.requests
          .map((request) => request.headers['X-Correlation-ID'])
          .toSet(),
      {fixedCorrelation},
    );
  });

  test('non-replayable mutation does not refresh or retry', () async {
    final transport = ScriptedTransport([
      problem(401, code: 'AUTHENTICATION_EXPIRED'),
    ]);
    final auth = MutableAuthSession(
      'expired-token',
      refreshedToken: 'fresh-token',
    );
    final client = testClient(transport, authSession: auth);
    final request = ApiRequest(
      operation: 'test.unsafe_mutation',
      method: 'POST',
      path: '/v1/unsafe',
      body: {'value': true},
    );

    await expectLater(
      client.send(request, (json) => json),
      throwsA(isA<ApiAuthenticationFailure>()),
    );
    expect(auth.refreshCalls, 0);
    expect(transport.requests, hasLength(1));
  });

  test(
    'safe retry budget handles timeout and retryable dependency failure',
    () async {
      final transport = ScriptedTransport([
        const TransportTimeoutException(),
        problem(503, code: 'UPSTREAM_UNAVAILABLE', retryable: true),
        response(200, {'ok': true}),
      ]);
      final delays = <Duration>[];
      final client = testClient(
        transport,
        delay: (duration, token) async {
          token.throwIfCancelled();
          delays.add(duration);
        },
        random: Random(1),
      );

      final result = await client.send(
        ApiRequest.get(
          operation: 'test.retry_read',
          path: '/v1/read',
          authRequired: false,
        ),
        (json) => (json as Map<String, Object?>)['ok'] as bool,
      );

      expect(result.value, isTrue);
      expect(transport.requests, hasLength(3));
      expect(delays, hasLength(2));
      expect(
        delays.every((delay) => delay <= const Duration(seconds: 2)),
        isTrue,
      );
    },
  );

  test(
    'idempotent command preserves its key and body across retries',
    () async {
      final transport = ScriptedTransport([
        problem(503, code: 'UPSTREAM_UNAVAILABLE', retryable: true),
        response(202, {'accepted': true}),
      ]);
      final client = testClient(
        transport,
        delay: noDelay,
        authSession: MutableAuthSession('synthetic-access-token'),
      );
      final request = ApiRequest.command(
        operation: 'test.create_command',
        method: 'POST',
        path: '/v1/commands',
        body: {'synthetic': true},
      );

      await client.send(request, (json) => json);

      expect(IdempotencyKey.isValid(request.idempotencyKey!), isTrue);
      expect(transport.requests, hasLength(2));
      expect(
        transport.requests
            .map((value) => value.headers['Idempotency-Key'])
            .toSet(),
        {request.idempotencyKey},
      );
      expect(transport.requests[0].body, transport.requests[1].body);
    },
  );

  test('server Retry-After is capped by the retry budget', () async {
    final transport = ScriptedTransport([
      problem(
        429,
        code: 'RATE_LIMITED',
        retryable: true,
        headers: {'Retry-After': '9999'},
      ),
      response(200, {'ok': true}),
    ]);
    final delays = <Duration>[];
    final client = testClient(
      transport,
      delay: (duration, _) async => delays.add(duration),
    );

    await client.send(
      ApiRequest.get(
        operation: 'test.rate_retry',
        path: '/v1/read',
        authRequired: false,
      ),
      (json) => json,
    );

    expect(delays, [const Duration(seconds: 30)]);
  });

  test('timeout exhaustion uses the exact retry budget', () async {
    final transport = ScriptedTransport([
      const TransportTimeoutException(),
      const TransportTimeoutException(),
      const TransportTimeoutException(),
    ]);

    await expectLater(
      testClient(transport).send(
        ApiRequest.get(
          operation: 'test.timeout_budget',
          path: '/v1/read',
          authRequired: false,
        ),
        (json) => json,
      ),
      throwsA(isA<ApiTimeoutFailure>()),
    );
    expect(transport.requests, hasLength(3));
  });

  test('retryable failure never replays an unsafe mutation', () async {
    final transport = ScriptedTransport([
      problem(503, code: 'UPSTREAM_UNAVAILABLE', retryable: true),
    ]);
    final request = ApiRequest(
      operation: 'test.unsafe_dependency_failure',
      method: 'POST',
      path: '/v1/write',
      body: {'synthetic': true},
    );

    await expectLater(
      testClient(
        transport,
        authSession: MutableAuthSession('synthetic-access-token'),
      ).send(request, (json) => json),
      throwsA(isA<ApiDependencyFailure>()),
    );
    expect(transport.requests, hasLength(1));
  });

  test('cancellation during retry delay maps to typed failure', () async {
    final delayStarted = Completer<void>();
    final cancellation = ApiCancellationToken();
    final client = testClient(
      ScriptedTransport([const TransportTimeoutException()]),
      delay: (_, token) async {
        delayStarted.complete();
        await token.whenCancelled;
        throw const TransportCancelledException();
      },
    );
    final pending = client.send(
      ApiRequest.get(
        operation: 'test.cancel_retry_delay',
        path: '/v1/read',
        authRequired: false,
      ),
      (json) => json,
      cancellationToken: cancellation,
    );
    await delayStarted.future;
    cancellation.cancel();

    await expectLater(pending, throwsA(isA<ApiCancellationFailure>()));
  });

  test(
    'cancellation before and during transport maps to typed failure',
    () async {
      final cancelled = ApiCancellationToken()..cancel();
      final unusedTransport = ScriptedTransport([]);
      await expectLater(
        testClient(unusedTransport).send(
          ApiRequest.get(
            operation: 'test.pre_cancelled',
            path: '/v1/read',
            authRequired: false,
          ),
          (json) => json,
          cancellationToken: cancelled,
        ),
        throwsA(isA<ApiCancellationFailure>()),
      );
      expect(unusedTransport.requests, isEmpty);

      final token = ApiCancellationToken();
      final waitingTransport = WaitingTransport();
      final future = testClient(waitingTransport).send(
        ApiRequest.get(
          operation: 'test.active_cancel',
          path: '/v1/read',
          authRequired: false,
        ),
        (json) => json,
        cancellationToken: token,
      );
      await waitingTransport.started.future;
      token.cancel();
      await expectLater(future, throwsA(isA<ApiCancellationFailure>()));
    },
  );

  test('status codes map to stable failure taxonomy', () async {
    final cases = <int, Type>{
      401: ApiAuthenticationFailure,
      403: ApiAuthorizationFailure,
      409: ApiConflictFailure,
      422: ApiValidationFailure,
      429: ApiRateLimitFailure,
      503: ApiDependencyFailure,
      418: ApiUnknownFailure,
    };
    for (final entry in cases.entries) {
      final transport = ScriptedTransport([
        problem(entry.key, code: 'SYNTHETIC_FAILURE', retryable: false),
      ]);
      final client = testClient(transport);
      await expectLater(
        client.send(
          ApiRequest.get(
            operation: 'test.failure_${entry.key}',
            path: '/v1/failure',
            authRequired: false,
          ),
          (json) => json,
        ),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.runtimeType,
            'type',
            entry.value,
          ),
        ),
      );
    }
  });

  test(
    'malformed success and error payloads become contract failures',
    () async {
      for (final scripted in [
        TransportResponse(
          statusCode: 200,
          headers: const {},
          body: Uint8List.fromList(utf8.encode('{')),
        ),
        TransportResponse(
          statusCode: 500,
          headers: const {},
          body: Uint8List.fromList(utf8.encode('stack trace')),
        ),
      ]) {
        final client = testClient(ScriptedTransport([scripted]));
        await expectLater(
          client.send(
            ApiRequest.get(
              operation: 'test.contract_failure',
              path: '/v1/read',
              authRequired: false,
            ),
            HealthResponse.fromJson,
          ),
          throwsA(isA<ApiContractFailure>()),
        );
      }
    },
  );

  test('diagnostic failures cannot alter request outcome', () async {
    final client = testClient(
      ScriptedTransport([
        response(200, {'ok': true}),
      ]),
      diagnostics: ThrowingDiagnostics(),
    );
    final result = await client.send(
      ApiRequest.get(
        operation: 'test.diagnostics_isolation',
        path: '/v1/read',
        authRequired: false,
      ),
      (json) => (json as Map<String, Object?>)['ok'] as bool,
    );
    expect(result.value, isTrue);
  });

  test('request policy rejects reserved headers and unsafe replay setup', () {
    expect(
      () => ApiRequest.get(
        operation: 'test.bad_header',
        path: '/v1/read',
        headers: {'Authorization': 'secret'},
      ),
      throwsFormatException,
    );
    expect(
      () => ApiRequest(
        operation: 'test.missing_key',
        method: 'POST',
        path: '/v1/write',
        replayPolicy: ApiReplayPolicy.idempotent,
      ),
      throwsFormatException,
    );
    expect(
      () => ApiRequest(
        operation: 'test.unsafe_replay',
        method: 'POST',
        path: '/v1/write',
        replayPolicy: ApiReplayPolicy.safe,
      ),
      throwsFormatException,
    );
  });

  test('request snapshots body, headers, and query before retries', () {
    final body = <String, Object?>{'value': 'before'};
    final headers = <String, String>{'X-Synthetic': 'before'};
    final query = <String, List<String>>{
      'category': ['before'],
    };
    final request = ApiRequest.command(
      operation: 'test.snapshot_command',
      method: 'POST',
      path: '/v1/write',
      body: body,
      headers: headers,
      query: query,
    );
    body['value'] = 'after';
    headers['X-Synthetic'] = 'after';
    query['category']!.add('after');

    expect(utf8.decode(request.encodeBody()!), '{"value":"before"}');
    expect(request.headers['X-Synthetic'], 'before');
    expect(request.query['category'], ['before']);
  });

  test('query values are encoded without collapsing repeated values', () async {
    final transport = ScriptedTransport([
      response(200, {'ok': true}),
    ]);
    await testClient(transport).send(
      ApiRequest.get(
        operation: 'test.repeated_query',
        path: '/v1/read',
        query: const {
          'category': ['flowers', 'cakes'],
          'search': ['Tamil wedding & reception'],
        },
        authRequired: false,
      ),
      (json) => json,
    );

    expect(transport.requests.single.url.queryParametersAll, {
      'category': ['flowers', 'cakes'],
      'search': ['Tamil wedding & reception'],
    });
  });

  test('invalid access and correlation values fail before transport', () async {
    final badTokenTransport = ScriptedTransport([]);
    await expectLater(
      testClient(
        badTokenTransport,
        authSession: MutableAuthSession('token with spaces'),
      ).send(
        ApiRequest.get(operation: 'test.invalid_token', path: '/v1/read'),
        (json) => json,
      ),
      throwsA(isA<ApiAuthenticationFailure>()),
    );
    expect(badTokenTransport.requests, isEmpty);

    final badCorrelationTransport = ScriptedTransport([]);
    final badCorrelationClient = ApiClient(
      baseUrl: Uri.parse('https://api.staging.planext4u.net'),
      transport: badCorrelationTransport,
      correlationIdFactory: () => 'invalid correlation',
    );
    await expectLater(
      badCorrelationClient.send(
        ApiRequest.get(
          operation: 'test.invalid_correlation',
          path: '/v1/read',
          authRequired: false,
        ),
        (json) => json,
      ),
      throwsFormatException,
    );
    expect(badCorrelationTransport.requests, isEmpty);
  });

  test('redaction removes credentials while retaining safe metadata', () {
    expect(
      redactHeadersForDiagnostics({
        'Authorization': 'Bearer secret',
        'Cookie': 'session=secret',
        'Idempotency-Key': 'synthetic-key',
        'Content-Type': 'application/json',
      }),
      {
        'Authorization': '[REDACTED]',
        'Cookie': '[REDACTED]',
        'Idempotency-Key': '[REDACTED]',
        'Content-Type': 'application/json',
      },
    );
  });

  test('generated CommonApi calls public contract routes', () async {
    final transport = ScriptedTransport([
      response(200, {'status': 'ok', 'service': 'gateway', 'version': 'v1'}),
      response(200, {'status': 'ready', 'service': 'gateway', 'version': 'v1'}),
    ]);
    final common = CommonApi(testClient(transport));
    expect((await common.getHealth()).value.status, HealthStatus.ok);
    expect((await common.getReadiness()).value.status, HealthStatus.ready);
    expect(transport.requests.map((request) => request.url.path), [
      '/healthz',
      '/readyz',
    ]);
    expect(
      transport.requests.every(
        (request) => !request.headers.containsKey('Authorization'),
      ),
      isTrue,
    );
  });
}

const fixedCorrelation = 'corr-synthetic-client-001';

ApiClient testClient(
  ApiTransport transport, {
  ApiAuthSession authSession = const AnonymousApiAuthSession(),
  ApiDiagnostics diagnostics = const NoopApiDiagnostics(),
  ApiDelay delay = noDelay,
  Random? random,
}) => ApiClient(
  baseUrl: Uri.parse('https://api.staging.planext4u.net'),
  transport: transport,
  authSession: authSession,
  diagnostics: diagnostics,
  delay: delay,
  correlationIdFactory: () => fixedCorrelation,
  random: random ?? Random(1),
);

Future<void> noDelay(Duration _, ApiCancellationToken token) async {
  token.throwIfCancelled();
}

TransportResponse response(
  int status,
  Object? body, {
  Map<String, String> headers = const {},
}) => TransportResponse(
  statusCode: status,
  headers: headers,
  body: Uint8List.fromList(utf8.encode(jsonEncode(body))),
);

TransportResponse problem(
  int status, {
  required String code,
  bool retryable = false,
  Map<String, String> headers = const {},
}) => response(status, {
  'error': {
    'code': code,
    'message': 'Synthetic safe failure.',
    'correlation_id': 'corr-synthetic-error',
    'retryable': retryable,
    'field_errors': [
      if (status == 422)
        {
          'field': 'synthetic_field',
          'code': 'INVALID',
          'message': 'Choose another value.',
        },
    ],
    'details': <String, Object?>{},
  },
}, headers: headers);

final class ScriptedTransport implements ApiTransport {
  ScriptedTransport(this._script);

  final List<Object> _script;
  final List<TransportRequest> requests = [];

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    requests.add(request);
    if (_script.isEmpty) throw StateError('No scripted response.');
    final next = _script.removeAt(0);
    if (next is Exception) throw next;
    return next as TransportResponse;
  }
}

final class WaitingTransport implements ApiTransport {
  final Completer<void> started = Completer<void>();

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    started.complete();
    await cancellationToken.whenCancelled;
    throw const TransportCancelledException();
  }
}

final class MutableAuthSession implements ApiAuthSession {
  MutableAuthSession(this.token, {this.refreshedToken});

  String? token;
  final String? refreshedToken;
  int refreshCalls = 0;

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<bool> refresh() async {
    refreshCalls++;
    token = refreshedToken;
    return refreshedToken != null;
  }
}

final class RecordingDiagnostics implements ApiDiagnostics {
  final List<String> operations = [];

  @override
  void requestStarted({
    required String operation,
    required String method,
    required int attempt,
    required String correlationId,
  }) {
    operations.add(operation);
  }

  @override
  void requestFinished({
    required String operation,
    required int attempt,
    required ApiDiagnosticOutcome outcome,
    required int? statusCode,
    required Duration elapsed,
    required String correlationId,
  }) {}

  @override
  String toString() => operations.join(',');
}

final class ThrowingDiagnostics implements ApiDiagnostics {
  @override
  void requestStarted({
    required String operation,
    required String method,
    required int attempt,
    required String correlationId,
  }) {
    throw StateError('synthetic diagnostics failure');
  }

  @override
  void requestFinished({
    required String operation,
    required int attempt,
    required ApiDiagnosticOutcome outcome,
    required int? statusCode,
    required Duration elapsed,
    required String correlationId,
  }) {
    throw StateError('synthetic diagnostics failure');
  }
}

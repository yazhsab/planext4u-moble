import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'cancellation.dart';
import 'diagnostics.dart';
import 'failures.dart';
import 'generated/common_models.g.dart';
import 'request.dart';
import 'transport.dart';

abstract interface class ApiAuthSession {
  Future<String?> accessToken();

  Future<bool> refresh();
}

final class AnonymousApiAuthSession implements ApiAuthSession {
  const AnonymousApiAuthSession();

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<bool> refresh() async => false;
}

final class ApiRetryBudget {
  const ApiRetryBudget({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 2),
    this.maxServerDelay = const Duration(seconds: 30),
  }) : assert(maxAttempts >= 1 && maxAttempts <= 5);

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final Duration maxServerDelay;
}

final class ApiResponse<T> {
  const ApiResponse({
    required this.value,
    required this.statusCode,
    required this.correlationId,
  });

  final T value;
  final int statusCode;
  final String correlationId;
}

typedef ApiDelay =
    Future<void> Function(Duration duration, ApiCancellationToken token);
typedef CorrelationIdFactory = String Function();

final class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required ApiTransport transport,
    ApiAuthSession authSession = const AnonymousApiAuthSession(),
    ApiDiagnostics diagnostics = const NoopApiDiagnostics(),
    ApiRetryBudget retryBudget = const ApiRetryBudget(),
    Duration attemptTimeout = const Duration(seconds: 10),
    ApiDelay delay = _cancellableDelay,
    CorrelationIdFactory correlationIdFactory = _newCorrelationId,
    Random? random,
  }) : baseUrl = _validateBaseUrl(baseUrl),
       _transport = transport,
       _authSession = authSession,
       _diagnostics = diagnostics,
       _retryBudget = retryBudget,
       _attemptTimeout = attemptTimeout,
       _delay = delay,
       _correlationIdFactory = correlationIdFactory,
       _random = random ?? Random.secure() {
    if (attemptTimeout <= Duration.zero ||
        attemptTimeout > const Duration(minutes: 1)) {
      throw const FormatException('attemptTimeout is outside the safe range.');
    }
    if (retryBudget.maxAttempts < 1 ||
        retryBudget.maxAttempts > 5 ||
        retryBudget.baseDelay <= Duration.zero ||
        retryBudget.maxDelay < retryBudget.baseDelay ||
        retryBudget.maxServerDelay < Duration.zero) {
      throw const FormatException('retryBudget is outside the safe range.');
    }
  }

  final Uri baseUrl;
  final ApiTransport _transport;
  final ApiAuthSession _authSession;
  final ApiDiagnostics _diagnostics;
  final ApiRetryBudget _retryBudget;
  final Duration _attemptTimeout;
  final ApiDelay _delay;
  final CorrelationIdFactory _correlationIdFactory;
  final Random _random;

  Future<ApiResponse<T>> send<T>(
    ApiRequest request,
    T Function(Object? json) decode, {
    ApiCancellationToken? cancellationToken,
  }) async {
    final cancellation = cancellationToken ?? ApiCancellationToken();
    final correlationId = _correlationIdFactory();
    if (!_validCorrelationId(correlationId)) {
      throw const FormatException(
        'Correlation ID factory returned an invalid value.',
      );
    }
    if (cancellation.isCancelled) {
      throw ApiCancellationFailure(correlationId: correlationId);
    }
    final body = request.encodeBody();
    var refreshed = false;
    Object? lastTransportError;

    for (var attempt = 1; attempt <= _retryBudget.maxAttempts; attempt++) {
      if (cancellation.isCancelled) {
        throw ApiCancellationFailure(correlationId: correlationId);
      }
      final headers = <String, String>{
        'Accept': 'application/json',
        'X-Correlation-ID': correlationId,
        ...request.headers,
      };
      if (body != null) headers['Content-Type'] = 'application/json';
      if (request.idempotencyKey != null) {
        headers['Idempotency-Key'] = request.idempotencyKey!;
      }
      if (request.authRequired) {
        String? token;
        try {
          token = await _authSession.accessToken();
        } catch (_) {
          throw ApiAuthenticationFailure(
            code: 'AUTH_SESSION_UNAVAILABLE',
            message: 'The secure session could not be read.',
            correlationId: correlationId,
          );
        }
        if (!_validAccessToken(token)) {
          throw ApiAuthenticationFailure(
            code: 'AUTHENTICATION_REQUIRED',
            message: 'Sign in to continue.',
            correlationId: correlationId,
          );
        }
        headers['Authorization'] = 'Bearer $token';
      }

      final url = _buildUrl(request);
      final started = Stopwatch()..start();
      _startDiagnostic(request, attempt, correlationId);
      TransportResponse response;
      try {
        response = await _transport.send(
          TransportRequest(
            method: request.method,
            url: url,
            headers: Map.unmodifiable(headers),
            body: body,
          ),
          timeout: _attemptTimeout,
          cancellationToken: cancellation,
        );
      } on TransportCancelledException {
        _finishDiagnostic(
          request,
          attempt,
          started,
          correlationId,
          ApiDiagnosticOutcome.cancelled,
          null,
        );
        throw ApiCancellationFailure(correlationId: correlationId);
      } on TransportTimeoutException catch (error) {
        lastTransportError = error;
        _finishDiagnostic(
          request,
          attempt,
          started,
          correlationId,
          ApiDiagnosticOutcome.failure,
          null,
        );
        if (!_mayRetry(request, attempt)) {
          throw ApiTimeoutFailure(correlationId: correlationId);
        }
        await _waitForRetry(
          _retryDelay(attempt, null),
          cancellation,
          correlationId,
        );
        continue;
      } on TransportResponseTooLargeException {
        _finishDiagnostic(
          request,
          attempt,
          started,
          correlationId,
          ApiDiagnosticOutcome.failure,
          null,
        );
        throw ApiContractFailure(
          code: 'RESPONSE_TOO_LARGE',
          message: 'The service returned an oversized response.',
          correlationId: correlationId,
        );
      } on ApiFailure {
        _finishDiagnostic(
          request,
          attempt,
          started,
          correlationId,
          ApiDiagnosticOutcome.failure,
          null,
        );
        rethrow;
      } catch (error) {
        lastTransportError = error;
        _finishDiagnostic(
          request,
          attempt,
          started,
          correlationId,
          ApiDiagnosticOutcome.failure,
          null,
        );
        if (!_mayRetry(request, attempt)) {
          throw ApiTransportFailure(correlationId: correlationId);
        }
        await _waitForRetry(
          _retryDelay(attempt, null),
          cancellation,
          correlationId,
        );
        continue;
      }

      final responseCorrelation = _safeResponseCorrelation(
        response,
        correlationId,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final decodedBody = response.body.isEmpty
              ? null
              : jsonDecode(utf8.decode(response.body, allowMalformed: false));
          final value = decode(decodedBody);
          _finishDiagnostic(
            request,
            attempt,
            started,
            responseCorrelation,
            ApiDiagnosticOutcome.success,
            response.statusCode,
          );
          return ApiResponse(
            value: value,
            statusCode: response.statusCode,
            correlationId: responseCorrelation,
          );
        } catch (_) {
          _finishDiagnostic(
            request,
            attempt,
            started,
            responseCorrelation,
            ApiDiagnosticOutcome.failure,
            response.statusCode,
          );
          throw ApiContractFailure(
            code: 'RESPONSE_CONTRACT_INVALID',
            message: 'The service returned an invalid response.',
            correlationId: responseCorrelation,
            statusCode: response.statusCode,
          );
        }
      }

      final failure = _mapFailure(response, responseCorrelation);
      _finishDiagnostic(
        request,
        attempt,
        started,
        responseCorrelation,
        ApiDiagnosticOutcome.failure,
        response.statusCode,
      );
      if (response.statusCode == 401 &&
          request.authRequired &&
          request.canReplay &&
          !refreshed &&
          _mayRetry(request, attempt)) {
        refreshed = true;
        var didRefresh = false;
        try {
          didRefresh = await _authSession.refresh();
        } catch (_) {
          didRefresh = false;
        }
        if (didRefresh) continue;
      }
      if (_retryableStatus(response.statusCode) &&
          failure.retryable &&
          _mayRetry(request, attempt)) {
        await _waitForRetry(
          _retryDelay(attempt, _parseRetryAfter(response)),
          cancellation,
          correlationId,
        );
        continue;
      }
      throw failure;
    }

    if (lastTransportError is TransportTimeoutException) {
      throw ApiTimeoutFailure(correlationId: correlationId);
    }
    throw ApiTransportFailure(correlationId: correlationId);
  }

  Uri _buildUrl(ApiRequest request) {
    final resolved = baseUrl.resolve(request.path);
    if (resolved.origin != baseUrl.origin) {
      throw const FormatException(
        'Request resolved outside the configured API origin.',
      );
    }
    return resolved.replace(
      queryParameters: {
        for (final entry in request.query.entries) entry.key: entry.value,
      },
    );
  }

  bool _mayRetry(ApiRequest request, int attempt) =>
      request.canReplay && attempt < _retryBudget.maxAttempts;

  Duration _retryDelay(int attempt, Duration? serverDelay) {
    if (serverDelay != null) return serverDelay;
    final multiplier = 1 << (attempt - 1);
    final rawMilliseconds = min(
      _retryBudget.maxDelay.inMilliseconds,
      _retryBudget.baseDelay.inMilliseconds * multiplier,
    );
    final jitter = 0.8 + (_random.nextDouble() * 0.4);
    return Duration(milliseconds: max(1, (rawMilliseconds * jitter).round()));
  }

  Duration? _parseRetryAfter(TransportResponse response) {
    final raw = response.header('Retry-After');
    final seconds = raw == null ? null : int.tryParse(raw.trim());
    if (seconds == null || seconds < 0) return null;
    final requested = Duration(seconds: seconds);
    return requested > _retryBudget.maxServerDelay
        ? _retryBudget.maxServerDelay
        : requested;
  }

  Future<void> _waitForRetry(
    Duration duration,
    ApiCancellationToken cancellation,
    String correlationId,
  ) async {
    try {
      await _delay(duration, cancellation);
    } on TransportCancelledException {
      throw ApiCancellationFailure(correlationId: correlationId);
    }
  }

  void _startDiagnostic(ApiRequest request, int attempt, String correlationId) {
    try {
      _diagnostics.requestStarted(
        operation: request.operation,
        method: request.method,
        attempt: attempt,
        correlationId: correlationId,
      );
    } catch (_) {
      // Diagnostics must never alter the network outcome.
    }
  }

  void _finishDiagnostic(
    ApiRequest request,
    int attempt,
    Stopwatch stopwatch,
    String correlationId,
    ApiDiagnosticOutcome outcome,
    int? statusCode,
  ) {
    stopwatch.stop();
    try {
      _diagnostics.requestFinished(
        operation: request.operation,
        attempt: attempt,
        outcome: outcome,
        statusCode: statusCode,
        elapsed: stopwatch.elapsed,
        correlationId: correlationId,
      );
    } catch (_) {
      // Diagnostics must never alter the network outcome.
    }
  }
}

ApiFailure _mapFailure(TransportResponse response, String fallbackCorrelation) {
  ApiErrorDetail detail;
  try {
    final decoded = jsonDecode(
      utf8.decode(response.body, allowMalformed: false),
    );
    detail = ApiErrorEnvelope.fromJson(decoded).error;
  } catch (_) {
    return ApiContractFailure(
      code: 'ERROR_CONTRACT_INVALID',
      message: 'The service returned an invalid error response.',
      correlationId: fallbackCorrelation,
      statusCode: response.statusCode,
    );
  }
  final correlation = _validCorrelationId(detail.correlationId)
      ? detail.correlationId
      : fallbackCorrelation;
  return switch (response.statusCode) {
    401 => ApiAuthenticationFailure(
      code: detail.code,
      message: detail.message,
      correlationId: correlation,
      statusCode: response.statusCode,
    ),
    403 => ApiAuthorizationFailure(
      code: detail.code,
      message: detail.message,
      correlationId: correlation,
      statusCode: response.statusCode,
    ),
    409 => ApiConflictFailure(
      code: detail.code,
      message: detail.message,
      correlationId: correlation,
      retryable: detail.retryable,
      statusCode: response.statusCode,
      fieldErrors: detail.fieldErrors,
    ),
    400 || 422 => ApiValidationFailure(
      code: detail.code,
      message: detail.message,
      correlationId: correlation,
      statusCode: response.statusCode,
      fieldErrors: detail.fieldErrors,
    ),
    429 => ApiRateLimitFailure(
      code: detail.code,
      message: detail.message,
      correlationId: correlation,
      retryable: detail.retryable,
      retryAfter: _retryAfterForFailure(response),
      statusCode: response.statusCode,
    ),
    502 || 503 || 504 => ApiDependencyFailure(
      code: detail.code,
      message: detail.message,
      correlationId: correlation,
      retryable: detail.retryable,
      statusCode: response.statusCode,
    ),
    _ => ApiUnknownFailure(
      code: detail.code,
      message: detail.message,
      correlationId: correlation,
      retryable: detail.retryable,
      statusCode: response.statusCode,
    ),
  };
}

Duration? _retryAfterForFailure(TransportResponse response) {
  final value = int.tryParse(response.header('Retry-After') ?? '');
  return value == null || value < 0 ? null : Duration(seconds: value);
}

bool _retryableStatus(int status) =>
    const {408, 429, 502, 503, 504}.contains(status);

String _safeResponseCorrelation(TransportResponse response, String fallback) {
  final value = response.header('X-Correlation-ID');
  return value != null && _validCorrelationId(value) ? value : fallback;
}

bool _validAccessToken(String? value) {
  if (value == null || value.isEmpty || value.length > 8192) {
    return false;
  }
  return value.runes.every(
    (character) => character >= 0x21 && character <= 0x7e,
  );
}

bool _validCorrelationId(String value) {
  if (value.isEmpty || value.length > 128) return false;
  return value.runes.every(
    (character) => character >= 0x21 && character <= 0x7e,
  );
}

Uri _validateBaseUrl(Uri value) {
  if (!value.isAbsolute ||
      (value.scheme != 'http' && value.scheme != 'https') ||
      value.host.isEmpty) {
    throw const FormatException('API base URL must be absolute HTTP(S).');
  }
  if (value.userInfo.isNotEmpty || value.hasQuery || value.hasFragment) {
    throw const FormatException(
      'API base URL cannot contain credentials, query, or fragment.',
    );
  }
  return value;
}

Future<void> _cancellableDelay(
  Duration duration,
  ApiCancellationToken token,
) async {
  token.throwIfCancelled();
  final timer = Completer<void>();
  final handle = Timer(duration, timer.complete);
  final removeListener = token.onCancel(() {
    if (!timer.isCompleted) {
      timer.completeError(const TransportCancelledException());
    }
  });
  try {
    await timer.future;
  } finally {
    handle.cancel();
    removeListener();
  }
}

String _newCorrelationId() {
  final random = Random.secure();
  return List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

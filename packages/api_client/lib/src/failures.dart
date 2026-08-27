import 'generated/common_models.g.dart';

sealed class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    required this.correlationId,
    required this.retryable,
    this.statusCode,
    this.fieldErrors = const [],
  });

  final String code;
  final String message;
  final String correlationId;
  final bool retryable;
  final int? statusCode;
  final List<ApiFieldError> fieldErrors;

  @override
  String toString() => '$runtimeType($code, correlation: $correlationId)';
}

final class ApiAuthenticationFailure extends ApiFailure {
  const ApiAuthenticationFailure({
    required super.code,
    required super.message,
    required super.correlationId,
    super.statusCode,
  }) : super(retryable: false);
}

final class ApiAuthorizationFailure extends ApiFailure {
  const ApiAuthorizationFailure({
    required super.code,
    required super.message,
    required super.correlationId,
    super.statusCode,
  }) : super(retryable: false);
}

final class ApiValidationFailure extends ApiFailure {
  const ApiValidationFailure({
    required super.code,
    required super.message,
    required super.correlationId,
    required super.fieldErrors,
    super.statusCode,
  }) : super(retryable: false);
}

final class ApiConflictFailure extends ApiFailure {
  const ApiConflictFailure({
    required super.code,
    required super.message,
    required super.correlationId,
    required super.retryable,
    super.statusCode,
    super.fieldErrors,
  });
}

final class ApiRateLimitFailure extends ApiFailure {
  const ApiRateLimitFailure({
    required super.code,
    required super.message,
    required super.correlationId,
    required super.retryable,
    required this.retryAfter,
    super.statusCode,
  });

  final Duration? retryAfter;
}

final class ApiDependencyFailure extends ApiFailure {
  const ApiDependencyFailure({
    required super.code,
    required super.message,
    required super.correlationId,
    required super.retryable,
    super.statusCode,
  });
}

final class ApiTransportFailure extends ApiFailure {
  const ApiTransportFailure({required super.correlationId})
    : super(
        code: 'NETWORK_UNAVAILABLE',
        message: 'The service could not be reached.',
        retryable: true,
      );
}

final class ApiTimeoutFailure extends ApiFailure {
  const ApiTimeoutFailure({required super.correlationId})
    : super(
        code: 'REQUEST_TIMEOUT',
        message: 'The request did not complete in time.',
        retryable: true,
      );
}

final class ApiCancellationFailure extends ApiFailure {
  const ApiCancellationFailure({required super.correlationId})
    : super(
        code: 'REQUEST_CANCELLED',
        message: 'The request was cancelled.',
        retryable: false,
      );
}

final class ApiContractFailure extends ApiFailure {
  const ApiContractFailure({
    required super.code,
    required super.message,
    required super.correlationId,
    super.statusCode,
  }) : super(retryable: false);
}

final class ApiUnknownFailure extends ApiFailure {
  const ApiUnknownFailure({
    required super.code,
    required super.message,
    required super.correlationId,
    required super.retryable,
    super.statusCode,
  });
}

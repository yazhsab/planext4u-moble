// Code generated from common.openapi.json (332ef63e39ef8f7e4dc13a25709b697f288fbb66061f29f73ecf0ee7a8db4b0f); DO NOT EDIT.

enum ApiAppRole {
  unknown('UNKNOWN'),
  customer('CUSTOMER'),
  vendor('VENDOR'),
  rider('RIDER'),
  admin('ADMIN');

  const ApiAppRole(this.wireValue);
  final String wireValue;

  static ApiAppRole fromJson(Object? value) => switch (value) {
    'CUSTOMER' => customer,
    'VENDOR' => vendor,
    'RIDER' => rider,
    'ADMIN' => admin,
    _ => unknown,
  };
}

enum GeoPurpose {
  unknown('UNKNOWN'),
  serviceability('SERVICEABILITY'),
  delivery('DELIVERY'),
  emergency('EMERGENCY');

  const GeoPurpose(this.wireValue);
  final String wireValue;

  static GeoPurpose fromJson(Object? value) => switch (value) {
    'SERVICEABILITY' => serviceability,
    'DELIVERY' => delivery,
    'EMERGENCY' => emergency,
    _ => unknown,
  };
}

enum HealthStatus {
  ok('ok'),
  ready('ready'),
  notReady('not_ready'),
  unknown('unknown');

  const HealthStatus(this.wireValue);
  final String wireValue;

  static HealthStatus fromJson(Object? value) => switch (value) {
    'ok' => ok,
    'ready' => ready,
    'not_ready' => notReady,
    _ => unknown,
  };
}

final class ApiFieldError {
  const ApiFieldError({
    required this.field,
    required this.code,
    required this.message,
  });

  factory ApiFieldError.fromJson(Object? value) {
    final json = _object(value, 'FieldError');
    return ApiFieldError(
      field: _string(json, 'field'),
      code: _string(json, 'code'),
      message: _string(json, 'message'),
    );
  }

  final String field;
  final String code;
  final String message;

  Map<String, Object?> toJson() => {
    'field': field,
    'code': code,
    'message': message,
  };
}

final class ApiErrorDetail {
  const ApiErrorDetail({
    required this.code,
    required this.message,
    required this.correlationId,
    required this.retryable,
    required this.fieldErrors,
    required this.details,
  });

  factory ApiErrorDetail.fromJson(Object? value) {
    final json = _object(value, 'ErrorDetail');
    final fieldErrors = _list(
      json,
      'field_errors',
    ).map(ApiFieldError.fromJson).toList(growable: false);
    return ApiErrorDetail(
      code: _string(json, 'code'),
      message: _string(json, 'message'),
      correlationId: _string(json, 'correlation_id'),
      retryable: _boolean(json, 'retryable'),
      fieldErrors: List.unmodifiable(fieldErrors),
      details: Map.unmodifiable(
        _object(json['details'], 'ErrorDetail.details'),
      ),
    );
  }

  final String code;
  final String message;
  final String correlationId;
  final bool retryable;
  final List<ApiFieldError> fieldErrors;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    'correlation_id': correlationId,
    'retryable': retryable,
    'field_errors': fieldErrors
        .map((value) => value.toJson())
        .toList(growable: false),
    'details': details,
  };
}

final class ApiErrorEnvelope {
  const ApiErrorEnvelope({required this.error});

  factory ApiErrorEnvelope.fromJson(Object? value) {
    final json = _object(value, 'ErrorEnvelope');
    return ApiErrorEnvelope(error: ApiErrorDetail.fromJson(json['error']));
  }

  final ApiErrorDetail error;
  Map<String, Object?> toJson() => {'error': error.toJson()};
}

final class PageMetadata {
  const PageMetadata({required this.hasMore, this.nextCursor});

  factory PageMetadata.fromJson(Object? value) {
    final json = _object(value, 'PageMetadata');
    final cursor = json['next_cursor'];
    if (cursor != null && cursor is! String) {
      throw const FormatException(
        'PageMetadata.next_cursor must be a string or null.',
      );
    }
    return PageMetadata(
      hasMore: _boolean(json, 'has_more'),
      nextCursor: cursor as String?,
    );
  }

  final bool hasMore;
  final String? nextCursor;
  Map<String, Object?> toJson() => {
    'next_cursor': nextCursor,
    'has_more': hasMore,
  };
}

final class Money {
  const Money({required this.minorUnits, required this.currency});

  factory Money.fromJson(Object? value) {
    final json = _object(value, 'Money');
    final currency = _string(json, 'currency');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const FormatException('Money.currency is invalid.');
    }
    return Money(minorUnits: _integer(json, 'minor_units'), currency: currency);
  }

  final int minorUnits;
  final String currency;
  Map<String, Object?> toJson() => {
    'minor_units': minorUnits,
    'currency': currency,
  };
}

final class ZonedInstant {
  const ZonedInstant({required this.instant, required this.timezone});

  factory ZonedInstant.fromJson(Object? value) {
    final json = _object(value, 'ZonedInstant');
    final instant = DateTime.tryParse(_string(json, 'instant'));
    if (instant == null) {
      throw const FormatException('ZonedInstant.instant is invalid.');
    }
    return ZonedInstant(
      instant: instant.toUtc(),
      timezone: _string(json, 'timezone'),
    );
  }

  final DateTime instant;
  final String timezone;
  Map<String, Object?> toJson() => {
    'instant': instant.toUtc().toIso8601String(),
    'timezone': timezone,
  };
}

final class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    required this.purpose,
    this.accuracyMetres,
  });

  factory GeoPoint.fromJson(Object? value) {
    final json = _object(value, 'GeoPoint');
    final latitude = _number(json, 'latitude');
    final longitude = _number(json, 'longitude');
    final accuracyValue = json['accuracy_metres'];
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException(
        'GeoPoint coordinates are outside WGS84 bounds.',
      );
    }
    final accuracy = switch (accuracyValue) {
      null => null,
      final num value when value >= 0 => value.toDouble(),
      _ => throw const FormatException('GeoPoint.accuracy_metres is invalid.'),
    };
    final capturedAt = DateTime.tryParse(_string(json, 'captured_at'));
    if (capturedAt == null) {
      throw const FormatException('GeoPoint.captured_at is invalid.');
    }
    return GeoPoint(
      latitude: latitude,
      longitude: longitude,
      accuracyMetres: accuracy,
      capturedAt: capturedAt.toUtc(),
      purpose: GeoPurpose.fromJson(json['purpose']),
    );
  }

  final double latitude;
  final double longitude;
  final double? accuracyMetres;
  final DateTime capturedAt;
  final GeoPurpose purpose;

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_metres': accuracyMetres,
    'captured_at': capturedAt.toUtc().toIso8601String(),
    'purpose': purpose.wireValue,
  };
}

final class IdempotentCommandMetadata {
  const IdempotentCommandMetadata({
    required this.commandId,
    required this.idempotencyKey,
    required this.correlationId,
  });

  factory IdempotentCommandMetadata.fromJson(Object? value) {
    final json = _object(value, 'IdempotentCommandMetadata');
    return IdempotentCommandMetadata(
      commandId: _string(json, 'command_id'),
      idempotencyKey: _string(json, 'idempotency_key'),
      correlationId: _string(json, 'correlation_id'),
    );
  }

  final String commandId;
  final String idempotencyKey;
  final String correlationId;

  Map<String, Object?> toJson() => {
    'command_id': commandId,
    'idempotency_key': idempotencyKey,
    'correlation_id': correlationId,
  };
}

final class HealthResponse {
  const HealthResponse({
    required this.status,
    required this.service,
    required this.version,
  });

  factory HealthResponse.fromJson(Object? value) {
    final json = _object(value, 'HealthResponse');
    return HealthResponse(
      status: HealthStatus.fromJson(json['status']),
      service: _string(json, 'service'),
      version: _string(json, 'version'),
    );
  }

  final HealthStatus status;
  final String service;
  final String version;
  Map<String, Object?> toJson() => {
    'status': status.wireValue,
    'service': service,
    'version': version,
  };
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be a JSON object.');
  }
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('$key must be a string.');
  }
  return value;
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('$key must be a boolean.');
  }
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an integer.');
  }
  return value;
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('$key must be a number.');
  }
  return value.toDouble();
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array.');
  }
  return value;
}

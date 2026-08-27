import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'cancellation.dart';

final class TransportRequest {
  const TransportRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final List<int>? body;
}

final class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;

  String? header(String name) {
    final normalized = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value;
    }
    return null;
  }
}

abstract interface class ApiTransport {
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  });
}

final class IoApiTransport implements ApiTransport {
  IoApiTransport({HttpClient? client, this.maxResponseBytes = 2 << 20})
    : _client = client ?? HttpClient(),
      _ownsClient = client == null {
    if (maxResponseBytes < 1 || maxResponseBytes > 32 << 20) {
      throw const FormatException(
        'maxResponseBytes is outside the safe range.',
      );
    }
  }

  final HttpClient _client;
  final bool _ownsClient;
  final int maxResponseBytes;

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    if (timeout <= Duration.zero ||
        !request.url.isAbsolute ||
        (request.url.scheme != 'http' && request.url.scheme != 'https') ||
        request.url.host.isEmpty ||
        request.url.userInfo.isNotEmpty) {
      throw const FormatException('Transport request is invalid.');
    }
    cancellationToken.throwIfCancelled();
    HttpClientRequest? ioRequest;
    final operation = Completer<TransportResponse>();
    Timer? timeoutTimer;

    void fail(Object error, [StackTrace? stackTrace]) {
      if (operation.isCompleted) return;
      ioRequest?.abort(error, stackTrace);
      operation.completeError(error, stackTrace ?? StackTrace.current);
    }

    timeoutTimer = Timer(
      timeout,
      () => fail(const TransportTimeoutException()),
    );
    final removeCancellationListener = cancellationToken.onCancel(
      () => fail(const TransportCancelledException()),
    );

    unawaited(() async {
      try {
        ioRequest = await _client.openUrl(request.method, request.url);
        if (operation.isCompleted) {
          ioRequest!.abort(const TransportCancelledException());
          return;
        }
        ioRequest!.followRedirects = false;
        request.headers.forEach(ioRequest!.headers.set);
        if (request.body != null) ioRequest!.add(request.body!);
        final response = await ioRequest!.close();
        final body = await _readBoundedBody(
          response,
          maxResponseBytes,
          cancellationToken,
        );
        if (operation.isCompleted) return;
        final headers = <String, String>{};
        response.headers.forEach(
          (name, values) => headers[name] = values.join(','),
        );
        operation.complete(
          TransportResponse(
            statusCode: response.statusCode,
            headers: Map.unmodifiable(headers),
            body: body,
          ),
        );
      } catch (error, stackTrace) {
        fail(error, stackTrace);
      }
    }());

    try {
      return await operation.future;
    } finally {
      timeoutTimer.cancel();
      removeCancellationListener();
    }
  }

  void close({bool force = false}) {
    if (_ownsClient) _client.close(force: force);
  }
}

Future<Uint8List> _readBoundedBody(
  HttpClientResponse response,
  int maxBytes,
  ApiCancellationToken cancellationToken,
) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in response) {
    cancellationToken.throwIfCancelled();
    if (bytes.length + chunk.length > maxBytes) {
      throw const TransportResponseTooLargeException();
    }
    bytes.add(chunk);
  }
  cancellationToken.throwIfCancelled();
  return bytes.takeBytes();
}

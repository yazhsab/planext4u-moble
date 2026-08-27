import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

void main() {
  test('IO transport sends and receives bounded HTTP data', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final captured = Completer<Map<String, Object?>>();
    server.listen((request) async {
      captured.complete({
        'method': request.method,
        'header': request.headers.value('X-Synthetic'),
        'body': await utf8.decoder.bind(request).join(),
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":true}');
      await request.response.close();
    });
    final transport = IoApiTransport();
    addTearDown(() => transport.close(force: true));

    final result = await transport.send(
      TransportRequest(
        method: 'POST',
        url: Uri.parse('http://127.0.0.1:${server.port}/v1/test'),
        headers: const {'X-Synthetic': 'safe'},
        body: utf8.encode('{"fixture":true}'),
      ),
      timeout: const Duration(seconds: 1),
      cancellationToken: ApiCancellationToken(),
    );

    expect(result.statusCode, 200);
    expect(jsonDecode(utf8.decode(result.body)), {'ok': true});
    expect(await captured.future, {
      'method': 'POST',
      'header': 'safe',
      'body': '{"fixture":true}',
    });
  });

  test('IO transport aborts a request at its timeout', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      request.response.write('{}');
      await request.response.close();
    });
    final transport = IoApiTransport();
    addTearDown(() => transport.close(force: true));

    await expectLater(
      transport.send(
        TransportRequest(
          method: 'GET',
          url: Uri.parse('http://127.0.0.1:${server.port}/slow'),
          headers: const {},
          body: null,
        ),
        timeout: const Duration(milliseconds: 20),
        cancellationToken: ApiCancellationToken(),
      ),
      throwsA(isA<TransportTimeoutException>()),
    );
  });

  test('IO transport aborts an actively cancelled request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = Completer<void>();
    server.listen((request) async {
      received.complete();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      request.response.write('{}');
      await request.response.close();
    });
    final transport = IoApiTransport();
    addTearDown(() => transport.close(force: true));
    final cancellation = ApiCancellationToken();
    final future = transport.send(
      TransportRequest(
        method: 'GET',
        url: Uri.parse('http://127.0.0.1:${server.port}/cancel'),
        headers: const {},
        body: null,
      ),
      timeout: const Duration(seconds: 1),
      cancellationToken: cancellation,
    );
    await received.future;
    cancellation.cancel();

    await expectLater(future, throwsA(isA<TransportCancelledException>()));
  });

  test('IO transport rejects an oversized response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write('123456');
      await request.response.close();
    });
    final transport = IoApiTransport(maxResponseBytes: 5);
    addTearDown(() => transport.close(force: true));

    await expectLater(
      transport.send(
        TransportRequest(
          method: 'GET',
          url: Uri.parse('http://127.0.0.1:${server.port}/large'),
          headers: const {},
          body: null,
        ),
        timeout: const Duration(seconds: 1),
        cancellationToken: ApiCancellationToken(),
      ),
      throwsA(isA<TransportResponseTooLargeException>()),
    );
  });

  test('IO transport does not follow redirects', () async {
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => target.close(force: true));
    var targetRequests = 0;
    target.listen((request) async {
      targetRequests++;
      request.response.write('{"unexpected":true}');
      await request.response.close();
    });
    final redirector = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => redirector.close(force: true));
    redirector.listen((request) async {
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        'http://127.0.0.1:${target.port}/different-origin',
      );
      await request.response.close();
    });
    final transport = IoApiTransport();
    addTearDown(() => transport.close(force: true));

    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        url: Uri.parse('http://127.0.0.1:${redirector.port}/redirect'),
        headers: const {},
        body: null,
      ),
      timeout: const Duration(seconds: 1),
      cancellationToken: ApiCancellationToken(),
    );

    expect(response.statusCode, HttpStatus.found);
    expect(targetRequests, 0);
  });
}

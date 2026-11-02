import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

const _id = '30000000-0000-4000-8000-000000000001';
final _now = DateTime.utc(2026, 10, 26);
Map<String, Object?> _waiting() => {
  'attempt_id': _id,
  'application_role': 'VENDOR',
  'status': 'AWAITING_USER',
  'expires_at': _now.add(const Duration(minutes: 10)).toIso8601String(),
  'launch_url': 'https://bank.example.test/hosted?one_time=private',
};

HostedBankLinkClient _client(_Transport transport, {String role = 'vendor'}) =>
    HostedBankLinkClient(
      client: ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        transport: transport,
        authSession: _Session(),
        retryBudget: const ApiRetryBudget(maxAttempts: 1),
      ),
      applicationRole: role,
      allowedOrigins: {Uri.parse('https://bank.example.test')},
      clock: () => _now,
    );

void main() {
  test(
    'bank commands bind the role, use empty bodies and retain idempotency on retry',
    () async {
      final transport = _Transport(_waiting()), client = _client(transport);
      expect((await client.start()).launchUrl?.host, 'bank.example.test');
      expect((await client.resume(_id)).attemptId, _id);
      transport.value = {..._waiting(), 'status': 'CANCELLED'}
        ..remove('launch_url');
      expect((await client.cancel(_id)).status, 'CANCELLED');
      expect(transport.requests.map((r) => r.url.path), [
        '/v1/vendor/bank-links',
        '/v1/vendor/bank-links/$_id/resume',
        '/v1/vendor/bank-links/$_id',
      ]);
      expect(transport.requests.map((r) => r.method), [
        'POST',
        'POST',
        'DELETE',
      ]);
      expect(
        transport.requests.take(2).map((r) => jsonDecode(utf8.decode(r.body!))),
        [<String, Object?>{}, <String, Object?>{}],
      );
      expect(transport.requests.every((r) => !r.url.hasQuery), isTrue);
      expect(
        transport.requests.every(
          (r) => r.headers['Authorization'] == 'Bearer synthetic-token',
        ),
        isTrue,
      );
      expect(
        transport.requests.every(
          (r) => IdempotencyKey.isValid(r.headers['Idempotency-Key']!),
        ),
        isTrue,
      );
    },
  );
  test(
    'current can omit a hosted URL and only a specific not-found means no attempt',
    () async {
      final transport = _Transport(_waiting()..remove('launch_url')),
          client = _client(transport);
      expect((await client.current())?.status, 'AWAITING_USER');
      transport.status = 404;
      transport.value = _error('BANK_LINK_NOT_FOUND');
      expect(await client.current(), isNull);
      transport.value = _error('OTHER_RESOURCE_NOT_FOUND');
      await expectLater(client.current(), throwsA(isA<ApiFailure>()));
    },
  );
  test(
    'verified results contain only validated masked details and no hosted capability',
    () async {
      final transport = _Transport(
        {
          ..._waiting(),
          'status': 'VERIFIED',
          'account': {
            'reference': 'bankref_synthetic1234',
            'holder_name': 'Synthetic Owner',
            'last4': '1234',
            'ifsc': 'TEST0123456',
          },
        }..remove('launch_url'),
      );
      final result = await _client(transport).resume(_id);
      expect(result.account?.last4, '1234');
      expect(result.launchUrl, isNull);
    },
  );
  for (final entry in <String, void Function(Map<String, Object?>)>{
    'wrong role': (v) => v['application_role'] = 'RIDER',
    'wrong attempt': (v) =>
        v['attempt_id'] = '30000000-0000-4000-8000-000000000002',
    'raw account': (v) => v['account_number'] = '123456789012',
    'pending account': (v) =>
        v['account'] = {'reference': 'bankref_synthetic1234'},
    'unknown status': (v) => v['status'] = 'APPROVED',
    'expired': (v) => v['expires_at'] = _now.toIso8601String(),
    'unbounded expiry': (v) =>
        v['expires_at'] = _now.add(const Duration(hours: 1)).toIso8601String(),
    'wrong origin': (v) =>
        v['launch_url'] = 'https://bank.example.test.evil.test/hosted',
    'userinfo': (v) =>
        v['launch_url'] = 'https://secret@bank.example.test/hosted',
    'fragment': (v) =>
        v['launch_url'] = 'https://bank.example.test/hosted#secret',
    'insecure launch': (v) =>
        v['launch_url'] = 'http://bank.example.test/hosted',
    'port change': (v) =>
        v['launch_url'] = 'https://bank.example.test:444/hosted',
    'missing URL': (v) => v.remove('launch_url'),
    'verified without mask': (v) {
      v['status'] = 'VERIFIED';
      v.remove('launch_url');
    },
    'nonmasked account': (v) {
      v['status'] = 'VERIFIED';
      v.remove('launch_url');
      v['account'] = {
        'reference': 'bankref_synthetic1234',
        'holder_name': 'Synthetic Owner',
        'last4': '123456789012',
      };
    },
  }.entries) {
    test('bank response rejects ${entry.key}', () async {
      final value = _waiting();
      entry.value(value);
      await expectLater(
        _client(_Transport(value)).resume(_id),
        throwsA(isA<ApiContractFailure>()),
      );
    });
  }
  test(
    'disposing account scope rejects late bank results and further commands',
    () async {
      final gate = Completer<void>(),
          transport = _Transport(_waiting())..gate = gate;
      final client = _client(transport);
      final pending = client.start();
      await transport.started.future;
      client.dispose();
      gate.complete();
      await expectLater(
        pending,
        throwsA(
          anyOf(
            isA<ApiCancellationFailure>(),
            isA<TransportCancelledException>(),
          ),
        ),
      );
      await expectLater(
        client.start(),
        throwsA(isA<TransportCancelledException>()),
      );
      expect(client.isActive, isFalse);
    },
  );
  test(
    'bank role, origin and path identifiers fail before transport',
    () async {
      final transport = _Transport(_waiting()), client = _client(transport);
      expect(() => _client(transport, role: 'admin'), throwsFormatException);
      expect(
        () => HostedBankLinkClient(
          client: ApiClient(
            baseUrl: Uri.parse('https://api.example.test'),
            transport: transport,
          ),
          applicationRole: 'vendor',
          allowedOrigins: {Uri.parse('https://bank.example.test/path')},
        ),
        throwsFormatException,
      );
      expect(() => client.resume('../other'), throwsFormatException);
      expect(transport.requests, isEmpty);
    },
  );
}

Map<String, Object?> _error(String code) => {
  'error': {
    'code': code,
    'message': 'Synthetic bank failure',
    'correlation_id': 'bank-test-correlation',
    'retryable': false,
    'field_errors': <Object?>[],
    'details': <String, Object?>{},
  },
};

final class _Session implements ApiAuthSession {
  @override
  Future<String?> accessToken() async => 'synthetic-token';
  @override
  Future<bool> refresh() async => false;
}

final class _Transport implements ApiTransport {
  _Transport(this.value);
  Object? value;
  int status = 200;
  Completer<void>? gate;
  final started = Completer<void>();
  final requests = <TransportRequest>[];
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    if (!started.isCompleted) started.complete();
    await gate?.future;
    return TransportResponse(
      statusCode: status,
      headers: const {'content-type': 'application/json'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(value))),
    );
  }
}

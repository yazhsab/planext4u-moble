import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

final class _Session implements ApiAuthSession {
  @override
  Future<String?> accessToken() async => 'synthetic-owner';
  @override
  Future<bool> refresh() async => false;
}

final class _Transport implements ApiTransport {
  Object? response = {
    'status': 'EMPTY',
    'policy_version': 'contacts-v1',
    'revision': 0,
    'contact_count': 0,
    'max_contacts': 100,
  };
  Completer<void>? gate;
  final requests = <TransportRequest>[];
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    await gate?.future;
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(response))),
    );
  }
}

ContactMatchingApi _api(_Transport transport) => ContactMatchingApi(
  ApiClient(
    baseUrl: Uri.parse('https://api.example.test'),
    transport: transport,
    authSession: _Session(),
    retryBudget: const ApiRetryBudget(maxAttempts: 1),
  ),
);

void main() {
  test(
    'contact requests use only current owner routes and bounded bodies',
    () async {
      final transport = _Transport();
      final api = _api(transport);
      expect((await api.state()).revision, 0);
      transport.response = {
        'status': 'READY',
        'policy_version': 'contacts-v1',
        'revision': 1,
        'contact_count': 1,
        'max_contacts': 100,
        'expires_at': DateTime.utc(2026, 10, 27).toIso8601String(),
      };
      expect(
        (await api.sync(
          providerToken: 'provider-private-token',
          policyVersion: 'contacts-v1',
          expectedRevision: 0,
          phones: const ['+919876543210'],
        )).ready,
        isTrue,
      );
      transport.response = {
        'snapshot_revision': 1,
        'items': [
          {'identity_id': 'member-1', 'display_name': 'Member'},
        ],
        'next_cursor': 'member-1',
      };
      final page = await api.matches(revision: 1);
      expect(page.items.single.identityId, 'member-1');
      expect(transport.requests.map((request) => request.url.path), [
        '/v1/me/contact-matching',
        '/v1/me/contact-matching',
        '/v1/me/contact-matching/matches',
      ]);
      expect(transport.requests[0].url.hasQuery, isFalse);
      expect(transport.requests[1].url.hasQuery, isFalse);
      expect(transport.requests[2].url.queryParameters, {
        'revision': '1',
        'limit': '50',
      });
      final body = jsonDecode(utf8.decode(transport.requests[1].body!)) as Map;
      expect(body.keys.toSet(), {
        'provider_token',
        'policy_version',
        'expected_revision',
        'phones',
      });
      expect(body['phones'], ['+919876543210']);
      expect(
        transport.requests.every(
          (request) =>
              request.headers['Authorization'] == 'Bearer synthetic-owner',
        ),
        isTrue,
      );
      expect(
        () => api.sync(
          providerToken: 'provider-private-token',
          policyVersion: 'contacts-v1',
          expectedRevision: 0,
          phones: const ['9876543210'],
        ),
        throwsFormatException,
      );
      await expectLater(
        api.matches(revision: 1, limit: 51),
        throwsFormatException,
      );
      api.dispose();
    },
  );

  test(
    'malformed rows, raw contact fields and late results are rejected',
    () async {
      final transport = _Transport();
      final api = _api(transport);
      for (final unsafe in [
        {
          'snapshot_revision': 1,
          'items': [
            {
              'identity_id': 'member',
              'display_name': 'Member',
              'phone': '+919876543210',
            },
          ],
        },
        {'snapshot_revision': 1, 'items': const [], 'next_cursor': '../other'},
      ]) {
        transport.response = unsafe;
        await expectLater(
          api.matches(revision: 1),
          throwsA(isA<ApiContractFailure>()),
        );
      }
      transport.response = {'snapshot_revision': 2, 'items': const []};
      await expectLater(api.matches(revision: 1), throwsFormatException);
      transport.response = {
        'status': 'READY',
        'policy_version': 'contacts-v1',
        'revision': 1,
        'contact_count': 0,
        'max_contacts': 100,
        'expires_at': DateTime.utc(2026, 10, 27).toIso8601String(),
      };
      transport.gate = Completer<void>();
      final pending = api.state();
      await Future<void>.delayed(Duration.zero);
      api.dispose();
      transport.gate!.complete();
      await expectLater(pending, throwsA(anything));
    },
  );
}

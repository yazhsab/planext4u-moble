import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

void main() {
  test(
    'identity exchange follows the backend contract and never replays',
    () async {
      final transport = CapturingTransport(authenticationJson());
      final api = IdentityApi(
        ApiClient(
          baseUrl: Uri.parse('https://api.example.test'),
          transport: transport,
          correlationIdFactory: () => 'corr-identity-001',
        ),
      );

      final result = await api.exchange(
        assertion: ProviderAssertion(
          provider: IdentityProviderKind.firebase,
          token: 'provider-token-secret',
        ),
        deviceId: 'device-001',
        country: 'IN',
      );

      expect(result.identityId, 'identity-1');
      expect(transport.request!.url.path, '/v1/auth/exchange');
      expect(transport.request!.headers, isNot(contains('Authorization')));
      expect(jsonDecode(utf8.decode(transport.request!.body!)), {
        'provider': 'firebase',
        'provider_token': 'provider-token-secret',
        'device_id': 'device-001',
        'country': 'IN',
      });
    },
  );

  test('204 revoke decodes safely', () async {
    final transport = CapturingTransport(null, statusCode: 204);
    final api = IdentityApi(
      ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        transport: transport,
        correlationIdFactory: () => 'corr-identity-002',
      ),
    );

    await api.revoke('refresh-token-00000000000000000000000000000001');

    expect(transport.request!.url.path, '/v1/auth/revoke');
  });
}

final class CapturingTransport implements ApiTransport {
  CapturingTransport(this.responseBody, {this.statusCode = 201});
  final Object? responseBody;
  final int statusCode;
  TransportRequest? request;

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    this.request = request;
    return TransportResponse(
      statusCode: statusCode,
      headers: {'X-Correlation-ID': 'corr-server-identity'},
      body: Uint8List.fromList(
        responseBody == null ? const [] : utf8.encode(jsonEncode(responseBody)),
      ),
    );
  }
}

Map<String, Object?> authenticationJson() => {
  'identity_id': 'identity-1',
  'tenant_id': 'tenant-1',
  'country': 'IN',
  'tokens': {
    'access_token': 'access-token',
    'access_expires_at': '2026-08-27T10:10:00Z',
    'refresh_token': 'refresh-token-00000000000000000000000000000001',
    'refresh_expires_at': '2026-09-27T10:00:00Z',
    'token_type': 'Bearer',
  },
  'profile': {
    'display_name': 'Synthetic Customer',
    'locale': 'en',
    'time_zone': 'Asia/Kolkata',
    'version': 1,
    'updated_at': '2026-08-27T10:00:00Z',
  },
  'roles': ['CUSTOMER'],
  'session': {
    'id': 'session-1',
    'device_reference': 'device-hash-1',
    'country': 'IN',
    'authenticated_at': '2026-08-27T10:00:00Z',
    'last_seen_at': '2026-08-27T10:00:00Z',
    'expires_at': '2026-09-27T10:00:00Z',
    'current': true,
  },
};

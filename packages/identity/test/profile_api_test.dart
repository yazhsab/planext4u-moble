import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

void main() {
  for (final role in const {
    'CUSTOMER': AppRole.customer,
    'VENDOR': AppRole.vendor,
    'RIDER': AppRole.rider,
  }.entries) {
    test(
      '${role.key.toLowerCase()} owns a revision-safe profile client',
      () async {
        final transport = _ProfileTransport([
          _currentProfile(role.key),
          _profile(version: 2, displayName: '${role.key} Updated'),
        ]);
        final api = IdentityProfileApi(
          ApiClient(
            baseUrl: Uri.parse('https://api.example.test'),
            transport: transport,
            authSession: const _StaticAuthSession(),
            correlationIdFactory: () =>
                'corr-profile-${role.key.toLowerCase()}',
          ),
        );

        final current = await api.current();
        final updated = await api.update(
          current: current.profile,
          displayName: '${role.key} Updated',
          locale: 'en',
          timeZone: 'Asia/Kolkata',
        );

        expect(current.roles, {role.value});
        expect(current.profile.email, 'profile@example.test');
        expect(current.profile.phone, '+919876543210');
        expect(updated.version, 2);
        expect(transport.requests[0].method, 'GET');
        expect(transport.requests[0].url.path, '/v1/me');
        expect(transport.requests[1].method, 'PATCH');
        expect(transport.requests[1].headers['If-Match'], '"1"');
        expect(jsonDecode(utf8.decode(transport.requests[1].body!)), {
          'display_name': '${role.key} Updated',
          'locale': 'en',
          'time_zone': 'Asia/Kolkata',
        });
      },
    );
  }

  test('identity profile accepts exactly the nine platform locales', () {
    for (final locale in planext4uSupportedLocaleCodes) {
      expect(
        IdentityProfile.fromJson({
          ..._profile(version: 1, displayName: 'Profile'),
          'locale': locale,
        }).locale,
        locale,
      );
    }
    expect(
      () => IdentityProfile.fromJson({
        ..._profile(version: 1, displayName: 'Profile'),
        'locale': 'fr',
      }),
      throwsFormatException,
    );
  });

  test('identity profile update accepts every platform locale', () async {
    for (final locale in planext4uSupportedLocaleCodes) {
      final transport = _ProfileTransport([
        {..._profile(version: 2, displayName: 'Updated'), 'locale': locale},
      ]);
      final api = IdentityProfileApi(
        ApiClient(
          baseUrl: Uri.parse('https://api.example.test'),
          transport: transport,
          authSession: const _StaticAuthSession(),
          correlationIdFactory: () => 'corr-profile-locale-$locale',
        ),
      );

      final updated = await api.update(
        current: IdentityProfile.fromJson(
          _profile(version: 1, displayName: 'Profile'),
        ),
        displayName: 'Updated',
        locale: locale,
        timeZone: 'Asia/Kolkata',
      );

      expect(updated.locale, locale);
    }
  });
}

final class _StaticAuthSession implements ApiAuthSession {
  const _StaticAuthSession();

  @override
  Future<String?> accessToken() async => 'access-token-profile-test';

  @override
  Future<bool> refresh() async => false;
}

final class _ProfileTransport implements ApiTransport {
  _ProfileTransport(this.responses);

  final List<Object?> responses;
  final List<TransportRequest> requests = [];

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: {'X-Correlation-ID': 'corr-profile-server'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(responses.removeAt(0)))),
    );
  }
}

Map<String, Object?> _currentProfile(String role) => {
  'id': 'identity-${role.toLowerCase()}',
  'tenant_id': 'tenant-1',
  'country': 'IN',
  'roles': [role],
  'profile': _profile(version: 1, displayName: role),
};

Map<String, Object?> _profile({
  required int version,
  required String displayName,
}) => {
  'display_name': displayName,
  'email': 'profile@example.test',
  'phone': '+919876543210',
  'locale': 'en',
  'time_zone': 'Asia/Kolkata',
  'version': version,
  'updated_at': '2026-09-01T10:00:00Z',
};

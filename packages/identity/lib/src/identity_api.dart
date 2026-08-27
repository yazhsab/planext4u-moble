import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'identity_models.dart';

abstract interface class IdentityRemote {
  Future<IdentityAuthentication> exchange({
    required ProviderAssertion assertion,
    required String deviceId,
    required String country,
  });

  Future<IdentityAuthentication> refresh(String refreshToken);

  Future<void> revoke(String refreshToken);
}

final class IdentityApi implements IdentityRemote {
  const IdentityApi(this._client);

  final ApiClient _client;

  @override
  Future<IdentityAuthentication> exchange({
    required ProviderAssertion assertion,
    required String deviceId,
    required String country,
  }) async {
    _validateDevice(deviceId, country);
    final response = await _client.send(
      ApiRequest(
        operation: 'identity.exchange_provider_token',
        method: 'POST',
        path: '/v1/auth/exchange',
        body: {
          'provider': assertion.provider.wireValue,
          'provider_token': assertion.token,
          'device_id': deviceId,
          'country': country,
        },
        authRequired: false,
        replayPolicy: ApiReplayPolicy.never,
      ),
      IdentityAuthentication.fromJson,
    );
    return response.value;
  }

  @override
  Future<IdentityAuthentication> refresh(String refreshToken) async {
    _validateRefreshToken(refreshToken);
    final response = await _client.send(
      ApiRequest(
        operation: 'identity.refresh_session',
        method: 'POST',
        path: '/v1/auth/refresh',
        body: {'refresh_token': refreshToken},
        authRequired: false,
        replayPolicy: ApiReplayPolicy.never,
      ),
      IdentityAuthentication.fromJson,
    );
    return response.value;
  }

  @override
  Future<void> revoke(String refreshToken) async {
    _validateRefreshToken(refreshToken);
    await _client.send(
      ApiRequest(
        operation: 'identity.revoke_by_refresh_token',
        method: 'POST',
        path: '/v1/auth/revoke',
        body: {'refresh_token': refreshToken},
        authRequired: false,
        replayPolicy: ApiReplayPolicy.never,
      ),
      (_) {},
    );
  }
}

void _validateDevice(String deviceId, String country) {
  if (deviceId.isEmpty ||
      deviceId.length > 128 ||
      !RegExp(r'^[!-~]+$').hasMatch(deviceId) ||
      !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
    throw const FormatException('Device exchange metadata is invalid.');
  }
}

void _validateRefreshToken(String token) {
  if (token.length < 8 || token.length > 128) {
    throw const FormatException('Refresh token is invalid.');
  }
}

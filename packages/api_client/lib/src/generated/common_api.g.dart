// Code generated from common.openapi.json (332ef63e39ef8f7e4dc13a25709b697f288fbb66061f29f73ecf0ee7a8db4b0f); DO NOT EDIT.

import '../client.dart';
import '../request.dart';
import 'common_models.g.dart';

final class CommonApi {
  const CommonApi(this._client);

  final ApiClient _client;

  Future<ApiResponse<HealthResponse>> getHealth() => _client.send(
    ApiRequest.get(
      operation: 'common.get_liveness',
      path: '/healthz',
      authRequired: false,
    ),
    HealthResponse.fromJson,
  );

  Future<ApiResponse<HealthResponse>> getReadiness() => _client.send(
    ApiRequest.get(
      operation: 'common.get_readiness',
      path: '/readyz',
      authRequired: false,
    ),
    HealthResponse.fromJson,
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_api_client/src/generated/contract_fixture.g.dart';

void main() {
  test('backend problem fixture decodes through generated models', () {
    final envelope = ApiErrorEnvelope.fromJson(jsonDecode(problemFixtureJson));

    expect(envelope.error.code, 'LOCATION_NOT_SERVICEABLE');
    expect(envelope.error.correlationId, 'corr-synthetic-001');
    expect(envelope.error.retryable, isFalse);
    expect(envelope.error.fieldErrors, hasLength(1));
    expect(envelope.error.fieldErrors.single.field, 'location_id');
    expect(envelope.toJson()['error'], isA<Map<String, Object?>>());
  });

  test('generated enums tolerate additive unknown values', () {
    expect(ApiAppRole.fromJson('FUTURE_ROLE'), ApiAppRole.unknown);
    expect(GeoPurpose.fromJson('FUTURE_PURPOSE'), GeoPurpose.unknown);
    expect(HealthStatus.fromJson('degraded'), HealthStatus.unknown);
  });

  test('generated value models validate contract constraints', () {
    expect(
      Money.fromJson({'minor_units': 124900, 'currency': 'INR'}).toJson(),
      {'minor_units': 124900, 'currency': 'INR'},
    );
    expect(
      () => Money.fromJson({'minor_units': 12.5, 'currency': 'INR'}),
      throwsFormatException,
    );
    expect(
      () => GeoPoint.fromJson({
        'latitude': 100,
        'longitude': 80,
        'captured_at': '2026-08-27T00:00:00Z',
        'purpose': 'SERVICEABILITY',
      }),
      throwsFormatException,
    );
  });

  test('generated models tolerate unknown additive object properties', () {
    final response = HealthResponse.fromJson({
      'status': 'ready',
      'service': 'gateway',
      'version': 'synthetic',
      'future_optional_property': true,
    });
    expect(response.status, HealthStatus.ready);
  });

  test('support contract snapshot contains every role-owned operation', () {
    final packageContract = File('contracts/support.openapi.json');
    final repositoryContract = File(
      'packages/api_client/contracts/support.openapi.json',
    );
    final contract =
        jsonDecode(
              (packageContract.existsSync()
                      ? packageContract
                      : repositoryContract)
                  .readAsStringSync(),
            )
            as Map<String, Object?>;
    final paths = contract['paths']! as Map<String, Object?>;
    expect(
      paths.keys,
      containsAll({
        '/v1/support/tickets',
        '/v1/support/tickets/{ticket_id}',
        '/v1/support/tickets/{ticket_id}/messages',
      }),
    );
  });

  test('fulfillment contract contains the rider offer decline operation', () {
    final packageContract = File('contracts/fulfillment.openapi.json');
    final repositoryContract = File(
      'packages/api_client/contracts/fulfillment.openapi.json',
    );
    final contract =
        jsonDecode(
              (packageContract.existsSync()
                      ? packageContract
                      : repositoryContract)
                  .readAsStringSync(),
            )
            as Map<String, Object?>;
    final paths = contract['paths']! as Map<String, Object?>;
    final decline =
        paths['/v1/rider/offers/{offer_id}/decline']! as Map<String, Object?>;
    final post = decline['post']! as Map<String, Object?>;
    final responses = post['responses']! as Map<String, Object?>;
    expect(responses['201'], isA<Map<String, Object?>>());
  });

  test('emergency contract contains the on-duty rider incident operations', () {
    final packageContract = File('contracts/emergency.openapi.json');
    final repositoryContract = File(
      'packages/api_client/contracts/emergency.openapi.json',
    );
    final contract =
        jsonDecode(
              (packageContract.existsSync()
                      ? packageContract
                      : repositoryContract)
                  .readAsStringSync(),
            )
            as Map<String, Object?>;
    final paths = contract['paths']! as Map<String, Object?>;
    expect(
      paths.keys,
      containsAll({
        '/v1/rider/emergency-incidents',
        '/v1/rider/emergency-incidents/{incident_id}',
        '/v1/rider/emergency-incidents/{incident_id}/location',
      }),
    );
    final create =
        paths['/v1/rider/emergency-incidents']! as Map<String, Object?>;
    final post = create['post']! as Map<String, Object?>;
    expect(post['requestBody'], isA<Map<String, Object?>>());
    expect(post['x-planext4u-on-duty-required'], isTrue);
  });

  test(
    'identity contract keeps guest sessions access-only and BFF-internal',
    () {
      final packageContract = File('contracts/identity.openapi.json');
      final repositoryContract = File(
        'packages/api_client/contracts/identity.openapi.json',
      );
      final contract =
          jsonDecode(
                (packageContract.existsSync()
                        ? packageContract
                        : repositoryContract)
                    .readAsStringSync(),
              )
              as Map<String, Object?>;
      final paths = contract['paths']! as Map<String, Object?>;
      final route =
          paths['/internal/v1/customer-guest-sessions']!
              as Map<String, Object?>;
      final post = route['post']! as Map<String, Object?>;
      expect(post['x-planext4u-session-class'], 'ephemeral-access-only');
      expect(
        post['x-planext4u-guest-capability'],
        'GET storefront allowlist only',
      );

      final components = contract['components']! as Map<String, Object?>;
      final schemas = components['schemas']! as Map<String, Object?>;
      final guest = schemas['GuestSession']! as Map<String, Object?>;
      final properties = guest['properties']! as Map<String, Object?>;
      expect(properties, isNot(contains('refresh_token')));
    },
  );

  test('configuration contract defines WEB bootstrap reload semantics', () {
    final packageContract = File('contracts/configuration.openapi.json');
    final repositoryContract = File(
      'packages/api_client/contracts/configuration.openapi.json',
    );
    final contract =
        jsonDecode(
              (packageContract.existsSync()
                      ? packageContract
                      : repositoryContract)
                  .readAsStringSync(),
            )
            as Map<String, Object?>;
    final components = contract['components']! as Map<String, Object?>;
    final schemas = components['schemas']! as Map<String, Object?>;
    final platform = schemas['Platform']! as Map<String, Object?>;
    final updateAction = schemas['UpdateAction']! as Map<String, Object?>;
    expect(platform['enum'], contains('WEB'));
    expect(updateAction['enum'], contains('RELOAD'));

    final paths = contract['paths']! as Map<String, Object?>;
    final bootstrap = paths['/v1/bootstrap']! as Map<String, Object?>;
    final get = bootstrap['get']! as Map<String, Object?>;
    final parameters = get['parameters']! as List<Object?>;
    final deployment = parameters.cast<Map<String, Object?>>().singleWhere(
      (parameter) => parameter['name'] == 'deployment_id',
    );
    expect(deployment['x-planext4u-required-for-platforms'], contains('WEB'));

    final response = schemas['Bootstrap']! as Map<String, Object?>;
    final properties = response['properties']! as Map<String, Object?>;
    expect(
      properties.keys,
      containsAll({
        'platform',
        'client_version',
        'update_gate',
        'update_action',
        'client_deployment_id',
        'latest_deployment_id',
      }),
    );
  });

  test('catalog contract defines typed browser and mobile presentations', () {
    final packageContract = File('contracts/catalog.openapi.json');
    final repositoryContract = File(
      'packages/api_client/contracts/catalog.openapi.json',
    );
    final contract =
        jsonDecode(
              (packageContract.existsSync()
                      ? packageContract
                      : repositoryContract)
                  .readAsStringSync(),
            )
            as Map<String, Object?>;
    final components = contract['components']! as Map<String, Object?>;
    final schemas = components['schemas']! as Map<String, Object?>;
    final presentation = schemas['MediaPresentation']! as Map<String, Object?>;
    final required = (presentation['required']! as List<Object?>)
        .cast<String>();
    expect(
      required,
      containsAll({
        'asset_id',
        'url',
        'content_type',
        'width',
        'height',
        'alt_text',
        'variants',
        'expires_at',
      }),
    );
    final properties = presentation['properties']! as Map<String, Object?>;
    final url = properties['url']! as Map<String, Object?>;
    expect(url['x-planext4u-url-policy'], 'HTTPS or same-origin path');
  });

  test('catalog contract defines CMS service collections and postal scope', () {
    final packageContract = File('contracts/catalog.openapi.json');
    final repositoryContract = File(
      'packages/api_client/contracts/catalog.openapi.json',
    );
    final contract =
        jsonDecode(
              (packageContract.existsSync()
                      ? packageContract
                      : repositoryContract)
                  .readAsStringSync(),
            )
            as Map<String, Object?>;
    final paths = contract['paths']! as Map<String, Object?>;
    final home = paths['/v1/home']! as Map<String, Object?>;
    final get = home['get']! as Map<String, Object?>;
    final parameters = get['parameters']! as List<Object?>;
    expect(
      parameters.whereType<Map<String, Object?>>(),
      contains(
        predicate<Map<String, Object?>>(
          (value) => value['name'] == 'postal_code' && value['in'] == 'query',
        ),
      ),
    );

    final components = contract['components']! as Map<String, Object?>;
    final schemas = components['schemas']! as Map<String, Object?>;
    expect(
      schemas.keys,
      containsAll({
        'ServiceTrustSummary',
        'ServiceCollectionItem',
        'ServiceCollection',
      }),
    );
    final homeSchema = schemas['Home']! as Map<String, Object?>;
    final homeProperties = homeSchema['properties']! as Map<String, Object?>;
    expect(homeProperties, contains('service_collections'));
    final item = schemas['ServiceCollectionItem']! as Map<String, Object?>;
    final properties = item['properties']! as Map<String, Object?>;
    expect(
      (properties['price_display']! as Map<String, Object?>)['description'],
      'Server-owned localized price display',
    );
  });

  test('media contract exposes public presentation resolution', () {
    final packageContract = File('contracts/media.openapi.json');
    final repositoryContract = File(
      'packages/api_client/contracts/media.openapi.json',
    );
    final contract =
        jsonDecode(
              (packageContract.existsSync()
                      ? packageContract
                      : repositoryContract)
                  .readAsStringSync(),
            )
            as Map<String, Object?>;
    final paths = contract['paths']! as Map<String, Object?>;
    expect(paths, contains('/v1/media/presentations:resolve'));
    final components = contract['components']! as Map<String, Object?>;
    final schemas = components['schemas']! as Map<String, Object?>;
    expect(schemas, contains('MediaPresentation'));
    expect(schemas, contains('PresentationResponse'));
  });

  test('social commands publish typed or intentional bodyless contracts', () {
    final packageContract = File('contracts/social.openapi.json');
    final repositoryContract = File(
      'packages/api_client/contracts/social.openapi.json',
    );
    final contract =
        jsonDecode(
              (packageContract.existsSync()
                      ? packageContract
                      : repositoryContract)
                  .readAsStringSync(),
            )
            as Map<String, Object?>;
    final paths = contract['paths']! as Map<String, Object?>;
    const allowedBodylessOperations = {
      'acceptSocialConversation',
      'acceptSocialFollow',
      'appealSocialMedia',
      'followSocialProfile',
      'purgeSocialRetention',
    };
    var typedCommands = 0;
    final bodylessOperations = <String>{};

    for (final pathItem in paths.values.whereType<Map<String, Object?>>()) {
      for (final method in const ['post', 'put', 'patch']) {
        final operation = pathItem[method];
        if (operation is! Map<String, Object?>) {
          continue;
        }
        final operationId = operation['operationId']! as String;
        final requestBody = operation['requestBody'];
        final intentionalBodyless =
            operation['x-planext4u-bodyless-command'] == true;

        expect(
          requestBody != null || intentionalBodyless,
          isTrue,
          reason: '$operationId must declare a request body or bodyless intent',
        );
        expect(
          requestBody != null && intentionalBodyless,
          isFalse,
          reason: '$operationId cannot declare both command styles',
        );

        if (intentionalBodyless) {
          bodylessOperations.add(operationId);
          continue;
        }

        final body = requestBody! as Map<String, Object?>;
        expect(body['required'], isTrue, reason: operationId);
        final content = body['content']! as Map<String, Object?>;
        final jsonContent =
            content['application/json']! as Map<String, Object?>;
        final schema = jsonContent['schema']! as Map<String, Object?>;
        expect(schema[r'$ref'], startsWith('#/components/schemas/'));
        typedCommands += 1;
      }
    }

    expect(typedCommands, 20);
    expect(bodylessOperations, allowedBodylessOperations);
  });

  test('social discovery and profile content reads are cursor bounded', () {
    final contract = _readContract('social.openapi.json');
    final paths = contract['paths']! as Map<String, Object?>;
    expect(paths, contains('/v1/social/profile-handles/{handle}'));
    expect(paths, contains('/v1/social/profiles/{profile_id}/content'));

    for (final path in const [
      '/v1/social/posts/{post_id}/comments',
      '/v1/social/ephemeral',
      '/v1/social/conversations',
      '/v1/social/conversations/{conversation_id}/messages',
    ]) {
      final pathItem = paths[path]! as Map<String, Object?>;
      final get = pathItem['get']! as Map<String, Object?>;
      final parameters = (get['parameters']! as List<Object?>)
          .whereType<Map<String, Object?>>()
          .map((parameter) => parameter[r'$ref'])
          .toSet();
      expect(
        parameters,
        containsAll({
          '#/components/parameters/ListCursor',
          '#/components/parameters/ListLimit',
        }),
        reason: path,
      );
    }

    final components = contract['components']! as Map<String, Object?>;
    final schemas = components['schemas']! as Map<String, Object?>;
    final ephemeral = schemas['SocialEphemeral']! as Map<String, Object?>;
    final properties = ephemeral['properties']! as Map<String, Object?>;
    expect(properties, contains('media_asset_id'));
  });

  test('supply commands publish typed bodies and concurrency headers', () {
    final contract = _readContract('supply.openapi.json');
    final paths = contract['paths']! as Map<String, Object?>;
    var typedCommands = 0;

    for (final pathItem in paths.values.whereType<Map<String, Object?>>()) {
      for (final method in const ['post', 'put', 'patch']) {
        final operation = pathItem[method];
        if (operation is! Map<String, Object?>) continue;
        final operationId = operation['operationId']! as String;
        final requestBody = operation['requestBody']! as Map<String, Object?>;
        expect(requestBody['required'], isTrue, reason: operationId);
        final content = requestBody['content']! as Map<String, Object?>;
        final jsonContent =
            content['application/json']! as Map<String, Object?>;
        final schema = jsonContent['schema']! as Map<String, Object?>;
        expect(schema[r'$ref'], startsWith('#/components/schemas/'));
        final parameters =
            (operation['parameters'] as List<Object?>? ?? const [])
                .whereType<Map<String, Object?>>();
        expect(
          parameters.any(
            (parameter) =>
                parameter[r'$ref'] == '#/components/parameters/IdempotencyKey',
          ),
          isTrue,
          reason: '$operationId must require an idempotency key',
        );
        typedCommands += 1;
      }
    }

    expect(typedCommands, 15);
  });

  test('rider commands publish typed or intentional bodyless contracts', () {
    final contract = _readContract('fulfillment.openapi.json');
    final paths = contract['paths']! as Map<String, Object?>;
    const allowedBodylessOperations = {
      'acceptRiderOffer',
      'endRiderDuty',
      'markRiderPickup',
    };
    var typedCommands = 0;
    final bodylessOperations = <String>{};

    for (final entry in paths.entries) {
      if (!entry.key.startsWith('/v1/rider/')) continue;
      final pathItem = entry.value as Map<String, Object?>;
      final operation = pathItem['post'];
      if (operation is! Map<String, Object?>) continue;
      final operationId = operation['operationId']! as String;
      final requestBody = operation['requestBody'];
      final intentionalBodyless =
          operation['x-planext4u-bodyless-command'] == true;
      expect(
        requestBody != null || intentionalBodyless,
        isTrue,
        reason: operationId,
      );
      expect(requestBody != null && intentionalBodyless, isFalse);
      if (intentionalBodyless) {
        bodylessOperations.add(operationId);
      } else {
        final body = requestBody! as Map<String, Object?>;
        expect(body['required'], isTrue, reason: operationId);
        final content = body['content']! as Map<String, Object?>;
        final jsonContent =
            content['application/json']! as Map<String, Object?>;
        final schema = jsonContent['schema']! as Map<String, Object?>;
        expect(schema[r'$ref'], startsWith('#/components/schemas/'));
        typedCommands += 1;
      }
    }

    expect(typedCommands, 7);
    expect(bodylessOperations, allowedBodylessOperations);
  });

  test('local verticals expose bounded safe reads and typed commands', () {
    final packageContract = File('contracts/local_verticals.openapi.json');
    final repositoryContract = File(
      'packages/api_client/contracts/local_verticals.openapi.json',
    );
    final contract =
        jsonDecode(
              (packageContract.existsSync()
                      ? packageContract
                      : repositoryContract)
                  .readAsStringSync(),
            )
            as Map<String, Object?>;
    final paths = contract['paths']! as Map<String, Object?>;
    final components = contract['components']! as Map<String, Object?>;
    final schemas = components['schemas']! as Map<String, Object?>;
    const allowedBodylessOperations = {
      'expireClassifiedListings',
      'publishHomeListing',
      'repostClassifiedListing',
    };
    var typedCommands = 0;
    final bodylessOperations = <String>{};

    for (final pathItem in paths.values.whereType<Map<String, Object?>>()) {
      final operation = pathItem['post'];
      if (operation is! Map<String, Object?>) continue;
      final operationId = operation['operationId']! as String;
      final requestBody = operation['requestBody'];
      final intentionalBodyless =
          operation['x-planext4u-bodyless-command'] == true;
      expect(
        requestBody != null || intentionalBodyless,
        isTrue,
        reason: operationId,
      );
      expect(requestBody != null && intentionalBodyless, isFalse);
      if (intentionalBodyless) {
        bodylessOperations.add(operationId);
      } else {
        final body = requestBody! as Map<String, Object?>;
        expect(body['required'], isTrue, reason: operationId);
        final content = body['content']! as Map<String, Object?>;
        final jsonContent =
            content['application/json']! as Map<String, Object?>;
        final schema = jsonContent['schema']! as Map<String, Object?>;
        expect(schema[r'$ref'], startsWith('#/components/schemas/'));
        typedCommands += 1;
      }
    }
    expect(typedCommands, 8);
    expect(bodylessOperations, allowedBodylessOperations);

    for (final schemaName in const [
      'PublicHomeListing',
      'PublicClassifiedListing',
    ]) {
      final schema = schemas[schemaName]! as Map<String, Object?>;
      final properties = schema['properties']! as Map<String, Object?>;
      expect(
        properties.keys,
        isNot(
          contains(
            anyOf('owner_id', 'latitude', 'longitude', 'media_asset_ids'),
          ),
        ),
      );
      expect(properties, contains('media'));
    }
    final media = schemas['MediaPresentation']! as Map<String, Object?>;
    final mediaProperties = media['properties']! as Map<String, Object?>;
    expect(mediaProperties, isNot(contains('asset_id')));

    for (final entry in const {
      '/v1/homes/listings': 'HomeListingPage',
      '/v1/classifieds/listings': 'ClassifiedListingPage',
    }.entries) {
      final pathItem = paths[entry.key]! as Map<String, Object?>;
      final get = pathItem['get']! as Map<String, Object?>;
      expect(get['x-planext4u-guest-readable'], isTrue);
      final responses = get['responses']! as Map<String, Object?>;
      final ok = responses['200']! as Map<String, Object?>;
      final content = ok['content']! as Map<String, Object?>;
      final jsonContent = content['application/json']! as Map<String, Object?>;
      final schema = jsonContent['schema']! as Map<String, Object?>;
      expect(schema[r'$ref'], '#/components/schemas/${entry.value}');
    }
  });
}

Map<String, Object?> _readContract(String name) {
  final packageContract = File('contracts/$name');
  final repositoryContract = File('packages/api_client/contracts/$name');
  return jsonDecode(
        (packageContract.existsSync() ? packageContract : repositoryContract)
            .readAsStringSync(),
      )
      as Map<String, Object?>;
}

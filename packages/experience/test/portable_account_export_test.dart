import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  test(
    'normal export adapter sends schema through the query contract',
    () async {
      final transport = _ExportTransport();
      final api = Phase5Api(
        ApiClient(
          baseUrl: Uri.parse('https://api.example.test'),
          transport: transport,
          authSession: _ExportSession(),
          retryBudget: const ApiRetryBudget(maxAttempts: 1),
        ),
      );
      final exported = await api.exportAccountData();
      expect(exported.document, isNotNull);
      expect(transport.requests, hasLength(1));
      expect(transport.requests.single.method, 'GET');
      expect(transport.requests.single.url.path, '/v1/me/data-export');
      expect(transport.requests.single.url.queryParametersAll, {
        'schema': ['4'],
      });
    },
  );
  test(
    'portable file retains complete identity history and explicit coverage',
    () {
      final value = AccountDataExport.fromJson(_payload());
      expect(value.consentHistoryCount, 2);
      expect(
        value.document!.fileName,
        'planext4u-account-20261025T120000Z.json',
      );
      final saved = jsonDecode(value.document!.json) as Map<String, Object?>;
      expect((saved['consent_history']! as List).length, 2);
      expect((saved['coverage']! as Map)['excluded'], ['orders_and_payments']);
      expect(value.document!.json, isNot(contains('credential-secret')));
      expect(value.document!.json, isNot(contains('refresh_token')));
      expect(value.document!.json, isNot(contains('device_id')));
      expect(value.document!.json, isNot(contains('provider_subject')));
    },
  );

  test('version two exports only safe contact snapshot metadata', () {
    final source = _payload()
      ..['schema_version'] = 2
      ..['contact_snapshots'] = [
        {
          'country': 'IN',
          'revision': 3,
          'contact_count': 1,
          'policy_version': 'contacts-v1',
          'expires_at': '2026-10-26T12:00:00Z',
          'phone_hash': 'private-phone-hash',
          'key_id': 'private-key-id',
          'request_hash': 'private-request-hash',
        },
      ];
    final saved = AccountDataExport.fromJson(source).document!.json;
    final payload = jsonDecode(saved) as Map<String, Object?>;
    final contacts = payload['contact_snapshots']! as List;
    expect(payload['schema_version'], 2);
    expect(contacts, hasLength(1));
    expect(contacts.single, {
      'country': 'IN',
      'revision': 3,
      'contact_count': 1,
      'policy_version': 'contacts-v1',
      'expires_at': '2026-10-26T12:00:00Z',
    });
    expect(saved, isNot(contains('private-phone-hash')));
    expect(saved, isNot(contains('private-key-id')));
    expect(saved, isNot(contains('private-request-hash')));
  });

  test('version three exports safe own deletion history only', () {
    final source = _payload()
      ..['schema_version'] = 3
      ..['contact_snapshots'] = <Object?>[]
      ..['deletion_history'] = [
        {
          'id': 'deletion-1',
          'status': 'SCHEDULED',
          'reason': 'Close my account',
          'requested_at': '2026-10-25T12:00:00Z',
          'effective_at': '2026-11-24T12:00:00Z',
          'identity_id': 'private-owner',
          'provider_subject': 'private-subject',
          'private_note': 'private-note',
        },
      ];
    final saved = AccountDataExport.fromJson(source).document!.json;
    final payload = jsonDecode(saved) as Map<String, Object?>;
    expect(payload['schema_version'], 3);
    expect(payload['contact_snapshots'], isEmpty);
    expect((payload['deletion_history']! as List).single, {
      'id': 'deletion-1',
      'status': 'SCHEDULED',
      'reason': 'Close my account',
      'requested_at': '2026-10-25T12:00:00Z',
      'effective_at': '2026-11-24T12:00:00Z',
    });
    expect(saved, isNot(contains('private-owner')));
    expect(saved, isNot(contains('private-subject')));
    expect(saved, isNot(contains('private-note')));
  });

  test('version four includes only safe own onboarding snapshots', () {
    final source = _payload()
      ..['schema_version'] = 4
      ..['contact_snapshots'] = <Object?>[]
      ..['deletion_history'] = <Object?>[]
      ..['vendor_applications'] = [
        {
          'country': 'IN',
          'revision': 3,
          'status': 'REJECTED',
          'business_name': 'Example shop',
          'business_type': 'Retail store',
          'contact_name': 'Example owner',
          'created_at': '2026-10-25T12:00:00Z',
          'updated_at': '2026-10-26T12:00:00Z',
          'bank_reference': 'private-bank-token',
          'review_reason': 'private-review-note',
        },
      ]
      ..['rider_profiles'] = [
        {
          'country': 'IN',
          'revision': 2,
          'status': 'KYC_REVIEW',
          'full_name': 'Example rider',
          'vehicle_type': 'BICYCLE',
          'vehicle_number': 'CYC123',
          'zones': ['600001'],
          'created_at': '2026-10-25T12:00:00Z',
          'updated_at': '2026-10-26T12:00:00Z',
          'identity_document': 'private-document',
          'bank_reference': 'private-bank-token',
        },
      ];
    final export = AccountDataExport.fromJson(source);
    expect(export.vendorApplicationCount, 1);
    expect(export.riderProfileCount, 1);
    final saved = export.document!.json;
    final payload = jsonDecode(saved) as Map<String, Object?>;
    expect(
      (payload['vendor_applications']! as List).single,
      containsPair('business_name', 'Example shop'),
    );
    expect(
      (payload['rider_profiles']! as List).single,
      containsPair('zones', ['600001']),
    );
    for (final privateValue in [
      'private-bank-token',
      'private-review-note',
      'private-document',
    ]) {
      expect(saved, isNot(contains(privateValue)));
    }
  });

  test(
    'unsupported versions and malformed or oversized records fail closed',
    () {
      expect(
        () => AccountDataExport.fromJson(_payload()..['schema_version'] = 5),
        throwsFormatException,
      );
      expect(
        () => AccountDataExport.fromJson(
          _payload()
            ..['schema_version'] = 4
            ..['contact_snapshots'] = <Object?>[]
            ..['deletion_history'] = <Object?>[]
            ..['vendor_applications'] = <Object?>[]
            ..['rider_profiles'] = [
              {
                'country': 'IN',
                'revision': 2,
                'status': 'KYC_REVIEW',
                'full_name': 'Example rider',
                'vehicle_type': 'BICYCLE',
                'vehicle_number': 'CYC123',
                'zones': [
                  {'private': 'unexpected'},
                ],
                'created_at': '2026-10-25T12:00:00Z',
                'updated_at': '2026-10-26T12:00:00Z',
              },
            ],
        ),
        throwsFormatException,
      );
      expect(
        () => AccountDataExport.fromJson(
          _payload()
            ..['schema_version'] = 3
            ..['contact_snapshots'] = <Object?>[]
            ..['deletion_history'] = [
              {
                'id': 'deletion-1',
                'status': 'UNKNOWN',
                'reason': 'Close',
                'requested_at': '2026-10-25T12:00:00Z',
                'effective_at': '2026-11-24T12:00:00Z',
              },
            ],
        ),
        throwsFormatException,
      );
      expect(
        () => AccountDataExport.fromJson(
          _payload()
            ..['schema_version'] = 2
            ..['contact_snapshots'] = [
              {'country': 'IN', 'revision': 3, 'contact_count': -1},
            ],
        ),
        throwsFormatException,
      );
      expect(
        () => AccountDataExport.fromJson(
          _payload()
            ..['consent_history'] = [
              <String, Object?>{
                'purpose': {'credential': 'secret'},
              },
            ],
        ),
        throwsFormatException,
      );
      expect(
        () => AccountDataExport.fromJson(
          _payload()
            ..['consent_history'] = List.filled(10001, <String, Object?>{}),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'only the latest response belonging to the active controller may save',
    () async {
      final saver = _Exporter();
      final controller = AccountPrivacyController(
        _Remote(),
        documentExporter: saver,
      );
      final first = (await controller.exportAccountData())!;
      final second = (await controller.exportAccountData())!;
      expect(await controller.saveExport(first), isNull);
      expect(saver.calls, 0);
      expect(await controller.saveExport(second), DocumentExportResult.saved);
      expect(saver.calls, 1);
      expect(saver.received!.every((byte) => byte == 0), isTrue);
      expect(
        controller.state.message,
        contains('saved to your chosen location'),
      );
      controller.dispose();
      expect(await controller.saveExport(second), isNull);
    },
  );

  test('save failure is retryable without exposing a provider error', () async {
    final saver = _Exporter()..fail = true;
    final controller = AccountPrivacyController(
      _Remote(),
      documentExporter: saver,
    );
    final value = (await controller.exportAccountData())!;
    expect(await controller.saveExport(value), isNull);
    expect(controller.state.message, isNot(contains('credential-secret')));
    expect(controller.state.status, AccountPrivacyStatus.failure);
    saver.fail = false;
    expect(await controller.saveExport(value), DocumentExportResult.saved);
    controller.dispose();
  });

  test('late picker result after account disposal cannot write', () async {
    final saver = _Exporter()..gate = Completer<void>();
    final controller = AccountPrivacyController(
      _Remote(),
      documentExporter: saver,
    );
    final value = (await controller.exportAccountData())!;
    final saving = controller.saveExport(value);
    expect(await controller.saveExport(value), isNull);
    controller.dispose();
    saver.gate!.complete();
    expect(await saving, isNull);
    expect(saver.writes, 0);
    expect(saver.received!.every((byte) => byte == 0), isTrue);
  });

  testWidgets(
    'privacy screen saves the portable payload using the normal control',
    (tester) async {
      final saver = _Exporter();
      final controller = AccountPrivacyController(
        _Remote(),
        documentExporter: saver,
      );
      await tester.pumpWidget(
        MaterialApp(home: AccountPrivacyScreen(controller: controller)),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('export-account-data')),
        250,
      );
      await tester.tap(find.byKey(const ValueKey('export-account-data')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-account-export')),
      );
      await tester.tap(find.byKey(const ValueKey('save-account-export')));
      await tester.pumpAndSettle();
      expect(saver.writes, 1);
      expect(
        find.text('Account export saved to your chosen location.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

final class _Exporter implements DocumentExporter {
  bool fail = false;
  int calls = 0, writes = 0;
  Uint8List? received;
  Completer<void>? gate;
  @override
  Future<DocumentExportResult> save({
    required String fileName,
    required Uint8List bytes,
    required bool Function() isCurrent,
  }) async {
    calls++;
    received = bytes;
    await gate?.future;
    if (!isCurrent()) return DocumentExportResult.cancelled;
    if (fail) {
      throw PlatformException(
        code: 'WRITE_FAILED',
        message: 'credential-secret',
      );
    }
    writes++;
    return DocumentExportResult.saved;
  }
}

final class _Remote implements AccountPrivacyRemote {
  @override
  Future<AccountDataExport> exportAccountData() async =>
      AccountDataExport.fromJson(_payload());
  @override
  Future<AccountDeletionRequest> requestAccountDeletion(String reason) async =>
      throw UnimplementedError();
}

final class _ExportSession implements ApiAuthSession {
  @override
  Future<String?> accessToken() async => 'synthetic-export-session';
  @override
  Future<bool> refresh() async => false;
}

final class _ExportTransport implements ApiTransport {
  final requests = <TransportRequest>[];
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: Uint8List.fromList(
        utf8.encode(
          jsonEncode(
            _payload()
              ..['schema_version'] = 4
              ..['contact_snapshots'] = <Object?>[]
              ..['deletion_history'] = <Object?>[]
              ..['vendor_applications'] = <Object?>[]
              ..['rider_profiles'] = <Object?>[],
          ),
        ),
      ),
    );
  }
}

Map<String, Object?> _payload() => {
  'schema_version': 1,
  'generated_at': '2026-10-25T12:00:00Z',
  'identity_id': 'account-export',
  'tenant_id': 'tenant-export',
  'country': 'IN',
  'roles': ['CUSTOMER'],
  'refresh_token': 'credential-secret',
  'coverage': {
    'included': [
      'identity.profile',
      'identity.sessions',
      'identity.consent_history',
    ],
    'excluded': ['orders_and_payments'],
  },
  'profile': {
    'display_name': 'My profile',
    'locale': 'en',
    'time_zone': 'Asia/Kolkata',
    'version': 1,
    'updated_at': '2026-10-25T12:00:00Z',
    'provider_subject': 'credential-secret',
  },
  'sessions': [
    {
      'id': 'session-export',
      'device_reference': 'masked-device',
      'country': 'IN',
      'authenticated_at': '2026-10-25T12:00:00Z',
      'last_seen_at': '2026-10-25T12:00:00Z',
      'expires_at': '2026-11-25T12:00:00Z',
      'current': true,
      'device_id': 'credential-secret',
    },
  ],
  'consents': [
    {
      'evidence_id': 'evidence-2',
      'purpose': 'ANALYTICS',
      'granted': false,
      'policy_version': 'p1',
      'recorded_at': '2026-10-25T12:00:00Z',
      'version': 2,
    },
  ],
  'consent_history': [
    {
      'evidence_id': 'evidence-1',
      'purpose': 'ANALYTICS',
      'granted': true,
      'policy_version': 'p1',
      'recorded_at': '2026-10-24T12:00:00Z',
      'version': 1,
      'country': null,
    },
    {
      'evidence_id': 'evidence-2',
      'purpose': 'ANALYTICS',
      'granted': false,
      'policy_version': 'p1',
      'recorded_at': '2026-10-25T12:00:00Z',
      'version': 2,
      'country': 'IN',
    },
  ],
};

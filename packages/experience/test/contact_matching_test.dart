import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

final class _Session implements ApiAuthSession {
  @override
  Future<String?> accessToken() async => 'synthetic-owner';
  @override
  Future<bool> refresh() async => false;
}

final class _ConsentRemote implements ConsentRemote {
  ConsentEvidence? current;
  @override
  Future<List<ConsentEvidence>> list() async => [?current];
  @override
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    if (granted && expectedVersion != (current?.version ?? 0)) {
      throw StateError('stale grant');
    }
    return current = ConsentEvidence(
      evidenceId: 'synthetic-consent',
      purpose: purpose,
      granted: granted,
      policyVersion: policyVersion,
      recordedAt: DateTime.utc(2026, 10, 26),
      version: (current?.version ?? 0) + 1,
    );
  }
}

final class _Permissions implements DeviceAccessPlatform {
  int requests = 0;
  DeviceAccessSnapshot _snapshot(DeviceAccess contacts) => DeviceAccessSnapshot(
    permissions: {
      for (final permission in DevicePermission.values)
        permission: permission == DevicePermission.contacts
            ? contacts
            : DeviceAccess.notAllowed,
    },
    locationServiceEnabled: false,
  );
  @override
  Future<DeviceAccessSnapshot> read() async =>
      _snapshot(DeviceAccess.notAllowed);
  @override
  Future<DeviceAccessSnapshot> request(DevicePermission permission) async {
    if (permission != DevicePermission.contacts) {
      throw StateError('wrong permission');
    }
    requests++;
    return _snapshot(DeviceAccess.allowed);
  }

  @override
  Future<bool> openSettings(DeviceSettings destination) async => false;
}

final class _Phones implements ContactPhonesPlatform {
  int reads = 0;
  Completer<NativeContactPhones>? gate;
  @override
  Future<NativeContactPhones> readPhones({required int maximum}) async {
    reads++;
    return gate?.future ??
        const NativeContactPhones(phones: ['+919876543210'], skipped: 2);
  }
}

final class _Transport implements ApiTransport {
  int syncs = 0, reads = 0;
  final requests = <TransportRequest>[];
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    Object result;
    if (request.method == 'PUT') {
      syncs++;
      result = _state('READY', 1);
    } else if (request.url.path.endsWith('/matches')) {
      result = {
        'snapshot_revision': 1,
        'items': [
          {'identity_id': 'member-2', 'display_name': 'Local Member'},
        ],
      };
    } else {
      reads++;
      result = _state(syncs > 0 ? 'READY' : 'EMPTY', syncs > 0 ? 1 : 0);
    }
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(result))),
    );
  }

  Map<String, Object?> _state(String status, int revision) => {
    'status': status,
    'revision': revision,
    'policy_version': 'contacts-v1',
    'contact_count': syncs,
    'max_contacts': 100,
    if (status == 'READY')
      'expires_at': DateTime.utc(2026, 10, 27).toIso8601String(),
  };
}

Future<
  ({
    ContactMatchingController controller,
    ConsentController consent,
    _Transport transport,
    _Phones phones,
    _Permissions permissions,
  })
>
_fixture({
  required bool Function() scope,
  String? Function()? policyVersion,
}) async {
  final transport = _Transport();
  final permissions = _Permissions();
  final phones = _Phones();
  final consent = ConsentController(_ConsentRemote());
  await consent.load();
  final api = ContactMatchingApi(
    ApiClient(
      baseUrl: Uri.parse('https://api.example.test'),
      transport: transport,
      authSession: _Session(),
      retryBudget: const ApiRetryBudget(maxAttempts: 1),
    ),
  );
  final controller = ContactMatchingController(
    api: api,
    consent: consent,
    policyVersion: policyVersion ?? () => 'contacts-v1',
    freshProviderToken: () async => 'fresh-provider-token',
    scopeIsCurrent: scope,
    permissions: permissions,
    phones: phones,
  );
  return (
    controller: controller,
    consent: consent,
    transport: transport,
    phones: phones,
    permissions: permissions,
  );
}

void main() {
  testWidgets(
    'explicit consent and Android choice precede reading or uploading',
    (tester) async {
      final f = await _fixture(scope: () => true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ContactMatchingCard(controller: f.controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.phones.reads, 0);
      expect(f.permissions.requests, 0);
      expect(f.transport.syncs, 0);
      await tester.tap(find.byKey(const ValueKey('allow-contact-matching')));
      await tester.pumpAndSettle();
      expect(f.phones.reads, 0);
      await tester.tap(find.byKey(const ValueKey('sync-contacts')));
      await tester.pumpAndSettle();
      expect(f.permissions.requests, 1);
      expect(f.phones.reads, 1);
      expect(f.transport.syncs, 1);
      final body =
          jsonDecode(
                utf8.decode(
                  f.transport.requests
                      .singleWhere((request) => request.method == 'PUT')
                      .body!,
                ),
              )
              as Map;
      expect(body['phones'], ['+919876543210']);
      expect(body.keys, isNot(contains('names')));
      await tester.tap(find.byKey(const ValueKey('show-contact-matches')));
      await tester.pumpAndSettle();
      expect(find.text('Local Member'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stop-contact-matching')));
      await tester.pumpAndSettle();
      expect(find.text('Local Member'), findsNothing);
      expect(f.controller.matches, isEmpty);
      expect(f.controller.skipped, 0);
      expect(f.controller.consentGranted, isFalse);
      expect(
        f.consent.evidence[ConsentPurpose.contactMatching]?.granted,
        isFalse,
      );
      expect(find.text('Contact matching stopped.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      f.controller.dispose();
      f.consent.dispose();
    },
  );

  test(
    'old consent can be withdrawn when the published policy is unavailable',
    () async {
      String? policy = 'contacts-v1';
      final f = await _fixture(scope: () => true, policyVersion: () => policy);
      await f.controller.load();
      await f.controller.grant();
      policy = null;
      await f.consent.load();
      expect(f.controller.state, isNull);
      expect(f.controller.canWithdraw, isTrue);
      await f.controller.withdraw();
      expect(f.controller.consentGranted, isFalse);
      expect(
        f.consent.evidence[ConsentPurpose.contactMatching]?.granted,
        isFalse,
      );
      f.controller.dispose();
      f.consent.dispose();
    },
  );

  test(
    'withdrawal during native read prevents upload and stale account result',
    () async {
      var current = true;
      final f = await _fixture(scope: () => current);
      await f.controller.load();
      await f.controller.grant();
      f.phones.gate = Completer<NativeContactPhones>();
      final pending = f.controller.sync();
      await Future<void>.delayed(Duration.zero);
      await f.consent.setConsent(
        purpose: ConsentPurpose.contactMatching,
        granted: false,
        policyVersion: 'contacts-v1',
      );
      current = false;
      f.phones.gate!.complete(
        const NativeContactPhones(phones: ['+919876543210'], skipped: 0),
      );
      await pending;
      expect(f.transport.syncs, 0);
      expect(f.controller.matches, isEmpty);
      f.controller.dispose();
      f.consent.dispose();
    },
  );
}

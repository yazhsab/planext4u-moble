import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

const _documents = [
  {
    'kind': 'OWNER_IDENTITY',
    'asset_id': '90000000-0000-4000-8000-000000000901',
  },
  {
    'kind': 'BUSINESS_REGISTRATION',
    'asset_id': '90000000-0000-4000-8000-000000000902',
  },
];
const _draft = RiderRegistrationDraft(
  fullName: 'Correction rider',
  vehicleType: 'BICYCLE',
  vehicleNumber: 'CYC123',
  documents: [
    RiderDocumentDraft(
      kind: 'IDENTITY',
      assetId: '90000000-0000-4000-8000-000000000903',
    ),
  ],
  bankReference: 'bankref_correction_fixture',
  zones: ['600001'],
  dutyLocationConsent: true,
);
RiderProfile _rider({
  bool rework = true,
  String status = 'SUSPENDED',
  int revision = 2,
  String id = 'rider-rework',
}) => RiderProfile(
  id: id,
  revision: revision,
  status: status,
  fullName: 'Correction rider',
  vehicleType: 'BICYCLE',
  vehicleNumber: 'CYC123',
  bankStatus: 'PENDING_VERIFICATION',
  zones: const ['600001'],
  maxConcurrent: 2,
  reworkAllowed: rework,
  reviewReason: rework ? 'Replace unreadable identity document' : '',
  allowedActions: rework
      ? const {'RESUBMIT_APPLICATION'}
      : const {'VIEW_REVIEW_STATUS'},
);
VendorApplication _vendor({
  bool rejected = true,
  String id = 'vendor-rework',
  int? revision,
  String? status,
}) => VendorApplication(
  id: id,
  revision: revision ?? (rejected ? 4 : 5),
  status: status ?? (rejected ? 'REJECTED' : 'DOCUMENTS_SUBMITTED'),
  businessName: 'Correction vendor',
  businessType: 'SOLE_PROPRIETOR',
  contactName: 'Synthetic contact',
  documents: const [],
  zoneCount: 0,
  bankStatus: 'NOT_CONFIGURED',
  verified: false,
  allowedActions: rejected ? const {'RESUBMIT_DOCUMENTS'} : const {},
  timeline: rejected
      ? [
          VendorTimelineEvent(
            status: 'REJECTED',
            actor: 'reviewer',
            createdAt: DateTime.utc(2026, 10, 27),
            reason: 'Correct the business contact and identity image',
          ),
        ]
      : const [],
);

void main() {
  test(
    'normal APIs send revisioned idempotent rework without caller authority',
    () async {
      final transport = _Transport();
      final client = ApiClient(
        baseUrl: Uri.parse('https://api.planext4u.test'),
        transport: transport,
        authSession: const _Auth(),
        retryBudget: const ApiRetryBudget(maxAttempts: 1),
      );
      await VendorOperationsApi(client).resubmitApplication(
        4,
        businessName: 'Corrected vendor',
        businessType: 'RETAIL_STORE',
        contactName: 'Corrected contact',
        documents: _documents,
      );
      await RiderOperationsApi(client).resubmit(2, _draft.toJson());
      expect(transport.requests.map((r) => r.url.path), [
        '/v1/vendor/application/resubmissions',
        '/v1/rider/application/resubmissions',
      ]);
      expect(transport.requests.map((r) => r.headers['If-Match']), [
        '"4"',
        '"2"',
      ]);
      for (final request in transport.requests) {
        expect(request.headers['Idempotency-Key'], isNotEmpty);
        final body =
            jsonDecode(utf8.decode(request.body!)) as Map<String, Object?>;
        expect(body.keys, isNot(contains('approved')));
        expect(body.keys, isNot(contains('source_session')));
        expect(body.keys, isNot(contains('rework_allowed')));
      }
      final vendorBody =
          jsonDecode(utf8.decode(transport.requests.first.body!))
              as Map<String, Object?>;
      expect(vendorBody['business_name'], 'Corrected vendor');
      expect(vendorBody['business_type'], 'RETAIL_STORE');
      expect(vendorBody['contact_name'], 'Corrected contact');
    },
  );

  test(
    'rider correction uses eligibility and authoritative readback',
    () async {
      final remote = _RiderRemote();
      final controller = RiderOperationsController(remote);
      await controller.load();
      remote.latest = _rider(rework: false, status: 'KYC_REVIEW', revision: 4);
      await controller.resubmit(_draft);
      expect(remote.revisions, [2]);
      expect(controller.state.profile?.revision, 4);
      expect(controller.state.profile?.reworkAllowed, false);
      controller.dispose();
    },
  );

  test('operational suspension and pending reviews cannot resubmit', () async {
    for (final status in ['SUSPENDED', 'KYC_REVIEW', 'APPROVED']) {
      final remote = _RiderRemote()
        ..latest = _rider(rework: false, status: status);
      final controller = RiderOperationsController(remote);
      await controller.load();
      await controller.resubmit(_draft);
      expect(remote.revisions, isEmpty);
      expect(controller.state.status, OperationsStatus.failure);
      controller.dispose();
    }
  });

  test(
    'acknowledged rider correction survives failed current readback',
    () async {
      final remote = _RiderRemote();
      final controller = RiderOperationsController(remote);
      await controller.load();
      remote.failReadback = true;
      await controller.resubmit(_draft);
      expect(controller.state.profile?.status, 'KYC_REVIEW');
      expect(controller.state.status, OperationsStatus.ready);
      expect(controller.state.message, contains('Corrections submitted'));
      controller.dispose();
    },
  );

  test(
    'rider refuses alien, stale and unsubmitted correction receipts',
    () async {
      final invalid = [
        _rider(
          id: 'another-rider',
          rework: false,
          status: 'KYC_REVIEW',
          revision: 3,
        ),
        _rider(rework: false, status: 'KYC_REVIEW', revision: 2),
        _rider(rework: false, status: 'SUSPENDED', revision: 3),
      ];
      for (final receipt in invalid) {
        final remote = _RiderRemote()..acknowledgement = receipt;
        final saved = _FormStore(
          const RiderOnboardingProgress(
            fullName: 'Unsaved correction must survive',
            applicationId: 'rider-rework',
            applicationRevision: 2,
          ),
        );
        final controller = RiderOperationsController(remote)
          ..onboardingProgress = saved;
        await controller.load();
        await controller.resubmit(_draft);
        expect(controller.state.status, OperationsStatus.failure);
        expect(controller.state.profile?.status, 'SUSPENDED');
        expect(saved.value?.fullName, 'Unsaved correction must survive');
        controller.dispose();
      }
    },
  );

  test(
    'rider keeps a valid receipt if later readback is alien or stale',
    () async {
      for (final readback in [
        _rider(
          id: 'another-rider',
          rework: false,
          status: 'KYC_REVIEW',
          revision: 4,
        ),
        _rider(rework: true, status: 'SUSPENDED', revision: 2),
        _rider(rework: true, status: 'SUSPENDED', revision: 3),
      ]) {
        final remote = _RiderRemote();
        final controller = RiderOperationsController(remote);
        await controller.load();
        remote.latest = readback;
        await controller.resubmit(_draft);
        expect(controller.state.status, OperationsStatus.ready);
        expect(controller.state.profile?.id, 'rider-rework');
        expect(controller.state.profile?.revision, 3);
        expect(controller.state.profile?.status, 'KYC_REVIEW');
        expect(controller.state.message, contains('Refresh'));
        controller.dispose();
      }
    },
  );

  test(
    'late correction response cannot update a disposed rider controller',
    () async {
      final remote = _RiderRemote()..pending = Completer<RiderProfile>();
      final controller = RiderOperationsController(remote);
      await controller.load();
      final result = controller.resubmit(_draft);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      remote.pending!.complete(
        _rider(rework: false, status: 'KYC_REVIEW', revision: 3),
      );
      await result;
      expect(controller.state.profile?.status, 'SUSPENDED');
    },
  );

  test(
    'vendor corrections use rework endpoint and retain acknowledged status',
    () async {
      final remote = _VendorRemote();
      final controller = VendorOperationsController(remote);
      await controller.loadAll();
      remote.failReadback = true;
      await controller.resubmitApplication(
        businessName: 'Corrected vendor',
        businessType: 'RETAIL_STORE',
        contactName: 'Corrected contact',
        documents: _documents,
      );
      expect(remote.revisions, [4]);
      expect(remote.businessNames, ['Corrected vendor']);
      expect(controller.state.application?.status, 'DOCUMENTS_SUBMITTED');
      expect(controller.state.status, OperationsStatus.ready);
      expect(controller.state.message, contains('Corrections submitted'));
      controller.dispose();
    },
  );

  test(
    'vendor refuses alien, stale and unsubmitted correction receipts',
    () async {
      final invalid = [
        _vendor(rejected: false, id: 'another-vendor'),
        _vendor(rejected: false, revision: 4),
        _vendor(rejected: false, status: 'REJECTED'),
      ];
      for (final receipt in invalid) {
        final remote = _VendorRemote()..acknowledgement = receipt;
        final saved = _VendorFormStore(
          const VendorOnboardingProgress(
            businessName: 'Unsaved correction must survive',
            applicationId: 'vendor-rework',
            applicationRevision: 4,
          ),
        );
        final controller = VendorOperationsController(remote)
          ..onboardingProgress = saved;
        await controller.loadAll();
        await controller.resubmitApplication(
          businessName: 'Corrected vendor',
          businessType: 'RETAIL_STORE',
          contactName: 'Corrected contact',
          documents: _documents,
        );
        expect(controller.state.status, OperationsStatus.failure);
        expect(controller.state.application?.status, 'REJECTED');
        expect(saved.value?.businessName, 'Unsaved correction must survive');
        controller.dispose();
      }
    },
  );

  test(
    'vendor keeps a valid receipt if later readback is alien or stale',
    () async {
      for (final readback in [
        _vendor(rejected: false, id: 'another-vendor', revision: 6),
        _vendor(rejected: true),
        _vendor(rejected: true, revision: 5),
      ]) {
        final remote = _VendorRemote();
        final controller = VendorOperationsController(remote);
        await controller.loadAll();
        remote.latest = readback;
        await controller.resubmitApplication(
          businessName: 'Corrected vendor',
          businessType: 'RETAIL_STORE',
          contactName: 'Corrected contact',
          documents: _documents,
        );
        expect(controller.state.status, OperationsStatus.ready);
        expect(controller.state.application?.id, 'vendor-rework');
        expect(controller.state.application?.revision, 5);
        expect(controller.state.application?.status, 'DOCUMENTS_SUBMITTED');
        expect(controller.state.message, contains('Refresh'));
        controller.dispose();
      }
    },
  );

  testWidgets(
    'vendor rework shows editable profile fields and fails closed without provider',
    (tester) async {
      final controller = VendorOperationsController(_VendorRemote());
      await controller.loadAll();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VendorOperationsView(
              controller: controller,
              destination: const RoleDestination(
                id: 'profile',
                label: 'Profile',
                icon: Icons.storefront,
                capability: RoleCapability.profile,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('vendor-rework-business-name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vendor-rework-business-type')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vendor-rework-contact-name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vendor-rework-provider-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vendor-rework-reason')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('vendor-rework-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'vendor rework submits edited fields and fresh private evidence',
    (tester) async {
      final remote = _VendorRemote();
      final controller = VendorOperationsController(remote);
      await controller.loadAll();
      final provider = _VendorProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VendorOperationsView(
              controller: controller,
              onboardingProvider: provider,
              destination: const RoleDestination(
                id: 'profile',
                label: 'Profile',
                icon: Icons.storefront,
                capability: RoleCapability.profile,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('vendor-rework-business-name')),
        'Updated store',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vendor-rework-business-type')),
        'Home services',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vendor-rework-contact-name')),
        'Updated owner',
      );
      final collect = find.byKey(
        const ValueKey('vendor-rework-collect-documents'),
      );
      await tester.ensureVisible(collect);
      await tester.tap(collect);
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('vendor-rework-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(remote.revisions, [4]);
      expect(remote.businessNames, ['Updated store']);
      expect(remote.businessTypes, ['Home services']);
      expect(remote.contactNames, ['Updated owner']);
      expect(remote.documentCounts, [2]);
      expect(provider.prepared, isTrue);
      expect(provider.forgot, isTrue);
      expect(controller.state.application?.status, 'DOCUMENTS_SUBMITTED');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'vendor rework restores matching draft and delete resets server fields',
    (tester) async {
      final controller = VendorOperationsController(_VendorRemote());
      final store = _VendorFormStore(
        const VendorOnboardingProgress(
          businessName: 'Saved business',
          businessType: 'Saved type',
          contactName: 'Saved contact',
          applicationId: 'vendor-rework',
          applicationRevision: 4,
        ),
      );
      controller.onboardingProgress = store;
      await controller.loadAll();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VendorOperationsView(
              controller: controller,
              destination: const RoleDestination(
                id: 'profile',
                label: 'Profile',
                icon: Icons.storefront,
                capability: RoleCapability.profile,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('vendor-rework-business-name'));
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        'Saved business',
      );
      final discard = find.byKey(const ValueKey('vendor-rework-discard-form'));
      await tester.ensureVisible(discard);
      await tester.tap(discard);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        'Correction vendor',
      );
      expect(store.value, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'vendor correction evidence is cleared on controller replacement',
    (tester) async {
      final first = VendorOperationsController(_VendorRemote());
      final second = VendorOperationsController(_VendorRemote());
      await first.loadAll();
      await second.loadAll();
      Widget view(
        VendorOperationsController controller,
        VendorOnboardingProvider provider,
      ) => MaterialApp(
        home: Scaffold(
          body: VendorOperationsView(
            controller: controller,
            onboardingProvider: provider,
            destination: const RoleDestination(
              id: 'profile',
              label: 'Profile',
              icon: Icons.storefront,
              capability: RoleCapability.profile,
            ),
          ),
        ),
      );
      await tester.pumpWidget(view(first, _VendorProvider()));
      await tester.pumpAndSettle();
      final collect = find.byKey(
        const ValueKey('vendor-rework-collect-documents'),
      );
      await tester.ensureVisible(collect);
      await tester.tap(collect);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('vendor-rework-submit')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(view(second, _VendorProvider()));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('vendor-rework-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      second.dispose();
    },
  );

  testWidgets(
    'rider rework shows the review reason and fails closed without provider',
    (tester) async {
      final controller = RiderOperationsController(_RiderRemote());
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiderOperationsView(
              controller: controller,
              destination: const RoleDestination(
                id: 'duty',
                label: 'Duty',
                icon: Icons.delivery_dining,
                capability: RoleCapability.riderDuty,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rider-rework-reason')), findsOneWidget);
      expect(
        find.textContaining('Replace unreadable identity document'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rider-register-provider-unavailable')),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('rider-submit-registration')),
      );
      expect(button.onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('rider rework ignores a form saved for another revision', (
    tester,
  ) async {
    final controller = RiderOperationsController(_RiderRemote());
    controller.onboardingProgress = _FormStore(
      const RiderOnboardingProgress(
        fullName: 'Outdated correction',
        vehicleType: 'CAR',
        vehicleNumber: 'OLD123',
        postalCodes: '999999',
        applicationId: 'rider-rework',
        applicationRevision: 1,
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderOperationsView(
            controller: controller,
            destination: const RoleDestination(
              id: 'duty',
              label: 'Duty',
              icon: Icons.delivery_dining,
              capability: RoleCapability.riderDuty,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('rider-registration-name')),
          )
          .controller!
          .text,
      'Correction rider',
    );
    expect(find.textContaining('another application review'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

class _FormStore implements RiderOnboardingProgressStore {
  _FormStore(this.value);
  RiderOnboardingProgress? value;
  @override
  Future<RiderOnboardingProgress?> read() async => value;
  @override
  Future<void> save(RiderOnboardingProgress value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _VendorFormStore implements VendorOnboardingProgressStore {
  _VendorFormStore(this.value);
  VendorOnboardingProgress? value;
  @override
  Future<VendorOnboardingProgress?> read() async => value;
  @override
  Future<void> save(VendorOnboardingProgress value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _RiderRemote implements RiderOperationsRemote, RiderReworkRemote {
  RiderProfile latest = _rider();
  RiderProfile? acknowledgement;
  bool failReadback = false;
  Completer<RiderProfile>? pending;
  final revisions = <int>[];
  @override
  Future<RiderProfile> profile() async {
    if (failReadback && revisions.isNotEmpty) {
      throw const ApiTransportFailure(correlationId: 'rework-readback');
    }
    return latest;
  }

  @override
  Future<RiderProfile> resubmit(
    int revision,
    Map<String, Object?> value,
  ) async {
    revisions.add(revision);
    return pending?.future ??
        Future.value(
          acknowledgement ??
              _rider(rework: false, status: 'KYC_REVIEW', revision: 3),
        );
  }

  @override
  Future<RiderDuty> duty() async => throw StateError('No active duty');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VendorRemote implements VendorOperationsRemote, VendorReworkRemote {
  bool failReadback = false;
  VendorApplication? acknowledgement;
  VendorApplication? latest;
  final revisions = <int>[];
  final businessNames = <String>[];
  final businessTypes = <String>[];
  final contactNames = <String>[];
  final documentCounts = <int>[];
  @override
  Future<VendorApplication> application() async {
    if (failReadback && revisions.isNotEmpty) {
      throw const ApiTransportFailure(correlationId: 'rework-readback');
    }
    return latest ?? _vendor(rejected: revisions.isEmpty);
  }

  @override
  Future<Map<String, Object?>> dashboard() async => {};
  @override
  Future<VendorApplication> resubmitApplication(
    int revision, {
    required String businessName,
    required String businessType,
    required String contactName,
    required List<Map<String, Object?>> documents,
  }) async {
    revisions.add(revision);
    businessNames.add(businessName);
    businessTypes.add(businessType);
    contactNames.add(contactName);
    documentCounts.add(documents.length);
    return acknowledgement ?? _vendor(rejected: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VendorProvider
    implements
        VendorOnboardingProvider,
        VendorOnboardingCapabilities,
        RecoverableOnboardingDocuments {
  bool prepared = false;
  bool forgot = false;
  @override
  bool get canCollectDocuments => true;
  @override
  bool get canTokenizeBankAccount => false;
  @override
  bool get retainsDocumentProgress => true;
  @override
  Future<List<VendorOnboardingDocument>> collectDocuments() async => const [
    VendorOnboardingDocument(
      kind: 'OWNER_IDENTITY',
      assetId: '90000000-0000-4000-8000-000000000901',
    ),
    VendorOnboardingDocument(
      kind: 'BUSINESS_REGISTRATION',
      assetId: '90000000-0000-4000-8000-000000000902',
    ),
  ];
  @override
  Future<void> prepareDocumentSubmission(Set<String> assetIds) async {
    expect(assetIds.length, 2);
    prepared = true;
  }

  @override
  Future<void> forgetSubmittedDocuments(Set<String> assetIds) async {
    forgot = true;
  }

  @override
  Future<void> discardSavedDocuments() async {}
  @override
  Future<VendorOnboardingBankAccount> tokenizeBankAccount() async =>
      throw StateError('Not configured');
}

class _Transport implements ApiTransport {
  final requests = <TransportRequest>[];
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    final body = request.url.path.contains('/vendor/')
        ? {
            'id': 'vendor-rework',
            'revision': 5,
            'status': 'DOCUMENTS_SUBMITTED',
            'business_name': 'Correction vendor',
            'business_type': 'SOLE_PROPRIETOR',
            'contact_name': 'Synthetic',
            'documents': <Object?>[],
            'service_zones': <Object?>[],
            'verified': false,
            'allowed_actions': <String>[],
            'timeline': <Object?>[],
            'updated_at': '2026-10-27T10:00:00Z',
          }
        : {
            'id': 'rider-rework',
            'revision': 3,
            'status': 'KYC_REVIEW',
            'full_name': 'Correction rider',
            'vehicle_type': 'BICYCLE',
            'vehicle_number': 'CYC123',
            'bank_status': 'PENDING_VERIFICATION',
            'zones': ['600001'],
            'max_concurrent': 2,
            'allowed_actions': ['VIEW_REVIEW_STATUS'],
            'rework_allowed': false,
            'last_command_sequence': 0,
            'last_location_sequence': 0,
          };
    return TransportResponse(
      statusCode: 200,
      headers: const {'X-Correlation-ID': 'rework-server'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );
  }
}

class _Auth implements ApiAuthSession {
  const _Auth();
  @override
  Future<String?> accessToken() async => 'synthetic-local-rework-access';
  @override
  Future<bool> refresh() async => false;
}

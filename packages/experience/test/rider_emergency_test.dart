import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('rider API creates, reads, and revokes an emergency incident', () async {
    final transport = _EmergencyTransport();
    final api = RiderOperationsApi(
      ApiClient(
        baseUrl: Uri.parse('https://api.planext4u.test'),
        transport: transport,
        authSession: const _StaticAuthSession(),
        retryBudget: const ApiRetryBudget(maxAttempts: 1),
        correlationIdFactory: () => 'corr-rider-emergency-test',
      ),
    );
    final location = RiderTrackedPosition(
      latitude: 13.08,
      longitude: 80.27,
      accuracyMeters: 8,
      capturedAt: DateTime.now().toUtc(),
    );

    final created = await api.createEmergencyIncident(
      category: 'SAFETY',
      description: 'Rider requested urgent safety assistance',
      location: location,
    );
    await api.emergencyIncident(created.id);
    await api.updateEmergencyIncidentLocation(created.id, consent: false);

    expect(transport.requests.map((request) => request.url.path), [
      '/v1/rider/emergency-incidents',
      '/v1/rider/emergency-incidents/incident-mobile-001',
      '/v1/rider/emergency-incidents/incident-mobile-001/location',
    ]);
    final create = transport.requests.first;
    expect(create.headers['Idempotency-Key'], isNotEmpty);
    expect(jsonDecode(utf8.decode(create.body!)), {
      'category': 'SAFETY',
      'description': 'Rider requested urgent safety assistance',
      'priority': 'CRITICAL',
      'location_consent': true,
      'location': {'latitude': 13.08, 'longitude': 80.27, 'accuracy_m': 8.0},
    });
    expect(jsonDecode(utf8.decode(transport.requests.last.body!)), {
      'consent': false,
      'location': {'latitude': 0, 'longitude': 0, 'accuracy_m': 0},
    });
  });

  test(
    'controller requires fresh consented duty location and never queues SOS',
    () async {
      final remote = _EmergencyRemote();
      final tracker = _EmergencyTracker();
      final store = MemoryRiderCommandStore();
      final controller = RiderOperationsController(
        remote,
        locationTracker: tracker,
        commandStore: store,
      );
      await controller.load();
      await tracker.emit(
        RiderTrackedPosition(
          latitude: 13.08,
          longitude: 80.27,
          accuracyMeters: 8,
          capturedAt: DateTime.now().toUtc(),
        ),
      );

      await controller.createEmergencyIncident(
        category: 'SAFETY',
        description: 'Rider requested urgent safety assistance',
        locationConsent: true,
      );
      expect(controller.state.emergencyIncident?.id, 'incident-mobile-001');
      expect(remote.created, 1);

      remote.offline = true;
      await controller.createEmergencyIncident(
        category: 'SAFETY',
        description: 'Retry while transport is unavailable',
        locationConsent: true,
      );
      expect(controller.state.status, OperationsStatus.offline);
      expect(controller.state.message, contains('never queued offline'));
      expect(await store.pending(), isEmpty);
      controller.dispose();
    },
  );

  test('controller rejects an expired emergency location', () async {
    final remote = _EmergencyRemote();
    final tracker = _EmergencyTracker();
    final controller = RiderOperationsController(
      remote,
      locationTracker: tracker,
    );
    await controller.load();
    await tracker.emit(
      RiderTrackedPosition(
        latitude: 13.08,
        longitude: 80.27,
        accuracyMeters: 8,
        capturedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 3)),
      ),
    );
    await controller.createEmergencyIncident(
      category: 'SAFETY',
      description: 'Rider requested urgent safety assistance',
      locationConsent: true,
    );
    expect(controller.state.status, OperationsStatus.failure);
    expect(controller.state.message, contains('fresh on-duty location'));
    expect(remote.created, 0);
    controller.dispose();
  });

  testWidgets('rider SOS collects consent and shows incident status', (
    tester,
  ) async {
    final remote = _EmergencyRemote();
    final tracker = _EmergencyTracker();
    final controller = RiderOperationsController(
      remote,
      locationTracker: tracker,
    );
    await controller.load();
    await tracker.emit(
      RiderTrackedPosition(
        latitude: 13.08,
        longitude: 80.27,
        accuracyMeters: 8,
        capturedAt: DateTime.now().toUtc(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderOperationsView(
            controller: controller,
            destination: const RoleDestination(
              id: 'emergency',
              label: 'Emergency',
              icon: Icons.emergency_outlined,
              capability: RoleCapability.riderEmergency,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Use local emergency services first'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-rider-emergency')));
    await tester.pumpAndSettle();
    expect(find.text('Request emergency assistance?'), findsOneWidget);
    final confirm = find.byKey(const ValueKey('confirm-rider-emergency'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('rider-emergency-consent')));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Emergency incident active'), findsOneWidget);
    expect(
      find.textContaining('Awaiting an approved responder'),
      findsOneWidget,
    );
    expect(find.text('Stop location sharing'), findsOneWidget);
    controller.dispose();
  });
}

final class _StaticAuthSession implements ApiAuthSession {
  const _StaticAuthSession();
  @override
  Future<String?> accessToken() async => 'rider-access-token';
  @override
  Future<bool> refresh() async => false;
}

final class _EmergencyTransport implements ApiTransport {
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    final consent = request.url.path.endsWith('/location') ? false : true;
    return TransportResponse(
      statusCode: request.method == 'GET'
          ? 200
          : request.url.path.endsWith('/location')
          ? 200
          : 201,
      headers: const {'X-Correlation-ID': 'corr-emergency-server'},
      body: Uint8List.fromList(
        utf8.encode(jsonEncode(_incidentJson(consent: consent))),
      ),
    );
  }
}

final class _EmergencyRemote implements RiderOperationsRemote {
  bool offline = false;
  int created = 0;

  @override
  Future<RiderProfile> profile() async => const RiderProfile(
    id: 'rider-emergency-001',
    revision: 2,
    status: 'APPROVED',
    fullName: 'Ravi Rider',
    vehicleNumber: 'TN01AB1234',
    bankStatus: 'VERIFIED',
    zones: ['600001'],
    maxConcurrent: 2,
    allowedActions: {'VIEW_EARNINGS'},
  );

  @override
  Future<RiderDuty> duty() async => RiderDuty(
    id: 'duty-emergency-001',
    revision: 1,
    status: 'ACTIVE',
    zoneId: '600001',
    activeTasks: 0,
    lastSeenAt: DateTime.now().toUtc(),
  );

  @override
  Future<void> updateLocation(RiderLocationCommand command) async {}

  @override
  Future<EmergencyAssistance> createEmergencyIncident({
    required String category,
    required String description,
    required RiderTrackedPosition location,
  }) async {
    if (offline) throw const ApiTransportFailure(correlationId: 'offline-sos');
    created++;
    return EmergencyAssistance.fromJson(_incidentJson());
  }

  @override
  Future<EmergencyAssistance> emergencyIncident(String incidentId) async =>
      EmergencyAssistance.fromJson(_incidentJson());

  @override
  Future<EmergencyAssistance> updateEmergencyIncidentLocation(
    String incidentId, {
    required bool consent,
    RiderTrackedPosition? location,
  }) async => EmergencyAssistance.fromJson(_incidentJson(consent: consent));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _EmergencyTracker implements RiderLocationTracker {
  Future<void> Function(RiderTrackedPosition)? callback;

  @override
  Future<void> start(
    Future<void> Function(RiderTrackedPosition position) onPosition,
  ) async {
    callback = onPosition;
  }

  Future<void> emit(RiderTrackedPosition position) => callback!(position);

  @override
  Future<void> stop() async => callback = null;
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openServiceSettings() async {}
}

Map<String, Object?> _incidentJson({bool consent = true}) => {
  'id': 'incident-mobile-001',
  'revision': consent ? 1 : 2,
  'requester_id': 'rider-emergency-001',
  'category': 'SAFETY',
  'description': 'Rider requested urgent safety assistance',
  'priority': 'CRITICAL',
  'status': 'OPEN',
  'location_consent': consent,
  'escalation_level': 0,
  'sla_deadline': '2026-09-01T10:05:00Z',
  'allowed_actions': ['UPDATE_LOCATION', 'REVOKE_LOCATION'],
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-01T10:00:00Z',
};

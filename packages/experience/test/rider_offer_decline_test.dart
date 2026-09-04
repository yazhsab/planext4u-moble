import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('rider API sends a revisioned idempotent decline command', () async {
    final transport = _DeclineTransport();
    final api = RiderOperationsApi(
      ApiClient(
        baseUrl: Uri.parse('https://api.planext4u.test'),
        transport: transport,
        authSession: const _StaticAuthSession(),
        retryBudget: const ApiRetryBudget(maxAttempts: 1),
        correlationIdFactory: () => 'corr-rider-decline-test',
      ),
    );

    final result = await api.decline(
      _offer,
      reason: RiderOfferDeclineReason.safetyConcern,
      note: 'Unsafe road conditions',
    );

    final request = transport.requests.single;
    expect(request.url.path, '/v1/rider/offers/task-decline-001/decline');
    expect(request.headers['If-Match'], '"2"');
    expect(request.headers['Idempotency-Key'], isNotEmpty);
    expect(request.headers['Authorization'], 'Bearer rider-access-token');
    expect(jsonDecode(utf8.decode(request.body!)), {
      'reason_code': 'SAFETY_CONCERN',
      'note': 'Unsafe road conditions',
    });
    expect(result.reason, RiderOfferDeclineReason.safetyConcern);
  });

  test('decline removes only the offer and is never queued offline', () async {
    final remote = _DeclineRemote();
    final store = MemoryRiderCommandStore();
    final controller = RiderOperationsController(remote, commandStore: store);
    await controller.load();
    await controller.refreshTasks();

    await controller.decline(_offer, reason: RiderOfferDeclineReason.tooFar);
    expect(controller.state.offers, isEmpty);
    expect(controller.state.message, 'Offer declined.');
    expect(remote.reasons, [RiderOfferDeclineReason.tooFar]);

    remote
      ..failed = true
      ..visible = true;
    await controller.refreshTasks();
    await controller.decline(
      _offer,
      reason: RiderOfferDeclineReason.endingDuty,
    );
    expect(controller.state.status, OperationsStatus.offline);
    expect(controller.state.pendingCommands, 0);
    expect(await store.pending(), isEmpty);
    expect(controller.state.message, contains('was not queued'));
    controller.dispose();
  });

  testWidgets('rider offer card collects and submits a decline reason', (
    tester,
  ) async {
    final remote = _DeclineRemote();
    final controller = RiderOperationsController(remote);
    await controller.load();
    await controller.refreshTasks();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderOperationsView(
            controller: controller,
            destination: const RoleDestination(
              id: 'assignments',
              label: 'Tasks',
              icon: Icons.route_outlined,
              capability: RoleCapability.riderAssignments,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('decline-task-decline-001')));
    await tester.pumpAndSettle();
    expect(find.text('Decline delivery offer?'), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-decline-reason')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-offer-decline')));
    await tester.pumpAndSettle();

    expect(remote.reasons, [RiderOfferDeclineReason.tooFar]);
    expect(find.text('No delivery offers'), findsOneWidget);
    controller.dispose();
  });
}

final _offer = RiderTask(
  id: 'task-decline-001',
  revision: 2,
  orderId: 'order-decline-001',
  orderType: 'FOOD',
  status: 'OFFERED',
  pickupLabel: 'Central kitchen',
  dropoffLabel: 'Anna Nagar',
  distanceMeters: 4200,
  earning: const CatalogMoney(amountMinor: 8500, currency: 'INR'),
  offerExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
  allowedActions: const {'ACCEPT', 'DECLINE'},
  podAssetId: '',
);

final class _StaticAuthSession implements ApiAuthSession {
  const _StaticAuthSession();
  @override
  Future<String?> accessToken() async => 'rider-access-token';
  @override
  Future<bool> refresh() async => false;
}

final class _DeclineTransport implements ApiTransport {
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 201,
      headers: const {'X-Correlation-ID': 'corr-decline-server'},
      body: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'task_id': _offer.id,
            'task_revision': _offer.revision,
            'reason_code': 'SAFETY_CONCERN',
            'note': 'Unsafe road conditions',
            'declined_at': '2026-09-01T10:00:00Z',
          }),
        ),
      ),
    );
  }
}

final class _DeclineRemote implements RiderOperationsRemote {
  bool failed = false;
  bool visible = true;
  final reasons = <RiderOfferDeclineReason>[];

  @override
  Future<RiderProfile> profile() async => const RiderProfile(
    id: 'rider-decline-001',
    revision: 2,
    status: 'APPROVED',
    fullName: 'Ravi Rider',
    vehicleNumber: 'TN01AB1234',
    bankStatus: 'VERIFIED',
    zones: ['600001'],
    maxConcurrent: 2,
    allowedActions: {'START_DUTY'},
  );

  @override
  Future<RiderDuty> duty() async => throw StateError('off duty');
  @override
  Future<List<RiderTask>> offers() async => visible ? [_offer] : const [];
  @override
  Future<List<RiderTask>> tasks() async => const [];

  @override
  Future<RiderOfferDecline> decline(
    RiderTask task, {
    required RiderOfferDeclineReason reason,
    String note = '',
  }) async {
    if (failed) throw const ApiTransportFailure(correlationId: 'offline');
    reasons.add(reason);
    visible = false;
    return RiderOfferDecline(
      taskId: task.id,
      taskRevision: task.revision,
      reason: reason,
      declinedAt: DateTime.now().toUtc(),
      note: note,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

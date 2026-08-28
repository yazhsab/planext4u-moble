import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_rider/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'MOB-E2E-007 rider duty concurrent offer offline recovery POD and earnings',
    (tester) async {
      final remote = _RiderJourneyRemote();
      final commands = MemoryRiderCommandStore();
      final controller = RiderOperationsController(
        remote,
        commandStore: commands,
      );
      await controller.load();
      await controller.startDuty();
      final offer = controller.state.offers.single;
      await controller.accept(offer);
      expect(controller.state.tasks.single.status, 'ASSIGNED');
      await expectLater(
        remote.accept(offer),
        throwsA(isA<ApiConflictFailure>()),
      );

      final assigned = controller.state.tasks.single;
      await controller.pickup(assigned);
      expect(controller.state.pendingCommands, 1);
      expect((await commands.pending()).single.deviceSequence, 1);
      await controller.recoverOffline();
      expect(controller.state.pendingCommands, 0);
      final pickedUp = controller.state.tasks.single;
      expect(pickedUp.status, 'PICKED_UP');
      await controller.complete(pickedUp, otp: '135790');
      expect(controller.state.tasks.single.status, 'DELIVERED');
      await controller.openChat(pickedUp.orderId);
      await controller.sendMessage('Please call +91 98765 43210');
      expect(controller.state.conversation?.messages.single.redacted, isTrue);
      expect(
        controller.state.conversation?.messages.single.body,
        '[contact redacted]',
      );
      await controller.loadSettlements();

      await tester.pumpWidget(
        RiderApp(
          config: AppConfig.parse(
            rawEnvironment: 'development',
            rawApiBaseUrl: 'http://10.0.2.2:8080',
          ),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.textContaining('DELIVERED'), findsOneWidget);
      expect(find.text('Delivery evidence verified'), findsOneWidget);
      await tester.tap(find.text('Earnings'));
      await tester.pumpAndSettle();
      expect(find.text('₹70.56'), findsWidgets);
      expect(find.textContaining('rider-commission-v1'), findsOneWidget);
      expect(
        remote.evidence,
        containsAllInOrder([
          'profile',
          'duty_start',
          'offers',
          'tasks',
          'atomic_accept_winner',
          'atomic_accept_conflict',
          'pickup_offline',
          'ordered_recovery',
          'offers',
          'tasks',
          'pod_photo_otp',
          'chat_open',
          'chat_redaction',
          'chat_open',
          'ledger_reconciled',
          'payout_status',
        ]),
      );
    },
  );
}

final class _RiderJourneyRemote implements RiderOperationsRemote {
  final evidence = <String>[];
  var _accepted = false;
  var _pickupOffline = true;
  var _status = 'OFFERED';
  var _revision = 1;
  final List<ChatMessageRecord> _messages = [];

  RiderTask get task => RiderTask(
    id: 'delivery-e2e-007',
    revision: _revision,
    orderId: 'food-order-e2e-005',
    orderType: 'FOOD',
    status: _status,
    pickupLabel: 'Saravana Kitchen',
    dropoffLabel: 'Customer',
    distanceMeters: 4800,
    earning: const CatalogMoney(amountMinor: 8000, currency: 'INR'),
    offerExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    allowedActions: switch (_status) {
      'OFFERED' => const {'ACCEPT'},
      'ASSIGNED' => const {'NAVIGATE_PICKUP', 'MARK_PICKED_UP'},
      'PICKED_UP' => const {'COMPLETE'},
      _ => const {},
    },
    podAssetId: _status == 'DELIVERED' ? 'asset-blurred-pod-e2e-007' : '',
  );

  @override
  Future<RiderProfile> profile() async {
    evidence.add('profile');
    return const RiderProfile(
      id: 'rider-profile-e2e-007',
      revision: 2,
      status: 'APPROVED',
      fullName: 'Synthetic Rider',
      vehicleNumber: 'TN01AB1234',
      bankStatus: 'VERIFIED',
      zones: ['600001'],
      maxConcurrent: 2,
      allowedActions: {'START_DUTY', 'VIEW_EARNINGS'},
    );
  }

  @override
  Future<RiderDuty> duty() async => throw StateError('off duty');
  @override
  Future<RiderDuty> startDuty(String zoneId) async {
    evidence.add('duty_start');
    return RiderDuty(
      id: 'duty-e2e-007',
      revision: 1,
      status: 'ACTIVE',
      zoneId: zoneId,
      activeTasks: 0,
      lastSeenAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<RiderTask>> offers() async {
    evidence.add('offers');
    return _status == 'OFFERED' ? [task] : const [];
  }

  @override
  Future<List<RiderTask>> tasks() async {
    evidence.add('tasks');
    return _status == 'OFFERED' ? const [] : [task];
  }

  @override
  Future<RiderTask> accept(RiderTask value) async {
    if (_accepted) {
      evidence.add('atomic_accept_conflict');
      throw const ApiConflictFailure(
        code: 'OFFER_ALREADY_ACCEPTED',
        message: 'Offer was accepted atomically.',
        correlationId: 'e2e-007-conflict',
        retryable: false,
        statusCode: 409,
      );
    }
    _accepted = true;
    _status = 'ASSIGNED';
    _revision++;
    evidence.add('atomic_accept_winner');
    return task;
  }

  @override
  Future<RiderTask> pickup(RiderTask value) async {
    if (_pickupOffline) {
      _pickupOffline = false;
      evidence.add('pickup_offline');
      throw const ApiTransportFailure(correlationId: 'e2e-007-offline');
    }
    _status = 'PICKED_UP';
    _revision++;
    return task;
  }

  @override
  Future<List<Map<String, Object?>>> recover(
    List<RiderOfflineCommand> commands,
  ) async {
    expect(commands.map((value) => value.deviceSequence), orderedEquals([1]));
    evidence.add('ordered_recovery');
    _status = 'PICKED_UP';
    _revision++;
    return [
      for (final command in commands)
        {'command_id': command.commandId, 'status': 'APPLIED'},
    ];
  }

  @override
  Future<RiderTask> complete(
    RiderTask value, {
    required String otp,
    required String blurredPhotoAssetId,
    String signatureAssetId = '',
  }) async {
    expect(otp, '135790');
    expect(blurredPhotoAssetId, startsWith('asset-blurred'));
    evidence.add('pod_photo_otp');
    _status = 'DELIVERED';
    _revision++;
    return task;
  }

  @override
  Future<OrderConversation> conversation(String orderId) async {
    evidence.add('chat_open');
    return OrderConversation(
      id: 'chat-e2e-007',
      orderId: orderId,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      blocked: false,
      messages: List.unmodifiable(_messages),
    );
  }

  @override
  Future<ChatMessageRecord> sendMessage(
    String conversationId,
    String body,
  ) async {
    evidence.add('chat_redaction');
    final message = ChatMessageRecord(
      id: 'message-e2e-007',
      senderId: 'rider-synthetic-001',
      body: '[contact redacted]',
      redacted: true,
      createdAt: DateTime.now().toUtc(),
    );
    _messages.add(message);
    return message;
  }

  @override
  Future<List<SettlementEntry>> ledger() async {
    evidence.add('ledger_reconciled');
    return [
      SettlementEntry(
        id: 'ledger-e2e-007',
        kind: 'DELIVERY_EARNING',
        referenceId: task.id,
        gross: const CatalogMoney(amountMinor: 8000, currency: 'INR'),
        commission: const CatalogMoney(amountMinor: 800, currency: 'INR'),
        tax: const CatalogMoney(amountMinor: 144, currency: 'INR'),
        net: const CatalogMoney(amountMinor: 7056, currency: 'INR'),
        calculationVersion: 'rider-commission-v1',
        availableAt: DateTime.utc(2026, 8, 27),
      ),
    ];
  }

  @override
  Future<List<PayoutRecord>> payouts() async {
    evidence.add('payout_status');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

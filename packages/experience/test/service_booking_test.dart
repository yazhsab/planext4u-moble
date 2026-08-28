import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('pinned Phase 4 service booking fixture decodes server truth', () {
    final booking = ServiceBooking.fromJson(_fixture());
    expect(booking.status, 'REQUESTED');
    expect(booking.offering.verifiedProvider, isTrue);
    expect(booking.slot.remaining, 1);
    expect(booking.amountDue.display(), '₹50.00');
    expect(booking.payment.status, 'CAPTURED');
    expect(booking.allowedActions, containsAll(['RESCHEDULE', 'CANCEL']));
  });

  test(
    'controller completes lock, reschedule, OTP and evidence lifecycle',
    () async {
      final remote = _BookingRemote();
      final controller = ServiceBookingController(remote: remote);
      await controller.loadOfferings(postalCode: '600001');
      expect(controller.state.offerings.single.verifiedProvider, isTrue);
      await controller.selectOffering(remote.offeringValue);
      expect(controller.state.slots, hasLength(2));
      final hold = await controller.hold(remote.slotsValue.first);
      expect(hold?.status, 'HELD');
      var booking = await controller.create(ServicePaymentMethod.wallet);
      expect(booking?.status, 'REQUESTED');
      booking = await controller.reschedule(
        booking!,
        remote.slotsValue.last,
        'Customer schedule changed',
      );
      expect(booking?.rescheduleCount, 1);
      expect(booking?.slot.id, 'slot-synthetic-002');
      booking = await controller.providerTransition(booking!, 'ACCEPTED');
      booking = await controller.providerTransition(
        booking!,
        'PROVIDER_EN_ROUTE',
      );
      booking = await controller.providerTransition(booking!, 'ARRIVED');
      booking = await controller.providerTransition(
        booking!,
        'START_OTP_REQUIRED',
      );
      expect(booking?.startOtp, '482613');
      expect(await controller.start(booking!, '123'), isNull);
      booking = await controller.start(booking, booking.startOtp!);
      expect(booking?.status, 'IN_PROGRESS');
      booking = await controller.providerTransition(
        booking!,
        'COMPLETION_EVIDENCE_REQUIRED',
      );
      booking = await controller.complete(booking!, 'asset-completion-001');
      expect(booking?.completionEvidence?.photoAssetId, 'asset-completion-001');
      booking = await controller.confirmCompletion(booking!);
      expect(booking?.status, 'COMPLETED');
      expect(remote.transitions, [
        'REQUESTED',
        'ACCEPTED',
        'PROVIDER_EN_ROUTE',
        'ARRIVED',
        'START_OTP_REQUIRED',
        'IN_PROGRESS',
        'COMPLETION_EVIDENCE_REQUIRED',
        'COMPLETED_PENDING_CONFIRMATION',
        'COMPLETED',
      ]);
    },
  );

  testWidgets('booking UI fits a narrow viewport at 130% text', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = ServiceBookingController(remote: _BookingRemote());
    await tester.pumpWidget(
      MaterialApp(
        home: ServiceBookingScreen(
          controller: controller,
          postalCode: '600001',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home deep cleaning'), findsOneWidget);
    expect(find.text('Verified provider'), findsOneWidget);
    await tester.tap(find.text('Home deep cleaning'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an appointment'), findsOneWidget);
    expect(controller.state.slots, hasLength(2));
    await tester.drag(find.byType(ListView).last, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.textContaining('appointments left'), findsWidgets);
    final firstSlot = find.byType(RadioListTile<String>).first;
    await tester.ensureVisible(firstSlot);
    await tester.pumpAndSettle();
    await tester.tap(firstSlot);
    await tester.pumpAndSettle();
    expect(controller.state.hold, isNotNull);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Time held for'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-service-booking')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Planext points'), findsOneWidget);
    expect(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}

Object? _fixture() => jsonDecode(
  File(
    '${_workspaceRoot().path}/packages/api_client/contracts/service_booking.fixture.json',
  ).readAsStringSync(),
);

Directory _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (directory.parent.path != directory.path) {
    if (File(
      '${directory.path}/packages/api_client/contracts/booking.openapi.json',
    ).existsSync()) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Workspace not found.');
}

final class _BookingRemote implements ServiceBookingRemote {
  _BookingRemote() {
    _booking = _decodeBooking(_baseBooking());
  }

  late ServiceBooking _booking;
  int _revision = 1;
  int _holdSequence = 0;
  final transitions = <String>[];

  late final offeringValue = ServiceOffering.fromJson(
    _baseBooking()['offering'],
  );
  late final slotsValue = [
    ServiceSlot.fromJson(_baseBooking()['slot']),
    ServiceSlot.fromJson({
      ...(_baseBooking()['slot']! as Map<String, Object?>),
      'id': 'slot-synthetic-002',
      'starts_at': '2026-08-30T10:00:00Z',
      'ends_at': '2026-08-30T12:00:00Z',
      'service_date': '2026-08-30',
      'remaining': 2,
      'provider_version': 2,
    }),
  ];

  Map<String, Object?> _baseBooking() =>
      (jsonDecode(jsonEncode(_fixture()))! as Map).cast<String, Object?>();

  ServiceBooking _decodeBooking(Map<String, Object?> value) =>
      ServiceBooking.fromJson(value);

  ServiceBooking _transition(
    String status, {
    Set<String> actions = const {},
    ServiceSlot? slot,
    int? rescheduleCount,
    String? startOtp,
    String? photoAssetId,
  }) {
    _revision++;
    transitions.add(status);
    final json = _baseBooking();
    json['revision'] = _revision;
    json['status'] = status;
    json['slot'] = _slotJson(slot ?? _booking.slot);
    json['reschedule_count'] = rescheduleCount ?? _booking.rescheduleCount;
    json['free_reschedules_left'] =
        1 - (rescheduleCount ?? _booking.rescheduleCount);
    json['allowed_actions'] = actions.toList(growable: false);
    json['timeline'] = [
      for (final event in _booking.timeline)
        {
          'status': event.status,
          'actor': event.actor,
          if (event.reason.isNotEmpty) 'reason': event.reason,
          'created_at': event.createdAt.toIso8601String(),
        },
      {
        'status': status,
        'actor': status == 'COMPLETED' ? 'CUSTOMER' : 'PROVIDER',
        'created_at': '2026-08-28T11:00:00Z',
      },
    ];
    if (startOtp != null) json['start_otp'] = startOtp;
    if (photoAssetId != null) {
      json['completion_evidence'] = {
        'photo_asset_id': photoAssetId,
        'captured_at': '2026-08-28T11:00:00Z',
        'submitted_by': 'provider-synthetic-001',
      };
    } else if (_booking.completionEvidence != null) {
      json['completion_evidence'] = {
        'photo_asset_id': _booking.completionEvidence!.photoAssetId,
        'captured_at': _booking.completionEvidence!.capturedAt
            .toIso8601String(),
        'submitted_by': _booking.completionEvidence!.submittedBy,
      };
    }
    _booking = _decodeBooking(json);
    return _booking;
  }

  Map<String, Object?> _slotJson(ServiceSlot slot) => {
    'id': slot.id,
    'offering_id': slot.offeringId,
    'provider_id': slot.providerId,
    'starts_at': slot.startsAt.toIso8601String(),
    'ends_at': slot.endsAt.toIso8601String(),
    'time_zone': slot.timeZone,
    'capacity': slot.capacity,
    'remaining': slot.remaining,
    'buffer_minutes': slot.bufferMinutes,
    'price': {
      'amount_minor': slot.price.amountMinor,
      'currency': slot.price.currency,
    },
    'advance': {
      'amount_minor': slot.advance.amountMinor,
      'currency': slot.advance.currency,
    },
    'allowed_actions': slot.allowedActions.toList(growable: false),
    'policy_version': slot.policyVersion,
    'service_date': slot.serviceDate,
    'provider_version': slot.providerVersion,
  };

  @override
  Future<List<ServiceOffering>> offerings({
    required String postalCode,
    String? categoryId,
  }) async => postalCode == '600001' ? [offeringValue] : [];
  @override
  Future<ServiceOffering> offering(
    String id, {
    required String postalCode,
  }) async => offeringValue;
  @override
  Future<List<ServiceSlot>> slots(
    String offeringId, {
    DateTime? from,
    DateTime? to,
  }) async => slotsValue;
  @override
  Future<ServiceSlotHold> hold({
    required String slotId,
    required String postalCode,
  }) async {
    _holdSequence++;
    return ServiceSlotHold.fromJson({
      'id': 'hold-synthetic-$_holdSequence',
      'slot_id': slotId,
      'offering_id': offeringValue.id,
      'status': 'HELD',
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'allowed_actions': ['RELEASE', 'CREATE_BOOKING'],
    });
  }

  @override
  Future<void> releaseHold(String id) async {}
  @override
  Future<List<ServiceBooking>> bookings() async => [_booking];
  @override
  Future<ServiceBooking> booking(String id) async => _booking;
  @override
  Future<ServiceBooking> create({
    required String holdId,
    required ServicePaymentMethod paymentMethod,
  }) async => _booking;
  @override
  Future<ServiceBooking> confirmPayment(ServiceBooking booking) async =>
      _transition('REQUESTED', actions: {'RESCHEDULE', 'CANCEL'});
  @override
  Future<ServiceBooking> reschedule({
    required ServiceBooking booking,
    required String holdId,
    required String reason,
  }) async => _transition(
    'REQUESTED',
    actions: {'RESCHEDULE', 'CANCEL'},
    slot: slotsValue.last,
    rescheduleCount: booking.rescheduleCount + 1,
  );
  @override
  Future<ServiceBooking> cancel({
    required ServiceBooking booking,
    required String reason,
  }) async => _transition('CANCELLED');
  @override
  Future<ServiceBooking> providerTransition({
    required ServiceBooking booking,
    required String status,
    String reason = '',
  }) async => _transition(
    status,
    actions: status == 'COMPLETED_PENDING_CONFIRMATION'
        ? {'CONFIRM_COMPLETION', 'DISPUTE'}
        : const {},
    startOtp: status == 'START_OTP_REQUIRED' ? '482613' : booking.startOtp,
  );
  @override
  Future<ServiceBooking> start({
    required ServiceBooking booking,
    required String otp,
  }) async => _transition('IN_PROGRESS');
  @override
  Future<ServiceBooking> complete({
    required ServiceBooking booking,
    required String photoAssetId,
  }) async => _transition(
    'COMPLETED_PENDING_CONFIRMATION',
    actions: {'CONFIRM_COMPLETION', 'DISPUTE'},
    photoAssetId: photoAssetId,
  );
  @override
  Future<ServiceBooking> confirmCompletion(ServiceBooking booking) async =>
      _transition('COMPLETED');
  @override
  Future<ServiceBooking> noShow({
    required ServiceBooking booking,
    required String reason,
  }) async => _transition('CUSTOMER_NO_SHOW');
  @override
  Future<ServiceBooking> dispute({
    required ServiceBooking booking,
    required String reason,
  }) async => _transition('DISPUTED');
}

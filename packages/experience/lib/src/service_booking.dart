import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'catalog.dart';
import 'transactions.dart';

enum ServicePaymentMethod {
  razorpay('RAZORPAY', 'Razorpay'),
  paystack('PAYSTACK', 'Paystack'),
  wallet('WALLET', 'Planext points');

  const ServicePaymentMethod(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

final class ServiceOffering {
  const ServiceOffering({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.categoryId,
    required this.name,
    required this.summary,
    required this.durationMinutes,
    required this.price,
    required this.advance,
    required this.paymentMode,
    required this.verifiedProvider,
    required this.ratingAverage,
    required this.completedBookings,
    required this.liveEngagements,
    required this.servicePostalCodes,
    required this.cancellationPolicyRef,
    required this.reschedulePolicyRef,
    required this.active,
  });

  factory ServiceOffering.fromJson(Object? value) {
    final json = _bookingObject(value, 'service offering');
    final rating = _bookingNumber(json, 'rating_average');
    final duration = _bookingInteger(json, 'duration_minutes');
    if (rating < 0 || rating > 5 || duration < 15) {
      throw const FormatException('Service offering trust data is invalid.');
    }
    return ServiceOffering(
      id: _bookingString(json, 'id'),
      providerId: _bookingString(json, 'provider_id'),
      providerName: _bookingString(json, 'provider_name'),
      categoryId: _bookingString(json, 'category_id'),
      name: _bookingString(json, 'name'),
      summary: _bookingString(json, 'summary'),
      durationMinutes: duration,
      price: CatalogMoney.fromJson(json['price']),
      advance: CatalogMoney.fromJson(json['advance']),
      paymentMode: _bookingString(json, 'payment_mode'),
      verifiedProvider: _bookingBoolean(json, 'verified_provider'),
      ratingAverage: rating,
      completedBookings: _bookingInteger(json, 'completed_bookings'),
      liveEngagements: _bookingInteger(json, 'live_engagements'),
      servicePostalCodes: List<String>.unmodifiable(
        _bookingList(json, 'service_postal_codes').cast<String>(),
      ),
      cancellationPolicyRef: _bookingString(json, 'cancellation_policy_ref'),
      reschedulePolicyRef: _bookingString(json, 'reschedule_policy_ref'),
      active: _bookingBoolean(json, 'active'),
    );
  }

  final String id;
  final String providerId;
  final String providerName;
  final String categoryId;
  final String name;
  final String summary;
  final int durationMinutes;
  final CatalogMoney price;
  final CatalogMoney advance;
  final String paymentMode;
  final bool verifiedProvider;
  final double ratingAverage;
  final int completedBookings;
  final int liveEngagements;
  final List<String> servicePostalCodes;
  final String cancellationPolicyRef;
  final String reschedulePolicyRef;
  final bool active;
}

final class ServiceSlot {
  const ServiceSlot({
    required this.id,
    required this.offeringId,
    required this.providerId,
    required this.startsAt,
    required this.endsAt,
    required this.timeZone,
    required this.capacity,
    required this.remaining,
    required this.bufferMinutes,
    required this.price,
    required this.advance,
    required this.allowedActions,
    required this.policyVersion,
    required this.serviceDate,
    required this.providerVersion,
  });

  factory ServiceSlot.fromJson(Object? value) {
    final json = _bookingObject(value, 'service slot');
    final startsAt = _bookingInstant(json, 'starts_at');
    final endsAt = _bookingInstant(json, 'ends_at');
    final capacity = _bookingInteger(json, 'capacity');
    final remaining = _bookingInteger(json, 'remaining');
    if (!endsAt.isAfter(startsAt) ||
        capacity < 1 ||
        remaining < 0 ||
        remaining > capacity) {
      throw const FormatException('Service slot capacity is invalid.');
    }
    return ServiceSlot(
      id: _bookingString(json, 'id'),
      offeringId: _bookingString(json, 'offering_id'),
      providerId: _bookingString(json, 'provider_id'),
      startsAt: startsAt,
      endsAt: endsAt,
      timeZone: _bookingString(json, 'time_zone'),
      capacity: capacity,
      remaining: remaining,
      bufferMinutes: _bookingInteger(json, 'buffer_minutes'),
      price: CatalogMoney.fromJson(json['price']),
      advance: CatalogMoney.fromJson(json['advance']),
      allowedActions: Set<String>.unmodifiable(
        _bookingList(json, 'allowed_actions').cast<String>(),
      ),
      policyVersion: _bookingString(json, 'policy_version'),
      serviceDate: _bookingString(json, 'service_date'),
      providerVersion: _bookingInteger(json, 'provider_version'),
    );
  }

  final String id;
  final String offeringId;
  final String providerId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timeZone;
  final int capacity;
  final int remaining;
  final int bufferMinutes;
  final CatalogMoney price;
  final CatalogMoney advance;
  final Set<String> allowedActions;
  final String policyVersion;
  final String serviceDate;
  final int providerVersion;

  bool get canHold => remaining > 0 && allowedActions.contains('HOLD');
}

final class ServiceSlotHold {
  const ServiceSlotHold({
    required this.id,
    required this.slotId,
    required this.offeringId,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.allowedActions,
  });

  factory ServiceSlotHold.fromJson(Object? value) {
    final json = _bookingObject(value, 'service slot hold');
    return ServiceSlotHold(
      id: _bookingString(json, 'id'),
      slotId: _bookingString(json, 'slot_id'),
      offeringId: _bookingString(json, 'offering_id'),
      status: _bookingString(json, 'status'),
      expiresAt: _bookingInstant(json, 'expires_at'),
      createdAt: _bookingInstant(json, 'created_at'),
      allowedActions: Set<String>.unmodifiable(
        _bookingList(json, 'allowed_actions').cast<String>(),
      ),
    );
  }

  final String id;
  final String slotId;
  final String offeringId;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final Set<String> allowedActions;

  Duration remainingAt(DateTime now) {
    final remaining = expiresAt.difference(now.toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

final class ServiceBookingTimelineEvent {
  const ServiceBookingTimelineEvent({
    required this.status,
    required this.actor,
    required this.createdAt,
    this.reason = '',
  });

  factory ServiceBookingTimelineEvent.fromJson(Object? value) {
    final json = _bookingObject(value, 'service booking timeline event');
    return ServiceBookingTimelineEvent(
      status: _bookingString(json, 'status'),
      actor: _bookingString(json, 'actor'),
      reason: json['reason'] as String? ?? '',
      createdAt: _bookingInstant(json, 'created_at'),
    );
  }

  final String status;
  final String actor;
  final String reason;
  final DateTime createdAt;
}

final class ServiceCompletionEvidence {
  const ServiceCompletionEvidence({
    required this.photoAssetId,
    required this.capturedAt,
    required this.submittedBy,
  });

  factory ServiceCompletionEvidence.fromJson(Object? value) {
    final json = _bookingObject(value, 'service completion evidence');
    return ServiceCompletionEvidence(
      photoAssetId: _bookingString(json, 'photo_asset_id'),
      capturedAt: _bookingInstant(json, 'captured_at'),
      submittedBy: _bookingString(json, 'submitted_by'),
    );
  }

  final String photoAssetId;
  final DateTime capturedAt;
  final String submittedBy;
}

final class ServiceBooking {
  const ServiceBooking({
    required this.id,
    required this.revision,
    required this.status,
    required this.offering,
    required this.slot,
    required this.price,
    required this.amountDue,
    required this.payment,
    required this.rescheduleCount,
    required this.freeReschedulesLeft,
    required this.allowedActions,
    required this.timeline,
    required this.createdAt,
    required this.updatedAt,
    this.startOtp,
    this.completionEvidence,
  });

  factory ServiceBooking.fromJson(Object? value) {
    final json = _bookingObject(value, 'service booking');
    final otp = json['start_otp'];
    if (otp != null &&
        (otp is! String || !RegExp(r'^[0-9]{6}$').hasMatch(otp))) {
      throw const FormatException('Service start code is invalid.');
    }
    return ServiceBooking(
      id: _bookingString(json, 'id'),
      revision: _bookingInteger(json, 'revision'),
      status: _bookingString(json, 'status'),
      offering: ServiceOffering.fromJson(json['offering']),
      slot: ServiceSlot.fromJson(json['slot']),
      price: CatalogMoney.fromJson(json['price']),
      amountDue: CatalogMoney.fromJson(json['amount_due']),
      payment: CustomerPayment.fromJson(json['payment']),
      startOtp: otp as String?,
      completionEvidence: json['completion_evidence'] == null
          ? null
          : ServiceCompletionEvidence.fromJson(json['completion_evidence']),
      rescheduleCount: _bookingInteger(json, 'reschedule_count'),
      freeReschedulesLeft: _bookingInteger(json, 'free_reschedules_left'),
      allowedActions: Set<String>.unmodifiable(
        _bookingList(json, 'allowed_actions').cast<String>(),
      ),
      timeline: List<ServiceBookingTimelineEvent>.unmodifiable(
        _bookingList(
          json,
          'timeline',
        ).map(ServiceBookingTimelineEvent.fromJson),
      ),
      createdAt: _bookingInstant(json, 'created_at'),
      updatedAt: _bookingInstant(json, 'updated_at'),
    );
  }

  final String id;
  final int revision;
  final String status;
  final ServiceOffering offering;
  final ServiceSlot slot;
  final CatalogMoney price;
  final CatalogMoney amountDue;
  final CustomerPayment payment;
  final String? startOtp;
  final ServiceCompletionEvidence? completionEvidence;
  final int rescheduleCount;
  final int freeReschedulesLeft;
  final Set<String> allowedActions;
  final List<ServiceBookingTimelineEvent> timeline;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool allows(String action) => allowedActions.contains(action);
}

abstract interface class ServiceBookingRemote {
  Future<List<ServiceOffering>> offerings({
    required String postalCode,
    String? categoryId,
  });
  Future<ServiceOffering> offering(String id, {required String postalCode});
  Future<List<ServiceSlot>> slots(
    String offeringId, {
    DateTime? from,
    DateTime? to,
  });
  Future<ServiceSlotHold> hold({
    required String slotId,
    required String postalCode,
  });
  Future<void> releaseHold(String id);
  Future<List<ServiceBooking>> bookings();
  Future<ServiceBooking> booking(String id);
  Future<ServiceBooking> create({
    required String holdId,
    required ServicePaymentMethod paymentMethod,
  });
  Future<ServiceBooking> confirmPayment(ServiceBooking booking);
  Future<ServiceBooking> reschedule({
    required ServiceBooking booking,
    required String holdId,
    required String reason,
  });
  Future<ServiceBooking> cancel({
    required ServiceBooking booking,
    required String reason,
  });
  Future<ServiceBooking> providerTransition({
    required ServiceBooking booking,
    required String status,
    String reason = '',
  });
  Future<ServiceBooking> start({
    required ServiceBooking booking,
    required String otp,
  });
  Future<ServiceBooking> complete({
    required ServiceBooking booking,
    required String photoAssetId,
  });
  Future<ServiceBooking> confirmCompletion(ServiceBooking booking);
  Future<ServiceBooking> noShow({
    required ServiceBooking booking,
    required String reason,
  });
  Future<ServiceBooking> dispute({
    required ServiceBooking booking,
    required String reason,
  });
}

final class ServiceBookingApi implements ServiceBookingRemote {
  const ServiceBookingApi(this._client);

  final ApiClient _client;

  @override
  Future<List<ServiceOffering>> offerings({
    required String postalCode,
    String? categoryId,
  }) => _list(
    ApiRequest.get(
      operation: 'booking.list_offerings',
      path: '/v1/services',
      query: {
        'postal_code': [postalCode.trim()],
        if (categoryId?.trim().isNotEmpty ?? false)
          'category_id': [categoryId!.trim()],
      },
    ),
    ServiceOffering.fromJson,
  );

  @override
  Future<ServiceOffering> offering(
    String id, {
    required String postalCode,
  }) async => (await _client.send(
    ApiRequest.get(
      operation: 'booking.get_offering',
      path: '/v1/services/${Uri.encodeComponent(id)}',
      query: {
        'postal_code': [postalCode.trim()],
      },
    ),
    ServiceOffering.fromJson,
  )).value;

  @override
  Future<List<ServiceSlot>> slots(
    String offeringId, {
    DateTime? from,
    DateTime? to,
  }) => _list(
    ApiRequest.get(
      operation: 'booking.list_slots',
      path: '/v1/services/${Uri.encodeComponent(offeringId)}/slots',
      query: {
        if (from != null) 'from': [from.toUtc().toIso8601String()],
        if (to != null) 'to': [to.toUtc().toIso8601String()],
      },
    ),
    ServiceSlot.fromJson,
  );

  @override
  Future<ServiceSlotHold> hold({
    required String slotId,
    required String postalCode,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'booking.hold_slot',
      method: 'POST',
      path: '/v1/service-slot-holds',
      body: {'slot_id': slotId, 'postal_code': postalCode.trim()},
    ),
    ServiceSlotHold.fromJson,
  )).value;

  @override
  Future<void> releaseHold(String id) async {
    await _client.send(
      ApiRequest.command(
        operation: 'booking.release_slot_hold',
        method: 'DELETE',
        path: '/v1/service-slot-holds/${Uri.encodeComponent(id)}',
        body: null,
      ),
      (_) {},
    );
  }

  @override
  Future<List<ServiceBooking>> bookings() => _list(
    ApiRequest.get(
      operation: 'booking.list_bookings',
      path: '/v1/service-bookings',
    ),
    ServiceBooking.fromJson,
  );

  @override
  Future<ServiceBooking> booking(String id) async => (await _client.send(
    ApiRequest.get(
      operation: 'booking.get_booking',
      path: '/v1/service-bookings/${Uri.encodeComponent(id)}',
    ),
    ServiceBooking.fromJson,
  )).value;

  @override
  Future<ServiceBooking> create({
    required String holdId,
    required ServicePaymentMethod paymentMethod,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'booking.create_booking',
      method: 'POST',
      path: '/v1/service-bookings',
      body: {'hold_id': holdId, 'payment_method': paymentMethod.wireValue},
    ),
    ServiceBooking.fromJson,
  )).value;

  Future<List<T>> _list<T>(
    ApiRequest request,
    T Function(Object?) decode,
  ) async => (await _client.send(
    request,
    (value) => List<T>.unmodifiable(
      _bookingList(_bookingObject(value, 'booking list'), 'items').map(decode),
    ),
  )).value;

  Future<ServiceBooking> _bookingCommand(
    ServiceBooking booking,
    String operation,
    String suffix,
    Object? body,
  ) async => (await _client.send(
    ApiRequest.command(
      operation: operation,
      method: 'POST',
      path: '/v1/service-bookings/${Uri.encodeComponent(booking.id)}/$suffix',
      body: body,
      headers: {'If-Match': '"${booking.revision}"'},
    ),
    ServiceBooking.fromJson,
  )).value;

  @override
  Future<ServiceBooking> confirmPayment(ServiceBooking booking) =>
      _bookingCommand(
        booking,
        'booking.confirm_payment',
        'payment-confirmation',
        const <String, Object?>{},
      );

  @override
  Future<ServiceBooking> reschedule({
    required ServiceBooking booking,
    required String holdId,
    required String reason,
  }) => _bookingCommand(booking, 'booking.reschedule', 'reschedule', {
    'hold_id': holdId,
    'reason': reason.trim(),
  });

  @override
  Future<ServiceBooking> cancel({
    required ServiceBooking booking,
    required String reason,
  }) => _bookingCommand(booking, 'booking.cancel', 'cancel', {
    'reason': reason.trim(),
  });

  @override
  Future<ServiceBooking> providerTransition({
    required ServiceBooking booking,
    required String status,
    String reason = '',
  }) => _bookingCommand(
    booking,
    'booking.provider_transition',
    'provider-status',
    {'status': status, 'reason': reason.trim()},
  );

  @override
  Future<ServiceBooking> start({
    required ServiceBooking booking,
    required String otp,
  }) => _bookingCommand(booking, 'booking.start', 'start', {'otp': otp});

  @override
  Future<ServiceBooking> complete({
    required ServiceBooking booking,
    required String photoAssetId,
  }) => _bookingCommand(booking, 'booking.complete', 'completion', {
    'photo_asset_id': photoAssetId.trim(),
  });

  @override
  Future<ServiceBooking> confirmCompletion(ServiceBooking booking) =>
      _bookingCommand(
        booking,
        'booking.confirm_completion',
        'confirm-completion',
        const <String, Object?>{},
      );

  @override
  Future<ServiceBooking> noShow({
    required ServiceBooking booking,
    required String reason,
  }) => _bookingCommand(booking, 'booking.no_show', 'no-show', {
    'reason': reason.trim(),
  });

  @override
  Future<ServiceBooking> dispute({
    required ServiceBooking booking,
    required String reason,
  }) => _bookingCommand(booking, 'booking.dispute', 'disputes', {
    'reason': reason.trim(),
  });
}

enum ServiceBookingStatus {
  idle,
  loading,
  ready,
  holding,
  submitting,
  success,
  conflict,
  failure,
}

final class ServiceBookingState {
  const ServiceBookingState({
    required this.status,
    this.postalCode = '',
    this.offerings = const [],
    this.offering,
    this.slots = const [],
    this.hold,
    this.booking,
    this.bookings = const [],
    this.message,
  });

  final ServiceBookingStatus status;
  final String postalCode;
  final List<ServiceOffering> offerings;
  final ServiceOffering? offering;
  final List<ServiceSlot> slots;
  final ServiceSlotHold? hold;
  final ServiceBooking? booking;
  final List<ServiceBooking> bookings;
  final String? message;
}

final class ServiceBookingController extends ChangeNotifier {
  ServiceBookingController({required ServiceBookingRemote remote})
    : _remote = remote;

  final ServiceBookingRemote _remote;
  ServiceBookingState _state = const ServiceBookingState(
    status: ServiceBookingStatus.idle,
  );

  ServiceBookingState get state => _state;

  Future<void> loadOfferings({
    required String postalCode,
    String? categoryId,
  }) async {
    final normalized = postalCode.trim();
    _set(_copy(status: ServiceBookingStatus.loading, postalCode: normalized));
    try {
      final values = await _remote.offerings(
        postalCode: normalized,
        categoryId: categoryId,
      );
      _set(
        _copy(
          status: ServiceBookingStatus.ready,
          offerings: values,
          message: values.isEmpty ? 'No services are available here yet.' : '',
        ),
      );
    } catch (_) {
      _set(
        _copy(
          status: ServiceBookingStatus.failure,
          message: 'Couldn’t load services for this location.',
        ),
      );
    }
  }

  Future<bool> selectOffering(ServiceOffering offering) async {
    _set(
      _copy(
        status: ServiceBookingStatus.loading,
        offering: offering,
        slots: const [],
        clearHold: true,
      ),
    );
    try {
      final slots = await _remote.slots(offering.id);
      _set(
        _copy(
          status: ServiceBookingStatus.ready,
          offering: offering,
          slots: slots,
          message: slots.isEmpty ? 'No appointments are available.' : '',
        ),
      );
      return true;
    } catch (_) {
      _set(
        _copy(
          status: ServiceBookingStatus.failure,
          offering: offering,
          message: 'Couldn’t load live appointment availability.',
        ),
      );
      return false;
    }
  }

  Future<ServiceSlotHold?> hold(ServiceSlot slot) async {
    if (!slot.canHold || _state.postalCode.isEmpty) return null;
    final previous = _state.hold;
    _set(_copy(status: ServiceBookingStatus.holding, clearMessage: true));
    try {
      if (previous != null && previous.status == 'HELD') {
        await _remote.releaseHold(previous.id);
      }
      final value = await _remote.hold(
        slotId: slot.id,
        postalCode: _state.postalCode,
      );
      _set(_copy(status: ServiceBookingStatus.ready, hold: value));
      return value;
    } on ApiConflictFailure {
      _set(
        _copy(
          status: ServiceBookingStatus.conflict,
          clearHold: true,
          message: 'That appointment was just taken. Choose another time.',
        ),
      );
      return null;
    } catch (_) {
      _set(
        _copy(
          status: ServiceBookingStatus.failure,
          clearHold: true,
          message: 'The appointment could not be held.',
        ),
      );
      return null;
    }
  }

  Future<void> releaseHold() async {
    final hold = _state.hold;
    if (hold == null) return;
    _set(_copy(clearHold: true));
    try {
      await _remote.releaseHold(hold.id);
    } catch (_) {
      // Holds expire on the server; local navigation must not be blocked.
    }
  }

  Future<ServiceBooking?> create(ServicePaymentMethod paymentMethod) async {
    final hold = _state.hold;
    if (hold == null || hold.remainingAt(DateTime.now()).inSeconds == 0) {
      _set(
        _copy(
          status: ServiceBookingStatus.conflict,
          clearHold: true,
          message: 'The appointment hold expired. Select the time again.',
        ),
      );
      return null;
    }
    _set(_copy(status: ServiceBookingStatus.submitting, clearMessage: true));
    try {
      final value = await _remote.create(
        holdId: hold.id,
        paymentMethod: paymentMethod,
      );
      _set(
        _copy(
          status: ServiceBookingStatus.success,
          booking: value,
          bookings: _replaceBooking(_state.bookings, value),
          clearHold: true,
        ),
      );
      return value;
    } on ApiConflictFailure {
      _set(
        _copy(
          status: ServiceBookingStatus.conflict,
          clearHold: true,
          message: 'The booking changed. Refresh availability and try again.',
        ),
      );
      return null;
    } catch (_) {
      _set(
        _copy(
          status: ServiceBookingStatus.failure,
          message: 'Booking wasn’t created. No duplicate charge was made.',
        ),
      );
      return null;
    }
  }

  Future<void> loadBookings() async {
    _set(_copy(status: ServiceBookingStatus.loading, clearMessage: true));
    try {
      final values = await _remote.bookings();
      _set(
        _copy(
          status: ServiceBookingStatus.ready,
          bookings: values,
          message: values.isEmpty ? 'You have no service bookings yet.' : '',
        ),
      );
    } catch (_) {
      _set(
        _copy(
          status: ServiceBookingStatus.failure,
          message: 'Couldn’t refresh service bookings.',
        ),
      );
    }
  }

  Future<ServiceBooking?> refresh(ServiceBooking booking) async {
    try {
      return _accept(await _remote.booking(booking.id));
    } catch (_) {
      _set(
        _copy(
          status: ServiceBookingStatus.failure,
          booking: booking,
          message: 'Couldn’t refresh this booking.',
        ),
      );
      return null;
    }
  }

  Future<ServiceBooking?> reschedule(
    ServiceBooking booking,
    ServiceSlot slot,
    String reason,
  ) async {
    if (!booking.allows('RESCHEDULE') || reason.trim().length < 3) return null;
    final held = await hold(slot);
    if (held == null) return null;
    return _mutate(
      booking,
      () =>
          _remote.reschedule(booking: booking, holdId: held.id, reason: reason),
    );
  }

  Future<ServiceBooking?> cancel(ServiceBooking booking, String reason) {
    if (!booking.allows('CANCEL') || reason.trim().length < 3) {
      return Future.value();
    }
    return _mutate(
      booking,
      () => _remote.cancel(booking: booking, reason: reason),
    );
  }

  Future<ServiceBooking?> confirmCompletion(ServiceBooking booking) {
    if (!booking.allows('CONFIRM_COMPLETION')) return Future.value();
    return _mutate(booking, () => _remote.confirmCompletion(booking));
  }

  Future<ServiceBooking?> dispute(ServiceBooking booking, String reason) {
    if (!booking.allows('DISPUTE') || reason.trim().length < 3) {
      return Future.value();
    }
    return _mutate(
      booking,
      () => _remote.dispute(booking: booking, reason: reason),
    );
  }

  Future<ServiceBooking?> providerTransition(
    ServiceBooking booking,
    String status, {
    String reason = '',
  }) => _mutate(
    booking,
    () => _remote.providerTransition(
      booking: booking,
      status: status,
      reason: reason,
    ),
  );

  Future<ServiceBooking?> start(ServiceBooking booking, String otp) {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) return Future.value();
    return _mutate(booking, () => _remote.start(booking: booking, otp: otp));
  }

  Future<ServiceBooking?> complete(
    ServiceBooking booking,
    String photoAssetId,
  ) {
    if (photoAssetId.trim().isEmpty) return Future.value();
    return _mutate(
      booking,
      () => _remote.complete(booking: booking, photoAssetId: photoAssetId),
    );
  }

  Future<ServiceBooking?> _mutate(
    ServiceBooking current,
    Future<ServiceBooking> Function() action,
  ) async {
    _set(
      _copy(
        status: ServiceBookingStatus.submitting,
        booking: current,
        clearMessage: true,
      ),
    );
    try {
      return _accept(await action());
    } on ApiConflictFailure {
      _set(
        _copy(
          status: ServiceBookingStatus.conflict,
          booking: current,
          message: 'This booking changed. Refresh before trying again.',
        ),
      );
      return null;
    } catch (_) {
      _set(
        _copy(
          status: ServiceBookingStatus.failure,
          booking: current,
          message: 'The booking action could not be completed.',
        ),
      );
      return null;
    }
  }

  ServiceBooking _accept(ServiceBooking value) {
    _set(
      _copy(
        status: ServiceBookingStatus.success,
        booking: value,
        bookings: _replaceBooking(_state.bookings, value),
        clearHold: true,
      ),
    );
    return value;
  }

  ServiceBookingState _copy({
    ServiceBookingStatus? status,
    String? postalCode,
    List<ServiceOffering>? offerings,
    ServiceOffering? offering,
    List<ServiceSlot>? slots,
    ServiceSlotHold? hold,
    ServiceBooking? booking,
    List<ServiceBooking>? bookings,
    String? message,
    bool clearHold = false,
    bool clearMessage = false,
  }) => ServiceBookingState(
    status: status ?? _state.status,
    postalCode: postalCode ?? _state.postalCode,
    offerings: offerings ?? _state.offerings,
    offering: offering ?? _state.offering,
    slots: slots ?? _state.slots,
    hold: clearHold ? null : hold ?? _state.hold,
    booking: booking ?? _state.booking,
    bookings: bookings ?? _state.bookings,
    message: clearMessage
        ? null
        : message?.isEmpty == true
        ? null
        : message ?? _state.message,
  );

  void _set(ServiceBookingState value) {
    _state = value;
    notifyListeners();
  }
}

List<ServiceBooking> _replaceBooking(
  List<ServiceBooking> values,
  ServiceBooking replacement,
) => List<ServiceBooking>.unmodifiable([
  replacement,
  ...values.where((value) => value.id != replacement.id),
]);

Map<String, Object?> _bookingObject(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}

String _bookingString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _bookingInteger(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

double _bookingNumber(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key must be a number.');
  return value.toDouble();
}

bool _bookingBoolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

List<Object?> _bookingList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key must be a list.');
  return value;
}

DateTime _bookingInstant(Map<String, Object?> json, String key) {
  final raw = _bookingString(json, key);
  final value = DateTime.tryParse(raw);
  if (value == null || !raw.endsWith('Z')) {
    throw FormatException('$key must be a UTC instant.');
  }
  return value.toUtc();
}

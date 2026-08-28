import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'service_booking.dart';
import 'transaction_screens.dart';
import 'transactions.dart';

final class ServiceBookingScreen extends StatefulWidget {
  const ServiceBookingScreen({
    required this.controller,
    required this.postalCode,
    this.paymentLauncher = const UnavailablePaymentProviderLauncher(),
    super.key,
  });

  final ServiceBookingController controller;
  final String postalCode;
  final PaymentProviderLauncher paymentLauncher;

  @override
  State<ServiceBookingScreen> createState() => _ServiceBookingScreenState();
}

final class _ServiceBookingScreenState extends State<ServiceBookingScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.loadOfferings(postalCode: widget.postalCode);
    widget.controller.loadBookings();
  }

  @override
  void didUpdateWidget(ServiceBookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (oldWidget.postalCode != widget.postalCode) {
      widget.controller.loadOfferings(postalCode: widget.postalCode);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Local services'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Discover'),
              Tab(text: 'Bookings'),
            ],
          ),
        ),
        body: TabBarView(children: [_offerings(state), _bookings(state)]),
      ),
    );
  }

  Widget _offerings(ServiceBookingState state) {
    if (state.status == ServiceBookingStatus.loading &&
        state.offerings.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Finding trusted professionals',
        message: 'Checking live services for your location.',
      );
    }
    if (state.offerings.isEmpty) {
      return Planext4uStatePanel(
        state: state.status == ServiceBookingStatus.failure
            ? Planext4uViewState.error
            : Planext4uViewState.empty,
        title: state.status == ServiceBookingStatus.failure
            ? 'Couldn’t load services'
            : 'No services nearby',
        message: state.message ?? 'Try another serviceable location.',
        actionLabel: 'Refresh',
        onAction: () =>
            widget.controller.loadOfferings(postalCode: widget.postalCode),
      );
    }
    return RefreshIndicator(
      onRefresh: () =>
          widget.controller.loadOfferings(postalCode: widget.postalCode),
      child: ListView(
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Verified local professionals'),
              subtitle: Text(
                'Live availability and booking policies are confirmed by Planext4u.',
              ),
            ),
          ),
          const SizedBox(height: Planext4uSpacing.x2),
          for (final offering in state.offerings)
            _OfferingCard(
              offering: offering,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ServiceOfferingScreen(
                    controller: widget.controller,
                    offering: offering,
                    paymentLauncher: widget.paymentLauncher,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bookings(ServiceBookingState state) {
    if (state.status == ServiceBookingStatus.loading &&
        state.bookings.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Loading bookings',
        message: 'Checking your latest service activity.',
      );
    }
    if (state.bookings.isEmpty) {
      return Planext4uStatePanel(
        state: state.status == ServiceBookingStatus.failure
            ? Planext4uViewState.error
            : Planext4uViewState.empty,
        title: 'No service bookings yet',
        message: state.message ?? 'Your appointments will appear here.',
        actionLabel: 'Refresh',
        onAction: widget.controller.loadBookings,
      );
    }
    return RefreshIndicator(
      onRefresh: widget.controller.loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        itemCount: state.bookings.length,
        itemBuilder: (context, index) {
          final booking = state.bookings[index];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.handyman_outlined)),
              title: Text(booking.offering.name),
              subtitle: Text(
                '${_statusLabel(booking.status)}\n${_slotLabel(context, booking.slot)}',
              ),
              isThreeLine: true,
              trailing: Text(booking.amountDue.display()),
              onTap: () => _openBooking(booking),
            ),
          );
        },
      ),
    );
  }

  void _openBooking(ServiceBooking booking) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServiceBookingDetailScreen(
          controller: widget.controller,
          initialBooking: booking,
        ),
      ),
    );
  }
}

final class _OfferingCard extends StatelessWidget {
  const _OfferingCard({required this.offering, required this.onPressed});

  final ServiceOffering offering;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: offering.active ? onPressed : null,
      child: Padding(
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.home_repair_service)),
                const SizedBox(width: Planext4uSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offering.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(offering.summary),
                    ],
                  ),
                ),
                Text(
                  offering.price.display(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            Wrap(
              spacing: Planext4uSpacing.x2,
              runSpacing: Planext4uSpacing.x2,
              children: [
                if (offering.verifiedProvider)
                  const Chip(
                    avatar: Icon(Icons.verified, size: 18),
                    label: Text('Verified provider'),
                  ),
                Chip(
                  avatar: const Icon(Icons.star_outline, size: 18),
                  label: Text(offering.ratingAverage.toStringAsFixed(1)),
                ),
                Chip(
                  avatar: const Icon(Icons.task_alt, size: 18),
                  label: Text('${offering.completedBookings} completed'),
                ),
              ],
            ),
            const SizedBox(height: Planext4uSpacing.x2),
            Text(
              '${offering.providerName} • ${offering.durationMinutes} min • '
              '${offering.liveEngagements} active jobs',
            ),
            if (offering.paymentMode == 'ADVANCE')
              Text('Advance today: ${offering.advance.display()}'),
          ],
        ),
      ),
    ),
  );
}

final class ServiceOfferingScreen extends StatefulWidget {
  const ServiceOfferingScreen({
    required this.controller,
    required this.offering,
    this.paymentLauncher = const UnavailablePaymentProviderLauncher(),
    super.key,
  });

  final ServiceBookingController controller;
  final ServiceOffering offering;
  final PaymentProviderLauncher paymentLauncher;

  @override
  State<ServiceOfferingScreen> createState() => _ServiceOfferingScreenState();
}

final class _ServiceOfferingScreenState extends State<ServiceOfferingScreen> {
  Timer? _timer;
  ServicePaymentMethod _method = ServicePaymentMethod.wallet;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.selectOffering(widget.offering);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.state.hold != null) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _timer?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _book() async {
    final booking = await widget.controller.create(_method);
    if (!mounted || booking == null) return;
    if (booking.payment.pending) {
      try {
        await widget.paymentLauncher.launch(booking.payment);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment setup is temporarily unavailable. Your booking can be checked safely.',
              ),
            ),
          );
        }
      }
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ServiceBookingDetailScreen(
          controller: widget.controller,
          initialBooking: booking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final hold = state.hold;
    final remaining = hold?.remainingAt(DateTime.now()) ?? Duration.zero;
    return Scaffold(
      appBar: AppBar(title: Text(widget.offering.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          children: [
            _OfferingCard(offering: widget.offering, onPressed: () {}),
            const SizedBox(height: Planext4uSpacing.x3),
            Text(
              'Choose an appointment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Availability and capacity update live. A selected time is held briefly during checkout.',
            ),
            const SizedBox(height: Planext4uSpacing.x2),
            if (state.status == ServiceBookingStatus.loading &&
                state.slots.isEmpty)
              const LinearProgressIndicator()
            else if (state.slots.isEmpty)
              Planext4uStatePanel(
                state: Planext4uViewState.empty,
                title: 'No appointments available',
                message: state.message ?? 'Check again later.',
                actionLabel: 'Refresh',
                onAction: () =>
                    widget.controller.selectOffering(widget.offering),
              )
            else
              RadioGroup<String>(
                groupValue: hold?.slotId,
                onChanged: (id) {
                  if (id == null) return;
                  final slot = state.slots.firstWhere(
                    (value) => value.id == id,
                  );
                  if (slot.canHold) widget.controller.hold(slot);
                },
                child: Column(
                  children: [
                    for (final slot in state.slots)
                      Card(
                        child: RadioListTile<String>(
                          value: slot.id,
                          enabled: slot.canHold,
                          title: Text(_slotLabel(context, slot)),
                          subtitle: Text(
                            slot.remaining == 0
                                ? 'Fully booked'
                                : '${slot.remaining} of ${slot.capacity} appointments left • ${slot.timeZone}',
                          ),
                          secondary: Text(slot.price.display()),
                        ),
                      ),
                  ],
                ),
              ),
            if (hold != null) ...[
              const SizedBox(height: Planext4uSpacing.x3),
              Semantics(
                liveRegion: true,
                child: Card(
                  color: remaining == Duration.zero
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(
                      remaining == Duration.zero
                          ? 'Appointment hold expired'
                          : 'Time held for ${_durationLabel(remaining)}',
                    ),
                    subtitle: const Text(
                      'Complete payment before the server hold expires.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              Text('Payment', style: Theme.of(context).textTheme.titleLarge),
              RadioGroup<ServicePaymentMethod>(
                groupValue: _method,
                onChanged: (value) {
                  if (value != null) setState(() => _method = value);
                },
                child: Column(
                  children: [
                    for (final method in ServicePaymentMethod.values)
                      RadioListTile<ServicePaymentMethod>(
                        value: method,
                        title: Text(method.label),
                        subtitle: Text(
                          method == ServicePaymentMethod.wallet
                              ? 'Uses your reconciled Planext points balance'
                              : 'Secure provider payment; confirmation comes from the server',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Planext4uSpacing.x2),
              FilledButton.icon(
                key: const ValueKey('create-service-booking'),
                onPressed:
                    remaining == Duration.zero ||
                        state.status == ServiceBookingStatus.submitting
                    ? null
                    : _book,
                icon: const Icon(Icons.lock_outline),
                label: Text(
                  'Book with ${widget.offering.advance.display()} due now',
                ),
              ),
            ],
            if (state.message != null) ...[
              const SizedBox(height: Planext4uSpacing.x2),
              Semantics(liveRegion: true, child: Text(state.message!)),
            ],
            if (state.status == ServiceBookingStatus.holding ||
                state.status == ServiceBookingStatus.submitting)
              const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

final class ServiceBookingDetailScreen extends StatefulWidget {
  const ServiceBookingDetailScreen({
    required this.controller,
    required this.initialBooking,
    super.key,
  });

  final ServiceBookingController controller;
  final ServiceBooking initialBooking;

  @override
  State<ServiceBookingDetailScreen> createState() =>
      _ServiceBookingDetailScreenState();
}

final class _ServiceBookingDetailScreenState
    extends State<ServiceBookingDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.refresh(widget.initialBooking);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  ServiceBooking get _booking {
    final current = widget.controller.state.booking;
    return current?.id == widget.initialBooking.id
        ? current!
        : widget.initialBooking;
  }

  Future<void> _reasonAction({required bool dispute}) async {
    final reason = await _reasonDialog(
      context,
      title: dispute ? 'Raise a dispute' : 'Cancel booking',
      action: dispute ? 'Submit dispute' : 'Cancel booking',
    );
    if (reason == null) return;
    if (dispute) {
      await widget.controller.dispute(_booking, reason);
    } else {
      await widget.controller.cancel(_booking, reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    final state = widget.controller.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service booking'),
        actions: [
          IconButton(
            tooltip: 'Refresh booking',
            onPressed: () => widget.controller.refresh(booking),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => widget.controller.refresh(booking),
          child: ListView(
            padding: const EdgeInsets.all(Planext4uSpacing.x4),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Planext4uSpacing.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(booking.status),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(booking.offering.name),
                      Text(_slotLabel(context, booking.slot)),
                      Text(
                        'Booking ${booking.id} • revision ${booking.revision}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              _DetailRow(
                label: 'Professional',
                value: booking.offering.providerName,
              ),
              _DetailRow(
                label: 'Service price',
                value: booking.price.display(),
              ),
              _DetailRow(
                label: 'Paid / due now',
                value: booking.amountDue.display(),
              ),
              _DetailRow(
                label: 'Payment',
                value:
                    '${booking.payment.method.label} • ${_statusLabel(booking.payment.status)}',
              ),
              _DetailRow(
                label: 'Free reschedules left',
                value: '${booking.freeReschedulesLeft}',
              ),
              if (booking.startOtp != null) ...[
                const SizedBox(height: Planext4uSpacing.x3),
                Semantics(
                  label: 'Six digit service start code',
                  child: Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(Planext4uSpacing.x4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Share only when the professional arrives',
                          ),
                          SelectableText(
                            booking.startOtp!,
                            key: const ValueKey('service-start-otp'),
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 8,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (booking.completionEvidence != null) ...[
                const SizedBox(height: Planext4uSpacing.x3),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Completion evidence received'),
                    subtitle: Text(
                      'Asset ${booking.completionEvidence!.photoAssetId}\nSubmitted by ${booking.completionEvidence!.submittedBy}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ],
              const SizedBox(height: Planext4uSpacing.x3),
              Text(
                'Booking timeline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final event in booking.timeline)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(_statusLabel(event.status)),
                  subtitle: Text(
                    '${event.actor}${event.reason.isEmpty ? '' : ' • ${event.reason}'}',
                  ),
                  trailing: Text(_timeLabel(context, event.createdAt)),
                ),
              const SizedBox(height: Planext4uSpacing.x3),
              Wrap(
                spacing: Planext4uSpacing.x2,
                runSpacing: Planext4uSpacing.x2,
                children: [
                  if (booking.allows('RESCHEDULE'))
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ServiceRescheduleScreen(
                            controller: widget.controller,
                            booking: booking,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: const Text('Reschedule'),
                    ),
                  if (booking.allows('CANCEL'))
                    OutlinedButton.icon(
                      onPressed: () => _reasonAction(dispute: false),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                    ),
                  if (booking.allows('CONFIRM_COMPLETION'))
                    FilledButton.icon(
                      key: const ValueKey('confirm-service-completion'),
                      onPressed: () =>
                          widget.controller.confirmCompletion(booking),
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Confirm completion'),
                    ),
                  if (booking.allows('DISPUTE'))
                    OutlinedButton.icon(
                      onPressed: () => _reasonAction(dispute: true),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Raise dispute'),
                    ),
                ],
              ),
              if (state.message != null) ...[
                const SizedBox(height: Planext4uSpacing.x3),
                Semantics(liveRegion: true, child: Text(state.message!)),
              ],
              if (state.status == ServiceBookingStatus.submitting)
                const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

final class ServiceRescheduleScreen extends StatefulWidget {
  const ServiceRescheduleScreen({
    required this.controller,
    required this.booking,
    super.key,
  });

  final ServiceBookingController controller;
  final ServiceBooking booking;

  @override
  State<ServiceRescheduleScreen> createState() =>
      _ServiceRescheduleScreenState();
}

final class _ServiceRescheduleScreenState
    extends State<ServiceRescheduleScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.selectOffering(widget.booking.offering);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _select(ServiceSlot slot) async {
    final reason = await _reasonDialog(
      context,
      title: 'Reason for rescheduling',
      action: 'Confirm new time',
    );
    if (reason == null) return;
    final value = await widget.controller.reschedule(
      widget.booking,
      slot,
      reason,
    );
    if (mounted && value != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a new time')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          children: [
            Text(
              '${widget.booking.freeReschedulesLeft} free reschedule available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'The new slot is held atomically before the booking changes.',
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            if (state.status == ServiceBookingStatus.loading)
              const LinearProgressIndicator(),
            for (final slot in state.slots)
              Card(
                child: ListTile(
                  title: Text(_slotLabel(context, slot)),
                  subtitle: Text('${slot.remaining} appointments left'),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: slot.canHold && slot.id != widget.booking.slot.id,
                  onTap: () => _select(slot),
                ),
              ),
            if (state.message != null)
              Semantics(liveRegion: true, child: Text(state.message!)),
          ],
        ),
      ),
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Planext4uSpacing.x1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: Planext4uSpacing.x3),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

Future<String?> _reasonDialog(
  BuildContext context, {
  required String title,
  required String action,
}) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: 'Reason',
          helperText: 'At least 3 characters',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () {
            final reason = controller.text.trim();
            if (reason.length >= 3) Navigator.of(context).pop(reason);
          },
          child: Text(action),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

String _slotLabel(BuildContext context, ServiceSlot slot) {
  final localizations = MaterialLocalizations.of(context);
  final localStart = slot.startsAt.toLocal();
  final localEnd = slot.endsAt.toLocal();
  return '${localizations.formatShortDate(localStart)} • '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localStart))}–'
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localEnd))}';
}

String _timeLabel(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()));

String _durationLabel(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _statusLabel(String value) {
  final words = value.toLowerCase().split('_');
  return words
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

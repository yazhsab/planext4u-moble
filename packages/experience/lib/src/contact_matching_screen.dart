import 'dart:async';
import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'contact_matching.dart';

final class ContactMatchingCard extends StatefulWidget {
  const ContactMatchingCard({required this.controller, super.key});
  final ContactMatchingController controller;
  @override
  State<ContactMatchingCard> createState() => _ContactMatchingCardState();
}

class _ContactMatchingCardState extends State<ContactMatchingCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.load());
    });
  }

  @override
  void didUpdateWidget(covariant ContactMatchingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.load());
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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final tamil = Localizations.localeOf(context).languageCode == 'ta';
    final state = controller.state;
    return Planext4uSectionCard(
      title: tamil ? 'தொடர்பு பொருத்தம்' : 'Find people you know',
      subtitle: tamil
          ? 'உங்கள் அனுமதியுடன் மட்டுமே தொலைபேசி எண்கள் பொருத்தப்படும். பெயர்கள் பதிவேற்றப்படாது; இருவரும் அனுமதித்தால் மட்டுமே முடிவு காட்டப்படும்.'
          : 'Only when you choose to sync: phone numbers are matched privately. Contact names are never uploaded. Both people must allow matching and have each other saved.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.busy) const LinearProgressIndicator(),
          if (controller.message case final message?)
            Semantics(liveRegion: true, child: Text(message)),
          if (state != null)
            Text(tamil ? 'நிலை: ${state.status}' : 'Status: ${state.status}'),
          if (state != null && state.status != 'UNAVAILABLE') ...[
            if (!controller.consentGranted && controller.hasPublishedPolicy)
              FilledButton(
                key: const ValueKey('allow-contact-matching'),
                onPressed: controller.busy ? null : controller.grant,
                child: Text(tamil ? 'அனுமதி வழங்கு' : 'Allow contact matching'),
              ),
            if (controller.consentGranted)
              FilledButton.icon(
                key: const ValueKey('sync-contacts'),
                onPressed: controller.busy ? null : controller.sync,
                icon: const Icon(Icons.sync),
                label: Text(tamil ? 'தொடர்புகளை ஒத்திசை' : 'Sync contacts'),
              ),
            if (controller.consentGranted && state.ready)
              TextButton(
                key: const ValueKey('show-contact-matches'),
                onPressed: controller.busy ? null : controller.loadMatches,
                child: Text(tamil ? 'பொருத்தங்களைப் பார்' : 'Show matches'),
              ),
            for (final match in controller.matches)
              ListTile(
                key: ValueKey('contact-match-${match.identityId}'),
                title: Text(
                  match.displayName.isEmpty
                      ? (tamil ? 'பிளானெக்ஸ்ட் பயனர்' : 'Planext4u member')
                      : match.displayName,
                ),
              ),
            if (controller.nextCursor != null)
              TextButton(
                key: const ValueKey('more-contact-matches'),
                onPressed: controller.busy ? null : controller.loadMatches,
                child: Text(tamil ? 'மேலும்' : 'Show more'),
              ),
          ],
          if (controller.canWithdraw)
            TextButton(
              key: const ValueKey('stop-contact-matching'),
              onPressed: controller.busy ? null : controller.withdraw,
              child: Text(
                tamil ? 'பொருத்தத்தை நிறுத்து' : 'Stop contact matching',
              ),
            ),
          TextButton(
            onPressed: controller.busy ? null : controller.load,
            child: Text(tamil ? 'புதுப்பி' : 'Refresh'),
          ),
        ],
      ),
    );
  }
}

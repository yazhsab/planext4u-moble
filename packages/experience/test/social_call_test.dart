import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  testWidgets('provider injection sends an offer and closes before END', (
    tester,
  ) async {
    final events = <String>[];
    final remote = _CallRemote(events);
    final provider = _RtcProvider(events);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerConversationScreen(
          controller: Phase5Controller(remote: remote),
          conversation: _acceptedConversation,
          rtcProviderFactory: () {
            events.add('factory');
            return provider;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start audio call'));
    await tester.pumpAndSettle();

    expect(events, ['create:AUDIO', 'factory']);
    expect(find.byType(SocialCallScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('start-call-signalling')));
    await tester.pumpAndSettle();
    expect(events, ['create:AUDIO', 'factory', 'offer', 'signal:OFFER']);
    expect(
      find.byKey(const ValueKey('social-call-offer-sent')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('end-social-call')));
    await tester.pumpAndSettle();

    expect(events, [
      'create:AUDIO',
      'factory',
      'offer',
      'signal:OFFER',
      'close',
      'signal:END',
    ]);
    expect(find.byType(SocialCallScreen), findsNothing);
  });

  testWidgets('missing provider fails closed before backend call creation', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerConversationScreen(
          controller: Phase5Controller(remote: _CallRemote(events)),
          conversation: _acceptedConversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final audioButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.call_outlined),
    );
    final videoButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.videocam_outlined),
    );
    expect(audioButton.onPressed, isNull);
    expect(videoButton.onPressed, isNull);
    expect(
      find.textContaining('WebRTC provider is configured'),
      findsOneWidget,
    );
    expect(events, isEmpty);
  });

  testWidgets('conversation allowed actions gate each call kind', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerConversationScreen(
          controller: Phase5Controller(remote: _CallRemote(events)),
          conversation: const SocialConversation(
            id: 'conversation-001',
            participantIds: ['customer-001', 'customer-002'],
            status: 'ACCEPTED',
            requestedBy: 'customer-001',
            allowedActions: {'AUDIO_CALL'},
          ),
          rtcProviderFactory: () => _RtcProvider(events),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.call_outlined),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.videocam_outlined),
          )
          .onPressed,
      isNull,
    );
    expect(events, isEmpty);
  });

  testWidgets('hangup closes local media even when END signaling fails', (
    tester,
  ) async {
    final events = <String>[];
    final remote = _CallRemote(events)..failEnd = true;
    final provider = _RtcProvider(events);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SocialCallScreen(
                  controller: Phase5Controller(remote: remote),
                  initialCall: _ringingCall,
                  rtcProvider: provider,
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('end-social-call')));
    await tester.pumpAndSettle();

    expect(events, ['close', 'signal:END']);
    expect(find.byType(SocialCallScreen), findsNothing);
  });

  testWidgets('hangup waits for an in-flight offer before signaling END', (
    tester,
  ) async {
    final events = <String>[];
    final remote = _CallRemote(events)..offerGate = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SocialCallScreen(
                  controller: Phase5Controller(remote: remote),
                  initialCall: _ringingCall,
                  rtcProvider: _RtcProvider(events),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-call-signalling')));
    await tester.pump();
    expect(events, ['offer', 'signal:OFFER']);

    await tester.tap(find.byKey(const ValueKey('end-social-call')));
    await tester.pump();
    expect(events, ['offer', 'signal:OFFER', 'close']);

    remote.offerGate!.complete();
    await tester.pumpAndSettle();
    expect(events, ['offer', 'signal:OFFER', 'close', 'signal:END']);
    expect(find.byType(SocialCallScreen), findsNothing);
  });
}

final class _RtcProvider implements SocialRtcOfferProvider {
  _RtcProvider(this.events);

  final List<String> events;

  @override
  Future<String> createOffer(SocialCall call) async {
    events.add('offer');
    return '{"type":"offer","sdp":"opaque-secure-offer"}';
  }

  @override
  Future<void> close() async => events.add('close');
}

final class _CallRemote extends Fake implements Phase5Remote {
  _CallRemote(this.events);

  final List<String> events;
  bool failEnd = false;
  Completer<void>? offerGate;

  @override
  Future<List<SocialMessage>> messages(String conversationId) async => const [];

  @override
  Future<SocialCall> createCall(String conversationId, String kind) async {
    events.add('create:$kind');
    return SocialCall(
      id: _ringingCall.id,
      conversationId: conversationId,
      kind: kind,
      status: 'RINGING',
      signalCount: 0,
      expiresAt: _ringingCall.expiresAt,
    );
  }

  @override
  Future<SocialCall> signalCall(
    String callId,
    String type,
    String payload,
  ) async {
    events.add('signal:$type');
    if (type == 'OFFER' && offerGate != null) await offerGate!.future;
    if (type == 'END' && failEnd) throw StateError('network unavailable');
    return SocialCall(
      id: callId,
      conversationId: _ringingCall.conversationId,
      kind: _ringingCall.kind,
      status: type == 'END' ? 'ENDED' : 'RINGING',
      signalCount: 1,
      expiresAt: _ringingCall.expiresAt,
    );
  }
}

const _acceptedConversation = SocialConversation(
  id: 'conversation-001',
  participantIds: ['customer-001', 'customer-002'],
  status: 'ACCEPTED',
  requestedBy: 'customer-001',
  allowedActions: {'MESSAGE', 'AUDIO_CALL', 'VIDEO_CALL'},
);

final _ringingCall = SocialCall(
  id: 'call-001',
  conversationId: 'conversation-001',
  kind: 'AUDIO',
  status: 'RINGING',
  signalCount: 0,
  expiresAt: DateTime.utc(2026, 9, 2, 12, 5),
);

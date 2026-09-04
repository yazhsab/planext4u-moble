import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  group('community media coordinator', () {
    test('hands valid captured media to the private uploader', () async {
      final visual = _VisualSource(
        CommunityBinaryMedia(
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/jpeg',
        ),
      );
      final uploader = _Uploader();
      final coordinator = _coordinator(visual: visual, uploader: uploader);

      final reference = await coordinator.captureAndUpload(
        CommunityMediaKind.storyImage,
      );

      expect(reference, 'private-asset-001');
      expect(visual.lastKind, CommunityMediaKind.storyImage);
      expect(uploader.lastKind, CommunityMediaKind.storyImage);
      expect(uploader.uploadCount, 1);
    });

    test('treats platform cancellation as a non-uploading outcome', () async {
      final uploader = _Uploader();
      final coordinator = _coordinator(
        visual: _VisualSource(null),
        uploader: uploader,
      );

      expect(
        await coordinator.captureAndUpload(CommunityMediaKind.classifiedImage),
        isNull,
      );
      expect(uploader.uploadCount, 0);
    });

    test('preserves permission denial and never invokes uploader', () async {
      final uploader = _Uploader();
      final coordinator = _coordinator(
        visual: _VisualSource(
          const CommunityCaptureException(
            CommunityCaptureIssue.permissionDenied,
            'Camera permission is required.',
          ),
        ),
        uploader: uploader,
      );

      await expectLater(
        coordinator.captureAndUpload(CommunityMediaKind.storyImage),
        throwsA(
          isA<CommunityCaptureException>().having(
            (error) => error.issue,
            'issue',
            CommunityCaptureIssue.permissionDenied,
          ),
        ),
      );
      expect(uploader.uploadCount, 0);
    });

    test('rejects oversized images before upload', () async {
      final uploader = _Uploader();
      final coordinator = _coordinator(
        visual: _VisualSource(
          CommunityBinaryMedia(
            bytes: Uint8List(CommunityMediaCoordinator.maxImageBytes + 1),
            contentType: 'image/jpeg',
          ),
        ),
        uploader: uploader,
      );

      await expectLater(
        coordinator.captureAndUpload(CommunityMediaKind.storyImage),
        throwsA(
          isA<CommunityCaptureException>().having(
            (error) => error.issue,
            'issue',
            CommunityCaptureIssue.invalidEvidence,
          ),
        ),
      );
      expect(uploader.uploadCount, 0);
    });

    test('rejects voice notes beyond the duration limit', () async {
      final voice = _VoiceSource(
        CommunityBinaryMedia(
          bytes: Uint8List.fromList(const [1, 2, 3]),
          contentType: 'audio/mp4',
          duration: const Duration(seconds: 61),
        ),
      );
      final uploader = _Uploader();
      final coordinator = _coordinator(voice: voice, uploader: uploader);

      await coordinator.startVoice();
      await expectLater(
        coordinator.stopVoiceAndUpload(),
        throwsA(
          isA<CommunityCaptureException>().having(
            (error) => error.issue,
            'issue',
            CommunityCaptureIssue.invalidEvidence,
          ),
        ),
      );

      expect(coordinator.voiceActive, isFalse);
      expect(uploader.uploadCount, 0);
    });

    test('rejects oversized voice notes before upload', () async {
      final voice = _VoiceSource(
        CommunityBinaryMedia(
          bytes: Uint8List(CommunityMediaCoordinator.maxVoiceBytes + 1),
          contentType: 'audio/mp4',
          duration: const Duration(seconds: 10),
        ),
      );
      final uploader = _Uploader();
      final coordinator = _coordinator(voice: voice, uploader: uploader);

      await coordinator.startVoice();
      await expectLater(
        coordinator.stopVoiceAndUpload(),
        throwsA(isA<CommunityCaptureException>()),
      );
      expect(uploader.uploadCount, 0);
    });

    test('explicit cancellation closes a recording without upload', () async {
      final voice = _VoiceSource(null);
      final uploader = _Uploader();
      final coordinator = _coordinator(voice: voice, uploader: uploader);

      await coordinator.startVoice();
      await coordinator.cancelVoice();

      expect(voice.active, isFalse);
      expect(coordinator.voiceActive, isFalse);
      expect(uploader.uploadCount, 0);
    });
  });

  group('community media contracts', () {
    test(
      'maps story/reel assets and voice jobs to backend media kinds',
      () async {
        final remote = _CommunityRemote();
        final controller = Phase5Controller(remote: remote);

        await controller.createStory(
          assetId: 'private-story-asset-001',
          kind: 'STORY',
          caption: 'Local update',
        );
        await controller.createStory(
          assetId: 'private-reel-asset-001',
          kind: 'REEL',
          caption: 'Short clip',
        );
        final voiceJob = await controller.prepareVoiceMessage(
          'private-voice-asset-001',
        );

        expect(remote.mediaKinds, ['IMAGE', 'VIDEO', 'VOICE']);
        expect(remote.ephemeralKinds, ['STORY', 'REEL']);
        expect(voiceJob, 'media-job-003');
      },
    );

    testWidgets('reports a cancelled story capture without posting', (
      tester,
    ) async {
      final remote = _CommunityRemote();
      final coordinator = _coordinator(visual: _VisualSource(null));

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerCommunityHubScreen(
            controller: Phase5Controller(remote: remote),
            mediaCoordinator: coordinator,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-story')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-story-kind')));
      await tester.pumpAndSettle();

      expect(find.text('Media capture cancelled.'), findsOneWidget);
      expect(remote.mediaKinds, isEmpty);
    });

    testWidgets('uploads and sends an accepted-conversation voice note', (
      tester,
    ) async {
      final remote = _CommunityRemote();
      final coordinator = _coordinator(
        voice: _VoiceSource(
          CommunityBinaryMedia(
            bytes: Uint8List.fromList(const [1, 2, 3]),
            contentType: 'audio/mp4',
            duration: const Duration(seconds: 5),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerConversationScreen(
            controller: Phase5Controller(remote: remote),
            conversation: _conversation,
            mediaCoordinator: coordinator,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('phase5-voice-note')));
      await tester.pump();
      expect(find.textContaining('Recording'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('phase5-voice-note')));
      await tester.pumpAndSettle();

      expect(remote.mediaKinds, ['VOICE']);
      expect(remote.lastMessageBody, isEmpty);
      expect(remote.lastVoiceMediaId, 'media-job-001');
      expect(find.text('Voice note sent.'), findsOneWidget);
    });

    testWidgets('includes captured classified photos in the submission', (
      tester,
    ) async {
      final remote = _CommunityRemote();
      final coordinator = _coordinator(
        visual: _VisualSource(
          CommunityBinaryMedia(
            bytes: Uint8List.fromList(const [1, 2, 3]),
            contentType: 'image/jpeg',
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClassifiedPostingWizard(
            controller: Phase5Controller(remote: remote),
            mediaCoordinator: coordinator,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('classified-next-0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('classified-title')),
        'Desk lamp',
      );
      await tester.enterText(
        find.byKey(const ValueKey('classified-description')),
        'A well maintained reading lamp',
      );
      await tester.tap(find.byKey(const ValueKey('classified-next-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('classified-price')),
        '450',
      );
      await tester.tap(find.byKey(const ValueKey('capture-classified-photo')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 5 safety-scanned photos'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('classified-next-2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('classified-contact')),
        '9876543210',
      );
      await tester.tap(find.byKey(const ValueKey('submit-classified')));
      await tester.pumpAndSettle();

      expect(remote.lastClassified?['media_asset_ids'], ['private-asset-001']);
    });
  });
}

CommunityMediaCoordinator _coordinator({
  _VisualSource? visual,
  _VoiceSource? voice,
  _Uploader? uploader,
}) => CommunityMediaCoordinator(
  visualSource: visual ?? _VisualSource(null),
  voiceSource: voice ?? _VoiceSource(null),
  uploader: uploader ?? _Uploader(),
);

final class _VisualSource implements CommunityVisualCaptureSource {
  _VisualSource(this.result);

  final Object? result;
  CommunityMediaKind? lastKind;

  @override
  Future<CommunityBinaryMedia?> capture(CommunityMediaKind kind) async {
    lastKind = kind;
    if (result is Exception) throw result! as Exception;
    return result as CommunityBinaryMedia?;
  }
}

final class _VoiceSource implements CommunityVoiceCaptureSource {
  _VoiceSource(this.result);

  final CommunityBinaryMedia? result;
  bool active = false;

  @override
  Future<void> start() async => active = true;

  @override
  Future<CommunityBinaryMedia?> stop() async {
    active = false;
    return result;
  }

  @override
  Future<void> cancel() async => active = false;

  @override
  Future<void> dispose() async => active = false;
}

final class _Uploader implements CommunityMediaUploader {
  int uploadCount = 0;
  CommunityMediaKind? lastKind;

  @override
  Future<String> upload({
    required CommunityMediaKind kind,
    required CommunityBinaryMedia media,
  }) async {
    uploadCount++;
    lastKind = kind;
    return 'private-asset-001';
  }
}

final class _CommunityRemote extends Fake implements Phase5Remote {
  final mediaKinds = <String>[];
  final ephemeralKinds = <String>[];
  Map<String, Object?>? lastClassified;
  String? lastMessageBody;
  String? lastVoiceMediaId;

  @override
  Future<List<SocialEphemeral>> ephemeral() async => const [];

  @override
  Future<SocialMediaJob> createMedia(String assetId, String kind) async {
    mediaKinds.add(kind);
    return SocialMediaJob(
      id: 'media-job-${mediaKinds.length.toString().padLeft(3, '0')}',
      kind: kind,
      state: 'READY',
      scanStatus: 'CLEAN',
    );
  }

  @override
  Future<SocialEphemeral> createEphemeral(
    String kind,
    String mediaJobId,
    String caption,
  ) async {
    ephemeralKinds.add(kind);
    return SocialEphemeral(
      id: 'ephemeral-${ephemeralKinds.length}',
      kind: kind,
      caption: caption,
      status: 'PUBLISHED',
      highlighted: false,
      expiresAt: DateTime.utc(2026, 9, 3),
      allowedActions: const {},
    );
  }

  @override
  Future<List<SocialConversation>> conversations() async => const [];

  @override
  Future<List<HomeListing>> homes({
    String query = '',
    String locality = '',
    String propertyType = '',
    String purpose = '',
  }) async => const [];

  @override
  Future<List<ClassifiedListing>> classifieds({
    String query = '',
    String category = '',
    String locality = '',
  }) async => const [];

  @override
  Future<List<EmergencyAssistance>> emergencies() async => const [];

  @override
  Future<void> setPresence(String state) async {}

  @override
  Future<List<SocialMessage>> messages(String conversationId) async => const [];

  @override
  Future<SocialMessage> sendMessage(
    String conversationId,
    String body, {
    String? voiceMediaId,
  }) async {
    lastMessageBody = body;
    lastVoiceMediaId = voiceMediaId;
    return SocialMessage(
      id: 'message-001',
      conversationId: conversationId,
      senderId: 'customer-001',
      body: body,
      voiceMediaId: voiceMediaId ?? '',
      status: 'DELIVERED',
      createdAt: DateTime.utc(2026, 9, 2),
    );
  }

  @override
  Future<ClassifiedListing> createClassified(Map<String, Object?> input) async {
    lastClassified = input;
    return _classified;
  }
}

const _conversation = SocialConversation(
  id: 'conversation-001',
  participantIds: ['customer-001', 'customer-002'],
  status: 'ACCEPTED',
  requestedBy: 'customer-001',
  allowedActions: {'MESSAGE'},
);

final _classified = ClassifiedListing(
  id: 'classified-001',
  revision: 1,
  ownerId: 'customer-001',
  category: 'ELECTRONICS',
  title: 'Desk lamp',
  description: 'A well maintained reading lamp',
  price: const Phase5Money(amountMinor: 45000, currency: 'INR'),
  locality: 'Chennai',
  status: 'PENDING_REVIEW',
  plan: 'STANDARD',
  contactMasked: '******3210',
  contactRevealed: '',
  whatsAppEnabled: false,
  expiresAt: DateTime.utc(2026, 10, 2),
  reportCount: 0,
  allowedActions: const {'EDIT'},
);

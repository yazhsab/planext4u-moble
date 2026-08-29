import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  group('Phase 5 community and local verticals', () {
    test('decodes every pinned Phase 5 fixture', () {
      final contracts =
          '${_workspaceRoot().path}/packages/api_client/contracts';
      final home = HomeListing.fromJson(
        jsonDecode(
          File('$contracts/home_listing.fixture.json').readAsStringSync(),
        ),
      );
      final classified = ClassifiedListing.fromJson(
        jsonDecode(
          File('$contracts/classified_listing.fixture.json').readAsStringSync(),
        ),
      );
      final emergency = EmergencyAssistance.fromJson(
        jsonDecode(
          File('$contracts/emergency_request.fixture.json').readAsStringSync(),
        ),
      );

      expect(home.estimate.version, isNotEmpty);
      expect(home.allowedActions, isNotEmpty);
      expect(classified.contactRevealed, isEmpty);
      expect(classified.contactMasked, contains('*'));
      expect(emergency.locationConsent, isTrue);
      expect(emergency.allowedActions, contains('REVOKE_LOCATION'));
    });

    test('keeps server-owned state across Phase 5 commands', () async {
      final remote = _Phase5FakeRemote();
      final controller = Phase5Controller(remote: remote);

      await controller.load();
      expect(controller.state.homes.single.estimate.version, 'homes-avm-test');
      expect(remote.presence, 'ONLINE');

      await controller.createHome(const {'title': 'My verified home'});
      expect(controller.state.homes.first.allowedActions, contains('PUBLISH'));
      await controller.publishHome(controller.state.homes.first);
      expect(remote.publishedHome, isTrue);

      await controller.createClassified(const {'title': 'Safe listing'});
      expect(
        controller.state.classifieds.first.allowedActions,
        contains('REPOST'),
      );
      await controller.repostClassified(controller.state.classifieds.first.id);
      expect(remote.repostedClassified, isTrue);

      await controller.createStory(
        assetId: 'media-asset-001',
        kind: 'STORY',
        caption: 'Neighbourhood update',
      );
      expect(controller.state.message, contains('safety pipeline'));

      final call = await controller.createCall('conversation-001', 'AUDIO');
      expect(call?.status, 'RINGING');
      final ended = await controller.signalCall(call!.id, 'END');
      expect(ended?.status, 'ENDED');

      final export = await controller.exportAccountData();
      expect(export?.sessionCount, 2);
      final deletion = await controller.requestAccountDeletion('Moving away');
      expect(deletion?.status, 'SCHEDULED');
    });

    testWidgets('renders all four responsive community journeys', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = Phase5Controller(remote: _Phase5FakeRemote());

      await tester.pumpWidget(
        MaterialApp(home: CustomerCommunityHubScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stories, reels & highlights'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-message-request')), findsOneWidget);

      await tester.tap(find.text('Homes'));
      await tester.pumpAndSettle();
      expect(find.text('Find your next home'), findsOneWidget);
      expect(find.text('Verified family apartment'), findsOneWidget);

      await tester.tap(find.text('Classifieds'));
      await tester.pumpAndSettle();
      expect(find.text('Local classifieds'), findsOneWidget);
      expect(find.text('Safety-scanned bicycle'), findsOneWidget);

      await tester.drag(find.byType(TabBar), const Offset(-220, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emergency'));
      await tester.pumpAndSettle();
      expect(find.text('Emergency assistance'), findsOneWidget);
      expect(find.text('My active requests'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('parses Phase 5 community deep links', () {
      expect(
        (CustomerDeepLink.parse(Uri.parse('/app/community'))
                as CustomerCommunityLink)
            .tab,
        0,
      );
      expect(
        (CustomerDeepLink.parse(Uri.parse('/app/homes'))
                as CustomerCommunityLink)
            .tab,
        1,
      );
      expect(
        (CustomerDeepLink.parse(Uri.parse('/app/classifieds'))
                as CustomerCommunityLink)
            .tab,
        2,
      );
      expect(
        (CustomerDeepLink.parse(Uri.parse('/app/emergency'))
                as CustomerCommunityLink)
            .tab,
        3,
      );
    });
  });
}

Directory _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (directory.parent.path != directory.path) {
    if (File('${directory.path}/pubspec.yaml').existsSync() &&
        Directory('${directory.path}/apps/customer').existsSync()) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Planext4u workspace root was not found.');
}

final class _Phase5FakeRemote implements Phase5Remote {
  String? presence;
  bool publishedHome = false;
  bool repostedClassified = false;

  @override
  Future<List<SocialEphemeral>> ephemeral() async => const [];
  @override
  Future<SocialMediaJob> createMedia(String assetId, String kind) async =>
      const SocialMediaJob(
        id: 'media-job-001',
        kind: 'STORY',
        state: 'QUARANTINED',
        scanStatus: 'PENDING',
      );
  @override
  Future<SocialEphemeral> createEphemeral(
    String kind,
    String mediaJobId,
    String caption,
  ) async => _story;
  @override
  Future<SocialEphemeral> setHighlight(String id, bool active) async => _story;
  @override
  Future<void> createCollection(String name) async {}
  @override
  Future<List<SocialConversation>> conversations() async => const [
    SocialConversation(
      id: 'conversation-001',
      participantIds: ['customer-001', 'customer-002'],
      status: 'ACCEPTED',
      requestedBy: 'customer-001',
      allowedActions: {'MESSAGE', 'AUDIO_CALL', 'VIDEO_CALL'},
    ),
  ];
  @override
  Future<SocialConversation> openConversation(String profileId) async =>
      (await conversations()).single;
  @override
  Future<SocialConversation> acceptConversation(String id) async =>
      (await conversations()).single;
  @override
  Future<List<SocialMessage>> messages(String conversationId) async => const [];
  @override
  Future<SocialMessage> sendMessage(
    String conversationId,
    String body, {
    String? voiceMediaId,
  }) async => SocialMessage(
    id: 'message-001',
    conversationId: conversationId,
    senderId: 'customer-001',
    body: body,
    voiceMediaId: voiceMediaId ?? '',
    status: 'DELIVERED',
    createdAt: _now,
  );
  @override
  Future<void> setPresence(String state) async => presence = state;
  @override
  Future<SocialCall> createCall(String conversationId, String kind) async =>
      SocialCall(
        id: 'social-call-001',
        conversationId: conversationId,
        kind: kind,
        status: 'RINGING',
        signalCount: 0,
        expiresAt: _now.add(const Duration(minutes: 2)),
      );
  @override
  Future<SocialCall> signalCall(
    String callId,
    String type,
    String payload,
  ) async => SocialCall(
    id: callId,
    conversationId: 'conversation-001',
    kind: 'AUDIO',
    status: type == 'END' ? 'ENDED' : 'CONNECTED',
    signalCount: 1,
    expiresAt: _now.add(const Duration(minutes: 2)),
  );
  @override
  Future<List<HomeListing>> homes({
    String query = '',
    String locality = '',
    String propertyType = '',
    String purpose = '',
  }) async => [_home];
  @override
  Future<HomeListing> createHome(Map<String, Object?> input) async =>
      _ownerHome;
  @override
  Future<HomeListing> publishHome(HomeListing listing) async {
    publishedHome = true;
    return _home;
  }

  @override
  Future<void> inquireHome(String id, String message) async {}
  @override
  Future<void> scheduleVisit(String id, DateTime scheduledAt) async {}
  @override
  Future<HomeListing> upgradeHome(String id, String plan) async => _ownerHome;
  @override
  Future<List<ClassifiedListing>> classifieds({
    String query = '',
    String category = '',
    String locality = '',
  }) async => [_classified];
  @override
  Future<ClassifiedListing> createClassified(
    Map<String, Object?> input,
  ) async => _ownerClassified;
  @override
  Future<ClassifiedListing> revealContact(String id, String channel) async =>
      _classified;
  @override
  Future<ClassifiedListing> reportClassified(String id, String reason) async =>
      _classified;
  @override
  Future<ClassifiedListing> repostClassified(String id) async {
    repostedClassified = true;
    return _classified;
  }

  @override
  Future<ClassifiedListing> upgradeClassified(String id, String plan) async =>
      _ownerClassified;
  @override
  Future<List<EmergencyAssistance>> emergencies() async => [_emergency];
  @override
  Future<EmergencyAssistance> createEmergency({
    required String category,
    required String description,
    required String priority,
    required double latitude,
    required double longitude,
    required double accuracyM,
  }) async => _emergency;
  @override
  Future<EmergencyAssistance> updateEmergencyLocation(
    String id, {
    required bool consent,
    double? latitude,
    double? longitude,
    double? accuracyM,
  }) async => _emergency;
  @override
  Future<List<EmergencyMessage>> emergencyMessages(String id) async => const [];
  @override
  Future<EmergencyMessage> sendEmergencyMessage(String id, String body) async =>
      EmergencyMessage(
        id: 'emergency-message-001',
        requestId: id,
        senderId: 'customer-001',
        body: body,
        status: 'DELIVERED',
        createdAt: _now,
      );
  @override
  Future<AccountDataExport> exportAccountData() async => AccountDataExport(
    generatedAt: _now,
    identityId: 'customer-001',
    sessionCount: 2,
    consentCount: 3,
  );
  @override
  Future<AccountDeletionRequest> requestAccountDeletion(String reason) async =>
      AccountDeletionRequest(
        id: 'deletion-001',
        status: 'SCHEDULED',
        requestedAt: _now,
        effectiveAt: _now.add(const Duration(days: 30)),
      );
}

final _now = DateTime.utc(2026, 8, 29, 12);
final _story = SocialEphemeral(
  id: 'story-001',
  kind: 'STORY',
  caption: 'Community update',
  status: 'PUBLISHED',
  highlighted: false,
  expiresAt: _now.add(const Duration(hours: 24)),
  allowedActions: const {'HIGHLIGHT'},
);
final _estimate = HomeEstimate(
  version: 'homes-avm-test',
  amount: const Phase5Money(amountMinor: 850000000, currency: 'INR'),
  pricePerArea: const Phase5Money(amountMinor: 850000, currency: 'INR'),
);
final _home = HomeListing(
  id: 'home-001',
  revision: 1,
  ownerId: 'owner-002',
  title: 'Verified family apartment',
  propertyType: 'APARTMENT',
  purpose: 'SALE',
  locality: 'Chennai',
  latitude: 13.03,
  longitude: 80.27,
  areaSqFt: 1000,
  bedrooms: 2,
  price: const Phase5Money(amountMinor: 850000000, currency: 'INR'),
  amenities: const ['parking'],
  status: 'ACTIVE',
  kycVerified: true,
  plan: 'STANDARD',
  estimate: _estimate,
  allowedActions: const {'INQUIRE', 'SCHEDULE_VISIT', 'VIEW_ESTIMATE'},
);
final _ownerHome = HomeListing(
  id: 'home-owner-001',
  revision: 1,
  ownerId: 'customer-001',
  title: 'My verified home',
  propertyType: 'APARTMENT',
  purpose: 'SALE',
  locality: 'Chennai',
  latitude: 13.03,
  longitude: 80.27,
  areaSqFt: 1000,
  bedrooms: 2,
  price: const Phase5Money(amountMinor: 850000000, currency: 'INR'),
  amenities: const ['parking'],
  status: 'DRAFT',
  kycVerified: true,
  plan: 'STANDARD',
  estimate: _estimate,
  allowedActions: const {'EDIT', 'UPGRADE', 'PUBLISH'},
);
final _classified = ClassifiedListing(
  id: 'classified-001',
  revision: 1,
  ownerId: 'owner-002',
  category: 'VEHICLES',
  title: 'Safety-scanned bicycle',
  description: 'Well maintained city bicycle',
  price: const Phase5Money(amountMinor: 1500000, currency: 'INR'),
  locality: 'Chennai',
  status: 'PUBLISHED',
  plan: 'STANDARD',
  contactMasked: '******6789',
  contactRevealed: '',
  whatsAppEnabled: true,
  expiresAt: _now.add(const Duration(days: 30)),
  reportCount: 0,
  allowedActions: const {'CONTACT', 'REPORT'},
);
final _ownerClassified = ClassifiedListing(
  id: 'classified-owner-001',
  revision: 1,
  ownerId: 'customer-001',
  category: 'OTHER',
  title: 'Safe listing',
  description: 'A safely moderated local listing',
  price: const Phase5Money(amountMinor: 10000, currency: 'INR'),
  locality: 'Chennai',
  status: 'EXPIRED',
  plan: 'STANDARD',
  contactMasked: '******6789',
  contactRevealed: '',
  whatsAppEnabled: false,
  expiresAt: _now.subtract(const Duration(days: 1)),
  reportCount: 0,
  allowedActions: const {'EDIT', 'UPGRADE', 'REPOST'},
);
final _emergency = EmergencyAssistance(
  id: 'emergency-001',
  revision: 1,
  category: 'MEDICAL',
  description: 'Need urgent assistance nearby',
  priority: 'CRITICAL',
  status: 'OPEN',
  assignedResponder: '',
  locationConsent: true,
  location: EmergencyLocation(
    latitude: 13.03,
    longitude: 80.27,
    accuracyM: 15,
    capturedAt: _now,
  ),
  escalationLevel: 0,
  slaDeadline: _now.add(const Duration(minutes: 5)),
  allowedActions: const {'UPDATE_LOCATION', 'REVOKE_LOCATION'},
);

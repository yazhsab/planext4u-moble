import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  group('Phase 5 Socio trust entry slice', () {
    test('decodes the pinned backend feed fixture', () {
      final value = jsonDecode(
        File(
          '${_workspaceRoot().path}/packages/api_client/contracts/social_feed.fixture.json',
        ).readAsStringSync(),
      );
      final page = SocialFeedPage.fromJson(value);

      expect(page.rankingVersion, 'socio-feed-v1');
      expect(page.items, hasLength(1));
      expect(page.items.single.author.verified, isTrue);
      expect(page.items.single.allowedActions, contains('REPORT'));
    });

    test('uses server truth for engagement and moderation states', () async {
      final remote = _SocialFakeRemote();
      final controller = SocialController(remote: remote);

      await controller.loadFeed();
      expect(controller.state.items.single.likeCount, 42);

      await controller.toggleLike(controller.state.items.single);
      expect(controller.state.items.single.likeCount, 43);
      expect(controller.state.items.single.liked, isTrue);

      await controller.createPost('Community update #local');
      expect(controller.state.items.first.pendingReview, isTrue);
      expect(controller.state.message, contains('Only you can see'));

      await controller.openComments('social-post-001');
      await controller.createComment('Thank you for sharing');
      expect(controller.state.comments.single.depth, 0);

      await controller.report('social-post-001', 'SPAM');
      expect(remote.reportReason, 'SPAM');
      expect(controller.state.message, contains('moderation team'));
    });

    test('refreshes authoritative state after a revision conflict', () async {
      final remote = _SocialFakeRemote(conflictOnce: true);
      final controller = SocialController(remote: remote);
      await controller.loadFeed();

      await controller.toggleSave(controller.state.items.single);

      expect(controller.state.items.single.revision, 2);
      expect(controller.state.items.single.saved, isTrue);
      expect(controller.state.message, contains('Latest state loaded'));
    });

    testWidgets('supports feed, compose, react, comment and report UI', (
      tester,
    ) async {
      final remote = _SocialFakeRemote();
      final controller = SocialController(remote: remote);
      await tester.pumpWidget(
        MaterialApp(home: CustomerSocialScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekend community market'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('like-social-post-001')));
      await tester.pumpAndSettle();
      expect(find.text('43'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('create-social-post')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('social-post-body')),
        'A safe community update',
      );
      await tester.tap(find.byKey(const ValueKey('submit-social-post')));
      await tester.pumpAndSettle();
      expect(find.text('Pending moderation review'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('comments-social-post-001')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('social-comment-body')),
        'Helpful update',
      );
      await tester.tap(find.byKey(const ValueKey('submit-social-comment')));
      await tester.pumpAndSettle();
      expect(find.text('Helpful update'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Post options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam or misleading'));
      await tester.pumpAndSettle();
      expect(remote.reportReason, 'SPAM');
    });

    testWidgets('fits a narrow Android viewport at 130% text', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = SocialController(remote: _SocialFakeRemote());

      await tester.pumpWidget(
        MaterialApp(home: CustomerSocialScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekend community market'), findsOneWidget);
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });

    test('parses safe Socio deep links', () {
      expect(
        CustomerDeepLink.parse(Uri.parse('/app/social')),
        isA<CustomerSocialLink>(),
      );
      final post = CustomerDeepLink.parse(
        Uri.parse('/app/social/posts/social-post-001'),
      );
      expect((post as CustomerSocialLink).postId, 'social-post-001');
      expect(
        CustomerDeepLink.parse(Uri.parse('/app/social/posts/unsafe%2Fid')),
        isNull,
      );
    });
  });
}

Directory _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (directory.parent.path != directory.path) {
    if (File(
      '${directory.path}/packages/api_client/contracts/social_feed.fixture.json',
    ).existsSync()) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Planext4u workspace root was not found.');
}

final class _SocialFakeRemote implements SocialRemote {
  _SocialFakeRemote({this.conflictOnce = false});

  final bool conflictOnce;
  bool _conflicted = false;
  String? reportReason;
  late SocialPost current = _post();

  @override
  Future<SocialFeedPage> feed({String? cursor, int limit = 20}) async =>
      SocialFeedPage(
        items: [current],
        nextCursor: '',
        rankingVersion: 'socio-feed-v1',
      );

  @override
  Future<SocialPost> post(String id) async {
    if (conflictOnce && _conflicted) {
      current = _post(revision: 2, saved: true);
    }
    return current;
  }

  @override
  Future<SocialPost> createPost(String body) async => _post(
    id: 'social-post-pending',
    body: body,
    status: 'PENDING_REVIEW',
    moderationReason: 'AUTOMATED_REVIEW',
    likeCount: 0,
    commentCount: 0,
  );

  @override
  Future<SocialPost> setLike(SocialPost post, bool active) async {
    current = _post(
      revision: post.revision + 1,
      liked: active,
      likeCount: active ? 43 : 42,
    );
    return current;
  }

  @override
  Future<SocialPost> setSave(SocialPost post, bool active) async {
    if (conflictOnce && !_conflicted) {
      _conflicted = true;
      throw const ApiConflictFailure(
        code: 'SOCIAL_REVISION_CONFLICT',
        message: 'The post changed.',
        correlationId: 'test-correlation',
        retryable: false,
        statusCode: 409,
      );
    }
    current = _post(revision: post.revision + 1, saved: active);
    return current;
  }

  @override
  Future<List<SocialComment>> comments(String postId) async => const [];

  @override
  Future<SocialComment> createComment(
    String postId,
    String body, {
    String? parentId,
  }) async => SocialComment(
    id: 'comment-001',
    postId: postId,
    parentId: parentId ?? '',
    depth: parentId == null ? 0 : 1,
    author: _profile,
    body: body,
    status: 'PUBLISHED',
    createdAt: DateTime.utc(2026, 8, 28, 12),
  );

  @override
  Future<void> report(
    String postId,
    String reason, {
    String details = '',
  }) async {
    reportReason = reason;
  }
}

const _profile = SocialProfile(
  id: 'customer-public-001',
  handle: 'local_guide',
  displayName: 'Local Guide',
  bio: 'Trusted neighbourhood updates',
  isPrivate: false,
  verified: true,
  relationship: 'NONE',
  allowedActions: {'FOLLOW', 'MUTE', 'BLOCK'},
);

SocialPost _post({
  String id = 'social-post-001',
  int revision = 1,
  String body = 'Weekend community market',
  String status = 'PUBLISHED',
  String moderationReason = '',
  int likeCount = 42,
  int commentCount = 8,
  bool liked = false,
  bool saved = false,
}) => SocialPost(
  id: id,
  revision: revision,
  author: _profile,
  body: body,
  mediaAssetIds: const [],
  hashtags: const ['local'],
  mentions: const [],
  sponsored: false,
  sponsorLabel: '',
  status: status,
  moderationReason: moderationReason,
  likeCount: likeCount,
  commentCount: commentCount,
  liked: liked,
  saved: saved,
  allowedActions: const {'LIKE', 'SAVE', 'COMMENT', 'REPORT'},
  rankingVersion: 'socio-feed-v1',
  createdAt: DateTime.utc(2026, 8, 28, 11),
);

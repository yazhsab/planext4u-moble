import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

enum SocialExperienceStatus { idle, loading, ready, submitting, failure }

final class SocialProfile {
  const SocialProfile({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.bio,
    required this.isPrivate,
    required this.verified,
    required this.relationship,
    required this.allowedActions,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  factory SocialProfile.fromJson(Object? value) {
    final json = _socialObject(value, 'social profile');
    return SocialProfile(
      id: _socialString(json, 'id'),
      handle: _socialString(json, 'handle'),
      displayName: _socialString(json, 'display_name'),
      bio: _socialOptionalString(json, 'bio'),
      isPrivate: _socialBool(json, 'private'),
      verified: _socialBool(json, 'verified'),
      relationship: _socialString(json, 'relationship'),
      allowedActions: _socialStrings(json, 'allowed_actions').toSet(),
      followerCount: _socialInt(json, 'follower_count'),
      followingCount: _socialInt(json, 'following_count'),
    );
  }

  final String id;
  final String handle;
  final String displayName;
  final String bio;
  final bool isPrivate;
  final bool verified;
  final String relationship;
  final Set<String> allowedActions;
  final int followerCount;
  final int followingCount;
}

final class SocialPost {
  const SocialPost({
    required this.id,
    required this.revision,
    required this.author,
    required this.body,
    required this.mediaAssetIds,
    required this.hashtags,
    required this.mentions,
    required this.sponsored,
    required this.sponsorLabel,
    required this.status,
    required this.moderationReason,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.saved,
    required this.allowedActions,
    required this.rankingVersion,
    required this.createdAt,
  });

  factory SocialPost.fromJson(Object? value) {
    final json = _socialObject(value, 'social post');
    final revision = _socialInt(json, 'revision');
    final status = _socialString(json, 'status');
    if (revision < 1 ||
        !const {'PUBLISHED', 'PENDING_REVIEW', 'REMOVED'}.contains(status)) {
      throw const FormatException('Social post trust state is invalid.');
    }
    return SocialPost(
      id: _socialString(json, 'id'),
      revision: revision,
      author: SocialProfile.fromJson(json['author']),
      body: _socialString(json, 'body'),
      mediaAssetIds: _socialStrings(json, 'media_asset_ids'),
      hashtags: _socialStrings(json, 'hashtags'),
      mentions: _socialStrings(json, 'mentions'),
      sponsored: _socialBool(json, 'sponsored'),
      sponsorLabel: _socialOptionalString(json, 'sponsor_label'),
      status: status,
      moderationReason: _socialOptionalString(json, 'moderation_reason'),
      likeCount: _socialInt(json, 'like_count'),
      commentCount: _socialInt(json, 'comment_count'),
      liked: _socialBool(json, 'liked'),
      saved: _socialBool(json, 'saved'),
      allowedActions: _socialStrings(json, 'allowed_actions').toSet(),
      rankingVersion: _socialString(json, 'ranking_version'),
      createdAt: _socialInstant(json, 'created_at'),
    );
  }

  final String id;
  final int revision;
  final SocialProfile author;
  final String body;
  final List<String> mediaAssetIds;
  final List<String> hashtags;
  final List<String> mentions;
  final bool sponsored;
  final String sponsorLabel;
  final String status;
  final String moderationReason;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool saved;
  final Set<String> allowedActions;
  final String rankingVersion;
  final DateTime createdAt;

  bool get published => status == 'PUBLISHED';
  bool get pendingReview => status == 'PENDING_REVIEW';
}

final class SocialComment {
  const SocialComment({
    required this.id,
    required this.postId,
    required this.parentId,
    required this.depth,
    required this.author,
    required this.body,
    required this.status,
    required this.createdAt,
  });

  factory SocialComment.fromJson(Object? value) {
    final json = _socialObject(value, 'social comment');
    final depth = _socialInt(json, 'depth');
    if (depth < 0 || depth > 2) {
      throw const FormatException('Social comment depth is invalid.');
    }
    return SocialComment(
      id: _socialString(json, 'id'),
      postId: _socialString(json, 'post_id'),
      parentId: _socialOptionalString(json, 'parent_id'),
      depth: depth,
      author: SocialProfile.fromJson(json['author']),
      body: _socialString(json, 'body'),
      status: _socialString(json, 'status'),
      createdAt: _socialInstant(json, 'created_at'),
    );
  }

  final String id;
  final String postId;
  final String parentId;
  final int depth;
  final SocialProfile author;
  final String body;
  final String status;
  final DateTime createdAt;
}

final class SocialFeedPage {
  const SocialFeedPage({
    required this.items,
    required this.nextCursor,
    required this.rankingVersion,
  });

  factory SocialFeedPage.fromJson(Object? value) {
    final json = _socialObject(value, 'social feed');
    return SocialFeedPage(
      items: _socialList(json, 'items').map(SocialPost.fromJson).toList(),
      nextCursor: _socialOptionalString(json, 'next_cursor'),
      rankingVersion: _socialString(json, 'ranking_version'),
    );
  }

  final List<SocialPost> items;
  final String nextCursor;
  final String rankingVersion;
}

abstract interface class SocialRemote {
  Future<SocialFeedPage> feed({String? cursor, int limit = 20});
  Future<SocialPost> post(String id);
  Future<SocialPost> createPost(String body);
  Future<SocialPost> setLike(SocialPost post, bool active);
  Future<SocialPost> setSave(SocialPost post, bool active);
  Future<List<SocialComment>> comments(String postId);
  Future<SocialComment> createComment(
    String postId,
    String body, {
    String? parentId,
  });
  Future<void> report(String postId, String reason, {String details = ''});
}

abstract interface class SocialRelationshipRemote {
  Future<SocialProfile> profile(String id);
  Future<SocialProfile> follow(String id);
  Future<SocialProfile> setRelationship(String id, String action);
}

final class SocialApi implements SocialRemote, SocialRelationshipRemote {
  const SocialApi(this._client);

  final ApiClient _client;

  @override
  Future<SocialFeedPage> feed({String? cursor, int limit = 20}) async =>
      (await _client.send(
        ApiRequest.get(
          operation: 'social.feed',
          path: '/v1/social/feed',
          query: {
            'limit': ['$limit'],
            if (cursor?.isNotEmpty == true) 'cursor': [cursor!],
          },
        ),
        SocialFeedPage.fromJson,
      )).value;

  @override
  Future<SocialPost> post(String id) async => (await _client.send(
    ApiRequest.get(
      operation: 'social.post',
      path: '/v1/social/posts/${Uri.encodeComponent(id)}',
    ),
    SocialPost.fromJson,
  )).value;

  @override
  Future<SocialProfile> profile(String id) async => (await _client.send(
    ApiRequest.get(
      operation: 'social.profile',
      path: '/v1/social/profiles/${Uri.encodeComponent(id)}',
    ),
    SocialProfile.fromJson,
  )).value;

  @override
  Future<SocialProfile> follow(String id) async {
    await _client.send(
      ApiRequest.command(
        operation: 'social.follow',
        method: 'POST',
        path: '/v1/social/profiles/${Uri.encodeComponent(id)}/follow',
        body: null,
      ),
      (value) => _socialString(_socialObject(value, 'social follow'), 'status'),
    );
    return profile(id);
  }

  @override
  Future<SocialProfile> setRelationship(String id, String action) async =>
      (await _client.send(
        ApiRequest.command(
          operation: 'social.set_relationship',
          method: 'PUT',
          path: '/v1/social/profiles/${Uri.encodeComponent(id)}/relationship',
          body: {'action': action},
        ),
        SocialProfile.fromJson,
      )).value;

  @override
  Future<SocialPost> createPost(String body) async => (await _client.send(
    ApiRequest.command(
      operation: 'social.create_post',
      method: 'POST',
      path: '/v1/social/posts',
      body: {'body': body.trim(), 'media_asset_ids': <String>[]},
    ),
    SocialPost.fromJson,
  )).value;

  @override
  Future<SocialPost> setLike(SocialPost post, bool active) =>
      _setEngagement(post, 'like', active);

  @override
  Future<SocialPost> setSave(SocialPost post, bool active) =>
      _setEngagement(post, 'save', active);

  Future<SocialPost> _setEngagement(
    SocialPost post,
    String action,
    bool active,
  ) async => (await _client.send(
    ApiRequest.command(
      operation: 'social.set_$action',
      method: 'PUT',
      path: '/v1/social/posts/${Uri.encodeComponent(post.id)}/$action',
      headers: {'If-Match': '"${post.revision}"'},
      body: {'active': active},
    ),
    SocialPost.fromJson,
  )).value;

  @override
  Future<List<SocialComment>> comments(String postId) async =>
      (await _client.send(
        ApiRequest.get(
          operation: 'social.comments',
          path: '/v1/social/posts/${Uri.encodeComponent(postId)}/comments',
        ),
        (value) {
          final json = _socialObject(value, 'social comments');
          return _socialList(
            json,
            'items',
          ).map(SocialComment.fromJson).toList();
        },
      )).value;

  @override
  Future<SocialComment> createComment(
    String postId,
    String body, {
    String? parentId,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'social.create_comment',
      method: 'POST',
      path: '/v1/social/posts/${Uri.encodeComponent(postId)}/comments',
      body: {
        'body': body.trim(),
        if (parentId?.isNotEmpty == true) 'parent_id': parentId,
      },
    ),
    SocialComment.fromJson,
  )).value;

  @override
  Future<void> report(
    String postId,
    String reason, {
    String details = '',
  }) async {
    await _client.send(
      ApiRequest.command(
        operation: 'social.report_post',
        method: 'POST',
        path: '/v1/social/posts/${Uri.encodeComponent(postId)}/reports',
        body: {'reason': reason, 'details': details.trim()},
      ),
      (_) {},
    );
  }
}

final class SocialState {
  const SocialState({
    this.status = SocialExperienceStatus.idle,
    this.items = const [],
    this.nextCursor = '',
    this.rankingVersion = '',
    this.comments = const [],
    this.openPostId,
    this.message,
  });

  final SocialExperienceStatus status;
  final List<SocialPost> items;
  final String nextCursor;
  final String rankingVersion;
  final List<SocialComment> comments;
  final String? openPostId;
  final String? message;

  bool get loading => status == SocialExperienceStatus.loading;
  bool get submitting => status == SocialExperienceStatus.submitting;
  bool get canLoadMore => nextCursor.isNotEmpty;

  SocialState copyWith({
    SocialExperienceStatus? status,
    List<SocialPost>? items,
    String? nextCursor,
    String? rankingVersion,
    List<SocialComment>? comments,
    String? openPostId,
    bool clearOpenPost = false,
    String? message,
    bool clearMessage = false,
  }) => SocialState(
    status: status ?? this.status,
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    rankingVersion: rankingVersion ?? this.rankingVersion,
    comments: comments ?? this.comments,
    openPostId: clearOpenPost ? null : openPostId ?? this.openPostId,
    message: clearMessage ? null : message ?? this.message,
  );
}

final class SocialController extends ChangeNotifier {
  SocialController({required SocialRemote remote}) : _remote = remote;

  final SocialRemote _remote;
  SocialState _state = const SocialState();
  SocialState get state => _state;

  SocialRelationshipRemote? get _relationships =>
      _remote is SocialRelationshipRemote
      ? _remote as SocialRelationshipRemote
      : null;

  Future<SocialProfile> profile(String id) async {
    final remote = _relationships;
    if (remote == null) {
      throw StateError('Social relationship features are unavailable.');
    }
    return remote.profile(id);
  }

  Future<SocialProfile> followProfile(String id) async {
    final remote = _relationships;
    if (remote == null) {
      throw StateError('Social relationship features are unavailable.');
    }
    return remote.follow(id);
  }

  Future<SocialProfile> setProfileRelationship(String id, String action) async {
    final remote = _relationships;
    if (remote == null) {
      throw StateError('Social relationship features are unavailable.');
    }
    final profile = await remote.setRelationship(id, action);
    if (action == 'BLOCK' || action == 'MUTE') {
      await loadFeed();
    }
    return profile;
  }

  Future<void> loadFeed({bool refresh = true}) async {
    if (_state.loading || _state.submitting) return;
    _set(
      _state.copyWith(
        status: SocialExperienceStatus.loading,
        clearMessage: true,
      ),
    );
    try {
      final page = await _remote.feed(
        cursor: refresh ? null : _state.nextCursor,
      );
      final items = refresh
          ? page.items
          : [..._state.items, ...page.items.where(_isNewPost)];
      _set(
        _state.copyWith(
          status: SocialExperienceStatus.ready,
          items: List.unmodifiable(items),
          nextCursor: page.nextCursor,
          rankingVersion: page.rankingVersion,
        ),
      );
    } catch (error) {
      _failure(error, 'The Socio feed could not be loaded.');
    }
  }

  bool _isNewPost(SocialPost post) =>
      !_state.items.any((existing) => existing.id == post.id);

  Future<void> createPost(String body) async {
    final value = body.trim();
    if (value.isEmpty || value.length > 2000 || _state.submitting) return;
    _set(
      _state.copyWith(
        status: SocialExperienceStatus.submitting,
        clearMessage: true,
      ),
    );
    try {
      final post = await _remote.createPost(value);
      _set(
        _state.copyWith(
          status: SocialExperienceStatus.ready,
          items: List.unmodifiable([post, ..._state.items]),
          message: post.pendingReview
              ? 'Post submitted for review. Only you can see it for now.'
              : 'Post published.',
        ),
      );
    } catch (error) {
      _failure(error, 'The post could not be submitted.');
    }
  }

  Future<void> toggleLike(SocialPost post) =>
      _engage(post, () => _remote.setLike(post, !post.liked));

  Future<void> toggleSave(SocialPost post) =>
      _engage(post, () => _remote.setSave(post, !post.saved));

  Future<void> _engage(
    SocialPost post,
    Future<SocialPost> Function() command,
  ) async {
    if (_state.submitting) return;
    _set(
      _state.copyWith(
        status: SocialExperienceStatus.submitting,
        clearMessage: true,
      ),
    );
    try {
      _replace(await command());
    } on ApiConflictFailure {
      try {
        _replace(await _remote.post(post.id));
        _set(
          _state.copyWith(message: 'This post changed. Latest state loaded.'),
        );
      } catch (error) {
        _failure(error, 'The latest post state could not be loaded.');
      }
    } catch (error) {
      _failure(error, 'The social action could not be completed.');
    }
  }

  void _replace(SocialPost post) {
    final items = [
      for (final item in _state.items)
        if (item.id == post.id) post else item,
    ];
    _set(
      _state.copyWith(
        status: SocialExperienceStatus.ready,
        items: List.unmodifiable(items),
      ),
    );
  }

  Future<void> openComments(String postId) async {
    _set(
      _state.copyWith(
        status: SocialExperienceStatus.loading,
        openPostId: postId,
        comments: const [],
        clearMessage: true,
      ),
    );
    try {
      final comments = await _remote.comments(postId);
      _set(
        _state.copyWith(
          status: SocialExperienceStatus.ready,
          comments: List.unmodifiable(comments),
        ),
      );
    } catch (error) {
      _failure(error, 'Comments could not be loaded.');
    }
  }

  Future<void> createComment(String body, {String? parentId}) async {
    final postId = _state.openPostId;
    final value = body.trim();
    if (postId == null || value.isEmpty || value.length > 1000) return;
    _set(
      _state.copyWith(
        status: SocialExperienceStatus.submitting,
        clearMessage: true,
      ),
    );
    try {
      final comment = await _remote.createComment(
        postId,
        value,
        parentId: parentId,
      );
      _set(
        _state.copyWith(
          status: SocialExperienceStatus.ready,
          comments: List.unmodifiable([..._state.comments, comment]),
          message: 'Comment published.',
        ),
      );
      try {
        _replace(await _remote.post(postId));
      } catch (_) {
        // The accepted comment remains visible while counts refresh later.
      }
    } catch (error) {
      _failure(error, 'The comment could not be published.');
    }
  }

  Future<void> report(String postId, String reason) async {
    if (_state.submitting) return;
    _set(
      _state.copyWith(
        status: SocialExperienceStatus.submitting,
        clearMessage: true,
      ),
    );
    try {
      await _remote.report(postId, reason);
      _set(
        _state.copyWith(
          status: SocialExperienceStatus.ready,
          message: 'Report submitted to the moderation team.',
        ),
      );
    } catch (error) {
      _failure(error, 'The report could not be submitted.');
    }
  }

  void closeComments() => _set(
    _state.copyWith(
      comments: const [],
      clearOpenPost: true,
      clearMessage: true,
    ),
  );

  void clearMessage() => _set(_state.copyWith(clearMessage: true));

  void _failure(Object error, String fallback) {
    _set(
      _state.copyWith(
        status: SocialExperienceStatus.failure,
        message: error is ApiFailure ? error.message : fallback,
      ),
    );
  }

  void _set(SocialState value) {
    _state = value;
    notifyListeners();
  }
}

Map<String, Object?> _socialObject(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}

String _socialString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String _socialOptionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return '';
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

bool _socialBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

int _socialInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('$key must be a non-negative integer.');
  }
  return value;
}

List<Object?> _socialList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key must be a list.');
  return value;
}

List<String> _socialStrings(Map<String, Object?> json, String key) {
  final values = _socialList(json, key);
  if (values.any((value) => value is! String)) {
    throw FormatException('$key must contain strings.');
  }
  return List<String>.unmodifiable(values.cast<String>());
}

DateTime _socialInstant(Map<String, Object?> json, String key) {
  final instant = DateTime.tryParse(_socialString(json, key));
  if (instant == null || !instant.isUtc) {
    throw FormatException('$key must be a UTC timestamp.');
  }
  return instant;
}

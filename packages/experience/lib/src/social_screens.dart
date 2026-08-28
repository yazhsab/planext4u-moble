import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'social.dart';

final class CustomerSocialScreen extends StatefulWidget {
  const CustomerSocialScreen({
    required this.controller,
    this.initialPostId,
    super.key,
  });

  final SocialController controller;
  final String? initialPostId;

  @override
  State<CustomerSocialScreen> createState() => _CustomerSocialScreenState();
}

class _CustomerSocialScreenState extends State<CustomerSocialScreen> {
  bool _openedInitialPost = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.status == SocialExperienceStatus.idle) {
      unawaited(widget.controller.loadFeed());
    }
    if (widget.initialPostId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openComments(widget.initialPostId!));
      });
    }
  }

  @override
  void didUpdateWidget(CustomerSocialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Socio'),
        actions: [
          IconButton(
            tooltip: 'Refresh Socio feed',
            onPressed: state.loading ? null : widget.controller.loadFeed,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('create-social-post'),
        onPressed: state.submitting ? null : _compose,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Create post'),
      ),
      body: SafeArea(child: _body(state)),
    );
  }

  Widget _body(SocialState state) {
    if (state.loading && state.items.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Loading Socio',
        message: 'Finding trusted updates from your community.',
      );
    }
    if (state.status == SocialExperienceStatus.failure && state.items.isEmpty) {
      return Planext4uStatePanel(
        state: Planext4uViewState.error,
        title: 'Socio is unavailable',
        message: state.message ?? 'The community feed could not be loaded.',
        actionLabel: 'Try again',
        onAction: widget.controller.loadFeed,
      );
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.controller.loadFeed,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 96),
            Planext4uStatePanel(
              state: Planext4uViewState.empty,
              title: 'Your Socio feed is ready',
              message: 'Follow local people or create the first update.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: widget.controller.loadFeed,
      child: ListView.builder(
        key: const ValueKey('social-feed'),
        padding: const EdgeInsets.only(bottom: 96),
        itemCount:
            state.items.length +
            (state.canLoadMore || state.message != null || state.submitting
                ? 1
                : 0),
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            final post = state.items[index];
            return _SocialPostCard(
              key: ValueKey('social-post-${post.id}'),
              post: post,
              disabled: state.submitting,
              onLike: () => widget.controller.toggleLike(post),
              onSave: () => widget.controller.toggleSave(post),
              onComments: () => _openComments(post.id),
              onReport: () => _report(post),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(Planext4uSpacing.x4),
            child: Column(
              children: [
                if (state.submitting) const LinearProgressIndicator(),
                if (state.message != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.message!,
                      key: const ValueKey('social-message'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (state.canLoadMore)
                  TextButton(
                    onPressed: state.loading
                        ? null
                        : () => widget.controller.loadFeed(refresh: false),
                    child: const Text('Load more'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _compose() async {
    final body = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const _ComposeSocialScreen()),
    );
    if (body != null) await widget.controller.createPost(body);
  }

  Future<void> _openComments(String postId) async {
    if (_openedInitialPost && widget.initialPostId == postId) return;
    if (widget.initialPostId == postId) _openedInitialPost = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SocialCommentsScreen(controller: widget.controller, postId: postId),
      ),
    );
    widget.controller.closeComments();
  }

  Future<void> _report(SocialPost post) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report this post'),
        children: [
          for (final option in const {
            'SPAM': 'Spam or misleading',
            'HARASSMENT': 'Harassment',
            'UNSAFE': 'Unsafe content',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(option.value),
              ),
            ),
        ],
      ),
    );
    if (reason != null) await widget.controller.report(post.id, reason);
  }
}

final class _ComposeSocialScreen extends StatefulWidget {
  const _ComposeSocialScreen();

  @override
  State<_ComposeSocialScreen> createState() => _ComposeSocialScreenState();
}

class _ComposeSocialScreenState extends State<_ComposeSocialScreen> {
  final _text = TextEditingController();

  Future<void> _submit() async {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create Socio post')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        children: [
          TextField(
            key: const ValueKey('social-post-body'),
            controller: _text,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'Share a useful update with your community',
            ),
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          FilledButton.icon(
            key: const ValueKey('submit-social-post'),
            onPressed: _submit,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Post'),
          ),
        ],
      ),
    ),
  );
}

final class _SocialPostCard extends StatelessWidget {
  const _SocialPostCard({
    required this.post,
    required this.disabled,
    required this.onLike,
    required this.onSave,
    required this.onComments,
    required this.onReport,
    super.key,
  });

  final SocialPost post;
  final bool disabled;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComments;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(
      Planext4uSpacing.x3,
      Planext4uSpacing.x3,
      Planext4uSpacing.x3,
      0,
    ),
    child: Padding(
      padding: const EdgeInsets.all(Planext4uSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.sponsored)
            Padding(
              padding: const EdgeInsets.only(bottom: Planext4uSpacing.x2),
              child: Text(
                post.sponsorLabel.isEmpty ? 'Sponsored' : post.sponsorLabel,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          Row(
            children: [
              CircleAvatar(
                child: Text(post.author.displayName.characters.first),
              ),
              const SizedBox(width: Planext4uSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.author.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (post.author.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 17,
                            semanticLabel: 'Verified profile',
                          ),
                        ],
                        if (post.author.isPrivate) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.lock_outline,
                            size: 16,
                            semanticLabel: 'Private profile',
                          ),
                        ],
                      ],
                    ),
                    Text('@${post.author.handle}'),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Post options',
                enabled: !disabled && post.allowedActions.contains('REPORT'),
                onSelected: (_) => onReport(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'report', child: Text('Report post')),
                ],
              ),
            ],
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          Text(post.body),
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: Planext4uSpacing.x2),
            Text(
              post.hashtags.map((value) => '#$value').join(' '),
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
          if (!post.published) ...[
            const SizedBox(height: Planext4uSpacing.x3),
            Chip(
              avatar: const Icon(Icons.shield_outlined, size: 18),
              label: Text(
                post.pendingReview ? 'Pending moderation review' : 'Removed',
              ),
            ),
            if (post.moderationReason.isNotEmpty)
              Text(
                post.moderationReason,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          const Divider(height: Planext4uSpacing.x5),
          Wrap(
            spacing: Planext4uSpacing.x1,
            children: [
              TextButton.icon(
                key: ValueKey('like-${post.id}'),
                onPressed: !disabled && post.allowedActions.contains('LIKE')
                    ? onLike
                    : null,
                icon: Icon(post.liked ? Icons.favorite : Icons.favorite_border),
                label: Text('${post.likeCount}'),
              ),
              TextButton.icon(
                key: ValueKey('comments-${post.id}'),
                onPressed: post.allowedActions.contains('COMMENT')
                    ? onComments
                    : null,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text('${post.commentCount}'),
              ),
              TextButton.icon(
                key: ValueKey('save-${post.id}'),
                onPressed: !disabled && post.allowedActions.contains('SAVE')
                    ? onSave
                    : null,
                icon: Icon(post.saved ? Icons.bookmark : Icons.bookmark_border),
                label: Text(post.saved ? 'Saved' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class SocialCommentsScreen extends StatefulWidget {
  const SocialCommentsScreen({
    required this.controller,
    required this.postId,
    super.key,
  });

  final SocialController controller;
  final String postId;

  @override
  State<SocialCommentsScreen> createState() => _SocialCommentsScreenState();
}

class _SocialCommentsScreenState extends State<SocialCommentsScreen> {
  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.openComments(widget.postId));
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _body.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    await widget.controller.createComment(body);
    if (widget.controller.state.status != SocialExperienceStatus.failure) {
      _body.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.loading && state.comments.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.comments.isEmpty
                  ? const Planext4uStatePanel(
                      state: Planext4uViewState.empty,
                      title: 'No comments yet',
                      message: 'Start a respectful conversation.',
                    )
                  : ListView.builder(
                      key: const ValueKey('social-comments'),
                      padding: const EdgeInsets.all(Planext4uSpacing.x3),
                      itemCount: state.comments.length,
                      itemBuilder: (context, index) {
                        final comment = state.comments[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            left: comment.depth * Planext4uSpacing.x4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                comment.author.displayName.characters.first,
                              ),
                            ),
                            title: Text(comment.author.displayName),
                            subtitle: Text(comment.body),
                          ),
                        );
                      },
                    ),
            ),
            if (state.message != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(state.message!),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Planext4uSpacing.x3,
                Planext4uSpacing.x2,
                Planext4uSpacing.x3,
                Planext4uSpacing.x3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('social-comment-body'),
                      controller: _body,
                      maxLength: 1000,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'Add a respectful comment',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    key: const ValueKey('submit-social-comment'),
                    tooltip: 'Post comment',
                    onPressed: state.submitting ? null : _submit,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

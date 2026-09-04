import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'phase5.dart';

/// Platform WebRTC adapters create opaque session descriptions locally. The
/// backend only relays those descriptions and remains authoritative for call
/// policy, expiry and block state.
abstract interface class SocialRtcOfferProvider {
  Future<String> createOffer(SocialCall call);
  Future<void> close();
}

typedef SocialRtcOfferProviderFactory = SocialRtcOfferProvider Function();

final class CustomerCommunityHubScreen extends StatefulWidget {
  const CustomerCommunityHubScreen({
    required this.controller,
    this.initialTab = 0,
    this.mediaCoordinator,
    this.rtcProviderFactory,
    super.key,
  });
  final Phase5Controller controller;
  final int initialTab;
  final CommunityMediaCoordinator? mediaCoordinator;
  final SocialRtcOfferProviderFactory? rtcProviderFactory;
  @override
  State<CustomerCommunityHubScreen> createState() =>
      _CustomerCommunityHubScreenState();
}

class _CustomerCommunityHubScreenState
    extends State<CustomerCommunityHubScreen> {
  String? _shownMessage;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.status == Phase5Status.idle) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void didUpdateWidget(CustomerCommunityHubScreen oldWidget) {
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
    if (!mounted) return;
    setState(() {});
    final message = widget.controller.state.message;
    if (message != null && message != _shownMessage) {
      _shownMessage = message;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              action: SnackBarAction(
                label: 'Dismiss',
                onPressed: widget.controller.clearMessage,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Socio+'),
              Tab(icon: Icon(Icons.home_work_outlined), text: 'Homes'),
              Tab(icon: Icon(Icons.sell_outlined), text: 'Classifieds'),
              Tab(icon: Icon(Icons.emergency_outlined), text: 'Emergency'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh community',
              onPressed: state.busy ? null : widget.controller.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(child: _body(state)),
      ),
    );
  }

  Widget _body(Phase5State state) {
    if (state.status == Phase5Status.loading && state.homes.isEmpty) {
      return const Center(
        child: Planext4uStatePanel(
          state: Planext4uViewState.loading,
          title: 'Loading community',
          message: 'Fetching privacy-filtered local services.',
        ),
      );
    }
    if (state.status == Phase5Status.failure && state.homes.isEmpty) {
      return Center(
        child: Planext4uStatePanel(
          state: Planext4uViewState.error,
          title: 'Community is unavailable',
          message: state.message ?? 'Try again.',
          actionLabel: 'Retry',
          onAction: widget.controller.load,
        ),
      );
    }
    return TabBarView(
      children: [
        _SocioPlusTab(
          controller: widget.controller,
          state: state,
          mediaCoordinator: widget.mediaCoordinator,
          rtcProviderFactory: widget.rtcProviderFactory,
        ),
        _HomesTab(controller: widget.controller, state: state),
        _ClassifiedsTab(
          controller: widget.controller,
          state: state,
          mediaCoordinator: widget.mediaCoordinator,
        ),
        _EmergencyTab(controller: widget.controller, state: state),
      ],
    );
  }
}

final class _SocioPlusTab extends StatelessWidget {
  const _SocioPlusTab({
    required this.controller,
    required this.state,
    this.mediaCoordinator,
    this.rtcProviderFactory,
  });
  final Phase5Controller controller;
  final Phase5State state;
  final CommunityMediaCoordinator? mediaCoordinator;
  final SocialRtcOfferProviderFactory? rtcProviderFactory;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: controller.load,
    child: ListView(
      key: const ValueKey('phase5-socio-tab'),
      padding: const EdgeInsets.all(Planext4uSpacing.x4),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Stories, reels & highlights',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              key: const ValueKey('create-story'),
              tooltip: 'Create story or reel',
              onPressed: state.busy ? null : () => _createStory(context),
              icon: const Icon(Icons.add_to_photos_outlined),
            ),
            IconButton(
              key: const ValueKey('create-collection'),
              tooltip: 'Create collection',
              onPressed: state.busy ? null : () => _collection(context),
              icon: const Icon(Icons.collections_bookmark_outlined),
            ),
          ],
        ),
        const Text(
          'Media is quarantined and scanned before publication. Expired stories disappear unless highlighted.',
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        if (state.stories.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.auto_stories_outlined),
              title: Text('No active stories'),
              subtitle: Text(
                'Ready stories and reels will appear here after safety processing.',
              ),
            ),
          )
        else
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.stories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = state.stories[index];
                return SizedBox(
                  width: 120,
                  child: Card(
                    child: InkWell(
                      onLongPress: item.allowedActions.contains('HIGHLIGHT')
                          ? () =>
                                controller.setHighlight(item, !item.highlighted)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              item.kind == 'REEL'
                                  ? Icons.movie_outlined
                                  : Icons.auto_stories_outlined,
                            ),
                            const Spacer(),
                            Text(
                              item.caption.isEmpty ? item.kind : item.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.highlighted
                                  ? 'Highlight'
                                  : _remaining(item.expiresAt),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: Planext4uSpacing.x5),
        Row(
          children: [
            Expanded(
              child: Text(
                'Messages',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('new-message-request'),
              onPressed: state.busy ? null : () => _newConversation(context),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New'),
            ),
          ],
        ),
        const Text(
          'Unknown contacts arrive as requests. Blocking always takes precedence over delivery, presence and calls.',
        ),
        const SizedBox(height: Planext4uSpacing.x2),
        if (state.conversations.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.mark_chat_unread_outlined),
              title: Text('No conversations yet'),
              subtitle: Text('Start a request from a community profile.'),
            ),
          )
        else
          for (final conversation in state.conversations)
            Card(
              child: ListTile(
                key: ValueKey('conversation-${conversation.id}'),
                leading: CircleAvatar(
                  child: Icon(
                    conversation.status == 'ACCEPTED'
                        ? Icons.chat_bubble_outline
                        : Icons.mark_chat_unread_outlined,
                  ),
                ),
                title: Text(
                  conversation.status == 'ACCEPTED'
                      ? 'Conversation'
                      : 'Message request',
                ),
                subtitle: Text(
                  conversation.participantIds.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerConversationScreen(
                      controller: controller,
                      conversation: conversation,
                      mediaCoordinator: mediaCoordinator,
                      rtcProviderFactory: rtcProviderFactory,
                    ),
                  ),
                ),
              ),
            ),
      ],
    ),
  );
  Future<void> _collection(BuildContext context) async {
    final name = await _textDialog(
      context,
      title: 'New collection',
      label: 'Collection name',
    );
    if (name != null) await controller.createCollection(name);
  }

  Future<void> _createStory(BuildContext context) async {
    final kind = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose format'),
        children: [
          SimpleDialogOption(
            key: const ValueKey('create-story-kind'),
            onPressed: () => Navigator.pop(context, 'STORY'),
            child: const ListTile(
              leading: Icon(Icons.auto_stories_outlined),
              title: Text('Story'),
              subtitle: Text('Expires after 24 hours'),
            ),
          ),
          SimpleDialogOption(
            key: const ValueKey('create-reel-kind'),
            onPressed: () => Navigator.pop(context, 'REEL'),
            child: const ListTile(
              leading: Icon(Icons.movie_outlined),
              title: Text('Reel'),
              subtitle: Text('Short safety-scanned video'),
            ),
          ),
        ],
      ),
    );
    if (kind == null || !context.mounted) return;
    final coordinator = mediaCoordinator;
    if (coordinator == null) {
      await _captureFeedback(
        context,
        'Media capture is unavailable until the private upload and moderation provider is configured.',
      );
      return;
    }
    String? asset;
    try {
      asset = await coordinator.captureAndUpload(
        kind == 'STORY'
            ? CommunityMediaKind.storyImage
            : CommunityMediaKind.reelVideo,
      );
    } on CommunityCaptureException catch (error) {
      if (context.mounted) await _captureFeedback(context, error.message);
      return;
    } catch (_) {
      if (context.mounted) {
        await _captureFeedback(
          context,
          'The private media provider is unavailable.',
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (asset == null) {
      await _captureFeedback(context, 'Media capture cancelled.');
      return;
    }
    final caption = await _textDialog(
      context,
      title: 'Add a caption',
      label: 'Caption',
    );
    if (caption == null) return;
    await controller.createStory(assetId: asset, kind: kind, caption: caption);
  }

  Future<void> _newConversation(BuildContext context) async {
    final profile = await _textDialog(
      context,
      title: 'New message request',
      label: 'Profile identifier',
      initial: 'customer-public-synthetic-001',
    );
    if (profile == null) return;
    final value = await controller.openConversation(profile);
    if (context.mounted && value != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CustomerConversationScreen(
            controller: controller,
            conversation: value,
            mediaCoordinator: mediaCoordinator,
            rtcProviderFactory: rtcProviderFactory,
          ),
        ),
      );
    }
  }
}

final class CustomerConversationScreen extends StatefulWidget {
  const CustomerConversationScreen({
    required this.controller,
    required this.conversation,
    this.mediaCoordinator,
    this.rtcProviderFactory,
    super.key,
  });
  final Phase5Controller controller;
  final SocialConversation conversation;
  final CommunityMediaCoordinator? mediaCoordinator;
  final SocialRtcOfferProviderFactory? rtcProviderFactory;
  @override
  State<CustomerConversationScreen> createState() =>
      _CustomerConversationScreenState();
}

class _CustomerConversationScreenState
    extends State<CustomerConversationScreen> {
  final _body = TextEditingController();
  List<SocialMessage>? _messages;
  Object? _failure;
  Timer? _voiceTimer;
  bool _voiceRecording = false;
  bool _voiceBusy = false;
  int _voiceSeconds = 0;
  String? _voiceMessage;
  String? _callMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    if (_voiceRecording) {
      unawaited(widget.mediaCoordinator?.cancelVoice());
    }
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _messages = await widget.controller.messages(widget.conversation.id);
      _failure = null;
    } catch (error) {
      _failure = error;
    }
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final value = _body.text.trim();
    if (value.isEmpty) return;
    await widget.controller.sendMessage(widget.conversation.id, value);
    _body.clear();
    await _load();
  }

  Future<void> _toggleVoice() =>
      _voiceRecording ? _finishVoice() : _startVoice();

  Future<void> _startVoice() async {
    final coordinator = widget.mediaCoordinator;
    if (_voiceBusy) return;
    if (coordinator == null) {
      setState(
        () => _voiceMessage =
            'Voice recording requires the configured private media provider.',
      );
      return;
    }
    setState(() {
      _voiceBusy = true;
      _voiceMessage = null;
    });
    try {
      await coordinator.startVoice();
      if (!mounted) {
        await coordinator.cancelVoice();
        return;
      }
      setState(() {
        _voiceRecording = true;
        _voiceSeconds = 0;
      });
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _voiceSeconds++);
        if (_voiceSeconds >=
            CommunityMediaCoordinator.maxVoiceDuration.inSeconds) {
          timer.cancel();
          unawaited(_finishVoice());
        }
      });
    } on CommunityCaptureException catch (error) {
      if (mounted) setState(() => _voiceMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _voiceMessage = 'The microphone provider is unavailable.',
        );
      }
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  Future<void> _finishVoice() async {
    final coordinator = widget.mediaCoordinator;
    if (!_voiceRecording || _voiceBusy || coordinator == null) return;
    _voiceTimer?.cancel();
    setState(() {
      _voiceBusy = true;
      _voiceRecording = false;
      _voiceMessage = 'Uploading voice note securely…';
    });
    try {
      final assetId = await coordinator.stopVoiceAndUpload();
      if (assetId == null) {
        if (mounted) setState(() => _voiceMessage = 'Voice note cancelled.');
        return;
      }
      final mediaJobId = await widget.controller.prepareVoiceMessage(assetId);
      if (mediaJobId == null) {
        if (mounted) {
          setState(() => _voiceMessage = widget.controller.state.message);
        }
        return;
      }
      await widget.controller.sendMessage(
        widget.conversation.id,
        '',
        voiceMediaId: mediaJobId,
      );
      await _load();
      if (mounted) setState(() => _voiceMessage = 'Voice note sent.');
    } on CommunityCaptureException catch (error) {
      if (mounted) setState(() => _voiceMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _voiceMessage = 'Voice note could not be sent.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _voiceBusy = false;
          _voiceSeconds = 0;
        });
      }
    }
  }

  Future<void> _cancelVoice() async {
    final coordinator = widget.mediaCoordinator;
    if (!_voiceRecording || _voiceBusy || coordinator == null) return;
    _voiceTimer?.cancel();
    setState(() {
      _voiceBusy = true;
      _voiceRecording = false;
    });
    try {
      await coordinator.cancelVoice();
      if (mounted) setState(() => _voiceMessage = 'Voice note discarded.');
    } catch (_) {
      if (mounted) {
        setState(() => _voiceMessage = 'Voice recording could not be closed.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _voiceBusy = false;
          _voiceSeconds = 0;
        });
      }
    }
  }

  Future<void> _call(String kind) async {
    final requiredAction = kind == 'VIDEO' ? 'VIDEO_CALL' : 'AUDIO_CALL';
    final providerFactory = widget.rtcProviderFactory;
    if (widget.conversation.status != 'ACCEPTED' ||
        !widget.conversation.allowedActions.contains(requiredAction) ||
        providerFactory == null) {
      setState(
        () => _callMessage = providerFactory == null
            ? 'Secure calling is unavailable until the WebRTC provider is configured.'
            : 'This conversation does not permit a ${kind.toLowerCase()} call.',
      );
      return;
    }
    final value = await widget.controller.createCall(
      widget.conversation.id,
      kind,
    );
    if (mounted && value != null) {
      SocialRtcOfferProvider provider;
      try {
        provider = providerFactory();
      } catch (_) {
        setState(
          () => _callMessage = 'The secure calling provider is unavailable.',
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SocialCallScreen(
            controller: widget.controller,
            initialCall: value,
            rtcProvider: provider,
          ),
        ),
      );
    }
  }

  bool _canCall(String kind) =>
      widget.rtcProviderFactory != null &&
      widget.conversation.status == 'ACCEPTED' &&
      widget.conversation.allowedActions.contains(
        kind == 'VIDEO' ? 'VIDEO_CALL' : 'AUDIO_CALL',
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Conversation'),
      actions: [
        IconButton(
          tooltip: 'Start audio call',
          onPressed: _canCall('AUDIO') ? () => _call('AUDIO') : null,
          icon: const Icon(Icons.call_outlined),
        ),
        IconButton(
          tooltip: 'Start video call',
          onPressed: _canCall('VIDEO') ? () => _call('VIDEO') : null,
          icon: const Icon(Icons.videocam_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (widget.conversation.status != 'ACCEPTED')
            MaterialBanner(
              content: const Text(
                'This is a message request. Messaging and calls unlock after acceptance.',
              ),
              actions: [
                if (widget.conversation.allowedActions.contains('ACCEPT'))
                  TextButton(
                    key: const ValueKey('accept-message-request'),
                    onPressed: () async {
                      await widget.controller.acceptConversation(
                        widget.conversation.id,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Accept'),
                  ),
              ],
            ),
          if (_callMessage != null ||
              (widget.conversation.status == 'ACCEPTED' &&
                  widget.rtcProviderFactory == null))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Semantics(
                liveRegion: _callMessage != null,
                child: Text(
                  _callMessage ??
                      'Secure calling is unavailable until the WebRTC provider is configured.',
                  key: const ValueKey('social-call-availability'),
                ),
              ),
            ),
          Expanded(
            child: _messages == null
                ? Center(
                    child: _failure == null
                        ? const CircularProgressIndicator()
                        : const Text('Messages could not be loaded.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages!.length,
                    itemBuilder: (context, index) {
                      final item = _messages![index];
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.voiceMediaId.isNotEmpty)
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.mic, size: 18),
                                      Text(' Voice note'),
                                    ],
                                  ),
                                if (item.body.isNotEmpty) Text(item.body),
                                Text(
                                  item.status,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('phase5-message-body'),
                    controller: _body,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      counterText: '',
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('phase5-voice-note'),
                  tooltip: _voiceRecording
                      ? 'Stop and send voice note'
                      : 'Record voice note',
                  onPressed: widget.conversation.status == 'ACCEPTED'
                      ? _toggleVoice
                      : null,
                  icon: _voiceBusy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _voiceRecording
                              ? Icons.stop_circle_outlined
                              : Icons.mic_outlined,
                        ),
                ),
                IconButton(
                  key: const ValueKey('phase5-send-message'),
                  tooltip: 'Send message',
                  onPressed: widget.conversation.status == 'ACCEPTED'
                      ? _send
                      : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
          if (_voiceRecording || _voiceMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _voiceRecording
                            ? 'Recording ${_voiceSeconds}s of ${CommunityMediaCoordinator.maxVoiceDuration.inSeconds}s'
                            : _voiceMessage!,
                      ),
                    ),
                    if (_voiceRecording)
                      TextButton(
                        key: const ValueKey('phase5-cancel-voice-note'),
                        onPressed: _voiceBusy ? null : _cancelVoice,
                        child: const Text('Discard'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

final class SocialCallScreen extends StatefulWidget {
  const SocialCallScreen({
    required this.controller,
    required this.initialCall,
    this.rtcProvider,
    super.key,
  });
  final Phase5Controller controller;
  final SocialCall initialCall;
  final SocialRtcOfferProvider? rtcProvider;
  @override
  State<SocialCallScreen> createState() => _SocialCallScreenState();
}

class _SocialCallScreenState extends State<SocialCallScreen> {
  late SocialCall _call = widget.initialCall;
  bool _busy = false;
  bool _ending = false;
  bool _providerClosed = false;
  bool _offerSent = false;
  bool _allowPop = false;
  String? _providerFailure;
  Completer<void>? _connectCompletion;

  @override
  void dispose() {
    unawaited(_closeProvider());
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy || _ending || _providerClosed || _offerSent) return;
    final completion = Completer<void>();
    _connectCompletion = completion;
    setState(() => _busy = true);
    try {
      final provider = widget.rtcProvider;
      if (provider == null) {
        throw StateError('Secure calling is unavailable on this build.');
      }
      final payload = await provider.createOffer(_call);
      if (_ending) return;
      if (payload.length < 16 ||
          payload.length > 16 * 1024 ||
          payload.contains('\r') ||
          payload.contains('\n')) {
        throw const FormatException('WebRTC offer is invalid.');
      }
      final next = await widget.controller.signalCall(
        _call.id,
        'OFFER',
        payload: payload,
      );
      if (next == null) {
        throw StateError('The offer was not accepted.');
      }
      if (!mounted) return;
      _call = next;
      _offerSent = true;
      _providerFailure = null;
    } catch (_) {
      await _closeProvider();
      if (!mounted) return;
      _providerFailure = 'Secure calling could not connect. Try again later.';
    } finally {
      if (mounted) setState(() => _busy = false);
      if (!completion.isCompleted) completion.complete();
      if (identical(_connectCompletion, completion)) {
        _connectCompletion = null;
      }
    }
  }

  Future<void> _endCall() async {
    if (_ending || _call.status == 'ENDED') return;
    setState(() => _ending = true);
    // Stop camera and microphone first. Network failure must never keep local
    // capture alive while an END audit signal is retried or rejected.
    await _closeProvider();
    await _connectCompletion?.future;
    final next = await widget.controller.signalCall(_call.id, 'END');
    if (!mounted) return;
    _call = next?.status == 'ENDED' ? next! : _ended(_call);
    setState(() {
      _ending = false;
      _allowPop = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _closeProvider() async {
    if (_providerClosed) return;
    _providerClosed = true;
    try {
      await widget.rtcProvider?.close();
    } catch (_) {
      // Capture has been invalidated locally; END signalling must still run.
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || _call.status == 'ENDED',
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_endCall());
    },
    child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 54,
                  child: Icon(
                    _call.kind == 'VIDEO' ? Icons.videocam : Icons.call,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '${_call.kind.toLowerCase()} call',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                ),
                Text(
                  _call.status,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                if (widget.rtcProvider == null || _providerFailure != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _providerFailure ??
                          'Secure calling is unavailable until the environment-owned WebRTC provider is configured.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                if (_offerSent && _providerFailure == null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Secure offer sent. Waiting for the other participant.',
                      key: const ValueKey('social-call-offer-sent'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                if (_call.status == 'RINGING' && !_offerSent)
                  FilledButton.tonalIcon(
                    key: const ValueKey('start-call-signalling'),
                    onPressed:
                        _busy ||
                            _ending ||
                            _providerClosed ||
                            widget.rtcProvider == null
                        ? null
                        : _connect,
                    icon: const Icon(Icons.wifi_calling_3),
                    label: const Text('Connect securely'),
                  ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  key: const ValueKey('end-social-call'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  onPressed: _ending ? null : _endCall,
                  child: _ending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.call_end),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

SocialCall _ended(SocialCall value) => SocialCall(
  id: value.id,
  conversationId: value.conversationId,
  kind: value.kind,
  status: 'ENDED',
  signalCount: value.signalCount,
  expiresAt: value.expiresAt,
);

final class _HomesTab extends StatefulWidget {
  const _HomesTab({required this.controller, required this.state});
  final Phase5Controller controller;
  final Phase5State state;
  @override
  State<_HomesTab> createState() => _HomesTabState();
}

class _HomesTabState extends State<_HomesTab> {
  final _search = TextEditingController();
  String _purpose = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.state.homes
        .where(
          (item) =>
              (_search.text.isEmpty ||
                  '${item.title} ${item.locality}'.toLowerCase().contains(
                    _search.text.toLowerCase(),
                  )) &&
              (_purpose.isEmpty || item.purpose == _purpose),
        )
        .toList();
    return ListView(
      key: const ValueKey('phase5-homes-tab'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Find your next home',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('post-home'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      HomeListingForm(controller: widget.controller),
                ),
              ),
              icon: const Icon(Icons.add_home_work_outlined),
              label: const Text('List'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search locality or property',
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '', label: Text('All')),
            ButtonSegment(value: 'SALE', label: Text('Buy')),
            ButtonSegment(value: 'RENT', label: Text('Rent')),
          ],
          selected: {_purpose},
          onSelectionChanged: (value) => setState(() => _purpose = value.first),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No homes matched'),
              subtitle: Text('Try another locality or filter.'),
            ),
          )
        else
          for (final item in filtered)
            _HomeCard(item: item, controller: widget.controller),
      ],
    );
  }
}

final class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.item, required this.controller});
  final HomeListing item;
  final Phase5Controller controller;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => _details(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (item.kycVerified)
                  const Icon(
                    Icons.verified_user,
                    semanticLabel: 'KYC verified',
                    color: Colors.teal,
                  ),
              ],
            ),
            Text(
              '${item.bedrooms} bed • ${item.areaSqFt} sq ft • ${item.propertyType}',
            ),
            Text(item.locality),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.price.display(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(item.plan)),
              ],
            ),
            Text(
              'Indicative value ${item.estimate.amount.display()} • ${item.estimate.version}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> _details(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(item.locality),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Map location'),
              subtitle: Text(
                '${item.latitude.toStringAsFixed(3)}, ${item.longitude.toStringAsFixed(3)} • approximate until inquiry',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: Text('Estimated ${item.estimate.amount.display()}'),
              subtitle: Text(
                '${item.estimate.pricePerArea.display()} / sq ft • ${item.estimate.version}',
              ),
            ),
            Wrap(
              spacing: 8,
              children: item.amenities
                  .map((item) => Chip(label: Text(item)))
                  .toList(),
            ),
            const SizedBox(height: 12),
            if (item.allowedActions.contains('INQUIRE'))
              FilledButton.icon(
                key: const ValueKey('home-inquiry'),
                onPressed: () async {
                  await controller.inquireHome(
                    item.id,
                    'I am interested. Please share verified ownership and visit details.',
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Contact owner'),
              ),
            if (item.allowedActions.contains('SCHEDULE_VISIT'))
              OutlinedButton.icon(
                onPressed: () async {
                  await controller.scheduleVisit(
                    item.id,
                    DateTime.now().add(const Duration(days: 1)),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Request a visit'),
              ),
            if (item.allowedActions.contains('PUBLISH'))
              FilledButton.icon(
                key: ValueKey('publish-home-${item.id}'),
                onPressed: () async {
                  await controller.publishHome(item);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publish listing'),
              ),
            if (item.allowedActions.contains('UPGRADE'))
              OutlinedButton.icon(
                key: ValueKey('upgrade-home-${item.id}'),
                onPressed: () async {
                  await controller.upgradeHome(item.id, 'FEATURED');
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Feature for 7 days'),
              ),
          ],
        ),
      ),
    ),
  );
}

final class HomeListingForm extends StatefulWidget {
  const HomeListingForm({required this.controller, super.key});
  final Phase5Controller controller;
  @override
  State<HomeListingForm> createState() => _HomeListingFormState();
}

class _HomeListingFormState extends State<HomeListingForm> {
  final _title = TextEditingController(),
      _locality = TextEditingController(),
      _price = TextEditingController();
  String _type = 'APARTMENT', _purpose = 'SALE';
  @override
  void dispose() {
    _title.dispose();
    _locality.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = double.tryParse(_price.text);
    if (_title.text.trim().length < 4 ||
        _locality.text.trim().length < 2 ||
        price == null) {
      return;
    }
    await widget.controller.createHome({
      'title': _title.text.trim(),
      'property_type': _type,
      'purpose': _purpose,
      'locality': _locality.text.trim(),
      'latitude': 13.03,
      'longitude': 80.27,
      'area_sq_ft': 1000,
      'bedrooms': 2,
      'price': {'amount_minor': (price * 100).round(), 'currency': 'INR'},
      'amenities': ['parking'],
      'media_asset_ids': <String>[],
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('List a home')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('Owner KYC required'),
              subtitle: Text(
                'The server verifies owner KYC before this draft can be published.',
              ),
            ),
          ),
          TextField(
            key: const ValueKey('home-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Listing title'),
          ),
          TextField(
            controller: _locality,
            decoration: const InputDecoration(labelText: 'Locality'),
          ),
          DropdownButtonFormField(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Property type'),
            items: const ['APARTMENT', 'HOUSE', 'VILLA', 'LAND', 'COMMERCIAL']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _type = value!),
          ),
          DropdownButtonFormField(
            initialValue: _purpose,
            decoration: const InputDecoration(labelText: 'Purpose'),
            items: const ['SALE', 'RENT']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _purpose = value!),
          ),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Price (INR)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('submit-home'),
            onPressed: _submit,
            child: const Text('Save KYC-gated draft'),
          ),
        ],
      ),
    ),
  );
}

final class _ClassifiedsTab extends StatefulWidget {
  const _ClassifiedsTab({
    required this.controller,
    required this.state,
    this.mediaCoordinator,
  });
  final Phase5Controller controller;
  final Phase5State state;
  final CommunityMediaCoordinator? mediaCoordinator;
  @override
  State<_ClassifiedsTab> createState() => _ClassifiedsTabState();
}

class _ClassifiedsTabState extends State<_ClassifiedsTab> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.state.classifieds
        .where(
          (item) =>
              _search.text.isEmpty ||
              '${item.title} ${item.category} ${item.locality}'
                  .toLowerCase()
                  .contains(_search.text.toLowerCase()),
        )
        .toList();
    return ListView(
      key: const ValueKey('phase5-classifieds-tab'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Local classifieds',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('post-classified'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ClassifiedPostingWizard(
                    controller: widget.controller,
                    mediaCoordinator: widget.mediaCoordinator,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Post ad'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search category, item or locality',
          ),
        ),
        const SizedBox(height: 12),
        for (final item in values)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(label: Text(item.status)),
                    ],
                  ),
                  Text('${item.category} • ${item.locality}'),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.price.display(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(item.contactMasked),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (item.allowedActions.contains('CONTACT'))
                        TextButton.icon(
                          key: ValueKey('classified-contact-${item.id}'),
                          onPressed: () => _contact(context, item),
                          icon: Icon(
                            item.whatsAppEnabled
                                ? Icons.chat
                                : Icons.phone_outlined,
                          ),
                          label: const Text('Contact'),
                        ),
                      if (item.allowedActions.contains('REPORT'))
                        TextButton.icon(
                          onPressed: () =>
                              widget.controller.reportClassified(item.id),
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Report'),
                        ),
                      if (item.allowedActions.contains('REPOST'))
                        TextButton.icon(
                          key: ValueKey('repost-classified-${item.id}'),
                          onPressed: () =>
                              widget.controller.repostClassified(item.id),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Repost'),
                        ),
                      if (item.allowedActions.contains('UPGRADE'))
                        TextButton.icon(
                          key: ValueKey('upgrade-classified-${item.id}'),
                          onPressed: () => widget.controller.upgradeClassified(
                            item.id,
                            'FEATURED',
                          ),
                          icon: const Icon(Icons.workspace_premium_outlined),
                          label: const Text('Feature'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _contact(BuildContext context, ClassifiedListing item) async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reveal seller contact?'),
        content: Text(
          'The seller will receive a ${item.whatsAppEnabled ? 'WhatsApp' : 'phone'} handoff. Your explicit consent is required and will be recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('consent-contact'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I consent'),
          ),
        ],
      ),
    );
    if (consent != true) return;
    final value = await widget.controller.revealContact(
      item.id,
      item.whatsAppEnabled ? 'WHATSAPP' : 'PHONE',
    );
    if (context.mounted && value?.contactRevealed.isNotEmpty == true) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Seller contact'),
          content: SelectableText(value!.contactRevealed),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }
}

final class ClassifiedPostingWizard extends StatefulWidget {
  const ClassifiedPostingWizard({
    required this.controller,
    this.mediaCoordinator,
    super.key,
  });
  final Phase5Controller controller;
  final CommunityMediaCoordinator? mediaCoordinator;
  @override
  State<ClassifiedPostingWizard> createState() =>
      _ClassifiedPostingWizardState();
}

class _ClassifiedPostingWizardState extends State<ClassifiedPostingWizard> {
  int _step = 0;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _contact = TextEditingController();
  final _mediaAssetIds = <String>[];
  String _category = 'ELECTRONICS';
  bool _whatsApp = false;
  bool _mediaBusy = false;
  String? _mediaMessage;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_price.text);
    if (_title.text.trim().length < 4 ||
        _description.text.trim().length < 8 ||
        amount == null ||
        _contact.text.trim().length < 8) {
      return;
    }
    await widget.controller.createClassified({
      'category': _category,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'price': {'amount_minor': (amount * 100).round(), 'currency': 'INR'},
      'locality': 'Chennai',
      'media_asset_ids': List<String>.unmodifiable(_mediaAssetIds),
      'contact': _contact.text.trim(),
      'whatsapp_enabled': _whatsApp,
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _capturePhoto() async {
    final coordinator = widget.mediaCoordinator;
    if (_mediaBusy || _mediaAssetIds.length >= 5) return;
    if (coordinator == null) {
      setState(
        () => _mediaMessage =
            'Classified photos require the configured private media provider.',
      );
      return;
    }
    setState(() {
      _mediaBusy = true;
      _mediaMessage = null;
    });
    try {
      final assetId = await coordinator.captureAndUpload(
        CommunityMediaKind.classifiedImage,
      );
      if (!mounted) return;
      setState(() {
        if (assetId == null) {
          _mediaMessage = 'Photo capture cancelled.';
        } else if (!_mediaAssetIds.contains(assetId)) {
          _mediaAssetIds.add(assetId);
          _mediaMessage = 'Private photo uploaded.';
        }
      });
    } on CommunityCaptureException catch (error) {
      if (mounted) setState(() => _mediaMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _mediaMessage = 'The private media provider is unavailable.',
        );
      }
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Post a classified')),
    body: SafeArea(
      child: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (_step < 3) {
            setState(() => _step++);
          } else {
            unawaited(_submit());
          }
        },
        onStepCancel: _step == 0 ? null : () => setState(() => _step--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              FilledButton(
                key: ValueKey(
                  details.stepIndex == 3
                      ? 'submit-classified'
                      : 'classified-next-${details.stepIndex}',
                ),
                onPressed: details.onStepContinue,
                child: Text(_step == 3 ? 'Submit for review' : 'Continue'),
              ),
              const SizedBox(width: 8),
              if (details.onStepCancel != null)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('Category'),
            content: DropdownButtonFormField(
              initialValue: _category,
              items:
                  const [
                        'ELECTRONICS',
                        'FURNITURE',
                        'VEHICLES',
                        'SERVICES',
                        'OTHER',
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
          ),
          Step(
            title: const Text('Details'),
            content: Column(
              children: [
                TextField(
                  key: const ValueKey('classified-title'),
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  key: const ValueKey('classified-description'),
                  controller: _description,
                  maxLength: 5000,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Price & photos'),
            content: Column(
              children: [
                TextField(
                  key: const ValueKey('classified-price'),
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (INR)'),
                ),
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate_outlined),
                  title: Text(
                    '${_mediaAssetIds.length} of 5 safety-scanned photos',
                  ),
                  subtitle: const Text(
                    'Media enters quarantine before publication.',
                  ),
                  trailing: IconButton(
                    key: const ValueKey('capture-classified-photo'),
                    tooltip: 'Capture classified photo',
                    onPressed: _mediaBusy || _mediaAssetIds.length >= 5
                        ? null
                        : _capturePhoto,
                    icon: _mediaBusy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_a_photo_outlined),
                  ),
                ),
                for (var index = 0; index < _mediaAssetIds.length; index++)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.lock_outline),
                    title: Text('Private photo ${index + 1}'),
                    trailing: IconButton(
                      key: ValueKey('remove-classified-photo-$index'),
                      tooltip: 'Remove photo ${index + 1}',
                      onPressed: _mediaBusy
                          ? null
                          : () =>
                                setState(() => _mediaAssetIds.removeAt(index)),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                if (_mediaMessage != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _mediaMessage!,
                      key: const ValueKey('classified-media-message'),
                    ),
                  ),
              ],
            ),
          ),
          Step(
            title: const Text('Safe contact'),
            content: Column(
              children: [
                TextField(
                  key: const ValueKey('classified-contact'),
                  controller: _contact,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    helperText: 'Masked until a buyer explicitly consents.',
                  ),
                ),
                SwitchListTile(
                  value: _whatsApp,
                  onChanged: (value) => setState(() => _whatsApp = value),
                  title: const Text('Allow WhatsApp handoff'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

final class _EmergencyTab extends StatefulWidget {
  const _EmergencyTab({required this.controller, required this.state});
  final Phase5Controller controller;
  final Phase5State state;
  @override
  State<_EmergencyTab> createState() => _EmergencyTabState();
}

class _EmergencyTabState extends State<_EmergencyTab> {
  bool _consent = false;
  final _description = TextEditingController();
  String _category = 'MEDICAL';
  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (!_consent || _description.text.trim().length < 5) return;
    await widget.controller.createEmergency(
      category: _category,
      description: _description.text.trim(),
      latitude: 13.03,
      longitude: 80.27,
      accuracyM: 15,
    );
    _description.clear();
    if (mounted) setState(() => _consent = false);
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('phase5-emergency-tab'),
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emergency),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency assistance',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'If life is in immediate danger, contact your local emergency number first. Planext4u connects verified local responders but is not a replacement for public emergency services.',
              ),
            ],
          ),
        ),
      ),
      DropdownButtonFormField(
        initialValue: _category,
        decoration: const InputDecoration(labelText: 'Assistance type'),
        items: const ['MEDICAL', 'SAFETY', 'FIRE', 'ACCIDENT', 'OTHER']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => _category = value!),
      ),
      TextField(
        key: const ValueKey('emergency-description'),
        controller: _description,
        maxLength: 2000,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'What happened?'),
      ),
      CheckboxListTile(
        key: const ValueKey('emergency-location-consent'),
        value: _consent,
        onChanged: (value) => setState(() => _consent = value ?? false),
        title: const Text('Share my live location'),
        subtitle: const Text(
          'Required to dispatch a responder. You can revoke it at any time.',
        ),
      ),
      FilledButton.icon(
        key: const ValueKey('request-emergency'),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: _consent && !widget.state.busy ? _request : null,
        icon: const Icon(Icons.sos),
        label: const Text('Request urgent assistance'),
      ),
      const SizedBox(height: 20),
      Text('My active requests', style: Theme.of(context).textTheme.titleLarge),
      if (widget.state.emergencies.isEmpty)
        const Card(
          child: ListTile(
            title: Text('No active requests'),
            subtitle: Text('Your emergency timeline will appear here.'),
          ),
        )
      else
        for (final item in widget.state.emergencies)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.category,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(label: Text(item.status)),
                    ],
                  ),
                  Text(item.description),
                  Text(
                    item.assignedResponder.isEmpty
                        ? 'Finding a verified responder'
                        : 'Responder ${item.assignedResponder}',
                  ),
                  Text(
                    item.escalationLevel > 0
                        ? 'Escalated level ${item.escalationLevel}'
                        : 'SLA target ${TimeOfDay.fromDateTime(item.slaDeadline.toLocal()).format(context)}',
                  ),
                  if (item.location == null)
                    const Text(
                      'Precise location hidden or stale',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    )
                  else
                    Text(
                      'Live location accuracy ±${item.location!.accuracyM.round()} m',
                    ),
                  if (item.locationConsent)
                    TextButton.icon(
                      key: ValueKey('revoke-location-${item.id}'),
                      onPressed: () =>
                          widget.controller.revokeEmergencyLocation(item.id),
                      icon: const Icon(Icons.location_off_outlined),
                      label: const Text('Stop location sharing'),
                    ),
                  OutlinedButton.icon(
                    key: ValueKey('open-emergency-${item.id}'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EmergencyAssistanceScreen(
                          controller: widget.controller,
                          request: item,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.support_agent_outlined),
                    label: const Text('Responder updates & chat'),
                  ),
                ],
              ),
            ),
          ),
    ],
  );
}

final class EmergencyAssistanceScreen extends StatefulWidget {
  const EmergencyAssistanceScreen({
    required this.controller,
    required this.request,
    super.key,
  });
  final Phase5Controller controller;
  final EmergencyAssistance request;
  @override
  State<EmergencyAssistanceScreen> createState() =>
      _EmergencyAssistanceScreenState();
}

class _EmergencyAssistanceScreenState extends State<EmergencyAssistanceScreen> {
  final _body = TextEditingController();
  List<EmergencyMessage>? _messages;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _messages = await widget.controller.emergencyMessages(widget.request.id);
      _failure = null;
    } catch (error) {
      _failure = error;
    }
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final value = _body.text.trim();
    if (value.isEmpty) return;
    await widget.controller.sendEmergencyMessage(widget.request.id, value);
    _body.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency response')),
      body: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.sos)),
              title: Text('${request.category} · ${request.status}'),
              subtitle: Text(
                request.assignedResponder.isEmpty
                    ? 'Dispatch is finding a verified responder.'
                    : 'Verified responder ${request.assignedResponder}',
              ),
              trailing: Badge(label: Text('L${request.escalationLevel}')),
            ),
            if (request.location != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${request.location!.latitude.toStringAsFixed(4)}, '
                        '${request.location!.longitude.toStringAsFixed(4)} · '
                        'accuracy ±${request.location!.accuracyM.round()} m',
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Expanded(
              child: _messages == null
                  ? Center(
                      child: _failure == null
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Responder updates could not be loaded.',
                            ),
                    )
                  : _messages!.isEmpty
                  ? const Center(
                      child: Text(
                        'No responder messages yet. Keep this screen open.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages!.length,
                      itemBuilder: (context, index) {
                        final message = _messages![index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.verified_user_outlined),
                            title: Text(message.body),
                            subtitle: Text(
                              '${message.senderId} · ${message.status}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (request.status != 'RESOLVED')
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('emergency-message-body'),
                        controller: _body,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Update responder',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('send-emergency-message'),
                      tooltip: 'Send emergency update',
                      onPressed: _send,
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

Future<String?> _textDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value?.isEmpty == true ? null : value;
}

String _remaining(DateTime expiry) {
  final duration = expiry.difference(DateTime.now().toUtc());
  if (duration.isNegative) return 'Expired';
  if (duration.inHours > 0) return '${duration.inHours}h left';
  return '${duration.inMinutes}m left';
}

Future<void> _captureFeedback(BuildContext context, String message) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Community media'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );

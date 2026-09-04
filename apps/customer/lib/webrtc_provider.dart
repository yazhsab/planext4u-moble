import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

/// Environment-owned ICE configuration. Credentials must be supplied at
/// runtime from protected configuration and are never written to diagnostics.
final class WebRtcIceServer {
  WebRtcIceServer({
    required List<Uri> urls,
    this.username = '',
    this.credential = '',
  }) : urls = List<Uri>.unmodifiable(urls) {
    if (urls.isEmpty ||
        urls.any(
          (url) =>
              !const {'stun', 'turn', 'turns'}.contains(url.scheme) ||
              url.toString().contains('@'),
        )) {
      throw const FormatException('ICE server URLs are invalid.');
    }
    final usesTurn = urls.any(
      (url) => const {'turn', 'turns'}.contains(url.scheme),
    );
    if (usesTurn && (username.trim().isEmpty || credential.trim().isEmpty)) {
      throw const FormatException(
        'TURN credentials must come from protected configuration.',
      );
    }
  }

  final List<Uri> urls;
  final String username;
  final String credential;

  Map<String, Object> toConfiguration() => {
    'urls': urls.map((url) => url.toString()).toList(growable: false),
    if (username.isNotEmpty) 'username': username,
    if (credential.isNotEmpty) 'credential': credential,
  };
}

SocialRtcOfferProviderFactory createFlutterSocialRtcProviderFactory({
  required List<WebRtcIceServer> iceServers,
  Duration iceGatheringTimeout = const Duration(seconds: 10),
}) {
  final immutableServers = List<WebRtcIceServer>.unmodifiable(iceServers);
  if (immutableServers.isEmpty) {
    throw const FormatException(
      'Secure calling requires environment-owned ICE configuration.',
    );
  }
  return () => FlutterSocialRtcOfferProvider(
    iceServers: immutableServers,
    iceGatheringTimeout: iceGatheringTimeout,
  );
}

/// Native WebRTC offer engine. Signaling transport remains outside this class:
/// the experience controller sends its opaque, one-line offer through the
/// authorized social-call contract.
final class FlutterSocialRtcOfferProvider implements SocialRtcOfferProvider {
  FlutterSocialRtcOfferProvider({
    required List<WebRtcIceServer> iceServers,
    this.iceGatheringTimeout = const Duration(seconds: 10),
  }) : _iceServers = List<WebRtcIceServer>.unmodifiable(iceServers);

  final List<WebRtcIceServer> _iceServers;
  final Duration iceGatheringTimeout;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _preparing = false;

  @override
  Future<String> createOffer(SocialCall call) async {
    if (_preparing || _peerConnection != null || _localStream != null) {
      throw StateError('A WebRTC session is already active.');
    }
    if (_iceServers.isEmpty || !const {'AUDIO', 'VIDEO'}.contains(call.kind)) {
      throw StateError('Secure call configuration is invalid.');
    }
    _preparing = true;
    try {
      final peer = await createPeerConnection({
        'iceServers': _iceServers
            .map((server) => server.toConfiguration())
            .toList(growable: false),
        'sdpSemantics': 'unified-plan',
      });
      _peerConnection = peer;

      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': call.kind == 'VIDEO'
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 24, 'max': 30},
              }
            : false,
      });
      _localStream = stream;
      for (final track in stream.getTracks()) {
        await peer.addTrack(track, stream);
      }

      final iceGathered = Completer<void>();
      peer.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !iceGathered.isCompleted) {
          iceGathered.complete();
        }
      };
      final offer = await peer.createOffer({
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': call.kind == 'VIDEO',
        },
        'optional': <Object>[],
      });
      await peer.setLocalDescription(offer);
      if (peer.iceGatheringState !=
          RTCIceGatheringState.RTCIceGatheringStateComplete) {
        await iceGathered.future.timeout(iceGatheringTimeout);
      }
      final description = await peer.getLocalDescription();
      final sdp = description?.sdp;
      final type = description?.type;
      if (sdp == null || sdp.isEmpty || type == null || type != 'offer') {
        throw const FormatException('WebRTC did not produce a valid offer.');
      }
      final payload = jsonEncode({'type': type, 'sdp': sdp});
      if (payload.length > 16 * 1024 ||
          payload.contains('\r') ||
          payload.contains('\n')) {
        throw const FormatException(
          'The WebRTC offer exceeds the signaling contract.',
        );
      }
      return payload;
    } catch (_) {
      await close();
      rethrow;
    } finally {
      _preparing = false;
    }
  }

  @override
  Future<void> close() async {
    final stream = _localStream;
    final peer = _peerConnection;
    _localStream = null;
    _peerConnection = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {
          // Continue stopping every local capture track.
        }
      }
      try {
        await stream.dispose();
      } catch (_) {
        // The peer connection is still closed below.
      }
    }
    if (peer != null) {
      try {
        await peer.close();
      } catch (_) {
        // Dispose still releases native resources if close reports an error.
      }
      try {
        await peer.dispose();
      } catch (_) {
        // All local references and tracks have already been invalidated.
      }
    }
  }
}

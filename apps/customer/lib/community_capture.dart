import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:record/record.dart';

/// Builds the device-side community capture stack around a production-owned
/// private uploader. The uploader remains an explicit dependency so captured
/// bytes can never fall back to a public or unmoderated endpoint.
CommunityMediaCoordinator createDeviceCommunityMediaCoordinator({
  required CommunityMediaUploader uploader,
  ImagePicker? imagePicker,
  AudioRecorder? audioRecorder,
}) => CommunityMediaCoordinator(
  visualSource: ImagePickerCommunityVisualSource(picker: imagePicker),
  voiceSource: RecordCommunityVoiceSource(recorder: audioRecorder),
  uploader: uploader,
);

/// Captures story/classified images and short reel video using the platform
/// camera. The selected file is read into memory and is never retained here.
final class ImagePickerCommunityVisualSource
    implements CommunityVisualCaptureSource {
  ImagePickerCommunityVisualSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<CommunityBinaryMedia?> capture(CommunityMediaKind kind) async {
    if (kind == CommunityMediaKind.voiceNote) {
      throw const CommunityCaptureException(
        CommunityCaptureIssue.invalidEvidence,
        'Voice notes must use the microphone recorder.',
      );
    }
    try {
      XFile? file = await _recoverInterruptedCapture(kind);
      file ??= switch (kind) {
        CommunityMediaKind.storyImage ||
        CommunityMediaKind.classifiedImage => await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
          requestFullMetadata: false,
        ),
        CommunityMediaKind.reelVideo => await _picker.pickVideo(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          maxDuration: CommunityMediaCoordinator.maxReelDuration,
        ),
        CommunityMediaKind.voiceNote => null,
      };
      if (file == null) return null;
      return CommunityBinaryMedia(
        bytes: await file.readAsBytes(),
        contentType: _contentType(file, kind),
      );
    } on CommunityCaptureException {
      rethrow;
    } on PlatformException catch (error) {
      throw _platformFailure(error);
    } catch (_) {
      throw const CommunityCaptureException(
        CommunityCaptureIssue.unavailable,
        'The device camera is unavailable.',
      );
    }
  }

  Future<XFile?> _recoverInterruptedCapture(CommunityMediaKind kind) async {
    if (!Platform.isAndroid) return null;
    final result = await _picker.retrieveLostData();
    if (result.exception != null) throw result.exception!;
    if (result.isEmpty) return null;
    final expected = kind == CommunityMediaKind.reelVideo
        ? RetrieveType.video
        : RetrieveType.image;
    return result.type == expected ? result.file : null;
  }

  static String _contentType(XFile file, CommunityMediaKind kind) {
    final provided = file.mimeType?.split(';').first.trim().toLowerCase();
    if (provided != null && provided.isNotEmpty) return provided;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.mov')) return 'video/quicktime';
    if (name.endsWith('.mp4')) return 'video/mp4';
    return kind == CommunityMediaKind.reelVideo ? 'video/mp4' : 'image/jpeg';
  }
}

/// Records a mono AAC voice note into the app's temporary directory. The
/// temporary file is deleted after it is read, cancelled, or disposed.
final class RecordCommunityVoiceSource implements CommunityVoiceCaptureSource {
  RecordCommunityVoiceSource({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _activePath;
  Stopwatch? _elapsed;
  bool _disposed = false;

  @override
  Future<void> start() async {
    if (_disposed) {
      throw const CommunityCaptureException(
        CommunityCaptureIssue.unavailable,
        'The microphone recorder is no longer available.',
      );
    }
    if (_activePath != null) {
      throw const CommunityCaptureException(
        CommunityCaptureIssue.recordingConflict,
        'A voice recording is already active.',
      );
    }
    if (!await _recorder.hasPermission()) {
      throw const CommunityCaptureException(
        CommunityCaptureIssue.permissionDenied,
        'Microphone permission is required to record a voice note.',
      );
    }
    final path = _temporaryPath();
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 24000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      _activePath = path;
      _elapsed = Stopwatch()..start();
    } on PlatformException catch (error) {
      await _deleteIfPresent(path);
      throw _platformFailure(error, microphone: true);
    } catch (_) {
      await _deleteIfPresent(path);
      throw const CommunityCaptureException(
        CommunityCaptureIssue.unavailable,
        'The device microphone is unavailable.',
      );
    }
  }

  @override
  Future<CommunityBinaryMedia?> stop() async {
    final fallbackPath = _activePath;
    final stopwatch = _elapsed;
    if (fallbackPath == null || stopwatch == null) {
      throw const CommunityCaptureException(
        CommunityCaptureIssue.recordingConflict,
        'No voice recording is active.',
      );
    }
    _activePath = null;
    _elapsed = null;
    stopwatch.stop();
    String? outputPath;
    try {
      outputPath = await _recorder.stop();
      if (outputPath == null) return null;
      final file = File(outputPath);
      return CommunityBinaryMedia(
        bytes: await file.readAsBytes(),
        contentType: 'audio/mp4',
        duration: stopwatch.elapsed,
      );
    } on PlatformException catch (error) {
      throw _platformFailure(error, microphone: true);
    } catch (_) {
      throw const CommunityCaptureException(
        CommunityCaptureIssue.unavailable,
        'The voice recording could not be completed.',
      );
    } finally {
      await _deleteIfPresent(outputPath ?? fallbackPath);
    }
  }

  @override
  Future<void> cancel() async {
    final path = _activePath;
    _activePath = null;
    _elapsed?.stop();
    _elapsed = null;
    if (path == null) return;
    try {
      await _recorder.cancel();
    } finally {
      await _deleteIfPresent(path);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await cancel();
    _disposed = true;
    await _recorder.dispose();
  }

  static String _temporaryPath() =>
      '${Directory.systemTemp.path}/planext4u-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';

  static Future<void> _deleteIfPresent(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

CommunityCaptureException _platformFailure(
  PlatformException error, {
  bool microphone = false,
}) {
  final code = error.code.toLowerCase().replaceAll('_', '');
  final permissionDenied =
      code.contains('permission') ||
      code.contains('accessdenied') ||
      code.contains('restricted');
  if (permissionDenied) {
    return CommunityCaptureException(
      CommunityCaptureIssue.permissionDenied,
      microphone
          ? 'Microphone permission is required to record a voice note.'
          : 'Camera permission is required to capture community media.',
    );
  }
  return CommunityCaptureException(
    CommunityCaptureIssue.unavailable,
    microphone
        ? 'The device microphone is unavailable.'
        : 'The device camera is unavailable.',
  );
}

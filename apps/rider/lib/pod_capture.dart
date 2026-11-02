import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

/// Opens the device camera for proof-of-delivery photos.
///
/// The returned bytes stay in memory and are handed directly to the configured
/// private POD uploader. A cancelled capture returns `null` without changing
/// the active task.
final class ImagePickerRiderPodPhotoSource implements RiderPodPhotoSource {
  ImagePickerRiderPodPhotoSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<RiderPodBinaryEvidence?> capture(RiderTask task) async {
    if (Platform.isAndroid) {
      // The old task/account cannot be established after process death.
      // Require fresh capture rather than attach an unowned previous result.
      final lost = await _picker.retrieveLostData();
      await PrivateCameraCache().discardUnattributed(
        (lost.files ?? const <XFile>[]).map((file) => file.path),
      );
    }
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    Uint8List? capturedBytes;
    try {
      if (await file.length() > RiderPodCaptureCoordinator.maxPhotoBytes) {
        throw const FormatException('POD photo is too large.');
      }
      capturedBytes = await sanitizePrivateCameraPhoto(
        await file.readAsBytes(),
        maxBytes: RiderPodCaptureCoordinator.maxPhotoBytes,
      );
      return RiderPodBinaryEvidence(
        bytes: capturedBytes,
        contentType: 'image/png',
      );
    } finally {
      try {
        if (Platform.isAndroid) {
          await PrivateCameraCache().discardUnattributed([file.path]);
        } else {
          final temporary = File(file.path);
          if (await temporary.exists()) await temporary.delete();
        }
      } catch (_) {
        capturedBytes?.fillRange(0, capturedBytes.length, 0);
        rethrow;
      }
    }
  }
}

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

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
    XFile? file;
    if (Platform.isAndroid) {
      final recovered = await _picker.retrieveLostData();
      if (recovered.exception != null) throw recovered.exception!;
      if (!recovered.isEmpty && recovered.type == RetrieveType.image) {
        file = recovered.file;
      }
    }
    file ??= await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return RiderPodBinaryEvidence(
      bytes: bytes,
      contentType: file.mimeType ?? _contentType(file.name),
    );
  }

  static String _contentType(String name) {
    final normalized = name.toLowerCase();
    return normalized.endsWith('.png') ? 'image/png' : 'image/jpeg';
  }
}

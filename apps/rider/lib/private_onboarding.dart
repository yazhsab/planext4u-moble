import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

final class RiderDocumentPhoto {
  const RiderDocumentPhoto(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

/// No OCR result, raw bank details or approval flag is accepted from the device.
final class NativeRiderOnboardingProvider
    implements RiderDocumentOnboardingProvider, RecoverableOnboardingDocuments {
  const NativeRiderOnboardingProvider({
    required this.uploader,
    required this.capture,
    this.progress,
    this.bankLinks,
    this.verifyBank,
  });
  final PrivateMediaUploader uploader;
  final Future<RiderDocumentPhoto?> Function(String kind) capture;
  final PrivateOnboardingProgressStore? progress;
  final HostedBankLinkClient? bankLinks;
  final Future<VerifiedBankAccount?> Function()? verifyBank;
  PrivateOnboardingDocumentCollector get _collector =>
      PrivateOnboardingDocumentCollector(
        uploader: uploader,
        progress: progress,
      );
  @override
  bool get canCollectDocuments => uploader.isActive;
  @override
  bool get canTokenizeBankAccount =>
      uploader.isActive && bankLinks?.isActive == true && verifyBank != null;

  @override
  Future<List<RiderDocumentDraft>> collectDocuments({
    required String vehicleType,
  }) async {
    if (!const {'BICYCLE', 'MOTORBIKE', 'CAR', 'VAN'}.contains(vehicleType)) {
      throw const FormatException('Unsupported vehicle type.');
    }
    final documents = await _collector.collect(
      workflow: 'RIDER_$vehicleType',
      capture: (kind) async {
        final photo = await capture(kind);
        return photo == null
            ? null
            : PrivateOnboardingPhoto(photo.bytes, photo.contentType);
      },
    );
    return List.unmodifiable(
      documents.entries.map(
        (entry) => RiderDocumentDraft(kind: entry.key, assetId: entry.value),
      ),
    );
  }

  @override
  bool get retainsDocumentProgress => progress != null;
  @override
  Future<void> discardSavedDocuments() => _collector.discardSaved();
  @override
  Future<void> prepareDocumentSubmission(Set<String> assetIds) =>
      _collector.prepareSubmission(assetIds);
  @override
  Future<void> forgetSubmittedDocuments(Set<String> assetIds) =>
      _collector.forgetSubmitted(assetIds);

  @override
  Future<void> discardUnsubmittedDocuments(
    List<RiderDocumentDraft> documents,
  ) async {
    // Screen disposal/rebuild must retain the explicitly configured recovery
    // journal. Its dedicated discard action checks every saved reference.
    if (progress != null) return;
    for (final document in documents) {
      try {
        await uploader.discardUnsubmitted(document.assetId);
      } catch (_) {
        /* Inactive scopes and unavailable cleanup need retention processing. */
      }
    }
  }

  @override
  Future<String> tokenizeBankAccount() async {
    if (!canTokenizeBankAccount) {
      throw StateError('Bank-verification provider is unavailable.');
    }
    final bank = await verifyBank!();
    if (!canTokenizeBankAccount || bank == null) {
      throw const TransportCancelledException();
    }
    return bank.reference;
  }

  @override
  Future<RiderOnboardingEvidence> collectEvidence({
    required String vehicleType,
  }) async {
    // Avoid collecting sensitive documents through this legacy combined entry
    // point when it cannot complete. The staged UI exposes documents separately.
    if (!canTokenizeBankAccount) {
      throw StateError('Bank-tokenization provider is not configured.');
    }
    final documents = await collectDocuments(vehicleType: vehicleType);
    try {
      return RiderOnboardingEvidence(
        documents: documents,
        bankReference: await tokenizeBankAccount(),
      );
    } catch (_) {
      await discardUnsubmittedDocuments(documents);
      rethrow;
    }
  }
}

Future<RiderDocumentPhoto?> captureNativeRiderDocument(
  BuildContext context,
  String kind, {
  required bool Function() isActive,
}) async {
  if (!context.mounted || !isActive()) return null;
  final tamil = Localizations.localeOf(context).languageCode == 'ta';
  final title = switch (kind) {
    'IDENTITY' => tamil ? 'அடையாள ஆவணம்' : 'Identity document',
    'DRIVER_LICENSE' => tamil ? 'ஓட்டுநர் உரிமம்' : 'Driver licence',
    'VEHICLE_REGISTRATION' => tamil ? 'வாகனப் பதிவு' : 'Vehicle registration',
    'INSURANCE' => tamil ? 'வாகனக் காப்பீடு' : 'Vehicle insurance',
    _ => throw const FormatException('Unsupported document kind.'),
  };
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        tamil
            ? 'ஆவணத்தைத் தெளிவாகப் படம் எடுக்கவும். சரிபார்ப்பிற்காகப் படம் பாதுகாப்பாகப் பதிவேற்றப்படும்.'
            : 'Take a clear photo of this document. It will be uploaded privately for verification.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tamil ? 'ரத்து' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(tamil ? 'கேமரா' : 'Open camera'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted || !isActive()) return null;
  final picker = ImagePicker();
  // A camera result recovered after process death cannot be attributed to this
  // account. Require a fresh capture instead of uploading recovered bytes.
  if (Platform.isAndroid) {
    final lost = await picker.retrieveLostData();
    await PrivateCameraCache().discardUnattributed(
      (lost.files ?? const <XFile>[]).map((file) => file.path),
    );
  }
  if (!context.mounted || !isActive()) return null;
  final file = await picker.pickImage(
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
    if (!context.mounted || !isActive()) return null;
    if (await file.length() > 15 << 20) {
      throw const FormatException('Document photo is too large.');
    }
    capturedBytes = await sanitizePrivateCameraPhoto(await file.readAsBytes());
    if (!context.mounted || !isActive()) {
      capturedBytes.fillRange(0, capturedBytes.length, 0);
      return null;
    }
    return RiderDocumentPhoto(capturedBytes, 'image/png');
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

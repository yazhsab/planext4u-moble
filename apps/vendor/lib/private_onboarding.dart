import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

final class VendorDocumentPhoto {
  const VendorDocumentPhoto(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

/// Collects private references. OCR, KYC approval and bank verification remain
/// server/provider decisions and are never inferred from a successful upload.
final class NativeVendorOnboardingProvider
    implements
        VendorOnboardingProvider,
        VendorOnboardingCapabilities,
        VendorDocumentCleanup,
        RecoverableOnboardingDocuments {
  const NativeVendorOnboardingProvider({
    required this.uploader,
    required this.capture,
    this.progress,
    this.bankLinks,
    this.verifyBank,
  });
  final PrivateMediaUploader uploader;
  final Future<VendorDocumentPhoto?> Function(String kind) capture;
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
  Future<List<VendorOnboardingDocument>> collectDocuments() async {
    final documents = await _collector.collect(
      workflow: 'VENDOR',
      capture: (kind) async {
        final photo = await capture(kind);
        return photo == null
            ? null
            : PrivateOnboardingPhoto(photo.bytes, photo.contentType);
      },
    );
    return List.unmodifiable(
      documents.entries.map(
        (entry) =>
            VendorOnboardingDocument(kind: entry.key, assetId: entry.value),
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
    List<VendorOnboardingDocument> documents,
  ) async {
    if (progress != null) return;
    for (final document in documents) {
      try {
        await uploader.discardUnsubmitted(document.assetId);
      } catch (_) {
        // The server retention process still owns failed cleanup attempts.
      }
    }
  }

  @override
  Future<VendorOnboardingBankAccount> tokenizeBankAccount() async {
    if (!canTokenizeBankAccount) {
      throw StateError('Bank-verification provider is unavailable.');
    }
    final bank = await verifyBank!();
    if (!canTokenizeBankAccount || bank == null) {
      throw const TransportCancelledException();
    }
    return VendorOnboardingBankAccount(
      reference: bank.reference,
      holderName: bank.holderName,
      last4: bank.last4,
      ifsc: bank.ifsc,
    );
  }
}

Future<VendorDocumentPhoto?> captureNativeVendorDocument(
  BuildContext context,
  String kind, {
  bool Function()? isActive,
}) async {
  if (!context.mounted || isActive?.call() == false) return null;
  final tamil = Localizations.localeOf(context).languageCode == 'ta';
  final title = kind == 'OWNER_IDENTITY'
      ? (tamil ? 'அடையாள ஆவணம்' : 'Identity document')
      : (tamil ? 'வணிகப் பதிவு ஆவணம்' : 'Business registration');
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
  if (accepted != true || !context.mounted || isActive?.call() == false) {
    return null;
  }
  final picker = ImagePicker();
  if (Platform.isAndroid) {
    // Lost camera results cannot be attributed to the current identity after
    // process death. Require a fresh capture; never silently reuse them.
    final lost = await picker.retrieveLostData();
    await PrivateCameraCache().discardUnattributed(
      (lost.files ?? const <XFile>[]).map((file) => file.path),
    );
  }
  if (!context.mounted || isActive?.call() == false) return null;
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
    if (!context.mounted || await file.length() > 15 << 20) {
      throw const FormatException(
        'Document photo is unavailable or too large.',
      );
    }
    capturedBytes = await sanitizePrivateCameraPhoto(await file.readAsBytes());
    if (!context.mounted || isActive?.call() == false) {
      capturedBytes.fillRange(0, capturedBytes.length, 0);
      return null;
    }
    return VendorDocumentPhoto(capturedBytes, 'image/png');
  } finally {
    // ImageSource.camera produces an application cache file. Delete that exact
    // captured file after copying its bytes; no gallery file is selected here.
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

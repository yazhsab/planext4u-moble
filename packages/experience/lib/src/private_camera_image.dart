import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Takes ownership of camera bytes, removes source metadata by encoding only
/// decoded pixels, and always wipes the input buffer. The returned PNG stays in
/// memory until the caller uploads it and clears its buffer. No photo is saved.
Future<Uint8List> sanitizePrivateCameraPhoto(
  Uint8List source, {
  int maxBytes = 15 << 20,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  Uint8List? encoded;
  var returned = false;
  try {
    final jpeg =
        source.length >= 3 &&
        source[0] == 0xff &&
        source[1] == 0xd8 &&
        source[2] == 0xff;
    final png =
        source.length >= 8 &&
        source[0] == 0x89 &&
        source[1] == 0x50 &&
        source[2] == 0x4e &&
        source[3] == 0x47 &&
        source[4] == 13 &&
        source[5] == 10 &&
        source[6] == 26 &&
        source[7] == 10;
    if (maxBytes < 1024 ||
        maxBytes > 15 << 20 ||
        source.isEmpty ||
        source.length > 15 << 20 ||
        (!jpeg && !png)) {
      throw const FormatException('Private camera photo is invalid.');
    }
    buffer = await ui.ImmutableBuffer.fromUint8List(source);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width < 1 ||
        descriptor.height < 1 ||
        descriptor.width * descriptor.height > 16 << 20) {
      throw const FormatException(
        'Private camera photo dimensions are invalid.',
      );
    }
    final dimensionScale = 1920 / math.max(descriptor.width, descriptor.height);
    final byteScale = math.sqrt(
      (maxBytes - 512) / (5 * descriptor.width * descriptor.height),
    );
    final scale = math.min(1.0, math.min(dimensionScale, byteScale));
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).floor()),
      targetHeight: math.max(1, (descriptor.height * scale).floor()),
    );
    if (codec.frameCount != 1) {
      throw const FormatException('Private camera photo must be still.');
    }
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const FormatException('Private camera photo could not be encoded.');
    }
    encoded = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (encoded.length > maxBytes) {
      throw const FormatException('Private camera photo is too large.');
    }
    returned = true;
    return encoded;
  } catch (_) {
    throw const FormatException(
      'Private camera photo could not be prepared safely.',
    );
  } finally {
    source.fillRange(0, source.length, 0);
    if (!returned) encoded?.fillRange(0, encoded.length, 0);
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

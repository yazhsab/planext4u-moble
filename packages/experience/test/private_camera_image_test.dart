import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

Future<Uint8List> _photo(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xffe74a3b), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'JPEG metadata is removed while decoded orientation is preserved',
    () async {
      final source = base64Decode(
        '/9j/4AAQSkZJRgABAQAAAQABAAD/4QBMRXhpZgAATU0AKgAAAAgAAgEOAAIAAAAeAAAAJgESAAMAAAABAAYAAAAAAABQUklWQVRFX0pQRUdfT1dORVJfR1BTX01BUktFUgD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAIABADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwCtRRRXgn6Of//Z',
      );
      final originalCodec = await ui.instantiateImageCodec(source);
      final original = (await originalCodec.getNextFrame()).image;
      final result = await sanitizePrivateCameraPhoto(source);
      final outputCodec = await ui.instantiateImageCodec(result);
      final output = (await outputCodec.getNextFrame()).image;
      expect(
        output.width / output.height,
        closeTo(original.width / original.height, .01),
      );
      expect(
        latin1.decode(result),
        isNot(contains('PRIVATE_JPEG_OWNER_GPS_MARKER')),
      );
      expect(source.every((b) => b == 0), isTrue);
      original.dispose();
      output.dispose();
      originalCodec.dispose();
      outputCodec.dispose();
    },
  );

  test(
    'private photo emits only pixels, discards source trailer metadata and wipes source',
    () async {
      final png = await _photo(8, 4);
      final source = Uint8List.fromList([
        ...png,
        ...utf8.encode('PRIVATE_GPS_EXIF_OWNER_MARKER'),
      ]);
      final result = await sanitizePrivateCameraPhoto(source);
      expect(source.every((byte) => byte == 0), isTrue);
      expect(
        latin1.decode(result),
        isNot(contains('PRIVATE_GPS_EXIF_OWNER_MARKER')),
      );
      expect(result.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(result),
          frame = await codec.getNextFrame();
      expect(frame.image.width, 8);
      expect(frame.image.height, 4);
      frame.image.dispose();
      codec.dispose();
    },
  );
  test(
    'oversized pixel dimensions are reduced with aspect ratio and byte budget',
    () async {
      final source = await _photo(2048, 1024);
      final result = await sanitizePrivateCameraPhoto(
        source,
        maxBytes: 2 << 20,
      );
      final codec = await ui.instantiateImageCodec(result),
          frame = await codec.getNextFrame();
      expect(frame.image.width, lessThanOrEqualTo(1920));
      expect(frame.image.width / frame.image.height, closeTo(2, .01));
      expect(result.length, lessThanOrEqualTo(2 << 20));
      expect(source.every((b) => b == 0), isTrue);
      frame.image.dispose();
      codec.dispose();
    },
  );
  test(
    'invalid photos and invalid budgets fail closed and wipe their source',
    () async {
      final invalid = Uint8List.fromList(utf8.encode('not a private photo'));
      await expectLater(
        sanitizePrivateCameraPhoto(invalid),
        throwsFormatException,
      );
      expect(invalid.every((b) => b == 0), isTrue);
      final valid = await _photo(2, 2);
      await expectLater(
        sanitizePrivateCameraPhoto(valid, maxBytes: 0),
        throwsFormatException,
      );
      expect(valid.every((b) => b == 0), isTrue);
    },
  );
}

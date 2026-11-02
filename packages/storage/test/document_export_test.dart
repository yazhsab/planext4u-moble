import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('net.planext4u.storage/document-export');
  const exporter = PlatformDocumentExporter();
  const name = 'planext4u-account-20261025T120000Z.json';
  final calls = <String>[];
  var current = true;
  String? destination = 'opaque-destination';
  var written = true;
  Uint8List? captured;

  setUp(() {
    calls.clear();
    current = true;
    destination = 'opaque-destination';
    written = true;
    captured = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'choose') return destination;
          if (call.method == 'write') {
            captured = Uint8List.fromList(
              (call.arguments as Map)['bytes'] as Uint8List,
            );
            return written;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('document picker cancellation performs no write', () async {
    destination = null;
    expect(
      await exporter.save(
        fileName: name,
        bytes: Uint8List.fromList([123, 125]),
        isCurrent: () => current,
      ),
      DocumentExportResult.cancelled,
    );
    expect(calls, ['choose']);
  });

  test(
    'account switch during picker discards selection without data',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'choose') {
              current = false;
              return destination;
            }
            return null;
          });
      expect(
        await exporter.save(
          fileName: name,
          bytes: Uint8List.fromList([123, 125]),
          isCurrent: () => current,
        ),
        DocumentExportResult.cancelled,
      );
      expect(calls, ['choose', 'discard']);
    },
  );

  test(
    'confirmed write is required and unfinished handles are discarded',
    () async {
      expect(
        await exporter.save(
          fileName: name,
          bytes: Uint8List.fromList([123, 125]),
          isCurrent: () => current,
        ),
        DocumentExportResult.saved,
      );
      expect(captured, [123, 125]);
      expect(calls, ['choose', 'write', 'discard']);
      calls.clear();
      written = false;
      await expectLater(
        exporter.save(
          fileName: name,
          bytes: Uint8List.fromList([123, 125]),
          isCurrent: () => current,
        ),
        throwsStateError,
      );
      expect(calls, ['choose', 'write', 'discard']);
    },
  );

  test(
    'invalid names, oversized data and retired account never open picker',
    () async {
      await expectLater(
        exporter.save(
          fileName: '../account.json',
          bytes: Uint8List(1),
          isCurrent: () => current,
        ),
        throwsArgumentError,
      );
      await expectLater(
        exporter.save(
          fileName: name,
          bytes: Uint8List(PlatformDocumentExporter.maxBytes + 1),
          isCurrent: () => current,
        ),
        throwsArgumentError,
      );
      current = false;
      expect(
        await exporter.save(
          fileName: name,
          bytes: Uint8List(1),
          isCurrent: () => current,
        ),
        DocumentExportResult.cancelled,
      );
      expect(calls, isEmpty);
    },
  );
}

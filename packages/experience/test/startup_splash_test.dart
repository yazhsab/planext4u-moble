import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_storage/planext4u_storage.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

PublicStartupDocument doc({
  int revision = 1,
  String country = 'IN',
  String role = 'customer',
  String? title = 'Welcome',
}) => PublicStartupDocument(
  revision: revision,
  publishedAt: DateTime.utc(2026, 10, 25),
  country: country,
  role: role,
  locale: 'en',
  version: title == null ? null : '1',
  title: title,
  message: title == null ? null : 'Public message',
);

class Store implements PublicStartupStore {
  PublicStartupDocument? value;
  bool fail = false;
  Completer<PublicStartupDocument?>? gate;
  @override
  Future<PublicStartupDocument?> read() async {
    if (fail) throw StateError('Storage unavailable');
    return gate?.future ?? value;
  }

  @override
  Future<void> save(PublicStartupDocument document) async {
    if (fail) throw StateError('Storage unavailable');
    value = document;
  }
}

class Remote implements PublicStartupRemote {
  final result = Completer<PublicStartupDocument>();
  ApiCancellationToken? cancellation;
  @override
  Future<PublicStartupDocument> fetch({
    required String country,
    required String role,
    required String locale,
    required ApiCancellationToken cancellation,
  }) {
    this.cancellation = cancellation;
    return result.future;
  }
}

PublicStartupController create(Remote remote, Store store) =>
    PublicStartupController(
      remote: remote,
      store: store,
      country: 'IN',
      role: 'customer',
      locale: 'ta',
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Public startup rejects private fields, foreign scope and overlong text',
    () {
      for (final value in <Object?>[
        {...doc().toJson(), 'identity_id': 'private'},
        {...doc().toJson(), 'country': 'NG'},
        {...doc().toJson(), 'role': 'vendor'},
        {
          ...doc().toJson(),
          'splash': {
            'version': '1',
            'title': 'Welcome',
            'message': 'Public',
            'redirect': '/private',
          },
        },
        {
          ...doc().toJson(),
          'splash': {'version': '1', 'title': 'a' * 121, 'message': 'Public'},
        },
      ]) {
        expect(
          () => PublicStartupDocument.decode(
            value,
            country: 'IN',
            role: 'customer',
          ),
          throwsFormatException,
        );
      }
      expect(
        PublicStartupDocument.decode(
          doc(title: null).toJson(),
          country: 'IN',
          role: 'customer',
        ).title,
        isNull,
      );
    },
  );
  test(
    'Cached public text renders while a newer publication replaces it',
    () async {
      final store = Store()..value = doc(),
          remote = Remote(),
          controller = create(remote, store);
      final loading = controller.load();
      await Future<void>.delayed(Duration.zero);
      expect(controller.document?.title, 'Welcome');
      remote.result.complete(doc(revision: 2, title: 'Current public welcome'));
      await loading;
      expect(controller.document?.title, 'Current public welcome');
      expect(controller.offline, false);
      controller.dispose();
    },
  );
  test(
    'A publication that disables splash clears the old cached display',
    () async {
      final store = Store()..value = doc(),
          remote = Remote(),
          controller = create(remote, store);
      final loading = controller.load();
      remote.result.complete(doc(revision: 2, title: null));
      await loading;
      await Future<void>.delayed(Duration.zero);
      expect(controller.document?.title, isNull);
      expect(store.value?.title, isNull);
      controller.dispose();
    },
  );
  test(
    'Outage uses only an available validated cache and remains optional',
    () async {
      final store = Store()..value = doc(),
          remote = Remote(),
          controller = create(remote, store);
      final loading = controller.load();
      remote.result.completeError(StateError('Offline'));
      await loading;
      expect(controller.document?.title, 'Welcome');
      expect(controller.loading, false);
      expect(controller.offline, true);
      controller.dispose();
    },
  );
  test(
    'Late old or inconsistent publication cannot replace newer cache',
    () async {
      for (final next in [
        doc(revision: 1, title: 'Old'),
        doc(revision: 2, title: 'Changed without a revision'),
      ]) {
        final store = Store()..value = doc(revision: 2, title: 'Current'),
            remote = Remote(),
            controller = create(remote, store);
        final loading = controller.load();
        remote.result.complete(next);
        await loading;
        expect(controller.document?.title, 'Current');
        expect(controller.offline, true);
        controller.dispose();
      }
    },
  );
  test('Skip/disposal cancels the read and discards late completion', () async {
    final store = Store(),
        remote = Remote(),
        controller = create(remote, store);
    final loading = controller.load();
    controller.stop();
    expect(remote.cancellation?.isCancelled, true);
    remote.result.complete(doc());
    await loading;
    expect(controller.document, isNull);
    expect(store.value, isNull);
    controller.dispose();
  });
  test(
    'Unavailable native storage does not block fresh public content',
    () async {
      final store = Store()..fail = true,
          remote = Remote(),
          controller = create(remote, store);
      final loading = controller.load();
      remote.result.complete(doc());
      await loading;
      expect(controller.document?.title, 'Welcome');
      controller.dispose();
    },
  );
  test(
    'Encrypted public cache survives a new instance, isolates endpoint/country/role/language and expires',
    () async {
      var now = DateTime.utc(2026, 10, 25);
      final encrypted = EncryptedRecordStore(
        records: MemoryBinaryRecordStore(),
        keyProvider: MemoryCacheKeyProvider(),
        namespace: 'public-startup-test',
        clock: () => now,
      );
      EncryptedPublicStartupStore store({
        String endpoint = 'https://api.example.test',
        String country = 'IN',
        String role = 'customer',
        String locale = 'en',
      }) => EncryptedPublicStartupStore(
        endpoint: Uri.parse(endpoint),
        country: country,
        role: role,
        locale: locale,
        records: encrypted,
        clock: () => now,
      );
      await store().save(doc());
      expect((await store().read())?.title, 'Welcome');
      expect(
        await store(endpoint: 'https://other.example.test').read(),
        isNull,
      );
      expect(await store(country: 'NG').read(), isNull);
      expect(await store(role: 'vendor').read(), isNull);
      expect(await store(locale: 'ta').read(), isNull);
      await store().save(doc(revision: 2, title: 'New'));
      await store().save(doc(revision: 1, title: 'Stale'));
      expect((await store().read())?.title, 'New');
      await expectLater(
        store().save(doc(revision: 2, title: 'Changed')),
        throwsFormatException,
      );
      now = now.add(const Duration(hours: 1));
      expect(await store().read(), isNull);
    },
  );
}

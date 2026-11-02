import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

List<GeographyReference> _path() => List.generate(
  5,
  (i) => GeographyReference(
    id: '00000000-0000-4000-8000-00000000000${i + 1}',
    country: 'IN',
    kind: geographyKinds[i],
    code: i == 0 ? 'IN' : geographyKinds[i],
    parentID: i == 0 ? null : '00000000-0000-4000-8000-00000000000$i',
    nameEN: [
      'India',
      'Tamil Nadu',
      'Chennai district',
      'Chennai',
      'Central',
    ][i],
    nameTA: [
      'இந்தியா',
      'தமிழ்நாடு',
      'சென்னை மாவட்டம்',
      'சென்னை',
      'மத்திய பகுதி',
    ][i],
    masterRevision: 1,
  ),
);
AddressGeography _selection() =>
    AddressGeography(areaID: _path().last.id, path: _path());
Map<String, Object?> _page(int i) => {
  'country': 'IN',
  'kind': geographyKinds[i],
  if (i > 0) 'parent_id': _path()[i - 1].id,
  'items': [_path()[i].toJson()],
};
CustomerAddress _address({
  String id = 'address-1',
  bool isDefault = true,
  int revision = 1,
}) => CustomerAddress(
  id: id,
  label: 'Home',
  postalCode: '600001',
  locality: 'Chennai',
  line1: '123 Local Road',
  geography: _selection(),
  isDefault: isDefault,
  revision: revision,
);
void main() {
  test(
    'safe geography snapshots retain complete ancestry and strip unknown credentials',
    () {
      final raw = _selection().toJson();
      ((raw['path'] as List).last as Map)['provider_subject'] = 'secret';
      final value = AddressGeography.fromJson(raw);
      expect(value.path, hasLength(5));
      expect(value.label('ta'), contains('சென்னை'));
      expect(jsonEncode(value.toJson()), isNot(contains('secret')));
      for (final changed in <Map<String, Object?>>[
        {'area_id': value.path.first.id, 'path': raw['path']},
        {
          'area_id': value.areaID,
          'path': (raw['path'] as List).reversed.toList(),
        },
        {
          'area_id': value.areaID,
          'path': [(raw['path'] as List).first],
        },
      ]) {
        expect(() => AddressGeography.fromJson(changed), throwsFormatException);
      }
      final foreign = _selection().toJson();
      ((foreign['path'] as List)[2] as Map)['country'] = 'US';
      expect(() => AddressGeography.fromJson(foreign), throwsFormatException);
      expect(
        () => GeographyPage.fromJson({..._page(0), 'country': 'US'}),
        throwsFormatException,
      );
      expect(
        () => GeographyPage.fromJson({
          ..._page(0),
          'items': [_path().first.toJson(), _path().first.toJson()],
        }),
        throwsFormatException,
      );
      expect(
        () => GeographyPage.fromJson({
          ..._page(0),
          'next_after': _path().first.id,
        }),
        throwsFormatException,
      );
      expect(
        () => GeographyReference.fromJson({
          ..._path().first.toJson(),
          'name_ta': '',
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'normal directory adapter uses structured hierarchy query and rejects foreign responses',
    () async {
      final transport = _Transport();
      final api = GeographyApi(
        ApiClient(
          baseUrl: Uri.parse('https://api.example.test'),
          transport: transport,
          authSession: _Session(),
          retryBudget: const ApiRetryBudget(maxAttempts: 1),
        ),
        country: 'IN',
      );
      await api.search(
        kind: 'STATE',
        parentID: _path().first.id,
        query: 'Tamil %',
      );
      expect(transport.requests.single.url.path, '/v1/geography');
      expect(transport.requests.single.url.queryParameters, {
        'kind': 'STATE',
        'parent_id': _path().first.id,
        'search': 'Tamil %',
      });
      transport.foreign = true;
      await expectLater(
        api.search(kind: 'COUNTRY'),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'picker walks authoritative parents, changes parent and rejects stale choices',
    () async {
      final directory = _Directory(),
          controller = GeographyController(_Directory(), country: 'IN');
      await controller.load();
      final old = controller.page!.items.first;
      await controller.choose(old);
      expect(controller.kind, 'STATE');
      expect(await controller.choose(old), isFalse);
      await controller.back();
      expect(controller.kind, 'COUNTRY');
      expect(controller.path, isEmpty);
      for (var i = 0; i < 5; i++) {
        expect(controller.page!.kind, geographyKinds[i]);
        await controller.choose(controller.page!.items.single);
      }
      expect(controller.selection!.areaID, _selection().areaID);
      controller.dispose();
      final failing = GeographyController(directory, country: 'IN');
      directory.fail = true;
      await failing.load();
      expect(failing.status, GeographyStatus.failure);
      directory.fail = false;
      await failing.retry();
      expect(failing.status, GeographyStatus.ready);
      failing.dispose();
    },
  );
  test(
    'late directory and address responses cannot restore an old account or disposed state',
    () async {
      final directory = _Directory()..pending = Completer<GeographyPage>();
      var current = true;
      final picker = GeographyController(
        directory,
        country: 'IN',
        scopeIsCurrent: () => current,
      );
      final load = picker.load();
      current = false;
      directory.pending!.complete(GeographyPage.fromJson(_page(0)));
      await load;
      expect(picker.page, isNull);
      expect(picker.path, isEmpty);
      picker.dispose();
      final remote = _AddressRemote()
        ..pending = Completer<List<CustomerAddress>>();
      final controller = TransactionController(remote: remote);
      final loading = controller.loadAddresses();
      controller.dispose();
      remote.pending!.complete([_address()]);
      await loading;
      expect(controller.state.addresses, isEmpty);
    },
  );
  test(
    'address book works without wallet or slot policies and reads authoritative default revisions',
    () async {
      final remote = _AddressRemote()..rows = [_address()];
      final controller = TransactionController(remote: remote);
      await controller.loadAddresses();
      expect(controller.state.status, TransactionStatus.ready);
      expect(remote.financeCalls, 0);
      expect(
        await controller.saveAddress(
          draft: CustomerAddressDraft(
            label: 'Office',
            line1: '456 Commerce Road',
            postalCode: '600001',
            locality: 'Chennai',
            isDefault: true,
            geographyAreaID: _selection().areaID,
          ),
        ),
        isTrue,
      );
      expect(controller.addressCommandPending, isFalse);
      expect(
        controller.state.addresses.where((e) => e.isDefault),
        hasLength(1),
      );
      expect(controller.state.addresses.first.revision, 2);
      expect(remote.lastDraft!.geographyAreaID, _selection().areaID);
      expect(
        await controller.deleteAddress(controller.state.addresses.last),
        isTrue,
      );
      expect(controller.state.addresses.single.isDefault, isTrue);
      controller.dispose();
    },
  );
  test(
    'acknowledged address writes survive failed readback and lost account results are discarded',
    () async {
      final remote = _AddressRemote(),
          controller = TransactionController(remote: remote);
      remote.failAfterWrite = true;
      expect(
        await controller.saveAddress(
          draft: const CustomerAddressDraft(
            label: 'Home',
            line1: '123 Local Road',
            postalCode: '600001',
            locality: 'Chennai',
          ),
        ),
        isTrue,
      );
      expect(controller.state.message, contains('Address saved'));
      expect(controller.state.addresses, hasLength(1));
      expect(controller.addressCommandPending, isFalse);
      controller.dispose();
      var current = true;
      final late = _AddressRemote()
        ..createPending = Completer<CustomerAddress>();
      final scoped = TransactionController(
        remote: late,
        scopeIsCurrent: () => current,
      );
      final save = scoped.saveAddress(
        draft: const CustomerAddressDraft(
          label: 'Home',
          line1: '123 Local Road',
          postalCode: '600001',
          locality: 'Chennai',
        ),
      );
      current = false;
      late.createPending!.complete(_address());
      expect(await save, isFalse);
      expect(scoped.state.addresses, isEmpty);
      scoped.dispose();
    },
  );
  testWidgets(
    'normal customer chooses complete hierarchy, saves and removes the last address',
    (tester) async {
      final remote = _AddressRemote();
      final controller = TransactionController(
        remote: remote,
        geography: _Directory(),
        addressCountry: 'IN',
      );
      await tester.pumpWidget(
        MaterialApp(home: CustomerAddressesScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add address'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Label'),
        'Home',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Address line 1'),
        '123 Local Road',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Locality or city'),
        'Chennai',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Postal or PIN code'),
        '600001',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save address'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('address-geography-choice')),
        -250,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Choose an address area before saving.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('address-geography-choice')));
      await tester.pumpAndSettle();
      for (final item in _path()) {
        await tester.ensureVisible(
          find.byKey(ValueKey('geography-${item.id}')),
        );
        await tester.tap(find.byKey(ValueKey('geography-${item.id}')));
        await tester.pumpAndSettle();
      }
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save address'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();
      expect(remote.lastDraft!.geographyAreaID, _selection().areaID);
      expect(find.text('Home'), findsOneWidget);
      expect(remote.financeCalls, 0);
      await tester.tap(find.byTooltip('Remove Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('No saved addresses'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
  testWidgets('Tamil geography search and retry remain usable at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final directory = _Directory()..fail = true;
    final picker = GeographyController(directory, country: 'IN');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ta'),
        supportedLocales: const [Locale('en'), Locale('ta')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: GeographyPicker(controller: picker),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('மீண்டும் முயலவும்'), findsOneWidget);
    directory.fail = false;
    await tester.ensureVisible(find.text('மீண்டும் முயலவும்'));
    await tester.tap(find.text('மீண்டும் முயலவும்'));
    await tester.pumpAndSettle();
    expect(find.text('இந்தியா'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    picker.dispose();
  });
}

final class _Directory implements GeographyDirectory {
  bool fail = false;
  Completer<GeographyPage>? pending;
  @override
  Future<GeographyPage> search({
    required String kind,
    String? parentID,
    String query = '',
    String? after,
  }) async {
    if (pending != null) return pending!.future;
    if (fail) throw StateError('Directory unavailable');
    return GeographyPage.fromJson(_page(geographyKinds.indexOf(kind)));
  }
}

final class _AddressRemote extends Fake implements TransactionRemote {
  List<CustomerAddress> rows = [];
  CustomerAddressDraft? lastDraft;
  int financeCalls = 0;
  bool failAfterWrite = false;
  bool written = false;
  Completer<List<CustomerAddress>>? pending;
  Completer<CustomerAddress>? createPending;
  @override
  Future<List<CustomerAddress>> addresses() async {
    if (pending != null) return pending!.future;
    if (written && failAfterWrite) throw StateError('Read unavailable');
    return rows;
  }

  @override
  Future<List<CustomerDeliverySlot>> deliverySlots() async {
    financeCalls++;
    throw StateError('No slot policy');
  }

  @override
  Future<WalletExperience> walletExperience() async {
    financeCalls++;
    throw StateError('No wallet policy');
  }

  @override
  Future<CustomerAddress> createAddress(
    CustomerAddressDraft value, {
    String? idempotencyKey,
  }) async {
    lastDraft = value;
    if (createPending != null) return createPending!.future;
    rows = rows
        .map(
          (e) => _address(id: e.id, isDefault: false, revision: e.revision + 1),
        )
        .toList();
    final address = _address(id: 'address-${rows.length + 1}');
    rows = [...rows, address];
    written = true;
    return address;
  }

  @override
  Future<CustomerAddress> updateAddress(
    CustomerAddress current,
    CustomerAddressDraft value, {
    String? idempotencyKey,
  }) async {
    lastDraft = value;
    return current;
  }

  @override
  Future<void> deleteAddress(
    CustomerAddress value, {
    String? idempotencyKey,
  }) async {
    rows = rows
        .where((e) => e.id != value.id)
        .map(
          (e) => _address(id: e.id, isDefault: true, revision: e.revision + 1),
        )
        .toList();
  }
}

final class _Session implements ApiAuthSession {
  @override
  Future<String?> accessToken() async => 'synthetic-geography-session';
  @override
  Future<bool> refresh() async => false;
}

final class _Transport implements ApiTransport {
  final requests = <TransportRequest>[];
  bool foreign = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    final i = geographyKinds.indexOf(request.url.queryParameters['kind']!);
    final data = _page(i);
    if (foreign) {
      data['country'] = 'US';
      data['items'] = <Object?>[];
    }
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(data))),
    );
  }
}

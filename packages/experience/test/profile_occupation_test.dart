import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

const _id = '00000000-0000-4000-8000-000000000123';
Map<String, Object?> _reference() => {
  'id': _id,
  'code': 'TEACHER',
  'country': 'IN',
  'name_en': 'Teacher',
  'name_ta': 'ஆசிரியர்',
  'master_revision': 1,
};
Map<String, Object?> _selection({int revision = 1, bool selected = true}) => {
  'country': 'IN',
  'occupation': selected ? _reference() : null,
  'revision': revision,
  if (revision > 0) 'updated_at': '2026-10-27T06:00:00Z',
};

void main() {
  test(
    'safe occupation projection preserves bilingual reference and strips unknown credentials',
    () {
      final raw = _selection();
      (raw['occupation']! as Map)['provider_subject'] = 'secret-provider';
      raw['refresh_token'] = 'secret-refresh';
      final value = ProfileOccupationSelection.fromJson(raw);
      expect(value.occupation!.label('ta-IN'), 'ஆசிரியர்');
      expect(value.occupation!.label('en'), 'Teacher');
      expect(jsonEncode(value.toJson()), isNot(contains('secret')));
      expect(
        ProfileOccupationSelection.fromJson(
          _selection(revision: 0, selected: false),
        ).updatedAt,
        isNull,
      );
      expect(
        ProfileOccupationSelection.fromJson(
          _selection(selected: false),
        ).occupation,
        isNull,
      );
    },
  );
  test(
    'rejects malformed references, cross-country state and invalid pagination',
    () {
      for (final reference in <Map<String, Object?>>[
        {..._reference(), 'id': 'invalid'},
        {..._reference(), 'code': 'bad code'},
        {..._reference(), 'name_ta': ''},
        {..._reference(), 'master_revision': 0},
        {..._reference(), 'name_en': 'Bad\nName'},
      ]) {
        expect(
          () => ProfileOccupation.fromJson(reference),
          throwsFormatException,
        );
      }
      for (final selection in <Map<String, Object?>>[
        {..._selection(), 'country': 'US'},
        {..._selection(), 'revision': -1},
        {..._selection(), 'updated_at': '2026-10-27'},
        {..._selection(), 'revision': 0},
        {'country': 'IN', 'revision': 0},
      ]) {
        expect(
          () => ProfileOccupationSelection.fromJson(selection),
          throwsFormatException,
        );
      }
      expect(
        () => ProfileOccupationPage.fromJson({
          'country': 'IN',
          'items': [_reference(), _reference()],
        }),
        throwsFormatException,
      );
      expect(
        () => ProfileOccupationPage.fromJson({
          'country': 'IN',
          'items': <Object?>[],
          'next_after': _id,
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'normal adapter sends structured search and non-replayed revisioned commands',
    () async {
      final transport = _Transport();
      final api = ProfileOccupationApi(
        ApiClient(
          baseUrl: Uri.parse('https://api.example.test'),
          transport: transport,
          authSession: _Session(),
          retryBudget: const ApiRetryBudget(maxAttempts: 1),
        ),
        country: 'IN',
      );
      expect((await api.current()).revision, 1);
      await api.search('Teacher %', after: _id);
      await api.save(null, 1);
      expect(transport.requests.map((request) => request.url.path), [
        '/v1/me/occupation',
        '/v1/occupations',
        '/v1/me/occupation',
      ]);
      expect(transport.requests[1].url.queryParametersAll, {
        'search': ['Teacher %'],
        'after': [_id],
      });
      expect(jsonDecode(utf8.decode(transport.requests.last.body!)), {
        'occupation_id': '',
        'expected_revision': 1,
      });
      expect(transport.requests.last.method, 'PUT');
      await expectLater(api.save('invalid', 1), throwsFormatException);
      await expectLater(api.search('bad\nquery'), throwsFormatException);
      transport.foreign = true;
      await expectLater(api.current(), throwsFormatException);
      await expectLater(api.search(''), throwsFormatException);
      await expectLater(api.save(null, 1), throwsFormatException);
    },
  );
  test(
    'controller saves, retains retired choices, clears and requires refresh after uncertain failure',
    () async {
      final remote = _Remote();
      final controller = ProfileOccupationController(
        remote,
        scopeIsCurrent: () => true,
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.save(_id);
      expect(controller.state.current!.revision, 1);
      expect(controller.state.saved, isTrue);
      remote.items = [];
      await controller.load();
      expect(controller.state.current!.occupation!.id, _id);
      expect(controller.state.page!.items, isEmpty);
      remote.fail = true;
      await controller.save(null);
      expect(controller.state.failed, isTrue);
      expect(controller.state.current!.occupation, isNotNull);
      final writes = remote.writes;
      await controller.save(null);
      expect(remote.writes, writes);
      remote.fail = false;
      await controller.load();
      await controller.save(null);
      expect(controller.state.current!.occupation, isNull);
      expect(controller.state.current!.revision, 2);
      await expectLater(
        controller.save('00000000-0000-4000-8000-000000000999'),
        throwsFormatException,
      );
    },
  );
  test(
    'late responses cannot populate a replaced account scope or a disposed controller',
    () async {
      var active = true;
      final remote = _Remote()..gate = Completer<ProfileOccupationSelection>();
      final controller = ProfileOccupationController(
        remote,
        scopeIsCurrent: () => active,
      );
      final loading = controller.load();
      active = false;
      remote.gate!.complete(ProfileOccupationSelection.fromJson(_selection()));
      await loading;
      expect(controller.state.current, isNull);
      expect(remote.searches, isEmpty);
      controller.dispose();
      final another = _Remote()..gate = Completer<ProfileOccupationSelection>();
      final disposed = ProfileOccupationController(
        another,
        scopeIsCurrent: () => true,
      );
      final pending = disposed.load();
      disposed.dispose();
      another.gate!.complete(ProfileOccupationSelection.fromJson(_selection()));
      await pending;
      expect(disposed.state.current, isNull);
    },
  );
  test(
    'schema-3 portable export includes own safe occupation and cleared state',
    () {
      final data = <String, Object?>{
        'schema_version': 3,
        'generated_at': '2026-10-27T06:00:00Z',
        'identity_id': 'identity-1',
        'tenant_id': 'tenant-1',
        'country': 'IN',
        'roles': ['CUSTOMER'],
        'profile': {
          'display_name': 'Customer',
          'locale': 'en',
          'time_zone': 'Asia/Kolkata',
          'version': 1,
          'updated_at': '2026-10-27T06:00:00Z',
        },
        'sessions': [],
        'consents': [],
        'consent_history': [],
        'contact_snapshots': [],
        'deletion_history': [],
        'coverage': {
          'included': ['identity.occupation_references'],
          'excluded': ['orders_and_payments'],
        },
        'occupation_references': [_selection()],
      };
      final reference =
          ((data['occupation_references']! as List).first as Map)['occupation']!
              as Map;
      reference['private_key'] = 'secret';
      final document = AccountExportDocument.fromJson(data);
      expect(document.json, contains('occupation_references'));
      expect(document.json, contains('ஆசிரியர்'));
      expect(document.json, isNot(contains('secret')));
      data['occupation_references'] = [_selection(selected: false)];
      expect(
        AccountExportDocument.fromJson(data).json,
        contains('"occupation":null'),
      );
      data['occupation_references'] = [_selection(), _selection()];
      expect(() => AccountExportDocument.fromJson(data), throwsFormatException);
    },
  );
  testWidgets(
    'normal screen searches, selects, persists, reloads and removes occupation',
    (tester) async {
      final remote = _Remote();
      final controller = ProfileOccupationController(
        remote,
        scopeIsCurrent: () => true,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: ProfileOccupationScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Teacher');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Search'));
      await tester.pumpAndSettle();
      expect(remote.searches.last, 'Teacher');
      await tester.tap(find.byKey(const ValueKey('occupation-$_id')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-profile-occupation')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-profile-occupation')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Occupation saved.'),
        ),
        findsOneWidget,
      );
      expect(remote.value.occupation!.id, _id);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove occupation'));
      await tester.tap(find.text('Remove occupation'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-profile-occupation')));
      await tester.pumpAndSettle();
      expect(remote.value.occupation, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Tamil error/retry screen remains usable with large text', (
    tester,
  ) async {
    final remote = _Remote()..fail = true;
    final controller = ProfileOccupationController(
      remote,
      scopeIsCurrent: () => true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ta'),
        supportedLocales: const [Locale('en'), Locale('ta')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ProfileOccupationScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('தொழில்'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('புதுப்பி'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    remote.fail = false;
    await tester.tap(find.text('புதுப்பி'));
    await tester.pumpAndSettle();
    expect(controller.state.failed, isFalse);
    expect(find.text('ஆசிரியர்'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _Remote implements ProfileOccupationRemote {
  ProfileOccupationSelection value = ProfileOccupationSelection.fromJson(
    _selection(revision: 0, selected: false),
  );
  List<ProfileOccupation> items = [ProfileOccupation.fromJson(_reference())];
  final searches = <String>[];
  bool fail = false;
  int writes = 0;
  Completer<ProfileOccupationSelection>? gate;
  @override
  Future<ProfileOccupationSelection> current() async {
    if (fail) {
      throw StateError('synthetic unavailable');
    }
    return gate?.future ?? value;
  }

  @override
  Future<ProfileOccupationPage> search(String term, {String? after}) async {
    searches.add(term);
    if (fail) {
      throw StateError('synthetic unavailable');
    }
    return ProfileOccupationPage(country: 'IN', items: items);
  }

  @override
  Future<ProfileOccupationSelection> save(String? id, int revision) async {
    writes++;
    if (fail) {
      throw StateError('synthetic uncertain write');
    }
    value = ProfileOccupationSelection(
      country: 'IN',
      revision: revision + 1,
      occupation: id == null ? null : ProfileOccupation.fromJson(_reference()),
      updatedAt: DateTime.utc(2026, 10, 27),
    );
    return value;
  }
}

final class _Session implements ApiAuthSession {
  @override
  Future<String?> accessToken() async => 'synthetic-profile-occupation';
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
    final country = foreign ? 'US' : 'IN';
    final body = request.url.path == '/v1/occupations'
        ? {
            'country': country,
            'items': [_reference()],
          }
        : {..._selection(), 'country': country, 'occupation': null};
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );
  }
}

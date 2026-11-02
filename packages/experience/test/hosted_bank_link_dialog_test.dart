import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

const _id = '30000000-0000-4000-8000-000000000001';

final class _Session implements ApiAuthSession {
  @override
  Future<String?> accessToken() async => 'synthetic-owner';
  @override
  Future<bool> refresh() async => false;
}

final class _Bank implements ApiTransport {
  int starts = 0, reads = 0, resolves = 0, cancels = 0;
  bool exists = false, failCancel = false, badUrl = false;
  String status = 'AWAITING_USER';
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    if (request.method == 'GET') {
      reads++;
      if (!exists) {
        return _response(404, {
          'error': {
            'code': 'BANK_LINK_NOT_FOUND',
            'message': 'Not found',
            'correlation_id': 'bank-dialog-test',
            'retryable': false,
            'field_errors': <Object?>[],
            'details': <String, Object?>{},
          },
        });
      }
    } else if (request.method == 'DELETE') {
      cancels++;
      if (failCancel) {
        return _response(503, {
          'error': {
            'code': 'BANK_PROVIDER_UNAVAILABLE',
            'message': 'Unavailable',
            'correlation_id': 'bank-dialog-test',
            'retryable': true,
            'field_errors': <Object?>[],
            'details': <String, Object?>{},
          },
        });
      }
      status = 'CANCELLED';
    } else if (request.url.path.endsWith('/resume')) {
      resolves++;
    } else {
      starts++;
      exists = true;
    }
    return _response(200, {
      'attempt_id': _id,
      'application_role': 'VENDOR',
      'status': status,
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
      if (status == 'AWAITING_USER' && request.method != 'GET')
        'launch_url': badUrl
            ? 'https://evil.example.test/hosted'
            : 'https://bank.example.test/hosted?one_time=private',
      if (status == 'VERIFIED')
        'account': {
          'reference': 'bankref_synthetic1234',
          'holder_name': 'Synthetic Owner',
          'last4': '1234',
          'ifsc': 'TEST0123456',
        },
    });
  }

  TransportResponse _response(int status, Object value) => TransportResponse(
    statusCode: status,
    headers: const {'content-type': 'application/json'},
    body: Uint8List.fromList(utf8.encode(jsonEncode(value))),
  );
}

HostedBankLinkClient _client(_Bank bank) => HostedBankLinkClient(
  client: ApiClient(
    baseUrl: Uri.parse('https://api.example.test'),
    transport: bank,
    authSession: _Session(),
    retryBudget: const ApiRetryBudget(maxAttempts: 1),
  ),
  applicationRole: 'vendor',
  allowedOrigins: {Uri.parse('https://bank.example.test')},
);
Future<void> _mount(
  WidgetTester tester,
  HostedBankLinkClient client, {
  required Future<bool> Function(Uri) launch,
  void Function(VerifiedBankAccount?)? completed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final value = await showHostedBankLinkDialog(
                context,
                client: client,
                launch: launch,
              );
              completed?.call(value);
            },
            child: const Text('Verify'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Verify'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'bank journey opens only approved page and requires owning verification before using masked result',
    (tester) async {
      final bank = _Bank(), client = _client(bank);
      VerifiedBankAccount? result;
      final launches = <Uri>[];
      await _mount(
        tester,
        client,
        launch: (url) async {
          launches.add(url);
          return true;
        },
        completed: (value) => result = value,
      );
      expect(bank.starts, 1);
      expect(find.byKey(const ValueKey('bank-link-use')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('bank-link-open')));
      await tester.pumpAndSettle();
      expect(launches.single.host, 'bank.example.test');
      expect(result, isNull);
      bank.status = 'VERIFIED';
      await tester.tap(find.byKey(const ValueKey('bank-link-refresh')));
      await tester.pumpAndSettle();
      expect(find.textContaining('•••• 1234'), findsOneWidget);
      expect(result, isNull);
      final before = bank.resolves;
      await tester.tap(find.byKey(const ValueKey('bank-link-use')));
      await tester.pumpAndSettle();
      expect(result?.reference, 'bankref_synthetic1234');
      expect(bank.resolves, before + 1);
    },
  );
  testWidgets(
    'closing retains server progress and reopening resumes without another create',
    (tester) async {
      final bank = _Bank(), client = _client(bank);
      await _mount(tester, client, launch: (_) async => true);
      await tester.tap(find.byKey(const ValueKey('bank-link-close')));
      await tester.pumpAndSettle();
      expect(bank.cancels, 0);
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(bank.starts, 1);
      expect(bank.reads, 2);
      expect(bank.resolves, 1);
    },
  );
  testWidgets(
    'unconfirmed cancellation stays recoverable and explicit retry confirms it',
    (tester) async {
      final bank = _Bank()..failCancel = true, client = _client(bank);
      await _mount(tester, client, launch: (_) async => true);
      await tester.tap(find.byKey(const ValueKey('bank-link-cancel')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cancellation was not confirmed'),
        findsOneWidget,
      );
      expect(bank.status, 'AWAITING_USER');
      bank.failCancel = false;
      await tester.tap(find.byKey(const ValueKey('bank-link-cancel')));
      await tester.pumpAndSettle();
      expect(bank.status, 'CANCELLED');
      expect(find.byKey(const ValueKey('bank-link-open')), findsNothing);
    },
  );
  testWidgets('unapproved provider URL cannot be shown or launched', (
    tester,
  ) async {
    final bank = _Bank()..badUrl = true, client = _client(bank);
    var launches = 0;
    await _mount(
      tester,
      client,
      launch: (_) async {
        launches++;
        return true;
      },
    );
    expect(find.byKey(const ValueKey('bank-link-open')), findsNothing);
    expect(launches, 0);
    expect(find.textContaining('evil.example.test'), findsNothing);
    expect(find.byKey(const ValueKey('bank-link-message')), findsOneWidget);
  });
  testWidgets(
    'expired attempt requires explicit restart and narrow layout remains usable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bank = _Bank()
            ..exists = true
            ..status = 'DECLINED',
          client = _client(bank);
      await _mount(tester, client, launch: (_) async => true);
      expect(bank.starts, 0);
      expect(find.byKey(const ValueKey('bank-link-restart')), findsOneWidget);
      bank.status = 'AWAITING_USER';
      await tester.tap(find.byKey(const ValueKey('bank-link-restart')));
      await tester.pumpAndSettle();
      expect(bank.starts, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

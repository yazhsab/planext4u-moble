import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  for (final role in AppRole.values) {
    test(
      '${role.name} support API uses role-owned idempotent routes',
      () async {
        final transport = _SupportTransport(role);
        final api = SupportApi(
          ApiClient(
            baseUrl: Uri.parse('https://api.example.test'),
            transport: transport,
            authSession: const _StaticAuthSession(),
            correlationIdFactory: () => 'corr-support-${role.name}',
          ),
        );
        final created = await api.create(
          role: role,
          category: _category(role),
          subject: '${role.label} support request',
          description: 'Please help with this role-owned workflow.',
          idempotencyKey: 'support-create-${role.name}-0001',
        );
        final listed = await api.list(role);
        final loaded = await api.get(created.id);
        final updated = await api.addMessage(
          ticketId: created.id,
          body: 'The request is still pending.',
          idempotencyKey: 'support-message-${role.name}-0001',
        );

        expect(created.ownerRole, role);
        expect(listed.items.single.ownerRole, role);
        expect(loaded.id, created.id);
        expect(updated.messages, hasLength(2));
        expect(transport.requests.map((request) => request.url.path), [
          '/v1/support/tickets',
          '/v1/support/tickets',
          '/v1/support/tickets/support-ticket-001',
          '/v1/support/tickets/support-ticket-001/messages',
        ]);
        expect(
          transport.requests[1].url.queryParameters['owner_role'],
          role.supportWireValue,
        );
        expect(
          transport.requests[0].headers['Idempotency-Key'],
          'support-create-${role.name}-0001',
        );
        expect(
          transport.requests[3].headers['Idempotency-Key'],
          'support-message-${role.name}-0001',
        );
      },
    );
  }

  test('support controller rejects tickets from another role', () async {
    final remote = _SupportRemote(AppRole.vendor)..responseRole = AppRole.rider;
    final controller = SupportController(role: AppRole.vendor, remote: remote);

    await controller.load();

    expect(controller.state.status, SupportViewStatus.failure);
    expect(controller.state.tickets, isEmpty);
    expect(controller.state.message, contains('safely'));
  });

  testWidgets('support screen loads an owned ticket and sends a message', (
    tester,
  ) async {
    final remote = _SupportRemote(AppRole.customer);
    final controller = SupportController(
      role: AppRole.customer,
      remote: remote,
    );
    await tester.pumpWidget(
      MaterialApp(home: SupportScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-ticket-list')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('support-ticket-support-ticket-001')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-message-list')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('support-message-input')),
      'The request is still pending.',
    );
    await tester.tap(find.byKey(const ValueKey('support-send-message')));
    await tester.pumpAndSettle();

    expect(remote.sentMessages, ['The request is still pending.']);
    expect(controller.state.selected?.messages, hasLength(2));
  });
}

final class _StaticAuthSession implements ApiAuthSession {
  const _StaticAuthSession();

  @override
  Future<String?> accessToken() async => 'support-access-token';

  @override
  Future<bool> refresh() async => false;
}

final class _SupportTransport implements ApiTransport {
  _SupportTransport(this.role);

  final AppRole role;
  final List<TransportRequest> requests = [];

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    final withSecondMessage = request.url.path.endsWith('/messages');
    final body =
        request.method == 'GET' && request.url.path == '/v1/support/tickets'
        ? {
            'items': [_ticketJson(role)],
          }
        : _ticketJson(role, withSecondMessage: withSecondMessage);
    return TransportResponse(
      statusCode: request.method == 'POST' ? 201 : 200,
      headers: {'X-Correlation-ID': 'corr-support-server'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );
  }
}

final class _SupportRemote implements SupportRemote {
  _SupportRemote(this.role);

  final AppRole role;
  AppRole? responseRole;
  final List<String> sentMessages = [];

  @override
  Future<SupportTicketPage> list(AppRole role) async =>
      SupportTicketPage(items: [_ticket(responseRole ?? this.role)]);

  @override
  Future<SupportTicket> get(String ticketId) async =>
      _ticket(responseRole ?? role);

  @override
  Future<SupportTicket> create({
    required AppRole role,
    required SupportCategory category,
    required String subject,
    required String description,
    SupportPriority priority = SupportPriority.normal,
    String? relatedReference,
    String? idempotencyKey,
  }) async => _ticket(responseRole ?? role);

  @override
  Future<SupportTicket> addMessage({
    required String ticketId,
    required String body,
    String? idempotencyKey,
  }) async {
    sentMessages.add(body);
    final current = _ticket(responseRole ?? role);
    return SupportTicket(
      id: current.id,
      ownerRole: current.ownerRole,
      category: current.category,
      subject: current.subject,
      priority: current.priority,
      status: current.status,
      messages: [
        ...current.messages,
        SupportMessage(
          id: 'support-message-002',
          author: SupportMessageAuthor.requester,
          body: body,
          createdAt: DateTime.utc(2026, 9, 1, 10, 1),
        ),
      ],
      createdAt: current.createdAt,
      updatedAt: DateTime.utc(2026, 9, 1, 10, 1),
    );
  }
}

SupportTicket _ticket(AppRole role) =>
    SupportTicket.fromJson(_ticketJson(role));

Map<String, Object?> _ticketJson(
  AppRole role, {
  bool withSecondMessage = false,
}) => {
  'id': 'support-ticket-001',
  'owner_role': role.supportWireValue,
  'category': _category(role).wireValue,
  'subject': '${role.label} support request',
  'priority': 'NORMAL',
  'status': 'OPEN',
  'messages': [
    {
      'id': 'support-message-001',
      'author_type': 'REQUESTER',
      'body': 'Please help with this role-owned workflow.',
      'created_at': '2026-09-01T10:00:00Z',
    },
    if (withSecondMessage)
      {
        'id': 'support-message-002',
        'author_type': 'REQUESTER',
        'body': 'The request is still pending.',
        'created_at': '2026-09-01T10:01:00Z',
      },
  ],
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': withSecondMessage
      ? '2026-09-01T10:01:00Z'
      : '2026-09-01T10:00:00Z',
};

SupportCategory _category(AppRole role) => switch (role) {
  AppRole.customer => SupportCategory.order,
  AppRole.vendor => SupportCategory.vendorOperations,
  AppRole.rider => SupportCategory.riderOperations,
};

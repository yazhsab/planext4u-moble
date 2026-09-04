import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';

enum SupportCategory {
  account('ACCOUNT', 'Account'),
  order('ORDER', 'Order'),
  payment('PAYMENT', 'Payment'),
  vendorOperations('VENDOR_OPERATIONS', 'Vendor operations'),
  riderOperations('RIDER_OPERATIONS', 'Rider operations'),
  other('OTHER', 'Other');

  const SupportCategory(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

enum SupportPriority {
  low('LOW'),
  normal('NORMAL'),
  high('HIGH'),
  urgent('URGENT');

  const SupportPriority(this.wireValue);
  final String wireValue;
}

enum SupportTicketStatus {
  open('OPEN'),
  waitingForSupport('WAITING_FOR_SUPPORT'),
  waitingForRequester('WAITING_FOR_REQUESTER'),
  resolved('RESOLVED'),
  closed('CLOSED');

  const SupportTicketStatus(this.wireValue);
  final String wireValue;
}

enum SupportMessageAuthor {
  requester('REQUESTER'),
  support('SUPPORT');

  const SupportMessageAuthor(this.wireValue);
  final String wireValue;
}

extension SupportRoleWire on AppRole {
  String get supportWireValue => name.toUpperCase();
}

final class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Object? value) {
    final json = _object(value, 'Support message');
    return SupportMessage(
      id: _identifier(json, 'id'),
      author: _enumValue(
        SupportMessageAuthor.values,
        json['author_type'],
        (value) => value.wireValue,
        'message author',
      ),
      body: _text(json, 'body', maximum: 8000),
      createdAt: _instant(json, 'created_at'),
    );
  }

  final String id;
  final SupportMessageAuthor author;
  final String body;
  final DateTime createdAt;
}

final class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.ownerRole,
    required this.category,
    required this.subject,
    required this.priority,
    required this.status,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.relatedReference,
  });

  factory SupportTicket.fromJson(Object? value) {
    final json = _object(value, 'Support ticket');
    final messages = json['messages'];
    if (messages is! List<Object?>) {
      throw const FormatException('Support ticket messages are invalid.');
    }
    final parsedMessages = messages
        .map(SupportMessage.fromJson)
        .toList(growable: false);
    for (var index = 1; index < parsedMessages.length; index++) {
      if (parsedMessages[index].createdAt.isBefore(
        parsedMessages[index - 1].createdAt,
      )) {
        throw const FormatException('Support messages are out of order.');
      }
    }
    return SupportTicket(
      id: _identifier(json, 'id'),
      ownerRole: _role(json['owner_role']),
      category: _enumValue(
        SupportCategory.values,
        json['category'],
        (value) => value.wireValue,
        'ticket category',
      ),
      subject: _text(json, 'subject', maximum: 160),
      relatedReference: _optionalIdentifier(json, 'related_reference'),
      priority: _enumValue(
        SupportPriority.values,
        json['priority'],
        (value) => value.wireValue,
        'ticket priority',
      ),
      status: _enumValue(
        SupportTicketStatus.values,
        json['status'],
        (value) => value.wireValue,
        'ticket status',
      ),
      messages: List.unmodifiable(parsedMessages),
      createdAt: _instant(json, 'created_at'),
      updatedAt: _instant(json, 'updated_at'),
    );
  }

  final String id;
  final AppRole ownerRole;
  final SupportCategory category;
  final String subject;
  final String? relatedReference;
  final SupportPriority priority;
  final SupportTicketStatus status;
  final List<SupportMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class SupportTicketPage {
  const SupportTicketPage({required this.items, this.nextCursor});

  factory SupportTicketPage.fromJson(Object? value) {
    final json = _object(value, 'Support ticket page');
    final items = json['items'];
    if (items is! List<Object?>) {
      throw const FormatException('Support ticket page items are invalid.');
    }
    return SupportTicketPage(
      items: List.unmodifiable(items.map(SupportTicket.fromJson)),
      nextCursor: _optionalText(json, 'next_cursor', maximum: 256),
    );
  }

  final List<SupportTicket> items;
  final String? nextCursor;
}

abstract interface class SupportRemote {
  Future<SupportTicketPage> list(AppRole role);

  Future<SupportTicket> get(String ticketId);

  Future<SupportTicket> create({
    required AppRole role,
    required SupportCategory category,
    required String subject,
    required String description,
    SupportPriority priority,
    String? relatedReference,
    String? idempotencyKey,
  });

  Future<SupportTicket> addMessage({
    required String ticketId,
    required String body,
    String? idempotencyKey,
  });
}

final class SupportApi implements SupportRemote {
  const SupportApi(this._client);

  final ApiClient _client;

  @override
  Future<SupportTicketPage> list(AppRole role) async => (await _client.send(
    ApiRequest.get(
      operation: 'support.list_tickets',
      path: '/v1/support/tickets',
      query: {
        'owner_role': [role.supportWireValue],
      },
    ),
    SupportTicketPage.fromJson,
  )).value;

  @override
  Future<SupportTicket> get(String ticketId) async => (await _client.send(
    ApiRequest.get(
      operation: 'support.get_ticket',
      path: '/v1/support/tickets/${Uri.encodeComponent(ticketId)}',
    ),
    SupportTicket.fromJson,
  )).value;

  @override
  Future<SupportTicket> create({
    required AppRole role,
    required SupportCategory category,
    required String subject,
    required String description,
    SupportPriority priority = SupportPriority.normal,
    String? relatedReference,
    String? idempotencyKey,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'support.create_ticket',
      method: 'POST',
      path: '/v1/support/tickets',
      idempotencyKey: idempotencyKey,
      body: {
        'owner_role': role.supportWireValue,
        'category': category.wireValue,
        'subject': subject.trim(),
        'description': description.trim(),
        'priority': priority.wireValue,
        if (relatedReference?.trim().isNotEmpty ?? false)
          'related_reference': relatedReference!.trim(),
      },
    ),
    SupportTicket.fromJson,
  )).value;

  @override
  Future<SupportTicket> addMessage({
    required String ticketId,
    required String body,
    String? idempotencyKey,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'support.add_ticket_message',
      method: 'POST',
      path: '/v1/support/tickets/${Uri.encodeComponent(ticketId)}/messages',
      idempotencyKey: idempotencyKey,
      body: {'body': body.trim()},
    ),
    SupportTicket.fromJson,
  )).value;
}

enum SupportViewStatus { idle, loading, ready, saving, offline, failure }

final class SupportState {
  const SupportState({
    this.status = SupportViewStatus.idle,
    this.tickets = const [],
    this.selected,
    this.message,
  });

  final SupportViewStatus status;
  final List<SupportTicket> tickets;
  final SupportTicket? selected;
  final String? message;
  bool get busy =>
      status == SupportViewStatus.loading || status == SupportViewStatus.saving;
}

final class SupportController extends ChangeNotifier {
  SupportController({required this.role, required SupportRemote remote})
    : _remote = remote;

  final AppRole role;
  final SupportRemote _remote;
  SupportState _state = const SupportState();
  SupportState get state => _state;

  Future<void> load() async {
    if (_state.busy) return;
    _set(
      SupportState(status: SupportViewStatus.loading, tickets: _state.tickets),
    );
    try {
      final page = await _remote.list(role);
      if (page.items.any((ticket) => ticket.ownerRole != role)) {
        throw const FormatException('Support tickets crossed a role boundary.');
      }
      _set(SupportState(status: SupportViewStatus.ready, tickets: page.items));
    } on ApiTransportFailure {
      _unavailable(
        SupportViewStatus.offline,
        'Reconnect to load support tickets.',
      );
    } on ApiTimeoutFailure {
      _unavailable(
        SupportViewStatus.offline,
        'Support timed out. Check your connection.',
      );
    } catch (_) {
      _unavailable(
        SupportViewStatus.failure,
        'Support tickets could not be loaded safely.',
      );
    }
  }

  Future<SupportTicket?> create({
    required SupportCategory category,
    required String subject,
    required String description,
    SupportPriority priority = SupportPriority.normal,
    String? relatedReference,
  }) async {
    if (_state.busy) return null;
    _set(
      SupportState(status: SupportViewStatus.saving, tickets: _state.tickets),
    );
    try {
      final ticket = await _remote.create(
        role: role,
        category: category,
        subject: subject,
        description: description,
        priority: priority,
        relatedReference: relatedReference,
      );
      _requireRole(ticket);
      final tickets = [
        ticket,
        ..._state.tickets.where((item) => item.id != ticket.id),
      ];
      _set(
        SupportState(
          status: SupportViewStatus.ready,
          tickets: List.unmodifiable(tickets),
          selected: ticket,
          message: 'Support ticket created.',
        ),
      );
      return ticket;
    } catch (_) {
      _unavailable(
        SupportViewStatus.failure,
        'The support ticket could not be created.',
      );
      return null;
    }
  }

  Future<void> select(String ticketId) async {
    if (_state.busy) return;
    _set(
      SupportState(
        status: SupportViewStatus.loading,
        tickets: _state.tickets,
        selected: _state.selected,
      ),
    );
    try {
      final ticket = await _remote.get(ticketId);
      _requireRole(ticket);
      _replace(ticket, message: null);
    } catch (_) {
      _unavailable(
        SupportViewStatus.failure,
        'The support ticket could not be opened.',
      );
    }
  }

  void closeTicket() {
    _set(
      SupportState(status: SupportViewStatus.ready, tickets: _state.tickets),
    );
  }

  Future<bool> send(String body) async {
    final current = _state.selected;
    if (current == null || _state.busy || body.trim().isEmpty) return false;
    _set(
      SupportState(
        status: SupportViewStatus.saving,
        tickets: _state.tickets,
        selected: current,
      ),
    );
    try {
      final updated = await _remote.addMessage(
        ticketId: current.id,
        body: body,
      );
      _requireRole(updated);
      if (updated.id != current.id ||
          updated.messages.length < current.messages.length) {
        throw const FormatException(
          'Support message response is inconsistent.',
        );
      }
      _replace(updated, message: 'Message sent.');
      return true;
    } catch (_) {
      _set(
        SupportState(
          status: SupportViewStatus.failure,
          tickets: _state.tickets,
          selected: current,
          message: 'The message could not be sent. Try again.',
        ),
      );
      return false;
    }
  }

  void _requireRole(SupportTicket ticket) {
    if (ticket.ownerRole != role) {
      throw const FormatException('Support ticket crossed a role boundary.');
    }
  }

  void _replace(SupportTicket ticket, {required String? message}) {
    final tickets = [
      for (final item in _state.tickets)
        if (item.id == ticket.id) ticket else item,
    ];
    if (!tickets.any((item) => item.id == ticket.id)) tickets.insert(0, ticket);
    _set(
      SupportState(
        status: SupportViewStatus.ready,
        tickets: List.unmodifiable(tickets),
        selected: ticket,
        message: message,
      ),
    );
  }

  void _unavailable(SupportViewStatus status, String message) {
    _set(
      SupportState(
        status: status,
        tickets: _state.tickets,
        selected: _state.selected,
        message: message,
      ),
    );
  }

  void _set(SupportState value) {
    _state = value;
    notifyListeners();
  }
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}

String _identifier(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !RegExp(r'^[A-Za-z0-9._:@/-]+$').hasMatch(value)) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

String? _optionalIdentifier(Map<String, Object?> json, String key) {
  if (json[key] == null) return null;
  return _identifier(json, key);
}

String _text(Map<String, Object?> json, String key, {required int maximum}) {
  final value = json[key];
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > maximum ||
      value.contains('\u0000')) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

String? _optionalText(
  Map<String, Object?> json,
  String key, {
  required int maximum,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty || value.length > maximum) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

DateTime _instant(Map<String, Object?> json, String key) {
  final value = DateTime.tryParse(json[key] as String? ?? '');
  if (value == null || !value.isUtc) throw FormatException('$key is invalid.');
  return value;
}

AppRole _role(Object? value) {
  for (final role in AppRole.values) {
    if (role.supportWireValue == value) return role;
  }
  throw const FormatException('Support owner role is invalid.');
}

T _enumValue<T>(
  Iterable<T> values,
  Object? wire,
  String Function(T) encode,
  String label,
) {
  for (final value in values) {
    if (encode(value) == wire) return value;
  }
  throw FormatException('$label is invalid.');
}

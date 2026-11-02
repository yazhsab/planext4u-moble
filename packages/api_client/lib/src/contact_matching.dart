import 'cancellation.dart';
import 'client.dart';
import 'request.dart';

final class ContactMatchingState {
  const ContactMatchingState({
    required this.status,
    required this.policyVersion,
    required this.revision,
    required this.contactCount,
    required this.maxContacts,
    this.expiresAt,
  });
  final String status;
  final String policyVersion;
  final int revision;
  final int contactCount;
  final int maxContacts;
  final DateTime? expiresAt;
  bool get ready => status == 'READY';
  factory ContactMatchingState.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Contact state is invalid.');
    }
    final status = value['status'];
    final revision = value['revision'];
    final count = value['contact_count'];
    final maximum = value['max_contacts'];
    final policy = value['policy_version'] ?? '';
    final expiry = value['expires_at'];
    final parsed = expiry is String ? DateTime.tryParse(expiry) : null;
    if (!const {
          'UNAVAILABLE',
          'CONSENT_REQUIRED',
          'EMPTY',
          'SYNC_REQUIRED',
          'READY',
        }.contains(status) ||
        revision is! int ||
        revision < 0 ||
        count is! int ||
        count < 0 ||
        maximum is! int ||
        maximum < 0 ||
        maximum > 10000 ||
        count > maximum ||
        policy is! String ||
        policy.length > 64 ||
        (expiry != null && (parsed == null || !parsed.isUtc)) ||
        (status == 'READY' && (parsed == null || policy.isEmpty))) {
      throw const FormatException('Contact state contract is invalid.');
    }
    return ContactMatchingState(
      status: status as String,
      policyVersion: policy,
      revision: revision,
      contactCount: count,
      maxContacts: maximum,
      expiresAt: parsed,
    );
  }
}

final class ContactMatch {
  const ContactMatch({required this.identityId, required this.displayName});
  final String identityId;
  final String displayName;
}

final class ContactMatchPage {
  const ContactMatchPage({
    required this.revision,
    required this.items,
    this.nextCursor,
  });
  final int revision;
  final List<ContactMatch> items;
  final String? nextCursor;
  factory ContactMatchPage.fromJson(Object? value) {
    final identifier = RegExp(r'^[A-Za-z0-9._:-]{1,128}$');
    if (value is! Map<String, Object?> ||
        value['snapshot_revision'] is! int ||
        (value['snapshot_revision'] as int) < 1 ||
        value['items'] is! List) {
      throw const FormatException('Contact matches are invalid.');
    }
    final rows = value['items'] as List;
    if (rows.length > 50) {
      throw const FormatException('Contact page is too large.');
    }
    final items = <ContactMatch>[];
    for (final row in rows) {
      if (row is! Map<String, Object?> ||
          row['identity_id'] is! String ||
          !identifier.hasMatch(row['identity_id'] as String) ||
          row['display_name'] is! String ||
          (row['display_name'] as String).length > 100 ||
          row.length != 2) {
        throw const FormatException('Contact match row is invalid.');
      }
      items.add(
        ContactMatch(
          identityId: row['identity_id'] as String,
          displayName: row['display_name'] as String,
        ),
      );
    }
    final cursor = value['next_cursor'];
    if (cursor != null && (cursor is! String || !identifier.hasMatch(cursor))) {
      throw const FormatException('Contact cursor is invalid.');
    }
    return ContactMatchPage(
      revision: value['snapshot_revision'] as int,
      items: List.unmodifiable(items),
      nextCursor: cursor as String?,
    );
  }
}

/// Owner scope is the authenticated ApiClient. Raw address-book numbers and
/// provider tokens are sent only by an explicit UI action; neither is cached.
final class ContactMatchingApi {
  ContactMatchingApi(this._client);
  final ApiClient _client;
  final Set<ApiCancellationToken> _operations = {};
  bool _disposed = false;
  bool get isActive => !_disposed;
  void dispose() {
    _disposed = true;
    for (final operation in _operations.toList()) {
      operation.cancel();
    }
  }

  Future<T> _send<T>(ApiRequest request, T Function(Object?) decode) async {
    if (_disposed) throw StateError('Contact matching scope ended.');
    final token = ApiCancellationToken();
    _operations.add(token);
    try {
      final response = await _client.send(
        request,
        decode,
        cancellationToken: token,
      );
      if (_disposed) throw StateError('Contact matching scope ended.');
      return response.value;
    } finally {
      _operations.remove(token);
    }
  }

  Future<ContactMatchingState> state() => _send(
    ApiRequest.get(
      operation: 'identity.contact_state',
      path: '/v1/me/contact-matching',
    ),
    ContactMatchingState.fromJson,
  );
  Future<ContactMatchingState> sync({
    required String providerToken,
    required String policyVersion,
    required int expectedRevision,
    required List<String> phones,
  }) {
    if (providerToken.length < 8 ||
        providerToken.length > 8192 ||
        policyVersion.isEmpty ||
        policyVersion.length > 64 ||
        expectedRevision < 0 ||
        phones.length > 10000 ||
        phones.any(
          (phone) => !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone),
        )) {
      throw const FormatException('Contact upload is invalid.');
    }
    return _send(
      ApiRequest.command(
        operation: 'identity.contact_sync',
        method: 'PUT',
        path: '/v1/me/contact-matching',
        body: {
          'provider_token': providerToken,
          'policy_version': policyVersion,
          'expected_revision': expectedRevision,
          'phones': phones,
        },
      ),
      ContactMatchingState.fromJson,
    );
  }

  Future<ContactMatchPage> matches({
    required int revision,
    String? cursor,
    int limit = 50,
  }) async {
    final identifier = RegExp(r'^[A-Za-z0-9._:-]{1,128}$');
    if (revision < 1 ||
        limit < 1 ||
        limit > 50 ||
        (cursor != null && !identifier.hasMatch(cursor))) {
      throw const FormatException('Contact page request is invalid.');
    }
    final query = <String, List<String>>{
      'revision': [revision.toString()],
      'limit': [limit.toString()],
      if (cursor != null) 'cursor': [cursor],
    };
    final page = await _send(
      ApiRequest.get(
        operation: 'identity.contact_matches',
        path: '/v1/me/contact-matching/matches',
        query: query,
      ),
      ContactMatchPage.fromJson,
    );
    if (page.revision != revision) {
      throw const FormatException('Contact revision changed.');
    }
    return page;
  }
}

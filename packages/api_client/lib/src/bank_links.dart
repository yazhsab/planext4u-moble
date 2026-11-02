import 'cancellation.dart';
import 'client.dart';
import 'failures.dart';
import 'request.dart';

final class VerifiedBankAccount {
  const VerifiedBankAccount({
    required this.reference,
    required this.holderName,
    required this.last4,
    required this.ifsc,
  });
  final String reference;
  final String holderName;
  final String last4;
  final String ifsc;
}

/// Transient owner response. Hosted URLs and masked results are deliberately
/// not serializable into device progress; recovery reads the owning service.
final class HostedBankLink {
  const HostedBankLink({
    required this.attemptId,
    required this.status,
    required this.expiresAt,
    this.launchUrl,
    this.account,
  });
  final String attemptId;
  final String status;
  final DateTime expiresAt;
  final Uri? launchUrl;
  final VerifiedBankAccount? account;
  bool get terminal =>
      const {'CANCELLED', 'DECLINED', 'EXPIRED'}.contains(status);
}

/// Bind to the authenticated tenant/country/account ApiClient. Dispose when
/// that scope ends; late results cannot cross into a replacement account.
final class HostedBankLinkClient {
  HostedBankLinkClient({
    required ApiClient client,
    required String applicationRole,
    required Set<Uri> allowedOrigins,
    bool allowDevelopmentHttp = false,
    DateTime Function()? clock,
  }) : _client = client,
       _role = applicationRole,
       _clock = clock ?? DateTime.now,
       _origins = allowedOrigins.map((uri) {
         if (!_safeUrl(uri, allowDevelopmentHttp) ||
             uri.path.isNotEmpty ||
             uri.hasQuery) {
           throw const FormatException('Bank launch origin is invalid.');
         }
         return uri.origin;
       }).toSet() {
    if (!const {'vendor', 'rider'}.contains(_role) ||
        _origins.isEmpty ||
        _origins.length > 8) {
      throw const FormatException('Bank link configuration is invalid.');
    }
  }

  final ApiClient _client;
  final String _role;
  final Set<String> _origins;
  final DateTime Function() _clock;
  final Set<ApiCancellationToken> _operations = {};
  bool _disposed = false;
  bool get isActive => !_disposed;
  String get _prefix => '/v1/$_role/bank-links';

  void dispose() {
    _disposed = true;
    for (final token in _operations.toList()) {
      token.cancel();
    }
  }

  Future<HostedBankLink?> current() async {
    try {
      return await _send(
        ApiRequest.get(
          operation: 'bank_links.current',
          path: '$_prefix/current',
        ),
        launchRequired: false,
      );
    } on ApiFailure catch (error) {
      if (error.statusCode == 404 && error.code == 'BANK_LINK_NOT_FOUND') {
        return null;
      }
      rethrow;
    }
  }

  Future<HostedBankLink> start() => _send(
    ApiRequest.command(
      operation: 'bank_links.start',
      method: 'POST',
      path: _prefix,
      body: const <String, Object?>{},
    ),
  );

  Future<HostedBankLink> resume(String attemptId) {
    _validateId(attemptId);
    return _send(
      ApiRequest.command(
        operation: 'bank_links.resume',
        method: 'POST',
        path: '$_prefix/$attemptId/resume',
        body: const <String, Object?>{},
      ),
      expectedId: attemptId,
    );
  }

  Future<HostedBankLink> cancel(String attemptId) {
    _validateId(attemptId);
    return _send(
      ApiRequest.command(
        operation: 'bank_links.cancel',
        method: 'DELETE',
        path: '$_prefix/$attemptId',
        body: null,
      ),
      expectedId: attemptId,
    );
  }

  Future<HostedBankLink> _send(
    ApiRequest request, {
    String? expectedId,
    bool launchRequired = true,
  }) async {
    if (_disposed) throw const TransportCancelledException();
    final token = ApiCancellationToken();
    _operations.add(token);
    try {
      final response = await _client.send(
        request,
        (value) => _decode(value, expectedId, launchRequired),
        cancellationToken: token,
      );
      if (_disposed || token.isCancelled) {
        throw const TransportCancelledException();
      }
      return response.value;
    } finally {
      _operations.remove(token);
    }
  }

  HostedBankLink _decode(
    Object? value,
    String? expectedId,
    bool launchRequired,
  ) {
    const fields = {
      'attempt_id',
      'application_role',
      'status',
      'expires_at',
      'launch_url',
      'account',
    };
    if (value is! Map<String, Object?> ||
        value.keys.any((key) => !fields.contains(key)) ||
        value['application_role'] != _role.toUpperCase() ||
        value['attempt_id'] is! String ||
        value['status'] is! String ||
        value['expires_at'] is! String) {
      throw const FormatException('Bank link response is invalid.');
    }
    final id = value['attempt_id']! as String;
    _validateId(id);
    if (expectedId != null && id != expectedId) {
      throw const FormatException('Bank link changed.');
    }
    final status = value['status']! as String;
    final expiry = DateTime.tryParse(value['expires_at']! as String);
    final now = _clock().toUtc();
    if (!const {
          'CREATING',
          'AWAITING_USER',
          'VERIFYING',
          'VERIFIED',
          'DECLINED',
          'CANCELLED',
          'EXPIRED',
        }.contains(status) ||
        expiry == null ||
        !expiry.isUtc ||
        expiry.isAfter(now.add(const Duration(minutes: 30))) ||
        (status != 'EXPIRED' && !expiry.isAfter(now)) ||
        (status == 'EXPIRED' && expiry.isAfter(now))) {
      throw const FormatException('Bank link status or expiry is invalid.');
    }
    Uri? launch;
    if (value.containsKey('launch_url')) {
      final raw = value['launch_url'];
      if (raw is! String || raw.length > 4096) {
        throw const FormatException('Bank launch URL is invalid.');
      }
      launch = Uri.tryParse(raw);
      if (launch == null ||
          !_safeUrl(launch, true) ||
          !_origins.contains(launch.origin) ||
          launch.path.isEmpty ||
          status != 'AWAITING_USER') {
        throw const FormatException('Bank launch URL is not approved.');
      }
    }
    if (launchRequired && status == 'AWAITING_USER' && launch == null) {
      throw const FormatException('Bank launch URL is missing.');
    }
    VerifiedBankAccount? account;
    if (status == 'VERIFIED') {
      final masked = value['account'];
      if (masked is! Map<String, Object?> ||
          masked.keys.any(
            (key) => !const {
              'reference',
              'holder_name',
              'last4',
              'ifsc',
            }.contains(key),
          ) ||
          masked['reference'] is! String ||
          !_reference.hasMatch(masked['reference']! as String) ||
          masked['holder_name'] is! String ||
          (masked['holder_name']! as String).trim().length < 3 ||
          (masked['holder_name']! as String).length > 200 ||
          masked['last4'] is! String ||
          !RegExp(r'^[0-9]{4}$').hasMatch(masked['last4']! as String) ||
          (masked['ifsc'] != null &&
              (masked['ifsc'] is! String ||
                  (masked['ifsc']! as String).length > 32))) {
        throw const FormatException(
          'Verified masked bank details are invalid.',
        );
      }
      account = VerifiedBankAccount(
        reference: masked['reference']! as String,
        holderName: masked['holder_name']! as String,
        last4: masked['last4']! as String,
        ifsc: masked['ifsc'] as String? ?? '',
      );
      if (RegExp(
        r'[\x00-\x1f\x7f]',
      ).hasMatch(account.holderName + account.ifsc)) {
        throw const FormatException(
          'Masked bank details contain invalid text.',
        );
      }
    } else if (value.containsKey('account')) {
      throw const FormatException('Unverified bank details were returned.');
    }
    return HostedBankLink(
      attemptId: id,
      status: status,
      expiresAt: expiry,
      launchUrl: launch,
      account: account,
    );
  }

  static final _uuid = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
  );
  static final _reference = RegExp(r'^bankref_[A-Za-z0-9_-]{8,100}$');
  static void _validateId(String id) {
    if (!_uuid.hasMatch(id) || id == '00000000-0000-0000-0000-000000000000') {
      throw const FormatException('Bank link ID is invalid.');
    }
  }

  static bool _safeUrl(Uri uri, bool allowDevelopmentHttp) =>
      uri.hasAuthority &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      !uri.toString().contains(r'\') &&
      (uri.scheme == 'https' ||
          (allowDevelopmentHttp &&
              uri.scheme == 'http' &&
              const {
                'localhost',
                '127.0.0.1',
                '10.0.2.2',
                '::1',
              }.contains(uri.host)));
}

import 'package:planext4u_core/planext4u_core.dart';

enum IdentityProviderKind {
  firebase('firebase'),
  oidc('oidc'),
  local('local');

  const IdentityProviderKind(this.wireValue);
  final String wireValue;
}

final class ProviderAssertion {
  ProviderAssertion({required this.provider, required this.token}) {
    if (token.length < 8 || token.length > 8192) {
      throw const FormatException('Provider assertion is invalid.');
    }
  }

  final IdentityProviderKind provider;
  final String token;
}

final class IdentityTokens {
  const IdentityTokens({
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  factory IdentityTokens.fromJson(Object? value) {
    final json = _object(value, 'tokens');
    if (json['token_type'] != 'Bearer') {
      throw const FormatException('Unsupported token type.');
    }
    final result = IdentityTokens(
      accessToken: _string(json, 'access_token'),
      accessExpiresAt: _instant(json, 'access_expires_at'),
      refreshToken: _string(json, 'refresh_token'),
      refreshExpiresAt: _instant(json, 'refresh_expires_at'),
    );
    if (result.accessToken.isEmpty || result.refreshToken.length < 8) {
      throw const FormatException('Authentication tokens are invalid.');
    }
    return result;
  }

  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;

  Map<String, Object> toJson() => {
    'access_token': accessToken,
    'access_expires_at': accessExpiresAt.toUtc().toIso8601String(),
    'refresh_token': refreshToken,
    'refresh_expires_at': refreshExpiresAt.toUtc().toIso8601String(),
    'token_type': 'Bearer',
  };
}

final class IdentityProfile {
  const IdentityProfile({
    required this.displayName,
    required this.locale,
    required this.timeZone,
    required this.version,
    required this.updatedAt,
    this.email,
    this.phone,
  });

  factory IdentityProfile.fromJson(Object? value) {
    final json = _object(value, 'profile');
    final displayName = json['display_name'];
    final locale = _string(json, 'locale');
    final version = _integer(json, 'version');
    final email = _optionalString(json, 'email');
    final phone = _optionalString(json, 'phone');
    if (displayName is! String ||
        displayName.length > 100 ||
        !isPlanext4uLocaleCode(locale) ||
        version < 1 ||
        (email != null &&
            (email.length > 254 ||
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) ||
        (phone != null && !RegExp(r'^\+[1-9][0-9]{7,15}$').hasMatch(phone))) {
      throw const FormatException('Profile contract is invalid.');
    }
    return IdentityProfile(
      displayName: displayName,
      email: email,
      phone: phone,
      locale: locale,
      timeZone: _string(json, 'time_zone'),
      version: version,
      updatedAt: _instant(json, 'updated_at'),
    );
  }

  final String displayName;
  final String? email;
  final String? phone;
  final String locale;
  final String timeZone;
  final int version;
  final DateTime updatedAt;

  Map<String, Object> toJson() => {
    'display_name': displayName,
    'email': ?email,
    'phone': ?phone,
    'locale': locale,
    'time_zone': timeZone,
    'version': version,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

final class CurrentIdentityProfile {
  const CurrentIdentityProfile({
    required this.identityId,
    required this.tenantId,
    required this.country,
    required this.roles,
    required this.profile,
  });

  factory CurrentIdentityProfile.fromJson(Object? value) {
    final json = _object(value, 'current profile');
    final rolesValue = json['roles'];
    if (rolesValue is! List<Object?> || rolesValue.isEmpty) {
      throw const FormatException('Current profile roles are invalid.');
    }
    final roles = rolesValue.map(_roleFromWire).toSet();
    if (roles.length != rolesValue.length) {
      throw const FormatException('Current profile roles are invalid.');
    }
    return CurrentIdentityProfile(
      identityId: _string(json, 'id'),
      tenantId: _string(json, 'tenant_id'),
      country: _country(json, 'country'),
      roles: Set.unmodifiable(roles),
      profile: IdentityProfile.fromJson(json['profile']),
    );
  }

  final String identityId;
  final String tenantId;
  final String country;
  final Set<AppRole> roles;
  final IdentityProfile profile;
}

final class IdentityDeviceSession {
  const IdentityDeviceSession({
    required this.id,
    required this.deviceReference,
    required this.country,
    required this.authenticatedAt,
    required this.lastSeenAt,
    required this.expiresAt,
    required this.current,
    this.revokedAt,
  });

  factory IdentityDeviceSession.fromJson(Object? value) {
    final json = _object(value, 'session');
    return IdentityDeviceSession(
      id: _string(json, 'id'),
      deviceReference: _string(json, 'device_reference'),
      country: _country(json, 'country'),
      authenticatedAt: _instant(json, 'authenticated_at'),
      lastSeenAt: _instant(json, 'last_seen_at'),
      expiresAt: _instant(json, 'expires_at'),
      revokedAt: json['revoked_at'] == null
          ? null
          : _instant(json, 'revoked_at'),
      current: _boolean(json, 'current'),
    );
  }

  final String id;
  final String deviceReference;
  final String country;
  final DateTime authenticatedAt;
  final DateTime lastSeenAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final bool current;

  Map<String, Object?> toJson() => {
    'id': id,
    'device_reference': deviceReference,
    'country': country,
    'authenticated_at': authenticatedAt.toUtc().toIso8601String(),
    'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
    if (revokedAt != null) 'revoked_at': revokedAt!.toUtc().toIso8601String(),
    'current': current,
  };
}

final class IdentityAuthentication {
  const IdentityAuthentication({
    required this.identityId,
    required this.tenantId,
    required this.country,
    required this.tokens,
    required this.profile,
    required this.roles,
    required this.session,
  });

  factory IdentityAuthentication.fromJson(Object? value) {
    final json = _object(value, 'authentication');
    final rolesValue = json['roles'];
    if (rolesValue is! List<Object?> || rolesValue.isEmpty) {
      throw const FormatException('Authentication roles are invalid.');
    }
    final roles = rolesValue.map(_roleFromWire).toSet();
    if (roles.length != rolesValue.length) {
      throw const FormatException('Authentication roles are invalid.');
    }
    return IdentityAuthentication(
      identityId: _string(json, 'identity_id'),
      tenantId: _string(json, 'tenant_id'),
      country: _country(json, 'country'),
      tokens: IdentityTokens.fromJson(json['tokens']),
      profile: IdentityProfile.fromJson(json['profile']),
      roles: Set.unmodifiable(roles),
      session: IdentityDeviceSession.fromJson(json['session']),
    );
  }

  final String identityId;
  final String tenantId;
  final String country;
  final IdentityTokens tokens;
  final IdentityProfile profile;
  final Set<AppRole> roles;
  final IdentityDeviceSession session;

  Map<String, Object> toJson() => {
    'identity_id': identityId,
    'tenant_id': tenantId,
    'country': country,
    'tokens': tokens.toJson(),
    'profile': profile.toJson(),
    'roles': roles.map(_roleToWire).toList(growable: false)..sort(),
    'session': session.toJson(),
  };
}

AppRole _roleFromWire(Object? value) => switch (value) {
  'CUSTOMER' => AppRole.customer,
  'VENDOR' => AppRole.vendor,
  'RIDER' => AppRole.rider,
  _ => throw const FormatException('Unsupported mobile role.'),
};

String _roleToWire(AppRole role) => switch (role) {
  AppRole.customer => 'CUSTOMER',
  AppRole.vendor => 'VENDOR',
  AppRole.rider => 'RIDER',
};

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string when supplied.');
  }
  return value;
}

String _country(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(value)) {
    throw FormatException('$key must be an ISO country code.');
  }
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

DateTime _instant(Map<String, Object?> json, String key) {
  final parsed = DateTime.tryParse(_string(json, key));
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$key must be a UTC date-time.');
  }
  return parsed;
}

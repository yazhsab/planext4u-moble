import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/src/role_bound_session.dart';

void main() {
  test(
    'old rider cannot retry with another account or country token',
    () async {
      var current = 'tenant-a:IN:rider-a:session-a';
      final delegate = _Session();
      final bound = RoleBoundApiSession(
        delegate: delegate,
        expectedScope: current,
        currentScope: () => current,
      );
      final pending = bound.accessToken();
      current = 'tenant-a:IN:rider-b:session-b';
      delegate.token.complete('rider-b-token');
      expect(await pending, isNull);
      expect(await bound.accessToken(), isNull);
      expect(await bound.refresh(), isFalse);
      expect(delegate.refreshes, 0);
    },
  );
}

final class _Session implements ApiAuthSession {
  final token = Completer<String?>();
  int refreshes = 0;
  @override
  Future<String?> accessToken() => token.future;
  @override
  Future<bool> refresh() async {
    refreshes++;
    return true;
  }
}

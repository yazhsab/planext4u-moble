import 'package:planext4u_api_client/planext4u_api_client.dart';

/// An old controller must never retry a command with a newly signed-in rider's
/// credentials. Check both before and after asynchronous token/refresh work.
final class RoleBoundApiSession implements ApiAuthSession {
  RoleBoundApiSession({
    required this.delegate,
    required this.expectedScope,
    required this.currentScope,
  });
  final ApiAuthSession delegate;
  final String expectedScope;
  final String? Function() currentScope;

  @override
  Future<String?> accessToken() async {
    if (currentScope() != expectedScope) return null;
    final token = await delegate.accessToken();
    return currentScope() == expectedScope ? token : null;
  }

  @override
  Future<bool> refresh() async {
    if (currentScope() != expectedScope) return false;
    final refreshed = await delegate.refresh();
    return currentScope() == expectedScope && refreshed;
  }
}

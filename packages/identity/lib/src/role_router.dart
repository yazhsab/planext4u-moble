import 'package:planext4u_core/planext4u_core.dart';

enum RoleRouteOutcome { allowed, wrongApplication, unsupported }

final class RoleRouteDecision {
  const RoleRouteDecision({required this.outcome, this.suggestedRole});

  final RoleRouteOutcome outcome;
  final AppRole? suggestedRole;

  bool get isAllowed => outcome == RoleRouteOutcome.allowed;
}

abstract final class IdentityRoleRouter {
  static RoleRouteDecision decide({
    required AppRole applicationRole,
    required Set<AppRole> grantedRoles,
  }) {
    if (grantedRoles.contains(applicationRole)) {
      return const RoleRouteDecision(outcome: RoleRouteOutcome.allowed);
    }
    if (grantedRoles.isEmpty) {
      return const RoleRouteDecision(outcome: RoleRouteOutcome.unsupported);
    }
    return RoleRouteDecision(
      outcome: RoleRouteOutcome.wrongApplication,
      suggestedRole: AppRole.values.firstWhere(grantedRoles.contains),
    );
  }
}

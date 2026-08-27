import 'package:flutter/material.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  runApp(RiderApp(config: AppConfig.fromCompileTime()));
}

class RiderApp extends StatelessWidget {
  const RiderApp({
    required this.config,
    this.grantedRoles = const {AppRole.rider},
    this.capabilities = const {
      RoleCapability.riderDuty,
      RoleCapability.profile,
    },
    this.featureFlags = const {},
    super.key,
  });

  final AppConfig config;
  final Set<AppRole> grantedRoles;
  final Set<RoleCapability> capabilities;
  final Map<String, bool> featureFlags;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Planext4u Rider',
      theme: Planext4uTheme.light,
      darkTheme: Planext4uTheme.dark,
      home: AuthenticatedRoleShell(
        applicationRole: AppRole.rider,
        grantedRoles: grantedRoles,
        capabilities: capabilities,
        featureFlags: featureFlags,
        environmentLabel: config.environmentLabel,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

void main() {
  runApp(CustomerApp(config: AppConfig.fromCompileTime()));
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Planext4uFoundationApp(
      role: AppRole.customer,
      environmentLabel: config.environmentLabel,
    );
  }
}

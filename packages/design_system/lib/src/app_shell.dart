import 'package:flutter/material.dart';
import 'package:planext4u_core/planext4u_core.dart';

import 'theme.dart';
import 'tokens.dart';

/// Minimal, production-shaped shell used while Phase 2 features are added.
class Planext4uFoundationApp extends StatelessWidget {
  const Planext4uFoundationApp({
    required this.role,
    required this.environmentLabel,
    super.key,
  });

  final AppRole role;
  final String environmentLabel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Planext4u ${role.label}',
      theme: Planext4uTheme.light,
      darkTheme: Planext4uTheme.dark,
      themeMode: ThemeMode.system,
      home: _FoundationScreen(role: role, environmentLabel: environmentLabel),
    );
  }
}

class _FoundationScreen extends StatelessWidget {
  const _FoundationScreen({required this.role, required this.environmentLabel});

  final AppRole role;
  final String environmentLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planext4u'),
        actions: [
          Semantics(
            label: 'Build environment: $environmentLabel',
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Planext4uSpacing.x4,
              ),
              child: Center(
                child: Text(
                  environmentLabel.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Planext4uColors.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Planext4uSpacing.x4),
              children: [
                Text(
                  '${role.label} application',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Planext4uColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Planext4uSpacing.x2),
                Text(role.description),
                const SizedBox(height: Planext4uSpacing.x6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Planext4uSpacing.x5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phase 2 foundation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: Planext4uSpacing.x2),
                        const Text(
                          'Shared workspace, typed configuration, accessible '
                          'themes, and role-safe application boundaries are ready.',
                        ),
                        const SizedBox(height: Planext4uSpacing.x4),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              color: Planext4uColors.success,
                            ),
                            const SizedBox(width: Planext4uSpacing.x2),
                            Expanded(
                              child: Text(
                                '${role.label} shell ready',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

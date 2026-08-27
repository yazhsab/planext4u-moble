import 'package:flutter/material.dart';

import 'components.dart';
import 'tokens.dart';

class Planext4uWidgetCatalogue extends StatelessWidget {
  const Planext4uWidgetCatalogue({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planext4u components')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tablet = constraints.maxWidth >= Planext4uBreakpoints.tablet;
            final usableWidth =
                constraints.maxWidth - (Planext4uSpacing.x4 * 2);
            final contentWidth = tablet
                ? (usableWidth - Planext4uSpacing.x4) / 2
                : usableWidth;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(Planext4uSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shared widget catalogue',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  const Text(
                    'Accessible, role-neutral components with synthetic content. '
                    'நீண்ட தமிழ் உரையிலும் செயல்கள் தெளிவாக இருக்க வேண்டும்.',
                  ),
                  const SizedBox(height: Planext4uSpacing.x6),
                  Wrap(
                    spacing: Planext4uSpacing.x4,
                    runSpacing: Planext4uSpacing.x4,
                    children: [
                      SizedBox(
                        width: contentWidth,
                        child: const _ActionsSection(),
                      ),
                      SizedBox(
                        width: contentWidth,
                        child: const _InputsSection(),
                      ),
                      SizedBox(
                        width: contentWidth,
                        child: const _StatusSection(),
                      ),
                      SizedBox(
                        width: contentWidth,
                        child: const Planext4uMetricCard(
                          label: 'Orders today',
                          value: '128',
                          freshness: 'Updated 2 minutes ago',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                      SizedBox(
                        width: contentWidth,
                        child: Planext4uProductCard(
                          name: 'Synthetic essentials basket',
                          vendor: 'Demo neighbourhood store',
                          price: '₹1,249.00',
                          status: 'In stock',
                          onPressed: () {},
                        ),
                      ),
                      SizedBox(
                        width: contentWidth,
                        child: Planext4uStatePanel(
                          state: Planext4uViewState.offline,
                          title: 'Showing saved information',
                          message:
                              'Reconnect to refresh availability and prices.',
                          actionLabel: 'Try again',
                          onAction: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection();

  @override
  Widget build(BuildContext context) {
    return Planext4uSectionCard(
      title: 'Actions',
      subtitle: 'Every action preserves a minimum 48 px target.',
      child: Wrap(
        spacing: Planext4uSpacing.x2,
        runSpacing: Planext4uSpacing.x2,
        children: [
          Planext4uButton(label: 'Continue', onPressed: () {}),
          Planext4uButton(
            label: 'Save for later',
            kind: Planext4uButtonKind.secondary,
            onPressed: () {},
          ),
          Planext4uButton(
            label: 'Learn more',
            kind: Planext4uButtonKind.tertiary,
            onPressed: () {},
          ),
          Planext4uButton(
            label: 'Remove',
            icon: Icons.delete_outline,
            kind: Planext4uButtonKind.destructive,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _InputsSection extends StatelessWidget {
  const _InputsSection();

  @override
  Widget build(BuildContext context) {
    return const Planext4uSectionCard(
      title: 'Input',
      subtitle: 'Labels remain visible and errors are announced.',
      child: Planext4uTextField(
        label: 'Search Planext4u',
        hint: 'Products, services, food and homes',
        helper: 'Try a category or vendor name',
        prefixIcon: Icons.search,
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection();

  @override
  Widget build(BuildContext context) {
    return const Planext4uSectionCard(
      title: 'Status',
      subtitle: 'Icons and text supplement semantic colour.',
      child: Wrap(
        spacing: Planext4uSpacing.x2,
        runSpacing: Planext4uSpacing.x2,
        children: [
          Planext4uStatusPill(
            label: 'Verified',
            tone: Planext4uStatusTone.success,
          ),
          Planext4uStatusPill(
            label: 'Pending',
            tone: Planext4uStatusTone.warning,
          ),
          Planext4uStatusPill(
            label: 'Needs attention',
            tone: Planext4uStatusTone.danger,
          ),
        ],
      ),
    );
  }
}

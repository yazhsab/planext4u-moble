import 'package:flutter/material.dart';

import 'tokens.dart';

enum Planext4uButtonKind { primary, secondary, tertiary, destructive }

enum Planext4uStatusTone { neutral, info, success, warning, danger }

enum Planext4uViewState { loading, empty, error, offline, permissionDenied }

class Planext4uButton extends StatelessWidget {
  const Planext4uButton({
    required this.label,
    required this.onPressed,
    this.kind = Planext4uButtonKind.primary,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Planext4uButtonKind kind;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: Planext4uSpacing.x2),
              Flexible(child: Text(label)),
            ],
          );
    final button = switch (kind) {
      Planext4uButtonKind.primary => FilledButton(
        onPressed: onPressed,
        child: child,
      ),
      Planext4uButtonKind.secondary => OutlinedButton(
        onPressed: onPressed,
        child: child,
      ),
      Planext4uButtonKind.tertiary => TextButton(
        onPressed: onPressed,
        child: child,
      ),
      Planext4uButtonKind.destructive => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: onPressed,
        child: child,
      ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class Planext4uTextField extends StatelessWidget {
  const Planext4uTextField({
    required this.label,
    this.hint,
    this.helper,
    this.error,
    this.controller,
    this.keyboardType,
    this.enabled = true,
    this.obscureText = false,
    this.prefixIcon,
    super.key,
  });

  final String label;
  final String? hint;
  final String? helper;
  final String? error;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool obscureText;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: error,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );
  }
}

class Planext4uStatusPill extends StatelessWidget {
  const Planext4uStatusPill({
    required this.label,
    required this.tone,
    super.key,
  });

  final String label;
  final Planext4uStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (color, icon) = switch (tone) {
      Planext4uStatusTone.neutral => (theme.colorScheme.outline, Icons.circle),
      Planext4uStatusTone.info => (Planext4uColors.info, Icons.info_outline),
      Planext4uStatusTone.success => (
        Planext4uColors.success,
        Icons.check_circle_outline,
      ),
      Planext4uStatusTone.warning => (
        Planext4uColors.warning,
        Icons.warning_amber_rounded,
      ),
      Planext4uStatusTone.danger => (
        Planext4uColors.danger,
        Icons.error_outline,
      ),
    };
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.24 : 0.12),
          borderRadius: BorderRadius.circular(Planext4uRadii.pill),
          border: Border.all(color: color),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.hasBoundedWidth && constraints.maxWidth < 96;
            final text = Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            );
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? Planext4uSpacing.x2 : Planext4uSpacing.x3,
                vertical: Planext4uSpacing.x2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!compact) ...[
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: Planext4uSpacing.x1),
                  ],
                  if (constraints.hasBoundedWidth)
                    Flexible(child: text)
                  else
                    text,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class Planext4uSectionCard extends StatelessWidget {
  const Planext4uSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: Planext4uSpacing.x1),
                        Text(subtitle!),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: Planext4uSpacing.x4),
            child,
          ],
        ),
      ),
    );
  }
}

class Planext4uSectionHeader extends StatelessWidget {
  const Planext4uSectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle?.isNotEmpty == true) ...[
              const SizedBox(height: Planext4uSpacing.x1),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
      if (actionLabel?.isNotEmpty == true)
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
    ],
  );
}

class Planext4uHorizontalRail extends StatelessWidget {
  const Planext4uHorizontalRail({
    required this.children,
    required this.height,
    this.itemWidth = 224,
    this.semanticLabel,
    super.key,
  });

  final List<Widget> children;
  final double height;
  final double itemWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: semanticLabel,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: children.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: Planext4uSpacing.x3),
          itemBuilder: (_, index) =>
              SizedBox(width: itemWidth, child: children[index]),
        ),
      ),
    );
  }
}

class Planext4uMediaPlaceholder extends StatelessWidget {
  const Planext4uMediaPlaceholder({
    required this.label,
    this.height = 112,
    this.icon = Icons.image_outlined,
    super.key,
  });

  final String label;
  final double height;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: ExcludeSemantics(
      child: Container(
        height: height,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        alignment: Alignment.center,
        child: Icon(icon, size: 40),
      ),
    ),
  );
}

class Planext4uCampaignHero extends StatelessWidget {
  const Planext4uCampaignHero({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.shopping_bag_outlined,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semanticsLabel = title.endsWith('.')
        ? '$title $subtitle'
        : '$title. $subtitle';
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primaryContainer, colors.secondaryContainer],
          ),
          borderRadius: BorderRadius.circular(Planext4uRadii.hero),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Planext4uSpacing.x5),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final accessibleText =
                  MediaQuery.textScalerOf(context).scale(1) >= 1.8;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        (compact
                                ? theme.textTheme.headlineSmall
                                : theme.textTheme.headlineMedium)
                            ?.copyWith(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  if (actionLabel?.isNotEmpty == true) ...[
                    const SizedBox(height: Planext4uSpacing.x4),
                    FilledButton.tonalIcon(
                      onPressed: onAction,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(actionLabel!),
                    ),
                  ],
                ],
              );
              final artwork = DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    compact ? Planext4uSpacing.x3 : Planext4uSpacing.x5,
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 40 : 56,
                    color: colors.primary,
                  ),
                ),
              );
              if (accessibleText && compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    artwork,
                    const SizedBox(height: Planext4uSpacing.x3),
                    copy,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: Planext4uSpacing.x3),
                  artwork,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

final class Planext4uBenefitItem {
  const Planext4uBenefitItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
}

class Planext4uBenefitStrip extends StatelessWidget {
  const Planext4uBenefitStrip({required this.items, super.key});

  final List<Planext4uBenefitItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final largeText = textScale > 1.15;
    final accessibleText = textScale >= 1.8;
    return SizedBox(
      height: accessibleText ? 320 : (largeText ? 176 : 112),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Planext4uSpacing.x2),
        itemBuilder: (context, index) {
          final item = items[index];
          return Semantics(
            container: true,
            button: item.onTap != null,
            label: '${item.title}. ${item.subtitle}',
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: item.onTap,
                child: SizedBox(
                  width: accessibleText ? 232 : 184,
                  child: Padding(
                    padding: const EdgeInsets.all(Planext4uSpacing.x3),
                    child: accessibleText
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                item.icon,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: Planext4uSpacing.x2),
                              _Planext4uBenefitCopy(item: item, maxLines: 4),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                item.icon,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: Planext4uSpacing.x2),
                              Expanded(
                                child: _Planext4uBenefitCopy(
                                  item: item,
                                  maxLines: largeText ? 3 : 2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Planext4uBenefitCopy extends StatelessWidget {
  const _Planext4uBenefitCopy({required this.item, required this.maxLines});

  final Planext4uBenefitItem item;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        item.title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: Planext4uSpacing.x1),
      Text(
        item.subtitle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class Planext4uMetricCard extends StatelessWidget {
  const Planext4uMetricCard({
    required this.label,
    required this.value,
    required this.freshness,
    this.icon = Icons.analytics_outlined,
    super.key,
  });

  final String label;
  final String value;
  final String freshness;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value. $freshness',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Planext4uColors.teal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Planext4uRadii.control),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Planext4uSpacing.x3),
                  child: Icon(icon, color: Planext4uColors.tealDark),
                ),
              ),
              const SizedBox(width: Planext4uSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: Planext4uSpacing.x1),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      freshness,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Planext4uProductCard extends StatelessWidget {
  const Planext4uProductCard({
    required this.name,
    required this.vendor,
    required this.price,
    required this.status,
    this.onPressed,
    this.available = true,
    this.favorite = false,
    this.onFavorite,
    this.onAddToCart,
    super.key,
  });

  final String name;
  final String vendor;
  final String price;
  final String status;
  final VoidCallback? onPressed;
  final bool available;
  final bool favorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final media = Stack(
            children: [
              Planext4uMediaPlaceholder(
                label: 'Product image placeholder for $name',
              ),
              if (onFavorite != null)
                Positioned(
                  top: Planext4uSpacing.x1,
                  right: Planext4uSpacing.x1,
                  child: IconButton.filledTonal(
                    tooltip: favorite
                        ? 'Remove $name from favourites'
                        : 'Add $name to favourites',
                    onPressed: onFavorite,
                    icon: Icon(
                      favorite ? Icons.favorite : Icons.favorite_border,
                    ),
                  ),
                ),
            ],
          );
          final details = Padding(
            padding: const EdgeInsets.all(Planext4uSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Planext4uSpacing.x1),
                Text(vendor, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: Planext4uSpacing.x2),
                Text(
                  price,
                  style: Planext4uTextStyles.identifier.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Planext4uSpacing.x3),
                Row(
                  children: [
                    Expanded(
                      child: Planext4uStatusPill(
                        label: status,
                        tone: available
                            ? Planext4uStatusTone.success
                            : Planext4uStatusTone.danger,
                      ),
                    ),
                    if (onAddToCart != null) ...[
                      const SizedBox(width: Planext4uSpacing.x1),
                      IconButton(
                        tooltip: 'Add $name to cart',
                        onPressed: available ? onAddToCart : null,
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                      ),
                    ],
                    const SizedBox(width: Planext4uSpacing.x1),
                    IconButton(
                      tooltip: 'View $name',
                      onPressed: onPressed,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ],
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              media,
              if (constraints.hasBoundedHeight)
                Expanded(child: details)
              else
                details,
            ],
          );
        },
      ),
    );
  }
}

class Planext4uStatePanel extends StatelessWidget {
  const Planext4uStatePanel({
    required this.state,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final Planext4uViewState state;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      Planext4uViewState.loading => null,
      Planext4uViewState.empty => Icons.inbox_outlined,
      Planext4uViewState.error => Icons.error_outline,
      Planext4uViewState.offline => Icons.cloud_off_outlined,
      Planext4uViewState.permissionDenied => Icons.lock_outline,
    };
    return Semantics(
      container: true,
      liveRegion: state != Planext4uViewState.loading,
      label: '$title. $message',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Planext4uSpacing.x5),
          child: Column(
            children: [
              if (state == Planext4uViewState.loading)
                const CircularProgressIndicator(
                  semanticsLabel: 'Loading content',
                )
              else
                Icon(icon, size: 32),
              const SizedBox(height: Planext4uSpacing.x3),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Planext4uSpacing.x2),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: Planext4uSpacing.x4),
                Planext4uButton(
                  label: actionLabel!,
                  kind: Planext4uButtonKind.secondary,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

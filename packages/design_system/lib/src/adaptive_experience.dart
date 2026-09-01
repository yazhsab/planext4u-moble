import 'package:flutter/material.dart';

import 'components.dart';

final class Planext4uExperiencePolicy extends InheritedWidget {
  const Planext4uExperiencePolicy({
    required this.dataSaver,
    required super.child,
    super.key,
  });

  final bool dataSaver;

  static bool dataSaverOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<Planext4uExperiencePolicy>()
          ?.dataSaver ??
      false;

  @override
  bool updateShouldNotify(Planext4uExperiencePolicy oldWidget) =>
      oldWidget.dataSaver != dataSaver;
}

class Planext4uAdaptiveAppBuilder extends StatelessWidget {
  const Planext4uAdaptiveAppBuilder({
    required this.child,
    this.dataSaver = false,
    this.forceReducedMotion = false,
    this.minimumTextScale = 1,
    super.key,
  }) : assert(minimumTextScale >= 1 && minimumTextScale <= 2);

  final Widget child;
  final bool dataSaver;
  final bool forceReducedMotion;
  final double minimumTextScale;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reducedMotion =
        forceReducedMotion ||
        media.disableAnimations ||
        media.accessibleNavigation;
    final deviceScale = media.textScaler.scale(1);
    return Planext4uExperiencePolicy(
      dataSaver: dataSaver,
      child: MediaQuery(
        data: media.copyWith(
          disableAnimations: reducedMotion,
          textScaler: deviceScale >= minimumTextScale
              ? media.textScaler
              : TextScaler.linear(minimumTextScale),
        ),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: child,
        ),
      ),
    );
  }
}

class Planext4uNetworkImage extends StatefulWidget {
  const Planext4uNetworkImage({
    required this.url,
    required this.semanticLabel,
    this.fit = BoxFit.cover,
    this.onFirstFrame,
    super.key,
  });

  final String url;
  final String semanticLabel;
  final BoxFit fit;
  final VoidCallback? onFirstFrame;

  @override
  State<Planext4uNetworkImage> createState() => _Planext4uNetworkImageState();
}

class _Planext4uNetworkImageState extends State<Planext4uNetworkImage> {
  bool _requested = false;
  bool _reportedFirstFrame = false;
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final dataSaver = Planext4uExperiencePolicy.dataSaverOf(context);
    if (dataSaver && !_requested) {
      return Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: 'Image paused',
        message: 'Data saver is on. Load this image when you need it.',
        actionLabel: 'Load image',
        onAction: () => setState(() => _requested = true),
      );
    }
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pixelRatio = MediaQuery.devicePixelRatioOf(context);
            final cacheWidth = constraints.hasBoundedWidth
                ? (constraints.maxWidth * pixelRatio)
                      .ceil()
                      .clamp(1, 4096)
                      .toInt()
                : null;
            return Image.network(
              widget.url,
              key: ValueKey('${widget.url}:$_attempt'),
              fit: widget.fit,
              cacheWidth: cacheWidth,
              frameBuilder: (context, child, frame, synchronous) {
                if ((frame != null || synchronous) && !_reportedFirstFrame) {
                  _reportedFirstFrame = true;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => widget.onFirstFrame?.call(),
                  );
                }
                return child;
              },
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Loading image',
                      ),
                    ),
              errorBuilder: (context, error, stack) => Planext4uStatePanel(
                state: Planext4uViewState.error,
                title: 'Image unavailable',
                message: 'Check your connection and try again.',
                actionLabel: 'Retry image',
                onAction: () => setState(() {
                  _attempt += 1;
                  _reportedFirstFrame = false;
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

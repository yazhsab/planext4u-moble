import 'dart:async';
import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'local_app_lock.dart';

final class LocalAppLockGate extends StatefulWidget {
  const LocalAppLockGate({
    required this.controller,
    required this.child,
    super.key,
  });
  final LocalAppLockController? controller;
  final Widget child;
  @override
  State<LocalAppLockGate> createState() => _LocalAppLockGateState();
}

class _LocalAppLockGateState extends State<LocalAppLockGate>
    with WidgetsBindingObserver {
  void _attach() {
    final controller = widget.controller;
    controller?.addListener(_changed);
    if (WidgetsBinding.instance.lifecycleState
        case final AppLifecycleState state) {
      if (state != AppLifecycleState.resumed) controller?.background();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(controller, widget.controller)) {
        unawaited(controller?.initialize());
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attach();
  }

  @override
  void didUpdateWidget(covariant LocalAppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller?.removeListener(_changed);
    _attach();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller?.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.controller?.background();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) return widget.child;
    final locked = controller.locked;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: locked,
          child: ExcludeFocus(
            excluding: locked,
            child: ExcludeSemantics(excluding: locked, child: widget.child),
          ),
        ),
        if (locked)
          Scaffold(
            key: const ValueKey('local-app-lock-gate'),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Unlock Planext4u',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Use your device biometrics or screen lock. You can also sign out and sign in again. This does not renew server authentication.',
                        ),
                        if (controller.busy) const LinearProgressIndicator(),
                        if (controller.error case final String error)
                          Semantics(liveRegion: true, child: Text(error)),
                        const SizedBox(height: 16),
                        if (controller.initialized && controller.enabled)
                          FilledButton(
                            key: const ValueKey('unlock-local-app'),
                            onPressed: controller.busy
                                ? null
                                : controller.unlock,
                            child: const Text('Use device unlock'),
                          ),
                        if (controller.error != null)
                          TextButton(
                            key: const ValueKey('retry-local-app-lock'),
                            onPressed: controller.busy
                                ? null
                                : controller.retryInitialization,
                            child: const Text('Refresh app lock settings'),
                          ),
                        if (controller.canResetAfterFreshSignIn &&
                            controller.error != null)
                          OutlinedButton(
                            key: const ValueKey(
                              'reset-local-lock-after-sign-in',
                            ),
                            onPressed: controller.busy
                                ? null
                                : controller.resetAfterFreshSignIn,
                            child: const Text(
                              'Reset local lock after this fresh sign-in',
                            ),
                          ),
                        TextButton(
                          key: const ValueKey('local-lock-sign-in-again'),
                          onPressed: controller.busy
                              ? null
                              : controller.signInAgain,
                          child: const Text('Sign out and sign in again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

final class LocalAppLockSettings extends StatelessWidget {
  const LocalAppLockSettings({required this.controller, super.key});
  final LocalAppLockController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Planext4uSectionCard(
      title: 'App lock',
      subtitle:
          'Use device biometrics or your device screen lock when returning to this account. Your saved server session and backend permissions still apply.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            key: const ValueKey('enable-local-app-lock'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Require device unlock'),
            value: controller.enabled,
            onChanged:
                controller.busy || controller.locked || !controller.initialized
                ? null
                : controller.setEnabled,
          ),
          if (controller.error case final String error)
            Semantics(liveRegion: true, child: Text(error)),
          if (controller.enabled)
            OutlinedButton(
              key: const ValueKey('lock-local-app-now'),
              onPressed: controller.busy ? null : controller.lock,
              child: const Text('Lock now'),
            ),
        ],
      ),
    ),
  );
}

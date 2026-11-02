import 'dart:async';
import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';
import 'device_permissions.dart';

final class DevicePermissionsScreen extends StatefulWidget {
  const DevicePermissionsScreen({this.controller, super.key});
  final DevicePermissionsController? controller;
  @override
  State<DevicePermissionsScreen> createState() =>
      _DevicePermissionsScreenState();
}

class _DevicePermissionsScreenState extends State<DevicePermissionsScreen>
    with WidgetsBindingObserver {
  late DevicePermissionsController _controller;
  void _attach() {
    _controller = widget.controller ?? DevicePermissionsController();
    _controller.addListener(_changed);
    final current = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(current, _controller)) {
        unawaited(current.refresh());
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
  void didUpdateWidget(covariant DevicePermissionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _controller.removeListener(_changed);
    if (oldWidget.controller == null) _controller.dispose();
    _attach();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _request(DevicePermission permission) async {
    final current = _controller;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Allow ${_title(permission).toLowerCase()}?'),
        content: Text(
          '${_reason(permission)} You can continue without allowing access. Android may offer a one-time or approximate choice. Changing device access does not grant a Planext4u privacy choice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue to Android'),
          ),
        ],
      ),
    );
    if (approved == true && mounted && identical(current, _controller)) {
      await current.request(permission);
    }
  }

  static String _title(DevicePermission permission) => switch (permission) {
    DevicePermission.location => 'Location',
    DevicePermission.camera => 'Camera',
    DevicePermission.microphone => 'Microphone',
    DevicePermission.notifications => 'Notifications',
    DevicePermission.contacts => 'Contacts',
  };
  static String _reason(DevicePermission permission) => switch (permission) {
    DevicePermission.location =>
      'Location supports nearby availability and delivery. Approximate access can limit precise delivery features. No location is collected on this screen.',
    DevicePermission.camera =>
      'Camera access supports photos you choose to capture for a listing or application. Opening these settings does not take a photo.',
    DevicePermission.microphone =>
      'Microphone access supports voice messages or calls you choose to start. Opening these settings does not record audio.',
    DevicePermission.notifications =>
      'Notifications can alert you about account and order activity. Message delivery also depends on your account choices and network.',
    DevicePermission.contacts =>
      'Contact matching shares verified phone digests only after your separate privacy consent and an explicit sync. No names are read.',
  };
  static String _label(DeviceAccess state) => switch (state) {
    DeviceAccess.allowed => 'Allowed by Android',
    DeviceAccess.precise => 'Precise location allowed',
    DeviceAccess.approximate => 'Approximate location allowed',
    DeviceAccess.notAllowed => 'Not allowed by Android',
    DeviceAccess.unavailable => 'Unavailable on this device',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Device permissions')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Planext4uSpacing.x5),
        children: [
          const Text(
            'Android controls device access. Your Planext4u privacy choices remain separate. If Android stops showing a permission prompt, change access in app settings.',
          ),
          SizedBox(
            height: 4,
            child: _controller.busy ? const LinearProgressIndicator() : null,
          ),
          if (_controller.error case final String error)
            Semantics(liveRegion: true, child: Text(error)),
          for (final permission in DevicePermission.values) ...[
            const SizedBox(height: Planext4uSpacing.x4),
            Planext4uSectionCard(
              key: ValueKey('device-permission-card-${permission.name}'),
              title: _title(permission),
              subtitle: _reason(permission),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _controller.snapshot == null
                        ? 'Current access not confirmed'
                        : _label(
                            _controller.snapshot!.permissions[permission]!,
                          ),
                  ),
                  if (permission == DevicePermission.location)
                    Text(
                      _controller.snapshot == null
                          ? 'Device location service status not confirmed.'
                          : _controller.snapshot!.locationServiceEnabled
                          ? 'Device location services are switched on.'
                          : 'Device location services are switched off.',
                    ),
                  if (_controller.snapshot == null ||
                      _controller.snapshot?.permissions[permission] ==
                          DeviceAccess.notAllowed ||
                      permission == DevicePermission.location &&
                          _controller.snapshot?.permissions[permission] ==
                              DeviceAccess.approximate)
                    OutlinedButton(
                      key: ValueKey('request-device-${permission.name}'),
                      onPressed:
                          _controller.busy || _controller.snapshot == null
                          ? null
                          : () => _request(permission),
                      child: const Text('Review permission request'),
                    ),
                  if (permission == DevicePermission.location)
                    TextButton(
                      key: const ValueKey('open-device-location-settings'),
                      onPressed: _controller.busy
                          ? null
                          : () => _controller.openSettings(
                              DeviceSettings.location,
                            ),
                      child: const Text('Open location settings'),
                    ),
                  if (permission == DevicePermission.notifications)
                    TextButton(
                      key: const ValueKey('open-device-notification-settings'),
                      onPressed: _controller.busy
                          ? null
                          : () => _controller.openSettings(
                              DeviceSettings.notifications,
                            ),
                      child: const Text('Open notification settings'),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Planext4uSpacing.x4),
          FilledButton(
            key: const ValueKey('open-device-app-settings'),
            onPressed: _controller.busy
                ? null
                : () => _controller.openSettings(DeviceSettings.application),
            child: const Text('Open Android app settings'),
          ),
          TextButton(
            key: const ValueKey('refresh-device-permissions'),
            onPressed: _controller.busy ? null : _controller.refresh,
            child: const Text('Refresh device permissions'),
          ),
        ],
      ),
    ),
  );
}

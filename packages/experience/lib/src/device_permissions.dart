import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';

/// OS permission state is device-wide, never a substitute for server consent.
final class DevicePermissionsController extends ChangeNotifier {
  DevicePermissionsController({
    DeviceAccessPlatform platform = const AndroidDeviceAccess(),
  }) : _platform = platform;
  final DeviceAccessPlatform _platform;
  DeviceAccessSnapshot? snapshot;
  String? error;
  bool busy = false;
  bool _disposed = false;
  bool _refreshPending = false;
  int _generation = 0;

  Future<void> refresh() async {
    if (_disposed) return;
    if (busy) {
      _refreshPending = true;
      return;
    }
    await _run(_platform.read);
  }

  void _runPendingRefresh() {
    if (_disposed || !_refreshPending) return;
    _refreshPending = false;
    unawaited(refresh());
  }

  /// The screen must obtain an explicit choice after explaining the feature.
  Future<void> request(DevicePermission permission) async {
    if (_disposed || busy) return;
    await _run(() => _platform.request(permission));
  }

  Future<void> _run(Future<DeviceAccessSnapshot> Function() action) async {
    final generation = ++_generation;
    busy = true;
    error = null;
    // A previous grant must never remain visible after a failed OS refresh.
    snapshot = null;
    notifyListeners();
    try {
      final value = await action();
      if (!_disposed && generation == _generation) snapshot = value;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error =
            'Device permissions could not be read. Refresh or use Android settings.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
        _runPendingRefresh();
      }
    }
  }

  Future<void> openSettings(DeviceSettings destination) async {
    if (_disposed || busy) return;
    final generation = ++_generation;
    busy = true;
    error = null;
    snapshot = null;
    notifyListeners();
    try {
      if (!await _platform.openSettings(destination)) {
        throw StateError('Settings unavailable');
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error =
            'Android settings could not be opened. Open this app from your device settings.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
        _runPendingRefresh();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshPending = false;
    _generation++;
    super.dispose();
  }
}

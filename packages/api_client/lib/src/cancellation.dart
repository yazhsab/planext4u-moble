import 'dart:async';

final class ApiCancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  final Map<int, void Function()> _listeners = {};
  int _nextListener = 0;

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
      final listeners = _listeners.values.toList(growable: false);
      _listeners.clear();
      for (final listener in listeners) {
        listener();
      }
    }
  }

  void Function() onCancel(void Function() listener) {
    if (isCancelled) {
      listener();
      return () {};
    }
    final identifier = _nextListener++;
    _listeners[identifier] = listener;
    return () => _listeners.remove(identifier);
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const TransportCancelledException();
    }
  }
}

final class TransportCancelledException implements Exception {
  const TransportCancelledException();

  @override
  String toString() => 'The request was cancelled.';
}

final class TransportTimeoutException implements Exception {
  const TransportTimeoutException();

  @override
  String toString() => 'The request timed out.';
}

final class TransportResponseTooLargeException implements Exception {
  const TransportResponseTooLargeException();

  @override
  String toString() => 'The response exceeded the configured limit.';
}
